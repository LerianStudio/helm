<!-- {% raw %} -->
# Helm Upgrade from v1.5.0 to v1.5.1

## Topics

- **[Dependency Updates](#dependency-updates)**
  - [lerian-common-helm upgrade to 2.7.0](#lerian-common-helm-upgrade-to-270)
- **[Configuration Changes](#configuration-changes)**
  - [New ALLOW_INSECURE_OTEL configuration model](#new-allow_insecure_otel-configuration-model)
  - [Enhanced observability configuration](#enhanced-observability-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Dependency Updates

### lerian-common-helm upgrade to 2.7.0

| Setting | v1.5.0 | v1.5.1 |
|---------|--------|--------|
| `lerian-common-helm` version | `2.1.2` | `2.7.0` |

The chart now depends on `lerian-common-helm` version `2.7.0`, which introduces enhanced OpenTelemetry configuration helpers and improved security modeling for insecure connections.

**Chart.yaml dependency change:**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.7.0"
    repository: "oci://ghcr.io/lerianstudio"
```

This dependency upgrade enables the new `ALLOW_INSECURE_OTEL` configuration model described below.

---

## Configuration Changes

### New ALLOW_INSECURE_OTEL configuration model

The chart now provides a structured configuration model for the `ALLOW_INSECURE_OTEL` environment variable, which controls whether the application accepts plaintext OpenTelemetry connections to node-local collectors in production environments.

**What changed:**

In v1.5.0, operators had to set `ALLOW_INSECURE_OTEL` through one of these legacy routes:
- `brSisbajud.secrets.ALLOW_INSECURE_OTEL`
- `brSisbajud.extraEnvVars` array entry
- An existing external Secret (via `brSisbajud.useExistingSecret`)

In v1.5.1, the chart introduces a **modeled configuration hierarchy** that resolves `ALLOW_INSECURE_OTEL` from multiple sources in order of precedence:

1. `brSisbajud.configmap.ALLOW_INSECURE_OTEL` (highest precedence)
2. `brSisbajud.security.allowInsecureOtel`
3. `global.observability.allowInsecureOtel`
4. Default reason: `"node-local collector on the pod's own node"` (lowest precedence)

**Why this matters:**

When telemetry is enabled (`global.observability.enabled: true` or `brSisbajud.configmap.ENABLE_TELEMETRY: "true"`) and no explicit OTLP endpoint is configured, the application ships traces to a node-local collector at `http://$(HOST_IP):4317` in plaintext. The `lib-observability` library refuses this insecure connection in production unless `ALLOW_INSECURE_OTEL` carries a reason string.

Previously, operators had to manually inject this variable through secrets or extraEnvVars. Now the chart automatically provides a default reason and allows structured override.

**Template logic changes:**

**Before (v1.5.0):**

```yaml
{{- if and $telemetry (not $explicitEndpoint) }}
{{- include "lerian-common.otel.podEnv" (dict "port" 4317) | nindent 12 }}
{{- end }}
```

**After (v1.5.1):**

```yaml
{{- if and $telemetry (not $explicitEndpoint) }}
{{- include "lerian-common.otel.podEnv" (dict "context" $ "configmap" $otelCm "port" 4317 "allowInsecure" (not $legacyAllow)) | nindent 12 }}
{{- end }}
```

The new template logic:
- Checks if `ALLOW_INSECURE_OTEL` is set via the modeled configuration (`brSisbajud.configmap`, `brSisbajud.security.allowInsecureOtel`, or `global.observability.allowInsecureOtel`)
- Falls back to legacy routes (`brSisbajud.secrets` or `brSisbajud.extraEnvVars`) if the modeled configuration is unset
- Passes the resolved value to the `lerian-common.otel.podEnv` helper, which emits the environment variable

**Behavior changes:**

| Scenario | v1.5.0 | v1.5.1 |
|----------|--------|--------|
| No `ALLOW_INSECURE_OTEL` set anywhere | Application refuses node-local OTLP in production | Chart automatically sets `ALLOW_INSECURE_OTEL="node-local collector on the pod's own node"` |
| `ALLOW_INSECURE_OTEL` in `brSisbajud.secrets` | Used from Secret | Used from Secret (legacy route still works) |
| `ALLOW_INSECURE_OTEL` in `brSisbajud.configmap` | Not supported | Used from ConfigMap (highest precedence) |
| `brSisbajud.security.allowInsecureOtel` set | Not supported | Used from security block |
| `global.observability.allowInsecureOtel` set | Not supported | Used from global observability block |

> **Important:** The modeled configuration takes precedence over the Secret. If you set `brSisbajud.configmap.ALLOW_INSECURE_OTEL` or `brSisbajud.security.allowInsecureOtel`, any value in `brSisbajud.secrets.ALLOW_INSECURE_OTEL` is ignored.

> **Warning:** If you use an external Secret (via `brSisbajud.useExistingSecret`), the chart cannot see its contents. Any `ALLOW_INSECURE_OTEL` value in that Secret will be **overridden** by the chart's modeled configuration. To prevent this, set `brSisbajud.configmap.ALLOW_INSECURE_OTEL: null` to explicitly unset the modeled value.

**Configuration options:**

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.configmap.ALLOW_INSECURE_OTEL` | Not set | Explicit reason string for allowing insecure OTLP (highest precedence) |
| `brSisbajud.security.allowInsecureOtel` | Not set | Reason string from security block (medium precedence) |
| `global.observability.allowInsecureOtel` | Not set | Reason string from global observability block (low precedence) |
| Default (when none set) | `"node-local collector on the pod's own node"` | Automatic default reason |

**Refusal behavior:**

To explicitly refuse insecure OTLP connections (e.g., in a production environment where you want to enforce explicit endpoint configuration), set the value to an empty string or `"false"`:

```yaml
brSisbajud:
  configmap:
    ALLOW_INSECURE_OTEL: ""
```

or

```yaml
brSisbajud:
  security:
    allowInsecureOtel: "false"
```

This will cause the application to refuse node-local OTLP connections in production, forcing operators to configure an explicit `OTEL_EXPORTER_OTLP_ENDPOINT`.

### Enhanced observability configuration

The `global.observability` block now includes documentation for the new `allowInsecureOtel` field.

**values.yaml documentation changes:**

**Before (v1.5.0):**

```yaml
# -- Env-wide observability: enabled | otlpEndpoint | deploymentEnvironment.
# With enabled=true and no otlpEndpoint, the pod ships to the node-local
# collector at http://$(HOST_IP):4317.
# Example: observability: { enabled: true }
observability: {}
```

**After (v1.5.1):**

```yaml
# -- Env-wide observability: enabled | otlpEndpoint | deploymentEnvironment | allowInsecureOtel.
# With enabled=true and no otlpEndpoint, the pod ships to the node-local
# collector at http://$(HOST_IP):4317.
# Example: observability: { enabled: true }
observability: {}
# example ↓ (uncomment & fill; comments render nothing = default stays empty):
#   enabled: true
#   allowInsecureOtel: "node-local collector on the pod's own node"
```

The documentation now explicitly mentions `allowInsecureOtel` and provides an example of how to set it.

**New configuration block in values.yaml:**

```yaml
# ALLOW_INSECURE_OTEL — with telemetry on and no endpoint set, the pod ships to the
# node-local collector at $(HOST_IP):4317 in plaintext, which lib-observability
# refuses in production unless ALLOW_INSECURE_OTEL carries a reason. The chart sets it
# on the container: brSisbajud.configmap.ALLOW_INSECURE_OTEL, else
# security.allowInsecureOtel, else global.observability.allowInsecureOtel, else
# "node-local collector on the pod's own node". "" or "false" refuses (the app then
# will not boot on the node-local hop in production); null is unset. See the README.
```

This documentation block appears in the `brSisbajud` section of `values.yaml`, explaining the configuration hierarchy and behavior.

---

## Migration Steps

### For operators using node-local OTLP collectors

If you have telemetry enabled and rely on the node-local collector at `http://$(HOST_IP):4317`, **no action is required**. The chart now automatically sets `ALLOW_INSECURE_OTEL="node-local collector on the pod's own node"` by default.

**Verify your configuration:**

```yaml
global:
  observability:
    enabled: true
    # otlpEndpoint not set — uses node-local collector
```

or

```yaml
brSisbajud:
  configmap:
    ENABLE_TELEMETRY: "true"
    # OTEL_EXPORTER_OTLP_ENDPOINT not set — uses node-local collector
```

After upgrading to v1.5.1, the application will accept the node-local plaintext connection in production without additional configuration.

### For operators who previously set ALLOW_INSECURE_OTEL in secrets

If you have `ALLOW_INSECURE_OTEL` in `brSisbajud.secrets`:

**Before (v1.5.0):**

```yaml
brSisbajud:
  secrets:
    POSTGRES_PASSWORD: "<vault-placeholder>"
    REDIS_PASSWORD: "<vault-placeholder>"
    ALLOW_INSECURE_OTEL: "node-local collector"
```

**After (v1.5.1) — Option 1: Keep existing (legacy route)**

The legacy route still works. No action required.

```yaml
brSisbajud:
  secrets:
    POSTGRES_PASSWORD: "<vault-placeholder>"
    REDIS_PASSWORD: "<vault-placeholder>"
    ALLOW_INSECURE_OTEL: "node-local collector"
```

**After (v1.5.1) — Option 2: Migrate to modeled configuration**

Move the value to the ConfigMap for better visibility and consistency:

```yaml
brSisbajud:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector"
  secrets:
    POSTGRES_PASSWORD: "<vault-placeholder>"
    REDIS_PASSWORD: "<vault-placeholder>"
    # ALLOW_INSECURE_OTEL removed from secrets
```

or use the security block:

```yaml
brSisbajud:
  security:
    allowInsecureOtel: "node-local collector"
  secrets:
    POSTGRES_PASSWORD: "<vault-placeholder>"
    REDIS_PASSWORD: "<vault-placeholder>"
    # ALLOW_INSECURE_OTEL removed from secrets
```

> **Note:** The modeled configuration takes precedence over the Secret. If you set both, the ConfigMap or security block value is used.

### For operators using external Secrets

If you use `brSisbajud.useExistingSecret: true` and have `ALLOW_INSECURE_OTEL` in your external Secret:

**Before (v1.5.0):**

```yaml
brSisbajud:
  useExistingSecret: true
  existingSecretName: "br-sisbajud-external-secret"
```

External Secret contains:

```yaml
data:
  POSTGRES_PASSWORD: <base64-encoded>
  REDIS_PASSWORD: <base64-encoded>
  ALLOW_INSECURE_OTEL: <base64-encoded>
```

**After (v1.5.1):**

The chart will now **override** the `ALLOW_INSECURE_OTEL` value from your external Secret with the default `"node-local collector on the pod's own node"`.

#### Option 1: Accept the chart's default

No action required. The chart's default reason is sufficient for most node-local collector scenarios.

#### Option 2: Preserve your external Secret value

Set `brSisbajud.configmap.ALLOW_INSECURE_OTEL: null` to explicitly unset the modeled configuration:

```yaml
brSisbajud:
  useExistingSecret: true
  existingSecretName: "br-sisbajud-external-secret"
  configmap:
    ALLOW_INSECURE_OTEL: null
```

This tells the chart to skip emitting `ALLOW_INSECURE_OTEL`, allowing your external Secret value to take effect.

#### Option 3: Migrate to modeled configuration

Move the value from your external Secret to the chart's values:

```yaml
brSisbajud:
  useExistingSecret: true
  existingSecretName: "br-sisbajud-external-secret"
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector"
```

Remove `ALLOW_INSECURE_OTEL` from your external Secret.

### For operators who want to refuse insecure OTLP

If you want to enforce explicit OTLP endpoint configuration and refuse node-local plaintext connections in production:

```yaml
brSisbajud:
  configmap:
    ALLOW_INSECURE_OTEL: ""
```

or

```yaml
brSisbajud:
  security:
    allowInsecureOtel: "false"
```

The application will refuse to start if telemetry is enabled without an explicit `OTEL_EXPORTER_OTLP_ENDPOINT`.

### For operators using extraEnvVars

If you have `ALLOW_INSECURE_OTEL` in `brSisbajud.extraEnvVars`:

**Before (v1.5.0):**

```yaml
brSisbajud:
  extraEnvVars:
    - name: ALLOW_INSECURE_OTEL
      value: "node-local collector"
```

**After (v1.5.1):**

The legacy route still works. No action required. However, consider migrating to the modeled configuration for consistency:

```yaml
brSisbajud:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector"
  extraEnvVars: []
```

---

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.5.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.5.1
```
<!-- {% endraw %} -->
