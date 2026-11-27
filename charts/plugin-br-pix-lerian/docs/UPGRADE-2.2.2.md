<!-- {% raw %} -->
# Helm Upgrade from v2.2.1 to v2.2.2

## Topics

- **[Fixes](#fixes)**
  - [1. Library Chart Dependency Update](#1-library-chart-dependency-update)
  - [2. ALLOW_INSECURE_OTEL Configuration Support](#2-allow_insecure_otel-configuration-support)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Library Chart Dependency Update

**What changed:**

The `lerian-common-helm` library chart dependency has been updated from version `2.6.0` to `2.7.0`.

| Setting | v2.2.1 | v2.2.2 |
|---------|--------|--------|
| `dependencies[0].version` | `2.6.0` | `2.7.0` |

**Why it matters:**

The library chart provides shared workload fragments (Service, HPA, ServiceAccount, scheduling helpers, observability configuration) used by all components. The update to `2.7.0` includes the `lerian-common.otel.allowInsecure` helper template that enables the new `ALLOW_INSECURE_OTEL` configuration support described below.

**How to handle it:**

No action is required. Helm will automatically fetch the updated library chart from the OCI registry during the upgrade.

**Before (v2.2.1) Chart.yaml:**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.6.0"
    repository: "oci://ghcr.io/lerianstudio"
```

**After (v2.2.2) Chart.yaml:**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.7.0"
    repository: "oci://ghcr.io/lerianstudio"
```

### 2. ALLOW_INSECURE_OTEL Configuration Support

**What changed:**

The chart now supports configuring `ALLOW_INSECURE_OTEL` for all components to permit plaintext OpenTelemetry exports in production environments. This variable is required by `lib-observability` when telemetry is enabled without an explicit endpoint (defaulting to the node-local collector at `$(HOST_IP):4317` in plaintext), and the deployment environment is production.

Three new configuration tiers have been introduced:

1. **Global configuration**: `global.observability.allowInsecureOtel` — applies to all components
2. **Component-specific configuration**: `<component>.configmap.ALLOW_INSECURE_OTEL` — overrides the global setting
3. **Default reason**: When using the chart's node-local collector hop, the chart provides a default reason: `"node-local collector on the pod's own node"`

**Why it matters:**

When telemetry is enabled (`global.observability.enabled: true`) without an explicit `otlpEndpoint`, the chart configures components to ship telemetry to a node-local collector at `$(HOST_IP):4317` in plaintext. In production environments, `lib-observability` refuses plaintext exports unless `ALLOW_INSECURE_OTEL` carries a reason string explaining why insecure transport is acceptable.

**Without this configuration, components will fail to boot in production** when using the node-local collector hop.

**How to handle it:**

#### Option 1: Accept the default reason (recommended for node-local collector)

If you are using the chart's default node-local collector configuration (telemetry enabled, no explicit endpoint), no action is required. The chart will automatically set:

```yaml
ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

This default reason is applied when:
- `global.observability.enabled: true`
- `global.observability.otlpEndpoint` is not set (or empty)
- Neither `global.observability.allowInsecureOtel` nor `<component>.configmap.ALLOW_INSECURE_OTEL` is set

#### Option 2: Set a custom reason globally

If you want to provide your own reason for all components, set it at the global level:

```yaml
global:
  observability:
    enabled: true
    allowInsecureOtel: "internal mesh with mTLS at ingress"
```

#### Option 3: Set a custom reason per component

If you need different reasons for different components, override at the component level:

```yaml
spi:
  configmap:
    ALLOW_INSECURE_OTEL: "dedicated secure network segment"

dictHub:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on isolated node pool"
```

#### Option 4: Refuse insecure OTEL (production with secure endpoint)

If you have a secure OTEL endpoint configured, you can explicitly refuse insecure transport by setting the value to an empty string or `"false"`:

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector.monitoring.svc.cluster.local:4317"
    allowInsecureOtel: "false"
```

> **Warning:** Setting `ALLOW_INSECURE_OTEL` to `""` or `"false"` is a refusal. If the application attempts to use plaintext transport in production, it will refuse to boot.

#### Option 5: Unset the variable (use application default)

To leave the variable unset and let the application use its own default behavior, set it to `null`:

```yaml
global:
  observability:
    allowInsecureOtel: null
```

**Configuration precedence:**

The chart resolves `ALLOW_INSECURE_OTEL` in the following order:

1. `<component>.configmap.ALLOW_INSECURE_OTEL` (component-specific override)
2. `global.observability.allowInsecureOtel` (global setting)
3. `"node-local collector on the pod's own node"` (chart default for node-local hop)

**After (v2.2.2) values.yaml:**

```yaml
global:
  # -- Observability (OTel collector) shared by ALL components: enabled / otlpEndpoint
  #    / deploymentEnvironment -> ENABLE_TELEMETRY / OTEL_EXPORTER_OTLP_ENDPOINT /
  #    OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT; allowInsecureOtel -> ALLOW_INSECURE_OTEL on
  #    the plaintext node-local hop (see the README). Example:
  #    observability: { enabled: true, otlpEndpoint: "otel-collector:4317" }
  observability: {}
  # example ↓ (uncomment & fill; comments render nothing = default stays empty):
  #   enabled: true
  #   allowInsecureOtel: "node-local collector on the pod's own node"
```

**Component-level configuration example:**

```yaml
spi:
  configmap: {}
  # ALLOW_INSECURE_OTEL — with telemetry on and no endpoint set, the Deployment
  # ships to the node-local collector at $(HOST_IP):4317 in plaintext, which
  # lib-observability refuses in production unless ALLOW_INSECURE_OTEL carries a
  # reason. The chart sets it on the container: configmap.ALLOW_INSECURE_OTEL,
  # else global.observability.allowInsecureOtel, else "node-local collector on
  # the pod's own node". "" or "false" refuses (the app then will not boot on the
  # node-local hop in production); null is unset. See the README.
  # configmap:
  #   ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

**Affected components:**

All application components now support `ALLOW_INSECURE_OTEL` configuration:

- `spi`
- `spiSystemplane`
- `adapterProviderMock`
- `dictHub`
- `dictHubVsync`
- `dictProxy`
- `dictSystemplane`
- `cobHub`
- `cobProxy`
- `cobSystemplane`
- `adapterLerian`
- `adapterLerianSystemplane`
- `pixauto`
- `pixautoSystemplane`

**Template changes:**

The chart now includes two new helper templates in `_helpers.tpl`:

1. **`plugin-br-pix-lerian.otelAllowInsecure.env`** — Emits the `ALLOW_INSECURE_OTEL` environment variable entry in Deployments
2. **`plugin-br-pix-lerian.otelAllowInsecure.configmap`** — Emits the `ALLOW_INSECURE_OTEL` ConfigMap entry when using an operator-provided endpoint

**Before (v2.2.1) deployment.yaml:**

```yaml
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "$(HOST_IP):4317"
```

**After (v2.2.2) deployment.yaml:**

```yaml
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "$(HOST_IP):4317"
{{- with (include "plugin-br-pix-lerian.otelAllowInsecure.env" (dict "context" $ "values" $values "configmap" $cm "nodeLocal" true)) }}
{{- . | nindent 12 }}
{{- end }}
```

**Before (v2.2.1) configmap.yaml:**

```yaml
{{- range $key, $value := $cm }}
{{- if not (hasKey $enumerated $key) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
```

**After (v2.2.2) configmap.yaml:**

```yaml
{{- range $key, $value := $cm }}
{{- /* A null ALLOW_INSECURE_OTEL is unset, not a refusal: skip it so the global
   value below (or the Deployment's default) applies. Other keys are untouched. */}}
{{- if and (not (hasKey $enumerated $key)) (not (and (eq $key "ALLOW_INSECURE_OTEL") (kindIs "invalid" $value))) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- /* ALLOW_INSECURE_OTEL from global.observability.allowInsecureOtel, for the case
   the Deployment does not ship the node-local endpoint (operator endpoint). */}}
{{- with (include "plugin-br-pix-lerian.otelAllowInsecure.configmap" (dict "context" $ "values" $values "configmap" $cm)) }}
{{ . }}
{{- end }}
```

**New environment variable:**

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_OTEL` | `"node-local collector on the pod's own node"` (when using node-local hop) | Reason string permitting plaintext OTEL exports in production. Required by `lib-observability` when shipping to `$(HOST_IP):4317` in a production deployment environment. Set to `""` or `"false"` to refuse insecure transport; set to `null` to leave unset. |

**Legacy configuration routes:**

The chart preserves backward compatibility with existing configuration methods:

1. **`<component>.extraEnvVars.ALLOW_INSECURE_OTEL`** — If set, the chart will not emit a duplicate environment variable entry
2. **`<component>.secrets.ALLOW_INSECURE_OTEL`** — If set (and not using `useExistingSecret`), the chart will emit an explicit environment variable entry to ensure the ConfigMap/model value wins over the Secret value

> **Note:** When using `useExistingSecret`, the chart cannot see the Secret contents. On the node-local branch, the chart will emit the environment variable entry and override any value in the Secret.

## Preview changes before upgrading

```bash
helm diff upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.2.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.2.2
```
<!-- {% endraw %} -->
