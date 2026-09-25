# Helm Upgrade from v1.3.0 to v1.3.1

## Topics ToC

- **[Fixes](#fixes)**
  - [1. Datastore Mask Resolver: Monolithic Chart Support](#1-datastore-mask-resolver-monolithic-chart-support)
  - [2. Multi-Tenant Environment Variables: Explicit False/Empty Value Handling](#2-multi-tenant-environment-variables-explicit-falseempty-value-handling)
  - [3. Service Discovery: External Endpoint Emission Logic](#3-service-discovery-external-endpoint-emission-logic)
  - [4. Service Discovery: Advanced Tuning Knobs Passthrough](#4-service-discovery-advanced-tuning-knobs-passthrough)
  - [5. Streaming Environment Variables: Explicit False/Empty Value Handling](#5-streaming-environment-variables-explicit-falseempty-value-handling)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Datastore Mask Resolver: Monolithic Chart Support

**What changed:**

The `lerian-common.datastore.value` helper now supports **monolithic parent charts** (e.g. Midaz) that declare per-component datastore masks at `<component>.datastores` instead of `.Values.datastores`.

**Why it matters:**

In v1.3.0, the helper assumed all product charts were **subcharts** with their own `.Values.datastores` block. Monolithic charts like Midaz that bundle multiple components (e.g. `ledger`, `crm`) in one chart could not use the datastore mask resolver because the helper always read from `.context.Values.datastores`, which in a monolithic chart is the parent's global block, not the per-component dedicated block.

v1.3.1 adds an optional `dedicated` input parameter that allows monolithic charts to pass the component-specific datastore map explicitly.

**Operational impact:**

> **Note:** This is a **backward-compatible fix**. Existing subchart deployments (where `.Values.datastores` is the product's own block) continue to work without changes.

For operators using **monolithic charts** (e.g. Midaz) that have adopted `lerian-common` v1.3.1:

- The chart maintainer will pass the component's dedicated datastore map explicitly via the `dedicated` parameter
- Operators can now declare per-component datastore overrides in the monolithic chart's `values.yaml` at `<component>.datastores.<type>.<field>`

**Configuration example (monolithic chart `values.yaml`):**

```yaml
# Midaz monolithic chart with per-component datastores
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

**Usage in monolithic chart templates:**

**Before (v1.3.0):**

```yaml
# Monolithic chart could not pass component-specific datastores
data:
  DB_LEDGER_HOST: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" .Values.ledger.configmap "type" "postgres" "field" "host") | quote }}
```

**After (v1.3.1):**

```yaml
# Monolithic chart passes component's dedicated datastores map explicitly
data:
  DB_LEDGER_HOST: {{ include "lerian-common.datastore.value" (dict "context" $ "dedicated" .Values.ledger.datastores "configmap" .Values.ledger.configmap "type" "postgres" "field" "host") | quote }}
```

**Precedence (unchanged):**

Native configmap key > `dedicated` (explicit or `.context.Values.datastores`) > `global.datastores` > default

### 2. Multi-Tenant Environment Variables: Explicit False/Empty Value Handling

**What changed:**

The `lerian-common.multiTenant.env` helper now resolves configuration values by **presence** (`hasKey`) instead of sprig's `default` function. This ensures that explicit `false`, `0`, or `""` values in `configmap.MULTI_TENANT_*` keys survive and are not overridden by global defaults.

**Why it matters:**

In v1.3.0, if an operator set `configmap.MULTI_TENANT_URL: ""` (explicitly empty) to disable the URL for a specific component, the helper would treat it as absent and fall back to `global.multiTenant.url`. This prevented operators from overriding a global value with an explicit empty/false value at the component level.

v1.3.1 fixes this by checking for key presence first, so an explicit `configmap.MULTI_TENANT_URL: ""` wins over the global value.

**Operational impact:**

> **Important:** This is a **backward-compatible fix**. Existing deployments where operators rely on the global fallback (by omitting the configmap key entirely) continue to work unchanged.

Operators who previously **could not** override a global multi-tenant setting with an explicit empty/false value at the component level can now do so.

**Configuration example:**

```yaml
# Umbrella values.yaml
global:
  multiTenant:
    url: "http://tenant-manager.prod.svc.cluster.local"
    redisHost: "redis-mt.prod.svc.cluster.local"
    redisPort: "6379"
    redisTls: "true"

# Component-level override: explicitly disable TLS for this component
myapp:
  configmap:
    MULTI_TENANT_REDIS_TLS: "false"  # v1.3.0: ignored, fell back to global "true"
                                      # v1.3.1: honored, emits "false"
```

**Before (v1.3.0):**

```yaml
# Component ConfigMap (v1.3.0 behavior)
data:
  MULTI_TENANT_REDIS_TLS: "true"  # Global value won, explicit "false" was ignored
```

**After (v1.3.1):**

```yaml
# Component ConfigMap (v1.3.1 behavior)
data:
  MULTI_TENANT_REDIS_TLS: "false"  # Explicit component value wins
```

**Affected environment variables:**

| Variable | Description |
|----------|-------------|
| `MULTI_TENANT_URL` | Tenant-manager service base URL |
| `MULTI_TENANT_REDIS_HOST` | Redis host for tenant cache |
| `MULTI_TENANT_REDIS_PORT` | Redis port |
| `MULTI_TENANT_REDIS_TLS` | Enable TLS for Redis connection |
| `MULTI_TENANT_SERVICE_NAME` | Service name for multi-tenant context |

### 3. Service Discovery: External Endpoint Emission Logic

**What changed:**

The `lerian-common.serviceDiscovery.env` helper now emits `SD_EXTERNAL_ADDRESS` and `SD_EXTERNAL_PORT` when **either** an Ingress host is configured **or** the operator supplies explicit legacy `configmap.SD_EXTERNAL_ADDRESS` / `configmap.SD_EXTERNAL_PORT` keys (on-prem deployments without Ingress).

**Why it matters:**

In v1.3.0, the helper only emitted the external endpoint when `.ingressHost` was non-empty. This prevented on-prem operators who manually set `configmap.SD_EXTERNAL_ADDRESS` (without an Ingress resource) from having the external endpoint emitted.

v1.3.1 fixes this by checking for the presence of legacy `configmap.SD_EXTERNAL_*` keys in addition to `.ingressHost`.

**Operational impact:**

> **Note:** This is a **backward-compatible fix**. Existing deployments with Ingress continue to work unchanged.

Operators who deploy on-prem **without Ingress** and manually set `configmap.SD_EXTERNAL_ADDRESS` / `configmap.SD_EXTERNAL_PORT` will now have the external endpoint emitted correctly.

**Configuration example (on-prem without Ingress):**

```yaml
# Component values.yaml (on-prem deployment)
myapp:
  configmap:
    SD_EXTERNAL_ADDRESS: "https://myapp.onprem.example.com"
    SD_EXTERNAL_PORT: "8443"
```

**Before (v1.3.0):**

```yaml
# Component ConfigMap (v1.3.0 behavior)
data:
  SD_ADDRESS: "consul.prod:443"
  SD_INTERNAL_ADDRESS: "myapp.prod.svc.cluster.local"
  SD_INTERNAL_PORT: "8080"
  # SD_EXTERNAL_ADDRESS and SD_EXTERNAL_PORT were omitted (no ingressHost)
```

**After (v1.3.1):**

```yaml
# Component ConfigMap (v1.3.1 behavior)
data:
  SD_ADDRESS: "consul.prod:443"
  SD_INTERNAL_ADDRESS: "myapp.prod.svc.cluster.local"
  SD_INTERNAL_PORT: "8080"
  SD_EXTERNAL_ADDRESS: "https://myapp.onprem.example.com"
  SD_EXTERNAL_PORT: "8443"
```

**Updated values.yaml documentation:**

| Setting | v1.3.0 | v1.3.1 |
|---------|---------|---------|
| `global.serviceDiscovery.externalPort` comment | `SD_EXTERNAL_PORT (emitted only when a component has an ingress host)` | `SD_EXTERNAL_PORT (emitted when a component has an ingress host OR sets legacy configmap.SD_EXTERNAL_*)` |

### 4. Service Discovery: Advanced Tuning Knobs Passthrough

**What changed:**

The `lerian-common.serviceDiscovery.env` helper now emits **advanced tuning knobs** when operators set them explicitly via legacy `configmap.SD_*` keys. These variables were previously undocumented and not emitted by the helper.

**Why it matters:**

Operators who need to tune service discovery timeouts or behavior (e.g. `SD_DIAL_TIMEOUT`, `SD_ALLOW_STALE`) could not use the helper in v1.3.0 because these keys were not passed through. They had to bypass the helper and set the ConfigMap data directly.

v1.3.1 adds passthrough support for these advanced keys, preserving backward-compatibility with the flat `configmap.SD_*` API.

**Operational impact:**

> **Note:** This is a **backward-compatible enhancement**. Existing deployments that do not set these keys continue to work unchanged (the variables are omitted when absent, keeping the ConfigMap clean).

Operators who need to tune service discovery behavior can now set these keys via `configmap.SD_*` and have them emitted by the helper.

**New environment variables (advanced tuning):**

| Variable | Default | Description |
|----------|---------|-------------|
| `SD_DIAL_TIMEOUT` | (omitted) | Dial timeout for service discovery connections |
| `SD_TLS_HANDSHAKE_TIMEOUT` | (omitted) | TLS handshake timeout |
| `SD_RESPONSE_HEADER_TIMEOUT` | (omitted) | Response header timeout |
| `SD_SEED_TIMEOUT` | (omitted) | Seed timeout for initial service discovery |
| `SD_WATCH_WAIT_TIME` | (omitted) | Watch wait time for service discovery updates |
| `SD_ALLOW_STALE` | (omitted) | Allow stale reads from service discovery |

**Configuration example:**

```yaml
# Component values.yaml (advanced tuning)
myapp:
  configmap:
    SD_DIAL_TIMEOUT: "5s"
    SD_TLS_HANDSHAKE_TIMEOUT: "10s"
    SD_ALLOW_STALE: "true"
```

**Before (v1.3.0):**

```yaml
# Component ConfigMap (v1.3.0 behavior)
data:
  SD_ADDRESS: "consul.prod:443"
  SD_INTERNAL_ADDRESS: "myapp.prod.svc.cluster.local"
  # Advanced tuning keys were not emitted
```

**After (v1.3.1):**

```yaml
# Component ConfigMap (v1.3.1 behavior)
data:
  SD_ADDRESS: "consul.prod:443"
  SD_INTERNAL_ADDRESS: "myapp.prod.svc.cluster.local"
  SD_DIAL_TIMEOUT: "5s"
  SD_TLS_HANDSHAKE_TIMEOUT: "10s"
  SD_ALLOW_STALE: "true"
```

> **Important:** These variables have **no global defaults** and are **not** part of the `global.serviceDiscovery` block. They are pure legacy configmap passthrough for advanced use cases. Omit them unless you have a specific tuning requirement.

### 5. Streaming Environment Variables: Explicit False/Empty Value Handling

**What changed:**

The `lerian-common.streaming.env` helper now resolves configuration values by **presence** (`hasKey`) instead of sprig's `default` function. This ensures that explicit `false`, `0`, or `""` values in `configmap.STREAMING_*` keys survive and are not overridden by global defaults.

Additionally, the helper now activates when **either** `global.streaming.brokers` **or** `configmap.STREAMING_BROKERS` is set (previously required `global.streaming.brokers`).

**Why it matters:**

In v1.3.0, if an operator set `configmap.STREAMING_TLS_ENABLED: false` (explicitly disable TLS) for a specific component, the helper would treat it as absent and fall back to `global.streaming.tlsEnabled`. This prevented operators from overriding a global value with an explicit empty/false value at the component level.

Additionally, on-prem operators who manually set `configmap.STREAMING_BROKERS` (without a global block) could not activate the helper.

v1.3.1 fixes both issues by checking for key presence first and allowing activation via legacy `configmap.STREAMING_BROKERS`.

**Operational impact:**

> **Important:** This is a **backward-compatible fix**. Existing deployments where operators rely on the global fallback (by omitting the configmap key entirely) continue to work unchanged.

Operators who previously **could not** override a global streaming setting with an explicit empty/false value at the component level can now do so.

**Configuration example:**

```yaml
# Umbrella values.yaml
global:
  streaming:
    brokers: "redpanda.prod:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"

# Component-level override: explicitly disable TLS for this component
myapp:
  configmap:
    STREAMING_TLS_ENABLED: "false"  # v1.3.0: ignored, fell back to global "true"
                                     # v1.3.1: honored, emits "false"
```

**Before (v1.3.0):**

```yaml
# Component ConfigMap (v1.3.0 behavior)
data:
  STREAMING_BROKERS: "redpanda.prod:9092"
  STREAMING_TLS_ENABLED: "true"  # Global value won, explicit "false" was ignored
```

**After (v1.3.1):**

```yaml
# Component ConfigMap (v1.3.1 behavior)
data:
  STREAMING_BROKERS: "redpanda.prod:9092"
  STREAMING_TLS_ENABLED: "false"  # Explicit component value wins
```

**Affected environment variables:**

| Variable | Description |
|----------|-------------|
| `STREAMING_BROKERS` | Kafka/RedPanda broker addresses |
| `STREAMING_TLS_ENABLED` | Enable TLS for broker connections |
| `STREAMING_SASL_MECHANISM` | SASL mechanism (e.g. `SCRAM-SHA-256`) |
| `STREAMING_SASL_USERNAME` | SASL username |
| `STREAMING_SASL_ALLOW_PLAINTEXT` | Allow plaintext SASL |
| `STREAMING_COMPRESSION` | Compression algorithm (e.g. `lz4`) |
| `STREAMING_REQUIRED_ACKS` | Required acks (e.g. `all`) |
| `STREAMING_BATCH_LINGER_MS` | Batch linger time in milliseconds |
| `STREAMING_IMPORTANT_EMIT_TIMEOUT_MS` | Emit timeout for important messages |
| `STREAMING_CLIENT_ID` | Client ID for streaming connection |
| `STREAMING_CLOUDEVENTS_SOURCE` | CloudEvents source identifier |

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.1 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v1.3.1, run `helm diff` on the **product charts** that consume it after updating their dependency to v1.3.1.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.1 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `1.3.1` and run `helm dependency update`, then upgrade the parent chart.
