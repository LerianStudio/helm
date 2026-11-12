<!-- {% raw %} -->
# Helm Upgrade from v5.4.1 to v5.4.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 4.10.0](#1-application-version-bump-to-4100)
  - [2. Kafka streaming support for business events](#2-kafka-streaming-support-for-business-events)
  - [3. CloudEvents source default changed to "reporter"](#3-cloudevents-source-default-changed-to-reporter)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that bumps the application version to `4.10.0` and introduces Kafka streaming support for business events. The reporter application now publishes every business event to Kafka instead of relying solely on RabbitMQ with outbox pattern. The CloudEvents source default has been changed from `//lerian.reporter` to `reporter`, and the application now enforces this value at boot time.

| Field | v5.4.1 | v5.4.2 |
|-------|--------|--------|
| Chart version | `5.4.1` | `5.4.2` |
| App version | `4.9.0` | `4.10.0` |
| Manager image tag | `4.9.0` | `4.10.0` |
| Worker image tag | `4.9.0` | `4.10.0` |

## Fixes

### 1. Application version bump to 4.10.0

The manager and worker image tags have been updated from `4.9.0` to `4.10.0`, and the chart `appVersion` field reflects this change.

| Component | v5.4.1 | v5.4.2 |
|-----------|--------|--------|
| `manager.image.tag` | `"4.9.0"` | `"4.10.0"` |
| `worker.image.tag` | `"4.9.0"` | `"4.10.0"` |
| Chart `appVersion` | `"4.9.0"` | `"4.10.0"` |

### 2. Kafka streaming support for business events

Application version `4.10.0` introduces direct Kafka publishing for all business events. The application now reads `STREAMING_KAFKA_BROKERS` to dial Kafka brokers, while `STREAMING_BROKERS` (from lib-streaming) is still validated as non-empty but never dialed.

A new helper template `reporter.streamingKafkaBrokers` has been added to emit `STREAMING_KAFKA_BROKERS` in each component's ConfigMap. The helper is invoked in both `manager/configmap.yaml` and `worker/configmap.yaml`.

**Template definition:**

```yaml
{{- define "reporter.streamingKafkaBrokers" -}}
{{- $ := .context -}}
{{- $comp := .component | default dict -}}
{{- $cm := $.Values.common.configmap | default dict -}}
{{- $s := ($.Values.global | default dict).streaming | default dict -}}
{{- $streamingRaw := $s.enabled -}}
{{- if hasKey $cm "STREAMING_ENABLED" }}{{- $streamingRaw = index $cm "STREAMING_ENABLED" -}}{{- end -}}
{{- $mtRaw := (($.Values.global | default dict).multiTenant | default dict).enabled -}}
{{- if hasKey $cm "MULTI_TENANT_ENABLED" }}{{- $mtRaw = index $cm "MULTI_TENANT_ENABLED" -}}{{- end -}}
{{- if kindIs "invalid" $mtRaw }}{{- $mtRaw = "false" -}}{{- end -}}
{{- $componentSets := or (hasKey ($comp.configmap | default dict) "STREAMING_KAFKA_BROKERS") (hasKey ($comp.extraEnvVars | default dict) "STREAMING_KAFKA_BROKERS") -}}
{{- if and (eq (include "reporter.isTrue" ($streamingRaw | default "false")) "true")
           (not (eq (include "reporter.isTrue" $mtRaw) "true"))
           (not (hasKey $cm "STREAMING_KAFKA_BROKERS"))
           (not $componentSets)
           (trim (toString ($s.brokers | default ""))) }}
STREAMING_KAFKA_BROKERS: {{ $s.brokers | quote }}
{{- end -}}
{{- end -}}
```

**How it works:**

- **Single-tenant mode:** When `STREAMING_ENABLED` is `true` and `global.streaming.brokers` is set, the helper emits `STREAMING_KAFKA_BROKERS` with the value from `global.streaming.brokers`. The application dials this list and refuses to boot if streaming is enabled and the key is empty.
- **Multi-tenant mode:** When `MULTI_TENANT_ENABLED` is `true`, the Tenant Manager serves the brokers per tenant, and `STREAMING_KAFKA_BROKERS` is not emitted.
- **Escape hatch:** If `common.configmap.STREAMING_KAFKA_BROKERS` is set, it takes precedence and the helper emits nothing (the value is rendered by `reporter.commonConfigmapData`).
- **Component override:** If a component sets `STREAMING_KAFKA_BROKERS` via its own `configmap` or `extraEnvVars`, the helper emits nothing to avoid duplication.

**Manager ConfigMap changes:**

**Before (v5.4.1):**

```yaml
data:
  {{- include "reporter.commonConfigmapData" . | nindent 2 }}
  {{- $idpEnvKeys := include "lerian-common.idp.keys" (dict "kind" "env") | fromJsonArray }}
  {{- range $key, $value := .Values.manager.configmap }}
```

**After (v5.4.2):**

```yaml
data:
  {{- include "reporter.commonConfigmapData" . | nindent 2 }}
  {{- with (include "reporter.streamingKafkaBrokers" (dict "context" $ "component" .Values.manager)) }}
  {{- . | nindent 2 }}
  {{- end }}
  {{- $idpEnvKeys := include "lerian-common.idp.keys" (dict "kind" "env") | fromJsonArray }}
  {{- range $key, $value := .Values.manager.configmap }}
```

**Worker ConfigMap changes:**

**Before (v5.4.1):**

```yaml
data:
  {{- include "reporter.commonConfigmapData" . | nindent 2 }}
  {{- range $key, $value := .Values.worker.configmap }}
```

**After (v5.4.2):**

```yaml
data:
  {{- include "reporter.commonConfigmapData" . | nindent 2 }}
  {{- with (include "reporter.streamingKafkaBrokers" (dict "context" $ "component" .Values.worker)) }}
  {{- . | nindent 2 }}
  {{- end }}
  {{- range $key, $value := .Values.worker.configmap }}
```

**Operational impact:**

- If you have `global.streaming.enabled: true` and `global.streaming.brokers` set in your values, the manager and worker ConfigMaps will now include `STREAMING_KAFKA_BROKERS` with the same broker list. The application will dial these brokers to publish business events.
- If you are running in multi-tenant mode (`global.multiTenant.enabled: true`), no `STREAMING_KAFKA_BROKERS` key is emitted — the Tenant Manager serves the brokers per tenant.
- The legacy `RABBITMQ_REPORT_EVENTS_EXCHANGE` environment variable is still emitted but is only read by application versions prior to `4.10.0`. Version `4.10.0` and later ignore this variable.

**Example configuration for single-tenant Kafka streaming:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda:9092"
```

This will emit:

```yaml
STREAMING_ENABLED: "true"
STREAMING_BROKERS: "redpanda:9092"
STREAMING_KAFKA_BROKERS: "redpanda:9092"
```

**Example escape-hatch override:**

```yaml
common:
  configmap:
    STREAMING_KAFKA_BROKERS: "kafka-cluster-1:9092,kafka-cluster-2:9092"
```

This will use the explicit override instead of `global.streaming.brokers`.

> **Important:** Application version `4.10.0` requires `STREAMING_KAFKA_BROKERS` to be non-empty when `STREAMING_ENABLED` is `true` in single-tenant mode. If you enable streaming without setting `global.streaming.brokers`, the application will refuse to boot.

### 3. CloudEvents source default changed to "reporter"

The default CloudEvents source has been changed from `//lerian.reporter` to `reporter`. Application version `4.10.0` enforces that the CloudEvents source must be exactly `"reporter"` and will refuse to boot with any other value, whether or not streaming is enabled.

**Before (v5.4.1):**

```yaml
{{- include "lerian-common.streaming.env" (dict
      "enabled" $streamingEnabled
      "configmap" $cm
      "clientId" ($cm.STREAMING_CLIENT_ID | default "reporter")
      "cloudeventsSource" ($cm.STREAMING_CLOUDEVENTS_SOURCE | default "//lerian.reporter")) | nindent 0 }}
```

**After (v5.4.2):**

```yaml
{{- include "lerian-common.streaming.env" (dict
      "enabled" $streamingEnabled
      "configmap" $cm
      "clientId" ($cm.STREAMING_CLIENT_ID | default "reporter")
      "cloudeventsSource" ($cm.STREAMING_CLOUDEVENTS_SOURCE | default "reporter")) | nindent 0 }}
```

**Operational impact:**

- If you have not set `common.configmap.STREAMING_CLOUDEVENTS_SOURCE` in your values, the default changes from `//lerian.reporter` to `reporter`. The application will boot successfully.
- If you have explicitly set `STREAMING_CLOUDEVENTS_SOURCE` to any value other than `"reporter"`, the application will refuse to boot. You must remove the override or set it to `"reporter"`.

**Example override (required if previously set to a custom value):**

```yaml
common:
  configmap:
    STREAMING_CLOUDEVENTS_SOURCE: "reporter"
```

> **Warning:** The application enforces that `STREAMING_CLOUDEVENTS_SOURCE` must be exactly `"reporter"`. Any other value will cause the application to exit at startup.

## Configuration Changes

No `values.yaml` keys were added, removed, or renamed. The changes are in template logic and default values only.

| Setting | v5.4.1 | v5.4.2 | Notes |
|---------|--------|--------|-------|
| `manager.image.tag` | `"4.9.0"` | `"4.10.0"` | Application version bump |
| `worker.image.tag` | `"4.9.0"` | `"4.10.0"` | Application version bump |
| `STREAMING_CLOUDEVENTS_SOURCE` (default) | `"//lerian.reporter"` | `"reporter"` | Application enforces this value at boot |
| `STREAMING_KAFKA_BROKERS` (new) | Not emitted | Emitted from `global.streaming.brokers` in single-tenant mode | Application dials this list to publish events |

## Migration Steps

This upgrade requires no mandatory values changes unless you have explicitly overridden `STREAMING_CLOUDEVENTS_SOURCE` to a value other than `"reporter"`.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. If you have explicitly set `common.configmap.STREAMING_CLOUDEVENTS_SOURCE` to a value other than `"reporter"`, update your values file:

   ```yaml
   common:
     configmap:
       STREAMING_CLOUDEVENTS_SOURCE: "reporter"
   ```

   Or remove the override entirely to use the new default.

3. If you have `global.streaming.enabled: true` but no `global.streaming.brokers` set, the application will refuse to boot in single-tenant mode. Ensure your values include:

   ```yaml
   global:
     streaming:
       enabled: true
       brokers: "your-kafka-brokers:9092"
   ```

4. Run the upgrade command during a maintenance window.

5. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n reporter
   ```

6. Check manager and worker logs to confirm Kafka connectivity:

   ```bash
   kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
   kubectl logs -n reporter -l app.kubernetes.io/name=reporter-worker --tail=50
   ```

7. Verify the ConfigMaps include the new `STREAMING_KAFKA_BROKERS` key (if streaming is enabled):

   ```bash
   kubectl get configmap -n reporter reporter-manager -o jsonpath='{.data.STREAMING_KAFKA_BROKERS}'
   kubectl get configmap -n reporter reporter-worker -o jsonpath='{.data.STREAMING_KAFKA_BROKERS}'
   ```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. If you are running in single-tenant mode with streaming enabled, ensure your Kafka brokers are reachable before upgrading.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.2
```
<!-- {% endraw %} -->
