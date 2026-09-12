# Helm Upgrade from v4.0.3 to v4.0.4

## Topics

- **[Overview](#overview)**
- **[Documentation Changes](#documentation-changes)**
  - [1. Authorization configuration precedence clarified](#1-authorization-configuration-precedence-clarified)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that adds inline documentation to clarify the authorization configuration precedence and default behavior. No template logic, default values, or application version have changed.

| Field | v4.0.3 | v4.0.4 |
|-------|--------|--------|
| Chart version | `4.0.3` | `4.0.4` |
| App version | `1.12.0` | `1.12.0` |

## Documentation Changes

### 1. Authorization configuration precedence clarified

The `global.auth` comment block in `values.yaml` has been expanded to document the configuration precedence and default behavior for the Access Manager (plugin-auth) integration.

**Before (v4.0.3):**

```yaml
# -- Env-wide Access Manager (plugin-auth) gate/host. Consumed by
# lerian-common.globalValue (block "auth"). Fields: enabled, host.
# (configmap.PLUGIN_AUTH_ENABLED / PLUGIN_AUTH_HOST override.)
auth: {}
```

**After (v4.0.4):**

```yaml
# -- Env-wide Access Manager (plugin-auth) gate/host. Consumed by
# lerian-common.globalValue (block "auth"). Fields: enabled, host.
# (configmap.PLUGIN_AUTH_ENABLED / PLUGIN_AUTH_HOST override.)
# Precedence: configmap.PLUGIN_AUTH_ENABLED, then global.auth.enabled, then
# the chart default "false" (AUTHORIZATION OFF). The console only enforces
# permissions when the rendered value is the word "true". Set enabled: true
# explicitly on every staging/production release (see README, "Authorization
# is OFF").
auth: {}
```

**What changed:**

The comment now explicitly documents:

- **Precedence order:** `configmap.PLUGIN_AUTH_ENABLED` takes highest precedence, followed by `global.auth.enabled`, then the chart default of `false`
- **Default behavior:** Authorization is **OFF** by default
- **Enforcement condition:** The console only enforces permissions when the rendered value is the string `"true"`
- **Operator guidance:** Authorization should be explicitly enabled (`enabled: true`) on every staging and production release

**Why this matters:**

Authorization is a critical security control. The expanded documentation makes it clear that:

1. The chart defaults to **authorization disabled** for backward compatibility and local development
2. Operators must **explicitly enable** authorization for staging and production environments
3. The precedence order determines which configuration value wins when multiple sources are set

> **Important:** This is a documentation-only change. If you are already setting `global.auth.enabled: true` or `configmap.PLUGIN_AUTH_ENABLED: "true"`, your authorization configuration is unaffected.

> **Warning:** If you are running product-console in staging or production environments and have **not** explicitly set `global.auth.enabled: true` or `configmap.PLUGIN_AUTH_ENABLED: "true"`, authorization is currently **disabled**. Review your values and enable authorization before upgrading.

## Migration Steps

This upgrade requires no configuration changes. The chart behavior is identical to v4.0.3.

**Recommended upgrade process:**

1. Review your current authorization configuration:

```bash
helm get values product-console -n product-console
```

2. Verify that authorization is explicitly enabled for staging and production environments. Check for one of:

```yaml
global:
  auth:
    enabled: true
```

or

```yaml
configmap:
  PLUGIN_AUTH_ENABLED: "true"
```

3. If authorization is not explicitly enabled and you are running in a non-development environment, add the configuration before upgrading:

```yaml
global:
  auth:
    enabled: true
    host: "your-plugin-auth-host"
```

4. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

5. Run the upgrade command.

6. Verify the deployment is healthy:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console
```

> **Note:** This upgrade does **not** trigger a pod restart unless you modify configuration values during the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.4 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.4 -n product-console
```
