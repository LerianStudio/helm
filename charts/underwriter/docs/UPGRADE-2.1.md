# Helm Upgrade from v2.0.x to v2.1.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Chart version bump to 2.1.0-beta.3](#1-chart-version-bump-to-210-beta3)
  - [2. PostgreSQL database key rename: POSTGRES_DB -> POSTGRES_NAME](#2-postgresql-database-key-rename-postgres_db---postgres_name)
  - [3. PostgreSQL read replica configuration](#3-postgresql-read-replica-configuration)
  - [4. Redis timeout keys aligned to duration strings](#4-redis-timeout-keys-aligned-to-duration-strings)
  - [5. Auth replaced by Plugin Auth (Access Manager)](#5-auth-replaced-by-plugin-auth-access-manager)
  - [6. Multi-tenant support added](#6-multi-tenant-support-added)
  - [7. RabbitMQ messaging support added](#7-rabbitmq-messaging-support-added)
  - [8. Transactional outbox support added](#8-transactional-outbox-support-added)
  - [9. Tiered rate limiting and circuit breaker](#9-tiered-rate-limiting-and-circuit-breaker)
  - [10. Configurable readiness and liveness probes](#10-configurable-readiness-and-liveness-probes)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `underwriter` chart upgrade from `2.0.0` to `2.1.0-beta.3`. The minor version adds multi-tenant support, RabbitMQ messaging, the transactional outbox pattern, a PostgreSQL read-replica option, tiered rate limiting, and probe overrides. It also renames a few existing keys and replaces the legacy `AUTH_*` block with the Plugin Auth integration. The application version is unchanged.

| Field | v2.0.x | v2.1.x |
|-------|--------|--------|
| Chart version | `2.0.0` | `2.1.0-beta.3` |
| App version | `1.0.0` | `1.0.0` |

All new features default to `disabled`, so existing single-tenant deployments will continue to work after the upgrade once renamed keys are corrected.

## Features

### 1. Chart version bump to 2.1.0-beta.3

The chart version moves from `2.0.0` to `2.1.0-beta.3`. The application image tag is unchanged.

```yaml
# Chart.yaml
version: 2.1.0-beta.3
appVersion: "1.0.0"
```

### 2. PostgreSQL database key rename: POSTGRES_DB -> POSTGRES_NAME

The PostgreSQL database name key has been renamed for consistency with the replica configuration.

| Setting | v2.0.x | v2.1.x |
|---------|--------|--------|
| `underwriter.configmap.POSTGRES_DB` | `"underwriter"` | removed |
| `underwriter.configmap.POSTGRES_NAME` | n/a | `"underwriter"` |

```yaml
underwriter:
  configmap:
    POSTGRES_HOST: "underwriter-postgresql-primary"
    POSTGRES_PORT: "5432"
    POSTGRES_NAME: "underwriter"
    POSTGRES_USER: "underwriter"
    POSTGRES_SSLMODE: "disable"
```

Rename `POSTGRES_DB` to `POSTGRES_NAME` in any custom values file.

### 3. PostgreSQL read replica configuration

A new optional read-replica block has been added. When unset, the replica falls back to the primary. The replica password defaults to the primary password when empty.

```yaml
underwriter:
  configmap:
    POSTGRES_REPLICA_HOST: ""
    POSTGRES_REPLICA_PORT: ""
    POSTGRES_REPLICA_NAME: ""
    POSTGRES_REPLICA_USER: ""
    POSTGRES_REPLICA_SSLMODE: ""
  secrets:
    POSTGRES_REPLICA_PASSWORD: ""
```

### 4. Redis timeout keys aligned to duration strings

The Redis timeout keys have been renamed to use Go duration strings instead of millisecond integers. Additional pool and retry knobs have been added.

| Setting | v2.0.x | v2.1.x |
|---------|--------|--------|
| `underwriter.configmap.REDIS_DIAL_TIMEOUT_MS` | `"5000"` | removed |
| `underwriter.configmap.REDIS_READ_TIMEOUT_MS` | `"3000"` | removed |
| `underwriter.configmap.REDIS_WRITE_TIMEOUT_MS` | `"3000"` | removed |
| `underwriter.configmap.REDIS_DIAL_TIMEOUT` | n/a | `"5s"` |
| `underwriter.configmap.REDIS_READ_TIMEOUT` | n/a | `"3s"` |
| `underwriter.configmap.REDIS_WRITE_TIMEOUT` | n/a | `"3s"` |
| `underwriter.configmap.REDIS_POOL_TIMEOUT` | n/a | `"4s"` |
| `underwriter.configmap.REDIS_MAX_RETRIES` | n/a | `"3"` |
| `underwriter.configmap.REDIS_MIN_RETRY_BACKOFF` | n/a | `"8ms"` |
| `underwriter.configmap.REDIS_MAX_RETRY_BACKOFF` | n/a | `"512ms"` |
| `underwriter.configmap.REDIS_TLS` | n/a | `"false"` |
| `underwriter.configmap.REDIS_MASTER_NAME` | n/a | `""` |
| `underwriter.secrets.REDIS_CA_CERT` | n/a | `""` |

```yaml
underwriter:
  configmap:
    REDIS_HOST: "underwriter-valkey-primary:6379"
    REDIS_TLS: "false"
    REDIS_DIAL_TIMEOUT: "5s"
    REDIS_READ_TIMEOUT: "3s"
    REDIS_WRITE_TIMEOUT: "3s"
    REDIS_POOL_TIMEOUT: "4s"
    REDIS_MAX_RETRIES: "3"
    REDIS_MIN_RETRY_BACKOFF: "8ms"
    REDIS_MAX_RETRY_BACKOFF: "512ms"
```

Rename the three `*_MS` keys to their duration-string equivalents in custom values files.

### 5. Auth replaced by Plugin Auth (Access Manager)

The legacy `AUTH_*` block has been removed. Authentication now flows through the Plugin Auth (Access Manager) integration, matching other Lerian services.

| Setting | v2.0.x | v2.1.x |
|---------|--------|--------|
| `underwriter.configmap.AUTH_ENABLED` | `"false"` | removed |
| `underwriter.configmap.AUTH_SERVICE_ADDRESS` | present | removed |
| `underwriter.configmap.DEFAULT_TENANT_SLUG` | `"default"` | removed |
| `underwriter.secrets.AUTH_JWT_SECRET` | present | removed |
| `underwriter.configmap.PLUGIN_AUTH_ENABLED` | n/a | `"false"` |
| `underwriter.configmap.PLUGIN_AUTH_HOST` | n/a | added |

```yaml
underwriter:
  configmap:
    PLUGIN_AUTH_ENABLED: "false"
    PLUGIN_AUTH_HOST: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local.:4000"
```

Remove `AUTH_ENABLED`, `AUTH_SERVICE_ADDRESS`, `DEFAULT_TENANT_SLUG`, and the `AUTH_JWT_SECRET` secret from any custom values file. If you relied on the built-in auth, enable Plugin Auth instead.

### 6. Multi-tenant support added

A new optional multi-tenant mode has been added. When `MULTI_TENANT_ENABLED=true`, the application requires a Tenant Manager URL and a Redis registry for tenant connection pools. The manager API key and optional Redis password are provided via secrets.

```yaml
underwriter:
  configmap:
    MULTI_TENANT_ENABLED: "false"
    MULTI_TENANT_URL: ""
    MULTI_TENANT_REDIS_HOST: ""
    MULTI_TENANT_REDIS_PORT: "6379"
    MULTI_TENANT_REDIS_TLS: "false"
    MULTI_TENANT_MAX_TENANT_POOLS: "100"
    MULTI_TENANT_IDLE_TIMEOUT_SEC: "300"
    MULTI_TENANT_TIMEOUT: "30"
    MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"
    MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: "30"
    MULTI_TENANT_CACHE_TTL_SEC: "120"
    MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "30"
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: ""
    MULTI_TENANT_REDIS_PASSWORD: ""
```

> **Note:** Multi-tenant mode is disabled by default. Existing single-tenant deployments are unaffected.

### 7. RabbitMQ messaging support added

A new optional RabbitMQ publisher has been added. When `RABBITMQ_ENABLED=true`, the application publishes domain events to the configured exchange/queue. Publisher confirms, recovery backoff, and health-check allow-list controls are exposed.

```yaml
underwriter:
  configmap:
    RABBITMQ_ENABLED: "false"
    RABBITMQ_HOST: ""
    RABBITMQ_PORT_AMQP: "5672"
    RABBITMQ_PORT_HOST: "15672"
    RABBITMQ_VHOST: "/"
    RABBITMQ_DEFAULT_USER: ""
    RABBITMQ_EXCHANGE: "underwriter.events"
    RABBITMQ_QUEUE: "underwriter.events.queue"
    RABBITMQ_URL: ""
    RABBITMQ_HEALTH_CHECK_URL: ""
    RABBITMQ_HEALTH_CHECK_ALLOWED_HOSTS: ""
    RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS: "false"
    RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK: "false"
    RABBITMQ_ALLOW_INSECURE_TLS: "false"
    RABBITMQ_PUBLISHER_CONFIRM_TIMEOUT_MS: "5000"
    RABBITMQ_PUBLISHER_MAX_RECOVERIES: "5"
    RABBITMQ_PUBLISHER_RECOVERY_INITIAL_MS: "100"
    RABBITMQ_PUBLISHER_RECOVERY_MAX_MS: "5000"
  secrets:
    RABBITMQ_DEFAULT_PASS: ""
```

### 8. Transactional outbox support added

A new outbox dispatcher has been added for reliable event publishing. When `OUTBOX_ENABLED=true`, the application writes events to the `OUTBOX_TABLE_NAME` table and dispatches them in batches.

```yaml
underwriter:
  configmap:
    OUTBOX_ENABLED: "false"
    OUTBOX_TABLE_NAME: "outbox_events"
    OUTBOX_BATCH_SIZE: "100"
    OUTBOX_DISPATCH_INTERVAL_SEC: "5"
    OUTBOX_PROCESSING_TIMEOUT_SEC: "30"
    OUTBOX_MAX_DISPATCH_ATTEMPTS: "5"
    OUTBOX_MAX_FAILED_PER_BATCH: "10"
    OUTBOX_RETRY_WINDOW_SEC: "60"
    OUTBOX_PUBLISH_BACKOFF_MS: "100"
    OUTBOX_PUBLISH_MAX_ATTEMPTS: "3"
    OUTBOX_PRIORITY_EVENT_TYPES: ""
    OUTBOX_INCLUDE_TENANT_METRICS: "false"
    OUTBOX_ALLOW_EMPTY_TENANT: "false"
```

### 9. Tiered rate limiting and circuit breaker

The rate-limiter has been extended with aggressive and relaxed tiers, and a circuit breaker has been added. The `RATE_LIMIT_EXPIRY_SEC` key has been renamed to `RATE_LIMIT_WINDOW_SEC`.

| Setting | v2.0.x | v2.1.x |
|---------|--------|--------|
| `underwriter.configmap.RATE_LIMIT_EXPIRY_SEC` | `"60"` | removed |
| `underwriter.configmap.RATE_LIMIT_WINDOW_SEC` | n/a | `"60"` |
| `underwriter.configmap.AGGRESSIVE_RATE_LIMIT_MAX` | n/a | `"10"` |
| `underwriter.configmap.AGGRESSIVE_RATE_LIMIT_WINDOW_SEC` | n/a | `"60"` |
| `underwriter.configmap.RELAXED_RATE_LIMIT_MAX` | n/a | `"1000"` |
| `underwriter.configmap.RELAXED_RATE_LIMIT_WINDOW_SEC` | n/a | `"60"` |
| `underwriter.configmap.CIRCUIT_BREAKER_ENABLED` | n/a | `"true"` |

```yaml
underwriter:
  configmap:
    RATE_LIMIT_ENABLED: "true"
    RATE_LIMIT_MAX: "100"
    RATE_LIMIT_WINDOW_SEC: "60"
    AGGRESSIVE_RATE_LIMIT_MAX: "10"
    AGGRESSIVE_RATE_LIMIT_WINDOW_SEC: "60"
    RELAXED_RATE_LIMIT_MAX: "1000"
    RELAXED_RATE_LIMIT_WINDOW_SEC: "60"
    CIRCUIT_BREAKER_ENABLED: "true"
```

Rename `RATE_LIMIT_EXPIRY_SEC` to `RATE_LIMIT_WINDOW_SEC` in any custom values file.

### 10. Configurable readiness and liveness probes

The chart now exposes `readinessProbe` and `livenessProbe` blocks under `underwriter`. Both default to empty maps and fall back to chart defaults; provide a map to override individual fields.

```yaml
underwriter:
  readinessProbe: {}
  livenessProbe: {}
```

Additional minor additions include `DEPLOYMENT_MODE`, `CORS_EXPOSE_HEADERS`, `CORS_ALLOW_CREDENTIALS`, `MAX_PAGINATION_LIMIT`, `MAX_PAGINATION_MONTH_DATE_RANGE`, `AWS_REGION`, `EXAMPLE_STATUS_PROVIDER_MODE`, `SWAGGER_*` documentation knobs, and `SERVER_TLS_CERT_FILE` / `SERVER_TLS_KEY_FILE` secret entries. The `OTEL_RESOURCE_SERVICE_VERSION` key was removed and is now auto-derived from the image tag in the template.

## Configuration Changes

The following table summarizes the renamed and removed keys that require action on existing values files.

| Setting | v2.0.x | v2.1.x | Change |
|---------|--------|--------|--------|
| `underwriter.configmap.POSTGRES_DB` | `"underwriter"` | removed | Renamed to `POSTGRES_NAME` |
| `underwriter.configmap.REDIS_DIAL_TIMEOUT_MS` | `"5000"` | removed | Renamed to `REDIS_DIAL_TIMEOUT` (`"5s"`) |
| `underwriter.configmap.REDIS_READ_TIMEOUT_MS` | `"3000"` | removed | Renamed to `REDIS_READ_TIMEOUT` (`"3s"`) |
| `underwriter.configmap.REDIS_WRITE_TIMEOUT_MS` | `"3000"` | removed | Renamed to `REDIS_WRITE_TIMEOUT` (`"3s"`) |
| `underwriter.configmap.AUTH_ENABLED` | `"false"` | removed | Replaced by `PLUGIN_AUTH_ENABLED` |
| `underwriter.configmap.AUTH_SERVICE_ADDRESS` | present | removed | Replaced by `PLUGIN_AUTH_HOST` |
| `underwriter.configmap.DEFAULT_TENANT_SLUG` | `"default"` | removed | Removed |
| `underwriter.configmap.RATE_LIMIT_EXPIRY_SEC` | `"60"` | removed | Renamed to `RATE_LIMIT_WINDOW_SEC` |
| `underwriter.configmap.OTEL_RESOURCE_SERVICE_VERSION` | `"1.0.0"` | removed | Auto-derived from image tag |
| `underwriter.secrets.AUTH_JWT_SECRET` | present | removed | Removed with `AUTH_*` block |

All other v2.1 entries are new and default to a safe-off value, so existing deployments do not require action on them.

## Migration Steps

This upgrade requires manual changes to any custom `values.yaml` because keys have been renamed or removed. No data migration is required.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Update your custom values file:
   - Rename `POSTGRES_DB` to `POSTGRES_NAME`.
   - Rename `REDIS_DIAL_TIMEOUT_MS`, `REDIS_READ_TIMEOUT_MS`, `REDIS_WRITE_TIMEOUT_MS` to their duration-string equivalents.
   - Remove `AUTH_ENABLED`, `AUTH_SERVICE_ADDRESS`, `DEFAULT_TENANT_SLUG`, and `AUTH_JWT_SECRET`. If you relied on built-in auth, enable Plugin Auth instead.
   - Rename `RATE_LIMIT_EXPIRY_SEC` to `RATE_LIMIT_WINDOW_SEC`.
   - Remove `OTEL_RESOURCE_SERVICE_VERSION` if previously overridden.
3. Optionally enable new features: multi-tenant, RabbitMQ, outbox dispatcher, PostgreSQL read replica, tiered rate limiting, custom probes.
4. Render the chart locally with your production values and review the manifest diff.
5. Apply the upgrade in a controlled environment before production.
6. Verify all pods are running and healthy after the upgrade.

```bash
kubectl get pods -n underwriter
```

7. Check service logs for any startup issues.

```bash
kubectl logs -n underwriter -l app.kubernetes.io/name=underwriter-helm --tail=50
```

> **Note:** The upgrade will trigger a rolling restart of the underwriter pods. Connections to PostgreSQL and Redis are re-established with the renamed configuration keys; missing renames will fail validation at boot.

## Preview changes before upgrading

```bash
helm diff upgrade underwriter oci://registry-1.docker.io/lerianstudio/underwriter-helm --version 2.1.0-beta.3 -n underwriter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade underwriter oci://registry-1.docker.io/lerianstudio/underwriter-helm --version 2.1.0-beta.3 -n underwriter
```
