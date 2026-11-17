<!-- {% raw %} -->
# Helm Upgrade from v2.6.3 to v2.7.0

## Topics ToC

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. OpenTelemetry ALLOW_INSECURE_OTEL Configuration](#1-opentelemetry-allow_insecure_otel-configuration)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v2.7.0 introduces a **modeled configuration setting** for the `ALLOW_INSECURE_OTEL` environment variable, which controls whether applications can ship telemetry to a plaintext (HTTP) OpenTelemetry collector in production environments.

**What changed:**

- The `lerian-common.otel.podEnv` helper now resolves `ALLOW_INSECURE_OTEL` from a **three-tier precedence hierarchy**: component-level `configmap.ALLOW_INSECURE_OTEL` > `global.observability.allowInsecureOtel` > default reason string
- A new helper `lerian-common.otel.allowInsecure` encapsulates the resolution logic
- Product charts that pass `context` and `configmap` to `lerian-common.otel.podEnv` now automatically inherit the environment-wide `global.observability.allowInsecureOtel` setting

**Why it matters:**

The **lib-observability** library refuses plaintext OTLP exporters in production unless `ALLOW_INSECURE_OTEL` carries a reason string. Previously, operators had to set this variable per component via `extraEnvVars` or component-specific `configmap` keys. With v2.7.0, operators can declare the setting **once** at the umbrella level (`global.observability.allowInsecureOtel`), and all components that ship to the node-local collector inherit it automatically.

**Backward compatibility:**

This is a **non-breaking change**. Existing deployments that do not pass `context` to `lerian-common.otel.podEnv` continue to emit the default reason string (`"node-local collector on the pod's own node"`). Product charts that already set `ALLOW_INSECURE_OTEL` via component `configmap` or `extraEnvVars` retain precedence over the new global setting.

## Features

### 1. OpenTelemetry ALLOW_INSECURE_OTEL Configuration

The `lerian-common.otel.allowInsecure` helper resolves the `ALLOW_INSECURE_OTEL` environment variable value from a modeled setting instead of requiring operators to inject it via `extraEnvVars`.

#### What changed

**Before (v2.6.3):**

The `lerian-common.otel.podEnv` helper emitted `ALLOW_INSECURE_OTEL` with a hardcoded default reason string when the OTLP endpoint used the `http://` scheme. Operators who needed to customize the reason (or refuse plaintext entirely) had to:

1. Pass `allowInsecure=false` to the helper to suppress the default emission
2. Set `ALLOW_INSECURE_OTEL` manually via component `extraEnvVars` or `configmap`

**After (v2.7.0):**

The helper resolves `ALLOW_INSECURE_OTEL` from a **three-tier precedence hierarchy**:

1. **Component-level:** `<component>.configmap.ALLOW_INSECURE_OTEL` (highest precedence)
2. **Environment-wide:** `global.observability.allowInsecureOtel` (umbrella setting)
3. **Default:** `"node-local collector on the pod's own node"` (fallback)

Product charts that pass `context` (root context `$`) and `configmap` (component configmap values) to `lerian-common.otel.podEnv` automatically inherit the global setting.

#### Configuration block

**Umbrella `values.yaml` (environment-wide setting):**

```yaml
global:
  observability:
    allowInsecureOtel: "node-local collector on the pod's own node"
```

**Component-level override (per-product `values.yaml`):**

```yaml
myapp:
  configmap:
    ALLOW_INSECURE_OTEL: "dev environment with local collector"
```

**Refusing plaintext (set to empty string or `false`):**

```yaml
global:
  observability:
    allowInsecureOtel: ""
```

> **Important:** Setting `allowInsecureOtel` to an empty string (`""`) or `false` **refuses** plaintext OTLP. Applications will fail to start if the collector endpoint uses `http://` and `ALLOW_INSECURE_OTEL` is empty.

#### Precedence

| Source | Precedence | Example |
|--------|------------|---------|
| Component `configmap.ALLOW_INSECURE_OTEL` | 1 (highest) | `myapp.configmap.ALLOW_INSECURE_OTEL: "custom reason"` |
| `global.observability.allowInsecureOtel` | 2 | `global.observability.allowInsecureOtel: "shared reason"` |
| Helper default | 3 (lowest) | `"node-local collector on the pod's own node"` |

> **Note:** A key explicitly set to `null` in YAML is treated as **unset** (not a refusal). To refuse plaintext, set the key to an empty string (`""`) or `false`.

#### Usage in product charts

**Before (v2.6.3):**

```yaml
# templates/deployment.yaml
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317) | nindent 10 }}
  {{- end }}
```

**After (v2.7.0):**

```yaml
# templates/deployment.yaml
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "context" $ "configmap" .Values.myapp.configmap "port" 4317) | nindent 10 }}
  {{- end }}
```

**Rendered output (with `global.observability.allowInsecureOtel` set):**

```yaml
- name: HOST_IP
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://$(HOST_IP):4317"
- name: ALLOW_INSECURE_OTEL
  value: "node-local collector on the pod's own node"
```

#### New helper: `lerian-common.otel.allowInsecure`

A standalone helper that resolves the `ALLOW_INSECURE_OTEL` value without emitting the full `podEnv` block. Product charts that need the value for custom logic can call this helper directly.

**Inputs:**

- `context` (required): root context (`$`)
- `configmap` (optional): component configmap values map

**Usage:**

```yaml
# templates/configmap.yaml
data:
  ALLOW_INSECURE_OTEL: {{ include "lerian-common.otel.allowInsecure" (dict "context" $ "configmap" .Values.myapp.configmap) | quote }}
```

#### Operational impact

**For operators managing umbrella deployments:**

If you want all components to use the same `ALLOW_INSECURE_OTEL` reason string, declare it once in your umbrella `values.yaml`:

```yaml
global:
  observability:
    allowInsecureOtel: "production environment with node-local collector"
```

All product charts that have adopted the updated `lerian-common.otel.podEnv` signature (passing `context` and `configmap`) will inherit this value automatically.

**For operators managing standalone product charts:**

No action required. If the product chart does not pass `context` to `lerian-common.otel.podEnv`, the helper continues to emit the default reason string (`"node-local collector on the pod's own node"`).

**For operators who already set `ALLOW_INSECURE_OTEL` via `extraEnvVars`:**

Your existing configuration retains precedence. The component-level `configmap.ALLOW_INSECURE_OTEL` (or `extraEnvVars` entry) overrides the global setting.

**For operators who want to refuse plaintext OTLP:**

Set `global.observability.allowInsecureOtel` to an empty string or `false`:

```yaml
global:
  observability:
    allowInsecureOtel: ""
```

Applications will fail to start if the collector endpoint uses `http://`. Ensure your collector is configured with TLS and update the `lerian-common.otel.podEnv` call to use `scheme: "https"`.

#### Legacy `allowInsecure` parameter

The `lerian-common.otel.podEnv` helper still accepts the legacy `allowInsecure` parameter for backward compatibility:

- `allowInsecure: false` (boolean) — suppress `ALLOW_INSECURE_OTEL` emission entirely (legacy behavior: the chart leaves the variable to `extraEnvVars`)
- `allowInsecure: "custom reason"` (string) — emit `ALLOW_INSECURE_OTEL` with the provided string (the caller resolved it from its own knob)

**Usage (legacy):**

```yaml
# templates/deployment.yaml (chart with custom knob)
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317 "allowInsecure" .Values.myapp.allowInsecureOtel) | nindent 10 }}
  {{- end }}
```

> **Note:** Passing `allowInsecure` as a string bypasses the modeled resolution logic. The helper emits the provided string directly without checking `global.observability.allowInsecureOtel` or component `configmap`.

## Configuration Reference

### New global configuration block

| Block | Field | Default | Description |
|-------|-------|---------|-------------|
| `global.observability` | `allowInsecureOtel` | `""` | Reason string for `ALLOW_INSECURE_OTEL` (environment-wide); empty or `false` refuses plaintext OTLP |

### New component configuration field

| Block | Field | Default | Description |
|-------|-------|---------|-------------|
| `<component>.configmap` | `ALLOW_INSECURE_OTEL` | `""` | Reason string for `ALLOW_INSECURE_OTEL` (component-level override); takes precedence over `global.observability.allowInsecureOtel` |

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_OTEL` | `"node-local collector on the pod's own node"` | Reason string that permits plaintext OTLP exporters in production; required by **lib-observability** when `OTEL_EXPORTER_OTLP_ENDPOINT` uses `http://` |

## Migration Steps

### For Operators (Umbrella Deployments)

If you manage Lerian product charts via an umbrella chart and want to adopt the shared `global.observability.allowInsecureOtel` setting:

1. **Add the `global.observability` block** to your umbrella `values.yaml`:

```yaml
global:
  observability:
    allowInsecureOtel: "node-local collector on the pod's own node"
```

2. **Remove component-level `ALLOW_INSECURE_OTEL` overrides** (optional) if you want all components to use the global setting. If a component has a custom reason, leave its `configmap.ALLOW_INSECURE_OTEL` entry intact (it will override the global setting).

3. **Ensure product charts have adopted the updated helper signature.** If a product chart does not pass `context` and `configmap` to `lerian-common.otel.podEnv`, it will not inherit the global setting. Coordinate with chart maintainers to update the helper call.

4. **Upgrade the umbrella chart:**

```bash
helm upgrade my-umbrella . -n lerian --values values.yaml
```

5. **Verify the environment variable** in running pods:

```bash
kubectl exec -n lerian deployment/myapp -- env | grep ALLOW_INSECURE_OTEL
```

Expected output:

```
ALLOW_INSECURE_OTEL=node-local collector on the pod's own node
```

### For Chart Maintainers (Product Charts)

If you maintain a Lerian product chart and want to adopt the modeled `ALLOW_INSECURE_OTEL` resolution:

1. **Update the `lerian-common.otel.podEnv` call** in your Deployment template to pass `context` and `configmap`:

**Before (v2.6.3):**

```yaml
# templates/deployment.yaml
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317) | nindent 10 }}
  {{- end }}
```

**After (v2.7.0):**

```yaml
# templates/deployment.yaml
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "context" $ "configmap" .Values.myapp.configmap "port" 4317) | nindent 10 }}
  {{- end }}
```

2. **(Optional) Expose `ALLOW_INSECURE_OTEL` in your chart's `values.yaml`** if you want operators to override it per component:

```yaml
myapp:
  configmap:
    # ALLOW_INSECURE_OTEL: "custom reason"
```

3. **Test render equivalence** (ensure output is identical for existing users who do not set `global.observability.allowInsecureOtel`):

```bash
helm template my-chart . --values test-values.yaml > before.yaml
# (after refactor)
helm template my-chart . --values test-values.yaml > after.yaml
diff before.yaml after.yaml
```

4. **Document the change** in your product chart's CHANGELOG (note: adopting the modeled setting is **not** a breaking change for operators).

### For Standalone Deployments

If you deploy a single product chart without an umbrella:

**No action required.** The helper continues to emit the default reason string (`"node-local collector on the pod's own node"`) when `global.observability.allowInsecureOtel` is not set.

If you want to customize the reason string for a standalone deployment, set it in the component's `configmap`:

```yaml
myapp:
  configmap:
    ALLOW_INSECURE_OTEL: "dev environment with local collector"
```

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.7.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of adopting v2.7.0, run `helm diff` on the **product charts** that consume it after updating their `lerian-common` dependency to v2.7.0.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.7.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` and run `helm dependency update`.
<!-- {% endraw %} -->
