<!-- {% raw %} -->
# Helm Upgrade from v1.2.0 to v1.2.1

## Topics

- **[Overview](#overview)**
- **[Dependency Update](#dependency-update)**
- **[New Configuration: ALLOW_INSECURE_OTEL](#new-configuration-allow_insecure_otel)**
  - [What changed](#what-changed)
  - [Why it matters](#why-it-matters)
  - [How to configure](#how-to-configure)
  - [Migration guidance](#migration-guidance)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a patch release that updates the `lerian-common-helm` dependency and introduces a new OpenTelemetry security configuration option.

| Setting | v1.2.0 | v1.2.1 |
|---------|--------|--------|
| Chart version | `1.2.0` | `1.2.1` |
| App version | `1.0.0-beta.86` | `1.0.0-beta.86` |
| lerian-common-helm dependency | `2.6.1` | `2.7.0` |

**What changed:**
- `lerian-common-helm` dependency upgraded from `2.6.1` to `2.7.0`
- New `ALLOW_INSECURE_OTEL` configuration option for OpenTelemetry plaintext transport
- New `global.observability.allowInsecureOtel` field for environment-wide OTEL security settings
- ConfigMap template now renders `ALLOW_INSECURE_OTEL` with fallback logic
- Deployment template now passes `ALLOW_INSECURE_OTEL` to the `lerian-common.otel.podEnv` helper

**What stayed the same:**
- Application version remains `1.0.0-beta.86`
- All existing values.yaml defaults unchanged
- No breaking changes to existing configuration

**Impact:** This upgrade is backward compatible. If you are using OpenTelemetry (`plugin-br-ted-lerian.otel.enabled: true`) with the node-local collector in production, the application will now require an explicit `ALLOW_INSECURE_OTEL` setting to permit plaintext transport. The chart provides a default reason, so no immediate action is required unless you want to customize the security justification.

---

## Dependency Update

The `lerian-common-helm` dependency has been updated from version `2.6.1` to `2.7.0`. This update brings the new `lerian-common.otel.podEnv` helper that supports the `ALLOW_INSECURE_OTEL` configuration.

| Dependency | v1.2.0 | v1.2.1 |
|------------|--------|--------|
| lerian-common-helm | `2.6.1` | `2.7.0` |

**Impact:** The dependency update is transparent to operators. The new version is automatically pulled when you upgrade the chart. No values changes are required.

---

## New Configuration: ALLOW_INSECURE_OTEL

### What changed

The chart now supports configuring `ALLOW_INSECURE_OTEL`, an environment variable that controls whether the application permits plaintext OpenTelemetry transport to the node-local collector in production environments.

**Before (v1.2.0):**

The `ALLOW_INSECURE_OTEL` variable could only be set via:
- `plugin-br-ted-lerian.extraEnvVars` (manual env entry)
- `plugin-br-ted-lerian.secrets.ALLOW_INSECURE_OTEL` (secret-based)

**After (v1.2.1):**

The variable is now a first-class configuration option with three levels of precedence:

1. `plugin-br-ted-lerian.configmap.ALLOW_INSECURE_OTEL` (component-specific)
2. `global.observability.allowInsecureOtel` (environment-wide)
3. Default: `"node-local collector on the pod's own node"` (automatic fallback)

The ConfigMap template now includes:

```yaml
data:
  ALLOW_INSECURE_OTEL: {{ value from configmap, global, or default }}
```

The Deployment template now passes the setting to the `lerian-common.otel.podEnv` helper, which emits the environment variable when OpenTelemetry is enabled.

### Why it matters

When OpenTelemetry is enabled (`plugin-br-ted-lerian.otel.enabled: true`), the application ships telemetry to a node-local collector at `$(HOST_IP):4317` using plaintext HTTP. The `lib-observability` library refuses plaintext transport in production unless `ALLOW_INSECURE_OTEL` carries a security justification string.

**Without this setting:** In production environments, the application will fail to start if OpenTelemetry is enabled and the node-local collector uses plaintext transport.

**With this setting:** Operators can explicitly document why plaintext transport is acceptable (e.g., "node-local collector on the pod's own node", "internal network with mTLS at the gateway").

### How to configure

#### Option 1: Use the default (recommended for node-local collectors)

If you are using the node-local collector pattern (collector runs on each node, pods ship to `$(HOST_IP):4317`), no action is required. The chart automatically sets:

```yaml
ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

#### Option 2: Set a custom reason at the component level

Override the default with a custom justification in your values file:

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: "internal network with mTLS at the gateway"
```

#### Option 3: Set a custom reason environment-wide

For multi-chart deployments sharing the same security posture, set it globally:

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    allowInsecureOtel: "internal network with mTLS at the gateway"
```

All charts consuming `global.observability` will inherit this setting.

#### Option 4: Refuse plaintext transport

To explicitly refuse plaintext transport (force the application to fail if plaintext is configured):

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: ""
```

Or:

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: "false"
```

> **Warning:** Setting `ALLOW_INSECURE_OTEL` to an empty string or `"false"` will cause the application to refuse to start if OpenTelemetry is enabled with a plaintext endpoint in production.

#### Option 5: Unset the variable

To leave `ALLOW_INSECURE_OTEL` unset (not rendered in the ConfigMap):

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: null
```

And:

```yaml
global:
  observability:
    allowInsecureOtel: null
```

> **Note:** If both are `null`, the chart will not render `ALLOW_INSECURE_OTEL` in the ConfigMap, and the application will use its internal default behavior.

### Migration guidance

**If you are NOT using OpenTelemetry:**

No action required. The `ALLOW_INSECURE_OTEL` setting only affects deployments with `plugin-br-ted-lerian.otel.enabled: true`.

**If you are using OpenTelemetry with the node-local collector:**

No action required. The chart now automatically sets `ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"`, which satisfies the `lib-observability` security check.

**If you previously set `ALLOW_INSECURE_OTEL` via `extraEnvVars`:**

Your existing configuration continues to work. The chart detects `extraEnvVars` entries and does not override them. However, we recommend migrating to the new model for consistency:

**Before (v1.2.0):**

```yaml
plugin-br-ted-lerian:
  extraEnvVars:
    - name: ALLOW_INSECURE_OTEL
      value: "internal network with mTLS at the gateway"
```

**After (v1.2.1):**

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: "internal network with mTLS at the gateway"
```

Then remove the `extraEnvVars` entry.

**If you previously set `ALLOW_INSECURE_OTEL` via `secrets`:**

Your existing configuration continues to work if you are using `plugin-br-ted-lerian.useExistingSecret: false`. However, the new model takes precedence:

- If you set `plugin-br-ted-lerian.configmap.ALLOW_INSECURE_OTEL` or `global.observability.allowInsecureOtel`, the chart will use that value and ignore the secret.
- If you are using `plugin-br-ted-lerian.useExistingSecret: true`, the chart cannot see the secret's contents, so you must migrate to the new model:

**Before (v1.2.0):**

```yaml
plugin-br-ted-lerian:
  secrets:
    ALLOW_INSECURE_OTEL: "internal network with mTLS at the gateway"
```

**After (v1.2.1):**

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: "internal network with mTLS at the gateway"
```

Then remove the `secrets` entry.

> **Important:** If you are using `useExistingSecret: true` and have `ALLOW_INSECURE_OTEL` in your external secret, the chart will override it with the ConfigMap value. Set `plugin-br-ted-lerian.configmap.ALLOW_INSECURE_OTEL` explicitly to match your secret's value, or remove the secret entry and let the chart manage it.

| Configuration Method | v1.2.0 Support | v1.2.1 Support | Recommended |
|---------------------|----------------|----------------|-------------|
| `plugin-br-ted-lerian.configmap.ALLOW_INSECURE_OTEL` | ❌ | ✅ | ✅ |
| `global.observability.allowInsecureOtel` | ❌ | ✅ | ✅ |
| `plugin-br-ted-lerian.extraEnvVars` | ✅ | ✅ | ❌ (legacy) |
| `plugin-br-ted-lerian.secrets.ALLOW_INSECURE_OTEL` | ✅ | ✅ | ❌ (legacy) |

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.2.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.2.1
```
<!-- {% endraw %} -->
