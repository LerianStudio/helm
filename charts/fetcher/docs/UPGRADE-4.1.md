# Helm Upgrade from v4.0.1 to v4.1.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Health preset ownership](#1-health-preset-ownership)
  - [2. Minimum image version enforcement](#2-minimum-image-version-enforcement)
  - [3. License key required](#3-license-key-required)
  - [4. Job event payloads use snake_case](#4-job-event-payloads-use-snake_case)
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
| `manager` | `readinessProbe`, `livenessProbe`, `startupProbe`, `terminationGracePeriodSeconds`, `deploymentStrategy`, `pdb.enabled`, `pdb.minAvailable`, `pdb.maxUnavailable` |
| `worker` | `readinessProbe`, `livenessProbe`, `startupProbe`, `terminationGracePeriodSeconds`, `deploymentStrategy`, `pdb.enabled`, `pdb.minAvailable`, `pdb.maxUnavailable` |

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
2. Also remove `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY` and `SHUTDOWN_TIMEOUT` from `manager.configmap` and `worker.configmap`; the render refuses them.
3. If you need to tune graceful shutdown timing, use the new `health.drainSeconds` and `health.shutdownSeconds` fields instead (see [New fields](#new-fields)).
4. The preset provides sensible defaults:
   - **Probes:** startup probe (httpGet on `/health`, port `8099`), liveness probe (httpGet on `/health`), readiness probe (httpGet on `/readyz`)
   - **Rollout strategy:** `RollingUpdate` with `maxUnavailable: 0`, `maxSurge: 25%`
   - **PDB:** `maxUnavailable: 1` (rendered for every component unless `health.singleton` is set)
   - **Termination grace period:** calculated from drain + shutdown seconds

The kubelet probes port `8099` on the pod IP. If your cluster restricts node-to-pod traffic, allow port `8099` before you upgrade.

> **Warning:** If you have customized probe paths, timings, or PDB settings, review the preset defaults in the `lerian-common-helm` library documentation. The preset is opinionated and may not match your previous configuration exactly.

### 2. Minimum image version enforcement

The chart now enforces a minimum image version of `4.1.0-beta.1` for both `manager` and `worker`. This is the first application version that serves the health port (`HEALTH_PORT` on `8099`) required by the health preset.

**What happens if you use an older image:**

The chart will fail to render with an error if you try to use an image tag older than `4.1.0-beta.1`.

**What you must do:**

Ensure both `manager.image.tag` and `worker.image.tag` are set to `4.1.0-beta.1` or newer. The default values have been updated to `4.1.0-beta.1`.

### 3. License key required

The `4.1.0-beta.1` manager and worker refuse to boot when `LICENSE_KEY` is empty. The chart default is `secrets.LICENSE_KEY: ""`, and `3.1.1` did not require it. Set `secrets.LICENSE_KEY` (or `LICENSE_KEY` in your existing Secret) before you upgrade.

### 4. Job event payloads use snake_case

The `job.completed` and `job.failed` event payloads now use snake_case field names (for example `jobId` is now `job_id`, `executionTimeMs` is now `execution_time_ms` and `completedAt` is now `completed_at`). The `ce-type` header of these events also changes from `studio.lerian.job.completed` and `studio.lerian.job.failed` to `studio.lerian.fetcher.job.completed` and `studio.lerian.fetcher.job.failed`. Update every consumer of these events to the new field names and `ce-type` values.

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

> **Important:** This is a beta release. Test thoroughly in a non-production environment before upgrading production workloads.

### 2. Health preset integration

The chart now integrates with the `lerian-common.health` preset from the `lerian-common-helm` library. This preset provides standardized health check configuration, graceful shutdown behavior, and high-availability settings.

**Manager health preset (`stack: go`):**

- Serves both the main application port (`manager.service.port`, default `4006`) and a dedicated health port (`8099`)
- Health port is exposed as a ClusterIP-only Service port named `health`
- Probes target `/health` and `/readyz` on the health port
- Includes drain environment variables (`SHUTDOWN_DRAIN_DELAY`, `SHUTDOWN_TIMEOUT`) for graceful shutdown
- Renders a PDB (`maxUnavailable: 1`) unless `health.singleton` is set

**Worker health preset (`stack: go-worker`):**

- Has no main Service (worker is a background processor)
- Health port (`8099`) is the only listener
- Probes target `/health` and `/readyz` on the health port
- Includes drain environment variables for graceful shutdown
- Renders a PDB (`maxUnavailable: 1`) unless `health.singleton` is set

**New environment variables injected by the preset:**

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTH_PORT` | `8099` | Port for health check endpoints (`/health`, `/readyz`) |
| `SHUTDOWN_DRAIN_DELAY` | `15s` (`0s` on the worker) | Time to wait for in-flight requests to complete before shutdown |
| `SHUTDOWN_TIMEOUT` | `30s` | Maximum time for graceful shutdown before forceful termination |

### 3. Default replica count increased to 2

Both `manager` and `worker` now default to `2` replicas (previously `1`). This aligns with the health preset's high-availability defaults.

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

> **Important:** This change doubles the default resource footprint. If you are resource-constrained or running in a development environment, you may want to override `replicaCount: 1` in your values.

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
| `manager.deploymentStrategy` | `type: RollingUpdate, maxSurge: 1, maxUnavailable: 0` | Managed by `manager.health` preset (`RollingUpdate, maxUnavailable: 0`) |
| `manager.pdb.enabled` | `false` | Rendered by the preset (`maxUnavailable: 1`) |
| `manager.pdb.minAvailable` | `1` | Managed by preset (`maxUnavailable: 1`) |
| `manager.pdb.maxUnavailable` | `1` | Managed by preset (`maxUnavailable: 1`) |
| `manager.pdb.annotations` | `{}` | Removed (not supported by preset) |

**Worker:**

| Field | v4.0.1 default | Replacement |
|-------|----------------|-------------|
| `worker.readinessProbe` | (not set in v4.0.1) | Managed by `worker.health` preset |
| `worker.livenessProbe` | (not set in v4.0.1) | Managed by `worker.health` preset |
| `worker.terminationGracePeriodSeconds` | (not set, Kubernetes default `30`) | Calculated from `worker.health.drainSeconds` + `worker.health.shutdownSeconds` |
| `worker.deploymentStrategy` | (not set in v4.0.1, Kubernetes default) | Managed by `worker.health` preset (`RollingUpdate, maxUnavailable: 0`) |
| `worker.pdb.enabled` | (not set in v4.0.1) | Rendered by the preset (`maxUnavailable: 1`) |
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
```

**Worker:**

```yaml
worker:
  # -- Health preset: stack go-worker has no Service; HEALTH_PORT 8099 is its only listener.
  health:
    stack: go-worker
```

| Field | Default | Description |
|-------|---------|-------------|
| `manager.health.stack` | `go` | Health preset stack type (determines probe configuration and Service ports) |
| `manager.health.drainSeconds` | `15` | Time to wait for in-flight requests to complete before shutdown |
| `manager.health.shutdownSeconds` | `30` | Maximum time for graceful shutdown before forceful termination |
| `worker.health.stack` | `go-worker` | Health preset stack type (worker has no main Service, only health port) |
| `worker.health.shutdownSeconds` | `30` | Maximum time for graceful shutdown before forceful termination |

> **Note:** `terminationGracePeriodSeconds` is calculated as `drainSeconds + shutdownSeconds + 10` (the worker drain is always `0`). If you previously customized `terminationGracePeriodSeconds`, adjust `drainSeconds` and `shutdownSeconds` to achieve the desired total.

## Migration Steps

1. **Back up your current values:**

```bash
helm get values fetcher -n fetcher > fetcher-values-4.0.1-backup.yaml
```

2. **Remove preset-owned fields from your custom values:**

Edit your `values.yaml` and remove the following fields if present:

- `manager.readinessProbe`
- `manager.livenessProbe`
- `manager.startupProbe`
- `manager.terminationGracePeriodSeconds`
- `manager.deploymentStrategy`
- `manager.pdb.enabled`
- `manager.pdb.minAvailable`
- `manager.pdb.maxUnavailable`
- `manager.pdb.annotations`
- `worker.readinessProbe`
- `worker.livenessProbe`
- `worker.startupProbe`
- `worker.terminationGracePeriodSeconds`
- `worker.deploymentStrategy`
- `worker.pdb.enabled`
- `worker.pdb.minAvailable`
- `worker.pdb.maxUnavailable`
- `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY` and `SHUTDOWN_TIMEOUT` under `manager.configmap` and `worker.configmap`

3. **(Optional) Tune graceful shutdown timing:**

If you need to adjust shutdown behavior, add the new `health` fields:

```yaml
manager:
  health:
    stack: go
    shutdownSeconds: 30   # Increase if shutdown takes longer

worker:
  health:
    stack: go-worker
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

5. **Set the license key and update event consumers:**

Set `secrets.LICENSE_KEY` (the manager and worker refuse to boot without it) and update every consumer of `job.completed` and `job.failed` events to the snake_case field names and the new `ce-type` values.

6. **Preview the changes:**

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.0 -n fetcher -f your-custom-values.yaml
```

Review the diff carefully, especially:
- New `health` port and Service port on manager
- New environment variables (`HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY`, `SHUTDOWN_TIMEOUT`)
- New probes (startup, liveness, readiness) targeting the health port
- PodDisruptionBudget creation
- Deployment strategy changes

7. **Run the upgrade:**

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.0 -n fetcher -f your-custom-values.yaml
```

8. **Verify the upgrade:**

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

Verify PodDisruptionBudget was created:

```bash
kubectl get pdb -n fetcher
```

9. **Monitor logs for errors:**

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
