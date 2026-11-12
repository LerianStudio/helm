# Helm Upgrade from v2.0.2 to v2.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Graceful shutdown drain delay](#1-graceful-shutdown-drain-delay)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.0.2` to `2.1.0`. The application version remains `1.0.2`; the chart bump to `2.1.0` is a minor release that introduces a single change: a hardcoded `SHUTDOWN_DRAIN_DELAY` environment variable set to `15s` in the deployment template. The default application image (`1.0.2`) does not read this variable, so this upgrade does not change application behavior.

This upgrade requires no operator action beyond running the upgrade command. Existing deployments will continue to work without values changes. The new environment variable is automatically injected into all plugin pods.

## Features

### 1. Graceful shutdown drain delay

The deployment template now sets `SHUTDOWN_DRAIN_DELAY` to `15s` on the application container. The default image (`1.0.2`) does not read it.

Rendered in v2.1.0:

```yaml
env:
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
```

The 15-second value is hardcoded in the chart and cannot be overridden via values.yaml in this release.

## Configuration Changes

| Setting | v2.0.2 | v2.1.0 |
|---------|--------|--------|
| `SHUTDOWN_DRAIN_DELAY` environment variable | not set | `"15s"` (hardcoded) |

No new values were added to `values.yaml`. The `SHUTDOWN_DRAIN_DELAY` environment variable is injected directly in the deployment template and is not configurable via values overrides in this release.

### New Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `"15s"` | Set by the chart. The default image (`1.0.2`) does not read it. |

## Migration Steps

1. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

2. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

3. Confirm the `SHUTDOWN_DRAIN_DELAY` environment variable is set in the running pods:

```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=plugin-br-payments -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="SHUTDOWN_DRAIN_DELAY")].value}'
```

Expected output:

```
15s
```

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --version 2.1.0 -n plugin-br-payments
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --version 2.1.0 -n plugin-br-payments
```
