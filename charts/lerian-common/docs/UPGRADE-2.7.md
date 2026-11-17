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

For example, **lib-observability v4.8.1** refuses enabled plaintext OTLP exporters in production-like environments without an accepted reason. Library 2.6.3 already emitted a default reason; 2.7.0 adds modeled resolution. A shared global setting is inherited only by consumers that pass `context` and do not override it. Verify the exact consumer image/library and startup path; this library ships no application image.

**Backward compatibility:**

Calls without `context` continue to emit the default reason string (`"node-local collector on the pod's own node"`). With `context`, the helper reads the explicitly passed component ConfigMap and then the global setting. It does not read `extraEnvVars`. An explicit container `env` entry overrides the same key imported with `envFrom`; duplicate explicit entries are not a safe precedence mechanism. Check the consumer's call and resulting manifest before calling adoption non-breaking.

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

> **Important:** With modeled resolution actually enabled and no higher-priority component/caller override, these values emit an empty string or `"false"`. Compatible lib-observability releases refuse plaintext in production-like environments when telemetry uses that gate. This is not a universal boot guarantee: verify the exact consumer image, library version, environment and enabled telemetry path. Rendering alone does not exercise startup.

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

`extraEnvVars` is not an input to this helper. Preserve unrelated entries and coordinate with the consumer maintainer: pass the desired component ConfigMap explicitly, or suppress helper emission with boolean `allowInsecure: false` and own the value elsewhere exactly once. An `envFrom` ConfigMap does not override an explicit helper-generated `env` value.

**For operators who want to refuse plaintext OTLP:**

Set `global.observability.allowInsecureOtel` to an empty string or `false`:

```yaml
global:
  observability:
    allowInsecureOtel: ""
```

Verify that the consumer passes `context` and has no higher-priority component/caller override; otherwise this global setting is not effective. Compatible applications in production-like environments refuse their enabled plaintext telemetry path. For TLS, configure a verified TLS collector and trust, then use `scheme: "https"`; changing the scheme alone does not provision TLS.

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
| `global.observability` | `allowInsecureOtel` | Unset; helper fallback reason | Presence-aware setting; explicit empty or `false` is a refusal, subject to higher-priority overrides |

### New component configuration field

| Block | Field | Default | Description |
|-------|-------|---------|-------------|
| `<component>.configmap` | `ALLOW_INSECURE_OTEL` | Unset; falls through | Only the ConfigMap passed to the helper is read; explicit empty/false overrides the global value |

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_OTEL` | `"node-local collector on the pod's own node"` | Helper fallback reason for HTTP; verify the actual application's enabled telemetry and production policy |

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
helm upgrade my-umbrella . -n lerian --reset-values --values values.yaml
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

4. Document the consumer's actual compatibility and rollout impact. A new explicit helper value can override a previously imported ConfigMap value; do not assume adoption is non-breaking.

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

Do not install, diff or upgrade the library as a release. Update the actual consumer dependency named `lerian-common-helm` to 2.7.0 through its normal development/review process and verify the resulting lock/package; dependency update can change other packages too. Use the verified consumer release/path/namespace below, not the library name.

```bash
helm template my-product ./my-product -n product --is-upgrade -f intended-values.yaml > target-private.yaml
helm diff upgrade my-product ./my-product -n product --reset-values -f intended-values.yaml --suppress-secrets
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

Use a restricted private directory (`umask 077`); rendered manifests and values can contain credentials. Both `intended-values.yaml` above and `values.yaml` in the umbrella example must be complete intended configurations, preserving unrelated settings, pins and Secret references: reset discards omissions. For consumers relying on `lookup`, follow their server-preview/current-bundled-password requirements privately, never decoded terminal output or CLI `--set`. Client-only previews can fail or synthesize misleading credential/checksum changes. No server preview was exercised here.

## Command to upgrade

```bash
helm upgrade my-product ./my-product -n product --reset-values -f intended-values.yaml
```

Compare all actual consumer pod templates, checksums, labels, images, selectors and hooks; a dependency bump alone does not establish rollout. Preserve consistent private backups and rehearse recovery before applying, then verify rollouts and enabled integrations. Helm rollback does not restore data or guarantee old-binary compatibility. Exact published 2.6.3/2.7.0 packages and synthetic consumer renders prove helper output only, not application boot, real dependency build, cluster upgrade or restore. This library has no standalone workloads, ports, licence gates, migrations or NOTES; validate those in the chosen consumer.
<!-- {% endraw %} -->
