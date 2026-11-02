# Helm Upgrade from v4.0.1 to v4.1.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Health preset ownership](#1-health-preset-ownership)
  - [2. Minimum image version enforcement](#2-minimum-image-version-enforcement)
- **[Features](#features)**
  - [1. Application version bump to 4.1.0-beta.1](#1-application-version-bump-to-410-beta1)
  - [2. Health preset integration](#2-health-preset-integration)
  - [3. Default replica count increased to 2](#3-default-replica-count-increased-to-2)
  - [4. lerian-common-helm dependency upgrade](#4-lerian-common-helm-dependency-upgrade)
- **[Configuration Changes](#configuration-changes)**
  - [Removed fields](#removed-fields)
  - [New fields](#new-fields)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `4.0.1` to `4.1.0`. This is a **minor** release that introduces a health preset system from the `lerian-common-helm` library, updates the application version to `4.1.0-beta.1`, and enforces minimum image version requirements.

The upgrade includes **breaking changes**: several `values.yaml` fields related to probes, PDB, deployment strategy, and grace periods are now owned by the health preset and must be removed from your custom values. The chart will fail to render if these fields are present.

## Breaking Changes

### 1. Health preset ownership

The chart now uses a health preset from `lerian-common-helm` (version `2.6.0`) that centrally manages probes, drain environment variables, termination grace periods, rollout strategy, and PodDisruptionBudget configuration. **You must remove** the following fields from your `values.yaml` if you have customized them:

| Component | Removed fields |
|-----------|----------------|
| `manager` | `readinessProbe`, `livenessProbe`, `terminationGracePeriodSeconds`, `deploymentStrategy`, `pdb.enabled`, `pdb.minAvailable`, `pdb.maxUnavailable` |
| `worker` | `readinessProbe`, `livenessProbe`, `terminationGracePeriodSeconds`, `deploymentStrategy`, `pdb.enabled`, `pdb.minAvailable`, `pdb.maxUnavailable` |

**Why this is breaking:**

The chart now validates that these fields are not present in your values. If any of these keys exist, the render will fail with an error message like:

```
fetcher: manager.pdb.enabled is owned by the health preset (PDB maxUnavailable 1); remove it
```

or

```
fetcher: manager.terminationGracePeriodSeconds is owned by the health preset (tune health.shutdownSeconds); remove it
```

**What you must do:**

1. Remove all the fields listed above from your custom `values.yaml`.
2. If you need to tune graceful shutdown timing, use the new `health.drainSeconds` and `health.shutdownSeconds` fields instead (see [New fields](#new-fields)).
3. The preset provides sensible defaults:
   - **Probes:** startup probe (httpGet on `/health`, port `8099`), liveness probe (httpGet on `/health`), readiness probe (httpGet on `/readyz`)
   - **Rollout strategy:** `RollingUpdate` with `maxUnavailable: 0`, `maxSurge: 1`
   - **PDB:** `maxUnavailable: 1` (enabled automatically when `replicaCount >= 2`)
   - **Termination grace period:** calculated from drain + shutdown seconds

> **Warning:** If you have customized probe paths, timings, or PDB settings, review the preset defaults in the `lerian-common-helm` library documentation. The preset is opinionated and may not match your previous configuration exactly.

### 2. Minimum image version enforcement

The chart now enforces a minimum image version of `4.1.0-beta.1` for both `manager` and `worker`. This is the first application version that serves the health port (`HEALTH_PORT` on `8099`) required by the health preset.

**What happens if you use an older image:**

The chart will fail to render with an error if you try to use an image tag older than `4.1.0-beta.1`.

**What you must do:**

Ensure both `manager.image.tag` and `worker.image.tag` are set to `4.1.0-beta.1` or newer. The default values have been updated to `4.1.0-beta.1`.

## Features

### 1. Application version bump to 4.1.0-beta.1

Both `manager` and `worker` components have been updated to application version `4.1.0-beta.1` (from `3.1.1`). This is the first beta release of the `4.1.0` series and introduces the health port listener required by the new health preset.

| Component | v4.0.1 | v4.1.0 |
|-----------|--------|--------|
| `appVersion` | `3.1.1` | `4.1.0-beta.1` |
| `manager.image.tag` | `"3.1.1"` | `"4.1.0-beta.1"` |
| `worker.image.tag` | `"3.1.1"` | `"4.1.0-beta.1"` |

**Before (v4.0.1):**

```yaml
manager:
  image:
    repository: lerianstudio/fetcher-manager
    pullPolicy: IfNotPresent
    tag: "3.1.1"

worker:
  image:
    repository: lerianstudio/fetcher-worker
    pullPolicy: IfNotPresent
    tag: "3.1.1"
```

**After (v4.1.0):**

```yaml
manager:
  image:
    repository: lerianstudio/fetcher-manager
    pullPolicy: IfNotPresent
    # -- Moves with `fetcher.minImage` (templates/_helpers.tpl) and Chart.yaml appVersion.
    tag: "4.1.0-beta.1"

worker:
  image:
    repository: lerianstudio/fetcher-worker
    pullPolicy: IfNotPresent
    # -- Moves with `fetcher.minImage` (templates/_helpers.tpl) and Chart.yaml appVersion.
    tag: "4.1.0-beta.1"
```

> **Important:** This is a beta release. Test thoroughly in a non-production environment before upgrading production workloads. Consult the upstream `fetcher` application release notes for details on changes between `3.1.1` and `4.1.0-beta.1`.

### 2. Health preset integration

The chart now integrates with the `lerian-common.health` preset from the `lerian-common-helm` library. This preset provides standardized health check configuration, graceful shutdown behavior, and high-availability settings.

**Manager health preset (`stack: go`):**

- Serves both the main application port (default `8080`) and a dedicated health port (`8099`)
- Health port is exposed as a ClusterIP-only Service port named `health`
- Probes target `/health` and `/readyz` on the health port
- Includes drain environment variables (`DRAIN_SECONDS`, `SHUTDOWN_SECONDS`) for graceful shutdown
- Automatically enables PDB when `replicaCount >= 2`

**Worker health preset (`stack: go-worker`):**

- Has no main Service (worker is a background processor)
- Health port (`8099`) is the only listener
- Probes target `/health` on the health port
- Includes drain environment variables for graceful shutdown
- Automatically enables PDB when `replicaCount >= 2`

**New environment variables injected by the preset:**

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTH_PORT` | `8099` | Port for health check endpoints (`/health`, `/readyz`) |
| `DRAIN_SECONDS` | `5` | Time to wait for in-flight requests to complete before shutdown |
| `SHUTDOWN_SECONDS` | `25` | Maximum time for graceful shutdown before forceful termination |

**Before (v4.0.1) — manager Deployment:**

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**After (v4.1.0) — manager Deployment:**

```yaml
env:
  - name: HEALTH_PORT
    value: "8099"
  - name: DRAIN_SECONDS
    value: "5"
  - name: SHUTDOWN_SECONDS
    value: "25"
ports:
  - name: http
    containerPort: 8080
    protocol: TCP
  - name: health
    containerPort: 8099
    protocol: TCP
startupProbe:
  httpGet:
    path: /health
    port: health
  initialDelaySeconds: 0
  periodSeconds: 2
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 15
livenessProbe:
  httpGet:
    path: /health
    port: health
  initialDelaySeconds: 0
  periodSeconds: 10
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /readyz
    port: health
  initialDelaySeconds: 0
  periodSeconds: 5
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 2
```

> **Note:** The worker Deployment receives similar changes, but with only the `health` port (no `http` port) since it does not serve external traffic.

### 3. Default replica count increased to 2

Both `manager` and `worker` now default to `2` replicas (previously `1`). This aligns with the health preset's high-availability defaults and automatically enables PodDisruptionBudget protection.

| Component | v4.0.1 | v4.1.0 |
|-----------|--------|--------|
| `manager.replicaCount` | `1` | `2` |
| `worker.replicaCount` | `1` | `2` |
| `manager.autoscaling.minReplicas` | `1` | `2` |

**Before (v4.0.1):**

```yaml
manager:
  replicaCount: 1
  autoscaling:
    enabled: false
    minReplicas: 1
    maxReplicas: 3

worker:
  replicaCount: 1
```

**After (v4.1.0):**

```yaml
manager:
  replicaCount: 2
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 3

worker:
  replicaCount: 2
```

> **Important:** This change doubles the default resource footprint. If you are resource-constrained or running in a development environment, you may want to override `replicaCount: 1` in your values. However, note that PDB will not be enabled with a single replica.

### 4. lerian-common-helm dependency upgrade

The `lerian-common-helm` dependency has been upgraded from `2.4.0` to `2.6.0`. This brings the health preset functionality and other library improvements.

| Dependency | v4.0.1 | v4.1.0 |
|------------|--------|--------|
| `lerian-common-helm` | `2.4.0` | `2.6.0` |

## Configuration Changes

### Removed fields

The following fields have been **removed** from `values.yaml` and are now managed by the health preset. If you have customized these fields, you must remove them from your custom values.

**Manager:**

| Field | v4.0.1 default | Replacement |
|-------|----------------|-------------|
| `manager.readinessProbe` | `initialDelaySeconds: 10, periodSeconds: 5, ...` | Managed by `manager.health` preset |
| `manager.livenessProbe` | `initialDelaySeconds: 15, periodSeconds: 10, ...` | Managed by `manager.health` preset |
| `manager.terminationGracePeriodSeconds` | (not set, Kubernetes default `30`) | Calculated from `manager.health.drainSeconds` + `manager.health.shutdownSeconds` |
| `manager.deploymentStrategy` | `type: RollingUpdate, maxSurge: 1, maxUnavailable: 0` | Managed by `manager.health` preset (always `RollingUpdate, maxUnavailable: 0`) |
| `manager.pdb.enabled` | `false` | Automatically enabled when `replicaCount >= 2` |
| `manager.pdb.minAvailable` | `1` | Managed by preset (`maxUnavailable: 1`) |
| `manager.pdb.maxUnavailable` | `1` | Managed by preset (`maxUnavailable: 1`) |
| `manager.pdb.annotations` | `{}` | Removed (not supported by preset) |

**Worker:**

| Field | v4.0.1 default | Replacement |
|-------|----------------|-------------|
| `worker.readinessProbe` | (not set in v4.0.1) | Managed by `worker.health` preset |
| `worker.livenessProbe` | (not set in v4.0.1) | Managed by `worker.health` preset |
| `worker.terminationGracePeriodSeconds` | (not set, Kubernetes default `30`) | Calculated from `worker.health.drainSeconds` + `worker.health.shutdownSeconds` |
| `worker.deploymentStrategy` | (not set in v4.0.1, Kubernetes default) | Managed by `worker.health` preset (always `RollingUpdate, maxUnavailable: 0`) |
| `worker.pdb.enabled` | (not set in v4.0.1) | Automatically enabled when `replicaCount >= 2` |
| `worker.pdb.minAvailable` | (not set in v4.0.1) | Managed by preset (`maxUnavailable: 1`) |
| `worker.pdb.maxUnavailable` | (not set in v4.0.1) | Managed by preset (`maxUnavailable: 1`) |

### New fields

**Manager:**

```yaml
manager:
  # -- Health preset (lerian-common.health): probes, drain, grace, rollout and PDB are
  # owned by the preset; tune only drainSeconds / shutdownSeconds. Stack go serves
  # /health and /readyz on HEALTH_PORT 8099 (ClusterIP-only Service port).
  health:
    stack: go
    # drainSeconds: 5        # Optional: time to drain in-flight requests
    # shutdownSeconds: 25    # Optional: max graceful shutdown time
```

**Worker:**

```yaml
worker:
  # -- Health preset: stack go-worker has no Service; HEALTH_PORT 8099 is its only listener.
  health:
    stack: go-worker
    # drainSeconds: 5        # Optional: time to drain in-flight requests
    # shutdownSeconds: 25    # Optional: max graceful shutdown time
```

| Field | Default | Description |
|-------|---------|-------------|
| `manager.health.stack` | `go` | Health preset stack type (determines probe configuration and Service ports) |
| `manager.health.drainSeconds` | `5` | Time to wait for in-flight requests to complete before shutdown |
| `manager.health.shutdownSeconds` | `25` | Maximum time for graceful shutdown before forceful termination |
| `worker.health.stack` | `go-worker` | Health preset stack type (worker has no main Service, only health port) |
| `worker.health.drainSeconds` | `5` | Time to wait for in-flight requests to complete before shutdown |
| `worker.health.shutdownSeconds` | `25` | Maximum time for graceful shutdown before forceful termination |

> **Note:** `terminationGracePeriodSeconds` is calculated as `drainSeconds + shutdownSeconds + 5` (5-second buffer). If you previously customized `terminationGracePeriodSeconds`, adjust `drainSeconds` and `shutdownSeconds` to achieve the desired total.

## Migration Steps

1. **Back up your current values:**

```bash
helm get values fetcher -n fetcher > fetcher-values-4.0.1-backup.yaml
```

2. **Remove preset-owned fields from your custom values:**

Edit your `values.yaml` and remove the following fields if present:

- `manager.readinessProbe`
- `manager.livenessProbe`
- `manager.terminationGracePeriodSeconds`
- `manager.deploymentStrategy`
- `manager.pdb.enabled`
- `manager.pdb.minAvailable`
- `manager.pdb.maxUnavailable`
- `manager.pdb.annotations`
- `worker.readinessProbe`
- `worker.livenessProbe`
- `worker.terminationGracePeriodSeconds`
- `worker.deploymentStrategy`
- `worker.pdb.enabled`
- `worker.pdb.minAvailable`
- `worker.pdb.maxUnavailable`

3. **(Optional) Tune graceful shutdown timing:**

If you need to adjust shutdown behavior, add the new `health` fields:

```yaml
manager:
  health:
    stack: go
    drainSeconds: 10      # Increase if you have long-running requests
    shutdownSeconds: 30   # Increase if shutdown takes longer

worker:
  health:
    stack: go-worker
    drainSeconds: 10
    shutdownSeconds: 30
```

4. **(Optional) Override replica count:**

If you want to keep a single replica (not recommended for production):

```yaml
manager:
  replicaCount: 1
  autoscaling:
    minReplicas: 1

worker:
  replicaCount: 1
```

> **Warning:** With `replicaCount: 1`, PDB will not be enabled and you will have no protection against voluntary disruptions.

5. **Preview the changes:**

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.0 -n fetcher -f your-custom-values.yaml
```

Review the diff carefully, especially:
- New `health` port and Service port on manager
- New environment variables (`HEALTH_PORT`, `DRAIN_SECONDS`, `SHUTDOWN_SECONDS`)
- New probes (startup, liveness, readiness) targeting the health port
- PodDisruptionBudget creation (if `replicaCount >= 2`)
- Deployment strategy changes

6. **Run the upgrade:**

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.0 -n fetcher -f your-custom-values.yaml
```

7. **Verify the upgrade:**

Check that both manager and worker pods are running the new version and are Ready:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager
kubectl get pods -n fetcher -l app.kubernetes.io/component=worker
```

Verify the new image version:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager -o jsonpath='{.items[*].spec.containers[0].image}'
kubectl get pods -n fetcher -l app.kubernetes.io/component=worker -o jsonpath='{.items[*].spec.containers[0].image}'
```

Check that the health port is listening:

```bash
kubectl port-forward -n fetcher svc/fetcher-manager 8099:8099
curl http://localhost:8099/health
curl http://localhost:8099/readyz
```

Verify PodDisruptionBudget was created (if `replicaCount >= 2`):

```bash
kubectl get pdb -n fetcher
```

8. **Monitor logs for errors:**

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50
```

Look for any errors related to health checks, graceful shutdown, or application startup.

> **Important:** This is a beta release (`4.1.0-beta.1`). Monitor your application closely after the upgrade and be prepared to roll back if you encounter issues.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.0 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.0 -n fetcher
```
