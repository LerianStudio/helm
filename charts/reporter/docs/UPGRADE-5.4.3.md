<!-- {% raw %} -->
# Helm Upgrade from v5.4.2 to v5.4.3

## Topics

- **[Overview](#overview)**
- **[Dependency Updates](#dependency-updates)**
  - [1. lerian-common-helm upgraded to v2.7.0](#1-lerian-common-helm-upgraded-to-v270)
- **[Configuration Changes](#configuration-changes)**
  - [1. New global.observability.allowInsecureOtel field](#1-new-globalobservabilityallowinsecureotel-field)
  - [2. New ALLOW_INSECURE_OTEL environment variable](#2-new-allow_insecure_otel-environment-variable)
- **[Template Changes](#template-changes)**
  - [1. Enhanced ConfigMap rendering for ALLOW_INSECURE_OTEL](#1-enhanced-configmap-rendering-for-allow_insecure_otel)
  - [2. New template helpers for OTEL insecure transport](#2-new-template-helpers-for-otel-insecure-transport)
  - [3. Manager deployment ALLOW_INSECURE_OTEL injection](#3-manager-deployment-allow_insecure_otel-injection)
  - [4. Worker deployment ALLOW_INSECURE_OTEL injection](#4-worker-deployment-allow_insecure_otel-injection)
  - [5. Worker KEDA ScaledJob ALLOW_INSECURE_OTEL injection](#5-worker-keda-scaledjob-allow_insecure_otel-injection)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that upgrades the `lerian-common-helm` dependency to v2.7.0 and adds support for the `ALLOW_INSECURE_OTEL` environment variable, which is required when shipping OpenTelemetry data to a node-local collector over plaintext in production environments. The application version remains unchanged at `4.10.0`.

| Field | v5.4.2 | v5.4.3 |
|-------|--------|--------|
| Chart version | `5.4.2` | `5.4.3` |
| App version | `4.10.0` | `4.10.0` |
| lerian-common-helm | `2.6.0` | `2.7.0` |

## Dependency Updates

### 1. lerian-common-helm upgraded to v2.7.0

The `lerian-common-helm` dependency has been upgraded from v2.6.0 to v2.7.0. This update includes the `lerian-common.otel.allowInsecure` template helper used by the new `ALLOW_INSECURE_OTEL` configuration.

| Dependency | v5.4.2 | v5.4.3 |
|------------|--------|--------|
| `lerian-common-helm` | `2.6.0` | `2.7.0` |

> **Note:** The dependency upgrade is handled automatically by Helm during the upgrade process. No manual intervention is required.

## Configuration Changes

### 1. New global.observability.allowInsecureOtel field

A new `global.observability.allowInsecureOtel` field has been added to support environments where OpenTelemetry data is shipped to a node-local collector over plaintext (e.g., `$(HOST_IP):4317`). The `lib-observability` library refuses plaintext exporters in production unless `ALLOW_INSECURE_OTEL` carries a reason string.

| Field | v5.4.2 | v5.4.3 | Default |
|-------|--------|--------|---------|
| `global.observability.allowInsecureOtel` | not present | added | `"node-local collector on the pod's own node"` (when node-local collector is enabled) |

**Example configuration:**

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
    allowInsecureOtel: "node-local collector on the pod's own node"
```

The field is documented in `values.yaml` with the following comment:

```yaml
# example ↓ (uncomment & fill; comments render nothing = default stays empty):
#   enabled: true
#   allowInsecureOtel: "node-local collector on the pod's own node"
```

> **Important:** Setting `allowInsecureOtel` to `null` (unset), `""` (empty string), or `"false"` will prevent the application from starting in production when using a plaintext OTEL endpoint. The value must be a non-empty reason string explaining why insecure transport is acceptable.

### 2. New ALLOW_INSECURE_OTEL environment variable

The `ALLOW_INSECURE_OTEL` environment variable has been added to both manager and worker components. This variable is set automatically when the node-local OTEL collector is enabled (`otel-collector-lerian.enabled=true`) and follows a precedence chain for configuration.

**Precedence order (highest to lowest):**

1. `<component>.configmap.ALLOW_INSECURE_OTEL` (manager or worker specific)
2. `common.configmap.ALLOW_INSECURE_OTEL` (shared across components)
3. `global.observability.allowInsecureOtel`
4. `"node-local collector on the pod's own node"` (default when node-local collector is enabled)

| Variable | Default (node-local collector enabled) | Default (node-local collector disabled) | Description |
|----------|----------------------------------------|----------------------------------------|-------------|
| `ALLOW_INSECURE_OTEL` | `"node-local collector on the pod's own node"` | not set (unless explicitly configured) | Reason string explaining why plaintext OTEL transport is acceptable in production |

**Manager configmap documentation:**

```yaml
manager:
  configmap:
    # ALLOW_INSECURE_OTEL — with otel-collector-lerian.enabled the manager ships to the
    # node-local collector at $(HOST_IP):4317 in plaintext, and lib-observability refuses
    # that in production unless ALLOW_INSECURE_OTEL carries a reason. The chart sets it on
    # the container: manager.configmap.ALLOW_INSECURE_OTEL > common.configmap.ALLOW_INSECURE_OTEL
    # > global.observability.allowInsecureOtel > "node-local collector on the pod's own node".
    # null = unset; "" or "false" = an explicit refusal (stops the chain).
    # ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

**Worker configmap documentation:**

```yaml
worker:
  configmap:
    # ALLOW_INSECURE_OTEL — with otel-collector-lerian.enabled the worker (Deployment or KEDA ScaledJob) ships to the
    # node-local collector at $(HOST_IP):4317 in plaintext, and lib-observability refuses
    # that in production unless ALLOW_INSECURE_OTEL carries a reason. The chart sets it on
    # the container: worker.configmap.ALLOW_INSECURE_OTEL > common.configmap.ALLOW_INSECURE_OTEL
    # > global.observability.allowInsecureOtel > "node-local collector on the pod's own node".
    # null = unset; "" or "false" = an explicit refusal (stops the chain).
    # ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

> **Note:** Setting `ALLOW_INSECURE_OTEL` to `null` in any tier of the precedence chain leaves it unset at that tier, allowing the next tier to provide a value. Setting it to `""` or `"false"` is an explicit refusal that stops the chain and prevents the application from starting in production with a plaintext OTEL endpoint.

## Template Changes

### 1. Enhanced ConfigMap rendering for ALLOW_INSECURE_OTEL

The common ConfigMap template (`_helpers.tpl`) now skips rendering `ALLOW_INSECURE_OTEL` when its value is `null` (Go template `invalid` kind). This allows the precedence chain to work correctly: a `null` value in a higher-precedence tier does not override a non-null value in a lower-precedence tier.

**Before (v5.4.2):**

```yaml
{{- range $key, $value := $cm }}
{{- if not (has $key $explicit) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
```

**After (v5.4.3):**

```yaml
{{- range $key, $value := $cm }}
{{- if not (or (has $key $explicit) (and (eq $key "ALLOW_INSECURE_OTEL") (kindIs "invalid" $value))) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
```

The manager and worker ConfigMap templates now also skip `null` values for `ALLOW_INSECURE_OTEL` and call the new `reporter.otelAllowInsecureConfigmap` helper to inject the global default when appropriate.

**Manager ConfigMap before (v5.4.2):**

```yaml
{{- range $key, $value := .Values.manager.configmap }}
{{- if not (has $key $idpEnvKeys) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
```

**Manager ConfigMap after (v5.4.3):**

```yaml
{{- range $key, $value := .Values.manager.configmap }}
{{- if not (or (has $key $idpEnvKeys) (and (eq $key "ALLOW_INSECURE_OTEL") (kindIs "invalid" $value))) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- with (include "reporter.otelAllowInsecureConfigmap" (dict "context" $ "component" .Values.manager) | trim) }}
{{- . | nindent 2 }}
{{- end }}
```

**Worker ConfigMap before (v5.4.2):**

```yaml
{{- range $key, $value := .Values.worker.configmap }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
```

**Worker ConfigMap after (v5.4.3):**

```yaml
{{- range $key, $value := .Values.worker.configmap }}
{{- if not (and (eq $key "ALLOW_INSECURE_OTEL") (kindIs "invalid" $value)) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- with (include "reporter.otelAllowInsecureConfigmap" (dict "context" $ "component" .Values.worker) | trim) }}
{{- . | nindent 2 }}
{{- end }}
```

> **Note:** The `kindIs "invalid"` check detects `null` values in YAML (rendered as Go template `nil`). This allows operators to explicitly unset `ALLOW_INSECURE_OTEL` at a higher precedence tier by setting it to `null`, letting the next tier provide a value.

### 2. New template helpers for OTEL insecure transport

Two new template helpers have been added to `_helpers.tpl` to manage the `ALLOW_INSECURE_OTEL` environment variable:

#### reporter.otelAllowInsecureEnv

Renders the `ALLOW_INSECURE_OTEL` environment variable entry for a component's container. This helper is called inside the `otel-collector-lerian.enabled` gate that emits the `$(HOST_IP):4317` endpoint.

**Usage:**

```yaml
{{- with (include "reporter.otelAllowInsecureEnv" (dict "context" $ "component" .Values.manager) | trim) }}
{{- . | nindent 10 }}
{{- end }}
```

**Precedence chain:**

1. `<component>.configmap.ALLOW_INSECURE_OTEL`
2. `common.configmap.ALLOW_INSECURE_OTEL`
3. `global.observability.allowInsecureOtel`
4. `"node-local collector on the pod's own node"` (default)

**Legacy routes (helper emits nothing to avoid duplicate env names):**

- The key exists in `<component>.extraEnvVars`
- A non-empty `secrets.ALLOW_INSECURE_OTEL` exists in the chart's own Secret (`useExistingSecret=false`) and no higher-precedence tier is set

**Collector-off mode:**

When called with `"nodeLocal" false`, the helper emits the environment variable only when:

- A value is set in the precedence chain (configmap tiers or global)
- No `extraEnvVars` key exists
- A Secret route is present (`secrets.ALLOW_INSECURE_OTEL` present or `useExistingSecret=true`)

This ensures the modeled value wins over the Secret (which is read after the ConfigMap via `envFrom`).

#### reporter.otelAllowInsecureConfigmap

Renders the `ALLOW_INSECURE_OTEL` key for a component's ConfigMap when the node-local collector is disabled. This helper injects the `global.observability.allowInsecureOtel` value into the ConfigMap only when:

- `global.observability.allowInsecureOtel` is non-null
- No higher-precedence tier (`<component>.configmap` or `common.configmap`) sets the key
- The key does not exist in `<component>.extraEnvVars`

**Usage:**

```yaml
{{- with (include "reporter.otelAllowInsecureConfigmap" (dict "context" $ "component" .Values.manager) | trim) }}
{{- . | nindent 2 }}
{{- end }}
```

> **Important:** These helpers ensure that the `ALLOW_INSECURE_OTEL` variable is set correctly regardless of whether the node-local collector is enabled, and that legacy configuration routes (extraEnvVars, secrets) continue to work without breaking changes.

### 3. Manager deployment ALLOW_INSECURE_OTEL injection

The manager deployment template now injects the `ALLOW_INSECURE_OTEL` environment variable when the node-local OTEL collector is enabled. When the collector is disabled, the variable is injected only if a modeled value exists and a Secret route is present.

**Before (v5.4.2):**

```yaml
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
{{- end }}
```

**After (v5.4.3):**

```yaml
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
{{- /* The node-local hop is plaintext: ALLOW_INSECURE_OTEL lets it boot in production (see reporter.otelAllowInsecureEnv). */}}
{{- with (include "reporter.otelAllowInsecureEnv" (dict "context" $ "component" .Values.manager) | trim) }}
{{- . | nindent 10 }}
{{- end }}
{{- else }}
{{- /* Collector off: the model must still beat a Secret reason (envFrom). */}}
{{- with (include "reporter.otelAllowInsecureEnv" (dict "context" $ "component" .Values.manager "nodeLocal" false) | trim) }}
{{- . | nindent 10 }}
{{- end }}
{{- end }}
```

The rendered environment variable entry looks like:

```yaml
- name: "ALLOW_INSECURE_OTEL"
  value: "node-local collector on the pod's own node"
```

> **Note:** The manager deployment will restart during the upgrade due to the addition of the new environment variable. If you have customized `manager.configmap.ALLOW_INSECURE_OTEL`, `common.configmap.ALLOW_INSECURE_OTEL`, or `global.observability.allowInsecureOtel`, verify that the value is a non-empty reason string before upgrading.

### 4. Worker deployment ALLOW_INSECURE_OTEL injection

The worker deployment template now injects the `ALLOW_INSECURE_OTEL` environment variable when the node-local OTEL collector is enabled. When the collector is disabled, the variable is injected only if a modeled value exists and a Secret route is present.

**Before (v5.4.2):**

```yaml
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
{{- end }}
```

**After (v5.4.3):**

```yaml
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
{{- /* The node-local hop is plaintext: ALLOW_INSECURE_OTEL lets it boot in production (see reporter.otelAllowInsecureEnv). */}}
{{- with (include "reporter.otelAllowInsecureEnv" (dict "context" $ "component" .Values.worker) | trim) }}
{{- . | nindent 10 }}
{{- end }}
{{- else }}
{{- /* Collector off: the model must still beat a Secret reason (envFrom). */}}
{{- with (include "reporter.otelAllowInsecureEnv" (dict "context" $ "component" .Values.worker "nodeLocal" false) | trim) }}
{{- . | nindent 10 }}
{{- end }}
{{- end }}
```

The rendered environment variable entry looks like:

```yaml
- name: "ALLOW_INSECURE_OTEL"
  value: "node-local collector on the pod's own node"
```

> **Note:** The worker deployment will restart during the upgrade due to the addition of the new environment variable. If you have customized `worker.configmap.ALLOW_INSECURE_OTEL`, `common.configmap.ALLOW_INSECURE_OTEL`, or `global.observability.allowInsecureOtel`, verify that the value is a non-empty reason string before upgrading.

### 5. Worker KEDA ScaledJob ALLOW_INSECURE_OTEL injection

The worker KEDA ScaledJob template now injects the `ALLOW_INSECURE_OTEL` environment variable when the node-local OTEL collector is enabled. When the collector is disabled, the variable is injected only if a modeled value exists and a Secret route is present.

**Before (v5.4.2):**

```yaml
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
{{- end }}
```

**After (v5.4.3):**

```yaml
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
{{- /* The node-local hop is plaintext: ALLOW_INSECURE_OTEL lets it boot in production (see reporter.otelAllowInsecureEnv). */}}
{{- with (include "reporter.otelAllowInsecureEnv" (dict "context" $ "component" $.Values.worker) | trim) }}
{{- . | nindent 10 }}
{{- end }}
{{- else }}
{{- /* Collector off: the model must still beat a Secret reason (envFrom). */}}
{{- with (include "reporter.otelAllowInsecureEnv" (dict "context" $ "component" $.Values.worker "nodeLocal" false) | trim) }}
{{- . | nindent 10 }}
{{- end }}
{{- end }}
```

The rendered environment variable entry looks like:

```yaml
- name: "ALLOW_INSECURE_OTEL"
  value: "node-local collector on the pod's own node"
```

> **Note:** The worker KEDA ScaledJob will be updated during the upgrade. New jobs created by KEDA will include the new environment variable. If you have customized `worker.configmap.ALLOW_INSECURE_OTEL`, `common.configmap.ALLOW_INSECURE_OTEL`, or `global.observability.allowInsecureOtel`, verify that the value is a non-empty reason string before upgrading.

## Migration Steps

This upgrade requires no mandatory configuration changes. The default behavior provides a reasonable value for `ALLOW_INSECURE_OTEL` when the node-local OTEL collector is enabled. However, you may want to customize the reason string for your environment.

**Recommended upgrade process:**

1. Review your current OTEL configuration. If you have `otel-collector-lerian.enabled=true` and `global.observability.deploymentEnvironment` set to a production tier, the upgrade will automatically inject `ALLOW_INSECURE_OTEL="node-local collector on the pod's own node"`.

2. **(Optional)** Customize the reason string by setting `global.observability.allowInsecureOtel`:

```yaml
global:
  observability:
    enabled: true
    deploymentEnvironment: "production"
    allowInsecureOtel: "Custom reason: node-local collector on the pod's own node"
```

3. **(Optional)** Override the reason string for a specific component:

```yaml
manager:
  configmap:
    ALLOW_INSECURE_OTEL: "Manager-specific reason"

worker:
  configmap:
    ALLOW_INSECURE_OTEL: "Worker-specific reason"
```

4. **(Optional)** Explicitly refuse insecure OTEL transport by setting the value to `""` or `"false"`:

```yaml
global:
  observability:
    allowInsecureOtel: ""
```

> **Warning:** Setting `allowInsecureOtel` to `""` or `"false"` will prevent the application from starting in production when using a plaintext OTEL endpoint. Only use this setting if you have migrated to a secure OTEL endpoint (e.g., TLS-enabled collector).

5. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

6. Run the upgrade command during a maintenance window.

7. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

8. Verify the `ALLOW_INSECURE_OTEL` environment variable is set correctly:

```bash
kubectl get deployment -n <namespace> reporter-manager -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="ALLOW_INSECURE_OTEL")].value}'
kubectl get deployment -n <namespace> reporter-worker -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="ALLOW_INSECURE_OTEL")].value}'
```

9. Check manager and worker logs to confirm OTEL data is being exported successfully:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50 | grep -i otel
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50 | grep -i otel
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments due to the addition of the new environment variable. The KEDA ScaledJob will be updated, and new jobs will include the variable.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.3
```
<!-- {% endraw %} -->
