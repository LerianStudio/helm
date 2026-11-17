<!-- {% raw %} -->
# Helm Upgrade from v2.2.0 to v2.2.1

## Topics

- **[Dependency Update](#dependency-update)**
- **[ALLOW_INSECURE_OTEL Configuration Model](#allow_insecure_otel-configuration-model)**
  - [What changed](#what-changed)
  - [Why it matters](#why-it-matters)
  - [Migration scenarios](#migration-scenarios)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Dependency Update

The chart now depends on a newer version of the `lerian-common-helm` library chart.

| Setting | v2.2.0 | v2.2.1 |
|---------|--------|--------|
| Chart version | `2.2.0` | `2.2.1` |
| lerian-common-helm dependency | `2.6.1` | `2.7.0` |

**Impact:** This is a patch-level chart update that bumps the `lerian-common-helm` library dependency from `2.6.1` to `2.7.0`. The library chart provides shared template helpers for workload boilerplate, observability configuration, and domain-level contracts. This update brings enhanced support for the `ALLOW_INSECURE_OTEL` configuration model described below.

**Migration required:** No action is required unless you are customizing the `ALLOW_INSECURE_OTEL` environment variable (see next section). The dependency update is transparent to operators who rely on default chart behavior.

---

## ALLOW_INSECURE_OTEL Configuration Model

### What changed

The chart now provides a structured configuration model for the `ALLOW_INSECURE_OTEL` environment variable, which controls whether the application accepts plaintext OTLP connections in production environments.

**Before (v2.2.0):**

The `ALLOW_INSECURE_OTEL` variable could only be set through:
- `streamingHub.extraEnvVars` (ConfigMap-backed)
- `streamingHub.secrets` (Secret-backed, chart-managed)
- An external secret (when `streamingHub.useExistingSecret: true`)

The chart template did not provide any default value or structured configuration path.

**After (v2.2.1):**

The chart now resolves `ALLOW_INSECURE_OTEL` through a three-tier precedence model:

1. **Per-component override:** `streamingHub.configmap.ALLOW_INSECURE_OTEL`
2. **Global observability contract:** `global.observability.allowInsecureOtel`
3. **Chart default:** `"node-local collector on the pod's own node"`

The new `global.observability.allowInsecureOtel` field is documented in the values.yaml schema:

```yaml
global:
  observability:
    # Empty by default → the template ships the defaults. Fields: otlpEndpoint
    # (OTEL_EXPORTER_OTLP_ENDPOINT), insecureExporter (OTEL_INSECURE_EXPORTER),
    # deploymentEnvironment (ENV_NAME), allowInsecureOtel (ALLOW_INSECURE_OTEL on the
    # plaintext node-local hop; see the README). The per-pod OTLP endpoint override is
    # governed separately by streamingHub.telemetry.enabled.
    allowInsecureOtel: ""
```

**New configuration fields:**

| Flag | Default | Description |
|------|---------|-------------|
| `global.observability.allowInsecureOtel` | `""` | Reason string for allowing plaintext OTLP in production (global default) |
| `streamingHub.configmap.ALLOW_INSECURE_OTEL` | (not set) | Per-component override for `ALLOW_INSECURE_OTEL` |

**Template logic changes:**

The `_deployment.tpl` template now includes precedence logic when `streamingHub.telemetry.enabled: true`:

```yaml
# Before (v2.2.0):
{{- if $sh.telemetry.enabled }}
# OTEL endpoint is overridden per-pod via the node host IP (DaemonSet
# collector pattern). Gated on the CHART-level streamingHub.telemetry.enabled.
{{- include "lerian-common.otel.podEnv" (dict "port" 4317) | nindent 12 }}
{{- end }}
```

```yaml
# After (v2.2.1):
{{- if $sh.telemetry.enabled }}
# OTEL endpoint is overridden per-pod via the node host IP (DaemonSet
# collector pattern). Gated on the CHART-level streamingHub.telemetry.enabled.
# ALLOW_INSECURE_OTEL is a modeled setting: streamingHub.configmap.ALLOW_INSECURE_OTEL,
# then global.observability.allowInsecureOtel, then the node-local reason; lerian-common
# resolves it and emits the one env entry. A key in streamingHub.extraEnvVars (rendered
# just above) or a non-empty streamingHub.secrets value (the legacy routes; the Secret only while the model is unset) still stands,
# so the helper adds no duplicate then. An existing Secret (useExistingSecret) is not
# visible to the chart, so a value there is overridden by this entry; set
# streamingHub.configmap.ALLOW_INSECURE_OTEL instead.
{{- $otelModelSet := or (not (kindIs "invalid" (index ($sh.configmap | default dict) "ALLOW_INSECURE_OTEL"))) (not (kindIs "invalid" (index (($.Values.global | default dict).observability | default dict) "allowInsecureOtel"))) }}
{{- $legacyAllow := or (hasKey ($sh.extraEnvVars | default dict) "ALLOW_INSECURE_OTEL") (and (not $otelModelSet) (not $sh.useExistingSecret) (ne (toString (index ($sh.secrets | default dict) "ALLOW_INSECURE_OTEL" | default "")) "")) }}
{{- include "lerian-common.otel.podEnv" (dict "context" $ "configmap" $sh.configmap "port" 4317 "allowInsecure" (not $legacyAllow)) | nindent 12 }}
{{- end }}
```

### Why it matters

**Production safety:** The `lib-observability` library (used by the streaming-hub application) refuses to establish plaintext OTLP connections in production environments unless `ALLOW_INSECURE_OTEL` contains a non-empty reason string. Without this variable, the application will fail to boot when `streamingHub.telemetry.enabled: true` and the deployment environment is production.

**Node-local collector pattern:** When using the DaemonSet collector pattern (`streamingHub.telemetry.enabled: true`), each pod ships telemetry to `http://$(HOST_IP):4317` in plaintext. This is a same-node hop (pod → node-local collector), which is considered acceptable in production if properly documented. The chart now provides a default reason string: `"node-local collector on the pod's own node"`.

**Precedence model:** The new model allows operators to:
- Set a global default reason for all charts in the cluster (`global.observability.allowInsecureOtel`)
- Override per component (`streamingHub.configmap.ALLOW_INSECURE_OTEL`)
- Explicitly refuse plaintext OTLP by setting either field to `""` or `"false"`

**Legacy compatibility:** Existing configurations using `streamingHub.extraEnvVars.ALLOW_INSECURE_OTEL` or `streamingHub.secrets.ALLOW_INSECURE_OTEL` continue to work. The chart detects these legacy paths and skips injecting the modeled value to avoid duplicates.

> **Warning:** If you use an external secret (`streamingHub.useExistingSecret: true`) and that secret contains `ALLOW_INSECURE_OTEL`, the chart cannot detect it. The modeled value will override the secret entry. Migrate to `streamingHub.configmap.ALLOW_INSECURE_OTEL` instead.

### Migration scenarios

#### Scenario 1: Default behavior (no telemetry override)

If you have not enabled `streamingHub.telemetry.enabled`, this change has no impact. The application uses the global `OTEL_EXPORTER_OTLP_ENDPOINT` from `global.observability.otlpEndpoint`, and no `ALLOW_INSECURE_OTEL` variable is injected.

**Configuration (v2.2.0 and v2.2.1):**

```yaml
streamingHub:
  telemetry:
    enabled: false
```

**Action required:** None.

---

#### Scenario 2: Node-local collector with default reason

If you have enabled `streamingHub.telemetry.enabled: true` and want to use the chart's default reason string, no configuration change is required.

**Configuration (v2.2.1):**

```yaml
streamingHub:
  telemetry:
    enabled: true

global:
  observability:
    allowInsecureOtel: ""  # Empty → chart default applies
```

**Behavior:** The chart injects:

```yaml
env:
  - name: ALLOW_INSECURE_OTEL
    value: "node-local collector on the pod's own node"
```

**Action required:** None. The chart now provides a production-safe default.

---

#### Scenario 3: Custom reason string (global)

If you want to provide a custom reason string for all charts in your cluster, set `global.observability.allowInsecureOtel`.

**Configuration (v2.2.1):**

```yaml
global:
  observability:
    allowInsecureOtel: "plaintext hop to node-local OTEL collector DaemonSet"

streamingHub:
  telemetry:
    enabled: true
```

**Behavior:** The chart injects:

```yaml
env:
  - name: ALLOW_INSECURE_OTEL
    value: "plaintext hop to node-local OTEL collector DaemonSet"
```

**Action required:** Add the `global.observability.allowInsecureOtel` field to your values.yaml.

---

#### Scenario 4: Custom reason string (per-component)

If you want to override the reason string for the streaming-hub component only, set `streamingHub.configmap.ALLOW_INSECURE_OTEL`.

**Configuration (v2.2.1):**

```yaml
streamingHub:
  telemetry:
    enabled: true
  configmap:
    ALLOW_INSECURE_OTEL: "streaming-hub uses node-local collector on same host"
```

**Behavior:** The chart injects:

```yaml
env:
  - name: ALLOW_INSECURE_OTEL
    valueFrom:
      configMapKeyRef:
        name: streaming-hub
        key: ALLOW_INSECURE_OTEL
```

**Action required:** Add the `streamingHub.configmap.ALLOW_INSECURE_OTEL` field to your values.yaml.

---

#### Scenario 5: Refuse plaintext OTLP

If you want to explicitly refuse plaintext OTLP (e.g., because you have a TLS-enabled collector), set either field to `""` or `"false"`.

**Configuration (v2.2.1):**

```yaml
streamingHub:
  telemetry:
    enabled: true
  configmap:
    ALLOW_INSECURE_OTEL: "false"
```

**Behavior:** The chart injects:

```yaml
env:
  - name: ALLOW_INSECURE_OTEL
    valueFrom:
      configMapKeyRef:
        name: streaming-hub
        key: ALLOW_INSECURE_OTEL
```

The application will refuse to boot in production with this configuration unless the OTLP endpoint uses TLS.

> **Important:** Setting `ALLOW_INSECURE_OTEL: "false"` is a refusal, not an omission. The application will fail to start if the endpoint is plaintext.

**Action required:** Add the `streamingHub.configmap.ALLOW_INSECURE_OTEL: "false"` field to your values.yaml and ensure your OTLP endpoint uses TLS.

---

#### Scenario 6: Migrate from legacy extraEnvVars

If you currently set `ALLOW_INSECURE_OTEL` via `streamingHub.extraEnvVars`, the chart will continue to honor it. However, the new model is preferred for consistency.

**Before (v2.2.0):**

```yaml
streamingHub:
  telemetry:
    enabled: true
  extraEnvVars:
    ALLOW_INSECURE_OTEL: "node-local collector"
```

**After (v2.2.1, recommended):**

```yaml
streamingHub:
  telemetry:
    enabled: true
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector"
```

**Action required:** Move the `ALLOW_INSECURE_OTEL` key from `streamingHub.extraEnvVars` to `streamingHub.configmap`. Remove the old key to avoid confusion.

---

#### Scenario 7: Migrate from legacy secrets

If you currently set `ALLOW_INSECURE_OTEL` via `streamingHub.secrets`, the chart will continue to honor it **only if the modeled fields are unset**. Once you set `streamingHub.configmap.ALLOW_INSECURE_OTEL` or `global.observability.allowInsecureOtel`, the modeled value takes precedence.

**Before (v2.2.0):**

```yaml
streamingHub:
  telemetry:
    enabled: true
  secrets:
    ALLOW_INSECURE_OTEL: "node-local collector"
```

**After (v2.2.1, recommended):**

```yaml
streamingHub:
  telemetry:
    enabled: true
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector"
```

**Action required:** Move the `ALLOW_INSECURE_OTEL` key from `streamingHub.secrets` to `streamingHub.configmap`. Remove the old key from the secret to avoid confusion.

> **Note:** `ALLOW_INSECURE_OTEL` is not a sensitive credential. It is a reason string for audit purposes. Storing it in a ConfigMap is appropriate.

---

#### Scenario 8: External secret (useExistingSecret)

If you use an external secret (`streamingHub.useExistingSecret: true`) and that secret contains `ALLOW_INSECURE_OTEL`, the chart cannot detect it. The modeled value will override the secret entry.

**Before (v2.2.0):**

```yaml
streamingHub:
  telemetry:
    enabled: true
  useExistingSecret: true
  existingSecretName: "streaming-hub-external"
```

External secret `streaming-hub-external` contains:

```yaml
data:
  ALLOW_INSECURE_OTEL: "node-local collector"
```

**After (v2.2.1, required migration):**

```yaml
streamingHub:
  telemetry:
    enabled: true
  useExistingSecret: true
  existingSecretName: "streaming-hub-external"
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector"
```

Remove `ALLOW_INSECURE_OTEL` from the external secret to avoid confusion.

**Action required:**

1. Add `streamingHub.configmap.ALLOW_INSECURE_OTEL` to your values.yaml with the same value from your external secret.
2. Remove the `ALLOW_INSECURE_OTEL` key from your external secret (the chart will now inject it via ConfigMap).

> **Warning:** If you do not migrate, the chart will inject the default reason string (`"node-local collector on the pod's own node"`), overriding your external secret value.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm -n streaming-hub --version 2.2.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm -n streaming-hub --version 2.2.1
```
<!-- {% endraw %} -->
