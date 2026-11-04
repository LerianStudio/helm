<!-- {% raw %} -->
# Helm Upgrade from v5.3.1 to v5.3.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Fixed PostgreSQL persistence configuration structure](#1-fixed-postgresql-persistence-configuration-structure)
  - [2. Removed obsolete Valkey documentation comment](#2-removed-obsolete-valkey-documentation-comment)
  - [3. Relaxed secret validation for external secret scenarios](#3-relaxed-secret-validation-for-external-secret-scenarios)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)

## Overview

This is a patch release that fixes the PostgreSQL persistence configuration structure, removes an obsolete documentation comment, and relaxes secret validation to support scenarios where all components use existing external secrets. The application version remains `1.14.0` and no breaking changes are introduced.

The expected upgrade path is an in-place Helm upgrade with no required configuration changes for most deployments.

| Component | v5.3.1 | v5.3.2 |
|-----------|--------|--------|
| Chart version | `5.3.1` | `5.3.2` |
| App version | `1.14.0` | `1.14.0` |

## Fixes

### 1. Fixed PostgreSQL persistence configuration structure

The PostgreSQL subchart configuration has been corrected to properly nest persistence settings under the `primary` block.

**What changed:**

The `persistence` and `resourcesPreset` settings have been moved from the root `postgresql` level to the `postgresql.primary` block:

**Before (v5.3.1):**

```yaml
postgresql:
  auth:
    username: "pix_btg"
    password: ""
    database: "pix_btg"
  persistence:
    size: 8Gi
  resourcesPreset: large
```

**After (v5.3.2):**

```yaml
postgresql:
  auth:
    username: "pix_btg"
    password: ""
    database: "pix_btg"
  primary:
    persistence:
      size: 8Gi
    resourcesPreset: large
```

**Why it matters:**

The Bitnami PostgreSQL subchart expects persistence and resource configuration to be nested under the `primary` key when using a standalone (non-replicaset) architecture. The previous structure placed these settings at the wrong level, which could cause the subchart to ignore custom persistence size or resource preset overrides.

**Operational impact:**

If you have **not** explicitly overridden `postgresql.persistence.size` or `postgresql.resourcesPreset` in your values file, this change ensures the default `8Gi` persistence size and `large` resource preset are correctly applied to the PostgreSQL primary instance.

If you **have** explicitly overridden these settings at the root `postgresql` level, you must migrate them to the `postgresql.primary` block:

**Migration example:**

**Before (v5.3.1):**

```yaml
postgresql:
  persistence:
    size: 20Gi
  resourcesPreset: xlarge
```

**After (v5.3.2):**

```yaml
postgresql:
  primary:
    persistence:
      size: 20Gi
    resourcesPreset: xlarge
```

> **Important:** If you are using an external PostgreSQL instance (`postgresql.enabled: false`), this change has no impact.

### 2. Removed obsolete Valkey documentation comment

An outdated documentation comment referencing Redis has been removed from the Valkey subchart configuration.

**What changed:**

The following comment lines have been removed from the `valkey` section:

```yaml
valkey:
  # Redis is used to handle scenarios where real-time performance and fast data retrieval are essential.
  # This component is responsible for providing an in-memory data store
  # For more details, refer to the documentation:
  # https://docs.lerian.studio/docs/midaz-components#why-redis
```

**Why it matters:**

The comment referenced "Redis" and linked to documentation about Redis, which is inconsistent with the chart's use of Valkey (a Redis-compatible fork). Removing the outdated comment reduces confusion about which in-memory data store is actually deployed.

**Operational impact:**

This is a documentation-only change with no functional impact. The Valkey subchart configuration and behavior remain unchanged.

### 3. Relaxed secret validation for external secret scenarios

The chart's secret validation logic has been updated to skip required secret checks when all components are configured to use existing external secrets.

**What changed:**

The template helper that validates required secrets now wraps the validation block with a conditional check:

**Before (v5.3.1):**

```yaml
{{/* BTG Secrets - Required */}}
{{- if not .Values.pix.secrets.BTG_CLIENT_ID }}
{{- fail "\n\nERROR: pix.secrets.BTG_CLIENT_ID is required. Set your BTG client ID in secrets section.\n" }}
{{- end }}
{{- if not .Values.pix.secrets.BTG_CLIENT_SECRET }}
{{- fail "\n\nERROR: pix.secrets.BTG_CLIENT_SECRET is required. Set your BTG client secret in secrets section.\n" }}
{{- end }}
{{/* ... additional secret validations ... */}}
```

**After (v5.3.2):**

```yaml
{{/* Required while the chart renders any Secret that reads them; only all-existing-Secrets frees them */}}
{{- if not (and .Values.pix.useExistingSecrets .Values.inbound.useExistingSecrets .Values.outbound.useExistingSecrets .Values.reconciliation.useExistingSecrets .Values.schedule.useExistingSecrets) }}
{{/* BTG Secrets - Required */}}
{{- if not .Values.pix.secrets.BTG_CLIENT_ID }}
{{- fail "\n\nERROR: pix.secrets.BTG_CLIENT_ID is required. Set your BTG client ID in secrets section.\n" }}
{{- end }}
{{- if not .Values.pix.secrets.BTG_CLIENT_SECRET }}
{{- fail "\n\nERROR: pix.secrets.BTG_CLIENT_SECRET is required. Set your BTG client secret in secrets section.\n" }}
{{- end }}
{{/* ... additional secret validations ... */}}
{{- end }}
```

**Why it matters:**

Previously, the chart required all secret values to be set in `values.yaml` even when operators configured all components to use existing external Kubernetes secrets (via `useExistingSecrets: true`). This forced operators to provide dummy values for secrets that would never be used.

The new logic skips secret validation entirely when **all five components** (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) are configured to use existing secrets.

**Operational impact:**

If you are using the chart's built-in secret generation (the default), this change has no impact. Secret validation continues to work as before.

If you are using external secrets for **all components**, you can now omit secret values from your `values.yaml`:

**Configuration example (v5.3.2):**

```yaml
pix:
  useExistingSecrets: true
  existingSecrets:
    - name: btg-credentials
    - name: pix-license

inbound:
  useExistingSecrets: true
  existingSecrets:
    - name: inbound-secrets

outbound:
  useExistingSecrets: true
  existingSecrets:
    - name: outbound-secrets

reconciliation:
  useExistingSecrets: true
  existingSecrets:
    - name: reconciliation-secrets

schedule:
  useExistingSecrets: true
  existingSecrets:
    - name: schedule-secrets

# Secret values no longer required when all components use existing secrets
# pix:
#   secrets:
#     BTG_CLIENT_ID: ""
#     BTG_CLIENT_SECRET: ""
#     # ... etc
```

> **Important:** Secret validation is **only** skipped when **all five** `useExistingSecrets` flags are set to `true`. If even one component uses the chart's built-in secret generation, all required secret values must be provided in `values.yaml`.

> **Note:** The validation logic includes a comment explaining the condition: "Required while the chart renders any Secret that reads them; only all-existing-Secrets frees them." This clarifies that the chart must validate secrets whenever it renders Secret resources that reference the `values.yaml` secret fields.

## Configuration Changes

| Setting | v5.3.1 | v5.3.2 | Notes |
|---------|--------|--------|-------|
| Chart version | `5.3.1` | `5.3.2` | Patch release |
| App version | `1.14.0` | `1.14.0` | No application changes |
| `postgresql.persistence` | Root level | Moved to `postgresql.primary.persistence` | Fixes subchart structure |
| `postgresql.resourcesPreset` | Root level | Moved to `postgresql.primary.resourcesPreset` | Fixes subchart structure |
| Valkey documentation comment | Present | Removed | Documentation cleanup |
| Secret validation | Always enforced | Skipped when all components use existing secrets | Supports external secret scenarios |

## Migration Steps

This upgrade requires minimal operator intervention. Most changes are backward-compatible and will take effect automatically.

**Required actions:**

1. **Migrate PostgreSQL persistence configuration (if customized):**

If you have explicitly overridden `postgresql.persistence.size` or `postgresql.resourcesPreset` at the root level, move them to the `postgresql.primary` block:

```bash
helm get values plugin-br-pix-indirect-btg -n plugin-br-pix-indirect-btg | grep -A 5 "postgresql:"
```

If the command shows `persistence:` or `resourcesPreset:` at the root `postgresql` level, update your values file:

**Before (v5.3.1):**

```yaml
postgresql:
  persistence:
    size: 20Gi
  resourcesPreset: xlarge
```

**After (v5.3.2):**

```yaml
postgresql:
  primary:
    persistence:
      size: 20Gi
    resourcesPreset: xlarge
```

**Optional actions:**

2. **Clean up secret values when using all external secrets:**

If you have configured all five components to use existing external secrets, you can now remove the secret value placeholders from your `values.yaml`:

```yaml
pix:
  useExistingSecrets: true
  # secrets:  # No longer required
  #   BTG_CLIENT_ID: ""
  #   BTG_CLIENT_SECRET: ""
  #   # ... etc

inbound:
  useExistingSecrets: true
  # secrets:  # No longer required

outbound:
  useExistingSecrets: true
  # secrets:  # No longer required

reconciliation:
  useExistingSecrets: true
  # secrets:  # No longer required

schedule:
  useExistingSecrets: true
  # secrets:  # No longer required
```

> **Note:** This is optional. Leaving the secret values in place will not cause errors — they will simply be ignored when `useExistingSecrets: true` is set for all components.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.2 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.2 -n plugin-br-pix-indirect-btg
```
<!-- {% endraw %} -->
