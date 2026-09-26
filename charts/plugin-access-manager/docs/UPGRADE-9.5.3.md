# Helm Upgrade from v9.5.2 to v9.5.3

# Topics

- **[Fixes](#fixes)**
  - [1. Security Context Configuration Centralized](#1-security-context-configuration-centralized)
  - [2. Caradhras Migrations Working Directory Fix](#2-caradhras-migrations-working-directory-fix)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Security Context Configuration Centralized

In v9.5.2, security context settings were hardcoded in multiple templates with inconsistent values. This made it difficult to customize security policies across the chart. In v9.5.3, security context configuration has been centralized to use `auth.securityContext` from values, providing a single source of truth for security settings.

**What changed:**

Security context definitions in three templates now reference `.Values.auth.securityContext` instead of using hardcoded values:

**Before (v9.5.2):**

```yaml
# templates/auth/init_user.yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

```yaml
# templates/caradhras/ui-deployment.yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 0
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

```yaml
# templates/caradhras/migrations.yaml
# No securityContext defined for initContainer or main container
```

**After (v9.5.3):**

```yaml
# templates/auth/init_user.yaml
securityContext:
  {{- toYaml .Values.auth.securityContext | nindent 12 }}
```

```yaml
# templates/caradhras/ui-deployment.yaml
securityContext:
  {{- toYaml (omit .Values.auth.securityContext "readOnlyRootFilesystem" "runAsGroup") | nindent 12 }}
```

```yaml
# templates/caradhras/migrations.yaml
# initContainer
securityContext:
  {{- toYaml .Values.auth.securityContext | nindent 10 }}

# main container
securityContext:
  {{- toYaml .Values.auth.securityContext | nindent 12 }}
```

**Why this matters:**

- **Centralized security policy**: All security context settings can now be managed from a single location in `values.yaml`
- **Consistent security posture**: Security settings are now uniform across auth and caradhras components
- **Easier customization**: Operators can override security context settings once instead of patching multiple templates
- **Better compliance**: Organizations with specific security requirements can now enforce them chart-wide

**Components affected:**

| Component | Change |
|-----------|--------|
| `auth/init_user` Job | Now uses `.Values.auth.securityContext` |
| `caradhras/migrations` Job (initContainer) | Now uses `.Values.auth.securityContext` |
| `caradhras/migrations` Job (main container) | Now uses `.Values.auth.securityContext` |
| `caradhras/ui-deployment` | Now uses `.Values.auth.securityContext` (with `readOnlyRootFilesystem` and `runAsGroup` omitted) |

**Special handling for UI deployment:**

The Caradhras UI deployment omits `readOnlyRootFilesystem` and `runAsGroup` from the security context because the bundled nginx server needs to write cache and PID files at runtime. This is intentional and documented in the template comments.

**Default behavior:**

The chart expects `auth.securityContext` to be defined in your values. If you haven't explicitly configured this value, you should add it to maintain the previous security posture:

```yaml
auth:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 0
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

> **Important:** If `auth.securityContext` is not defined in your values, the upgrade will fail with a template rendering error. Ensure this value is set before upgrading.

#### Option 1: Use Recommended Security Context

Add the recommended security context to your `values.yaml`:

```yaml
auth:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 0
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

#### Option 2: Customize for Your Security Policy

If your organization has specific security requirements (e.g., different UID/GID, additional capabilities), configure them once:

```yaml
auth:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
    capabilities:
      drop:
        - ALL
```

#### Option 3: Minimal Security Context

For development or testing environments with relaxed security requirements:

```yaml
auth:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
```

> **Warning:** The minimal configuration is not recommended for production environments. Always follow your organization's security policies and compliance requirements.

### 2. Caradhras Migrations Working Directory Fix

In v9.5.2, the Caradhras migrations container could fail when running with a non-default user ID due to permission issues with the image's default working directory. This has been fixed in v9.5.3 by explicitly setting the working directory to `/tmp`.

**What changed:**

The migrations container now sets an explicit working directory:

**Before (v9.5.2):**

```yaml
# templates/caradhras/migrations.yaml
containers:
  - name: migrate
    image: "{{ include "caradhras.migrationsImageRepository" . }}:{{ include "caradhras.migrationsImageTag" . }}"
    imagePullPolicy: {{ include "caradhras.migrationsImagePullPolicy" . }}
    env:
      - name: DB_HOST
```

**After (v9.5.3):**

```yaml
# templates/caradhras/migrations.yaml
containers:
  - name: migrate
    securityContext:
      {{- toYaml .Values.auth.securityContext | nindent 12 }}
    # The image's workdir /home/nonroot is 0700 for uid 65532; any other uid panics reading conf/ there.
    workingDir: /tmp
    image: "{{ include "caradhras.migrationsImageRepository" . }}:{{ include "caradhras.migrationsImageTag" . }}"
    imagePullPolicy: {{ include "caradhras.migrationsImagePullPolicy" . }}
    env:
      - name: DB_HOST
```

**Why this matters:**

- **Fixes permission errors**: The migrations image's default working directory (`/home/nonroot`) is owned by UID 65532 with 0700 permissions
- **Supports custom user IDs**: When running with a different UID (e.g., 1000), the container can now start successfully
- **Prevents migration failures**: Migrations will no longer fail due to inability to read configuration files from the working directory
- **Better compatibility**: Works correctly regardless of the `runAsUser` setting in your security context

**Technical details:**

The migrations image has a default working directory of `/home/nonroot` with restrictive permissions (0700) owned by UID 65532. When the security context specifies a different user (e.g., `runAsUser: 1000`), the container cannot access this directory and fails to start. By setting `workingDir: /tmp`, the container uses a world-writable directory that works with any user ID.

> **Note:** This change is transparent to operators. No configuration changes are required. The fix ensures migrations work correctly with the centralized security context introduced in Fix #1.

**Impact:**

If you previously experienced migration job failures with errors related to permission denied or inability to read configuration files, this fix resolves those issues. The migrations will now complete successfully regardless of your configured `runAsUser` value.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.3 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.3 -n plugin-access-manager
```
