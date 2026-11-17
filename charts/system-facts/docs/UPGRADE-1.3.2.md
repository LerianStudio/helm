<!-- {% raw %} -->
# Helm Upgrade from v1.3.1 to v1.3.2

This guide covers the upgrade of the `system-facts` Helm chart from version **1.3.1** to **1.3.2**. This is a patch release that updates the `lerian-common-helm` dependency from **2.6.1** to **2.7.0** and introduces support for the `ALLOW_INSECURE_OTEL` environment variable to control plaintext OpenTelemetry exports in production environments.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Dependency Updates](#dependency-updates)**
  - [lerian-common-helm 2.6.1 → 2.7.0](#lerian-common-helm-261--270)
- **[New Configuration Options](#new-configuration-options)**
  - [1. ALLOW_INSECURE_OTEL Environment Variable](#1-allow_insecure_otel-environment-variable)
  - [2. Global Observability allowInsecureOtel Field](#2-global-observability-allowinsecureotel-field)
- **[Template Changes](#template-changes)**
  - [ConfigMap Template](#configmap-template)
  - [Deployment Template](#deployment-template)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.3.2** introduces the following changes:

- **Dependency update**: `lerian-common-helm` upgraded from **2.6.1** to **2.7.0**
- **New configuration option**: `ALLOW_INSECURE_OTEL` environment variable support for controlling plaintext OpenTelemetry exports
- **New global field**: `global.observability.allowInsecureOtel` for environment-wide configuration
- **Template enhancements**: ConfigMap and Deployment templates updated to support the new `ALLOW_INSECURE_OTEL` setting with a three-tier resolution hierarchy

There are no changes to:

- Application version (`appVersion` remains `1.2.0-beta.4`)
- Image tags or container specifications
- Service, Ingress, or other resource templates
- PostgreSQL or other dependency versions

The upgrade does not roll pods unless you enable OpenTelemetry (`system-facts.otel.enabled: true`) and the new `ALLOW_INSECURE_OTEL` logic changes the rendered ConfigMap or Deployment environment variables.

---

## Breaking Changes

**None.** This is a patch release with no breaking changes. All existing configurations remain valid.

The new `ALLOW_INSECURE_OTEL` setting is optional. If you do not set it, the chart provides a default reason (`"node-local collector on the pod's own node"`) when OpenTelemetry is enabled, so existing deployments with `system-facts.otel.enabled: true` will continue to work without configuration changes.

> **Important:** If you previously set `ALLOW_INSECURE_OTEL` via `system-facts.extraEnvVars` or `system-facts.secrets`, those methods still work and take precedence over the new modeled settings. The chart detects legacy configurations and avoids duplicating the environment variable.

---

## Dependency Updates

### lerian-common-helm 2.6.1 → 2.7.0

The `lerian-common-helm` subchart has been updated from version **2.6.1** to **2.7.0**.

**Dependency change:**

| Dependency | v1.3.1 | v1.3.2 |
|------------|--------|--------|
| `lerian-common-helm` | `2.6.1` | `2.7.0` |

**What changed:**

The `lerian-common-helm` library chart provides shared helpers and templates used across Lerian Studio charts. Version **2.7.0** introduces the `lerian-common.otel.podEnv` helper enhancement that supports the new `allowInsecure` parameter for managing `ALLOW_INSECURE_OTEL` environment variables.

**Operational impact:**

This dependency update enables the new `ALLOW_INSECURE_OTEL` functionality. There are no breaking changes in the library chart itself. The upgrade is transparent if you do not use the new features.

> **Note:** Review the [lerian-common-helm 2.7.0 release notes](https://github.com/lerianstudio/lerian-common-helm/releases/tag/2.7.0) for details on library helper changes.

---

## New Configuration Options

### 1. ALLOW_INSECURE_OTEL Environment Variable

Version **1.3.2** introduces explicit support for the `ALLOW_INSECURE_OTEL` environment variable, which controls whether the application accepts plaintext OpenTelemetry exports in production environments.

**Background:**

When OpenTelemetry is enabled (`system-facts.otel.enabled: true`), the System Facts service exports telemetry to a node-local collector at `$(HOST_IP):4317` over plaintext HTTP. The `lib-observability` library refuses plaintext exports in production (when `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` is `"production"`) unless `ALLOW_INSECURE_OTEL` carries a reason string explaining why the plaintext connection is acceptable.

The typical reason is that the collector runs on the same node as the pod, so the traffic never leaves the host. An empty string (`""`) or the literal value `"false"` refuses the connection, causing the application to fail to boot.

**Resolution hierarchy:**

The chart resolves `ALLOW_INSECURE_OTEL` in the following order (first match wins):

1. **`system-facts.extraEnvVars`**: If an entry with `name: ALLOW_INSECURE_OTEL` exists, the chart does not render the variable in the ConfigMap or Deployment (legacy route, still supported)
2. **`system-facts.secrets.ALLOW_INSECURE_OTEL`**: If set and `system-facts.useExistingSecret` is `false`, the chart does not render the variable in the ConfigMap or Deployment (legacy route, still supported)
3. **`system-facts.configmap.ALLOW_INSECURE_OTEL`**: Explicit per-service override (new modeled setting)
4. **`global.observability.allowInsecureOtel`**: Environment-wide default (new modeled setting)
5. **Default reason**: `"node-local collector on the pod's own node"` (only when OpenTelemetry is enabled and none of the above are set)

**New values fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `system-facts.configmap.ALLOW_INSECURE_OTEL` | string or null | `null` (unset) | Per-service reason for allowing plaintext OTLP exports. Set to a descriptive string (e.g., `"node-local collector on the pod's own node"`), `""` or `"false"` to refuse, or leave unset to fall back to `global.observability.allowInsecureOtel` or the default. |
| `global.observability.allowInsecureOtel` | string or null | `null` (unset) | Environment-wide reason for allowing plaintext OTLP exports. Consumed by all services in the environment. Set to a descriptive string, `""` or `"false"` to refuse, or leave unset to use the chart default. |

**Example configuration:**

To set an environment-wide reason for all services:

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
    allowInsecureOtel: "node-local collector on the pod's own node"
```

To override the reason for the System Facts service only:

```yaml
system-facts:
  otel:
    enabled: true
  configmap:
    ALLOW_INSECURE_OTEL: "dedicated collector on the same node"
```

To explicitly refuse plaintext exports (causing the application to fail to boot if the endpoint is plaintext):

```yaml
system-facts:
  configmap:
    ALLOW_INSECURE_OTEL: "false"
```

> **Note:** The value `null` (unset) is different from `""` (empty string). An unset value falls back to the next tier in the hierarchy, while an empty string or `"false"` explicitly refuses the connection.

> **Warning:** If you use an existing Secret (`system-facts.useExistingSecret: true`), the chart cannot see its contents. If that Secret contains `ALLOW_INSECURE_OTEL`, the new modeled settings (ConfigMap or global) will override it. Set `system-facts.configmap.ALLOW_INSECURE_OTEL` instead to control the value explicitly.

### 2. Global Observability allowInsecureOtel Field

The `global.observability` block now supports an `allowInsecureOtel` field for environment-wide configuration.

**Before (v1.3.1):**

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
```

**After (v1.3.2):**

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
    allowInsecureOtel: "node-local collector on the pod's own node"
```

**Operational impact:**

This field is optional. If you do not set it, the chart uses the default reason when OpenTelemetry is enabled. Set it to provide a consistent reason across all services in your environment, or to explicitly refuse plaintext exports by setting it to `""` or `"false"`.

---

## Template Changes

### ConfigMap Template

The `configmap.yaml` template now includes logic to render the `ALLOW_INSECURE_OTEL` environment variable based on the resolution hierarchy.

**Before (v1.3.1):**

The ConfigMap did not include `ALLOW_INSECURE_OTEL`. Operators had to set it manually via `system-facts.extraEnvVars` or `system-facts.secrets`.

**After (v1.3.2):**

```yaml
data:
  # ... other environment variables ...
  OTEL_EXPORTER_OTLP_ENDPOINT: {{ include "lerian-common.globalValue" ... | quote }}
  {{- /* ALLOW_INSECURE_OTEL: system-facts.configmap.ALLOW_INSECURE_OTEL, then
     global.observability.allowInsecureOtel; null is unset and nothing renders when both are.
     Rendered here so the setting reaches the app with the node-local collector off too
     (an explicit plaintext endpoint); with it on, the Deployment's env entry carries the
     same value. A key in system-facts.extraEnvVars renders below instead. */}}
  {{- $otelAllowCm := ((index .Values "system-facts").configmap) | default dict }}
  {{- $otelAllowObs := (.Values.global | default dict).observability | default dict }}
  {{- $otelAllowLegacy := false }}
  {{- range ((index .Values "system-facts").extraEnvVars | default list) }}{{- if eq .name "ALLOW_INSECURE_OTEL" }}{{- $otelAllowLegacy = true }}{{- end }}{{- end }}
  {{- if not $otelAllowLegacy }}
  {{- if not (kindIs "invalid" (index $otelAllowCm "ALLOW_INSECURE_OTEL")) }}
  ALLOW_INSECURE_OTEL: {{ index $otelAllowCm "ALLOW_INSECURE_OTEL" | toString | quote }}
  {{- else if not (kindIs "invalid" (index $otelAllowObs "allowInsecureOtel")) }}
  ALLOW_INSECURE_OTEL: {{ index $otelAllowObs "allowInsecureOtel" | toString | quote }}
  {{- end }}
  {{- end }}
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: {{ include "lerian-common.globalValue" ... | quote }}
```

**Operational impact:**

The ConfigMap now includes `ALLOW_INSECURE_OTEL` when:

- `system-facts.configmap.ALLOW_INSECURE_OTEL` is set (including `""` or `"false"`), OR
- `global.observability.allowInsecureOtel` is set (including `""` or `"false"`)

The variable is **not** rendered if:

- Both `system-facts.configmap.ALLOW_INSECURE_OTEL` and `global.observability.allowInsecureOtel` are unset (`null`), OR
- An entry with `name: ALLOW_INSECURE_OTEL` exists in `system-facts.extraEnvVars` (legacy route takes precedence)

If the ConfigMap content changes, Kubernetes rolls the System Facts pods to pick up the new environment variable.

> **Note:** The ConfigMap renders `ALLOW_INSECURE_OTEL` even when OpenTelemetry is disabled (`system-facts.otel.enabled: false`), so the setting is available if you configure an explicit plaintext endpoint via `system-facts.configmap.OTEL_EXPORTER_OTLP_ENDPOINT`.

### Deployment Template

The `deployment.yaml` template now passes the `allowInsecure` parameter to the `lerian-common.otel.podEnv` helper, which controls whether the helper renders `ALLOW_INSECURE_OTEL` in the pod environment.

**Before (v1.3.1):**

```yaml
{{- if $otelEnabled }}
{{- include "lerian-common.otel.podEnv" (dict "port" 4317 "scheme" "http://") | nindent 10 }}
{{- end }}
```

**After (v1.3.2):**

```yaml
{{- if $otelEnabled }}
{{- /* ALLOW_INSECURE_OTEL is a modeled setting: system-facts.configmap.ALLOW_INSECURE_OTEL, then
   global.observability.allowInsecureOtel, then the node-local reason; lerian-common
   resolves it and emits the one env entry. A key in system-facts.extraEnvVars or a
   non-empty system-facts.secrets value (the legacy routes; the Secret only while the model is unset) still stands, so the helper
   adds no duplicate then.
   An existing Secret (useExistingSecret) is not visible to the chart, so a value
   there is overridden by this entry; set system-facts.configmap.ALLOW_INSECURE_OTEL instead. */}}
{{- /* The model wins over the Secret: a configmap, knob or global value (a refusal too) keeps the entry. */}}
{{- $otelModelSet := or (not (kindIs "invalid" (index ((index $.Values "system-facts").configmap | default dict) "ALLOW_INSECURE_OTEL"))) (not (kindIs "invalid" (index (($.Values.global | default dict).observability | default dict) "allowInsecureOtel"))) }}
{{- $legacyAllow := (and (not $otelModelSet) (not (index .Values "system-facts").useExistingSecret) (ne (toString (index ((index .Values "system-facts").secrets | default dict) "ALLOW_INSECURE_OTEL" | default "")) "")) }}
{{- range ((index .Values "system-facts").extraEnvVars | default list) }}{{- if eq .name "ALLOW_INSECURE_OTEL" }}{{- $legacyAllow = true }}{{- end }}{{- end }}
{{- include "lerian-common.otel.podEnv" (dict "context" $ "configmap" (index .Values "system-facts").configmap "port" 4317 "scheme" "http://" "allowInsecure" (not $legacyAllow)) | nindent 10 }}
{{- end }}
```

**Operational impact:**

The Deployment template now:

1. Detects whether `ALLOW_INSECURE_OTEL` is set via the new modeled settings (`system-facts.configmap.ALLOW_INSECURE_OTEL` or `global.observability.allowInsecureOtel`)
2. Detects whether `ALLOW_INSECURE_OTEL` is set via legacy routes (`system-facts.extraEnvVars` or `system-facts.secrets`)
3. Passes `allowInsecure: true` to the `lerian-common.otel.podEnv` helper only when the modeled settings are used (not legacy routes)

When `allowInsecure: true`, the helper renders `ALLOW_INSECURE_OTEL` in the pod environment with the resolved value from the hierarchy. When `allowInsecure: false` (legacy routes detected), the helper does not render the variable, avoiding duplicates.

The helper also injects the `HOST_IP` environment variable (via the Downward API) and sets `OTEL_EXPORTER_OTLP_ENDPOINT` to `http://$(HOST_IP):4317` when OpenTelemetry is enabled.

If the Deployment pod template changes, Kubernetes rolls the System Facts pods.

> **Important:** If you use an existing Secret (`system-facts.useExistingSecret: true`) and that Secret contains `ALLOW_INSECURE_OTEL`, the new modeled settings will override it because the chart cannot see the Secret's contents. To control the value explicitly, set `system-facts.configmap.ALLOW_INSECURE_OTEL` instead of relying on the existing Secret.

---

## Migration Steps

No values changes are required for this upgrade. The chart provides sensible defaults for the new `ALLOW_INSECURE_OTEL` setting.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.3.1`.

### Step 2: Review OpenTelemetry configuration

If you have OpenTelemetry enabled (`system-facts.otel.enabled: true`), review your current `ALLOW_INSECURE_OTEL` configuration:

- **If you set it via `system-facts.extraEnvVars` or `system-facts.secrets`**: No action required. The chart detects these legacy routes and preserves them.
- **If you did not set it**: The chart will now render `ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"` by default when OpenTelemetry is enabled. This is the recommended value for node-local collectors.
- **If you want to set it explicitly**: Add `system-facts.configmap.ALLOW_INSECURE_OTEL` or `global.observability.allowInsecureOtel` to your values file (see [New Configuration Options](#new-configuration-options)).

### Step 3: Apply the upgrade

Upgrade to version `1.3.2`, keeping your existing values:

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --version 1.3.2 \
  --namespace system-facts \
  --reuse-values
```

> **Note:** The `--reuse-values` flag preserves your existing configuration. The new `ALLOW_INSECURE_OTEL` logic is additive and does not conflict with existing settings.

### Step 4: Monitor the upgrade

If OpenTelemetry is enabled and the ConfigMap or Deployment environment changes, watch the rollout status:

```bash
kubectl rollout status deployment/system-facts -n system-facts
```

If OpenTelemetry is disabled or the environment variables did not change, the upgrade completes immediately without rolling pods.

### Step 5: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.3.2`.

Verify that the `ALLOW_INSECURE_OTEL` environment variable is set correctly (if OpenTelemetry is enabled):

```bash
kubectl get configmap system-facts -n system-facts -o jsonpath='{.data.ALLOW_INSECURE_OTEL}'
```

Expected output (if using the default):

```
node-local collector on the pod's own node
```

### Step 6: (Optional) Migrate from legacy routes

If you previously set `ALLOW_INSECURE_OTEL` via `system-facts.extraEnvVars` or `system-facts.secrets`, consider migrating to the new modeled settings for consistency:

#### Option 1: Keep existing configuration

No action required. The chart detects legacy routes and preserves them. This is the safest option if your current configuration works.

#### Option 2: Migrate to modeled settings

1. Remove the `ALLOW_INSECURE_OTEL` entry from `system-facts.extraEnvVars` or `system-facts.secrets`
2. Add the value to `system-facts.configmap.ALLOW_INSECURE_OTEL` or `global.observability.allowInsecureOtel`
3. Apply the updated values:

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --version 1.3.2 \
  --namespace system-facts \
  --values values.yaml
```

**Example migration:**

**Before (legacy route):**

```yaml
system-facts:
  extraEnvVars:
    - name: ALLOW_INSECURE_OTEL
      value: "node-local collector on the pod's own node"
```

**After (modeled setting):**

```yaml
system-facts:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

Or, for environment-wide configuration:

```yaml
global:
  observability:
    allowInsecureOtel: "node-local collector on the pod's own node"
```

> **Note:** Migrating to modeled settings provides better visibility and consistency across services, but is not required for this upgrade.

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm --namespace system-facts --version 1.3.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm --namespace system-facts --version 1.3.2
```
<!-- {% endraw %} -->
