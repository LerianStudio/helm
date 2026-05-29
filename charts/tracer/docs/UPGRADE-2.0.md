# Helm Upgrade from v1.x to v2.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Chart version bump to 2.0.0-beta.6](#1-chart-version-bump-to-200-beta6)
  - [2. Default HTTP port aligned with source convention](#2-default-http-port-aligned-with-source-convention)
  - [3. Auth plugin variable rename: PLUGIN_AUTH_HOST -> PLUGIN_AUTH_ADDRESS](#3-auth-plugin-variable-rename-plugin_auth_host---plugin_auth_address)
  - [4. API key secret rename: API_KEY_SECRET -> API_KEY](#4-api-key-secret-rename-api_key_secret---api_key)
  - [5. Multi-tenant support added](#5-multi-tenant-support-added)
  - [6. Removed CEL cache and cleanup retention defaults](#6-removed-cel-cache-and-cleanup-retention-defaults)
  - [7. Configurable readiness and liveness probes](#7-configurable-readiness-and-liveness-probes)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `1.0.0` to `2.0.0-beta.6`. The major version bump reflects renamed configuration keys, a changed default service port, and the introduction of multi-tenant support. Review the renamed values and the new defaults before applying the upgrade to production.

The application version remains `1.0.0`.

| Field | v1.x | v2.x |
|-------|------|------|
| Chart version | `1.0.0` | `2.0.0-beta.6` |
| App version | `1.0.0` | `1.0.0` |

## Features

### 1. Chart version bump to 2.0.0-beta.6

The chart version moves from `1.0.0` to `2.0.0-beta.6`. The application image tag is unchanged.

```yaml
# Chart.yaml
version: 2.0.0-beta.6
appVersion: "1.0.0"
```

### 2. Default HTTP port aligned with source convention

The default HTTP port changes from `8080` to `4020` to match the tracer source convention (`Dockerfile` `EXPOSE 4020`, `.env.example`, `Dockerfile.dev`). The application reads `SERVER_ADDRESS` first and falls back to `SERVER_PORT`. Keep `service.port`, `SERVER_PORT`, `SERVER_ADDRESS`, and `SWAGGER_HOST` in sync when overriding.

| Setting | v1.x | v2.x |
|---------|------|------|
| `tracer.service.port` | `8080` | `4020` |
| `tracer.configmap.SERVER_PORT` | `"8080"` | `"4020"` |
| `tracer.configmap.SERVER_ADDRESS` | `":8080"` | `":4020"` |
| `tracer.configmap.SWAGGER_HOST` | `":8080"` | `":4020"` |

```yaml
tracer:
  service:
    type: ClusterIP
    port: 4020
  configmap:
    SERVER_PORT: "4020"
    SERVER_ADDRESS: ":4020"
    SWAGGER_HOST: ":4020"
```

If you have an existing deployment expecting `8080`, override `service.port`, `SERVER_PORT`, `SERVER_ADDRESS`, and `SWAGGER_HOST` in your environment values file to keep the legacy port.

### 3. Auth plugin variable rename: PLUGIN_AUTH_HOST -> PLUGIN_AUTH_ADDRESS

The auth plugin configuration key has been renamed for consistency with other plugin variables.

| Setting | v1.x | v2.x |
|---------|------|------|
| `tracer.configmap.PLUGIN_AUTH_HOST` | present | removed |
| `tracer.configmap.PLUGIN_AUTH_ADDRESS` | n/a | added |

```yaml
tracer:
  configmap:
    PLUGIN_AUTH_ENABLED: "false"
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local.:4000"
```

Remove `PLUGIN_AUTH_HOST` from any custom values file and replace it with `PLUGIN_AUTH_ADDRESS`.

### 4. API key secret rename: API_KEY_SECRET -> API_KEY

The secret key used by the API-key authentication path has been renamed. The application reads `$API_KEY` at runtime. The previous name `API_KEY_SECRET` was never read by the application and silently disabled API-key auth even when `API_KEY_ENABLED=true`.

| Setting | v1.x | v2.x |
|---------|------|------|
| `tracer.secrets.API_KEY_SECRET` | present | removed |
| `tracer.secrets.API_KEY` | n/a | added |

```yaml
tracer:
  secrets:
    DB_PASSWORD: "lerian"
    API_KEY: ""
```

If you rely on API-key authentication, move the value from `API_KEY_SECRET` to `API_KEY` before upgrading.

### 5. Multi-tenant support added

A new optional multi-tenant mode is available. When `MULTI_TENANT_ENABLED=true`, the application requires a Tenant Manager URL, a Redis registry for tenant connection pools, and a service API key. The chart also requires `PLUGIN_AUTH_ENABLED=true` and `API_KEY_ENABLED_ONLY_VALIDATION=false` when MT is enabled (enforced by the app at boot).

```yaml
tracer:
  configmap:
    MULTI_TENANT_ENABLED: "false"
    MULTI_TENANT_URL: ""
    MULTI_TENANT_ALLOW_INSECURE_HTTP: "false"
    MULTI_TENANT_REDIS_HOST: ""
    MULTI_TENANT_REDIS_PORT: "6379"
    MULTI_TENANT_REDIS_TLS: "true"
    MULTI_TENANT_MAX_TENANT_POOLS: "100"
    MULTI_TENANT_IDLE_TIMEOUT_SEC: "300"
    MULTI_TENANT_TIMEOUT: "30"
    MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"
    MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: "30"
    MULTI_TENANT_CACHE_TTL_SEC: "120"
    MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "30"
  secrets:
    # MULTI_TENANT_SERVICE_API_KEY: ""
    # MULTI_TENANT_REDIS_PASSWORD: ""
```

> **Note:** Multi-tenant mode is disabled by default. Existing single-tenant deployments are unaffected.

### 6. Removed CEL cache and cleanup retention defaults

Two unused configuration defaults have been removed from the chart.

| Setting | v1.x | v2.x |
|---------|------|------|
| `tracer.configmap.CEL_CACHE_MAX_SIZE` | `"1000"` | removed |
| `tracer.configmap.CLEANUP_RETENTION_DAYS` | `"90"` | removed |

Remove these keys from any custom values file before upgrading.

### 7. Configurable readiness and liveness probes

The chart now exposes `readinessProbe` and `livenessProbe` blocks under `tracer`. Both default to empty maps and fall back to chart defaults; provide a map to override individual fields.

```yaml
tracer:
  readinessProbe: {}
  livenessProbe: {}
```

## Configuration Changes

The following table summarizes all configuration changes:

| Setting | v1.x | v2.x | Change |
|---------|------|------|--------|
| `tracer.service.port` | `8080` | `4020` | Changed |
| `tracer.configmap.SERVER_PORT` | `"8080"` | `"4020"` | Changed |
| `tracer.configmap.SERVER_ADDRESS` | `":8080"` | `":4020"` | Changed |
| `tracer.configmap.SWAGGER_HOST` | `":8080"` | `":4020"` | Changed |
| `tracer.configmap.PLUGIN_AUTH_HOST` | present | removed | Renamed |
| `tracer.configmap.PLUGIN_AUTH_ADDRESS` | n/a | added | Renamed |
| `tracer.secrets.API_KEY_SECRET` | present | removed | Renamed |
| `tracer.secrets.API_KEY` | n/a | added | Renamed |
| `tracer.configmap.CEL_CACHE_MAX_SIZE` | `"1000"` | removed | Removed |
| `tracer.configmap.CLEANUP_RETENTION_DAYS` | `"90"` | removed | Removed |
| `tracer.configmap.MULTI_TENANT_*` | n/a | added | Added |
| `tracer.readinessProbe` | n/a | `{}` | Added |
| `tracer.livenessProbe` | n/a | `{}` | Added |

## Migration Steps

This upgrade requires manual changes to any custom `values.yaml` because keys have been renamed or removed.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Update your custom values file:
   - Rename `PLUGIN_AUTH_HOST` to `PLUGIN_AUTH_ADDRESS`.
   - Rename `API_KEY_SECRET` to `API_KEY`.
   - Remove `CEL_CACHE_MAX_SIZE` and `CLEANUP_RETENTION_DAYS`.
   - Decide whether to keep the new default port `4020` or pin the legacy port `8080` by overriding `service.port`, `SERVER_PORT`, `SERVER_ADDRESS`, and `SWAGGER_HOST`.
3. If adopting multi-tenant mode, set `MULTI_TENANT_ENABLED=true`, populate the required configmap and secret values, and confirm `PLUGIN_AUTH_ENABLED=true` and `API_KEY_ENABLED_ONLY_VALIDATION=false`.
4. Render the chart locally with your production values and review the manifest diff.
5. Apply the upgrade in a controlled environment before production.
6. Verify all pods are running and healthy after the upgrade.

```bash
kubectl get pods -n tracer
```

7. Check service logs for any startup issues.

```bash
kubectl logs -n tracer -l app.kubernetes.io/name=tracer-helm --tail=50
```

> **Note:** The default port change from `8080` to `4020` will trigger a rolling restart and change the in-cluster service port. Update any consumer that hard-codes the tracer port or pin the legacy port in your values file.

## Preview changes before upgrading

```bash
helm diff upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.0.0-beta.6 -n tracer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.0.0-beta.6 -n tracer
```
