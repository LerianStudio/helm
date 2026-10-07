# Helm Upgrade from v4.0.0 to v4.0.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Removed obsolete Redis configuration from outbound worker](#1-removed-obsolete-redis-configuration-from-outbound-worker)
  - [2. Removed obsolete WEBHOOK_CLIENT_URL configuration](#2-removed-obsolete-webhook_client_url-configuration)
  - [3. Pinned PostgreSQL and MongoDB image digests](#3-pinned-postgresql-and-mongodb-image-digests)
  - [4. Added MongoDB Recreate update strategy](#4-added-mongodb-recreate-update-strategy)
  - [5. Centralized API URL template helper](#5-centralized-api-url-template-helper)
  - [6. Centralized secret defaults for BTG credentials and webhook secret](#6-centralized-secret-defaults-for-btg-credentials-and-webhook-secret)
  - [7. Simplified Redis host configuration for pix service](#7-simplified-redis-host-configuration-for-pix-service)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that removes obsolete configuration fields, pins database image digests for stability, and centralizes common configuration patterns. The application version remains `1.10.0` and no breaking changes are introduced. Existing custom values continue to work, but operators should review removed fields to ensure they are not explicitly set in their values overrides.

The expected upgrade path is an in-place Helm upgrade with no required configuration changes for most deployments.

| Component | v4.0.0 | v4.0.1 |
|-----------|--------|--------|
| Chart version | `4.0.0` | `4.0.1` |
| App version | `1.10.0` | `1.10.0` |

## Fixes

### 1. Removed obsolete Redis configuration from outbound worker

The outbound worker no longer requires Redis/Valkey configuration. All Redis-related environment variables have been removed from the outbound worker's ConfigMap.

**What changed:**

The following environment variables have been removed from `outbound.configmap`:

- `REDIS_HOST`
- `REDIS_PORT`
- `REDIS_USER`
- `REDIS_MASTER_NAME`
- `REDIS_TLS`
- `REDIS_CA_CERT`
- `REDIS_USE_GCP_IAM`
- `REDIS_SERVICE_ACCOUNT`
- `GOOGLE_APPLICATION_CREDENTIALS`
- `REDIS_TOKEN_LIFETIME`
- `REDIS_TOKEN_REFRESH_DURATION`
- `REDIS_DB`
- `REDIS_PROTOCOL`
- `REDIS_POOL_SIZE`
- `REDIS_MIN_IDLE_CONNS`
- `REDIS_READ_TIMEOUT`
- `REDIS_WRITE_TIMEOUT`
- `REDIS_DIAL_TIMEOUT`
- `REDIS_POOL_TIMEOUT`
- `REDIS_MAX_RETRIES`
- `REDIS_MIN_RETRY_BACKOFF`
- `REDIS_MAX_RETRY_BACKOFF`

**Why it matters:**

The outbound worker's architecture no longer uses Redis for caching or state management. Removing these unused configuration fields reduces configuration complexity and prevents confusion about which components require Redis connectivity.

**Operational impact:**

If you have explicitly set any of these Redis configuration values in your `outbound.configmap` overrides, they will be ignored after the upgrade. The outbound worker will continue to function normally without Redis connectivity.

**Before (v4.0.0):**

```yaml
outbound:
  configmap:
    REDIS_HOST: "valkey-master.midaz-plugins.svc.cluster.local"
    REDIS_PORT: "6379"
    REDIS_USER: "plugin"
    # ... 20+ additional Redis settings
```

**After (v4.0.1):**

```yaml
outbound:
  configmap:
    # Redis configuration removed — outbound worker no longer uses Redis
    DB_HOST: "postgresql.midaz-plugins.svc.cluster.local"
    # ... other non-Redis settings
```

> **Note:** The `pix`, `inbound`, and `reconciliation` components still use Redis/Valkey. Only the outbound worker's Redis configuration has been removed.

### 2. Removed obsolete WEBHOOK_CLIENT_URL configuration

The `WEBHOOK_CLIENT_URL` environment variable has been removed from the outbound worker's ConfigMap, along with the associated warning annotation helper.

**What changed:**

The following configuration has been removed:

- `outbound.configmap.WEBHOOK_CLIENT_URL` environment variable
- `plugin-br-pix-indirect-btg.webhookWarnings` template helper that generated warning annotations for missing webhook URLs

**Why it matters:**

The `WEBHOOK_CLIENT_URL` field was deprecated in favor of entity-specific webhook URLs (e.g., `WEBHOOK_RECURRING_AUTHORIZATION_URL`, `WEBHOOK_DICT_CLAIM_URL`). The `WEBHOOK_DEFAULT_URL` field serves as the fallback when entity-specific URLs are not configured.

**Operational impact:**

If you have explicitly set `WEBHOOK_CLIENT_URL` in your `outbound.configmap` overrides, remove it and ensure `WEBHOOK_DEFAULT_URL` is configured instead.

**Before (v4.0.0):**

```yaml
outbound:
  configmap:
    WEBHOOK_DEFAULT_URL: "https://api.example.com/webhooks/default"
    WEBHOOK_CLIENT_URL: "https://api.example.com/webhooks/client"
    WEBHOOK_DICT_CLAIM_URL: ""
```

**After (v4.0.1):**

```yaml
outbound:
  configmap:
    # WEBHOOK_DEFAULT_URL is required when an enabled entity has no entity or flow URL
    WEBHOOK_DEFAULT_URL: "https://api.example.com/webhooks/default"
    WEBHOOK_DICT_CLAIM_URL: ""
```

> **Important:** The comment for `WEBHOOK_DEFAULT_URL` has been updated to clarify its purpose: "WEBHOOK_DEFAULT_URL is required when an enabled entity has no entity or flow URL." Ensure this field is set if you have webhook handlers enabled without entity-specific URLs.

### 3. Pinned PostgreSQL and MongoDB image digests

The bundled PostgreSQL and MongoDB subcharts now use pinned image digests to ensure consistent versions across deployments.

**What changed:**

Two new fields have been added to pin database image versions:

| Setting | v4.0.0 | v4.0.1 |
|---------|--------|--------|
| `postgresql.image.digest` | (not present) | `"sha256:7045d816bdf7e704f0f662fabf243f3c0a975aa380e73e4e881ee94740f60d4f"` |
| `mongodb.image.digest` | (not present) | `"sha256:c8babafb7d15a7412543a9a391ffee8ba206c4d10dd6a1ba2ae2bf74fdfe538b"` |

**Why it matters:**

Pinning image digests prevents unexpected version changes when pulling the `latest` tag. This is critical for databases because:

- **PostgreSQL refuses to start** if the data directory was created by a different major version
- **MongoDB requires careful version management** to avoid data directory compatibility issues

The pinned digests correspond to:

- PostgreSQL 18.6.0 (latest as of this release)
- MongoDB 8.3.11 (latest as of this release)

**Operational impact:**

If you are using the bundled PostgreSQL or MongoDB subcharts (the default), the upgrade will pin the image versions to the specified digests. This ensures that subsequent Helm upgrades or pod restarts will use the exact same database versions.

**If you are using external databases** (`postgresql.enabled: false` or `mongodb.enabled: false`), this change has no impact.

**Configuration:**

```yaml
postgresql:
  image:
    repository: bitnamisecure/postgresql
    tag: "latest"
    # latest (PostgreSQL 18.6.0), pinned: PostgreSQL refuses a data directory of another major.
    digest: "sha256:7045d816bdf7e704f0f662fabf243f3c0a975aa380e73e4e881ee94740f60d4f"

mongodb:
  image:
    repository: bitnamisecure/mongodb
    tag: "latest"
    # latest (MongoDB 8.3.11), pinned so the version opening this volume changes only on upgrade.
    digest: "sha256:c8babafb7d15a7412543a9a391ffee8ba206c4d10dd6a1ba2ae2bf74fdfe538b"
```

> **Warning:** If you need to upgrade PostgreSQL or MongoDB to a newer version, you must update the `digest` field to the new version's digest and follow the database vendor's upgrade procedures. Simply changing the `tag` field will not work when a digest is pinned.

### 4. Added MongoDB Recreate update strategy

The bundled MongoDB subchart now uses a `Recreate` update strategy to prevent data directory conflicts during upgrades.

**What changed:**

A new `updateStrategy` configuration has been added to the MongoDB subchart:

```yaml
mongodb:
  # Recreate, not a rolling update: a new mongod cannot open the data directory the old pod still holds.
  # architecture: replicaset or useStatefulSet: true needs updateStrategy.type: RollingUpdate; a StatefulSet refuses Recreate.
  updateStrategy:
    type: Recreate
```

**Why it matters:**

MongoDB cannot open a data directory that is still held by another running instance. With the default `RollingUpdate` strategy, a new pod may attempt to start before the old pod has fully terminated, causing startup failures.

The `Recreate` strategy ensures the old pod is fully terminated and the data directory is released before the new pod starts.

**Operational impact:**

When upgrading the chart, the MongoDB pod will experience a brief downtime while the old pod terminates and the new pod starts. This is expected behavior and ensures data directory integrity.

**If you are using MongoDB in replicaset mode** (`mongodb.architecture: replicaset` or `mongodb.useStatefulSet: true`), this setting will be ignored because StatefulSets require `RollingUpdate` strategy. In that case, ensure your replicaset configuration handles data directory locking correctly.

> **Note:** This change only affects the bundled MongoDB subchart. If you are using an external MongoDB instance (`mongodb.enabled: false`), this change has no impact.

### 5. Centralized API URL template helper

A new template helper `plugin-br-pix-indirect-btg.apiURL` has been added to generate the internal API Service URL consistently across all components.

**What changed:**

A new template helper has been added to `_helpers.tpl`:

```yaml
{{/*
plugin-br-pix-indirect-btg.apiURL — this release's API Service, which the inbound, reconciliation and
schedule workers call.
*/}}
{{- define "plugin-br-pix-indirect-btg.apiURL" -}}
{{- printf "http://%s.%s.svc.cluster.local:%v" (include "plugin-br-pix-indirect-btg.fullname" .) .Release.Namespace .Values.pix.service.port -}}
{{- end }}
```

This helper is now used as the default value for:

- `inbound.configmap.WEBHOOK_INBOUND_BASE_URL`
- `reconciliation.configmap.PLUGIN_PIX_BTG_BASE_URL`
- `schedule.configmap.SCHEDULE_APP_BASE_URL`

**Why it matters:**

Previously, these three fields had hardcoded default URLs that assumed a specific release name and namespace (`http://plugin-br-pix-indirect-btg.midaz-plugins.svc.cluster.local:4014`). This caused configuration errors when deploying the chart with a different release name or namespace.

The new helper generates the correct URL based on the actual release name, namespace, and service port, ensuring internal communication works correctly regardless of deployment configuration.

**Operational impact:**

If you have **not** explicitly set these three configuration values, the upgrade will automatically use the new dynamic default. The generated URL will match your actual deployment configuration.

If you **have** explicitly set these values in your overrides, they will continue to be used and the new helper will be ignored.

**Before (v4.0.0):**

```yaml
inbound:
  configmap:
    WEBHOOK_INBOUND_BASE_URL: "http://plugin-br-pix-indirect-btg.midaz-plugins.svc.cluster.local:4014"

reconciliation:
  configmap:
    PLUGIN_PIX_BTG_BASE_URL: "http://plugin-br-pix-indirect-btg.midaz-plugins.svc.cluster.local:4014"

schedule:
  configmap:
    SCHEDULE_APP_BASE_URL: "http://plugin-br-pix-indirect-btg.midaz-plugins.svc.cluster.local:4014"
```

**After (v4.0.1):**

```yaml
inbound:
  configmap:
    # Defaults to: http://<release-name>.<namespace>.svc.cluster.local:<pix.service.port>
    WEBHOOK_INBOUND_BASE_URL: ""  # Uses template helper default

reconciliation:
  configmap:
    # Defaults to: http://<release-name>.<namespace>.svc.cluster.local:<pix.service.port>
    PLUGIN_PIX_BTG_BASE_URL: ""  # Uses template helper default

schedule:
  configmap:
    # Defaults to: http://<release-name>.<namespace>.svc.cluster.local:<pix.service.port>
    SCHEDULE_APP_BASE_URL: ""  # Uses template helper default
```

> **Note:** If you deploy the chart with a custom release name or namespace, the new helper will automatically generate the correct URL. You no longer need to override these fields manually.

### 6. Centralized secret defaults for BTG credentials and webhook secret

The `reconciliation` and `inbound` workers now fall back to the `pix` service's secret values for BTG credentials and internal webhook secrets when component-specific values are not provided.

**What changed:**

Two secret fields now have fallback logic:

**Reconciliation worker BTG credentials:**

**Before (v4.0.0):**

```yaml
data:
  BTG_CLIENT_ID: {{ .Values.reconciliation.secrets.BTG_CLIENT_ID | default "" | b64enc | quote }}
  BTG_CLIENT_SECRET: {{ .Values.reconciliation.secrets.BTG_CLIENT_SECRET | default "" | b64enc | quote }}
```

**After (v4.0.1):**

```yaml
data:
  BTG_CLIENT_ID: {{ .Values.reconciliation.secrets.BTG_CLIENT_ID | default .Values.pix.secrets.BTG_CLIENT_ID | default "" | b64enc | quote }}
  BTG_CLIENT_SECRET: {{ .Values.reconciliation.secrets.BTG_CLIENT_SECRET | default .Values.pix.secrets.BTG_CLIENT_SECRET | default "" | b64enc | quote }}
```

**Inbound worker internal webhook secret:**

**Before (v4.0.0):**

```yaml
data:
  INTERNAL_WEBHOOK_SECRET: {{ .Values.inbound.secrets.INTERNAL_WEBHOOK_SECRET | default "" | b64enc | quote }}
```

**After (v4.0.1):**

```yaml
data:
  INTERNAL_WEBHOOK_SECRET: {{ .Values.inbound.secrets.INTERNAL_WEBHOOK_SECRET | default .Values.pix.secrets.INTERNAL_WEBHOOK_SECRET | default "" | b64enc | quote }}
```

**Why it matters:**

This change reduces configuration duplication. Operators can now set BTG credentials and the internal webhook secret once in the `pix.secrets` block, and both the reconciliation and inbound workers will inherit those values automatically.

**Operational impact:**

If you have set these secrets in multiple places (e.g., both `pix.secrets` and `reconciliation.secrets`), the component-specific values will continue to take precedence. If you have only set them in `pix.secrets`, the reconciliation and inbound workers will now automatically use those values.

**Recommended configuration (v4.0.1):**

```yaml
pix:
  secrets:
    BTG_CLIENT_ID: "your-btg-client-id"
    BTG_CLIENT_SECRET: "your-btg-client-secret"
    INTERNAL_WEBHOOK_SECRET: "your-webhook-secret"

# reconciliation and inbound will inherit the above values automatically
reconciliation:
  secrets:
    # BTG_CLIENT_ID: ""  # Optional override
    # BTG_CLIENT_SECRET: ""  # Optional override

inbound:
  secrets:
    # INTERNAL_WEBHOOK_SECRET: ""  # Optional override
```

> **Note:** This is a non-breaking change. Existing configurations with component-specific secrets will continue to work exactly as before.

### 7. Simplified Redis host configuration for pix service

The `pix` service now combines Redis host and port into a single `REDIS_HOST` environment variable.

**What changed:**

The `pix` service's Redis configuration has been simplified:

**Before (v4.0.0):**

```yaml
pix:
  configmap:
    REDIS_HOST: "valkey-master.midaz-plugins.svc.cluster.local"
    REDIS_PORT: "6379"
```

**After (v4.0.1):**

```yaml
pix:
  configmap:
    REDIS_HOST: "valkey-master.midaz-plugins.svc.cluster.local:6379"
    # REDIS_PORT removed — port is now part of REDIS_HOST
```

The template now generates the combined host:port format by default:

```yaml
REDIS_HOST: {{ .Values.pix.configmap.REDIS_HOST | default (printf "%s:6379" (include "plugin-br-pix-indirect-btg.valkeyHost" .)) | quote }}
```

**Why it matters:**

This change aligns the `pix` service's Redis configuration with common connection string patterns and reduces the number of configuration fields.

**Operational impact:**

If you have explicitly set `pix.configmap.REDIS_HOST` without a port, you must update it to include the port number.

**Migration example:**

**Before (v4.0.0):**

```yaml
pix:
  configmap:
    REDIS_HOST: "my-redis-instance.example.com"
    REDIS_PORT: "6379"
```

**After (v4.0.1):**

```yaml
pix:
  configmap:
    REDIS_HOST: "my-redis-instance.example.com:6379"
```

> **Important:** If you are using the bundled Valkey subchart (the default), the template will automatically generate the correct host:port format. You only need to update your configuration if you have explicitly overridden `REDIS_HOST` with an external Redis instance.

## Configuration Changes

| Setting | v4.0.0 | v4.0.1 | Notes |
|---------|--------|--------|-------|
| Chart version | `4.0.0` | `4.0.1` | Patch release |
| App version | `1.10.0` | `1.10.0` | No application changes |
| `outbound.configmap.REDIS_*` | 23 Redis settings | (removed) | Outbound worker no longer uses Redis |
| `outbound.configmap.WEBHOOK_CLIENT_URL` | `""` | (removed) | Use `WEBHOOK_DEFAULT_URL` instead |
| `postgresql.image.digest` | (not present) | `"sha256:7045..."` | Pins PostgreSQL 18.6.0 |
| `mongodb.image.digest` | (not present) | `"sha256:c8ba..."` | Pins MongoDB 8.3.11 |
| `mongodb.updateStrategy.type` | (not present) | `Recreate` | Prevents data directory conflicts |
| `pix.configmap.REDIS_HOST` | Host only | Host:port combined | Port now included in host string |
| `reconciliation.secrets.BTG_CLIENT_ID` | Component-specific | Falls back to `pix.secrets.BTG_CLIENT_ID` | Reduces duplication |
| `reconciliation.secrets.BTG_CLIENT_SECRET` | Component-specific | Falls back to `pix.secrets.BTG_CLIENT_SECRET` | Reduces duplication |
| `inbound.secrets.INTERNAL_WEBHOOK_SECRET` | Component-specific | Falls back to `pix.secrets.INTERNAL_WEBHOOK_SECRET` | Reduces duplication |

## Migration Steps

This upgrade requires minimal operator intervention. Most changes are backward-compatible and will take effect automatically.

**Required actions:**

1. **Review and remove obsolete Redis configuration from outbound worker:**

If you have explicitly set any Redis configuration in `outbound.configmap`, remove those settings:

```bash
helm get values plugin-br-pix-indirect-btg -n plugin-br-pix-indirect-btg | grep -A 30 "outbound:" | grep "REDIS_"
```

If the command returns any Redis settings, remove them from your values overrides.

2. **Replace WEBHOOK_CLIENT_URL with WEBHOOK_DEFAULT_URL:**

If you have explicitly set `outbound.configmap.WEBHOOK_CLIENT_URL`, remove it and ensure `WEBHOOK_DEFAULT_URL` is configured:

```yaml
outbound:
  configmap:
    # WEBHOOK_CLIENT_URL: ""  # Remove this line
    WEBHOOK_DEFAULT_URL: "https://api.example.com/webhooks/default"
```

3. **Update Redis host configuration for pix service (if using external Redis):**

If you have explicitly set `pix.configmap.REDIS_HOST` to an external Redis instance, update it to include the port:

```yaml
pix:
  configmap:
    REDIS_HOST: "my-redis-instance.example.com:6379"
```

**Optional actions:**

4. **Consolidate BTG credentials and webhook secrets:**

If you have set BTG credentials or internal webhook secrets in multiple places, consider consolidating them in `pix.secrets`:

```yaml
pix:
  secrets:
    BTG_CLIENT_ID: "your-btg-client-id"
    BTG_CLIENT_SECRET: "your-btg-client-secret"
    INTERNAL_WEBHOOK_SECRET: "your-webhook-secret"

# Remove duplicate settings from reconciliation and inbound
reconciliation:
  secrets:
    # BTG_CLIENT_ID: ""  # Inherited from pix.secrets
    # BTG_CLIENT_SECRET: ""  # Inherited from pix.secrets

inbound:
  secrets:
    # INTERNAL_WEBHOOK_SECRET: ""  # Inherited from pix.secrets
```

5. **Review database image digests:**

If you need to use a different PostgreSQL or MongoDB version, update the `digest` fields:

```yaml
postgresql:
  image:
    digest: "sha256:your-preferred-postgresql-digest"

mongodb:
  image:
    digest: "sha256:your-preferred-mongodb-digest"
```

> **Note:** Changing database versions requires careful planning and may require data migration. Consult the PostgreSQL and MongoDB upgrade documentation before changing these digests.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.0.1 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.0.1 -n plugin-br-pix-indirect-btg
```
