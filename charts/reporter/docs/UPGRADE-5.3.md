# Helm Upgrade from v5.2.0 to v5.3.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Health preset replaces manual probe configuration](#1-health-preset-replaces-manual-probe-configuration)
  - [2. Worker service removed](#2-worker-service-removed)
  - [3. PodDisruptionBudget fields now managed by health preset](#3-poddisruptionbudget-fields-now-managed-by-health-preset)
  - [4. Deployment strategy fields now managed by health preset](#4-deployment-strategy-fields-now-managed-by-health-preset)
  - [5. RABBITMQ_HEALTH_CHECK_URL removed from configuration](#5-rabbitmq_health_check_url-removed-from-configuration)
  - [6. HEALTH_PORT removed from worker configuration](#6-health_port-removed-from-worker-configuration)
- **[Features](#features)**
  - [1. Health preset system for standardized pod lifecycle management](#1-health-preset-system-for-standardized-pod-lifecycle-management)
  - [2. Default replica count increased to 2](#2-default-replica-count-increased-to-2)
  - [3. Startup probe added to manager and worker](#3-startup-probe-added-to-manager-and-worker)
  - [4. Manager health port exposed on internal Service](#4-manager-health-port-exposed-on-internal-service)
  - [5. Worker KEDA ScaledJob now sets SHUTDOWN_DRAIN_DELAY to 0s](#5-worker-keda-scaledjob-now-sets-shutdown_drain_delay-to-0s)
  - [6. Application version bump to 4.7.0-beta.1](#6-application-version-bump-to-470-beta1)
  - [7. lerian-common-helm dependency updated to 2.6.0](#7-lerian-common-helm-dependency-updated-to-260)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review health preset configuration](#step-1-review-health-preset-configuration)
  - [Step 2: Migrate custom probe settings](#step-2-migrate-custom-probe-settings)
  - [Step 3: Remove deprecated configuration](#step-3-remove-deprecated-configuration)
  - [Step 4: Adjust replica count if needed](#step-4-adjust-replica-count-if-needed)
  - [Step 5: Execute the upgrade](#step-5-execute-the-upgrade)
  - [Step 6: Verify deployment health](#step-6-verify-deployment-health)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that introduces a health preset system for standardized pod lifecycle management, increases default replica counts for high availability, and updates the application to version `4.7.0-beta.1`. The health preset consolidates probe configuration, graceful shutdown settings, deployment strategy, and PodDisruptionBudget rules into a single, stack-aware configuration block.

| Field | v5.2.0 | v5.3.0 |
|-------|--------|--------|
| Chart version | `5.2.0` | `5.3.0` |
| App version | `4.6.0` | `4.7.0-beta.1` |
| Manager image tag | `4.6.0` | `4.7.0-beta.1` |
| Worker image tag | `4.6.0` | `4.7.0-beta.1` |
| lerian-common-helm dependency | `2.4.0` | `2.6.0` |

> **Important:** This release changes how probes, graceful shutdown, deployment strategy, and PodDisruptionBudget are configured. Remove `livenessProbe` and `readinessProbe` from `manager` and `worker` in your values file: the health preset refuses to render when they are set.

## Breaking Changes

### 1. Health preset replaces manual probe configuration

The `manager.readinessProbe`, `manager.livenessProbe`, `worker.readinessProbe`, and `worker.livenessProbe` configuration blocks have been replaced by a health preset system. All probe timing fields (`initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `successThreshold`, `failureThreshold`) are now managed by the preset and cannot be overridden individually.

| Setting | v5.2.0 | v5.3.0 |
|---------|--------|--------|
| `manager.readinessProbe` | Full configuration block | Removed (managed by `manager.health` preset) |
| `manager.livenessProbe` | Full configuration block | Removed (managed by `manager.health` preset) |
| `worker.readinessProbe` | Full configuration block | Removed (managed by `worker.health` preset) |
| `worker.livenessProbe` | Full configuration block | Removed (managed by `worker.health` preset) |
| `manager.health` | Not present | `{ stack: "go" }` |
| `worker.health` | Not present | `{ stack: "go-worker" }` |

**Before (v5.2.0):**

```yaml
manager:
  readinessProbe:
    initialDelaySeconds: 25
    periodSeconds: 5
    timeoutSeconds: 3
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    initialDelaySeconds: 30
    periodSeconds: 5
    timeoutSeconds: 3
    successThreshold: 1
    failureThreshold: 3
```

**After (v5.3.0):**

```yaml
manager:
  health:
    stack: go
```

The health preset now generates startup, liveness, and readiness probes automatically based on the `stack` type. The `go` stack preset includes:

- Startup probe: 5s period, 3s timeout, 60 failures
- Liveness probe: 10s period, 3s timeout, 3 failures
- Readiness probe: 5s period, 3s timeout, 3 failures

> **Warning:** The manager no longer serves `/readyz` on `manager.service.port` (`4005`). Readiness is on the health port `8099`. Move any external readiness check to port `8099`.
>
> **Warning:** Custom probe paths (e.g., `manager.readinessProbe.path`) are no longer supported. The health preset uses fixed paths: `/health` for liveness and `/readyz` for readiness. If your application uses different paths, you must update the application code or contact the chart maintainers.

### 2. Worker service removed

The worker Service resource has been removed. The worker component does not expose HTTP endpoints for external traffic and only serves health probes on an internal port.

| Resource | v5.2.0 | v5.3.0 |
|----------|--------|--------|
| `worker/service.yaml` | Present | Removed |
| `worker.service.type` | `ClusterIP` | Removed |
| `worker.service.port` | `80` | Removed |
| `worker.service.annotations` | `{}` | Removed |

**Before (v5.2.0):**

```yaml
worker:
  service:
    type: ClusterIP
    port: 80
    annotations: {}
```

**After (v5.3.0):**

```yaml
# worker.service removed — no configuration needed
```

> **Note:** If you have external monitoring or service mesh configuration that references the worker Service, remove those references before upgrading.

### 3. PodDisruptionBudget fields now managed by health preset

The `manager.pdb.maxUnavailable` and `manager.pdb.minAvailable` fields are now managed by the health preset and cannot be overridden individually.

| Setting | v5.2.0 | v5.3.0 |
|---------|--------|--------|
| `manager.pdb.maxUnavailable` | `1` | Removed (managed by `manager.health` preset) |
| `manager.pdb.minAvailable` | `0` | Removed (managed by `manager.health` preset) |

**Before (v5.2.0):**

```yaml
manager:
  pdb:
    enabled: true
    maxUnavailable: 1
    minAvailable: 0
```

**After (v5.3.0):**

```yaml
manager:
  pdb:
    enabled: true
```

The health preset now generates PDB rules automatically:

The preset renders `maxUnavailable: 1` and `unhealthyPodEvictionPolicy: AlwaysAllow`. The PDB is rendered when `manager.pdb.enabled` is true and `manager.health.singleton` is not set.

### 4. Deployment strategy fields now managed by health preset

The `manager.deploymentStrategy` and `worker.deploymentStrategy` fields are now managed by the health preset and cannot be overridden individually.

| Setting | v5.2.0 | v5.3.0 |
|---------|--------|--------|
| `manager.deploymentStrategy` | Full configuration block | Removed (managed by `manager.health` preset) |
| `worker.deploymentStrategy` | Full configuration block | Removed (managed by `worker.health` preset) |

**Before (v5.2.0):**

```yaml
manager:
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

**After (v5.3.0):**

```yaml
# manager.deploymentStrategy removed — managed by health preset
```

The health preset now generates deployment strategy automatically:

- `type: RollingUpdate`
- `maxSurge: 25%`
- `maxUnavailable: 0`

> **Note:** The deployment strategy is now consistent across all components using the health preset.

### 5. RABBITMQ_HEALTH_CHECK_URL removed from configuration

The `RABBITMQ_HEALTH_CHECK_URL` environment variable has been removed from the manager and worker ConfigMaps. The application no longer performs RabbitMQ health checks via the management API.

| Setting | v5.2.0 | v5.3.0 |
|---------|--------|--------|
| `common.configmap.RABBITMQ_HEALTH_CHECK_URL` | Generated from broker host and port | Removed |

**Before (v5.2.0):**

```yaml
# Rendered in ConfigMap
RABBITMQ_HEALTH_CHECK_URL: "http://reporter-rabbitmq.reporter.svc.cluster.local:15672"
```

**After (v5.3.0):**

```yaml
# RABBITMQ_HEALTH_CHECK_URL removed from ConfigMap
```

> **Note:** Remove `RABBITMQ_HEALTH_CHECK_URL` and `HEALTH_PORT` from `common.configmap`, `manager.configmap` and `worker.configmap` in your values file: the 5.3.0 values schema rejects both keys and the upgrade fails.

### 6. HEALTH_PORT removed from worker configuration

The `worker.configmap.HEALTH_PORT` environment variable has been removed. The worker health port is now managed by the health preset and injected automatically.

| Setting | v5.2.0 | v5.3.0 |
|---------|--------|--------|
| `worker.configmap.HEALTH_PORT` | `"4006"` | Removed (managed by `worker.health` preset) |

**Before (v5.2.0):**

```yaml
worker:
  configmap:
    HEALTH_PORT: "4006"
```

**After (v5.3.0):**

```yaml
# worker.configmap.HEALTH_PORT removed — managed by health preset
```

The health preset now injects the `HEALTH_PORT` environment variable automatically based on the stack type.

## Features

### 1. Health preset system for standardized pod lifecycle management

The chart now uses a health preset system (provided by `lerian-common-helm` v2.6.0) that consolidates probe configuration, graceful shutdown settings, deployment strategy, and PodDisruptionBudget rules into a single, stack-aware configuration block.

**New fields added:**

| Component | Field | Default | Description |
|-----------|-------|---------|-------------|
| `manager` | `health.stack` | `"go"` | Health preset stack type (controls probes, ports, env, grace, strategy, PDB) |
| `worker` | `health.stack` | `"go-worker"` | Health preset stack type for worker component |

**Manager health preset configuration:**

```yaml
manager:
  health:
    stack: go
```

**Worker health preset configuration:**

```yaml
worker:
  health:
    stack: go-worker
```

The health preset generates the following resources automatically:

- **Probes**: Startup, liveness, and readiness probes with stack-appropriate timing
- **Ports**: Health port container port definition
- **Environment variables**: `HEALTH_PORT` and `SHUTDOWN_DRAIN_DELAY`
- **Grace period**: `terminationGracePeriodSeconds` calculated as `drainSeconds + shutdownSeconds + 10`
- **Deployment strategy**: `RollingUpdate` with `maxSurge: 25%` and `maxUnavailable: 0`
- **PodDisruptionBudget**: `maxUnavailable: 1` unless the component is a singleton

**Rendered probe configuration (manager):**

```yaml
startupProbe:
  httpGet:
    path: /health
    port: health
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 60
livenessProbe:
  httpGet:
    path: /health
    port: health
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /readyz
    port: health
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**Rendered environment variables:**

```yaml
env:
  - name: HEALTH_PORT
    value: "8099"
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
  - name: SHUTDOWN_TIMEOUT
    value: "30s"
```

**Rendered grace period:**

```yaml
terminationGracePeriodSeconds: 55  # 15s drain + 30s shutdown + 10s buffer
```

> **Note:** The chart refuses to render when `manager.image.tag` (or `worker.image.tag` when the worker runs as a Deployment) is below `4.7.0-beta.1`, the first image that serves the health port. Remove an older pin or set it to `4.7.0-beta.1` or later.

### 2. Default replica count increased to 2

The default replica count for the manager has been increased from `1` to `2` to improve high availability. This change affects the static `replicaCount` field as well as the `minReplicas` settings for HPA and KEDA autoscaling.

| Setting | v5.2.0 | v5.3.0 |
|---------|--------|--------|
| `manager.replicaCount` | `1` | `2` |
| `manager.autoscaling.minReplicas` | `1` | `2` |
| `manager.keda.scaledObject.minReplicaCount` | `1` | `2` |

**Before (v5.2.0):**

```yaml
manager:
  replicaCount: 1
  autoscaling:
    minReplicas: 1
  keda:
    scaledObject:
      minReplicaCount: 1
```

**After (v5.3.0):**

```yaml
manager:
  replicaCount: 2
  autoscaling:
    minReplicas: 2
  keda:
    scaledObject:
      minReplicaCount: 2
```

> **Important:** If you are running in a resource-constrained environment, override these values to `1` in your `values.yaml`.

### 3. Startup probe added to manager and worker

Both manager and worker deployments now include a startup probe that allows up to 300 seconds for the application to start before the liveness probe begins checking. This prevents premature pod restarts during slow startup scenarios.

**Rendered startup probe:**

```yaml
startupProbe:
  httpGet:
    path: /health
    port: health
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 60
```

Once the startup probe succeeds, the liveness and readiness probes take over.

> **Note:** The startup probe uses the same `/health` path as the liveness probe but with more lenient timing to accommodate application initialization.

### 4. Manager health port exposed on internal Service

The manager Service now exposes the health port (`8099`) as an additional port named `health`.

**Rendered Service ports:**

```yaml
ports:
  - port: 4005
    targetPort: http
    protocol: TCP
    name: http
  - port: 8099
    targetPort: 8099
    protocol: TCP
    name: health
```

> **Note:** The health port is only exposed when `manager.service.type` is `ClusterIP`. LoadBalancer and NodePort services do not expose the health port.

### 5. Worker KEDA ScaledJob now sets SHUTDOWN_DRAIN_DELAY to 0s

When the worker is deployed as a KEDA ScaledJob, the `SHUTDOWN_DRAIN_DELAY` environment variable is now explicitly set to `0s`. Job pods do not receive traffic from a Service and do not need a drain period.

**Rendered environment variable (ScaledJob only):**

```yaml
env:
  - name: SHUTDOWN_DRAIN_DELAY
    value: 0s
```

### 6. Application version bump to 4.7.0-beta.1

The manager and worker image tags have been updated from `4.6.0` to `4.7.0-beta.1`, and the chart `appVersion` field reflects this change.

| Component | v5.2.0 | v5.3.0 |
|-----------|--------|--------|
| `manager.image.tag` | `"4.6.0"` | `"4.7.0-beta.1"` |
| `worker.image.tag` | `"4.6.0"` | `"4.7.0-beta.1"` |
| Chart `appVersion` | `"4.6.0"` | `"4.7.0-beta.1"` |

### 7. lerian-common-helm dependency updated to 2.6.0

The `lerian-common-helm` dependency has been updated from `2.4.0` to `2.6.0`. This update provides the health preset system and other shared template improvements.

| Dependency | v5.2.0 | v5.3.0 |
|------------|--------|--------|
| `lerian-common-helm` | `2.4.0` | `2.6.0` |

> **Note:** The `lerian-common-helm` update is required for the health preset system to function. Do not downgrade this dependency.

## Configuration Reference

### Health preset fields

| Field | Default | Description |
|-------|---------|-------------|
| `manager.health.stack` | `"go"` | Health preset stack type for manager (controls probes, ports, env, grace, strategy, PDB) |
| `worker.health.stack` | `"go-worker"` | Health preset stack type for worker (controls probes, ports, env, grace, strategy) |
| `manager.health.drainSeconds` | `15` | Drain delay (`SHUTDOWN_DRAIN_DELAY`). The `go-worker` stack always uses `0` |
| `manager.health.shutdownSeconds` | `30` | Shutdown budget (`SHUTDOWN_TIMEOUT`); the grace period is drain + shutdown + 10 |

`worker.health` takes the same two keys. Besides `stack`, the preset accepts only `drainSeconds`, `shutdownSeconds` and `singleton` under `health`.

### Replica count fields

| Field | Default | Description |
|-------|---------|-------------|
| `manager.replicaCount` | `2` | Static replica count for manager (used when autoscaling is disabled) |
| `manager.autoscaling.minReplicas` | `2` | Minimum replicas for HPA autoscaling |
| `manager.keda.scaledObject.minReplicaCount` | `2` | Minimum replicas for KEDA autoscaling |

### Removed fields

| Field | v5.2.0 | v5.3.0 |
|-------|--------|--------|
| `manager.readinessProbe` | Full configuration block | Removed (managed by `manager.health` preset) |
| `manager.livenessProbe` | Full configuration block | Removed (managed by `manager.health` preset) |
| `manager.deploymentStrategy` | Full configuration block | Removed (managed by `manager.health` preset) |
| `manager.pdb.maxUnavailable` | `1` | Removed (managed by `manager.health` preset) |
| `manager.pdb.minAvailable` | `0` | Removed (managed by `manager.health` preset) |
| `worker.readinessProbe` | Full configuration block | Removed (managed by `worker.health` preset) |
| `worker.livenessProbe` | Full configuration block | Removed (managed by `worker.health` preset) |
| `worker.deploymentStrategy` | Full configuration block | Removed (managed by `worker.health` preset) |
| `worker.service` | Full configuration block | Removed (worker does not expose external Service) |
| `worker.configmap.HEALTH_PORT` | `"4006"` | Removed (managed by `worker.health` preset) |
| `common.configmap.RABBITMQ_HEALTH_CHECK_URL` | Generated from broker host and port | Removed |

## Migration Steps

### Step 1: Review health preset configuration

The health preset is enabled by default with `stack: go` for the manager and `stack: go-worker` for the worker. No action is required unless you need to customize the preset behavior.

**Default configuration (v5.3.0):**

```yaml
manager:
  health:
    stack: go

worker:
  health:
    stack: go-worker
```

> **Note:** The chart refuses to render when `manager.image.tag` (or `worker.image.tag` when the worker runs as a Deployment) is below `4.7.0-beta.1`, the first image that serves the health port. Remove an older pin or set it to `4.7.0-beta.1` or later.

### Step 2: Migrate custom probe settings

If you have customized probe settings in your `values.yaml`, you must remove them. The health preset does not support individual probe field overrides.

**Before (v5.2.0):**

```yaml
manager:
  readinessProbe:
    initialDelaySeconds: 30
    periodSeconds: 10
  livenessProbe:
    initialDelaySeconds: 40
    periodSeconds: 10
```

**After (v5.3.0):**

```yaml
# Remove custom probe settings — managed by health preset
```

> **Warning:** If your application requires custom probe timing, you must either accept the preset defaults or contact the chart maintainers to request configurable probe overrides in the health preset.

### Step 3: Remove deprecated configuration

Remove the following deprecated fields from your `values.yaml`:

- `manager.readinessProbe`
- `manager.livenessProbe`
- `manager.deploymentStrategy`
- `manager.pdb.maxUnavailable`
- `manager.pdb.minAvailable`
- `worker.readinessProbe`
- `worker.livenessProbe`
- `worker.deploymentStrategy`
- `worker.service`
- `worker.configmap.HEALTH_PORT`
- `common.configmap.RABBITMQ_HEALTH_CHECK_URL`

**Before (v5.2.0):**

```yaml
manager:
  readinessProbe:
    initialDelaySeconds: 25
  livenessProbe:
    initialDelaySeconds: 30
  deploymentStrategy:
    type: RollingUpdate
  pdb:
    maxUnavailable: 1

worker:
  readinessProbe:
    initialDelaySeconds: 15
  livenessProbe:
    initialDelaySeconds: 20
  deploymentStrategy:
    type: RollingUpdate
  service:
    type: ClusterIP
    port: 80
  configmap:
    HEALTH_PORT: "4006"
```

**After (v5.3.0):**

```yaml
# Remove all deprecated fields
```

### Step 4: Adjust replica count if needed

The default replica count has been increased to `2` for the manager. If you are running in a resource-constrained environment, override these values to `1` in your `values.yaml`:

```yaml
manager:
  replicaCount: 1
  autoscaling:
    minReplicas: 1
  keda:
    scaledObject:
      minReplicaCount: 1
```

### Step 5: Execute the upgrade

Run the upgrade command with your updated values file:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm \
  --version 5.3.0 \
  -n reporter \
  -f values.yaml
```

> **Warning:** The upgrade will trigger a rolling restart of the manager Deployment (and of the worker Deployment when KEDA is disabled). The new replica count will take effect immediately.

> **Warning:** Do not use `--reuse-values`. It keeps the 5.2.0 chart defaults, including `worker.configmap.HEALTH_PORT`, and the 5.3.0 render fails. Pass the migrated file with `-f`, or use `--reset-then-reuse-values`.

### Step 6: Verify deployment health

Check that all pods are running and healthy:

```bash
kubectl get pods -n reporter
```

Verify manager and worker logs:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
# Default KEDA ScaledJob: Job pods carry only the scaledjob.keda.sh/name label.
# With KEDA disabled, use -l app.kubernetes.io/name=reporter-worker instead.
kubectl logs -n reporter -l scaledjob.keda.sh/name=reporter-worker --tail=50
```

Verify probe behavior (the worker has probes only when it runs as a Deployment, with KEDA disabled):

```bash
kubectl describe pod -n reporter -l app.kubernetes.io/name=reporter-manager | grep -A5 -E "Liveness|Readiness|Startup"
kubectl describe pod -n reporter -l app.kubernetes.io/name=reporter-worker | grep -A5 -E "Liveness|Readiness|Startup"
```

Verify PodDisruptionBudget:

```bash
kubectl get pdb -n reporter
kubectl describe pdb -n reporter reporter-manager
```

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.3.0 -n reporter -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

Pass the migrated values file. Without `-f`, Helm reuses the release's stored values, and leftover probe keys, `HEALTH_PORT` or an image pin below `4.7.0-beta.1` make the render fail.

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.3.0 -n reporter -f values.yaml
```
