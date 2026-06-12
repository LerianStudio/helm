# Helm Upgrade from v2.0.0 to v2.1.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Application version downgrade](#1-application-version-downgrade)
  - [2. Default PostgreSQL credentials changed](#2-default-postgresql-credentials-changed)
  - [3. Default ALLOW_INSECURE_TLS changed](#3-default-allow_insecure_tls-changed)
- **[Features](#features)**
  - [1. Migrations now enabled by default](#1-migrations-now-enabled-by-default)
  - [2. Chart-managed migration secrets](#2-chart-managed-migration-secrets)
  - [3. Internal PostgreSQL support for migrations](#3-internal-postgresql-support-for-migrations)
  - [4. Automatic migration image tag fallback](#4-automatic-migration-image-tag-fallback)
- **[Configuration Reference](#configuration-reference)**
  - [Migration configuration changes](#migration-configuration-changes)
  - [New template resources](#new-template-resources)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review application version change](#step-1-review-application-version-change)
  - [Step 2: Update PostgreSQL credentials if using defaults](#step-2-update-postgresql-credentials-if-using-defaults)
  - [Step 3: Configure migrations](#step-3-configure-migrations)
  - [Step 4: Review TLS settings](#step-4-review-tls-settings)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This release introduces significant changes to the database migration workflow, adds support for chart-managed PostgreSQL, and changes several default values. The application version has been downgraded from `2.4.0` to `1.0.0`, and migrations are now enabled by default with automatic secret management.

## Breaking Changes

### 1. Application version downgrade

The application version has been changed from `2.4.0` to `1.0.0`.

| Setting | v2.0.0 | v2.1.0 |
|---------|--------|--------|
| `appVersion` | `2.4.0` | `1.0.0` |
| `bankTransfer.image.tag` | `2.4.0` | `1.0.0` |

> **Warning:** This is a **downgrade** of the application version. Ensure that version `1.0.0` of the plugin-br-bank-transfer application is compatible with your existing database schema and runtime environment before upgrading.

**Action required:**

1. Verify that application version `1.0.0` is the correct target version for your deployment
2. If you need to stay on `2.4.0`, explicitly override the image tag:

```yaml
bankTransfer:
  image:
    tag: "2.4.0"
```

### 2. Default PostgreSQL credentials changed

The default PostgreSQL username and database name have been changed in the migrations job.

| Setting | v2.0.0 | v2.1.0 |
|---------|--------|--------|
| Default `POSTGRES_USER` | `plugin-br-bank-transfer` | `bank_transfer` |
| Default `POSTGRES_DB` | `plugin-br-bank-transfer` | `bank_transfer` |

> **Important:** If you are using the default PostgreSQL credentials and have not explicitly set `bankTransfer.configmap.POSTGRES_USER` or `bankTransfer.configmap.POSTGRES_DB`, the migration job will attempt to connect to a database with different credentials after upgrade.

**Action required:**

If your existing deployment uses the old defaults (`plugin-br-bank-transfer`), explicitly set them in your values to maintain compatibility:

```yaml
bankTransfer:
  configmap:
    POSTGRES_USER: "plugin-br-bank-transfer"
    POSTGRES_DB: "plugin-br-bank-transfer"
```

### 3. Default ALLOW_INSECURE_TLS changed

The default value for `ALLOW_INSECURE_TLS` in the migrations job has changed from `false` to `true`.

| Setting | v2.0.0 | v2.1.0 |
|---------|--------|--------|
| Default `ALLOW_INSECURE_TLS` (migrations) | `false` | `true` |

> **Warning:** This change allows the migration job to connect to PostgreSQL without TLS by default. If your PostgreSQL instance requires TLS, you must explicitly configure it.

**Action required:**

If you require TLS connections to PostgreSQL, ensure `POSTGRES_SSLMODE` is set appropriately and set `ALLOW_INSECURE_TLS` to `false`:

```yaml
bankTransfer:
  configmap:
    POSTGRES_SSLMODE: "require"
    ALLOW_INSECURE_TLS: "false"
```

## Features

### 1. Migrations now enabled by default

Database migrations are now enabled by default in v2.1.0.

| Setting | v2.0.0 | v2.1.0 |
|---------|--------|--------|
| `bankTransfer.migrations.enabled` | `false` | `true` |

**What changed:**

In v2.0.0, migrations were disabled by default and required explicit operator configuration. In v2.1.0, migrations run automatically during chart installation and upgrade.

**Why it matters:**

Operators no longer need to manually enable migrations for standard deployments. The migration job will run as a Helm hook before (external PostgreSQL) or after (internal PostgreSQL) the main application deployment.

> **Note:** Migrations remain automatically disabled when `MULTI_TENANT_ENABLED=true`, as tenant-manager owns tenant database migrations in multi-tenant mode.

**Action required:**

If you want to **disable** migrations (e.g., you manage schema separately), explicitly set:

```yaml
bankTransfer:
  migrations:
    enabled: false
```

### 2. Chart-managed migration secrets

The chart now automatically manages secrets for database migrations, eliminating the requirement for pre-existing operator-provisioned secrets.

**Before (v2.0.0):**

```yaml
bankTransfer:
  migrations:
    enabled: true
    useExistingSecret: true  # Required
    existingSecretName: "my-postgres-secret"  # Required
```

**After (v2.1.0):**

```yaml
bankTransfer:
  migrations:
    enabled: true
    # useExistingSecret defaults to false
    # Chart manages the secret automatically
  secrets:
    POSTGRES_PASSWORD: "my-secure-password"
```

**What changed:**

- A new template `migration-secret.yaml` creates a minimal hook Secret containing only `POSTGRES_PASSWORD`
- The Secret is rendered as a `pre-install,pre-upgrade` hook with weight `-5` (before the migration Job at weight `-1`)
- The migration Job now references the chart-managed Secret by default
- `bankTransfer.migrations.useExistingSecret` is now **optional** (defaults to `false`)
- `bankTransfer.migrations.existingSecretName` is only required when `useExistingSecret=true`

**Why it matters:**

Operators no longer need to create and manage a separate Secret before enabling migrations. The chart handles secret lifecycle automatically, including proper cleanup on uninstall.

**Secret resolution order:**

The migration Job resolves `POSTGRES_PASSWORD` in the following priority:

1. Migration-specific existing Secret (`bankTransfer.migrations.existingSecretName`) when `bankTransfer.migrations.useExistingSecret=true`
2. App-level existing Secret (`bankTransfer.existingSecretName`) when `bankTransfer.useExistingSecret=true`
3. Chart-managed Secret (automatic):
   - **Internal PostgreSQL**: References the main application Secret (already exists during post-install/post-upgrade)
   - **External PostgreSQL**: References the new migration-only hook Secret (`<release>-migrations`)

**Migration scenarios:**

#### Option 1: Use chart-managed secrets (recommended)

No action required. Ensure `POSTGRES_PASSWORD` is set in `bankTransfer.secrets`:

```yaml
bankTransfer:
  secrets:
    POSTGRES_PASSWORD: "my-secure-password"
  migrations:
    enabled: true
```

#### Option 2: Continue using existing secrets

If you have an existing Secret and want to keep using it:

```yaml
bankTransfer:
  migrations:
    enabled: true
    useExistingSecret: true
    existingSecretName: "my-postgres-secret"
```

> **Important:** The existing Secret must contain a key named `POSTGRES_PASSWORD`.

### 3. Internal PostgreSQL support for migrations

The chart now supports running migrations against the chart-managed PostgreSQL instance (when `postgresql.enabled=true` and `postgresql.external=false`).

**What changed:**

In v2.0.0, the migration Job would fail with an error if `postgresql.enabled=true` and the database was not external:

```
bankTransfer.migrations.enabled cannot be true when chart-managed postgresql.enabled=true
```

In v2.1.0, migrations automatically adapt based on the PostgreSQL configuration:

| PostgreSQL Mode | Hook Phase | Hook Type | Wait for DB |
|----------------|------------|-----------|-------------|
| External (`postgresql.external=true` or `postgresql.enabled=false`) | Pre-install/Pre-upgrade | `PreSync` (ArgoCD) / `pre-install,pre-upgrade` (Helm) | No (DB already exists) |
| Internal (`postgresql.enabled=true` and `postgresql.external=false`) | Post-install/Post-upgrade | `PostSync` (ArgoCD) / `post-install,post-upgrade` (Helm) | Yes (initContainer waits up to 300s) |

**Before (v2.0.0):**

```yaml
# migrations.yaml (excerpt)
annotations:
  "helm.sh/hook": pre-install,pre-upgrade
  "argocd.argoproj.io/hook": PreSync
# No initContainer support
```

**After (v2.1.0):**

```yaml
# migrations.yaml (excerpt) - Internal PostgreSQL
annotations:
  "helm.sh/hook": post-install,post-upgrade
  "argocd.argoproj.io/hook": PostSync
spec:
  template:
    spec:
      initContainers:
        - name: wait-for-postgres
          image: busybox:1.37
          command:
            - /bin/sh
            - -c
            - >
              echo "Waiting for $POSTGRES_HOST:$POSTGRES_PORT...";
              # Polls with nc -z, 5s interval, 300s timeout
```

**Why it matters:**

Operators can now enable both the chart-managed PostgreSQL **and** migrations in a single deployment. The migration Job automatically waits for the database to be ready before running schema changes.

**Action required:**

If you are using internal PostgreSQL and want to enable migrations:

```yaml
postgresql:
  enabled: true
  external: false
  auth:
    password: "my-postgres-password"

bankTransfer:
  migrations:
    enabled: true
  secrets:
    POSTGRES_PASSWORD: "my-postgres-password"  # Must match postgresql.auth.password
```

> **Important:** When using internal PostgreSQL, `bankTransfer.secrets.POSTGRES_PASSWORD` **must** equal `postgresql.auth.password`. The application and migrations both connect to the same chart-managed database.

### 4. Automatic migration image tag fallback

The migration image tag now automatically falls back to the application image tag when not explicitly set.

| Setting | v2.0.0 Behavior | v2.1.0 Behavior |
|---------|-----------------|-----------------|
| `bankTransfer.migrations.image.tag` (empty) | **Error**: "tag or digest is required" | Falls back to `bankTransfer.image.tag` or `appVersion` |
| `bankTransfer.migrations.image.tag` (set) | Uses explicit tag | Uses explicit tag |
| `bankTransfer.migrations.image.digest` (set) | Uses digest | Uses digest |

**What changed:**

In v2.0.0, the migration image tag was completely decoupled from the application image tag. Operators had to explicitly set `bankTransfer.migrations.image.tag` or `bankTransfer.migrations.image.digest`, or the chart would fail with:

```
migration images must not silently reuse the app tag
```

In v2.1.0, when neither `tag` nor `digest` is set, the migration image tag defaults to:

1. `bankTransfer.image.tag` (if set)
2. Chart `appVersion` (if `bankTransfer.image.tag` is empty)

**Why it matters:**

For most deployments, the migration image version matches the application version. Operators no longer need to duplicate version numbers in two places.

**Migration scenarios:**

#### Option 1: Use automatic fallback (recommended for most cases)

Remove explicit migration image tag configuration:

```yaml
bankTransfer:
  image:
    tag: "1.0.0"
  migrations:
    enabled: true
    # image.tag is empty - automatically uses "1.0.0"
```

#### Option 2: Pin migration image independently

If your migration image version differs from the application version:

```yaml
bankTransfer:
  image:
    tag: "1.0.0"
  migrations:
    enabled: true
    image:
      tag: "1.0.1"  # Explicit override
```

## Configuration Reference

### Migration configuration changes

The following fields in `bankTransfer.migrations` have changed behavior:

| Field | v2.0.0 | v2.1.0 | Notes |
|-------|--------|--------|-------|
| `enabled` | `false` (required `true` + existing secret) | `true` (works with chart-managed secrets) | Now enabled by default |
| `useExistingSecret` | `false` (but migrations required `true`) | `false` | Optional; chart manages secrets when `false` |
| `existingSecretName` | Required when `enabled=true` | Required only when `useExistingSecret=true` | Conditional requirement |
| `image.tag` | Required (explicit) | Optional (falls back to app tag) | Automatic fallback added |

**Complete migration configuration example:**

```yaml
bankTransfer:
  migrations:
    enabled: true
    useExistingSecret: false
    existingSecretName: ""
    image:
      repository: ghcr.io/lerianstudio/plugin-br-bank-transfer-migrations
      tag: ""  # Defaults to bankTransfer.image.tag or appVersion
      pullPolicy: IfNotPresent
    annotations: {}
    serviceAccountName: ""
```

### New template resources

#### migration-secret.yaml

A new template file `migration-secret.yaml` is added in v2.1.0. This Secret is rendered **only** when all of the following conditions are met:

- `bankTransfer.enabled=true`
- `bankTransfer.migrations.enabled=true`
- `bankTransfer.migrations.useExistingSecret=false`
- `bankTransfer.useExistingSecret=false`
- `postgresql.enabled=false` OR `postgresql.external=true` (external PostgreSQL)
- `bankTransfer.configmap.MULTI_TENANT_ENABLED != "true"`

**Resource details:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <release>-migrations
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
    "argocd.argoproj.io/hook": PreSync
    "argocd.argoproj.io/sync-wave": "-5"
type: Opaque
stringData:
  POSTGRES_PASSWORD: <from bankTransfer.secrets.POSTGRES_PASSWORD>
```

**Why it exists:**

When migrations run as a **pre-install/pre-upgrade** hook (external PostgreSQL), they execute before the main application Secret (a normal, non-hook resource) is created. This minimal hook Secret provides only `POSTGRES_PASSWORD` to the migration Job, while keeping the full application Secret as a normal resource to ensure proper cleanup on uninstall.

> **Note:** For internal PostgreSQL, migrations run as a **post-install/post-upgrade** hook, so the main application Secret already exists and is used directly (no separate migration Secret is created).

## Migration Steps

### Step 1: Review application version change

The application version has been downgraded from `2.4.0` to `1.0.0`. Verify this is intentional for your deployment.

**Check your current version:**

```bash
helm list -n plugin-br-bank-transfer
```

**If you need to stay on 2.4.0:**

Create or update your `values.yaml`:

```yaml
bankTransfer:
  image:
    tag: "2.4.0"
  migrations:
    image:
      tag: "2.4.0"  # If migrations image version should match
```

### Step 2: Update PostgreSQL credentials if using defaults

If you have **not** explicitly set `POSTGRES_USER` or `POSTGRES_DB` in your values, and you are using the old defaults, you must preserve them.

**Check your current configuration:**

```bash
helm get values plugin-br-bank-transfer -n plugin-br-bank-transfer
```

**If `bankTransfer.configmap.POSTGRES_USER` and `POSTGRES_DB` are not set:**

Add them to your `values.yaml`:

```yaml
bankTransfer:
  configmap:
    POSTGRES_USER: "plugin-br-bank-transfer"
    POSTGRES_DB: "plugin-br-bank-transfer"
```

**If you are starting fresh or can migrate credentials:**

The new defaults (`bank_transfer`) will be used automatically. Ensure your PostgreSQL instance has a user and database with these names.

### Step 3: Configure migrations

Decide whether to use chart-managed secrets or continue with existing secrets.

#### Option A: Use chart-managed secrets (recommended)

Ensure `POSTGRES_PASSWORD` is set in your values:

```yaml
bankTransfer:
  secrets:
    POSTGRES_PASSWORD: "your-secure-password"
  migrations:
    enabled: true  # Default in v2.1.0
```

If using internal PostgreSQL, ensure the password matches:

```yaml
postgresql:
  enabled: true
  external: false
  auth:
    password: "your-secure-password"

bankTransfer:
  secrets:
    POSTGRES_PASSWORD: "your-secure-password"
  migrations:
    enabled: true
```

#### Option B: Continue using existing secrets

If you have a pre-existing Secret named `my-postgres-secret`:

```yaml
bankTransfer:
  migrations:
    enabled: true
    useExistingSecret: true
    existingSecretName: "my-postgres-secret"
```

Or, if the application already uses an existing Secret:

```yaml
bankTransfer:
  useExistingSecret: true
  existingSecretName: "my-app-secret"
  migrations:
    enabled: true
    # Automatically uses my-app-secret
```

#### Option C: Disable migrations

If you manage database schema separately:

```yaml
bankTransfer:
  migrations:
    enabled: false
```

### Step 4: Review TLS settings

The default `ALLOW_INSECURE_TLS` for migrations has changed to `true`. If you require TLS:

```yaml
bankTransfer:
  configmap:
    POSTGRES_SSLMODE: "require"  # or "verify-ca" / "verify-full"
    ALLOW_INSECURE_TLS: "false"
```

If you are using a non-TLS PostgreSQL instance (e.g., in development), no action is required.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.0 -n plugin-br-bank-transfer
```
