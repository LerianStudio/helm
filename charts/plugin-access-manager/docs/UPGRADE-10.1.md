<!-- {% raw %} -->
# Helm Upgrade from v10.0.3 to v10.1.0

# Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Skip RBAC Chain in Caradhras Migrations](#1-skip-rbac-chain-in-caradhras-migrations)
  - [2. Extra Environment Variables for Migrate Init Container](#2-extra-environment-variables-for-migrate-init-container)
- **[Configuration Reference](#configuration-reference)**
  - [New Caradhras Migration Settings](#new-caradhras-migration-settings)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Determine if You Need skipRBACChain](#step-1-determine-if-you-need-skiprbacchain)
  - [Step 2: Review Any Custom Migration Environment Variables](#step-2-review-any-custom-migration-environment-variables)
  - [Step 3: Verify Image Compatibility](#step-3-verify-image-compatibility)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a minor release that increments the chart version from 10.0.3 to 10.1.0. The application version (appVersion) remains unchanged at `3.13.1`.

**What changed:**

This release introduces two new optional configuration fields under `caradhras.migrations` that provide more control over the database migration process:

1. **`skipRBACChain`**: Allows operators to skip the RBAC (permissions/roles/groups) migration chain when permissions are delivered via external RI manifests
2. **`extraEnvVars`**: Enables passing custom environment variables to the migrate init container

**What this means for operators:**

These changes are **opt-in** and **backward compatible**. If you do not set the new fields, the chart behaves identically to v10.0.3. The upgrade requires no configuration changes unless you have a specific use case for these new features (e.g., cross-environment deployments where RBAC is managed externally).

| Component | v10.0.3 | v10.1.0 |
|-----------|---------|---------|
| Chart version | 10.0.3 | 10.1.0 |
| App version | 3.13.1 | 3.13.1 |
| Caradhras image | *(unchanged)* | *(unchanged)* |
| Caradhras migrations image | *(unchanged)* | *(unchanged)* |

**Action required:**

None for standard deployments. Review the [Migration Steps](#migration-steps) section if you manage RBAC permissions externally or need to pass custom environment variables to the migration process.

# Features

### 1. Skip RBAC Chain in Caradhras Migrations

**What changed:**

A new boolean flag `caradhras.migrations.skipRBACChain` allows operators to skip the RBAC migration chain (Lerian product permissions, roles, and groups under owner 'lerian') during both the migrate init container execution and the caradhras boot schema check.

**Why this matters:**

In some deployment scenarios (e.g., cross-environment installations), RBAC permissions are delivered exclusively through external RI (Resource Inventory) manifests rather than through database migrations. In these cases:

- Running the RBAC migration chain is unnecessary and may cause conflicts
- The caradhras boot schema check would fail if it expects RBAC migrations that were never applied
- Skipping the chain allows the application to start correctly when RBAC is managed externally

**How it works:**

When enabled, the chart sets the `MIGRATIONS_SKIP_RBAC_CHAIN` environment variable to `"true"` in:

1. The `migrate` init container (which runs database migrations before caradhras starts)
2. The main `caradhras` container (which performs a boot-time schema check)

**Before (v10.0.3):**

The migrate init container and caradhras container had no mechanism to skip the RBAC migration chain. All migrations, including RBAC, were always executed and checked.

**After (v10.1.0):**

```yaml
# In the migrate init container
- name: MIGRATIONS_SKIP_RBAC_CHAIN
  value: "true"

# In the caradhras container
- name: MIGRATIONS_SKIP_RBAC_CHAIN
  value: "true"
```

**Template changes:**

**Before (v10.0.3):**

The migrate init container and caradhras container had no conditional logic for RBAC chain handling.

**After (v10.1.0):**

```yaml
# In migrate init container
{{- with .Values.caradhras.migrations }}
{{- if .skipRBACChain }}
# Schema chain only; RBAC arrives via RI manifests. Needs an image that reads it.
- name: MIGRATIONS_SKIP_RBAC_CHAIN
  value: "true"
{{- end }}
{{- end }}

# In caradhras container
{{- if (.Values.caradhras.migrations).skipRBACChain }}
# The boot schema check must skip the chain the migrate init container skipped,
# or any image with a newer rbac head crash-loops. Needs an image that reads it.
- name: MIGRATIONS_SKIP_RBAC_CHAIN
  value: "true"
{{- end }}
```

> **Important:** This feature requires caradhras and caradhras-migrations container images that understand and respect the `MIGRATIONS_SKIP_RBAC_CHAIN` environment variable. Using this flag with older images that do not support it will have no effect.

> **Warning:** Only enable `skipRBACChain` if you are certain that RBAC permissions are being delivered through external RI manifests. Enabling this flag in a standard deployment where RBAC is managed through migrations will result in missing permissions and authorization failures.

### 2. Extra Environment Variables for Migrate Init Container

**What changed:**

A new map field `caradhras.migrations.extraEnvVars` allows operators to pass custom environment variables to the migrate init container. Variables are specified as `NAME: value` pairs and are rendered as standard Kubernetes environment variable entries.

**Why this matters:**

Operators may need to customize the migration process with additional configuration that is not exposed through standard chart values. This field provides a flexible escape hatch for:

- Passing migration-specific feature flags
- Configuring migration behavior for specific environments
- Enabling debug or verbose logging during migrations
- Setting custom timeouts or retry logic

**How it works:**

Each key-value pair in `extraEnvVars` is rendered as a separate environment variable in the migrate init container. Values are automatically converted to strings and quoted in the pod spec.

**Protected variable names:**

The chart refuses to render the following variable names in `extraEnvVars` because they are managed by the chart itself:

- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_SSLMODE`
- `MIGRATIONS_SKIP_RBAC_CHAIN`

Attempting to set any of these will cause the Helm upgrade to fail with an error message.

**Template changes:**

**Before (v10.0.3):**

The migrate init container only received chart-managed environment variables for database connection and SSL mode.

**After (v10.1.0):**

```yaml
{{- range $name, $value := .extraEnvVars }}
{{- if has $name (list "POSTGRES_HOST" "POSTGRES_PORT" "POSTGRES_DB" "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_SSLMODE" "MIGRATIONS_SKIP_RBAC_CHAIN") }}
{{- fail (printf "caradhras.migrations.extraEnvVars.%s duplicates a chart-owned env of the migrate init container; use the chart value instead" $name) }}
{{- end }}
- name: {{ $name | quote }}
  value: {{ $value | toString | quote }}
{{- end }}
```

**Example usage:**

```yaml
caradhras:
  migrations:
    extraEnvVars:
      MIGRATION_TIMEOUT: "300"
      MIGRATION_VERBOSE: "true"
      CUSTOM_FEATURE_FLAG: "enabled"
```

This would render as:

```yaml
- name: "MIGRATION_TIMEOUT"
  value: "300"
- name: "MIGRATION_VERBOSE"
  value: "true"
- name: "CUSTOM_FEATURE_FLAG"
  value: "enabled"
```

> **Note:** Values in `extraEnvVars` are rendered directly into the pod spec and are visible in Kubernetes resource definitions. Do not use this field for secrets or sensitive data. Use Kubernetes Secrets and reference them through standard chart secret mechanisms instead.

> **Warning:** The `extraEnvVars` field is not validated beyond checking for reserved names. Ensure that any custom variables you add are actually read and understood by your caradhras-migrations image, or they will have no effect.

# Configuration Reference

### New Caradhras Migration Settings

The following new configuration fields are available under `caradhras.migrations`:

```yaml
caradhras:
  migrations:
    # Existing fields (image configuration)
    image:
      repository: ""
      tag: ""
    
    # New in v10.1.0
    skipRBACChain: false
    extraEnvVars: {}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `skipRBACChain` | boolean | `false` | Skip the RBAC migration chain (permissions/roles/groups under owner 'lerian') in both the migrate init container and the caradhras boot schema check. Use this when RBAC permissions arrive exclusively via RI manifests (e.g., cross-environment deployments). Requires caradhras and caradhras-migrations images that understand `MIGRATIONS_SKIP_RBAC_CHAIN`. |
| `extraEnvVars` | map | `{}` | Additional environment variables for the migrate init container, specified as `NAME: value` pairs. Values are rendered as quoted strings in the pod spec. Chart-owned variable names (`POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_SSLMODE`, `MIGRATIONS_SKIP_RBAC_CHAIN`) are refused. Not suitable for secrets—values are visible in the pod spec. |

**Environment variables set by skipRBACChain:**

When `skipRBACChain: true`, the following environment variable is added to both the migrate init container and the caradhras container:

| Variable | Value | Description |
|----------|-------|-------------|
| `MIGRATIONS_SKIP_RBAC_CHAIN` | `"true"` | Instructs the migration tooling and caradhras boot check to skip the RBAC migration chain. Only the schema migrations are executed and validated. |

# Migration Steps

### Step 1: Determine if You Need skipRBACChain

Review your deployment architecture to determine if you manage RBAC permissions externally:

#### Option 1: Standard Deployment (No Action Required)

If your deployment relies on database migrations to create and manage RBAC permissions, roles, and groups, **do not enable `skipRBACChain`**. The default behavior (`skipRBACChain: false`) is correct for your environment.

**Indicators you should keep the default:**

- You have never heard of "RI manifests" for RBAC
- Your permissions are created during the initial caradhras deployment
- You do not have external tooling that applies RBAC configuration

**Action:** Proceed with the upgrade using your existing values. No changes required.

#### Option 2: External RBAC Management (Enable skipRBACChain)

If your deployment uses external RI manifests to deliver RBAC permissions (common in cross-environment or multi-tenant architectures), you should enable `skipRBACChain`.

**Indicators you should enable skipRBACChain:**

- You have external tooling or processes that apply RI manifests for permissions
- Your RBAC configuration is managed separately from the caradhras deployment
- You have been instructed by Lerian support to skip the RBAC migration chain
- You are deploying in a "cross" environment where RBAC is centrally managed

**Action:** Add the following to your `values.yaml`:

```yaml
caradhras:
  migrations:
    skipRBACChain: true
```

> **Important:** Before enabling `skipRBACChain`, verify that your caradhras and caradhras-migrations images support the `MIGRATIONS_SKIP_RBAC_CHAIN` environment variable. Check your image documentation or contact Lerian support if unsure.

> **Warning:** Enabling `skipRBACChain` in a standard deployment where RBAC is managed through migrations will result in missing permissions. Users will experience authorization failures when attempting to access resources.

### Step 2: Review Any Custom Migration Environment Variables

If you need to pass custom environment variables to the migrate init container, use the new `extraEnvVars` field.

#### Option 1: No Custom Variables Needed (No Action Required)

If you do not have specific migration configuration requirements beyond what the chart already provides, **do not set `extraEnvVars`**. The default empty map (`{}`) is correct.

**Action:** Proceed with the upgrade using your existing values. No changes required.

#### Option 2: Add Custom Migration Variables

If you need to pass additional configuration to the migration process (e.g., timeouts, feature flags, debug settings), add them to `extraEnvVars`.

**Example:**

```yaml
caradhras:
  migrations:
    extraEnvVars:
      MIGRATION_TIMEOUT: "600"
      MIGRATION_LOG_LEVEL: "debug"
      CUSTOM_MIGRATION_FLAG: "enabled"
```

**Validation:**

The chart will fail the upgrade if you attempt to set any of the following reserved variable names:

- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_SSLMODE`
- `MIGRATIONS_SKIP_RBAC_CHAIN`

If you need to customize these values, use the appropriate chart fields instead:

```yaml
# Use chart fields for database configuration
caradhras:
  database:
    host: "my-postgres.example.com"
    port: 5432
    name: "caradhras_db"
    sslMode: "require"
  
  # Use skipRBACChain for the RBAC chain flag
  migrations:
    skipRBACChain: true
```

> **Note:** Variables set in `extraEnvVars` are only passed to the migrate init container, not to the main caradhras container. If you need to set environment variables for the caradhras application itself, use the appropriate caradhras configuration fields.

> **Warning:** Do not use `extraEnvVars` for sensitive data like passwords or API keys. Values are rendered in plain text in the pod spec and are visible to anyone with access to the Kubernetes resources. Use Kubernetes Secrets and the chart's secret reference mechanisms instead.

### Step 3: Verify Image Compatibility

If you are enabling `skipRBACChain`, verify that your container images support this feature.

**Check your current image versions:**

```bash
helm get values plugin-access-manager -n plugin-access-manager -o yaml | grep -A 5 "caradhras:"
```

Look for the `image.tag` and `migrations.image.tag` values.

**Verify support:**

The `MIGRATIONS_SKIP_RBAC_CHAIN` environment variable is supported in:

- Caradhras images: *(check with Lerian support for minimum version)*
- Caradhras-migrations images: *(check with Lerian support for minimum version)*

If you are using custom image tags, ensure they are recent enough to support this feature. If unsure, contact Lerian support before enabling `skipRBACChain`.

**Test in non-production:**

Before upgrading production, test the new configuration in a non-production environment:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 10.1.0 \
  -n plugin-access-manager-staging \
  -f values.yaml
```

Verify that:

- The migrate init container completes successfully
- The caradhras pod starts without crash-looping
- The boot schema check passes
- RBAC permissions are correctly available (either from migrations or RI manifests)

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.0 -n plugin-access-manager
```
<!-- {% endraw %} -->
