<!-- {% raw %} -->
# Helm Upgrade from v10.4.1 to v10.5.0

# Topics

- **[Features](#features)**
  - [1. Application Version Updates](#1-application-version-updates)
  - [2. Init User Job Replaced with Identity-Managed Admin Creation](#2-init-user-job-replaced-with-identity-managed-admin-creation)
  - [3. Minor Formatting and Whitespace Cleanup](#3-minor-formatting-and-whitespace-cleanup)
- **[Breaking Changes](#breaking-changes)**
  - [Init User Job Removal](#init-user-job-removal)
- **[Configuration Reference](#configuration-reference)**
  - [Init User Configuration](#init-user-configuration)
  - [Version Requirements](#version-requirements)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Verify Component Versions](#step-1-verify-component-versions)
  - [Step 2: Update Init User Configuration](#step-2-update-init-user-configuration)
  - [Step 3: Upgrade the Chart](#step-3-upgrade-the-chart)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Application Version Updates

This release updates the application versions for the identity and auth services in the plugin-access-manager chart.

| Service | v10.4.1 | v10.5.0 |
|---------|---------|---------|
| Identity | 3.16.1 | 3.17.0 |
| Auth | 3.16.1 | 3.17.0 |
| Chart appVersion | 3.16.1 | 3.17.0 |

**What this means for operators:**

These are minor version updates that introduce new functionality for admin user initialization. The identity service now handles first-admin creation directly by calling Caradhras, eliminating the need for a separate Kubernetes Job.

### 2. Init User Job Replaced with Identity-Managed Admin Creation

The standalone `init-user` Kubernetes Job has been completely removed and replaced with a new mechanism where the identity service (version 3.17.0+) calls Caradhras (version 2.1.0+) to create the first Console admin user.

**What changed:**

**Before (v10.4.1):**

The chart deployed a post-install Kubernetes Job (`<release>-auth-init-user`) that:
- Ran once after `helm install` (never on upgrades)
- Connected directly to the database to check for existing users
- Called Caradhras API to create the admin user
- Was deleted automatically after success
- Used a separate `caradhras-user-init` container image

**After (v10.5.0):**

The identity service deployment now includes the admin password and credentials as environment variables, and the service itself calls Caradhras's `ensure-first-admin` endpoint:

```yaml
# v10.5.0 - Environment variables in identity deployment
spec:
  template:
    spec:
      containers:
        - name: <release>-identity
          env:
            - name: ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: <release>-auth-init-user
                  key: ADMIN_PASSWORD
                  optional: true
            - name: ADMIN_EMAIL
              value: "admin@midaz.tech"
            - name: ADMIN_DISPLAY_NAME
              value: "Admin"
```

**Why this matters:**

1. **Simpler lifecycle management**: No separate Job to track or debug; admin creation is part of the identity service's startup routine
2. **Better error visibility**: Admin creation failures appear in identity pod logs and affect readiness, rather than being hidden in a completed Job
3. **Reduced complexity**: Eliminates the need for the init-user container to connect directly to the database
4. **Idempotent behavior**: Caradhras 2.1.0+ ensures the admin is created at most once per organization, even if the identity service restarts

**How it works:**

- Identity 3.17.0+ calls Caradhras's `/api/ensure-first-admin` endpoint during startup
- Caradhras 2.1.0+ checks if the organization has ever been initialized
- If not initialized, Caradhras creates the admin user with the provided credentials
- If already initialized (even if the admin user was later deleted), Caradhras returns 204 and does nothing
- The identity service becomes ready only after this call succeeds (or returns 204)

**Important behavioral change:**

In v10.4.1, deleting the admin user and upgrading the chart would **not** recreate the admin (the Job only ran on first install). In v10.5.0, deleting the admin user will **not** recreate it either—Caradhras tracks whether an organization was ever initialized, and once initialized, it never seeds the admin again, even if the user is deleted.

> **Note:** The Secret holding the admin password (`<release>-auth-init-user`) is no longer a Helm hook resource. It is now a regular Secret, rendered while `auth.initUser.enabled=true` without `useExistingSecret`, and the identity deployment references it with `optional: true` so the pod starts even if the Secret is missing.

### 3. Minor Formatting and Whitespace Cleanup

Several `values.yaml` entries had trailing blank lines or formatting inconsistencies that have been cleaned up. These changes have no functional impact:

- Removed blank lines after `global.scheduling.spread.nodeTaintsPolicy`
- Removed blank lines after `auth.securityContext`
- Removed blank lines after `auth.initUser.enabled`
- Removed blank lines after `caradhras.ui.enabled`
- Reformatted `auth-database.auth.existingSecret` for better readability (line break added for long template expression)

**What this means for operators:**

No action required. These are cosmetic changes to improve `values.yaml` readability and consistency.

# Breaking Changes

### Init User Job Removal

The `init-user` Kubernetes Job resource has been completely removed from the chart templates. If you have automation, monitoring, or documentation that references this Job, you must update it.

**What was removed:**

- The `batch/v1/Job` resource named `<release>-auth-init-user`
- The `caradhras-user-init` container image reference
- All database connection environment variables in the init-user Job (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_SSL_MODE`, `DB_PASS`)
- The `CASDOOR_URL`, `CASDOOR_TIMEOUT_SEC`, and `TABLE_TIMEOUT_SEC` environment variables
- Helm hook annotations (`helm.sh/hook: post-install`, `helm.sh/hook-weight`, `helm.sh/hook-delete-policy`)

**What replaced it:**

- The identity service deployment now includes `ADMIN_PASSWORD`, `ADMIN_EMAIL`, and `ADMIN_DISPLAY_NAME` environment variables (when `auth.initUser.enabled=true`)
- The identity service calls Caradhras's `/api/ensure-first-admin` endpoint during startup
- The `<release>-auth-init-user` Secret is now a regular Secret (not a hook resource) and is rendered while `auth.initUser.enabled=true` without `useExistingSecret`

**Impact on operators:**

1. **Monitoring**: If you monitor Job completion or failure, update your alerts to check identity pod logs for admin creation status instead
2. **Debugging**: Admin creation errors now appear in `kubectl logs deployment/<release>-identity` instead of `kubectl logs job/<release>-auth-init-user`
3. **Automation**: If you have scripts that wait for the init-user Job to complete, remove that logic—identity readiness now waits for admin creation
4. **Documentation**: Update any runbooks or deployment guides that reference the init-user Job

> **Warning:** If a failed v10.4.1 install left the generated `<release>-auth-init-user` Secret with a `helm.sh/hook` annotation behind, delete only that Secret before upgrading. Never delete an external or database Secret.

> **Warning:** If you have `auth.initUser.enabled=true` in your current v10.4.1 deployment and the admin user already exists, the upgrade to v10.5.0 will **not** recreate or modify the existing admin. Caradhras 2.1.0+ tracks initialization state and will return 204 (no action taken) if the organization was previously initialized.

> **Important:** The init-user Job's database connection logic has been removed. The identity service no longer needs direct database access for admin creation—it relies entirely on Caradhras's API.

# Configuration Reference

### Init User Configuration

The `auth.initUser` configuration block has been updated with new documentation and stricter version requirements.

**v10.4.1 configuration:**

```yaml
auth:
  initUser:
    # Long comment about post-install Job behavior, not advertised, etc.
    enabled: false
```

**v10.5.0 configuration:**

```yaml
auth:
  initUser:
    # Identity >= 3.17.0 asks Caradhras >= 2.1.0 (server and migrations) to create
    # the first Console admin at most once, and only for an organization Caradhras
    # never initialized (see README); deleting users never re-seeds it.
    # Set adminPassword or useExistingSecret + adminPasswordSecretName;
    # adminEmail and adminDisplayName are optional.
    enabled: false
```

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `false` | Enable first-admin creation via identity service calling Caradhras |
| `adminPassword` | (required if not using existing secret) | Password for the first admin user; stored in `<release>-auth-init-user` Secret |
| `useExistingSecret` | `false` | Use an existing Secret instead of generating one |
| `adminPasswordSecretName` | `<release>-auth-init-user` | Name of the Secret holding the admin password |
| `adminPasswordSecretKey` | `ADMIN_PASSWORD` | Key within the Secret holding the password |
| `adminEmail` | `admin@midaz.tech` | Email address for the first admin user |
| `adminDisplayName` | `Admin` | Display name for the first admin user |

**Removed fields:**

The following fields from v10.4.1 are no longer used and have been removed:

- `auth.initUser.image` (string or object with `repository`, `tag`, `pullPolicy`)
- `auth.initUser.casdoorTimeout` (default 120)
- `auth.initUser.tableTimeout` (default 60)
- `auth.initUser.resources` (CPU/memory limits for the Job container)

**New environment variables in identity deployment:**

When `auth.initUser.enabled=true`, the identity deployment now includes:

| Variable | Source | Description |
|----------|--------|-------------|
| `ADMIN_PASSWORD` | Secret `<release>-auth-init-user`, key `ADMIN_PASSWORD` | Password for first admin; optional reference (pod starts even if missing) |
| `ADMIN_EMAIL` | `auth.initUser.adminEmail` | Email for first admin; defaults to `admin@midaz.tech` |
| `ADMIN_DISPLAY_NAME` | `auth.initUser.adminDisplayName` | Display name for first admin; defaults to `Admin` |

**Example: Enable init user with generated Secret**

```yaml
auth:
  initUser:
    enabled: true
    adminPassword: "your-secure-password-here"
    adminEmail: "admin@example.com"
    adminDisplayName: "System Administrator"
caradhras:
  # The check needs Caradhras server and migrations >= 2.1.0 (see Version Requirements).
  image:
    tag: "2.1.0"
  migrations:
    image:
      tag: "2.1.0"
  # Caradhras 2.x refuses to boot without its own license key.
  secrets:
    LICENSE_KEY: "your-caradhras-license-key"
```

**Example: Enable init user with existing Secret**

```yaml
auth:
  initUser:
    enabled: true
    useExistingSecret: true
    adminPasswordSecretName: "my-admin-credentials"
    adminPasswordSecretKey: "password"
    adminEmail: "admin@example.com"
caradhras:
  # The check needs Caradhras server and migrations >= 2.1.0 (see Version Requirements).
  image:
    tag: "2.1.0"
  migrations:
    image:
      tag: "2.1.0"
  # Caradhras 2.x refuses to boot without its own license key.
  secrets:
    LICENSE_KEY: "your-caradhras-license-key"
```

> **Note:** If you set `useExistingSecret=true`, you **must** also set `adminPasswordSecretName`. The chart will fail to render if this requirement is not met.

### Version Requirements

The chart now enforces strict version requirements when `auth.initUser.enabled=true` to ensure compatibility between identity and Caradhras.

**Required versions:**

| Component | Minimum Version | Reason |
|-----------|----------------|--------|
| Identity | 3.17.0 | Includes logic to call Caradhras `/api/ensure-first-admin` endpoint |
| Caradhras server | 2.1.0 | Provides `/api/ensure-first-admin` endpoint with idempotent behavior |
| Caradhras migrations | 2.1.0 | Includes database schema for tracking organization initialization state |

**Version validation:**

The chart validates versions using semantic version comparison. The following conditions must be met:

1. All three image tags (`identity.image.tag`, `caradhras.image.tag`, `caradhras.migrations.image.tag`) must be plain semantic versions (e.g., `3.17.0`, `v3.17.0`; prerelease tags such as `3.17.0-rc.1` are refused)
2. No digest-based tags (e.g., `sha256:abc123...`) are allowed when `auth.initUser.enabled=true`
3. No `latest` or non-semver tags are allowed when `auth.initUser.enabled=true`

**Error message if versions are incompatible:**

```
ERROR: auth.initUser.enabled needs identity >= 3.17.0 and Caradhras server and migrations >= 2.1.0 (plain semver tags, no prereleases or digests); got identity 3.16.1, caradhras server 1.8.6, caradhras migrations 1.8.6.
   Pin identity.image.tag=3.17.0 and caradhras.image.tag / caradhras.migrations.image.tag=2.1.0, or set auth.initUser.enabled=false once the first admin exists.
   Caradhras 2.x also needs caradhras.secrets.LICENSE_KEY or caradhras.useExistingSecret.
```

**Multi-tenant mode:**

If `identity.configmap.MULTI_TENANT_ENABLED: "true"` (or `global.multiTenant.enabled=true`), the version check is skipped because multi-tenant identity never calls the `ensure-first-admin` endpoint.

> **Important:** If you use custom image tags (e.g., internal registry tags, commit SHAs, or `latest`), you must either disable `auth.initUser.enabled` or ensure your images are based on the required versions and use semver-compatible tags.

# Migration Steps

### Step 1: Verify Component Versions

Before upgrading, check your current image tags and ensure they meet the minimum requirements if you plan to use `auth.initUser.enabled=true`.

**Check your current values:**

```bash
helm get values plugin-access-manager -n plugin-access-manager
```

Look for:

```yaml
identity:
  image:
    tag: "3.16.1"  # Must be >= 3.17.0

caradhras:
  image:
    tag: "1.8.6"  # Must be >= 2.1.0
  migrations:
    image:
      tag: "1.8.6"  # Must be >= 2.1.0
```

The chart default for both `caradhras.image.tag` and `caradhras.migrations.image.tag` is still `1.8.6`, which the check refuses, even when `helm get values` does not list them.

**If your versions are below the requirements:**

You have two options:

#### Option 1: Upgrade to required versions

Update your `values.yaml` to use the new minimum versions:

```yaml
identity:
  image:
    tag: "3.17.0"

caradhras:
  image:
    tag: "2.1.0"
  migrations:
    image:
      tag: "2.1.0"
```

> **Note:** Caradhras 2.x requires a license key. Ensure you have `caradhras.secrets.LICENSE_KEY` set or `caradhras.useExistingSecret=true` with a valid license Secret.

Identity always authenticates as `app-lerian` with the same client secret as auth (`auth.secrets.AUTHORIZER_CLIENT_SECRET`, `auth.useExistingSecret` or the generated one); it has no secret of its own. Leave `identity.configmap.AUTHORIZER_CLIENT_ID` at its default (the same client auth uses): another client ID would be sent with app-lerian's secret and identity would stay unready.

#### Option 2: Disable init user feature

If you already have an admin user or don't need automatic admin creation, disable the feature:

```yaml
auth:
  initUser:
    enabled: false
```

Identity 3.17.0 also runs this check when `ADMIN_PASSWORD`, `ADMIN_EMAIL` or `ADMIN_DISPLAY_NAME` reaches it outside `auth.initUser`, for example through `identity.extraEnvVars` or the Secret named by `identity.existingSecretName`. The render does not check these. With Caradhras below 2.1.0, remove them before upgrading, or identity stays unready.

### Step 2: Update Init User Configuration

If you currently have `auth.initUser.enabled=true` in v10.4.1, review and update your configuration for v10.5.0.

**Remove obsolete fields:**

If your `values.yaml` includes any of these fields, remove them (they are no longer used):

```yaml
auth:
  initUser:
    image: "..."  # Remove
    casdoorTimeout: 120  # Remove
    tableTimeout: 60  # Remove
    resources:  # Remove
      limits:
        cpu: "100m"
        memory: "128Mi"
```

**Verify required fields:**

Ensure you have either:

1. `adminPassword` set (for generated Secret), or
2. `useExistingSecret=true` with `adminPasswordSecretName` pointing to an existing Secret

**Example updated configuration:**

```yaml
auth:
  initUser:
    enabled: true
    adminPassword: "your-secure-password"
    adminEmail: "admin@example.com"
    adminDisplayName: "Administrator"
caradhras:
  # The check needs Caradhras server and migrations >= 2.1.0 (see Version Requirements).
  image:
    tag: "2.1.0"
  migrations:
    image:
      tag: "2.1.0"
  # Caradhras 2.x refuses to boot without its own license key.
  secrets:
    LICENSE_KEY: "your-caradhras-license-key"
```

### Step 3: Upgrade the Chart

After verifying versions and updating configuration, proceed with the Helm upgrade.

**Preview the changes:**

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.5.0 -n plugin-access-manager
```

**Expected changes in the diff:**

- With `auth.initUser.enabled=true`: identity deployment gets new `ADMIN_PASSWORD`, `ADMIN_EMAIL`, `ADMIN_DISPLAY_NAME` environment variables
- Identity deployment: new `checksum/init-user` annotation
- With `auth.initUser.enabled=true`: auth init-user Job **removed** (will show as deleted)
- With `auth.initUser.enabled=true` and a generated Secret: auth init-user Secret annotations removed (no longer a hook resource)

**Perform the upgrade:**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.5.0 -n plugin-access-manager
```

**Verify the upgrade:**

1. Check that the identity pods are running and ready:

```bash
kubectl get pods -n plugin-access-manager -l app.kubernetes.io/name=plugin-access-manager-identity
```

2. Check identity logs for admin creation status:

```bash
kubectl logs -n plugin-access-manager deployment/<release>-identity --tail=50
```

Look for log entries related to `ensure-first-admin` or admin user creation.

3. With `auth.initUser.enabled=true` and a generated Secret, verify the init-user Secret exists (it is now a regular release Secret):

```bash
kubectl get secret -n plugin-access-manager <release>-auth-init-user
```

4. Confirm the old Job is gone:

```bash
kubectl get job -n plugin-access-manager <release>-auth-init-user
```

This should return "not found" (the Job is removed in v10.5.0).

> **Warning:** If the identity pods fail to become ready after the upgrade, check the logs for errors related to Caradhras connectivity or version mismatches. With `auth.initUser.enabled=true`, the identity service will not become ready until the `ensure-first-admin` call succeeds or returns 204.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.5.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.5.0 -n plugin-access-manager
```
<!-- {% endraw %} -->
