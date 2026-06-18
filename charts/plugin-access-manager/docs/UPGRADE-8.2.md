# Helm Upgrade from v8.1.0 to v8.2.0

# Topics

- **[Features](#features)**
  - [1. Enhanced Security Context Configuration](#1-enhanced-security-context-configuration)
  - [2. Single-Source Database Password Management](#2-single-source-database-password-management)
  - [3. PostgreSQL Subchart Version Update](#3-postgresql-subchart-version-update)
  - [4. Insecure TLS Configuration Option](#4-insecure-tls-configuration-option)
  - [5. Chart Type Annotation](#5-chart-type-annotation)
  - [6. Template Helper Improvements](#6-template-helper-improvements)
- **[Breaking Changes](#breaking-changes)**
  - [1. Database Password Configuration](#1-database-password-configuration)
  - [2. Authorizer Client Secret Removal](#2-authorizer-client-secret-removal)
  - [3. Admin Password Validation](#3-admin-password-validation)
- **[Configuration Reference](#configuration-reference)**
  - [Identity Service Security Context](#identity-service-security-context)
  - [Auth Service Security Context](#auth-service-security-context)
  - [Database Password Configuration](#database-password-configuration)
  - [TLS Configuration](#tls-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review and Set Database Password](#step-1-review-and-set-database-password)
  - [Step 2: Configure Authorizer Client Secret](#step-2-configure-authorizer-client-secret)
  - [Step 3: Set Admin Password](#step-3-set-admin-password)
  - [Step 4: Review Security Context Changes](#step-4-review-security-context-changes)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Enhanced Security Context Configuration

Both the identity and auth services now include additional security hardening options in their container security contexts.

**What changed:**

New security context fields have been added to enforce stricter pod security standards:

| Service | Field | v8.1.0 | v8.2.0 |
|---------|-------|--------|--------|
| Identity | `allowPrivilegeEscalation` | *(not set)* | `false` |
| Identity | `seccompProfile.type` | *(not set)* | `RuntimeDefault` |
| Auth | `runAsGroup` | *(commented out)* | `1000` |
| Auth | `runAsUser` | *(commented out)* | `1000` |
| Auth | `runAsNonRoot` | *(commented out)* | `true` |
| Auth | `capabilities.drop` | *(commented out)* | `[ALL]` |
| Auth | `readOnlyRootFilesystem` | *(commented out)* | `true` |
| Auth | `allowPrivilegeEscalation` | *(not set)* | `false` |
| Auth | `seccompProfile.type` | *(not set)* | `RuntimeDefault` |

**Why this matters:**

These changes align the chart with Kubernetes Pod Security Standards (PSS) at the "Restricted" level, providing defense-in-depth security:

- **`allowPrivilegeEscalation: false`** prevents processes from gaining more privileges than their parent
- **`seccompProfile.type: RuntimeDefault`** applies the container runtime's default seccomp profile to limit syscalls
- **`runAsNonRoot: true`** ensures containers don't run as root user
- **`readOnlyRootFilesystem: true`** prevents writes to the container filesystem (except mounted volumes)
- **`capabilities.drop: [ALL]`** removes all Linux capabilities from the container

**Before (v8.1.0):**

```yaml
# identity security context
securityContext:
  runAsGroup: 1000
  runAsUser: 1000
  runAsNonRoot: true
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true

# auth security context (commented out)
securityContext: {}
```

**After (v8.2.0):**

```yaml
# identity security context
securityContext:
  runAsGroup: 1000
  runAsUser: 1000
  runAsNonRoot: true
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault

# auth security context (now enabled)
securityContext:
  runAsGroup: 1000
  runAsUser: 1000
  runAsNonRoot: true
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
```

**Operational impact:**

- Init containers now inherit the same security context as the main containers
- The auth-backend container specifically disables `readOnlyRootFilesystem` because Casdoor writes runtime logs and session files to its working directory
- These settings are applied automatically; no configuration changes are required unless you need to override them

> **Note:** If your environment uses a custom PodSecurityPolicy or Pod Security Admission that conflicts with these settings, you can override them in your `values.yaml` under `identity.securityContext` or `auth.securityContext`.

### 2. Single-Source Database Password Management

The chart now implements a "single-source" pattern for the database password, reading it directly from the PostgreSQL subchart's generated Secret when using the bundled database.

**What changed:**

Previously, the database password had to be set in multiple places (`auth.secrets.DB_PASSWORD` and `auth-database.auth.password`). Now:

- When using the **bundled PostgreSQL subchart** (default), the password is automatically read from the subchart's Secret
- When using an **external database**, you must explicitly set `auth.secrets.DB_PASSWORD`

**Why this matters:**

This eliminates configuration duplication and reduces the risk of password mismatches between the application and database. The password is now managed in a single location.

**How it works:**

A new template helper `plugin-auth.dbPasswordEnv` dynamically determines where to read the password from:

1. If `auth-database.auth.existingSecret` is set → reads from that Secret
2. If using the bundled subchart → reads from the auto-generated `<release>-auth-database` Secret
3. If using an external database → reads from the `plugin-auth` Secret (requires `auth.secrets.DB_PASSWORD` to be set)

**Before (v8.1.0):**

```yaml
# Deployment template - hardcoded secret reference
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: plugin-access-manager-auth
      key: DB_PASSWORD
```

**After (v8.2.0):**

```yaml
# Deployment template - dynamic secret reference
{{- include "plugin-auth.dbPasswordEnv" (dict "context" $ "envName" "DB_PASSWORD") | nindent 10 }}
```

This template helper expands to different configurations based on your setup. See [Database Password Configuration](#database-password-configuration) for details.

### 3. PostgreSQL Subchart Version Update

The bundled PostgreSQL subchart (aliased as `auth-database`) has been updated from version 16.3 to 16.3.5.

| Component | v8.1.0 | v8.2.0 |
|-----------|--------|--------|
| postgresql (auth-database) | 16.3 | 16.3.5 |

**What this means for operators:**

This is a patch version update of the Bitnami PostgreSQL chart that includes bug fixes and security updates. The upgrade should be seamless with no configuration changes required.

> **Note:** If you're using an external database (`auth-database.external: true`), this change does not affect your deployment.

### 4. Insecure TLS Configuration Option

A new environment variable `ALLOW_INSECURE_TLS` has been added to both the identity and auth services.

**What changed:**

| Service | Variable | Default Value |
|---------|----------|---------------|
| Identity | `ALLOW_INSECURE_TLS` | `"true"` |
| Auth | `ALLOW_INSECURE_TLS` | `"true"` |

**Why this matters:**

This flag allows the services to connect to TLS endpoints with self-signed certificates or certificate validation issues, which is common in development and testing environments.

**Configuration:**

```yaml
identity:
  configmap:
    ALLOW_INSECURE_TLS: "true"

auth:
  configmap:
    ALLOW_INSECURE_TLS: "true"
```

> **Warning:** In production environments, you should set this to `"false"` and ensure proper TLS certificate validation is in place.

### 5. Chart Type Annotation

The chart now includes a metadata annotation identifying it as a multi-component chart.

**What changed:**

```yaml
annotations:
  lerian.studio/chart-type: multi-component
```

**Why this matters:**

This annotation provides metadata for tooling and documentation systems to understand that this chart deploys multiple related services (identity, auth, auth-backend) rather than a single application.

**Operational impact:**

This is a metadata-only change with no impact on deployment behavior.

### 6. Template Helper Improvements

The template helpers file has been renamed and enhanced with new functionality.

**What changed:**

| Change | Description |
|--------|-------------|
| File rename | `templates/helpers.tpl` → `templates/_helpers.tpl` |
| New helper | `plugin-auth.dbPasswordEnv` for single-source password management |
| New helper | `common.names.dependency.fullname` vendored from Bitnami common library |
| Removed helper | `plugin-auth-backend.dataSourceName` (no longer needed) |

**Why this matters:**

- The underscore prefix (`_helpers.tpl`) follows Helm best practices for partial/helper templates
- The new helpers enable the single-source password pattern and improve subchart integration
- The vendored Bitnami helper ensures consistent naming even when subcharts are disabled

**Operational impact:**

These are internal template improvements with no direct configuration changes required.

# Breaking Changes

### 1. Database Password Configuration

The way database passwords are configured has changed significantly in v8.2.0.

**What changed:**

| Configuration Path | v8.1.0 | v8.2.0 |
|-------------------|--------|--------|
| `auth.secrets.DB_PASSWORD` | `"lerian"` (default) | `""` (empty, auto-sourced) |
| `auth-database.auth.password` | `"lerian"` (default) | `""` (empty, auto-generated) |

**Why this is breaking:**

If you are using an **external database** (not the bundled PostgreSQL subchart), you **must** now explicitly set `auth.secrets.DB_PASSWORD`. The chart will fail to deploy if this value is empty when using an external database.

**Migration required:**

#### Option 1: Using the bundled PostgreSQL subchart (default)

If you're using the bundled database, **no action is required**. The password is now auto-generated by the PostgreSQL subchart and automatically referenced by the auth service.

**Before (v8.1.0):**

```yaml
auth:
  secrets:
    DB_PASSWORD: "lerian"

auth-database:
  enabled: true
  auth:
    password: "lerian"
```

**After (v8.2.0):**

```yaml
auth:
  secrets:
    DB_PASSWORD: ""  # Leave empty - auto-sourced from subchart

auth-database:
  enabled: true
  auth:
    password: ""  # Leave empty - auto-generated by subchart
```

#### Option 2: Using an external database

If you're using an external database, you **must** set `auth.secrets.DB_PASSWORD`:

```yaml
auth:
  secrets:
    DB_PASSWORD: "your-external-db-password"

auth-database:
  enabled: false
  external: true
```

#### Option 3: Using an existing Secret

If you manage database credentials in an external Secret:

```yaml
auth-database:
  auth:
    existingSecret: "my-db-credentials"
    # The Secret must have a key named "password"
```

> **Important:** The chart will now validate that `auth.secrets.DB_PASSWORD` is set when using an external database. If it's empty, you'll see an error message during deployment with instructions on how to fix it.

### 2. Authorizer Client Secret Removal

The default value for the authorizer client secret has been removed from the common configuration.

**What changed:**

| Configuration Path | v8.1.0 | v8.2.0 |
|-------------------|--------|--------|
| `common.authorizer.clientSecret` | `"6add4bc64f394456a77fa85708ad8c9b67e39e4c"` | *(removed)* |
| `identity.secrets.AUTHORIZER_CLIENT_SECRET` | `"{{ .Values.common.authorizer.clientSecret }}"` | `""` |
| `auth.secrets.AUTHORIZER_CLIENT_SECRET` | `"6add4bc64f394456a77fa85708ad8c9b67e39e4c"` | `""` |

**Why this is breaking:**

The hardcoded client secret was a security risk. You must now explicitly provide this value.

**Migration required:**

Set the authorizer client secret in your `values.yaml`:

```yaml
identity:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "your-client-secret-here"

auth:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "your-client-secret-here"
```

> **Warning:** Do not use the old default value (`6add4bc64f394456a77fa85708ad8c9b67e39e4c`) in production. Generate a new secure secret.

**Alternative: Using existing secrets**

If you manage secrets externally:

```yaml
identity:
  useExistingSecret: true
  existingSecretName: "my-identity-secrets"

auth:
  useExistingSecret: true
  existingSecretName: "my-auth-secrets"
```

### 3. Admin Password Validation

The admin user initialization now requires an explicit password to be set.

**What changed:**

| Configuration Path | v8.1.0 | v8.2.0 |
|-------------------|--------|--------|
| `auth.initUser.adminPassword` | `""` (optional) | `"Lerian@123"` (required) |

**Why this is breaking:**

The chart now validates that `auth.initUser.adminPassword` is set when `auth.initUser.enabled` is true and `auth.initUser.useExistingSecret` is false. This prevents deploying with an empty admin password.

**Migration required:**

If you're using the admin user initialization feature, explicitly set the password:

```yaml
auth:
  initUser:
    enabled: true
    adminPassword: "YourSecurePassword123!"
```

> **Important:** The default value `"Lerian@123"` is provided for development/testing only. **You must change this in production environments.**

**Alternative: Using an existing secret**

```yaml
auth:
  initUser:
    enabled: true
    useExistingSecret: true
    adminPasswordSecretName: "my-admin-password-secret"
```

# Configuration Reference

### Identity Service Security Context

The identity service security context now includes additional hardening options:

```yaml
identity:
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

| Field | Default | Description |
|-------|---------|-------------|
| `runAsGroup` | `1000` | Group ID for the container process |
| `runAsUser` | `1000` | User ID for the container process |
| `runAsNonRoot` | `true` | Ensures the container doesn't run as root |
| `capabilities.drop` | `[ALL]` | Drops all Linux capabilities |
| `readOnlyRootFilesystem` | `true` | Makes the root filesystem read-only |
| `allowPrivilegeEscalation` | `false` | Prevents privilege escalation |
| `seccompProfile.type` | `RuntimeDefault` | Applies default seccomp profile |

### Auth Service Security Context

The auth service security context is now fully enabled with the same hardening options:

```yaml
auth:
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

| Field | Default | Description |
|-------|---------|-------------|
| `runAsGroup` | `1000` | Group ID for the container process |
| `runAsUser` | `1000` | User ID for the container process |
| `runAsNonRoot` | `true` | Ensures the container doesn't run as root |
| `capabilities.drop` | `[ALL]` | Drops all Linux capabilities |
| `readOnlyRootFilesystem` | `true` | Makes the root filesystem read-only |
| `allowPrivilegeEscalation` | `false` | Prevents privilege escalation |
| `seccompProfile.type` | `RuntimeDefault` | Applies default seccomp profile |

> **Note:** The auth-backend container specifically sets `readOnlyRootFilesystem: false` because Casdoor requires write access to its working directory for logs and session files.

### Database Password Configuration

The database password is now single-sourced based on your deployment configuration:

#### Scenario 1: Bundled PostgreSQL (default)

```yaml
auth:
  secrets:
    DB_PASSWORD: ""  # Leave empty

auth-database:
  enabled: true
  auth:
    password: ""  # Auto-generated by subchart
```

The password is automatically read from the `<release>-auth-database` Secret created by the PostgreSQL subchart.

#### Scenario 2: External database

```yaml
auth:
  secrets:
    DB_PASSWORD: "your-external-db-password"

auth-database:
  enabled: false
  external: true
```

You must explicitly provide the password for your external database.

#### Scenario 3: Existing Secret for bundled database

```yaml
auth:
  secrets:
    DB_PASSWORD: ""  # Leave empty

auth-database:
  enabled: true
  auth:
    existingSecret: "my-db-credentials"
```

The password is read from your existing Secret (must have a `password` key).

#### Scenario 4: Existing Secret for application

```yaml
auth:
  useExistingSecret: true
  existingSecretName: "my-auth-secrets"

auth-database:
  enabled: false
  external: true
```

All auth secrets (including `DB_PASSWORD`) are read from your existing Secret.

### TLS Configuration

New environment variables control TLS certificate validation:

```yaml
identity:
  configmap:
    ALLOW_INSECURE_TLS: "true"

auth:
  configmap:
    ALLOW_INSECURE_TLS: "true"
```

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `"true"` | Allows connections to TLS endpoints with invalid certificates |

> **Warning:** Set to `"false"` in production environments with proper TLS certificates.

# Migration Steps

### Step 1: Review and Set Database Password

Determine your database configuration and set the password accordingly.

**If using the bundled PostgreSQL subchart:**

Remove any explicit password values and let the subchart auto-generate:

```yaml
auth:
  secrets:
    DB_PASSWORD: ""

auth-database:
  enabled: true
  auth:
    password: ""
```

**If using an external database:**

Set the password explicitly:

```yaml
auth:
  secrets:
    DB_PASSWORD: "your-external-db-password"

auth-database:
  enabled: false
  external: true
```

### Step 2: Configure Authorizer Client Secret

Set the authorizer client secret for both services:

```yaml
identity:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "your-secure-client-secret"

auth:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "your-secure-client-secret"
```

> **Important:** Generate a new secure secret. Do not reuse the old default value.

### Step 3: Set Admin Password

If using admin user initialization, set a secure password:

```yaml
auth:
  initUser:
    enabled: true
    adminPassword: "YourSecurePassword123!"
```

> **Warning:** Change the default password (`Lerian@123`) in production environments.

### Step 4: Review Security Context Changes

The new security context settings are applied automatically. If your environment requires different settings, override them:

```yaml
identity:
  securityContext:
    runAsUser: 2000  # Example override

auth:
  securityContext:
    runAsUser: 2000  # Example override
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.2.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.2.0 -n plugin-access-manager
```
