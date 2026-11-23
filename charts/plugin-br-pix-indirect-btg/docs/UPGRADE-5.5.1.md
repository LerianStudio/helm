# Helm Upgrade from v5.5.0 to v5.5.1

## Topics

- **[Overview](#overview)**
- **[Dependency Updates](#dependency-updates)**
- **[New Configuration](#new-configuration)**
  - [1. ALLOW_INSECURE_OTEL environment variable](#1-allow_insecure_otel-environment-variable)
  - [2. Global observability settings](#2-global-observability-settings)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that upgrades the `lerian-common-helm` dependency from `2.6.0` to `2.7.0` and introduces explicit configuration for the `ALLOW_INSECURE_OTEL` environment variable across all service components. The application version remains `1.15.0` and no existing values are removed or renamed, so existing custom values continue to work without changes.

The expected upgrade path is an in-place Helm upgrade after reviewing the new telemetry configuration options.

## Dependency Updates

The chart now depends on `lerian-common-helm` version `2.7.0`, which provides the `lerian-common.otel.allowInsecure` template helper used for telemetry configuration.

| Dependency | v5.5.0 | v5.5.1 |
|------------|--------|--------|
| `lerian-common-helm` | `2.6.0` | `2.7.0` |

## New Configuration

### 1. ALLOW_INSECURE_OTEL environment variable

All five service components (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) now support explicit configuration of the `ALLOW_INSECURE_OTEL` environment variable. This variable controls whether the application accepts plaintext telemetry connections to the node-local OpenTelemetry collector.

**What changed:**

When the node-local collector is enabled (`otel-collector-lerian.enabled: true`), each component sends telemetry to `$(HOST_IP):4317` in plaintext. The `lib-observability` library refuses plaintext connections in production environments unless `ALLOW_INSECURE_OTEL` carries a justification string explaining why insecure transport is acceptable.

The chart now sets `ALLOW_INSECURE_OTEL` automatically using a three-level fallback:

1. Component-specific setting: `<component>.configmap.ALLOW_INSECURE_OTEL`
2. Global setting: `global.observability.allowInsecureOtel`
3. Default reason: `"node-local collector on the pod's own node"`

**Why it matters:**

Without this variable set in production deployments, applications using `lib-observability` will refuse to start when the node-local collector is enabled, because the plaintext connection to `$(HOST_IP):4317` is rejected by the library's security checks.

**Configuration precedence:**

The chart resolves `ALLOW_INSECURE_OTEL` in the following order (first match wins):

1. **extraEnvVars override** — If you set `ALLOW_INSECURE_OTEL` in `<component>.extraEnvVars`, that value is used and the chart adds no ConfigMap or Deployment entry.
2. **Component-specific setting** — `<component>.configmap.ALLOW_INSECURE_OTEL` (set per service).
3. **Global setting** — `global.observability.allowInsecureOtel` (applies to all services).
4. **Chart default** — `"node-local collector on the pod's own node"` (applied by the `lerian-common.otel.allowInsecure` template helper when the node-local collector is enabled).

**New environment variable:**

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_OTEL` | `"node-local collector on the pod's own node"` | Justification string required by `lib-observability` to accept plaintext telemetry connections in production. Set to `""` or `"false"` to refuse insecure connections. Set to `null` to leave unset. |

**Example configuration (component-specific):**

```yaml
pix:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"

inbound:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"

outbound:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"

reconciliation:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"

schedule:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

**Example configuration (global):**

```yaml
global:
  observability:
    allowInsecureOtel: "node-local collector on the pod's own node"
```

> **Note:** The chart default reason is applied automatically when `otel-collector-lerian.enabled: true` and no explicit value is set. You only need to override this if you want a different justification string or need to disable insecure connections by setting the value to `""` or `"false"`.

**Disabling insecure telemetry:**

To refuse plaintext telemetry connections (for example, when using an external collector with TLS), set the variable to an empty string or `"false"`:

```yaml
global:
  observability:
    allowInsecureOtel: ""
```

Or per component:

```yaml
pix:
  configmap:
    ALLOW_INSECURE_OTEL: "false"
```

> **Warning:** Setting `ALLOW_INSECURE_OTEL` to `""` or `"false"` will cause the application to refuse to start in production if the node-local collector is enabled and no alternative secure endpoint is configured.

**Unsetting the variable:**

To leave `ALLOW_INSECURE_OTEL` unset (not rendered in the ConfigMap or Deployment), set the value to `null`:

```yaml
pix:
  configmap:
    ALLOW_INSECURE_OTEL: null
```

### 2. Global observability settings

A new `global.observability` block has been added to `values.yaml` to provide environment-wide telemetry configuration.

**New values block:**

```yaml
global:
  observability: {}
  # example ↓ (uncomment & fill; comments render nothing = default stays empty):
  #   allowInsecureOtel: "node-local collector on the pod's own node"
```

**Fields:**

| Field | Default | Description |
|-------|---------|-------------|
| `allowInsecureOtel` | (unset) | Env-wide justification string for plaintext telemetry connections. Applied to all components unless overridden by `<component>.configmap.ALLOW_INSECURE_OTEL`. |

**Why it matters:**

The `global.observability` block allows operators to set telemetry security policy once for the entire chart instead of repeating the same value across all five service components.

**Example usage:**

```yaml
global:
  observability:
    allowInsecureOtel: "node-local collector on the pod's own node"

otel-collector-lerian:
  enabled: true
```

This configuration applies the justification string to all components (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) without requiring per-component overrides.

## Migration Steps

This upgrade requires no destructive migration steps. The chart applies a default value for `ALLOW_INSECURE_OTEL` when the node-local collector is enabled, so existing deployments will continue to work without configuration changes.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. If you are running in a production environment and want to customize the `ALLOW_INSECURE_OTEL` justification string, add the `global.observability.allowInsecureOtel` setting to your values file before upgrading.
3. If you need to disable insecure telemetry connections, set `global.observability.allowInsecureOtel: ""` or `"false"` and configure an alternative secure telemetry endpoint.
4. Run the upgrade command during a maintenance window.
5. Verify all pods are running and healthy after the upgrade.

```bash
kubectl get pods -n midaz-plugins
```

6. Check service logs to confirm telemetry is being exported correctly.

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
```

> **Note:** The upgrade triggers a rolling restart of all five service deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) because the ConfigMap and Deployment specs change. Depending on your replica count and readiness probe timing, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.5.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.5.1
```
