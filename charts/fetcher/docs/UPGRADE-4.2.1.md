# Helm Upgrade from v4.2.0 to v4.2.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Insecure OTEL configuration support](#1-insecure-otel-configuration-support)
  - [2. Dependency update: lerian-common-helm 2.7.0](#2-dependency-update-lerian-common-helm-270)
- **[Configuration Changes](#configuration-changes)**
  - [New observability configuration](#new-observability-configuration)
  - [Environment variable precedence](#environment-variable-precedence)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `4.2.0` to `4.2.1`. This is a **patch** release that adds support for configuring insecure OTEL (OpenTelemetry) endpoints in production environments and updates the `lerian-common-helm` dependency to version `2.7.0`.

The application version (`appVersion: 4.1.0`) is unchanged. No breaking changes or data migration are required. Existing installations will continue to work without modification, but operators using plaintext OTEL collectors (such as node-local collectors) can now explicitly configure the `ALLOW_INSECURE_OTEL` setting through the values hierarchy.

## Fixes

### 1. Insecure OTEL configuration support

The chart now provides a modeled configuration path for the `ALLOW_INSECURE_OTEL` environment variable, which is required by `lib-observability` when exporting telemetry to a plaintext OTLP endpoint in production. Previously, operators had to set this variable through `extraEnvVars` or component secrets, which bypassed the chart's configuration model.

**Why this matters:**

When observability is enabled with the default node-local collector endpoint (`http://$(HOST_IP):4317`), the OTLP exporter uses plaintext (no TLS). The `lib-observability` library refuses to initialize a plaintext exporter in production unless the `ALLOW_INSECURE_OTEL` environment variable contains a reason string (e.g., `"node-local collector on the pod's own node"`). Without this variable, telemetry initialization fails and the application may not start correctly.

**What changed:**

The chart now supports setting `ALLOW_INSECURE_OTEL` through a three-tier configuration hierarchy:

1. **Component-level:** `manager.configmap.ALLOW_INSECURE_OTEL` or `worker.configmap.ALLOW_INSECURE_OTEL`
2. **Common-level:** `common.configmap.ALLOW_INSECURE_OTEL`
3. **Global-level:** `global.observability.allowInsecureOtel`

The component-level setting takes precedence, followed by common, then global. A `null` value at any tier means "unset" and the next tier is consulted. An empty string (`""`) or `"false"` is an explicit refusal and will prevent the plaintext exporter from initializing.

**Default behavior:**

When observability is enabled and no explicit `ALLOW_INSECURE_OTEL` setting is provided, the chart now automatically sets the variable to `"node-local collector on the pod's own node"` for both manager and worker containers. This default applies only when using the node-local hop (the default `http://$(HOST_IP):4317` endpoint).

**Before (v4.2.0):**

Operators had to manually configure the variable through `extraEnvVars`:

```yaml
manager:
  extraEnvVars:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"

worker:
  extraEnvVars:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

**After (v4.2.1):**

The variable is automatically set when observability is enabled, or can be configured through the values hierarchy:

```yaml
# Option 1: Set globally for all components
global:
  observability:
    enabled: true
    allowInsecureOtel: "node-local collector on the pod's own node"

# Option 2: Set at common level
common:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"

# Option 3: Set per component
manager:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"

worker:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

> **Note:** If you were previously setting `ALLOW_INSECURE_OTEL` through `extraEnvVars` or component secrets, those settings will continue to work and take precedence over the new configuration model. No action is required for existing installations.

> **Important:** Setting the value to an empty string (`""`) or `"false"` explicitly refuses the plaintext exporter. If you are using a plaintext OTEL endpoint, ensure the variable contains a non-empty reason string.

### 2. Dependency update: lerian-common-helm 2.7.0

The `lerian-common-helm` dependency has been updated from version `2.6.0` to `2.7.0`. This update provides the underlying template functions used by the new `ALLOW_INSECURE_OTEL` configuration model.

| Dependency | v4.2.0 | v4.2.1 |
|------------|--------|--------|
| `lerian-common-helm` | `2.6.0` | `2.7.0` |

> **Note:** This dependency update is transparent to operators. No configuration changes are required.

## Configuration Changes

### New observability configuration

The `global.observability` block now supports an `allowInsecureOtel` field:

| Field | Default | Description |
|-------|---------|-------------|
| `global.observability.allowInsecureOtel` | (not set) | Reason string for allowing plaintext OTLP exporters in production. When set, this value is used as the default for `ALLOW_INSECURE_OTEL` across all components unless overridden at the common or component level. |

**Example configuration:**

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
    allowInsecureOtel: "node-local collector on the pod's own node"
```

The `common.configmap` block now documents the `ALLOW_INSECURE_OTEL` key:

```yaml
common:
  configmap:
    # Set ALLOW_INSECURE_OTEL to allow plaintext OTLP exporters
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

Component-level overrides are also supported:

```yaml
manager:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"

worker:
  configmap:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

### Environment variable precedence

The `ALLOW_INSECURE_OTEL` environment variable is resolved using the following precedence order (highest to lowest):

1. **Component `extraEnvVars`:** A key in `manager.extraEnvVars` or `worker.extraEnvVars` takes absolute precedence
2. **Component secrets:** A non-empty value in `manager.secrets.ALLOW_INSECURE_OTEL` or `worker.secrets.ALLOW_INSECURE_OTEL` (or the shared `secrets.ALLOW_INSECURE_OTEL`)
3. **Component configmap:** `manager.configmap.ALLOW_INSECURE_OTEL` or `worker.configmap.ALLOW_INSECURE_OTEL`
4. **Common configmap:** `common.configmap.ALLOW_INSECURE_OTEL`
5. **Global observability:** `global.observability.allowInsecureOtel`
6. **Chart default:** `"node-local collector on the pod's own node"` (only when using the node-local hop)

> **Important:** A `null` value at any tier means "unset" and the next tier is consulted. An empty string (`""`) or `"false"` is an explicit refusal and stops the precedence chain.

**Precedence table:**

| Setting | v4.2.0 | v4.2.1 |
|---------|--------|--------|
| `manager.extraEnvVars.ALLOW_INSECURE_OTEL` | Supported (highest precedence) | Supported (highest precedence) |
| `manager.secrets.ALLOW_INSECURE_OTEL` | Supported | Supported |
| `manager.configmap.ALLOW_INSECURE_OTEL` | Not modeled | Supported (new) |
| `common.configmap.ALLOW_INSECURE_OTEL` | Not modeled | Supported (new) |
| `global.observability.allowInsecureOtel` | Not supported | Supported (new) |
| Chart default (node-local hop) | Not set | `"node-local collector on the pod's own node"` |

## Migration Steps

This upgrade requires no manual migration steps. The chart will automatically apply the new configuration model during the Helm upgrade.

**Recommended upgrade process:**

1. Review your current observability configuration. If you are using the default node-local collector endpoint (`http://$(HOST_IP):4317`) and have not explicitly set `ALLOW_INSECURE_OTEL`, the chart will now set it automatically.

2. If you were previously setting `ALLOW_INSECURE_OTEL` through `extraEnvVars` or secrets, those settings will continue to work. Consider migrating to the new configuration model for consistency:

   **Before (v4.2.0):**

   ```yaml
   manager:
     extraEnvVars:
       ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
   
   worker:
     extraEnvVars:
       ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
   ```

   **After (v4.2.1):**

   ```yaml
   global:
     observability:
       enabled: true
       allowInsecureOtel: "node-local collector on the pod's own node"
   ```

3. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. Run the upgrade command during a maintenance window.

5. Verify the manager and worker pods are healthy after the upgrade:

   ```bash
   kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=fetcher
   ```

6. Check manager and worker logs to confirm telemetry is initializing correctly:

   ```bash
   kubectl logs -n midaz-plugins -l app.kubernetes.io/component=manager --tail=50 | grep -i otel
   kubectl logs -n midaz-plugins -l app.kubernetes.io/component=worker --tail=50 | grep -i otel
   ```

> **Note:** If you are using a custom OTEL endpoint with TLS, no changes are required. The `ALLOW_INSECURE_OTEL` variable is only needed for plaintext endpoints.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm -n midaz-plugins --version 4.2.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm -n midaz-plugins --version 4.2.1
```
