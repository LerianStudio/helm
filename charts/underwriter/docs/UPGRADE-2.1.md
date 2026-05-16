# Helm Upgrade from v2.0.x to v2.1.x
## Topics
- **[Overview](#overview)**- **[Version changes](#version-changes)**- **[Configuration changes](#configuration-changes)**- **[Template changes](#template-changes)**- **[Migration steps](#migration-steps)**- **[Preview changes before upgrading](#preview-changes-before-upgrading)**- **[Command to upgrade](#command-to-upgrade)**

## Overview
This guide covers the `underwriter` chart upgrade from `2.0.0` to `2.1.0-beta.3`. It was generated retroactively from the chart history and focuses on minor version changes; patch-only releases are intentionally ignored.

Because this is a minor upgrade, the expected path is an in-place Helm upgrade after reviewing new values and changed defaults.

## Version changes

| Field | Previous | Current |
|-------|----------|---------|
| Chart version | `2.0.0` | `2.1.0-beta.3` |
| App version | `1.0.0` | `1.0.0` |

## Configuration changes

### Added values

```yaml
underwriter.configmap.AGGRESSIVE_RATE_LIMIT_MAX: "10"
underwriter.configmap.AGGRESSIVE_RATE_LIMIT_WINDOW_SEC: "60"
underwriter.configmap.AWS_REGION: ""
underwriter.configmap.CIRCUIT_BREAKER_ENABLED: "true"
underwriter.configmap.CORS_ALLOW_CREDENTIALS: "false"
underwriter.configmap.CORS_EXPOSE_HEADERS: ""
underwriter.configmap.DEPLOYMENT_MODE: "local"
underwriter.configmap.EXAMPLE_STATUS_PROVIDER_MODE: "healthy"
underwriter.configmap.MAX_PAGINATION_LIMIT: "100"
underwriter.configmap.MAX_PAGINATION_MONTH_DATE_RANGE: "12"
underwriter.configmap.MULTI_TENANT_CACHE_TTL_SEC: "120"
underwriter.configmap.MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"
underwriter.configmap.MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: "30"
underwriter.configmap.MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "30"
underwriter.configmap.MULTI_TENANT_ENABLED: "false"
underwriter.configmap.MULTI_TENANT_IDLE_TIMEOUT_SEC: "300"
underwriter.configmap.MULTI_TENANT_MAX_TENANT_POOLS: "100"
underwriter.configmap.MULTI_TENANT_REDIS_HOST: ""
underwriter.configmap.MULTI_TENANT_REDIS_PORT: "6379"
underwriter.configmap.MULTI_TENANT_REDIS_TLS: "false"
underwriter.configmap.MULTI_TENANT_TIMEOUT: "30"
underwriter.configmap.MULTI_TENANT_URL: ""
underwriter.configmap.OUTBOX_ALLOW_EMPTY_TENANT: "false"
underwriter.configmap.OUTBOX_BATCH_SIZE: "100"
underwriter.configmap.OUTBOX_DISPATCH_INTERVAL_SEC: "5"
underwriter.configmap.OUTBOX_ENABLED: "false"
underwriter.configmap.OUTBOX_INCLUDE_TENANT_METRICS: "false"
underwriter.configmap.OUTBOX_MAX_DISPATCH_ATTEMPTS: "5"
underwriter.configmap.OUTBOX_MAX_FAILED_PER_BATCH: "10"
underwriter.configmap.OUTBOX_PRIORITY_EVENT_TYPES: ""
underwriter.configmap.OUTBOX_PROCESSING_TIMEOUT_SEC: "30"
underwriter.configmap.OUTBOX_PUBLISH_BACKOFF_MS: "100"
underwriter.configmap.OUTBOX_PUBLISH_MAX_ATTEMPTS: "3"
underwriter.configmap.OUTBOX_RETRY_WINDOW_SEC: "60"
underwriter.configmap.OUTBOX_TABLE_NAME: "outbox_events"
underwriter.configmap.PLUGIN_AUTH_ENABLED: "false"
underwriter.configmap.PLUGIN_AUTH_HOST: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local.:4000"
underwriter.configmap.POSTGRES_NAME: "underwriter"
underwriter.configmap.POSTGRES_REPLICA_HOST: ""
underwriter.configmap.POSTGRES_REPLICA_NAME: ""
underwriter.configmap.POSTGRES_REPLICA_PORT: ""
underwriter.configmap.POSTGRES_REPLICA_SSLMODE: ""
underwriter.configmap.POSTGRES_REPLICA_USER: ""
underwriter.configmap.RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK: "false"
underwriter.configmap.RABBITMQ_ALLOW_INSECURE_TLS: "false"
underwriter.configmap.RABBITMQ_DEFAULT_USER: ""
underwriter.configmap.RABBITMQ_ENABLED: "false"
underwriter.configmap.RABBITMQ_EXCHANGE: "underwriter.events"
underwriter.configmap.RABBITMQ_HEALTH_CHECK_ALLOWED_HOSTS: ""
underwriter.configmap.RABBITMQ_HEALTH_CHECK_URL: ""
underwriter.configmap.RABBITMQ_HOST: ""
underwriter.configmap.RABBITMQ_PORT_AMQP: "5672"
underwriter.configmap.RABBITMQ_PORT_HOST: "15672"
underwriter.configmap.RABBITMQ_PUBLISHER_CONFIRM_TIMEOUT_MS: "5000"
underwriter.configmap.RABBITMQ_PUBLISHER_MAX_RECOVERIES: "5"
underwriter.configmap.RABBITMQ_PUBLISHER_RECOVERY_INITIAL_MS: "100"
underwriter.configmap.RABBITMQ_PUBLISHER_RECOVERY_MAX_MS: "5000"
underwriter.configmap.RABBITMQ_QUEUE: "underwriter.events.queue"
underwriter.configmap.RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS: "false"
underwriter.configmap.RABBITMQ_URL: ""
underwriter.configmap.RABBITMQ_VHOST: "/"
underwriter.configmap.RATE_LIMIT_WINDOW_SEC: "60"
underwriter.configmap.REDIS_DIAL_TIMEOUT: "5s"
underwriter.configmap.REDIS_MASTER_NAME: ""
underwriter.configmap.REDIS_MAX_RETRIES: "3"
underwriter.configmap.REDIS_MAX_RETRY_BACKOFF: "512ms"
underwriter.configmap.REDIS_MIN_RETRY_BACKOFF: "8ms"
underwriter.configmap.REDIS_POOL_TIMEOUT: "4s"
underwriter.configmap.REDIS_READ_TIMEOUT: "3s"
underwriter.configmap.REDIS_TLS: "false"
underwriter.configmap.REDIS_WRITE_TIMEOUT: "3s"
underwriter.configmap.RELAXED_RATE_LIMIT_MAX: "1000"
underwriter.configmap.RELAXED_RATE_LIMIT_WINDOW_SEC: "60"
underwriter.configmap.SWAGGER_BASE_PATH: "/"
underwriter.configmap.SWAGGER_DESCRIPTION: "Underwriter service"
underwriter.configmap.SWAGGER_HOST: ""
underwriter.configmap.SWAGGER_LEFT_DELIM: "{{"
underwriter.configmap.SWAGGER_RIGHT_DELIM: "}}"
underwriter.configmap.SWAGGER_SCHEMES: "https"
underwriter.configmap.SWAGGER_TITLE: "Underwriter API"
# ... 7 more entries
```

### Removed values

```yaml
underwriter.configmap.AUTH_ENABLED: "false"
underwriter.configmap.AUTH_SERVICE_ADDRESS: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local.:4000"
underwriter.configmap.DEFAULT_TENANT_SLUG: "default"
underwriter.configmap.OTEL_RESOURCE_SERVICE_VERSION: "1.0.0"
underwriter.configmap.POSTGRES_DB: "underwriter"
underwriter.configmap.RATE_LIMIT_EXPIRY_SEC: "60"
underwriter.configmap.REDIS_DIAL_TIMEOUT_MS: "5000"
underwriter.configmap.REDIS_READ_TIMEOUT_MS: "3000"
underwriter.configmap.REDIS_WRITE_TIMEOUT_MS: "3000"
underwriter.secrets.AUTH_JWT_SECRET: ""
```

### Changed operational values

_No image, env, secret, probe, ingress, service, port, or enablement changes detected in values.yaml._

## Template changes

### Added files

- No chart files added.

### Removed files

- No chart files removed.

### Modified files

- `charts/underwriter/Chart.yaml`
- `charts/underwriter/templates/configmap.yaml`
- `charts/underwriter/templates/deployment.yaml`
- `charts/underwriter/values.yaml`

## Migration steps

1. Read this guide and compare your custom values against `charts/underwriter/values.yaml`.
2. Remove values that no longer exist in the chart before running the upgrade.
3. Add any required new values for your environment, especially secrets, configmaps, probes, ingress, and service settings.
4. Render the chart locally with your production values and review the manifest diff.
5. Apply the upgrade in a controlled environment before production.

## Preview changes before upgrading

```bash
helm diff upgrade underwriter ./charts/underwriter \
  --namespace <namespace> \
  --values <your-values.yaml>
```

## Command to upgrade

```bash
helm upgrade underwriter ./charts/underwriter \
  --namespace <namespace> \
  --values <your-values.yaml>
```
