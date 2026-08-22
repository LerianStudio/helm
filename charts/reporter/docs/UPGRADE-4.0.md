# Helm Upgrade from v3.2.0 to v4.0.0

# Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. RabbitMQ bootstrap app user renamed from "plugin" to "reporter"](#1-rabbitmq-bootstrap-app-user-renamed-from-plugin-to-reporter)
  - [2. CORS configuration no longer has a chart default](#2-cors-configuration-no-longer-has-a-chart-default)
- **[Features](#features)**
  - [3. Lerian Common Helm Library Integration](#3-lerian-common-helm-library-integration)
  - [4. Global Configuration Masks](#4-global-configuration-masks)
  - [5. Datastore Connection Masks](#5-datastore-connection-masks)
  - [6. Object Storage Mask](#6-object-storage-mask)
  - [7. Service Discovery, Multi-Tenant, Streaming, Observability Masks](#7-service-discovery-multi-tenant-streaming-observability-masks)
- **[Configuration Reference](#configuration-reference)**
- **[Known Gotchas (Field-Verified)](#known-gotchas-field-verified)**
- **[Migration Guide](#migration-guide)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Breaking Changes

### 1. RabbitMQ bootstrap app user renamed from "plugin" to "reporter"

The chart's native RabbitMQ bootstrap Job (`externalRabbitmqDefinitions.enabled: true`) previously created a generic `plugin` user for the application to authenticate with. It is now named `reporter`, matching the component.

**What changed:**

| Setting | v3.2.0 | v4.0.0 |
|---------|--------|--------|
| Bootstrap-created RabbitMQ username | `plugin` | `reporter` |
| `secrets.RABBITMQ_DEFAULT_USER` default | `"plugin"` | `"reporter"` |
| `externalRabbitmqDefinitions.appCredentials.pluginPassword` | (this field) | renamed to `appCredentials.reporterPassword` |

**Why this matters:**

If you have an existing v3.2.0 install with the bootstrap Job enabled, the RabbitMQ user your app actually authenticates as will change from `plugin` to `reporter` on upgrade. The chart's bootstrap Job is idempotent and will provision the new `reporter` user automatically, but:

- If you set `secrets.RABBITMQ_DEFAULT_USER` explicitly to `"plugin"` in your values, update it to `"reporter"` (or remove the override to pick up the new default).
- If you set `externalRabbitmqDefinitions.appCredentials.pluginPassword`, rename the key to `reporterPassword`.
- The old `plugin` RabbitMQ user is **not** deleted automatically — if you no longer need it, remove it manually via the RabbitMQ management API/UI.

**What operators need to do:**

```yaml
# Before (v3.2.0)
secrets:
  RABBITMQ_DEFAULT_USER: "plugin"
externalRabbitmqDefinitions:
  appCredentials:
    pluginPassword: "..."

# After (v4.0.0)
secrets:
  RABBITMQ_DEFAULT_USER: "reporter"   # or omit to use the new default
externalRabbitmqDefinitions:
  appCredentials:
    reporterPassword: "..."
```

### 2. CORS configuration no longer has a chart default

`common.configmap.CORS_ALLOWED_ORIGINS` (and `_METHODS`/`_HEADERS`) previously defaulted to a wildcard (`"*"`). There is no longer a chart default for any of the three.

**Why this matters:**

The application's own production config validation requires `CORS_ALLOWED_ORIGINS` to be a real, non-wildcard value when `ENV_NAME=production`. A wildcard default was effectively unsafe (and unused, since there is no browser-facing frontend consuming this API), so it was removed rather than left in place.

**What operators need to do:**

Set a real value explicitly if you're in production:

```yaml
common:
  configmap:
    CORS_ALLOWED_ORIGINS: "https://your-real-consumer.example.com"
```

If nothing calls this API cross-origin, any non-empty, non-wildcard value satisfies the app's validation (e.g. a placeholder like `"https://reporter.internal"`).

# Features

### 3. Lerian Common Helm Library Integration

This release introduces the `lerian-common-helm` library chart (pinned to `2.0.0`) as a dependency, providing shared templates and configuration masks — the same pattern already adopted by `plugin-access-manager`, `midaz`, and other Lerian charts.

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.0.0"
    repository: "oci://ghcr.io/lerianstudio"
```

Your existing configuration continues to work without modification — native `common.configmap.<KEY>` / `manager.configmap.<KEY>` / `worker.configmap.<KEY>` values always win over any mask.

### 4. Global Configuration Masks

A new top-level `global` block lets you set environment-wide defaults once instead of duplicating them across the `manager` and `worker` surfaces:

```yaml
global:
  cloud: ""
  datastores: {}
  objectStorage: {}
  env: {}
  observability: {}
  auth: {}
  multiTenant: {}
  streaming: {}
  serviceDiscovery: {}
```

**Precedence (highest to lowest):** native `configmap.<KEY>` > dedicated `datastores`/`objectStorage` block > global mask > `global.cloud` topology preset > chart default.

### 5. Datastore Connection Masks

PostgreSQL (direct-query datasource), MongoDB, Redis/Valkey, and RabbitMQ connection parameters can now be configured once via `global.datastores`:

| Setting | v3.2.0 Location | v4.0.0 Location |
|---------|----------------|-----------------|
| PostgreSQL host/port/user/ssl | `common.configmap.DATASOURCE_ONBOARDING_*` | `global.datastores.postgres.*` |
| MongoDB host/port/user/params | `common.configmap.MONGO_*` | `global.datastores.mongo.*` |
| Redis host/tls/caCert | `common.configmap.REDIS_*` | `global.datastores.redis.*` |
| RabbitMQ host/port/scheme/amqpPort | `common.configmap.RABBITMQ_*` | `global.datastores.broker.*` |

```yaml
global:
  cloud: "aws"   # activates postgres.ssl=require, redis.tls=true, broker.scheme=amqps/amqpPort=5671
  datastores:
    postgres:
      host: "my-rds-instance.sa-east-1.rds.amazonaws.com"
      user: "reporter"
    redis:
      host: "my-elasticache.sa-east-1.cache.amazonaws.com:6379"
      caCert: "<base64 Amazon Root CA1 — see Known Gotchas below>"
    broker:
      host: "my-amazonmq.sa-east-1.on.aws"
```

If you don't configure the masks, the chart continues to use the bundled in-cluster MongoDB/Valkey/RabbitMQ subcharts with the same defaults as v3.2.0.

### 6. Object Storage Mask

S3/SeaweedFS connection parameters are now resolved through `global.objectStorage.s3` (non-secret fields only — access keys stay in `secrets.OBJECT_STORAGE_ACCESS_KEY_ID`/`_SECRET_KEY`):

```yaml
global:
  objectStorage:
    s3:
      endpoint: "https://s3.sa-east-1.amazonaws.com"   # client-supplied — the mask cannot infer this
      region: "sa-east-1"
      bucket: "my-bucket"
      usePathStyle: "false"
      disableSSL: "false"
```

### 7. Service Discovery, Multi-Tenant, Streaming, Observability Masks

`global.observability`, `global.auth`, `global.multiTenant`, and `global.streaming` all follow the same `enabled`-gated pattern (see Configuration Reference). `global.env` is a separate mask with a single `name` field (no `enabled` gate — it single-sources `ENV_NAME`). `global.serviceDiscovery` remains an open/untyped block — reporter's Consul wiring uses a different contract (`.envFlat`) with no dedicated field set to close against.

# Configuration Reference

```yaml
global:
  cloud: ""                       # aws | gcp | azure
  env:
    name: "production"
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth:4000"
  multiTenant:
    enabled: false
  streaming:
    enabled: false
    brokers: ""
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"
```

# Known Gotchas (Field-Verified)

The following were found while running a real `global.cloud: "aws"` install against a managed AmazonMQ/DocumentDB/ElastiCache topology and a plain (non-TLS) in-cluster OTel collector. They are operational pitfalls, not template-diff changes.

### Non-TLS OTel collector requires an explicit double opt-in

If your OTel collector doesn't terminate TLS on its OTLP receiver (e.g. a plain in-cluster `otel-collector-lerian` agent), you need **both**:

```yaml
common:
  configmap:
    OTEL_INSECURE_EXPORTER: "true"    # the OTel SDK client: don't attempt a TLS handshake
    ALLOW_INSECURE_OTEL: "local collector has no TLS"   # the app's own production safety check
```

Setting only one of the two still fails: `OTEL_INSECURE_EXPORTER` alone still trips the app's production validation (`insecure exporter detected in "production" environment`), and `ALLOW_INSECURE_OTEL` alone leaves the OTel client attempting (and failing) a TLS handshake against a plaintext port.

### RabbitMQ bootstrap user needs `administrator` tags

The application itself — not just the bootstrap Job — authenticates against the RabbitMQ management API with the `reporter` user's credentials for its own startup health check (`RABBITMQ_HEALTH_CHECK_URL`). A `reporter` user with no tags (or a lesser tag like `monitoring`, untested) fails that health check with `401 Unauthorized` and the pod never becomes ready. The bootstrap Job sets `administrator` tags for this reason — don't strip it if you're managing the user outside the chart's bootstrap Job.

### `RABBITMQ_HEALTH_CHECK_URL` now mirrors the broker's TLS scheme

Previously hardcoded to `http://`, it's now derived from the same `global.datastores.broker.scheme` mask as `RABBITMQ_URI` (`amqp` → `http`, `amqps` → `https`). A managed broker over TLS (AmazonMQ) needs no extra configuration for this — it's automatic once `global.cloud: "aws"` or an explicit `scheme: "amqps"` is set. Override with `common.configmap.RABBITMQ_HEALTH_CHECK_URL` if your management API's TLS state genuinely differs from your AMQP TLS state.

### Bootstrap Job installs `jq` at runtime

The RabbitMQ bootstrap Job's `curlimages/curl` image doesn't ship `jq`; the Job runs `apk add --no-cache jq` once at start to safely JSON-encode the generated password. This requires the Job's pod to reach the Alpine package mirror — if your cluster has no outbound internet access, mirror the Alpine repos internally or pre-bake a custom image.

# Migration Guide

1. If you have the RabbitMQ bootstrap Job enabled (`externalRabbitmqDefinitions.enabled: true`), rename `appCredentials.pluginPassword` → `appCredentials.reporterPassword` and update `secrets.RABBITMQ_DEFAULT_USER` to `"reporter"` (or remove the override).
2. Set `common.configmap.CORS_ALLOWED_ORIGINS` to a real value if `ENV_NAME=production` (previously implicit via the wildcard default).
3. (Optional) Migrate duplicated `common.configmap.DATASOURCE_ONBOARDING_*` / `MONGO_*` / `REDIS_*` / `RABBITMQ_*` values into `global.datastores.*` for a single source of truth.
4. (Optional) Migrate `common.configmap.ENABLE_TELEMETRY` / `MULTI_TENANT_ENABLED` / `STREAMING_ENABLED` into their respective `global.*.enabled` masks.

For steps 3–4: after moving a value into a `global.*` mask, render the chart (`helm template` or `helm diff upgrade`) and confirm the derived output matches expectations, **then remove the old `common.configmap.<KEY>` / `manager.configmap.<KEY>` / `worker.configmap.<KEY>` override** — a native key always wins over its mask, so leaving both in place silently keeps the old value active and makes the migration a no-op.

Existing configuration not touched by the above continues to work unchanged — native `configmap.<KEY>` values always take precedence over any mask.

# Preview changes before upgrading

> **Important:** Pass your values file (`-f values.yaml`) or `--reuse-values` explicitly on every command below. A plain `helm upgrade`/`helm diff upgrade` with no values source falls back to the chart's bare defaults, not your existing release's values — this would revert any customization (datastores, secrets, replica counts, ...) already in place.

```bash
helm diff upgrade reporter oci://ghcr.io/lerianstudio/reporter-helm --version 4.0.0 -n reporter -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade reporter oci://ghcr.io/lerianstudio/reporter-helm --version 4.0.0 -n reporter -f values.yaml
```
