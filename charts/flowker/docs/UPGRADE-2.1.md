# Helm Upgrade from v2.0.x to v2.1.x
## Topics
- **[Overview](#overview)**- **[Version changes](#version-changes)**- **[Configuration changes](#configuration-changes)**- **[Template changes](#template-changes)**- **[Migration steps](#migration-steps)**- **[Preview changes before upgrading](#preview-changes-before-upgrading)**- **[Command to upgrade](#command-to-upgrade)**

## Overview
This guide covers the `flowker` chart upgrade from `2.0.0` to `2.1.0-beta.6`. It was generated retroactively from the chart history and focuses on minor version changes; patch-only releases are intentionally ignored.

Because this is a minor upgrade, the expected path is an in-place Helm upgrade after reviewing new values and changed defaults.

## Version changes

| Field | Previous | Current |
|-------|----------|---------|
| Chart version | `2.0.0` | `2.1.0-beta.6` |
| App version | `1.0.0` | `1.0.0` |

## Configuration changes

### Added values

```yaml
flowker.configmap.AUDIT_DB_HOST: ""
flowker.configmap.AUDIT_DB_NAME: "flowker_audit"
flowker.configmap.AUDIT_DB_PORT: "5432"
flowker.configmap.AUDIT_DB_SSL_MODE: "disable"
flowker.configmap.AUDIT_DB_USER: "flowker_audit"
flowker.configmap.AUDIT_MIGRATIONS_PATH: "/migrations"
flowker.configmap.DEPLOYMENT_MODE: "local"
flowker.configmap.FAULT_INJECTION_ENABLED: "false"
flowker.configmap.MULTI_TENANT_ALLOW_INSECURE_HTTP: "false"
flowker.configmap.MULTI_TENANT_CACHE_TTL_SEC: "120"
flowker.configmap.MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"
flowker.configmap.MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: "30"
flowker.configmap.MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "30"
flowker.configmap.MULTI_TENANT_ENABLED: "false"
flowker.configmap.MULTI_TENANT_IDLE_TIMEOUT_SEC: "300"
flowker.configmap.MULTI_TENANT_MAX_TENANT_POOLS: "100"
flowker.configmap.MULTI_TENANT_REDIS_HOST: ""
flowker.configmap.MULTI_TENANT_REDIS_PORT: "6379"
flowker.configmap.MULTI_TENANT_REDIS_TLS: "false"
flowker.configmap.MULTI_TENANT_TIMEOUT: "30"
flowker.configmap.MULTI_TENANT_URL: ""
flowker.configmap.PLUGIN_AUTH_ADDRESS: ""
flowker.configmap.PLUGIN_AUTH_ENABLED: "false"
flowker.configmap.SKIP_LIB_COMMONS_TELEMETRY: "false"
flowker.configmap.SSRF_ALLOW_PRIVATE: "false"
flowker.secrets.AUDIT_DB_PASSWORD: "lerian"
flowker.secrets.MONGO_TLS_CA_CERT: ""
flowker.secrets.MONGO_URI: "mongodb://flowker:lerian@flowker-mongodb:27017/flowker?authSource=flowker"
flowker.secrets.MULTI_TENANT_REDIS_PASSWORD: ""
flowker.secrets.MULTI_TENANT_SERVICE_API_KEY: ""
```

### Removed values

```yaml
flowker.configmap.MONGO_APP_USER: "flowker"
flowker.configmap.MONGO_CONNECT_TIMEOUT_MS: "10000"
flowker.configmap.MONGO_HOST: "flowker-mongodb"
flowker.configmap.MONGO_MAX_IDLE_TIME_MS: "60000"
flowker.configmap.MONGO_MIN_POOL_SIZE: "5"
flowker.configmap.MONGO_PORT: "27017"
flowker.configmap.MONGO_SOCKET_TIMEOUT_MS: "30000"
flowker.configmap.MONGO_URI: "mongodb://flowker:lerian@flowker-mongodb:27017/flowker?authSource=admin"
flowker.secrets.MONGO_APP_PASSWORD: "lerian"
```

### Changed operational values

```yaml
# flowker.configmap.MONGO_MAX_POOL_SIZE
#   previous: "10"
#   current:  "20"
# flowker.configmap.SERVER_ADDRESS
#   previous: ":4000"
#   current:  ":4021"
# flowker.configmap.SERVER_PORT
#   previous: "4000"
#   current:  "4021"
# flowker.configmap.SWAGGER_HOST
#   previous: ":4000"
#   current:  ":4021"
# flowker.service.port
#   previous: 4000
#   current:  4021
```

## Template changes

### Added files

- No chart files added.

### Removed files

- No chart files removed.

### Modified files

- `charts/flowker/CHANGELOG.md`
- `charts/flowker/Chart.yaml`
- `charts/flowker/README.md`
- `charts/flowker/templates/configmap.yaml`
- `charts/flowker/templates/deployment.yaml`
- `charts/flowker/templates/secrets.yaml`
- `charts/flowker/values-template.yaml`
- `charts/flowker/values.yaml`

## Migration steps

1. Read this guide and compare your custom values against `charts/flowker/values.yaml`.
2. Remove values that no longer exist in the chart before running the upgrade.
3. Add any required new values for your environment, especially secrets, configmaps, probes, ingress, and service settings.
4. Render the chart locally with your production values and review the manifest diff.
5. Apply the upgrade in a controlled environment before production.

## Preview changes before upgrading

```bash
helm diff upgrade flowker ./charts/flowker \
  --namespace <namespace> \
  --values <your-values.yaml>
```

## Command to upgrade

```bash
helm upgrade flowker ./charts/flowker \
  --namespace <namespace> \
  --values <your-values.yaml>
```
