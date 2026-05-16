# Helm Upgrade from v1.x to v2.x
## Topics
- **[Overview](#overview)**- **[Version changes](#version-changes)**- **[Configuration changes](#configuration-changes)**- **[Breaking changes to review](#breaking-changes-to-review)**- **[Template changes](#template-changes)**- **[Migration steps](#migration-steps)**- **[Preview changes before upgrading](#preview-changes-before-upgrading)**- **[Command to upgrade](#command-to-upgrade)**

## Overview
This guide covers the `tracer` chart upgrade from `1.0.0` to `2.0.0-beta.6`. It was generated retroactively from the chart history and focuses on major version changes; patch-only releases are intentionally ignored.

Because this is a major upgrade, review all removed values, renamed templates, and changed defaults before applying it to production.

## Version changes

| Field | Previous | Current |
|-------|----------|---------|
| Chart version | `1.0.0` | `2.0.0-beta.6` |
| App version | `1.0.0` | `1.0.0` |

## Configuration changes

### Added values

```yaml
tracer.configmap.MULTI_TENANT_ALLOW_INSECURE_HTTP: "false"
tracer.configmap.MULTI_TENANT_CACHE_TTL_SEC: "120"
tracer.configmap.MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"
tracer.configmap.MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: "30"
tracer.configmap.MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "30"
tracer.configmap.MULTI_TENANT_ENABLED: "false"
tracer.configmap.MULTI_TENANT_IDLE_TIMEOUT_SEC: "300"
tracer.configmap.MULTI_TENANT_MAX_TENANT_POOLS: "100"
tracer.configmap.MULTI_TENANT_REDIS_HOST: ""
tracer.configmap.MULTI_TENANT_REDIS_PORT: "6379"
tracer.configmap.MULTI_TENANT_REDIS_TLS: "true"
tracer.configmap.MULTI_TENANT_TIMEOUT: "30"
tracer.configmap.MULTI_TENANT_URL: ""
tracer.configmap.PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local.:4000"
tracer.secrets.API_KEY: ""
```

### Removed values

```yaml
tracer.configmap.CEL_CACHE_MAX_SIZE: "1000"
tracer.configmap.CLEANUP_RETENTION_DAYS: "90"
tracer.configmap.PLUGIN_AUTH_HOST: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local.:4000"
tracer.secrets.API_KEY_SECRET: ""
```

### Changed operational values

```yaml
# tracer.configmap.SERVER_ADDRESS
#   previous: ":8080"
#   current:  ":4020"
# tracer.configmap.SERVER_PORT
#   previous: "8080"
#   current:  "4020"
# tracer.configmap.SWAGGER_HOST
#   previous: ":8080"
#   current:  ":4020"
# tracer.service.port
#   previous: 8080
#   current:  4020
```

## Breaking changes to review

The following values were removed and should be deleted from custom values files before the upgrade:

```yaml
tracer.configmap.CEL_CACHE_MAX_SIZE: "1000"
tracer.configmap.CLEANUP_RETENTION_DAYS: "90"
tracer.configmap.PLUGIN_AUTH_HOST: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local.:4000"
tracer.secrets.API_KEY_SECRET: ""
```

## Template changes

### Added files

- No chart files added.

### Removed files

- No chart files removed.

### Modified files

- `charts/tracer/Chart.yaml`
- `charts/tracer/README.md`
- `charts/tracer/templates/configmap.yaml`
- `charts/tracer/templates/deployment.yaml`
- `charts/tracer/templates/secrets.yaml`
- `charts/tracer/values-template.yaml`
- `charts/tracer/values.yaml`

## Migration steps

1. Read this guide and compare your custom values against `charts/tracer/values.yaml`.
2. Remove values that no longer exist in the chart before running the upgrade.
3. Add any required new values for your environment, especially secrets, configmaps, probes, ingress, and service settings.
4. Render the chart locally with your production values and review the manifest diff.
5. Apply the upgrade in a controlled environment before production.

## Preview changes before upgrading

```bash
helm diff upgrade tracer ./charts/tracer \
  --namespace <namespace> \
  --values <your-values.yaml>
```

## Command to upgrade

```bash
helm upgrade tracer ./charts/tracer \
  --namespace <namespace> \
  --values <your-values.yaml>
```
