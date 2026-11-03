<!-- {% raw %} -->
# Helm Upgrade from v1.1.1 to v1.2.0

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.1.1** to **1.2.0**. This minor release introduces graceful shutdown improvements and removes the deprecated `IS_DEVELOPMENT` license configuration flag.

## Table of Contents

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Graceful Shutdown Configuration](#1-graceful-shutdown-configuration)
  - [2. Deprecated License Development Flag Removal](#2-deprecated-license-development-flag-removal)
- **[Configuration Reference](#configuration-reference)**
  - [Termination Grace Period](#termination-grace-period)
  - [Shutdown Drain Delay](#shutdown-drain-delay)
  - [Removed Configuration](#removed-configuration)
  - [Environment Variables](#environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.2.0 introduces graceful shutdown improvements to the `plugin-br-sisbajud` chart, ensuring the application has sufficient time to drain in-flight requests and complete shutdown stages before Kubernetes terminates the pod. This release also removes the deprecated `IS_DEVELOPMENT` license flag.

**Key changes:**

- **Termination grace period increased** from 30 seconds to 105 seconds to accommodate shutdown stages
- **`SHUTDOWN_DRAIN_DELAY` environment variable** set to `15s` on the `sisbajud` container
- **`IS_DEVELOPMENT` license flag removed** from values.yaml and templates

> **Note:** The new termination grace period and `SHUTDOWN_DRAIN_DELAY` are applied automatically. If you set `sisbajud.license.isDevelopment` or `sisbajud.configmap.IS_DEVELOPMENT` to `"true"`, see [Migration Steps](#migration-steps).

## Features

### 1. Graceful Shutdown Configuration

The chart now configures a longer termination grace period and sets the `SHUTDOWN_DRAIN_DELAY` environment variable.


**Configuration changes:**

| Setting | v1.1.1 | v1.2.0 |
|---------|--------|--------|
| `sisbajud.terminationGracePeriodSeconds` | `30` | `105` |
| `SHUTDOWN_DRAIN_DELAY` environment variable | Not set | `15s` |

**Before (v1.1.1):**

```yaml
sisbajud:
  terminationGracePeriodSeconds: 30
```

**After (v1.2.0):**

```yaml
sisbajud:
  # SHUTDOWN_DRAIN_DELAY 15s + 90s of shutdown stages (HTTP drain, closeResources, telemetry flush).
  terminationGracePeriodSeconds: 105
```


**Operational impact:**

- The `terminationGracePeriodSeconds` is increased from 30 to 105 seconds, giving the application more time to complete shutdown stages
- The `SHUTDOWN_DRAIN_DELAY` environment variable is set to `15s`
- The `env` block is now unconditionally rendered (previously conditional on `$pgRef`, `$vkRef`, `$telemetry`, `$raOn`, or `$extra`)
- Pods will take up to 105 seconds to terminate gracefully during rolling updates or scale-down operations

> **Note:** The application image `1.1.0` that this chart deploys does not read `SHUTDOWN_DRAIN_DELAY`: it is built on lib-commons `v7.19.0`, and the variable arrives in lib-commons `v7.21.0`. Image `1.1.0` keeps its own fixed shutdown timings (a 12-second readiness drain and a 30-second HTTP shutdown budget), so with that image only the longer grace period changes.

> **Important:** If your deployment uses a custom `terminationGracePeriodSeconds` value, ensure it is at least 105 seconds to accommodate the shutdown stages. Values below 105 seconds may cause the pod to be forcefully terminated before completing graceful shutdown.

### 2. Deprecated License Development Flag Removal

The `IS_DEVELOPMENT` license flag has been removed from the chart. This flag was used to route the license library to a development gateway for dev-issued license keys.

**Configuration changes:**

| Setting | v1.1.1 | v1.2.0 |
|---------|--------|--------|
| `sisbajud.license.isDevelopment` | `""` (optional) | Removed from values.yaml; still validates, ignored |
| `IS_DEVELOPMENT` environment variable | Rendered if set | Not rendered in the ConfigMap |

**Before (v1.1.1):**

```yaml
sisbajud:
  license:
    organizationIds: "global"
    isDevelopment: ""  # Optional: "true" routes to dev gateway
```

**After (v1.2.0):**

```yaml
sisbajud:
  license:
    organizationIds: "global"
    # isDevelopment field removed
```

**Operational impact:**

- The `sisbajud.license.isDevelopment` field is removed from values.yaml; a value set there still validates and is ignored
- The `IS_DEVELOPMENT` environment variable is never rendered in the ConfigMap
- If `IS_DEVELOPMENT` is set via `sisbajud.configmap.IS_DEVELOPMENT`, it is silently ignored (accepted by the schema but never emitted)
- Development license keys are no longer supported; all deployments must use production license keys

> **Note:** If your deployment previously set `sisbajud.license.isDevelopment: "true"` or `sisbajud.configmap.IS_DEVELOPMENT: "true"`, you must obtain a production license key from Lerian Studio. The chart will render successfully but the application will reject development keys.

## Configuration Reference

### Termination Grace Period

| Flag | Default | Description |
|------|---------|-------------|
| `sisbajud.terminationGracePeriodSeconds` | `105` | Pod termination grace period in seconds (increased from 30 in v1.1.1) |

**Configuration example:**

```yaml
sisbajud:
  terminationGracePeriodSeconds: 105  # Default in v1.2.0
```

> **Warning:** Do not set this value below 105 seconds. Values below 105 may cause forceful termination and incomplete shutdown.

### Shutdown Drain Delay

The `SHUTDOWN_DRAIN_DELAY` environment variable is automatically set to `15s` in v1.2.0. This value is not configurable via the values schema.

**Environment variable:**

```yaml
env:
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
```


### Removed Configuration

The following configuration fields have been removed in v1.2.0:

| Field | Removed From | Replacement |
|-------|--------------|-------------|
| `sisbajud.license.isDevelopment` | `values.yaml` | None (use production license keys) |
| `IS_DEVELOPMENT` | ConfigMap environment variables | None |

**Migration:**

If your deployment previously used development license keys with `isDevelopment: "true"`, you must obtain a production license key from Lerian Studio and update your secrets:

```yaml
sisbajud:
  secrets:
    LICENSE_KEY: "production-license-key-here"
```

### Environment Variables

The following environment variable is added in v1.2.0:

| Variable | Source | Default | Description |
|----------|--------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | Deployment template | `15s` | Set by the Deployment template |

The following environment variable is removed in v1.2.0:

| Variable | Removed From | Reason |
|----------|--------------|--------|
| `IS_DEVELOPMENT` | ConfigMap | No longer rendered by the chart |

## Migration Steps

### For all deployments

No action required unless you set `sisbajud.license.isDevelopment` or `sisbajud.configmap.IS_DEVELOPMENT` to `"true"` (see below). The `SHUTDOWN_DRAIN_DELAY` variable is applied automatically during the upgrade, and so is the new termination grace period unless you set `sisbajud.terminationGracePeriodSeconds` yourself (see [For deployments with custom termination grace period](#for-deployments-with-custom-termination-grace-period)).

**Upgrade command:**

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n sisbajud
```

**Post-upgrade verification:**

1. Verify the pod has the new termination grace period:

```bash
kubectl get pod -n sisbajud -l app.kubernetes.io/name=plugin-br-sisbajud,app.kubernetes.io/component=sisbajud -o jsonpath='{.items[0].spec.terminationGracePeriodSeconds}'
```

Expected output: `105`

2. Verify the `SHUTDOWN_DRAIN_DELAY` environment variable is set:

```bash
kubectl get pod -n sisbajud -l app.kubernetes.io/name=plugin-br-sisbajud,app.kubernetes.io/component=sisbajud -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="SHUTDOWN_DRAIN_DELAY")].value}'
```

Expected output: `15s`

### For deployments using development license keys

If your deployment previously set `sisbajud.license.isDevelopment: "true"` or `sisbajud.configmap.IS_DEVELOPMENT: "true"`, you must obtain a production license key from Lerian Studio.

**Migration steps:**

1. Obtain a production license key from Lerian Studio support.

2. Update your values file to remove the `isDevelopment` field and set the production license key. With `sisbajud.useExistingSecret: true`, the chart renders no Secret: put the new `LICENSE_KEY` in the Secret named by `sisbajud.existingSecretName` instead.

**Before (v1.1.1):**

```yaml
sisbajud:
  license:
    organizationIds: "global"
    isDevelopment: "true"
  
  secrets:
    LICENSE_KEY: "dev-license-key"
```

**After (v1.2.0):**

```yaml
sisbajud:
  license:
    organizationIds: "global"
  
  secrets:
    LICENSE_KEY: "production-license-key-here"
```

3. Upgrade the chart with the updated values:

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n sisbajud -f values.yaml
```

> **Important:** The application will fail to start if the license key is invalid or expired and not in an active grace period. Verify the license key with Lerian Studio support before upgrading.

### For deployments with custom termination grace period

If your deployment overrides `sisbajud.terminationGracePeriodSeconds` with a value below 105 seconds, you must increase it to at least 105 seconds.

**Migration steps:**

1. Update your values file to set the termination grace period to at least 105 seconds:

**Before (v1.1.1):**

```yaml
sisbajud:
  terminationGracePeriodSeconds: 60  # Custom value
```

**After (v1.2.0):**

```yaml
sisbajud:
  terminationGracePeriodSeconds: 105  # Minimum required for graceful shutdown
```

2. Upgrade the chart with the updated values:

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n sisbajud -f values.yaml
```

> **Warning:** Values below 105 seconds may cause the pod to be forcefully terminated before completing graceful shutdown, resulting in incomplete telemetry flush, unclosed database connections, or lost in-flight requests.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n sisbajud
```
<!-- {% endraw %} -->
