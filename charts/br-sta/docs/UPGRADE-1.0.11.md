<!-- {% raw %} -->
# Helm Upgrade from v1.0.10 to v1.0.11

## Topics

- **[Dependency Updates](#dependency-updates)**
- **[Configuration Changes](#configuration-changes)**
  - [New ALLOW_INSECURE_OTEL Configuration Model](#new-allow_insecure_otel-configuration-model)
  - [Enhanced Observability Documentation](#enhanced-observability-documentation)
- **[Template Changes](#template-changes)**
  - [OTEL Pod Environment Resolution Logic](#otel-pod-environment-resolution-logic)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Dependency Updates

Chart 1.0.11 upgrades the `lerian-common-helm` dependency from version 2.1.2 to 2.7.0. This is a minor version jump that may include new features, bug fixes, or behavioral changes in the common library functions used by this chart.

| Dependency | v1.0.10 | v1.0.11 |
|------------|---------|---------|
| lerian-common-helm | 2.1.2 | 2.7.0 |

> **Note:** Review the lerian-common-helm changelog between 2.1.2 and 2.7.0 to understand any breaking changes or new capabilities that may affect your deployment.

## Configuration Changes

### New ALLOW_INSECURE_OTEL Configuration Model

Chart 1.0.11 introduces a structured configuration model for the `ALLOW_INSECURE_OTEL` environment variable, which controls whether the application accepts plaintext OTLP connections to node-local collectors in production environments.

#### What Changed

Previously, `ALLOW_INSECURE_OTEL` could only be set via:
- `common.secrets.ALLOW_INSECURE_OTEL`
- Direct `extraEnvVars` on individual components

Now, the chart provides a **precedence-based configuration model** with multiple layers:

1. Component-specific configmap (e.g., `worker.configmap.ALLOW_INSECURE_OTEL`)
2. Common configmap (`common.configmap.ALLOW_INSECURE_OTEL`)
3. Security knob (`common.security.allowInsecureOtel`)
4. Global observability setting (`global.observability.allowInsecureOtel`)
5. Default value: `"node-local collector on the pod's own node"`

#### Why This Matters

When telemetry is enabled (`observability.enabled: true`) without an explicit OTLP endpoint, pods ship telemetry to `$(HOST_IP):4317` in plaintext. The `lib-observability` library refuses this in production environments unless `ALLOW_INSECURE_OTEL` contains a reason string explaining why insecure transport is acceptable.

**Without this setting in production:**
- Pods will fail to start when using node-local OTLP collectors
- The application will refuse to boot with telemetry enabled

**With this setting:**
- The chart automatically provides a default reason when needed
- Operators can override at multiple levels based on their security policies
- Setting an empty string (`""`) or `"false"` explicitly refuses insecure OTLP

#### Configuration Precedence

The chart resolves `ALLOW_INSECURE_OTEL` in this order (first match wins):

| Priority | Configuration Path | Scope |
|----------|-------------------|-------|
| 1 | `worker.configmap.ALLOW_INSECURE_OTEL` | Worker pod only |
| 2 | `common.configmap.ALLOW_INSECURE_OTEL` | All components |
| 3 | `common.security.allowInsecureOtel` | All components |
| 4 | `global.observability.allowInsecureOtel` | Environment-wide |
| 5 | Default: `"node-local collector on the pod's own node"` | Fallback |

> **Important:** The new model takes precedence over legacy Secret-based configuration. If you set any of the above values (including an explicit refusal with `""`), the chart will use that value even if `common.secrets.ALLOW_INSECURE_OTEL` exists.

> **Warning:** If you use `common.useExistingSecret: true`, the chart cannot see Secret contents. Any `ALLOW_INSECURE_OTEL` value in that external Secret will be overridden by the configmap entry. Migrate to the configmap model instead.

#### Migration Options

##### Option 1: Accept the Default (Recommended for Node-Local Collectors)

If you use node-local OTLP collectors and the default reason is acceptable, no action is required. The chart will automatically set:

```yaml
# No configuration needed - chart provides default
```

The pods will receive:

```yaml
env:
  - name: ALLOW_INSECURE_OTEL
    value: "node-local collector on the pod's own node"
```

##### Option 2: Set a Custom Reason

If your security policy requires a specific justification string:

```yaml
global:
  observability:
    enabled: true
    allowInsecureOtel: "approved by security team ticket SEC-12345"
```

Or at the common level:

```yaml
common:
  security:
    allowInsecureOtel: "internal network segment with mTLS at gateway"
```

##### Option 3: Refuse Insecure OTLP

To explicitly prevent plaintext OTLP in production, set an empty string or `"false"`:

```yaml
common:
  configmap:
    ALLOW_INSECURE_OTEL: ""
```

> **Warning:** With this configuration, pods will fail to start if telemetry is enabled without an explicit `otlpEndpoint`. You must either disable telemetry or provide a secure OTLP endpoint.

##### Option 4: Migrate from Secret to Configmap

If you currently use `common.secrets.ALLOW_INSECURE_OTEL`:

**Before (v1.0.10):**

```yaml
common:
  secrets:
    ALLOW_INSECURE_OTEL: "legacy reason string"
```

**After (v1.0.11):**

```yaml
common:
  configmap:
    ALLOW_INSECURE_OTEL: "legacy reason string"
  secrets:
    # Remove ALLOW_INSECURE_OTEL from here
```

> **Note:** This is not a sensitive credential and belongs in a ConfigMap, not a Secret. The configmap model also provides better visibility and precedence control.

##### Option 5: Component-Specific Configuration

To refuse insecure OTLP only for the worker while allowing it for the manager:

```yaml
worker:
  configmap:
    ALLOW_INSECURE_OTEL: ""  # Worker refuses

common:
  configmap:
    ALLOW_INSECURE_OTEL: "manager uses node-local collector"
```

### Enhanced Observability Documentation

The `values.yaml` file now includes expanded inline documentation for the `global.observability` block, clarifying the new `allowInsecureOtel` field and providing configuration examples.

**Before (v1.0.10):**

```yaml
# -- Env-wide observability: enabled | otlpEndpoint | deploymentEnvironment.
# With enabled=true and no otlpEndpoint, the pods ship to the node-local
# collector at http://$(HOST_IP):4317.
# Example: observability: { enabled: true }
observability: {}
```

**After (v1.0.11):**

```yaml
# -- Env-wide observability: enabled | otlpEndpoint | deploymentEnvironment | allowInsecureOtel.
# With enabled=true and no otlpEndpoint, the pods ship to the node-local
# collector at http://$(HOST_IP):4317.
# Example: observability: { enabled: true }
observability: {}
# example ↓ (uncomment & fill; comments render nothing = default stays empty):
#   enabled: true
#   allowInsecureOtel: "node-local collector on the pod's own node"
```

The `common.cors` section also received expanded documentation explaining the new `ALLOW_INSECURE_OTEL` resolution logic:

```yaml
# ALLOW_INSECURE_OTEL — with telemetry on and no endpoint set, the pod ships to the
# node-local collector at $(HOST_IP):4317 in plaintext, which lib-observability
# refuses in production unless ALLOW_INSECURE_OTEL carries a reason. The chart sets it
# on the container: worker.configmap (worker pod), else
# common.configmap.ALLOW_INSECURE_OTEL, else security.allowInsecureOtel, else
# global.observability.allowInsecureOtel, else "node-local collector on the pod's own
# node". "" or "false" refuses (the app then will not boot on the node-local hop in
# production); null is unset. See the README.
```

## Template Changes

### OTEL Pod Environment Resolution Logic

The `_helpers.tpl` template file contains significant changes to how `ALLOW_INSECURE_OTEL` is resolved and injected into pod environments when using node-local OTLP collectors.

#### What Changed

**Before (v1.0.10):**

The helper unconditionally called `lerian-common.otel.podEnv` with only a port number:

```yaml
{{- if and $telemetry (not (or (hasKey $cm "OTEL_EXPORTER_OTLP_ENDPOINT") $obs.otlpEndpoint (hasKey $x "OTEL_EXPORTER_OTLP_ENDPOINT"))) }}
{{ include "lerian-common.otel.podEnv" (dict "port" 4317) }}
{{- end }}
```

**After (v1.0.11):**

The helper now implements a multi-source resolution strategy with precedence logic:

```yaml
{{- if and $telemetry (not (or (hasKey $cm "OTEL_EXPORTER_OTLP_ENDPOINT") $obs.otlpEndpoint (hasKey $x "OTEL_EXPORTER_OTLP_ENDPOINT"))) }}
{{- /* ALLOW_INSECURE_OTEL is a modeled setting: the worker's own configmap (worker
   pod), then common.configmap, then common.security.allowInsecureOtel, then
   global.observability.allowInsecureOtel, then the node-local reason; lerian-common
   resolves it and emits the one env entry. A key in this pod's extraEnvVars or a
   non-empty common.secrets value (the legacy routes; the Secret
   only while the model is unset) still stands, so the helper adds
   no duplicate then. An existing Secret (common.useExistingSecret) is not visible to the
   chart, so a value there is overridden by this entry; set the configmap key instead. */}}
{{- /* Chosen by presence, not merged: sprig merge fills an empty value from the next
   map, which would turn a worker refusal ("") into the common value. null is unset. */}}
{{- $otelCm := dict }}
{{- $otelSources := list (dict "map" (ternary (.Values.worker.configmap | default dict) dict (eq $component "worker")) "key" "ALLOW_INSECURE_OTEL") (dict "map" $cm "key" "ALLOW_INSECURE_OTEL") (dict "map" (.Values.common.security | default dict) "key" "allowInsecureOtel") }}
{{- range $otelSources }}
{{- if and (not (hasKey $otelCm "ALLOW_INSECURE_OTEL")) (hasKey .map .key) (not (kindIs "invalid" (index .map .key))) }}
{{- $_ := set $otelCm "ALLOW_INSECURE_OTEL" (index .map .key) }}
{{- end }}
{{- end }}
{{- /* The model wins over the Secret: a configmap, knob or global value (a refusal too) keeps the entry. */}}
{{- $otelModelSet := or (not (kindIs "invalid" (index $otelCm "ALLOW_INSECURE_OTEL"))) (not (kindIs "invalid" (index ((.Values.global | default dict).observability | default dict) "allowInsecureOtel"))) }}
{{- $legacyAllow := or (hasKey $x "ALLOW_INSECURE_OTEL") (and (not $otelModelSet) (not .Values.common.useExistingSecret) (ne (toString (index (.Values.common.secrets | default dict) "ALLOW_INSECURE_OTEL" | default "")) "")) }}
{{ include "lerian-common.otel.podEnv" (dict "context" . "configmap" $otelCm "port" 4317 "allowInsecure" (not $legacyAllow)) }}
{{- end }}
```

#### Operational Impact

1. **Automatic Default Provisioning**: When telemetry is enabled with node-local collectors, the chart now automatically provides a default `ALLOW_INSECURE_OTEL` value, preventing production boot failures.

2. **Precedence-Based Resolution**: The template walks through configuration sources in order, selecting the first non-null value. This allows fine-grained control at different scopes.

3. **Legacy Compatibility**: Existing `extraEnvVars` and `common.secrets` configurations continue to work, but the new model takes precedence when set.

4. **External Secret Override**: If you use `common.useExistingSecret: true`, the chart will override any `ALLOW_INSECURE_OTEL` value in that Secret with the configmap model. Migrate to configmap-based configuration.

5. **Explicit Refusal Support**: Setting `""` or `"false"` now correctly refuses insecure OTLP, causing production pods to fail fast if misconfigured rather than silently accepting insecure transport.

> **Important:** This change only affects pods that use node-local OTLP collectors (telemetry enabled without an explicit endpoint). If you set `observability.otlpEndpoint`, this logic does not apply.

## Migration Steps

1. **Review Current Telemetry Configuration**

   Check if you have telemetry enabled and how you currently configure OTLP endpoints:

   ```bash
   helm get values br-sta -n br-sta -o yaml | grep -A 5 observability
   ```

2. **Identify Existing ALLOW_INSECURE_OTEL Settings**

   Check if you currently set this variable via Secrets or extraEnvVars:

   ```bash
   helm get values br-sta -n br-sta -o yaml | grep -i allow_insecure_otel
   ```

3. **Choose Migration Strategy**

   Based on your current configuration:
   - **No telemetry or explicit OTLP endpoint**: No action required
   - **Node-local collector with no current ALLOW_INSECURE_OTEL**: Accept the default (no action required)
   - **Existing Secret-based configuration**: Migrate to configmap model (see Option 4 above)
   - **External Secret (`useExistingSecret: true`)**: Migrate to configmap model to prevent override
   - **Security policy requires explicit refusal**: Set empty string (see Option 3 above)

4. **Update Values File**

   Prepare your complete values file with any necessary changes from the migration options above.

5. **Test in Non-Production**

   Deploy to a non-production environment first and verify:
   - Pods start successfully with telemetry enabled
   - OTLP connections work as expected
   - No unexpected environment variable duplicates

   ```bash
   kubectl get pods -n br-sta -l app.kubernetes.io/instance=br-sta
   kubectl describe pod <manager-pod-name> -n br-sta | grep -A 10 "Environment:"
   ```

6. **Verify OTEL Configuration**

   After upgrade, confirm the effective `ALLOW_INSECURE_OTEL` value in running pods:

   ```bash
   kubectl exec -n br-sta deployment/br-sta-manager -- env | grep ALLOW_INSECURE_OTEL
   ```

> **Note:** If you see duplicate `ALLOW_INSECURE_OTEL` entries in pod environments, you have both the new configmap model and a legacy configuration (extraEnvVars or Secret). Remove the legacy configuration to avoid confusion.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.11
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.11
```
<!-- {% endraw %} -->
