# Helm Upgrade from v5.2.3 to v5.3.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Health preset system replaces manual probe configuration](#1-health-preset-system-replaces-manual-probe-configuration)
  - [2. Worker components no longer expose Service or Ingress](#2-worker-components-no-longer-expose-service-or-ingress)
  - [3. PDB and deployment strategy now owned by health preset](#3-pdb-and-deployment-strategy-now-owned-by-health-preset)
  - [4. Default replica count increased for pix component](#4-default-replica-count-increased-for-pix-component)
- **[New Features](#new-features)**
  - [1. lerian-common-helm dependency](#1-lerian-common-helm-dependency)
  - [2. Startup probes added to all components](#2-startup-probes-added-to-all-components)
  - [3. Health port and environment variables](#3-health-port-and-environment-variables)
  - [4. Termination grace period](#4-termination-grace-period)
- **[Configuration Reference](#configuration-reference)**
  - [Health preset options](#health-preset-options)
  - [Removed configuration fields](#removed-configuration-fields)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that introduces a **health preset system** powered by the new `lerian-common-helm` dependency. The chart now derives probes, ports, grace periods, deployment strategies, and PodDisruptionBudgets from a single `health.stack` value per component, replacing the previous manual configuration approach.

The application version upgrades from `1.12.0` to `1.14.0-beta.6`, which serves `/health` and `/readyz` on a dedicated health port. This release includes **breaking changes** that require values migration before upgrading.

| Setting | v5.2.3 | v5.3.0 |
|---------|--------|--------|
| Chart version | `5.2.3` | `5.3.0` |
| App version | `1.12.0` | `1.14.0-beta.6` |
| Chart dependencies | `postgresql`, `valkey`, `mongodb` | adds `lerian-common-helm` 2.6.0 |
| Default `pix.replicaCount` | `1` | `2` |

## Breaking Changes

### 1. Health preset system replaces manual probe configuration

All components (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) now use a `health.stack` preset instead of manual `readinessProbe` and `livenessProbe` configuration.

**Before (v5.2.3):**

```yaml
pix:
  readinessProbe:
    path: /health
  livenessProbe: {}
```

**After (v5.3.0):**

```yaml
pix:
  health:
    stack: go
```

**What changed:**

The chart no longer reads `readinessProbe` or `livenessProbe` directly from values. Instead, it uses the `health.stack` preset to generate:

- Startup probe (new)
- Liveness probe
- Readiness probe
- Container ports
- Termination grace period
- Deployment strategy
- PodDisruptionBudget configuration

**Why it matters:**

The health preset ensures consistent probe configuration across all components and aligns with the platform-wide health endpoint convention. The `1.14.0-beta.6` application image serves health checks on a dedicated port and exposes `/readyz` for readiness checks.

**Migration required:**

If you have overridden `readinessProbe` or `livenessProbe` in your custom values, you must remove those overrides and configure the `health` preset instead. The chart will **fail to render** if you attempt to override probe configuration manually.

**Component-specific presets:**

| Component | v5.3.0 default preset | Purpose |
|-----------|----------------------|---------|
| `pix` | `stack: go` | HTTP service with health port |
| `inbound` | `stack: go-worker` | Background worker |
| `outbound` | `stack: go-worker` | Background worker |
| `reconciliation` | `stack: go-worker` | Background worker |
| `schedule` | `stack: go-worker` | Background worker |

**Example migration:**

If you previously customized probe timing:

```yaml
# v5.2.3 (old)
pix:
  readinessProbe:
    path: /health
    initialDelaySeconds: 15
    periodSeconds: 10
  livenessProbe:
    path: /health
    initialDelaySeconds: 10
```

You must now use the health preset and accept the preset's timing defaults:

```yaml
# v5.3.0 (recommended)
pix:
  health:
    stack: go
```

### 2. Worker components no longer expose Service or Ingress

The `inbound`, `outbound`, `reconciliation`, and `schedule` worker components no longer create Kubernetes Service or Ingress resources. These components are background workers that do not serve HTTP traffic.

**What was removed:**

| Component | Removed fields |
|-----------|----------------|
| `inbound` | `service`, `ingress` |
| `outbound` | `service`, `ingress` |
| `reconciliation` | `service`, `ingress` |
| `schedule` | `service` |

**Before (v5.2.3):**

```yaml
inbound:
  service:
    type: ClusterIP
    port: 4016
  ingress:
    enabled: false
    className: "nginx"
```

**After (v5.3.0):**

```yaml
inbound:
  health:
    stack: go-worker
  # service and ingress fields removed
```

**Why it matters:**

Worker components do not need external network access. Removing the Service and Ingress resources simplifies the chart and prevents operators from accidentally exposing internal workers.

**Migration required:**

If you have overridden `service` or `ingress` for any worker component in your custom values, you must remove those overrides before upgrading. The chart will **fail to render** if these fields are present.

**Example migration:**

```yaml
# v5.2.3 (old) - REMOVE THESE
inbound:
  service:
    port: 4016
  ingress:
    enabled: true
    hosts:
      - host: inbound.example.com
```

```yaml
# v5.3.0 (new) - workers have no service/ingress
inbound:
  health:
    stack: go-worker
```

> **Important:** The `pix` component still exposes a Service on port `4014` because it serves HTTP API traffic. Only worker components are affected by this change.

### 3. PDB and deployment strategy now owned by health preset

The `pdb` and `deploymentStrategy` configuration blocks are now derived from the `health` preset and cannot be overridden directly.

**What was removed:**

All components previously allowed manual configuration of:

- `pdb.enabled`
- `pdb.maxUnavailable`
- `pdb.minAvailable`
- `pdb.annotations`
- `deploymentStrategy.type`
- `deploymentStrategy.rollingUpdate.maxSurge`
- `deploymentStrategy.rollingUpdate.maxUnavailable`

**Before (v5.2.3):**

```yaml
pix:
  pdb:
    enabled: true
    maxUnavailable: 1
    minAvailable: 0
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
```

**After (v5.3.0):**

```yaml
pix:
  health:
    stack: go
  # pdb and deploymentStrategy derived from health preset
```

**Why it matters:**

The health preset ensures consistent rollout behavior and disruption budgets across all components. The preset automatically configures:

- **PDB:** `maxUnavailable: 1` for all components
- **Strategy:** `RollingUpdate` with `maxSurge: 25%` and `maxUnavailable: 0` for all components

**Migration required:**

If you have overridden `pdb` or `deploymentStrategy` in your custom values, you must remove those overrides before upgrading. The chart will **fail to render** if these fields are present.

**Example migration:**

```yaml
# v5.2.3 (old) - REMOVE THESE
pix:
  pdb:
    enabled: true
    maxUnavailable: 2
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 0
```

```yaml
# v5.3.0 (new) - preset owns these
pix:
  health:
    stack: go
```

### 4. Default replica count increased for pix component

The default `pix.replicaCount` increased from `1` to `2`.

| Component | v5.2.3 default | v5.3.0 default |
|-----------|----------------|----------------|
| `pix.replicaCount` | `1` | `2` |
| `inbound.replicaCount` | `1` | `1` |
| `outbound.replicaCount` | `1` | `1` |
| `reconciliation.replicaCount` | `1` | `1` |
| `schedule.replicaCount` | `1` | `1` |

`replicaCount` applies only when `pix.autoscaling.enabled` is `false`; with the default (`true`, `minReplicas: 3`) the HPA sets the replica count, as before.

**Why it matters:**

Worker components remain at `1` replica by default because they process background jobs and do not serve user traffic.

**Migration required:**

If you explicitly set `pix.replicaCount: 1` in your custom values and want to keep a single replica, no action is required — your override will take precedence. If you disabled `pix.autoscaling` and relied on the chart default and want to keep a single replica, you must now explicitly set:

```yaml
pix:
  replicaCount: 1
```

## New Features

### 1. lerian-common-helm dependency

The chart now depends on `lerian-common-helm` version `2.6.0`, which provides the health preset system and common template helpers.

**Chart.yaml change:**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.6.0"
    repository: "oci://ghcr.io/lerianstudio"
  - name: postgresql
    version: "16.3.5"
    repository: "https://charts.bitnami.com/bitnami"
```

**Why it matters:**

The `lerian-common-helm` library chart provides reusable templates for health checks, PDBs, and deployment strategies, ensuring consistency across all Lerian Studio charts.

**Operational impact:**

The published chart package already includes `lerian-common-helm`, so the upgrade needs no extra repository. No manual action is required.

### 2. Startup probes added to all components

All components now include a startup probe in addition to liveness and readiness probes. The startup probe allows the application more time to initialize before liveness checks begin.

**Example probe configuration (derived from `health.stack: go`):**

```yaml
startupProbe:
  httpGet:
    path: /health
    port: health
  initialDelaySeconds: 0
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 60
livenessProbe:
  httpGet:
    path: /health
    port: health
  initialDelaySeconds: 0
  periodSeconds: 10
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /readyz
    port: health
  initialDelaySeconds: 0
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
```

**Why it matters:**

The startup probe prevents the kubelet from killing slow-starting containers during initialization.

**Operational impact:**

Pods may take slightly longer to become ready during initial deployment, but will be more resilient to slow startup times.

### 3. Health port and environment variables

The `1.14.0-beta.6` application image serves health checks on a dedicated port (separate from the main service port). The health preset automatically configures the container ports and injects health-related environment variables.

**Container ports (example for `pix` component):**

```yaml
ports:
  - name: http
    containerPort: 4014
    protocol: TCP
  - name: health
    containerPort: 8099
    protocol: TCP
```

**Environment variables injected by health preset:**

| Variable | Value | Purpose |
|----------|-------|---------|
| `HEALTH_PORT` | `8099` | Port for health check endpoints |
| `SHUTDOWN_DRAIN_DELAY` | `15s` on `pix`, `0s` on workers | Drain delay before shutdown (`health.drainSeconds`) |
| `SHUTDOWN_TIMEOUT` | `30s` | Graceful shutdown timeout (`health.shutdownSeconds`) |

**Why it matters:**

The environment variables ensure the application serves health endpoints on the correct port.

**Operational impact:**

The application must read the `HEALTH_PORT` environment variable and serve health endpoints on that port. The `1.14.0-beta.6` image includes this support.

### 4. Termination grace period

The health preset automatically sets `terminationGracePeriodSeconds` based on the component type:

| Component type | Termination grace period |
|----------------|--------------------------|
| `go` (HTTP service) | `55` seconds |
| `go-worker` (background worker) | `40` seconds |

**Operational impact:**

During pod termination (e.g., during a rolling update), the kubelet will wait up to 40 seconds for worker pods to shut down gracefully before sending SIGKILL.

## Configuration Reference

### Health preset options

Each component must define a `health.stack` value. The preset determines all probe, port, and rollout configuration.

**Available presets:**

| Preset | Use case | Probes target | Container ports | Grace period |
|--------|----------|---------------|-----------------|--------------|
| `go` | HTTP service | `/readyz`, `/health` on `health` port | `http` + `health` | 55s |
| `go-worker` | Background worker | `/readyz`, `/health` on `health` port | `health` only | 40s |

**Example configuration:**

```yaml
pix:
  health:
    stack: go

inbound:
  health:
    stack: go-worker

outbound:
  health:
    stack: go-worker

reconciliation:
  health:
    stack: go-worker

schedule:
  health:
    stack: go-worker
```

> **Note:** The `health` preset is mandatory.

### Removed configuration fields

The following fields are no longer supported and will cause the chart to fail rendering if present:

**All components:**

- `readinessProbe` (replaced by `health` preset)
- `livenessProbe` (replaced by `health` preset)
- `startupProbe` and `terminationGracePeriodSeconds` (owned by the `health` preset)
- `pdb` (replaced by `health` preset)
- `deploymentStrategy` (replaced by `health` preset)
- `configmap.HEALTH_PORT`, `configmap.SHUTDOWN_DRAIN_DELAY` and `configmap.SHUTDOWN_TIMEOUT` (use `health.drainSeconds` and `health.shutdownSeconds`)
- An `image.tag` below `1.14.0-beta.6`, the first image that serves the health port

**Worker components only (`inbound`, `outbound`, `reconciliation`, `schedule`):**

- `service` (workers do not expose services)
- `ingress` (workers do not expose ingress)

**Not rendered any more:**

- `configmap.WORKER_PORT` on `inbound`, `outbound`, `reconciliation` and `schedule`; a value you set is ignored.
- `outbound.configmap.WEBHOOK_ORCHESTRATOR_SHUTDOWN_TIMEOUT`; set `outbound.health.shutdownSeconds` instead (default 30).

## Migration Steps

Follow these steps to migrate your custom values from v5.2.3 to v5.3.0:

**1. Review your current custom values file**

Identify any overrides for the removed fields:

```bash
grep -E "(readinessProbe|livenessProbe|pdb|deploymentStrategy|service|ingress)" your-values.yaml
```

**2. Remove all overrides for preset-owned fields**

Delete or comment out the following sections from your custom values:

```yaml
# REMOVE THESE
pix:
  readinessProbe: {}
  livenessProbe: {}
  pdb:
    enabled: true
  deploymentStrategy:
    type: RollingUpdate

inbound:
  readinessProbe: {}
  livenessProbe: {}
  pdb: {}
  deploymentStrategy: {}
  service: {}
  ingress: {}

outbound:
  readinessProbe: {}
  livenessProbe: {}
  pdb: {}
  deploymentStrategy: {}
  service: {}
  ingress: {}

reconciliation:
  readinessProbe: {}
  livenessProbe: {}
  pdb: {}
  deploymentStrategy: {}
  service: {}
  ingress: {}

schedule:
  readinessProbe: {}
  livenessProbe: {}
  pdb: {}
  deploymentStrategy: {}
  service: {}
```

**3. Add health preset configuration**

If you removed any probe or PDB overrides, add the `health` preset to each affected component:

```yaml
pix:
  health:
    stack: go

inbound:
  health:
    stack: go-worker

outbound:
  health:
    stack: go-worker

reconciliation:
  health:
    stack: go-worker

schedule:
  health:
    stack: go-worker
```

> **Note:** If you did not override any probe or PDB settings in v5.2.3, you do not need to add the `health` preset — the chart defaults will apply automatically.

**4. Review replica count for pix component**

If `pix.autoscaling.enabled` is `false` and you want to keep a single replica of the `pix` service (instead of the new default of `2`), explicitly set:

```yaml
pix:
  replicaCount: 1
```

**5. Update image tags (if pinned)**

If you explicitly set image tags in your custom values, update them to `1.14.0-beta.6`:

```yaml
pix:
  image:
    tag: "1.14.0-beta.6"

inbound:
  image:
    tag: "1.14.0-beta.6"

outbound:
  image:
    tag: "1.14.0-beta.6"

reconciliation:
  image:
    tag: "1.14.0-beta.6"

schedule:
  image:
    tag: "1.14.0-beta.6"
```

> **Note:** If you rely on the chart's `appVersion` default, no action is required.

**6. Give every worker a license key**

From app `1.14.0-beta.6`, the `inbound`, `outbound`, `reconciliation` and `schedule` workers refuse to boot without `LICENSE_KEY`. With chart-managed Secrets (the default), each worker falls back to `pix.secrets.LICENSE_KEY`, so no action is needed. For a worker with `useExistingSecrets: true`, add the `LICENSE_KEY` key to that existing Secret before you upgrade.

> **Note:** Do not upgrade with `--reuse-values`. It keeps the `5.2.3` chart defaults (`pdb`, `deploymentStrategy`, `readinessProbe` and the worker `service` blocks), and the render fails. Pass your values file with `-f`, as below.

**7. Preview the upgrade**

Use the helm-diff plugin to review all changes before applying:

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.0 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

**8. Perform the upgrade**

Run the upgrade command during a maintenance window:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.0 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

**9. Verify all pods are running**

Check that all components have successfully rolled out:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg
```

**10. Verify health endpoints**

Confirm that the new health endpoints are responding:

```bash
kubectl port-forward -n plugin-br-pix-indirect-btg deploy/plugin-br-pix-indirect-btg 8099:8099
curl http://localhost:8099/health
curl http://localhost:8099/readyz
```

> **Warning:** The upgrade triggers a rolling restart of all five deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) because the probe and port configuration changes. Depending on your replica count and grace periods, this may cause brief service interruptions for the `pix` API.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.0 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

Pass the migrated values file. Without `-f`, Helm reuses the values stored in the release, including any override you removed from your file, and the render fails.

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.0 -n plugin-br-pix-indirect-btg -f your-values.yaml
```
