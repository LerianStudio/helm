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

This guide covers the `plugin-br-payments` chart upgrade from `2.0.2` to `2.1.0`. The application version remains `1.0.2`; the chart bump to `2.1.0` is a minor release that introduces a single feature: a hardcoded `SHUTDOWN_DRAIN_DELAY` environment variable set to `15s` in the deployment template to enable graceful shutdown behavior.

This upgrade requires no operator action beyond running the upgrade command. Existing deployments will continue to work without values changes. The new environment variable is automatically injected into all plugin pods.

## Features

### 1. Graceful shutdown drain delay

The deployment template now injects a `SHUTDOWN_DRAIN_DELAY` environment variable set to `15s` into the application container. This variable instructs the application binary to wait 15 seconds after receiving a SIGTERM signal before beginning its shutdown sequence, allowing in-flight requests to complete and giving load balancers and service meshes time to remove the pod from their routing tables.

**Before (v2.0.2):**

The deployment template did not set `SHUTDOWN_DRAIN_DELAY`. The application would begin shutdown immediately upon receiving SIGTERM, potentially dropping in-flight requests.

**After (v2.1.0):**

```yaml
env:
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
```

**Operational impact:**

When a pod is terminated (during a rolling update, scale-down, or node drain), Kubernetes sends a SIGTERM signal to the application process. With the new `SHUTDOWN_DRAIN_DELAY` variable, the application will:

1. Receive SIGTERM
2. Wait 15 seconds (the drain delay)
3. Stop accepting new requests
4. Complete in-flight requests
5. Shut down cleanly

This behavior reduces the likelihood of dropped requests during pod termination. The 15-second delay is hardcoded in the chart and cannot be overridden via values.yaml in this release.

> **Note:** The 15-second drain delay is independent of the pod's `terminationGracePeriodSeconds` setting (which defaults to 30 seconds in Kubernetes). The application must complete its shutdown within the termination grace period, or Kubernetes will send a SIGKILL. The default 30-second grace period provides sufficient time for the 15-second drain delay plus additional shutdown work.

> **Important:** If your deployment overrides `terminationGracePeriodSeconds` to a value less than 15 seconds, the pod may be forcefully killed before the drain delay completes. Ensure `terminationGracePeriodSeconds` is at least 20 seconds (15s drain + 5s shutdown buffer) if you have customized this value.

## Configuration Changes

| Setting | v2.0.2 | v2.1.0 |
|---------|--------|--------|
| `SHUTDOWN_DRAIN_DELAY` environment variable | not set | `"15s"` (hardcoded) |

No new values were added to `values.yaml`. The `SHUTDOWN_DRAIN_DELAY` environment variable is injected directly in the deployment template and is not configurable via values overrides in this release.

### New Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `"15s"` | Duration to wait after receiving SIGTERM before beginning shutdown sequence. Allows in-flight requests to complete and gives load balancers time to deregister the pod. |

## Migration Steps

1. Review your deployment's `terminationGracePeriodSeconds` setting (if customized). If you have set this value to less than 20 seconds, consider increasing it to allow the 15-second drain delay to complete:

```yaml
# Example values override (only if you previously customized terminationGracePeriodSeconds)
podSpec:
  terminationGracePeriodSeconds: 30
```

2. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

4. Confirm the `SHUTDOWN_DRAIN_DELAY` environment variable is set in the running pods:

```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=plugin-br-payments -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="SHUTDOWN_DRAIN_DELAY")].value}'
```

Expected output:

```
15s
```

5. **(Optional)** Test graceful shutdown behavior by triggering a rolling restart and observing application logs:

```bash
kubectl rollout restart deployment/plugin-br-payments -n <namespace>
kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-br-payments --tail=50 -f
```

Look for log entries indicating the application is waiting for the drain delay before shutting down.

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions. The new graceful shutdown behavior will reduce (but not eliminate) the risk of dropped requests during future rolling updates.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 2.1.0 -n plugin-br-payments
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 2.1.0 -n plugin-br-payments
```
