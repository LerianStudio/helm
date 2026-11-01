# Helm Upgrade from v5.1.1 to v5.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Graceful shutdown configuration for manager](#1-graceful-shutdown-configuration-for-manager)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that introduces graceful shutdown handling for the manager component. The chart now configures a shutdown drain delay and extends the pod termination grace period to allow in-flight requests to complete before the manager process exits.

| Field | v5.1.1 | v5.2.0 |
|-------|--------|--------|
| Chart version | `5.1.1` | `5.2.0` |
| App version | `4.6.0` | `4.6.0` |

## Features

### 1. Graceful shutdown configuration for manager

The manager deployment now includes a `SHUTDOWN_DRAIN_DELAY` environment variable and an extended `terminationGracePeriodSeconds` to ensure graceful shutdown during pod termination. This prevents connection errors and request failures when the manager pod is terminated during rolling updates or scale-down operations.

**What changed:**

- A new environment variable `SHUTDOWN_DRAIN_DELAY` is set to `15s` in the manager container
- The pod `terminationGracePeriodSeconds` is set to `55` seconds (calculated as: 15s drain delay + 30s application shutdown budget + 10s buffer)

| Setting | v5.1.1 | v5.2.0 |
|---------|--------|--------|
| Manager `SHUTDOWN_DRAIN_DELAY` environment variable | not present | `"15s"` |
| Manager pod `terminationGracePeriodSeconds` | Kubernetes default (30s) | `55` |

**Before (v5.1.1):**

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: 65532
      initContainers:
        - name: wait-for-dependencies
          # ...
      containers:
        - name: manager
          envFrom:
          - configMapRef:
              name: reporter-manager
          env:
          - name: MONGO_PASSWORD
            # ...
```

**After (v5.2.0):**

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: 65532
      # SHUTDOWN_DRAIN_DELAY 15s + the app's 30s shutdown budget + 10s.
      terminationGracePeriodSeconds: 55
      initContainers:
        - name: wait-for-dependencies
          # ...
      containers:
        - name: manager
          envFrom:
          - configMapRef:
              name: reporter-manager
          env:
          - name: SHUTDOWN_DRAIN_DELAY
            value: "15s"
          - name: MONGO_PASSWORD
            # ...
```

**Why this matters:**

When Kubernetes terminates a pod (during upgrades, scaling, or node drains), it sends a SIGTERM signal to the container and simultaneously removes the pod from service endpoints. Without a drain delay, the application may begin shutting down while the service mesh or load balancer is still routing requests to it, causing connection failures.

The `SHUTDOWN_DRAIN_DELAY` instructs the manager to wait 15 seconds after receiving SIGTERM before starting its shutdown sequence. This gives the control plane time to propagate endpoint updates and stop sending new requests. The extended `terminationGracePeriodSeconds` ensures Kubernetes waits long enough for both the drain delay and the application's internal shutdown logic (30 seconds) to complete before forcibly killing the pod.

**Operational impact:**

- During rolling updates, manager pods will take up to 55 seconds to terminate gracefully instead of the default 30 seconds
- In-flight requests will have time to complete before the manager stops accepting new connections
- No configuration changes are required — the new behavior is applied automatically on upgrade

> **Note:** If your manager workload requires a different shutdown budget, you can override the drain delay by setting a custom environment variable in your values file. However, you must also adjust `terminationGracePeriodSeconds` accordingly to ensure Kubernetes waits long enough. The chart does not currently expose `terminationGracePeriodSeconds` as a configurable value, so this would require a post-upgrade patch or a feature request to the chart maintainers.

## Configuration Reference

### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `"15s"` | Time to wait after receiving SIGTERM before starting shutdown sequence (manager only) |

### Pod lifecycle settings

| Setting | Default | Description |
|---------|---------|-------------|
| Manager pod `terminationGracePeriodSeconds` | `55` | Maximum time Kubernetes waits for graceful shutdown before sending SIGKILL |

> **Note:** The `terminationGracePeriodSeconds` value is hardcoded in the template and is not currently exposed as a configurable field in `values.yaml`.

## Migration Steps

This upgrade requires no configuration changes. The graceful shutdown behavior is applied automatically when the manager deployment is rolled.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. Monitor the rolling update of the manager deployment:

```bash
kubectl rollout status deployment/reporter-manager -n <namespace>
```

4. Verify that manager pods terminate gracefully during the rollout by checking termination logs:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --previous --tail=50
```

Look for log entries indicating the drain delay and graceful shutdown sequence.

5. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

6. Test manager endpoint availability during a manual pod deletion to confirm graceful shutdown:

```bash
# In one terminal, watch pod status
kubectl get pods -n <namespace> -l app.kubernetes.io/name=reporter-manager -w

# In another terminal, delete a manager pod
kubectl delete pod -n <namespace> -l app.kubernetes.io/name=reporter-manager --field-selector=status.phase=Running --timeout=60s
```

The pod should take approximately 55 seconds to terminate (or less if shutdown completes earlier).

> **Important:** The upgrade triggers a rolling restart of the manager deployment. Ensure you have multiple manager replicas configured to maintain availability during the rollout. If `manager.replicaCount` is set to 1, expect brief downtime during pod replacement.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.2.0 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.2.0 -n reporter
```
