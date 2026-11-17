<!-- {% raw %} -->
# Helm Upgrade from v2.6.2 to v2.6.3

## Topics ToC

- **[Fixes](#fixes)**
  - [1. OpenTelemetry Insecure Exporter Support](#1-opentelemetry-insecure-exporter-support)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. OpenTelemetry Insecure Exporter Support

The `lerian-common.otel.podEnv` helper now emits `ALLOW_INSECURE_OTEL` by default for its HTTP exporter endpoint. This can satisfy the plaintext-exporter gate in applications using a compatible lib-observability version; it does not prove application startup. Adopting it also changes the security posture of consumers that previously refused plaintext, so review the transport policy before upgrading the product chart.

#### What changed

The `lerian-common.otel.podEnv` template helper has been enhanced to:

1. Emit `ALLOW_INSECURE_OTEL` with a descriptive reason when `scheme` is `http` (default)
2. Skip emitting `ALLOW_INSECURE_OTEL` when `scheme` is `https`
3. Accept a new optional input parameter `allowInsecure` (default: `true`) to suppress emission when the operator already sets this variable elsewhere

#### Why it matters

**Runtime prerequisite:** For example, lib-observability v4.8.1 rejects enabled plaintext exporters in production-like environments unless `ALLOW_INSECURE_OTEL` carries an accepted reason. Verify the actual consumer image/library and enabled telemetry path; this library chart ships no application image and does not certify every consumer's startup behavior.

**Chart behavior:** The helper sets `ALLOW_INSECURE_OTEL="node-local collector on the pod's own node"` by default with HTTP. That reason is not a security assessment: verify the endpoint, network controls and policy. Use a validated TLS collector where plaintext is not permitted. Other application startup requirements still apply.

#### Operational impact

> **Important:** This is a library chart (type: library) that is consumed as a dependency by other charts. It does not deploy resources directly.

**For operators using product charts that consume this helper:**

- **No action required** if your product chart has not yet adopted the `lerian-common.otel.podEnv` helper
- **Review required** when the product adopts this dependency: default helper settings now permit plaintext rather than preserving a previous refusal. Verify the shipped application's library version and all other startup prerequisites.
- **Additional coordination required** if you already set `ALLOW_INSECURE_OTEL` via ConfigMap, `extraEnvVars`, or a chart-specific knob (see [Migration Steps](#migration-steps) below)

**For chart maintainers:**

An explicit container `env` entry overrides the same key imported with `envFrom`. Thus the new default can override an operator's ConfigMap refusal without creating a duplicate list entry. If the product owns the value elsewhere, pass `allowInsecure=false` and emit/import the intended value exactly once. Duplicate explicit `env` entries are a separate apply/patch hazard; do not rely on their ordering.

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

   - Review the product's plaintext policy before adoption. The helper adds a reason string, not a general startup guarantee.

3. **If you DO set `ALLOW_INSECURE_OTEL` via values:**

   - **Option 1 (only if the default reason matches approved policy):** Remove only the custom `ALLOW_INSECURE_OTEL` entry and preserve every unrelated environment variable. The following minimal example has no other entries:

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
     - name: lerian-common-helm
       version: 2.6.3
       repository: oci://ghcr.io/lerianstudio
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

   Inspect the parsed manifest per applicable container, including `envFrom` sources: grep alone does not prove uniqueness or effective precedence. Expect one explicit entry only when the helper owns an HTTP setting; HTTPS and operator-owned paths can emit none from this helper.

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

Do not install, diff or upgrade this library as a release: Helm libraries are dependencies, not deployable products. Preview the actual consumer after updating its dependency and lock through the normal chart-development process. Resolve and verify the intended locked package; `helm dependency update` can change other dependencies too.

```bash
helm template my-product ./my-product -n product --is-upgrade -f intended-values.yaml > target-private.yaml
helm diff upgrade my-product ./my-product -n product --reset-values -f intended-values.yaml --suppress-secrets
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

Use a private restricted directory (`umask 077`) for values, backups and rendered output. `intended-values.yaml` must contain the complete intended consumer configuration, preserving unrelated settings, image pins and Secret references: reset discards omitted overrides. If the consumer relies on cluster `lookup`, use its documented lookup-aware server preview and preserve current bundled-store passwords privately; never decode credentials to terminal or use CLI `--set`. Client rendering can fail or generate misleading credential/checksum differences. No cluster/server preview is certified here.

## Command to upgrade

```bash
helm upgrade my-product ./my-product -n product --reset-values -f intended-values.yaml
```

Use the verified consumer release/namespace/path instead of these illustrative names. Compare all consumer pod templates, checksums, labels, images, selectors and hooks before applying; adopting a library alone does not prove which workloads roll. Take consistent private data/configuration backups and rehearse recovery first. Verify rollouts and enabled integrations afterward. Helm rollback does not restore data or guarantee old-binary compatibility. Exact published library packages 2.6.2/2.6.3 and synthetic consumer renders establish helper output, not application boot, real dependency build, live upgrade or restore. There are no standalone workloads, ports, licence gates, migrations or NOTES in this library; those belong to the chosen consumer.
<!-- {% endraw %} -->
