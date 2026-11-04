# Helm Upgrade from v4.1.1 to v4.1.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Removed hardcoded STORAGE_PROVIDER from worker configmap](#1-removed-hardcoded-storage_provider-from-worker-configmap)
  - [2. Removed unused storage encryption keys from worker secrets](#2-removed-unused-storage-encryption-keys-from-worker-secrets)
  - [3. Removed ORGANIZATION_IDS from secrets](#3-removed-organization_ids-from-secrets)
  - [4. Removed SeaweedFS filer connection variables from common configmap](#4-removed-seaweedfs-filer-connection-variables-from-common-configmap)
  - [5. REDIS_TLS now auto-configured from global.datastores.redis.tls](#5-redis_tls-now-auto-configured-from-globaldatastoresredistls)
  - [6. KEDA CRDs now installed by default](#6-keda-crds-now-installed-by-default)
  - [7. Chart home URL updated](#7-chart-home-url-updated)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `4.1.1` to `4.1.2`. This is a **patch** release that removes obsolete configuration keys and improves datastore connection handling. The application version (`appVersion: 4.1.0`) is unchanged.

No breaking changes are introduced. All removed keys were either unused by the application or have been replaced by automatic configuration through the `lerian-common` library. No manual migration is required unless you explicitly overrode the removed keys in your `values.yaml`.

## Fixes

### 1. Removed hardcoded STORAGE_PROVIDER from worker configmap

The `worker.configmap.STORAGE_PROVIDER` key has been removed. This value was hardcoded to `"seaweedfs"` but is now obsolete because object storage configuration is handled exclusively through `global.objectStorage.fetcher` and the `lerian-common.objectStorage.value` template helper.

**Before (v4.1.1):**

```yaml
worker:
  configmap:
    STORAGE_PROVIDER: "seaweedfs"
    OBJECT_STORAGE_KEY_PREFIX: ""
```

**After (v4.1.2):**

```yaml
worker:
  configmap:
    OBJECT_STORAGE_KEY_PREFIX: ""
```

| Setting | v4.1.1 | v4.1.2 |
|---------|--------|--------|
| `worker.configmap.STORAGE_PROVIDER` | `"seaweedfs"` | (removed) |

> **Note:** If you explicitly set `worker.configmap.STORAGE_PROVIDER` in your `values.yaml`, remove it before upgrading. Object storage provider configuration is now controlled by `global.objectStorage.fetcher.provider`.

**Example configuration for object storage:**

```yaml
global:
  objectStorage:
    fetcher:
      provider: "s3"
      endpoint: "s3.amazonaws.com"
      region: "us-east-1"
      bucket: "fetcher-data"
```

### 2. Removed unused storage encryption keys from worker secrets

The following encryption key fields have been removed from `worker.secrets` because they were never used by the application:

- `CRYPTO_ENCRYPT_FILE_STORAGE`
- `CRYPTO_HASH_SECRET_KEY_FILE_STORAGE`

**Before (v4.1.1):**

```yaml
worker:
  secrets:
    STREAMING_SASL_PASSWORD: ""
    STREAMING_TLS_CA_CERT: ""
    CRYPTO_ENCRYPT_FILE_STORAGE: ""
    CRYPTO_HASH_SECRET_KEY_FILE_STORAGE: ""
    CRYPTO_ENCRYPT_SECRET_KEY_PLUGIN_CRM: ""
    CRYPTO_HASH_SECRET_KEY_PLUGIN_CRM: ""
```

**After (v4.1.2):**

```yaml
worker:
  secrets:
    STREAMING_SASL_PASSWORD: ""
    STREAMING_TLS_CA_CERT: ""
    CRYPTO_ENCRYPT_SECRET_KEY_PLUGIN_CRM: ""
    CRYPTO_HASH_SECRET_KEY_PLUGIN_CRM: ""
```

| Setting | v4.1.1 | v4.1.2 |
|---------|--------|--------|
| `worker.secrets.CRYPTO_ENCRYPT_FILE_STORAGE` | `""` | (removed) |
| `worker.secrets.CRYPTO_HASH_SECRET_KEY_FILE_STORAGE` | `""` | (removed) |

> **Note:** If you set these keys in your `values.yaml`, remove them before upgrading. They were never consumed by the worker application and had no operational effect.

### 3. Removed ORGANIZATION_IDS from secrets

The `secrets.ORGANIZATION_IDS` key has been removed from the top-level `secrets` section. This field was unused by both manager and worker components.

**Before (v4.1.1):**

```yaml
secrets:
  REDIS_USER: ""
  REDIS_PASSWORD: ""
  LICENSE_KEY: ""
  ORGANIZATION_IDS: ""
```

**After (v4.1.2):**

```yaml
secrets:
  REDIS_USER: ""
  REDIS_PASSWORD: ""
  LICENSE_KEY: ""
```

| Setting | v4.1.1 | v4.1.2 |
|---------|--------|--------|
| `secrets.ORGANIZATION_IDS` | `""` | (removed) |

> **Note:** If you set `secrets.ORGANIZATION_IDS` in your `values.yaml`, remove it before upgrading. This key was never referenced by the application.

### 4. Removed SeaweedFS filer connection variables from common configmap

The following SeaweedFS filer protocol connection variables have been removed from the common configmap template (`fetcher.commonConfigmapData`):

- `SEAWEEDFS_HOST`
- `SEAWEEDFS_FILER_PORT`
- `SEAWEEDFS_TTL`

These variables were used for the SeaweedFS filer wire protocol, which is distinct from the S3-compatible object storage interface. The application now exclusively uses the S3-compatible interface configured via `global.objectStorage.fetcher`.

**Before (v4.1.1):**

```yaml
# Template output (fetcher.commonConfigmapData)
SEAWEEDFS_HOST: "seaweedfs-filer"
SEAWEEDFS_FILER_PORT: "8888"
SEAWEEDFS_TTL: "6M"
REDIS_HOST: "valkey"
REDIS_PORT: "6379"
REDIS_DB: "0"
```

**After (v4.1.2):**

```yaml
# Template output (fetcher.commonConfigmapData)
REDIS_HOST: "valkey"
REDIS_PORT: "6379"
REDIS_DB: "0"
REDIS_TLS: "false"
```

| Setting | v4.1.1 | v4.1.2 |
|---------|--------|--------|
| `SEAWEEDFS_HOST` | `"seaweedfs-filer"` (default) | (removed) |
| `SEAWEEDFS_FILER_PORT` | `"8888"` (default) | (removed) |
| `SEAWEEDFS_TTL` | `"6M"` (default) | (removed) |

> **Important:** If you were using SeaweedFS as an object storage backend, ensure you have configured `global.objectStorage.fetcher` with the S3-compatible endpoint. The filer wire protocol is no longer supported.

**Example SeaweedFS S3 configuration:**

```yaml
global:
  objectStorage:
    fetcher:
      provider: "s3"
      endpoint: "seaweedfs-s3:8333"
      region: "us-east-1"
      bucket: "fetcher-data"
      usePathStyle: true
```

### 5. REDIS_TLS now auto-configured from global.datastores.redis.tls

The `REDIS_TLS` environment variable is now automatically configured through the `lerian-common` datastore mask, reading from `global.datastores.redis.tls` or `global.cloud`. Previously, this variable was not emitted by any template and had to be set manually in `common.configmap.REDIS_TLS`.

**Before (v4.1.1):**

```yaml
# values.yaml comment
common:
  # NOTE: REDIS_TLS and RABBITMQ_TLS (read by the app) are not emitted by any datastore mask
  # (global.datastores.*.tls/scheme, global.cloud); set them here when the endpoint needs TLS.
  configmap: {}
```

**After (v4.1.2):**

```yaml
# values.yaml comment
common:
  # NOTE: REDIS_TLS follows global.datastores.redis.tls / global.cloud. RABBITMQ_TLS is not
  # emitted by any datastore mask; set it here when the broker needs TLS.
  configmap: {}
```

The template now includes:

```yaml
# Template output (fetcher.commonConfigmapData)
REDIS_TLS: "false"
```

| Setting | v4.1.1 | v4.1.2 |
|---------|--------|--------|
| `REDIS_TLS` | (not emitted, manual override required) | Auto-configured from `global.datastores.redis.tls` |

> **Note:** If you manually set `common.configmap.REDIS_TLS` in your `values.yaml`, you can remove it. The value will now be automatically derived from `global.datastores.redis.tls` or `global.cloud`.

**Example Redis TLS configuration:**

```yaml
global:
  datastores:
    redis:
      host: "redis.example.com"
      port: "6380"
      tls: true
```

This will automatically set `REDIS_TLS: "true"` in the configmap.

### 6. KEDA CRDs now installed by default

The KEDA subchart now installs its Custom Resource Definitions (CRDs) by default. Previously, `keda.crds.install` was set to `false`.

**Before (v4.1.1):**

```yaml
keda:
  enabled: false
  crds:
    install: false
  webhookCerts:
    generate: true
```

**After (v4.1.2):**

```yaml
keda:
  enabled: false
  crds:
    install: true
  webhookCerts:
    generate: true
```

| Setting | v4.1.1 | v4.1.2 |
|---------|--------|--------|
| `keda.crds.install` | `false` | `true` |

> **Note:** This change only affects installations where `keda.enabled: true`. If you enable KEDA, the CRDs will now be installed automatically. If you manage KEDA CRDs separately (e.g., via a cluster-wide KEDA installation), set `keda.crds.install: false` explicitly.

> **Important:** The chart does not include any `ScaledObject` resources. Enabling KEDA installs the operator and CRDs only. Use `manager.autoscaling` (HPA) for autoscaling, or create your own `ScaledObject` resources.

**Example KEDA configuration:**

```yaml
keda:
  enabled: true
  crds:
    install: true
```

### 7. Chart home URL updated

The chart home URL has been updated from the upstream application repository to the Helm chart repository.

**Before (v4.1.1):**

```yaml
home: https://github.com/LerianStudio/fetcher
```

**After (v4.1.2):**

```yaml
home: https://github.com/LerianStudio/helm/tree/main/charts/fetcher
```

| Setting | v4.1.1 | v4.1.2 |
|---------|--------|--------|
| `Chart.yaml` `home` | `https://github.com/LerianStudio/fetcher` | `https://github.com/LerianStudio/helm/tree/main/charts/fetcher` |

> **Note:** This is a metadata change with no operational impact.

## Configuration Changes

The following table summarizes all configuration changes:

| Setting | v4.1.1 | v4.1.2 | Action Required |
|---------|--------|--------|-----------------|
| `worker.configmap.STORAGE_PROVIDER` | `"seaweedfs"` | (removed) | Remove from `values.yaml` if set |
| `worker.secrets.CRYPTO_ENCRYPT_FILE_STORAGE` | `""` | (removed) | Remove from `values.yaml` if set |
| `worker.secrets.CRYPTO_HASH_SECRET_KEY_FILE_STORAGE` | `""` | (removed) | Remove from `values.yaml` if set |
| `secrets.ORGANIZATION_IDS` | `""` | (removed) | Remove from `values.yaml` if set |
| `SEAWEEDFS_HOST` (configmap) | `"seaweedfs-filer"` | (removed) | Migrate to `global.objectStorage.fetcher` |
| `SEAWEEDFS_FILER_PORT` (configmap) | `"8888"` | (removed) | Migrate to `global.objectStorage.fetcher` |
| `SEAWEEDFS_TTL` (configmap) | `"6M"` | (removed) | Migrate to `global.objectStorage.fetcher` |
| `REDIS_TLS` (configmap) | (not emitted) | Auto-configured | Remove manual override if set |
| `keda.crds.install` | `false` | `true` | Set to `false` if managing CRDs externally |

## Migration Steps

This upgrade requires no manual migration steps for most installations. Follow these steps to ensure a smooth upgrade:

1. **Review your `values.yaml` for removed keys.** If you explicitly set any of the following, remove them:

```yaml
# Remove these keys if present
worker:
  configmap:
    STORAGE_PROVIDER: "seaweedfs"  # Remove this line
  secrets:
    CRYPTO_ENCRYPT_FILE_STORAGE: ""  # Remove this line
    CRYPTO_HASH_SECRET_KEY_FILE_STORAGE: ""  # Remove this line

secrets:
  ORGANIZATION_IDS: ""  # Remove this line

common:
  configmap:
    REDIS_TLS: "false"  # Remove this line (now auto-configured)
```

2. **If using SeaweedFS, verify S3 endpoint configuration.** Ensure `global.objectStorage.fetcher` is configured with the S3-compatible endpoint:

```yaml
global:
  objectStorage:
    fetcher:
      provider: "s3"
      endpoint: "seaweedfs-s3:8333"
      region: "us-east-1"
      bucket: "fetcher-data"
      usePathStyle: true
```

3. **If using Redis with TLS, verify datastore configuration.** Ensure `global.datastores.redis.tls` is set correctly:

```yaml
global:
  datastores:
    redis:
      host: "redis.example.com"
      port: "6380"
      tls: true
```

4. **If managing KEDA CRDs externally, disable automatic installation:**

```yaml
keda:
  enabled: true
  crds:
    install: false
```

5. **Preview the changes** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

6. **Run the upgrade** during a maintenance window.

7. **Verify pods are healthy** after the upgrade:

```bash
kubectl get pods -n fetcher
```

8. **Check logs** for any configuration-related errors:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50
```

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.2 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.2 -n fetcher
```
