# Helm Upgrade from v4.5.0 to v4.5.1

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Chart metadata improvements](#1-chart-metadata-improvements)
  - [2. Removed obsolete CI trigger comment](#2-removed-obsolete-ci-trigger-comment)
  - [3. Simplified external MongoDB configuration guidance](#3-simplified-external-mongodb-configuration-guidance)
  - [4. Removed redundant service configuration variables](#4-removed-redundant-service-configuration-variables)
  - [5. Removed CRM_BASE_PATH configuration](#5-removed-crm_base_path-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that cleans up chart metadata, removes obsolete configuration variables, and simplifies external MongoDB connection guidance. No breaking changes are introduced — all removed variables were redundant or unused by the application.

| Field | v4.5.0 | v4.5.1 |
|-------|--------|--------|
| Chart version | `4.5.0` | `4.5.1` |
| App version | `3.0.0` | `3.0.0` |

## Changes

### 1. Chart metadata improvements

The `home` field in `Chart.yaml` has been updated to point directly to the chart's directory in the repository instead of the repository root.

| Setting | v4.5.0 | v4.5.1 |
|---------|--------|--------|
| `home` | `https://github.com/LerianStudio/helm` | `https://github.com/LerianStudio/helm/tree/main/charts/product-console` |

**Impact:**

This is a documentation-only change that improves discoverability of the chart's source code. No operational impact.

### 2. Removed obsolete CI trigger comment

A CI-related comment has been removed from the end of `values.yaml`:

**Before (v4.5.0):**

```yaml
mongodb:
  persistence:
    size: 8Gi
    resourcePolicy: keep
# ci: re-trigger release — 2.9.0 skipped in run 37708480081 (main moved during semantic-release)
```

**After (v4.5.1):**

```yaml
mongodb:
  persistence:
    size: 8Gi
    resourcePolicy: keep
```

**Impact:**

This is a cosmetic change with no functional impact.

### 3. Simplified external MongoDB configuration guidance

The `NOTES.txt` template has been updated to clarify how external MongoDB connections are configured. The guidance now reflects that the application builds the full connection string internally.

**Before (v4.5.0):**

```yaml
Bundled MongoDB is DISABLED.
Configure an external MongoDB connection using one of the following options:

Option 1 — Full connection string:
  - configmap.MONGODB_URI        (e.g. mongodb://host:27017/dbname)

Option 2 — Host and port pair:
  - configmap.MONGO_HOST         (hostname)
  - configmap.MONGO_PORT         (default: 27017)

Both options also require:
  - configmap.MONGODB_DB_NAME    (database name)
  - configmap.MONGODB_USER       (database user)
  - secrets.MONGODB_PASS         (database password)
```

**After (v4.5.1):**

```yaml
Bundled MongoDB is DISABLED.
Configure an external MongoDB connection:

The console builds the connection string itself. Set:
  - configmap.MONGODB_URI        (the scheme only: mongodb, the default)
  - configmap.MONGO_HOST         (hostname)
  - configmap.MONGO_PORT         (default: 27017)

Also set:
  - configmap.MONGODB_DB_NAME    (database name)
  - configmap.MONGODB_USER       (database user)
  - secrets.MONGODB_PASS         (database password)
```

**Impact:**

This clarifies that `MONGODB_URI` should contain only the connection scheme (`mongodb`), not a full connection string. The application constructs the full URI from the individual components. If you are using an external MongoDB instance, ensure your configuration follows this pattern:

```yaml
configmap:
  MONGODB_URI: "mongodb"
  MONGO_HOST: "your-mongodb-host.example.com"
  MONGO_PORT: "27017"
  MONGODB_DB_NAME: "your-database"
  MONGODB_USER: "your-user"
secrets:
  MONGODB_PASS: "your-password"
```

> **Note:** If you were previously setting a full connection string in `MONGODB_URI`, you should migrate to the component-based approach. The application will construct the URI as `{MONGODB_URI}://{MONGODB_USER}:{MONGODB_PASS}@{MONGO_HOST}:{MONGO_PORT}?{MONGO_PARAMETERS}`.

### 4. Removed redundant service configuration variables

Several environment variables that duplicated information already present in `*_BASE_PATH` variables have been removed from the ConfigMap template:

| Removed Variable | Replacement | Notes |
|------------------|-------------|-------|
| `MIDAZ_TRANSACTION_BASE_HOST` | Use `MIDAZ_TRANSACTION_BASE_PATH` | Full path already includes host and port |
| `MIDAZ_TRANSACTION_BASE_PORT` | Use `MIDAZ_TRANSACTION_BASE_PATH` | Full path already includes host and port |
| `PLUGIN_AUTH_HOST` | Use `PLUGIN_AUTH_BASE_PATH` | Full path already includes host and port |
| `PLUGIN_AUTH_PORT` | Use `PLUGIN_AUTH_BASE_PATH` | Full path already includes host and port |
| `PLUGIN_IDENTITY_HOST` | Use `PLUGIN_IDENTITY_BASE_PATH` | Full path already includes host and port |
| `PLUGIN_IDENTITY_PORT` | Use `PLUGIN_IDENTITY_BASE_PATH` | Full path already includes host and port |

**Before (v4.5.0):**

```yaml
MIDAZ_TRANSACTION_BASE_HOST: "midaz-ledger.midaz.svc.cluster.local"
MIDAZ_TRANSACTION_BASE_PORT: "3002"
MIDAZ_TRANSACTION_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v1"

PLUGIN_AUTH_HOST: "plugin-access-manager-auth.plugin-access-manager.svc.cluster.local"
PLUGIN_AUTH_PORT: "4000"
PLUGIN_AUTH_BASE_PATH: "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000/v1"

PLUGIN_IDENTITY_HOST: "plugin-access-manager-identity.plugin-access-manager.svc.cluster.local"
PLUGIN_IDENTITY_PORT: "4001"
PLUGIN_IDENTITY_BASE_PATH: "http://plugin-access-manager-identity.plugin-access-manager.svc.cluster.local:4001/v1"
```

**After (v4.5.1):**

```yaml
MIDAZ_TRANSACTION_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v1"

PLUGIN_AUTH_BASE_PATH: "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000/v1"

PLUGIN_IDENTITY_BASE_PATH: "http://plugin-access-manager-identity.plugin-access-manager.svc.cluster.local:4001/v1"
```

**Impact:**

The application does not read the removed `*_HOST` and `*_PORT` variables — it only uses the `*_BASE_PATH` variables. If you have overridden any of the removed variables in your `values.yaml`, you should migrate to overriding the corresponding `*_BASE_PATH` variable instead:

```yaml
# Before (v4.5.0)
configmap:
  PLUGIN_AUTH_HOST: "custom-auth-host.example.com"
  PLUGIN_AUTH_PORT: "8080"

# After (v4.5.1)
configmap:
  PLUGIN_AUTH_BASE_PATH: "http://custom-auth-host.example.com:8080/v1"
```

> **Important:** The ConfigMap template changes also include a simplification of the plugin auth configuration logic. The `PLUGIN_AUTH_ENABLED` variable is now set directly instead of using the `lerian-common.auth.env` helper for host/port. The behavior remains the same: `PLUGIN_AUTH_ENABLED` follows `global.auth.enabled` unless explicitly overridden via `configmap.PLUGIN_AUTH_ENABLED`.

### 5. Removed CRM_BASE_PATH configuration

The `CRM_BASE_PATH` environment variable has been removed from the ConfigMap template.

**Before (v4.5.0):**

```yaml
# CRM Plugin Configuration
CRM_BASE_PATH: "http://midaz-crm.midaz.svc.cluster.local:4003/v1/"
```

**After (v4.5.1):**

*(variable removed)*

**Impact:**

If you have overridden `configmap.CRM_BASE_PATH` in your values, you can safely remove that override — the variable is no longer used.

## Migration Steps

This upgrade requires no mandatory configuration changes. However, if you have customized any of the removed variables, follow these steps:

1. Review your current values file to check if any removed variables are set:

```bash
helm get values product-console -n product-console
```

2. If you have overridden any of the following variables, migrate to the corresponding `*_BASE_PATH` variable:

   - `MIDAZ_TRANSACTION_BASE_HOST` / `MIDAZ_TRANSACTION_BASE_PORT` → `MIDAZ_TRANSACTION_BASE_PATH`
   - `PLUGIN_AUTH_HOST` / `PLUGIN_AUTH_PORT` → `PLUGIN_AUTH_BASE_PATH`
   - `PLUGIN_IDENTITY_HOST` / `PLUGIN_IDENTITY_PORT` → `PLUGIN_IDENTITY_BASE_PATH`

   Example migration:

   ```yaml
   # Before
   configmap:
     PLUGIN_AUTH_HOST: "auth.example.com"
     PLUGIN_AUTH_PORT: "9000"

   # After
   configmap:
     PLUGIN_AUTH_BASE_PATH: "http://auth.example.com:9000/v1"
   ```

3. If you have overridden `configmap.CRM_BASE_PATH`, remove it from your values file — the variable is no longer used.

4. If you are using an external MongoDB instance and have set a full connection string in `configmap.MONGODB_URI`, migrate to the component-based approach (see [section 3](#3-simplified-external-mongodb-configuration-guidance)).

5. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

6. Run the upgrade command.

7. Verify the deployment is healthy:

```bash
kubectl rollout status deployment/product-console -n product-console
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console
```

8. Check the ConfigMap to confirm the removed variables are no longer present:

```bash
kubectl get configmap product-console -n product-console -o yaml
```

> **Note:** This upgrade does not change the application image version.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.5.1 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.5.1 -n product-console
```
