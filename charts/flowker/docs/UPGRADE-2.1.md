# Helm Upgrade from v2.0.x to v2.1.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Default service port moved to 4021](#1-default-service-port-moved-to-4021)
  - [2. Mongo connection consolidated to `MONGO_URI`](#2-mongo-connection-consolidated-to-mongo_uri)
  - [3. Multi-tenant support (opt-in)](#3-multi-tenant-support-opt-in)
  - [4. Audit database configuration](#4-audit-database-configuration)
  - [5. Plugin Auth and SSRF / telemetry knobs](#5-plugin-auth-and-ssrf--telemetry-knobs)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `flowker` chart upgrade from `2.0.0` to `2.1.0-beta.6`. The application image (`appVersion: 1.0.0`) is unchanged, but the chart now reflects upstream environment-variable changes: the service port moves to `4021`, the Mongo connection collapses into a single `MONGO_URI`, and the chart exposes opt-in support for multi-tenant pools, an audit database, plugin-auth, SSRF protection, and lib-commons telemetry.

The upgrade is **not transparent**: the default port changes and the Mongo env-var surface changes. Read [Migration Steps](#migration-steps) before upgrading any environment that overrides those values.

## Features

### 1. Default service port moved to 4021

The chart default port moves from `4000` to `4021`, matching the upstream Flowker source convention.

| Setting | v2.0.0 | v2.1.0-beta.6 |
|---------|--------|---------------|
| `flowker.service.port` | `4000` | `4021` |
| `flowker.configmap.SERVER_ADDRESS` | `:4000` | `:4021` |
| `flowker.configmap.SERVER_PORT` | `4000` | `4021` |
| `flowker.configmap.SWAGGER_HOST` | `:4000` | `:4021` |

> **Note:** Any Ingress, Service, NetworkPolicy, or downstream client pinned to `4000` must be updated, or `flowker.service.port` must be pinned to `4000` in your values override.

### 2. Mongo connection consolidated to `MONGO_URI`

The previous chart exposed Mongo via discrete env vars (`MONGO_HOST`, `MONGO_PORT`, `MONGO_APP_USER`, `MONGO_APP_PASSWORD`, pool/timeout knobs). v2.1 collapses these into a single `MONGO_URI` secret plus optional TLS CA, aligning with how the Flowker application now reads its configuration.

Removed values:

```yaml
flowker.configmap.MONGO_APP_USER: "flowker"
flowker.configmap.MONGO_CONNECT_TIMEOUT_MS: "10000"
flowker.configmap.MONGO_HOST: "flowker-mongodb"
flowker.configmap.MONGO_MAX_IDLE_TIME_MS: "60000"
flowker.configmap.MONGO_MIN_POOL_SIZE: "5"
flowker.configmap.MONGO_PORT: "27017"
flowker.configmap.MONGO_SOCKET_TIMEOUT_MS: "30000"
flowker.secrets.MONGO_APP_PASSWORD: "lerian"
```

New values:

```yaml
flowker:
  secrets:
    MONGO_URI: "mongodb://flowker:lerian@flowker-mongodb:27017/flowker?authSource=flowker"
    MONGO_TLS_CA_CERT: ""
```

Note also that the Mongo URI default `authSource` changes from `admin` to `flowker`. Pool size now lives in a single knob:

| Setting | v2.0.0 | v2.1.0-beta.6 |
|---------|--------|---------------|
| `flowker.configmap.MONGO_MAX_POOL_SIZE` | `10` | `20` |

### 3. Multi-tenant support (opt-in)

The chart now ships configuration for the multi-tenant pool manager. Disabled by default; enable only if your deployment runs in multi-tenant mode.

```yaml
flowker:
  configmap:
    MULTI_TENANT_ENABLED: "false"
    MULTI_TENANT_URL: ""
    MULTI_TENANT_TIMEOUT: "30"
    MULTI_TENANT_CACHE_TTL_SEC: "120"
    MULTI_TENANT_IDLE_TIMEOUT_SEC: "300"
    MULTI_TENANT_MAX_TENANT_POOLS: "100"
    MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "30"
    MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"
    MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: "30"
    MULTI_TENANT_ALLOW_INSECURE_HTTP: "false"
    MULTI_TENANT_REDIS_HOST: ""
    MULTI_TENANT_REDIS_PORT: "6379"
    MULTI_TENANT_REDIS_TLS: "false"
  secrets:
    MULTI_TENANT_REDIS_PASSWORD: ""
    MULTI_TENANT_SERVICE_API_KEY: ""
```

### 4. Audit database configuration

A separate audit Postgres connection is now configurable, intended for the audit trail subsystem. Disabled in practice if `AUDIT_DB_HOST` is empty.

```yaml
flowker:
  configmap:
    AUDIT_DB_HOST: ""
    AUDIT_DB_PORT: "5432"
    AUDIT_DB_NAME: "flowker_audit"
    AUDIT_DB_USER: "flowker_audit"
    AUDIT_DB_SSL_MODE: "disable"
    AUDIT_MIGRATIONS_PATH: "/migrations"
  secrets:
    AUDIT_DB_PASSWORD: "lerian"
```

### 5. Plugin Auth and SSRF / telemetry knobs

New operational knobs:

```yaml
flowker:
  configmap:
    DEPLOYMENT_MODE: "local"
    PLUGIN_AUTH_ENABLED: "false"
    PLUGIN_AUTH_ADDRESS: ""
    FAULT_INJECTION_ENABLED: "false"
    SSRF_ALLOW_PRIVATE: "false"
    SKIP_LIB_COMMONS_TELEMETRY: "false"
```

## Configuration Changes

Summary of `values.yaml` impact:

| Category | Count |
|----------|-------|
| Added configmap keys | 21 |
| Added secret keys | 4 |
| Removed configmap keys | 8 |
| Removed secret keys | 1 |
| Changed defaults | 5 (port + pool size) |

Files touched in the chart between `2.0.0` and `2.1.0-beta.6`:

- `charts/flowker/Chart.yaml`
- `charts/flowker/values.yaml`
- `charts/flowker/values-template.yaml`
- `charts/flowker/templates/configmap.yaml`
- `charts/flowker/templates/secrets.yaml`
- `charts/flowker/templates/deployment.yaml`
- `charts/flowker/README.md`

## Migration Steps

1. **Audit your overrides for the legacy Mongo keys.** If you set any of `MONGO_HOST`, `MONGO_PORT`, `MONGO_APP_USER`, `MONGO_APP_PASSWORD`, or the Mongo timeout knobs, replace them with a single `flowker.secrets.MONGO_URI`. Confirm the `authSource` query parameter matches your deployment (default flips from `admin` to `flowker`).
2. **Decide on the service port.** If anything in your cluster (Ingress, Service consumers, NetworkPolicy, Istio rules) is pinned to `4000`, either pin `flowker.service.port: 4000` and the `SERVER_*`/`SWAGGER_HOST` values back to `:4000`, or update those downstream pins to `4021`.
3. **Leave multi-tenant disabled** unless you are intentionally enabling it. The defaults are inert (`MULTI_TENANT_ENABLED: "false"`).
4. **Leave the audit DB host empty** unless you are wiring a separate audit Postgres.
5. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
6. Run the upgrade and verify the rollout:

```bash
kubectl rollout status -n flowker deploy/flowker
kubectl get pods -n flowker
```

7. Check that the application is listening on the new port:

```bash
kubectl logs -n flowker -l app.kubernetes.io/name=flowker --tail=50
```

> **Note:** Because the default Service port changes, clients calling `flowker.<namespace>.svc.cluster.local:4000` will fail after the upgrade unless you pin the port back to `4000` in values.

## Preview changes before upgrading

```bash
helm diff upgrade flowker oci://registry-1.docker.io/lerianstudio/flowker-helm --version 2.1.0-beta.6 -n flowker
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade flowker oci://registry-1.docker.io/lerianstudio/flowker-helm --version 2.1.0-beta.6 -n flowker
```
