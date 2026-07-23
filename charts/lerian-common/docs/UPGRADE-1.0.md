# Helm Upgrade from v0.x to v1.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Features](#features)**
  - [1. Service Discovery Environment Variables](#1-service-discovery-environment-variables)
  - [2. Streaming Environment Variables](#2-streaming-environment-variables)
  - [3. Multi-Tenant Environment Variables](#3-multi-tenant-environment-variables)
  - [4. Auth Environment Variables](#4-auth-environment-variables)
  - [5. Datastore Mask Resolver](#5-datastore-mask-resolver)
  - [6. Dependency Helpers](#6-dependency-helpers)
  - [7. Deployment Pod-Spec Fragments](#7-deployment-pod-spec-fragments)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v1.0.0 is the **initial release** of a shared Helm library chart for the Lerian product suite. This is a **library chart** (type: `library`) that renders nothing on its own — it provides reusable template helpers consumed by product charts via `{{ include "lerian-common.helper" . }}`.

**What this chart does:**

- Centralizes duplicated logic across product charts (service discovery, streaming, multi-tenant, auth, datastore configuration)
- Provides environment variable contract helpers that read from a shared `global.*` values block
- Offers reusable deployment fragments (scheduling, probes, secrets) to reduce boilerplate
- Enables operators to declare environment-wide infrastructure settings **once** at the umbrella level instead of repeating them in every product chart

**Who should use this chart:**

- Operators managing Lerian product charts in an umbrella/GitOps deployment
- Chart maintainers refactoring product charts to consume shared helpers

**Backward compatibility:**

Every helper is designed to be **render-equivalent** when adopted: with `global.*` blocks absent, helpers fall back to existing component values, producing identical output. Adopting this library is a refactor for chart maintainers, not a breaking change for operators.

## Breaking Changes

**None.** This is the initial release (v0.0.0 → v1.0.0). The chart did not exist before v1.0.0.

If you are an operator, you do not need to install or upgrade this chart directly unless you are:

1. A chart maintainer refactoring a product chart to consume `lerian-common` helpers
2. Managing an umbrella chart that declares the shared `global.*` contract

## Features

### 1. Service Discovery Environment Variables

The `lerian-common.serviceDiscovery.env` helper emits environment variables for the **lib-service-discovery** integration (Consul-based service discovery).

**Environment variables emitted:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SD_ENABLED` | `false` | Enable service discovery for this component |
| `SD_ADDRESS` | `""` | Service discovery server address (e.g. `consul.prod:443`) |
| `SD_TLS` | `false` | Enable TLS for service discovery connection |
| `SD_TLS_SKIP_VERIFY` | `false` | Skip TLS certificate verification |
| `SD_WORKLOAD` | `""` | Workload isolation key (provider and consumer must match) |
| `SD_PREFER_VIEW` | `external` | Preferred view for service resolution (`internal` or `external`) |
| `SD_INTERNAL_SCHEME` | `http` | Scheme for internal service URLs |
| `SD_EXTERNAL_PORT` | `443` | Port for external service URLs (emitted only when component has ingress) |

**Configuration block (umbrella `values.yaml`):**

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: false
    workload: "production"
    preferView: external
    internalScheme: http
    externalPort: 443
```

**Precedence:**

Component-level `configmap.<KEY>` > `global.serviceDiscovery.<field>` > helper default

**Usage in product charts:**

Product chart maintainers include this helper in their ConfigMap template:

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.serviceDiscovery.env" (dict "context" $ "configmap" .Values.myapp.configmap) | nindent 2 }}
```

### 2. Streaming Environment Variables

The `lerian-common.streaming.env` helper emits environment variables for **RedPanda/Kafka streaming** integration.

**Environment variables emitted:**

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAMING_ENABLED` | `false` | Enable streaming for this component |
| `STREAMING_BROKERS` | `""` | Kafka/RedPanda broker addresses (e.g. `redpanda.prod:9092`) |
| `STREAMING_TLS_ENABLED` | `false` | Enable TLS for broker connections |
| `STREAMING_SASL_MECHANISM` | `""` | SASL mechanism (e.g. `SCRAM-SHA-256`) |
| `STREAMING_SASL_USERNAME` | `""` | SASL username |

> **Important:** `STREAMING_SASL_PASSWORD` and `STREAMING_TLS_CA_CERT` are **secrets** and must be set per component under `.secrets`, never in `global.streaming`.

**Configuration block (umbrella `values.yaml`):**

```yaml
global:
  streaming:
    brokers: "redpanda.prod.example.com:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "lerian-user"
```

**Precedence:**

Component-level `configmap.<KEY>` > `global.streaming.<field>` > helper default

**Usage in product charts:**

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.streaming.env" (dict "context" $ "configmap" .Values.myapp.configmap) | nindent 2 }}
```

### 3. Multi-Tenant Environment Variables

The `lerian-common.multiTenant.env` helper emits environment variables for **multi-tenancy** (tenant-manager and Redis).

**Environment variables emitted:**

| Variable | Default | Description |
|----------|---------|-------------|
| `MULTI_TENANT_ENABLED` | `false` | Enable multi-tenant mode for this component |
| `MULTI_TENANT_URL` | `""` | Tenant-manager service base URL |
| `MULTI_TENANT_REDIS_HOST` | `""` | Redis host for tenant cache |
| `MULTI_TENANT_REDIS_PORT` | `6379` | Redis port |
| `MULTI_TENANT_REDIS_TLS` | `false` | Enable TLS for Redis connection |

**Configuration block (umbrella `values.yaml`):**

```yaml
global:
  multiTenant:
    url: "http://tenant-manager.prod.svc.cluster.local"
    redisHost: "redis-mt.prod.svc.cluster.local"
    redisPort: "6379"
    redisTls: "false"
```

**Precedence:**

Component-level `configmap.MULTI_TENANT_*` > `global.multiTenant.<field>` > helper default

**Usage in product charts:**

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.multiTenant.env" (dict "context" $ "configmap" .Values.myapp.configmap) | nindent 2 }}
```

### 4. Auth Environment Variables

The `lerian-common.auth.env` helper emits environment variables for **plugin-access-manager** authentication.

**Environment variables emitted:**

| Variable | Default | Description |
|----------|---------|-------------|
| `PLUGIN_AUTH_ENABLED` | `false` | Enable auth plugin for this component |
| `PLUGIN_AUTH_HOST` or `PLUGIN_AUTH_ADDRESS` | `""` | Auth service host (key name varies per product) |

> **Note:** The host environment variable key differs per product. Ledger uses `PLUGIN_AUTH_HOST`, CRM uses `PLUGIN_AUTH_ADDRESS`. The caller passes `hostKey` to specify which key to emit.

**Configuration block (umbrella `values.yaml`):**

```yaml
global:
  auth:
    enabled: true
    host: "auth.prod.svc.cluster.local"
```

**Precedence:**

Component-level `configmap.<hostKey>` > `global.auth.<field>` > helper default

**Usage in product charts:**

```yaml
# templates/configmap.yaml (ledger)
data:
  {{- include "lerian-common.auth.env" (dict "context" $ "configmap" .Values.ledger.configmap "hostKey" "PLUGIN_AUTH_HOST") | nindent 2 }}
```

```yaml
# templates/configmap.yaml (crm)
data:
  {{- include "lerian-common.auth.env" (dict "context" $ "configmap" .Values.crm.configmap "hostKey" "PLUGIN_AUTH_ADDRESS") | nindent 2 }}
```

### 5. Datastore Mask Resolver

The `lerian-common.datastore.value` helper resolves datastore connection fields from an operator-friendly "mask" instead of requiring operators to set product-specific environment variable keys.

**Problem solved:**

Instead of setting `DB_ONBOARDING_HOST`, `DB_FEES_HOST`, `DB_CRM_HOST` separately, operators declare `postgres.host` once (shared) or per-product (dedicated).

**Deploy modes:**

- **SHARED:** `global.datastores.<type>.<field>` — all products use one instance
- **DEDICATED:** `<product>.datastores.<type>.<field>` — each product has its own instance

**Supported datastore types:**

- `postgres`
- `mongo`
- `redis`
- `redisMt` (multi-tenant Redis)
- `broker` (RabbitMQ)
- Custom roles (e.g. `ledger`, `crm`)

**Supported fields (shared across modules):**

- `host`
- `replicaHost`
- `user`
- `port`
- `ssl`
- `params`

> **Note:** Per-module fields like `database` or `name` remain native (not masked).

**Precedence:**

Native configmap key > dedicated (`<product>.datastores`) > shared (`global.datastores`) > default

**Configuration example (umbrella `values.yaml`):**

```yaml
# Shared PostgreSQL (all products)
global:
  datastores:
    postgres:
      host: "postgres.prod.svc.cluster.local"
      port: "5432"
      user: "lerian"
      ssl: "require"

# Dedicated MongoDB for CRM
crm:
  datastores:
    mongo:
      host: "mongo-crm.prod.svc.cluster.local"
      port: "27017"
      user: "crm-user"
```

**Usage in product charts:**

```yaml
# templates/configmap.yaml
data:
  DB_ONBOARDING_HOST: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" .Values.onboarding.configmap "type" "postgres" "field" "host" "nativeKey" "DB_ONBOARDING_HOST" "default" "") | quote }}
  DB_ONBOARDING_PORT: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" .Values.onboarding.configmap "type" "postgres" "field" "port" "nativeKey" "DB_ONBOARDING_PORT" "default" "5432") | quote }}
```

### 6. Dependency Helpers

The library provides two helpers for managing Bitnami-style subchart dependencies (PostgreSQL, Valkey, MongoDB, RabbitMQ, SeaweedFS).

#### `lerian-common.dependency.fullname`

Generates the collapse-aware subchart resource name (honors `nameOverride`, `fullnameOverride`, and release-name collapse).

**Inputs:**

- `chartName`: subchart name (e.g. `postgresql`)
- `chartValues`: subchart values map (e.g. `.Values.postgresql`)
- `context`: root context (`$`)

**Usage in product charts:**

```yaml
# templates/_helpers.tpl
{{- define "myapp.postgresql.fullname" -}}
{{- include "lerian-common.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" .) -}}
{{- end -}}
```

#### `lerian-common.infraSecretRef`

Generates a container `env:` entry (secretKeyRef) that sources an infrastructure password from the subchart's Secret (or its `existingSecret` override).

**Inputs:**

- `context`: root context (`$`)
- `subchart`: subchart name (e.g. `postgresql`)
- `key`: secret key (e.g. `password`)
- `envName`: container environment variable name (e.g. `DB_PASSWORD`)

**Usage in product charts:**

```yaml
# templates/deployment.yaml
env:
  {{- include "lerian-common.infraSecretRef" (dict "context" $ "subchart" "postgresql" "key" "password" "envName" "DB_PASSWORD") | nindent 10 }}
```

**Before (v0.0.0):**

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "myapp.postgresql.fullname" . }}
        key: password
```

**After (v1.0.0):**

```yaml
env:
  {{- include "lerian-common.infraSecretRef" (dict "context" $ "subchart" "postgresql" "key" "password" "envName" "DB_PASSWORD") | nindent 10 }}
```

### 7. Deployment Pod-Spec Fragments

The library provides reusable helpers for common Deployment pod-spec blocks that are byte-identical across ~51 workloads.

#### `lerian-common.scheduling`

Emits `nodeSelector`, `affinity`, and `tolerations` blocks.

**Usage in product charts:**

```yaml
# templates/deployment.yaml
spec:
  template:
    spec:
      {{- if or .Values.myapp.nodeSelector .Values.myapp.affinity .Values.myapp.tolerations }}
      {{- include "lerian-common.scheduling" .Values.myapp | nindent 6 }}
      {{- end }}
```

#### `lerian-common.imagePullSecrets`

Emits the `imagePullSecrets` block.

**Usage in product charts:**

```yaml
# templates/deployment.yaml
spec:
  template:
    spec:
      {{- with .Values.myapp.imagePullSecrets }}
      {{- include "lerian-common.imagePullSecrets" . | nindent 6 }}
      {{- end }}
```

#### `lerian-common.deploymentStrategy`

Emits the `strategy:` block (type + optional `rollingUpdate`).

**Inputs:**

- `type`: strategy type (e.g. `RollingUpdate`, `Recreate`)
- `maxSurge`: max surge value
- `maxUnavailable`: max unavailable value

**Usage in product charts:**

```yaml
# templates/deployment.yaml (flat deploymentUpdate shape)
spec:
  {{- include "lerian-common.deploymentStrategy" (dict "type" .Values.myapp.deploymentUpdate.type "maxSurge" .Values.myapp.deploymentUpdate.maxSurge "maxUnavailable" .Values.myapp.deploymentUpdate.maxUnavailable) | nindent 2 }}
```

```yaml
# templates/deployment.yaml (nested deploymentStrategy shape)
spec:
  {{- include "lerian-common.deploymentStrategy" (dict "type" .Values.myapp.deploymentStrategy.type "maxSurge" .Values.myapp.deploymentStrategy.rollingUpdate.maxSurge "maxUnavailable" .Values.myapp.deploymentStrategy.rollingUpdate.maxUnavailable) | nindent 2 }}
```

#### `lerian-common.httpProbe`

Emits one HTTP probe block (`readinessProbe`, `livenessProbe`, or `startupProbe`).

**Inputs:**

- `kind`: probe kind (`readinessProbe`, `livenessProbe`, `startupProbe`)
- `probe`: component probe values map (e.g. `.Values.myapp.readinessProbe`)
- `port`: service port
- `path`: probe path
- `initialDelay`: initial delay seconds (default)
- `period`: period seconds (default)
- `timeout`: timeout seconds (default)
- `success`: success threshold (default)
- `failure`: failure threshold (default)

**Usage in product charts:**

```yaml
# templates/deployment.yaml
containers:
  - name: myapp
    {{- include "lerian-common.httpProbe" (dict "kind" "readinessProbe" "probe" .Values.myapp.readinessProbe "port" .Values.myapp.service.port "path" "/readyz" "initialDelay" 10 "period" 5 "timeout" 1 "success" 1 "failure" 3) | nindent 10 }}
    {{- include "lerian-common.httpProbe" (dict "kind" "livenessProbe" "probe" .Values.myapp.livenessProbe "port" .Values.myapp.service.port "path" "/health" "initialDelay" 5 "period" 5 "timeout" 1 "success" 1 "failure" 3) | nindent 10 }}
```

## Configuration Reference

The `lerian-common` chart has **no values of its own** (it is a library chart). The `values.yaml` file documents the **shared `global.*` contract** that operators declare once at the umbrella level.

**Full umbrella `values.yaml` example:**

```yaml
global:
  # Service Discovery (Consul)
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: false
    workload: "production"
    preferView: external
    internalScheme: http
    externalPort: 443

  # Streaming (RedPanda/Kafka)
  streaming:
    brokers: "redpanda.prod.example.com:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "lerian-user"
    # STREAMING_SASL_PASSWORD and STREAMING_TLS_CA_CERT are secrets — set per component

  # Multi-tenant (tenant-manager + Redis)
  multiTenant:
    url: "http://tenant-manager.prod.svc.cluster.local"
    redisHost: "redis-mt.prod.svc.cluster.local"
    redisPort: "6379"
    redisTls: "false"

  # Auth (plugin-access-manager)
  auth:
    enabled: true
    host: "auth.prod.svc.cluster.local"

  # Datastores (shared across all products)
  datastores:
    postgres:
      host: "postgres.prod.svc.cluster.local"
      port: "5432"
      user: "lerian"
      ssl: "require"
    redis:
      host: "redis.prod.svc.cluster.local"
      port: "6379"
    mongo:
      host: "mongo.prod.svc.cluster.local"
      port: "27017"
      user: "lerian"
    broker:
      host: "rabbitmq.prod.svc.cluster.local"
      port: "5672"
      user: "lerian"

# Per-product dedicated datastores (optional)
ledger:
  datastores:
    postgres:
      host: "postgres-ledger.prod.svc.cluster.local"
      port: "5432"
      user: "ledger-user"

crm:
  datastores:
    mongo:
      host: "mongo-crm.prod.svc.cluster.local"
      port: "27017"
      user: "crm-user"
```

**Configuration flags:**

| Block | Field | Default | Description |
|-------|-------|---------|-------------|
| `global.serviceDiscovery` | `address` | `""` | Service discovery server address (required when `SD_ENABLED=true`) |
| `global.serviceDiscovery` | `tls` | `false` | Enable TLS for service discovery |
| `global.serviceDiscovery` | `tlsSkipVerify` | `false` | Skip TLS certificate verification |
| `global.serviceDiscovery` | `workload` | `""` | Workload isolation key |
| `global.serviceDiscovery` | `preferView` | `external` | Preferred view (`internal` or `external`) |
| `global.serviceDiscovery` | `internalScheme` | `http` | Scheme for internal URLs |
| `global.serviceDiscovery` | `externalPort` | `443` | Port for external URLs |
| `global.streaming` | `brokers` | `""` | Kafka/RedPanda broker addresses (required when `STREAMING_ENABLED=true`) |
| `global.streaming` | `tlsEnabled` | `false` | Enable TLS for broker connections |
| `global.streaming` | `saslMechanism` | `""` | SASL mechanism (e.g. `SCRAM-SHA-256`) |
| `global.streaming` | `saslUsername` | `""` | SASL username |
| `global.multiTenant` | `url` | `""` | Tenant-manager base URL |
| `global.multiTenant` | `redisHost` | `""` | Redis host for tenant cache |
| `global.multiTenant` | `redisPort` | `6379` | Redis port |
| `global.multiTenant` | `redisTls` | `false` | Enable TLS for Redis |
| `global.auth` | `enabled` | `false` | Enable auth plugin |
| `global.auth` | `host` | `""` | Auth service host |
| `global.datastores.<type>` | `host` | `""` | Datastore host |
| `global.datastores.<type>` | `port` | varies | Datastore port |
| `global.datastores.<type>` | `user` | `""` | Datastore user |
| `global.datastores.<type>` | `ssl` | `""` | SSL mode (PostgreSQL) |
| `global.datastores.<type>` | `params` | `""` | Additional connection parameters |

## Migration Steps

### For Operators (Umbrella Deployments)

If you manage Lerian product charts via an umbrella chart and want to adopt the shared `global.*` contract:

1. **Add `lerian-common` as a dependency** to your umbrella `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 1.0.0
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Declare the `global.*` contract** in your umbrella `values.yaml` (see [Configuration Reference](#configuration-reference) for the full example).

4. **Ensure product charts consume the helpers.** If you are using product charts that have already adopted `lerian-common`, no further action is required. If not, coordinate with chart maintainers to refactor product charts.

5. **Upgrade the umbrella chart:**

```bash
helm upgrade my-umbrella . -n lerian --values values.yaml
```

### For Chart Maintainers (Product Charts)

If you maintain a Lerian product chart and want to refactor it to consume `lerian-common` helpers:

1. **Add `lerian-common` as a dependency** to your product chart's `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 1.0.0
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Refactor templates** to use the helpers (see [Features](#features) for usage examples).

4. **Test render equivalence** (ensure output is byte-identical for existing users):

```bash
helm template my-chart . --values test-values.yaml > before.yaml
# (after refactor)
helm template my-chart . --values test-values.yaml > after.yaml
diff before.yaml after.yaml
```

5. **Document the refactor** in your product chart's CHANGELOG (note: adopting `lerian-common` is **not** a breaking change for operators if render-equivalent).

### For Standalone Deployments

If you deploy a single product chart without an umbrella:

**No action required.** The `lerian-common` helpers are backward-compatible: with `global.*` blocks absent, they fall back to existing component values, producing identical output.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.0.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of adopting `lerian-common`, run `helm diff` on the **product charts** that consume it.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.0.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, add it as a dependency in your umbrella or product chart's `Chart.yaml` and run `helm dependency update`.
