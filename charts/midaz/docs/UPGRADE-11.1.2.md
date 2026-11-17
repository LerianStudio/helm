# Helm Upgrade from v11.1.1 to v11.1.2

## Topics

- **[Dependency Updates](#dependency-updates)**
  - [1. lerian-common-helm bump to 2.7.0](#1-lerian-common-helm-bump-to-270)
- **[Configuration Changes](#configuration-changes)**
  - [1. New ALLOW_INSECURE_OTEL configuration](#1-new-allow_insecure_otel-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Dependency Updates

### 1. lerian-common-helm bump to 2.7.0

Chart v11.1.2 updates the `lerian-common-helm` dependency from version `2.6.0` to `2.7.0`. This dependency provides shared templates and helpers for environment-wide configuration, including the new `lerian-common.otel.allowInsecure` helper used in this release.

| Setting | v11.1.1 | v11.1.2 |
|---------|---------|---------|
| `dependencies[lerian-common-helm].version` | 2.6.0 | 2.7.0 |

The dependency is automatically fetched during `helm dependency update` and enables the new OTEL insecure transport configuration described in [Configuration Changes](#configuration-changes).

> **Note:** The lerian-common-helm chart is hosted at `oci://ghcr.io/lerianstudio` and will be pulled automatically when you upgrade. No manual action is required.

## Configuration Changes

### 1. New ALLOW_INSECURE_OTEL configuration

Chart v11.1.2 introduces a new `ALLOW_INSECURE_OTEL` environment variable that controls whether OpenTelemetry exporters can use plaintext (non-TLS) connections to the OTLP endpoint. This setting is now configurable at both the global and per-component levels.

#### What changed

The `ALLOW_INSECURE_OTEL` environment variable is now rendered into the ConfigMap and Deployment templates for the `ledger`, `tracer`, and `crm` components. This variable allows operators to explicitly permit insecure OTEL connections when using node-local collectors or other plaintext endpoints.

| Component | v11.1.1 | v11.1.2 |
|-----------|---------|---------|
| `global.observability.allowInsecureOtel` | (not present) | `""` (optional) |
| `ledger.configmap.ALLOW_INSECURE_OTEL` | (not present) | `""` (optional) |
| `tracer.configmap.ALLOW_INSECURE_OTEL` | (not present) | `""` (optional) |
| `crm.configmap.ALLOW_INSECURE_OTEL` | (not present) | `""` (optional) |

#### Configuration precedence

The `ALLOW_INSECURE_OTEL` setting follows a three-tier precedence model:

1. **Native override** (highest): `<component>.extraEnvVars.ALLOW_INSECURE_OTEL`
2. **Component-level**: `<component>.configmap.ALLOW_INSECURE_OTEL`
3. **Global-level** (lowest): `global.observability.allowInsecureOtel`

When the node-local OTEL collector is enabled (`<component>.otelCollector.enabled: true`), the Deployment template automatically injects `ALLOW_INSECURE_OTEL` with a descriptive reason string. This injection only occurs if the variable is not already set via `extraEnvVars`.

#### Global configuration

To enable insecure OTEL connections for all components at once:

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector-lerian:4317"
    deploymentEnvironment: "production"
    allowInsecureOtel: "node-local collector on the pod's own node"
```

> **Note:** The value can be any string. It is typically used to document the reason for allowing insecure transport (e.g., "node-local collector", "internal plaintext endpoint").

#### Per-component configuration

To override the global setting for a specific component:

```yaml
ledger:
  configmap:
    ALLOW_INSECURE_OTEL: "plaintext endpoint for testing"
```

#### Legacy extraEnvVars override

If you have already set `ALLOW_INSECURE_OTEL` via `extraEnvVars`, the chart will respect that value and skip rendering the new ConfigMap and Deployment entries:

```yaml
ledger:
  extraEnvVars:
    ALLOW_INSECURE_OTEL: "custom reason"
```

> **Important:** The `extraEnvVars` route takes precedence over both the component-level and global-level settings. If you migrate to the new configuration surface, remove the `extraEnvVars` entry to avoid confusion.

#### Template changes

**Before (v11.1.1):**

The `ALLOW_INSECURE_OTEL` variable was not rendered by the chart. Operators had to set it manually via `extraEnvVars`.

**After (v11.1.2):**

The variable is now rendered into the ConfigMap when set at the component or global level:

```yaml
# ledger/configmap.yaml
data:
  ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

When the node-local OTEL collector is enabled, the Deployment template injects the variable as an environment entry:

```yaml
# ledger/deployment.yaml
env:
  - name: "ALLOW_INSECURE_OTEL"
    value: "node-local collector on the pod's own node"
```

The ConfigMap entry ensures the setting reaches the application even when the node-local collector is disabled (e.g., when using an explicit plaintext endpoint). The Deployment entry carries the same value when the collector is enabled.

#### Operational impact

This change is **backward compatible**. Existing installations that do not set `ALLOW_INSECURE_OTEL` will continue to work as before. The new configuration surface provides a standardized way to control insecure OTEL transport without relying on `extraEnvVars`.

If your environment uses plaintext OTEL endpoints (e.g., node-local collectors, internal testing endpoints), you should now configure `ALLOW_INSECURE_OTEL` explicitly via the global or component-level settings. This makes the configuration intent clear and avoids relying on application defaults.

#### New environment variable

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_OTEL` | `""` (unset) | Permits plaintext (non-TLS) OTLP connections. Set to any non-empty string to enable. The value is typically a reason string (e.g., "node-local collector"). |

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.1.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.1.2
```
