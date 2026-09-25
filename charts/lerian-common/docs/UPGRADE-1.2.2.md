# Helm Upgrade from v1.2.1 to v1.2.2

## Topics ToC

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Service Discovery Legacy Configmap Support](#1-service-discovery-legacy-configmap-support)
  - [2. Streaming Legacy Configmap Support and New Configuration Fields](#2-streaming-legacy-configmap-support-and-new-configuration-fields)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v1.2.2 is a **patch release** that adds backward-compatibility support for legacy flat `configmap.*` overrides in the `serviceDiscovery.env` and `streaming.env` helpers, and introduces new streaming configuration fields for production tuning.

**What changed:**

- Both helpers now honor component-level `configmap.SD_*` and `configmap.STREAMING_*` keys as the highest-precedence source (mirroring the existing `multiTenant.env` behavior)
- New `global.streaming` fields for Kafka producer tuning: `saslAllowPlaintext`, `compression`, `requiredAcks`, `batchLingerMs`, `importantEmitTimeoutMs`

**Who should upgrade:**

- Operators managing Lerian product charts that consume `lerian-common` v1.2.1 and use the `serviceDiscovery.env` or `streaming.env` helpers
- Chart maintainers who need to support legacy flat configmap overrides alongside the new `global.*` contract

**Backward compatibility:**

This release is **fully backward-compatible**. Existing deployments that do not pass the `configmap` parameter to these helpers will render **byte-identical** output. The new streaming fields have safe defaults and are optional.

## Fixes

### 1. Service Discovery Legacy Configmap Support

The `lerian-common.serviceDiscovery.env` helper now accepts an optional `configmap` parameter. When a component's legacy `.configmap` map contains a `SD_*` key (e.g. `SD_ADDRESS`, `SD_TLS`), that flat value **wins** over the `global.serviceDiscovery.*` value.

**What changed:**

The helper's precedence order is now:

1. Component-level `configmap.SD_*` (highest)
2. `global.serviceDiscovery.*`
3. Helper default (lowest)

**Why it matters:**

Product charts that migrated to `lerian-common` but still support the legacy flat configmap API (e.g. `.Values.myapp.configmap.SD_ADDRESS`) can now pass that map to the helper. Operators who set overrides via the flat configmap will see those values take precedence over `global.serviceDiscovery.*`, preserving backward compatibility.

**Operational impact:**

> **Important:** This change is **opt-in** for chart maintainers. If a product chart does not pass the `configmap` parameter, the helper behaves identically to v1.2.1.

**Before (v1.2.1):**

The helper only read from `global.serviceDiscovery.*`:

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.serviceDiscovery.env" (dict "context" $ "name" "myapp" "namespace" .Release.Namespace "port" .Values.myapp.service.port "ingressHost" .Values.myapp.ingress.host) | nindent 2 }}
```

If an operator set `.Values.myapp.configmap.SD_ADDRESS`, it was **ignored** by the helper (the component had to emit it separately).

**After (v1.2.2):**

The helper accepts the component's `configmap` map:

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.serviceDiscovery.env" (dict "context" $ "name" "myapp" "namespace" .Release.Namespace "port" .Values.myapp.service.port "ingressHost" .Values.myapp.ingress.host "configmap" .Values.myapp.configmap) | nindent 2 }}
```

Now, if an operator sets:

```yaml
myapp:
  configmap:
    SD_ADDRESS: "consul-override.example.com:8500"
```

The helper emits `SD_ADDRESS: "consul-override.example.com:8500"` instead of the `global.serviceDiscovery.address` value.

**Environment variables affected:**

| Variable | Precedence (v1.2.2) |
|----------|---------------------|
| `SD_ADDRESS` | `configmap.SD_ADDRESS` > `global.serviceDiscovery.address` > `""` |
| `SD_TLS` | `configmap.SD_TLS` > `global.serviceDiscovery.tls` > `false` |
| `SD_TLS_SKIP_VERIFY` | `configmap.SD_TLS_SKIP_VERIFY` > `global.serviceDiscovery.tlsSkipVerify` > `false` |
| `SD_WORKLOAD` | `configmap.SD_WORKLOAD` > `global.serviceDiscovery.workload` > `""` |
| `SD_PREFER_VIEW` | `configmap.SD_PREFER_VIEW` > `global.serviceDiscovery.preferView` > `"internal"` |
| `SD_INTERNAL_ADDRESS` | `configmap.SD_INTERNAL_ADDRESS` > derived from `name` + `namespace` > `""` |
| `SD_INTERNAL_PORT` | `configmap.SD_INTERNAL_PORT` > `port` input > `""` |
| `SD_INTERNAL_SCHEME` | `configmap.SD_INTERNAL_SCHEME` > `global.serviceDiscovery.internalScheme` > `"http"` |
| `SD_EXTERNAL_ADDRESS` | `configmap.SD_EXTERNAL_ADDRESS` > derived from `ingressHost` > `""` |
| `SD_EXTERNAL_PORT` | `configmap.SD_EXTERNAL_PORT` > `global.serviceDiscovery.externalPort` > `443` |

> **Note:** The `configmap` parameter defaults to an empty dict when omitted, so a chart that does not pass it renders **byte-identical** output to v1.2.1.

### 2. Streaming Legacy Configmap Support and New Configuration Fields

The `lerian-common.streaming.env` helper now accepts an optional `configmap` parameter (same precedence behavior as `serviceDiscovery.env`) and emits **five new environment variables** for Kafka producer tuning.

#### Legacy Configmap Support

**What changed:**

The helper's precedence order is now:

1. Component-level `configmap.STREAMING_*` (highest)
2. `global.streaming.*`
3. Helper default (lowest)

**Why it matters:**

Product charts that support the legacy flat configmap API (e.g. `.Values.myapp.configmap.STREAMING_BROKERS`) can now pass that map to the helper. Operators who set overrides via the flat configmap will see those values take precedence over `global.streaming.*`.

**Before (v1.2.1):**

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.streaming.env" (dict "context" $ "enabled" .Values.myapp.streaming.enabled "clientId" .Values.myapp.streaming.clientId "cloudeventsSource" .Values.myapp.streaming.cloudeventsSource) | nindent 2 }}
```

**After (v1.2.2):**

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.streaming.env" (dict "context" $ "enabled" .Values.myapp.streaming.enabled "clientId" .Values.myapp.streaming.clientId "cloudeventsSource" .Values.myapp.streaming.cloudeventsSource "configmap" .Values.myapp.configmap) | nindent 2 }}
```

#### New Streaming Configuration Fields

**What changed:**

The helper now emits five additional environment variables for Kafka producer tuning:

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAMING_SASL_ALLOW_PLAINTEXT` | `"false"` | Allow SASL authentication over plaintext (non-TLS) connections |
| `STREAMING_COMPRESSION` | `"lz4"` | Compression codec for producer messages (`none`, `gzip`, `snappy`, `lz4`, `zstd`) |
| `STREAMING_REQUIRED_ACKS` | `"all"` | Producer acknowledgment mode (`0`, `1`, `all`) |
| `STREAMING_BATCH_LINGER_MS` | `"5"` | Time to wait before sending a batch (milliseconds) |
| `STREAMING_IMPORTANT_EMIT_TIMEOUT_MS` | `"5000"` | Timeout for important message emission (milliseconds) |

**Why it matters:**

These fields allow operators to tune Kafka producer behavior for production workloads (e.g. increase `batchLingerMs` for higher throughput, set `requiredAcks` to `1` for lower latency, enable `saslAllowPlaintext` for dev/test environments).

**Configuration block (umbrella `values.yaml`):**

```yaml
global:
  streaming:
    brokers: "redpanda.prod.example.com:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "lerian-user"
    # New fields (v1.2.2)
    saslAllowPlaintext: "false"
    compression: "lz4"
    requiredAcks: "all"
    batchLingerMs: "5"
    importantEmitTimeoutMs: "5000"
```

**Precedence for new fields:**

| Variable | Precedence (v1.2.2) |
|----------|---------------------|
| `STREAMING_SASL_ALLOW_PLAINTEXT` | `configmap.STREAMING_SASL_ALLOW_PLAINTEXT` > `global.streaming.saslAllowPlaintext` > `"false"` |
| `STREAMING_COMPRESSION` | `configmap.STREAMING_COMPRESSION` > `global.streaming.compression` > `"lz4"` |
| `STREAMING_REQUIRED_ACKS` | `configmap.STREAMING_REQUIRED_ACKS` > `global.streaming.requiredAcks` > `"all"` |
| `STREAMING_BATCH_LINGER_MS` | `configmap.STREAMING_BATCH_LINGER_MS` > `global.streaming.batchLingerMs` > `"5"` |
| `STREAMING_IMPORTANT_EMIT_TIMEOUT_MS` | `configmap.STREAMING_IMPORTANT_EMIT_TIMEOUT_MS` > `global.streaming.importantEmitTimeoutMs` > `"5000"` |

**Existing fields (precedence updated in v1.2.2):**

| Variable | Precedence (v1.2.2) |
|----------|---------------------|
| `STREAMING_BROKERS` | `configmap.STREAMING_BROKERS` > `global.streaming.brokers` > `""` |
| `STREAMING_TLS_ENABLED` | `configmap.STREAMING_TLS_ENABLED` > `global.streaming.tlsEnabled` > `false` |
| `STREAMING_SASL_MECHANISM` | `configmap.STREAMING_SASL_MECHANISM` > `global.streaming.saslMechanism` > `""` |
| `STREAMING_SASL_USERNAME` | `configmap.STREAMING_SASL_USERNAME` > `global.streaming.saslUsername` > `""` |
| `STREAMING_CLIENT_ID` | `configmap.STREAMING_CLIENT_ID` > `clientId` input > (not emitted) |
| `STREAMING_CLOUDEVENTS_SOURCE` | `configmap.STREAMING_CLOUDEVENTS_SOURCE` > `cloudeventsSource` input > (not emitted) |

> **Note:** The new fields are **optional**. If not set in `global.streaming.*` or `configmap.*`, the helper emits the default values shown above.

## Configuration Reference

### New `global.streaming` Fields (v1.2.2)

| Field | Default | Description |
|-------|---------|-------------|
| `saslAllowPlaintext` | `"false"` | Allow SASL authentication over plaintext (non-TLS) connections. Set to `"true"` for dev/test environments without TLS. |
| `compression` | `"lz4"` | Compression codec for producer messages. Valid values: `none`, `gzip`, `snappy`, `lz4`, `zstd`. |
| `requiredAcks` | `"all"` | Producer acknowledgment mode. `0` = no ack, `1` = leader ack, `all` = all in-sync replicas ack. |
| `batchLingerMs` | `"5"` | Time to wait before sending a batch (milliseconds). Increase for higher throughput, decrease for lower latency. |
| `importantEmitTimeoutMs` | `"5000"` | Timeout for important message emission (milliseconds). |

**Full `global.streaming` block example (v1.2.2):**

```yaml
global:
  streaming:
    brokers: "redpanda.prod.example.com:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "lerian-user"
    saslAllowPlaintext: "false"
    compression: "lz4"
    requiredAcks: "all"
    batchLingerMs: "5"
    importantEmitTimeoutMs: "5000"
```

### Legacy Configmap Override Example

If an operator needs to override a specific streaming or service discovery field for one component without changing the global value:

```yaml
myapp:
  configmap:
    # Override streaming brokers for this component only
    STREAMING_BROKERS: "redpanda-dev.example.com:9092"
    STREAMING_COMPRESSION: "snappy"
    # Override service discovery address for this component only
    SD_ADDRESS: "consul-dev.example.com:8500"
    SD_PREFER_VIEW: "external"
```

## Migration Steps

### For Operators (Umbrella Deployments)

#### Option 1: No Action Required (Use Defaults)

If you are satisfied with the new streaming defaults (`lz4` compression, `all` acks, `5ms` linger, `5000ms` timeout), **no action is required**. The helper will emit these values automatically.

#### Option 2: Tune Streaming Configuration

If you need to tune Kafka producer behavior for your environment:

1. **Add the new fields** to your umbrella `values.yaml` under `global.streaming`:

```yaml
global:
  streaming:
    brokers: "redpanda.prod.example.com:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "lerian-user"
    # Tune for higher throughput
    compression: "zstd"
    batchLingerMs: "10"
    # Tune for lower latency
    requiredAcks: "1"
    importantEmitTimeoutMs: "3000"
```

2. **Upgrade the umbrella chart:**

```bash
helm upgrade my-umbrella . -n lerian --values values.yaml
```

3. **Verify the new environment variables** are present in the ConfigMap:

```bash
helm get manifest my-umbrella -n lerian | grep -A 20 "kind: ConfigMap"
```

#### Option 3: Override Per Component (Legacy Configmap)

If you need to override streaming or service discovery settings for a specific component without changing the global value:

1. **Set the override** in the component's `configmap` block:

```yaml
myapp:
  configmap:
    STREAMING_COMPRESSION: "snappy"
    SD_PREFER_VIEW: "external"
```

2. **Upgrade the umbrella chart:**

```bash
helm upgrade my-umbrella . -n lerian --values values.yaml
```

> **Note:** This approach is only supported if the product chart passes the `configmap` parameter to the helper. Check the product chart's templates to confirm.

### For Chart Maintainers (Product Charts)

If you maintain a product chart that consumes `lerian-common` and want to support legacy flat configmap overrides:

1. **Update the `lerian-common` dependency** in your `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 1.2.2
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Pass the `configmap` parameter** to the helpers in your ConfigMap template:

**Before (v1.2.1):**

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.serviceDiscovery.env" (dict "context" $ "name" .Values.myapp.name "namespace" .Release.Namespace "port" .Values.myapp.service.port "ingressHost" .Values.myapp.ingress.host) | nindent 2 }}
  {{- include "lerian-common.streaming.env" (dict "context" $ "enabled" .Values.myapp.streaming.enabled "clientId" .Values.myapp.streaming.clientId "cloudeventsSource" .Values.myapp.streaming.cloudeventsSource) | nindent 2 }}
```

**After (v1.2.2):**

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.serviceDiscovery.env" (dict "context" $ "name" .Values.myapp.name "namespace" .Release.Namespace "port" .Values.myapp.service.port "ingressHost" .Values.myapp.ingress.host "configmap" .Values.myapp.configmap) | nindent 2 }}
  {{- include "lerian-common.streaming.env" (dict "context" $ "enabled" .Values.myapp.streaming.enabled "clientId" .Values.myapp.streaming.clientId "cloudeventsSource" .Values.myapp.streaming.cloudeventsSource "configmap" .Values.myapp.configmap) | nindent 2 }}
```

4. **Test render equivalence** (ensure output is byte-identical for existing users who do not set `configmap.*` overrides):

```bash
helm template my-chart . --values test-values.yaml > before.yaml
# (after refactor)
helm template my-chart . --values test-values.yaml > after.yaml
diff before.yaml after.yaml
```

5. **Document the new override capability** in your product chart's README or CHANGELOG.

### For Standalone Deployments

If you deploy a single product chart without an umbrella:

**No action required.** The new streaming fields have safe defaults and will be emitted automatically. If you need to tune them, set `global.streaming.*` in your product chart's `values.yaml`.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.2.2 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v1.2.2, run `helm diff` on the **product charts** that consume it after updating the dependency version.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.2.2 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `1.2.2` and run `helm dependency update`, then upgrade the parent chart.
