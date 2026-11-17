<!-- {% raw %} -->
# Helm Upgrade from v2.6.2 to v2.6.3

## Topics ToC

- **[Fixes](#fixes)**
  - [1. OpenTelemetry Insecure Exporter Support](#1-opentelemetry-insecure-exporter-support)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. OpenTelemetry Insecure Exporter Support

The `lerian-common.otel.podEnv` helper now automatically emits the `ALLOW_INSECURE_OTEL` environment variable when using plaintext (HTTP) OpenTelemetry exporters. This fixes a boot failure where applications using lib-observability would exit in production environments when connecting to a node-local collector over plaintext.

#### What changed

The `lerian-common.otel.podEnv` template helper has been enhanced to:

1. Emit `ALLOW_INSECURE_OTEL` with a descriptive reason when `scheme` is `http` (default)
2. Skip emitting `ALLOW_INSECURE_OTEL` when `scheme` is `https`
3. Accept a new optional input parameter `allowInsecure` (default: `true`) to suppress emission when the operator already sets this variable elsewhere

#### Why it matters

**Problem:** The lib-observability library refuses plaintext OTLP exporters in production unless `ALLOW_INSECURE_OTEL` carries a reason string. The node-local collector hop (pod → DaemonSet on the same node) uses plaintext for performance, but without `ALLOW_INSECURE_OTEL`, applications would exit at boot with an error.

**Solution:** The helper now automatically sets `ALLOW_INSECURE_OTEL="node-local collector on the pod's own node"` when using HTTP scheme, allowing the application to start successfully while documenting why insecure transport is acceptable in this specific case.

#### Operational impact

> **Important:** This is a library chart (type: library) that is consumed as a dependency by other charts. It does not deploy resources directly.

**For operators using product charts that consume this helper:**

- **No action required** if your product chart has not yet adopted the `lerian-common.otel.podEnv` helper
- **No action required** if your product chart uses the helper with default settings — the new behavior is automatic and fixes the boot failure
- **Action required** only if you already set `ALLOW_INSECURE_OTEL` via ConfigMap, `extraEnvVars`, or a chart-specific knob (see [Migration Steps](#migration-steps) below)

**For chart maintainers:**

If your product chart already sets `ALLOW_INSECURE_OTEL` through another mechanism (ConfigMap, `extraEnvVars`, or a dedicated values field), you must pass `allowInsecure=false` to prevent duplicate environment variable entries, which would break the Kubernetes apply:

**Before (v2.6.2):**

```yaml
# templates/deployment.yaml
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317) | nindent 10 }}
  {{- end }}
  # Operator sets ALLOW_INSECURE_OTEL via extraEnvVars or configmap
```

**After (v2.6.3):**

```yaml
# templates/deployment.yaml
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317 "allowInsecure" false) | nindent 10 }}
  {{- end }}
  # Operator's ALLOW_INSECURE_OTEL value stands; helper does not emit it
```

#### New environment variable

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_OTEL` | `"node-local collector on the pod's own node"` | Reason string allowing plaintext OTLP exporter; emitted automatically when `scheme` is `http` (unless `allowInsecure=false`) |

#### New template input parameter

The `lerian-common.otel.podEnv` helper accepts a new optional input:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `allowInsecure` | bool | `true` | Emit `ALLOW_INSECURE_OTEL` when using HTTP scheme; set to `false` when the operator already sets this variable via ConfigMap, `extraEnvVars`, or a chart knob |

#### Migration steps

**For operators:**

1. **Check if you already set `ALLOW_INSECURE_OTEL`** in your product chart values (via `extraEnvVars`, ConfigMap overrides, or a chart-specific field).

2. **If you do NOT set `ALLOW_INSECURE_OTEL` anywhere:**

   - **No action required.** Upgrade to v2.6.3 and the helper will automatically emit the variable, fixing the boot failure.

3. **If you DO set `ALLOW_INSECURE_OTEL` via values:**

   - **Option 1 (recommended):** Remove your custom `ALLOW_INSECURE_OTEL` setting and let the helper manage it automatically:

     **Before (v2.6.2):**

     ```yaml
     # values.yaml
     myapp:
       extraEnvVars:
         - name: ALLOW_INSECURE_OTEL
           value: "custom reason"
     ```

     **After (v2.6.3):**

     ```yaml
     # values.yaml
     myapp:
       extraEnvVars: []
       # ALLOW_INSECURE_OTEL now emitted by lerian-common.otel.podEnv
     ```

   - **Option 2:** Keep your custom value and coordinate with the chart maintainer to pass `allowInsecure=false` to the helper (see chart maintainer instructions above). This prevents duplicate environment variable entries.

**For chart maintainers:**

1. **Update your product chart's `Chart.yaml` dependency** to use `lerian-common` v2.6.3:

   ```yaml
   dependencies:
     - name: lerian-common
       version: 2.6.3
       repository: oci://registry-1.docker.io/lerianstudio
   ```

2. **Update dependencies:**

   ```bash
   helm dependency update
   ```

3. **If your chart provides a way for operators to set `ALLOW_INSECURE_OTEL`** (via `extraEnvVars`, ConfigMap overrides, or a dedicated field), pass `allowInsecure=false` to the helper:

   ```yaml
   # templates/deployment.yaml
   env:
     {{- if (index .Values "otel-collector-lerian").enabled }}
     {{- include "lerian-common.otel.podEnv" (dict "port" 4317 "allowInsecure" false) | nindent 10 }}
     {{- end }}
   ```

4. **If your chart does NOT provide a way to set `ALLOW_INSECURE_OTEL`:**

   - **No template changes required.** The helper will automatically emit the variable with default `allowInsecure=true`.

5. **Test the upgrade** to ensure no duplicate environment variable entries:

   ```bash
   helm template my-chart . --values test-values.yaml | grep -A 2 "ALLOW_INSECURE_OTEL"
   ```

   You should see exactly **one** `ALLOW_INSECURE_OTEL` entry per container.

#### Configuration example

**Usage with default behavior (automatic emission):**

```yaml
# templates/deployment.yaml
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317) | nindent 10 }}
  {{- end }}
```

**Rendered output:**

```yaml
env:
  - name: HOST_IP
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://$(HOST_IP):4317"
  - name: ALLOW_INSECURE_OTEL
    value: "node-local collector on the pod's own node"
```

**Usage with HTTPS scheme (no emission):**

```yaml
# templates/deployment.yaml
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317 "scheme" "https") | nindent 10 }}
  {{- end }}
```

**Rendered output:**

```yaml
env:
  - name: HOST_IP
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "https://$(HOST_IP):4317"
  # ALLOW_INSECURE_OTEL not emitted (HTTPS is secure)
```

**Usage with operator-managed ALLOW_INSECURE_OTEL (suppressed emission):**

```yaml
# templates/deployment.yaml
env:
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317 "allowInsecure" false) | nindent 10 }}
  {{- end }}
  # Operator's ALLOW_INSECURE_OTEL from extraEnvVars or configmap follows
```

**Rendered output:**

```yaml
env:
  - name: HOST_IP
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://$(HOST_IP):4317"
  # ALLOW_INSECURE_OTEL not emitted (allowInsecure=false)
  - name: ALLOW_INSECURE_OTEL
    value: "custom operator reason"
```

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.6.3 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of this fix, run `helm diff` on the **product charts** that consume the `lerian-common.otel.podEnv` helper.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.6.3 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `2.6.3` and run `helm dependency update`, then upgrade your product chart.
<!-- {% endraw %} -->
