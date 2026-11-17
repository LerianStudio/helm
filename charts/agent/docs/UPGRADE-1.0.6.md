<!-- {% raw %} -->
# Helm Upgrade from v1.0.5 to v1.0.6

This guide helps operators upgrade the **Lerian BYOC agent** chart from version **1.0.5** to **1.0.6**. This is a patch release that updates the lerian-common-helm dependency and introduces new telemetry configuration options for insecure OTEL connections.

## Topics

- **[Overview](#overview)**
- **[Changes in v1.0.6](#changes-in-v106)**
  - [Dependency Update](#dependency-update)
  - [New Telemetry Configuration](#new-telemetry-configuration)
  - [Template Logic Changes](#template-logic-changes)
- **[Migration Steps](#migration-steps)**
  - [Option 1: No Action Required (Default Behavior)](#option-1-no-action-required-default-behavior)
  - [Option 2: Explicitly Configure ALLOW_INSECURE_OTEL](#option-2-explicitly-configure-allow_insecure_otel)
  - [Option 3: Migrate from Legacy Secret to Configmap Model](#option-3-migrate-from-legacy-secret-to-configmap-model)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version **1.0.6** is a patch release that updates the lerian-common-helm dependency from `2.2.0` to `2.7.0` and introduces a new configuration model for allowing insecure OTEL connections when telemetry is enabled without an explicit endpoint.

**What changed:**

- lerian-common-helm dependency updated from `2.2.0` to `2.7.0`
- New `agent.configmap.ALLOW_INSECURE_OTEL` configuration option added
- New `global.observability.allowInsecureOtel` configuration option added
- Template logic updated to handle insecure OTEL connections with priority resolution

**What stayed the same:**

- Agent application version remains `1.0.2`
- Agent container image tag remains `1.0.2`
- All other configuration options remain unchanged
- Default behavior for telemetry remains unchanged

## Changes in v1.0.6

### Dependency Update

The lerian-common-helm dependency has been updated to version `2.7.0`.

| Setting | v1.0.5 | v1.0.6 |
|---------|--------|--------|
| `dependencies[0].version` | `2.2.0` | `2.7.0` |

**Operational impact:**

The updated lerian-common-helm library includes enhanced OTEL helper functions that support the new insecure connection model. This dependency update enables the new `ALLOW_INSECURE_OTEL` configuration options and improved template logic for telemetry configuration.

### New Telemetry Configuration

A new configuration option `ALLOW_INSECURE_OTEL` has been added to control whether the agent can connect to a node-local OTEL collector over an insecure (plaintext) connection.

**Context:**

When `ENABLE_TELEMETRY` is set to `"true"` and `OTEL_EXPORTER_OTLP_ENDPOINT` is empty, the agent defaults to shipping telemetry to a node-local collector at `$(HOST_IP):4317` in plaintext. The lib-observability library refuses insecure connections in production unless `ALLOW_INSECURE_OTEL` carries a reason string explaining why the insecure connection is acceptable.

**New configuration keys:**

| Flag | Default | Description |
|------|---------|-------------|
| `agent.configmap.ALLOW_INSECURE_OTEL` | `null` (unset) | Reason string for allowing insecure OTEL connections. Set to a descriptive reason (e.g., `"node-local collector on the pod's own node"`) to permit plaintext connections. Set to `""` or `"false"` to refuse insecure connections. `null` means unset. |
| `global.observability.allowInsecureOtel` | `null` (unset) | Global fallback for `ALLOW_INSECURE_OTEL`. Used when `agent.configmap.ALLOW_INSECURE_OTEL` is not set. |

**Default behavior:**

The chart now provides a default reason string when neither `agent.configmap.ALLOW_INSECURE_OTEL` nor `global.observability.allowInsecureOtel` is set: `"node-local collector on the pod's own node"`. This maintains backward compatibility with v1.0.5 behavior.

**After (v1.0.6):**

```yaml
agent:
  configmap:
    ENABLE_TELEMETRY: "false"
    OTEL_SERVICE_NAME: "lerian-agent"
    OTEL_EXPORTER_OTLP_ENDPOINT: ""
    # ALLOW_INSECURE_OTEL — with ENABLE_TELEMETRY "true" and no endpoint set, the pod
    # ships to the node-local collector at $(HOST_IP):4317 in plaintext, which
    # lib-observability refuses in production unless ALLOW_INSECURE_OTEL carries a
    # reason. The chart sets it on the container: this key, else
    # global.observability.allowInsecureOtel, else "node-local collector on the pod's
    # own node". "" or "false" refuses (the app then will not boot on the node-local hop
    # in production); null is unset. See the README.
    # ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

**Configuration examples:**

**Example 1: Allow insecure node-local collector (explicit):**

```yaml
agent:
  configmap:
    ENABLE_TELEMETRY: "true"
    OTEL_EXPORTER_OTLP_ENDPOINT: ""
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

**Example 2: Refuse insecure connections:**

```yaml
agent:
  configmap:
    ENABLE_TELEMETRY: "true"
    OTEL_EXPORTER_OTLP_ENDPOINT: ""
    ALLOW_INSECURE_OTEL: "false"
```

**Example 3: Use global default:**

```yaml
global:
  observability:
    allowInsecureOtel: "trusted internal network"

agent:
  configmap:
    ENABLE_TELEMETRY: "true"
    OTEL_EXPORTER_OTLP_ENDPOINT: ""
    # ALLOW_INSECURE_OTEL not set — inherits from global
```

**Operational impact:**

- **If you are not using telemetry** (`ENABLE_TELEMETRY: "false"`): No impact. The `ALLOW_INSECURE_OTEL` setting is only evaluated when telemetry is enabled.
- **If you have an explicit `OTEL_EXPORTER_OTLP_ENDPOINT` set**: No impact. The `ALLOW_INSECURE_OTEL` setting is only evaluated when the endpoint is empty and the agent falls back to the node-local collector.
- **If you are using node-local telemetry** (telemetry enabled, no endpoint): The chart now sets `ALLOW_INSECURE_OTEL` with a default reason string, maintaining the same behavior as v1.0.5. You can override this by setting `agent.configmap.ALLOW_INSECURE_OTEL` explicitly.

### Template Logic Changes

The deployment template now includes enhanced logic to resolve the `ALLOW_INSECURE_OTEL` environment variable with priority handling for legacy configurations.

**Before (v1.0.5):**

```yaml
{{- if eq (toString .Values.agent.configmap.ENABLE_TELEMETRY) "true" }}
{{- if not .Values.agent.configmap.OTEL_EXPORTER_OTLP_ENDPOINT }}
{{- include "lerian-common.otel.podEnv" (dict "port" 4317) | nindent 10 }}
{{- end }}
{{- end }}
```

**After (v1.0.6):**

```yaml
{{- if eq (toString .Values.agent.configmap.ENABLE_TELEMETRY) "true" }}
{{- if not .Values.agent.configmap.OTEL_EXPORTER_OTLP_ENDPOINT }}
{{- /* ALLOW_INSECURE_OTEL is a modeled setting: agent.configmap.ALLOW_INSECURE_OTEL, then
   global.observability.allowInsecureOtel, then the node-local reason; lerian-common
   resolves it and emits the one env entry. A key in agent.extraEnvVars or a
   non-empty agent.secrets value (the legacy routes; the Secret only while the model is unset) still stands, so the helper adds
   no duplicate then.
   An existing Secret (useExistingSecret) is not visible to the chart, so a value
   there is overridden by this entry; set agent.configmap.ALLOW_INSECURE_OTEL instead. */}}
{{- /* The model wins over the Secret: a configmap, knob or global value (a refusal too) keeps the entry. */}}
{{- $otelModelSet := or (not (kindIs "invalid" (index (.Values.agent.configmap | default dict) "ALLOW_INSECURE_OTEL"))) (not (kindIs "invalid" (index (($.Values.global | default dict).observability | default dict) "allowInsecureOtel"))) }}
{{- $legacyAllow := (and (not $otelModelSet) (not .Values.agent.useExistingSecret) (ne (toString (index (.Values.agent.secrets | default dict) "ALLOW_INSECURE_OTEL" | default "")) "")) }}
{{- range .Values.agent.extraEnvVars }}{{- if eq .name "ALLOW_INSECURE_OTEL" }}{{- $legacyAllow = true }}{{- end }}{{- end }}
{{- include "lerian-common.otel.podEnv" (dict "context" $ "configmap" .Values.agent.configmap "port" 4317 "allowInsecure" (not $legacyAllow)) | nindent 10 }}
{{- end }}
{{- end }}
```

**Resolution priority:**

The template resolves `ALLOW_INSECURE_OTEL` in the following order:

1. `agent.configmap.ALLOW_INSECURE_OTEL` (highest priority)
2. `global.observability.allowInsecureOtel`
3. Default reason: `"node-local collector on the pod's own node"`
4. Legacy routes: `agent.secrets.ALLOW_INSECURE_OTEL` or `agent.extraEnvVars` (only if the new model is unset)

**Operational impact:**

- **If you are using `agent.secrets.ALLOW_INSECURE_OTEL`**: The new configmap model takes precedence. If you set `agent.configmap.ALLOW_INSECURE_OTEL` or `global.observability.allowInsecureOtel`, the secret value will be ignored. Migrate to the configmap model for consistent behavior.
- **If you are using `agent.extraEnvVars` with `ALLOW_INSECURE_OTEL`**: The extraEnvVars entry will be preserved and the chart will not add a duplicate environment variable.
- **If you are using `agent.useExistingSecret`**: The chart cannot inspect the contents of an existing secret. If your secret contains `ALLOW_INSECURE_OTEL`, it will be overridden by the new template logic. Set `agent.configmap.ALLOW_INSECURE_OTEL` explicitly to control this value.

> **Important:** If you are using an existing secret (`agent.useExistingSecret: true`) that contains `ALLOW_INSECURE_OTEL`, the new template logic will override it. Migrate to `agent.configmap.ALLOW_INSECURE_OTEL` to maintain control over this setting.

## Migration Steps

### Option 1: No Action Required (Default Behavior)

If you are not using telemetry, or if you have an explicit `OTEL_EXPORTER_OTLP_ENDPOINT` set, no action is required. The upgrade will not change your agent's behavior.

**To upgrade:**

1. Review your current values file:

```bash
helm get values lerian-agent -n lerian-system > current-values.yaml
```

2. Verify that one of the following is true:
   - `agent.configmap.ENABLE_TELEMETRY` is `"false"` (or unset)
   - `agent.configmap.OTEL_EXPORTER_OTLP_ENDPOINT` is set to a non-empty value

3. Run the upgrade command (see below)

4. Verify the agent pod is running:

```bash
kubectl -n lerian-system get pods -l app.kubernetes.io/name=agent
kubectl -n lerian-system logs deploy/lerian-agent | grep -i "version\|heartbeat"
```

### Option 2: Explicitly Configure ALLOW_INSECURE_OTEL

If you are using node-local telemetry and want to explicitly control the insecure connection behavior, set `agent.configmap.ALLOW_INSECURE_OTEL` in your values file.

**To upgrade:**

1. Review your current values file:

```bash
helm get values lerian-agent -n lerian-system > current-values.yaml
```

2. Add the `ALLOW_INSECURE_OTEL` setting to your values file:

```yaml
agent:
  configmap:
    ENABLE_TELEMETRY: "true"
    OTEL_EXPORTER_OTLP_ENDPOINT: ""
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

3. Run the upgrade command with your updated values file:

```bash
helm upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.6 -f current-values.yaml
```

4. Verify the agent pod is running and the environment variable is set:

```bash
kubectl -n lerian-system get pods -l app.kubernetes.io/name=agent
kubectl -n lerian-system exec deploy/lerian-agent -- env | grep ALLOW_INSECURE_OTEL
```

### Option 3: Migrate from Legacy Secret to Configmap Model

If you are currently setting `ALLOW_INSECURE_OTEL` via `agent.secrets` or `agent.extraEnvVars`, migrate to the new configmap model for consistent behavior.

**To upgrade:**

1. Review your current values file:

```bash
helm get values lerian-agent -n lerian-system > current-values.yaml
```

2. If you have `agent.secrets.ALLOW_INSECURE_OTEL` set, move it to `agent.configmap.ALLOW_INSECURE_OTEL`:

**Before:**

```yaml
agent:
  secrets:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

**After:**

```yaml
agent:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
  secrets: {}
```

3. If you have `agent.extraEnvVars` with `ALLOW_INSECURE_OTEL`, remove it and set `agent.configmap.ALLOW_INSECURE_OTEL`:

**Before:**

```yaml
agent:
  extraEnvVars:
    - name: ALLOW_INSECURE_OTEL
      value: "node-local collector on the pod's own node"
```

**After:**

```yaml
agent:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
  extraEnvVars: []
```

4. Run the upgrade command with your updated values file:

```bash
helm upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.6 -f current-values.yaml
```

5. Verify the agent pod is running and the environment variable is set correctly:

```bash
kubectl -n lerian-system get pods -l app.kubernetes.io/name=agent
kubectl -n lerian-system exec deploy/lerian-agent -- env | grep ALLOW_INSECURE_OTEL
```

> **Note:** If you are using `agent.useExistingSecret: true` and your secret contains `ALLOW_INSECURE_OTEL`, you must migrate to `agent.configmap.ALLOW_INSECURE_OTEL` to prevent the chart from overriding your secret value.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.6
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.6
```
<!-- {% endraw %} -->
