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

The application version upgrades from `1.12.0` to `1.14.0-beta.6`, which introduces a dedicated health port and `/readyz` endpoint support. This release includes **breaking changes** that require values migration before upgrading.

| Setting | v5.2.3 | v5.3.0 |
|---------|--------|--------|
| Chart version | `5.2.3` | `5.3.0` |
| App version | `1.12.0` | `1.14.0-beta.6` |
| Chart dependencies | `postgresql` only | `lerian-common-helm` + `postgresql` |
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

You must now use the health preset and accept the preset's timing defaults, or override the entire probe configuration by setting `health: {}` and providing full probe specs (not recommended):

```yaml
# v5.3.0 (recommended)
pix:
  health:
    stack: go
```

> **Warning:** The health preset owns probe configuration. If you need custom probe timing that differs from the preset, you must set `health: {}` and provide complete `startupProbe`, `livenessProbe`, and `readinessProbe` blocks manually. This is not recommended and may conflict with future chart updates.

### 2. Worker components no longer expose Service or Ingress

The `inbound`, `outbound`, `reconciliation`, and `schedule` worker components no longer create Kubernetes Service or Ingress resources. These components are background workers that do not serve HTTP traffic.

**What was removed:**

| Component | Removed fields |
|-----------|----------------|
| `inbound` | `service`, `ingress`, `configmap.WORKER_PORT` |
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
- **Strategy:** `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0` for services, `maxUnavailable: 1` for workers

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

# v5.3.0 (new) - preset owns these
pix:
  health:
    stack: go
```

> **Warning:** If you require custom PDB or deployment strategy settings that differ from the preset, you must set `health: {}` and provide complete probe, strategy, and PDB configuration manually. This is not recommended and may conflict with future chart updates.

### 4. Default replica count increased for pix component

The default `pix.replicaCount` increased from `1` to `2` to improve availability for the HTTP API service.

| Component | v5.2.3 default | v5.3.0 default |
|-----------|----------------|----------------|
| `pix.replicaCount` | `1` | `2` |
| `inbound.replicaCount` | `1` | `1` |
| `outbound.replicaCount` | `1` | `1` |
| `reconciliation.replicaCount` | `1` | `1` |
| `schedule.replicaCount` | `1` | `1` |

**Why it matters:**

Running two replicas of the `pix` service ensures zero-downtime deployments and better resilience during pod disruptions. Worker components remain at `1` replica by default because they process background jobs and do not serve user traffic.

**Migration required:**

If you explicitly set `pix.replicaCount: 1` in your custom values and want to keep a single replica, no action is required — your override will take precedence. If you relied on the chart default and want to keep a single replica, you must now explicitly set:

```yaml
pix:
  replicaCount: 1
```

> **Note:** The new default of `2` replicas may increase resource usage. Review your cluster capacity before upgrading.

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

Helm will automatically fetch the `lerian-common-helm` dependency during the upgrade. No manual action is required.

### 2. Startup probes added to all components

All components now include a startup probe in addition to liveness and readiness probes. The startup probe allows the application more time to initialize before liveness checks begin.

**Example probe configuration (derived from `health.stack: go`):**

```yaml
startupProbe:
  httpGet:
    path: /readyz
    port: health
  initialDelaySeconds: 0
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 12
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

The startup probe prevents the kubelet from killing slow-starting containers during initialization. The application has up to 60 seconds (12 failures × 5 seconds) to become ready before the liveness probe takes over.

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
    containerPort: 8080
    protocol: TCP
```

**Environment variables injected by health preset:**

| Variable | Value | Purpose |
|----------|-------|---------|
| `HEALTH_PORT` | `8080` | Port for health check endpoints |
| `HEALTH_STARTUP_PATH` | `/readyz` | Startup probe endpoint |
| `HEALTH_LIVENESS_PATH` | `/health` | Liveness probe endpoint |
| `HEALTH_READINESS_PATH` | `/readyz` | Readiness probe endpoint |

**Why it matters:**

Separating health checks from the main service port improves security and allows independent scaling of health check traffic. The environment variables ensure the application serves health endpoints on the correct port.

**Operational impact:**

The application must read the `HEALTH_PORT` environment variable and serve health endpoints on that port. The `1.14.0-beta.6` image includes this support.

### 4. Termination grace period

The health preset automatically sets `terminationGracePeriodSeconds` based on the component type:

| Component type | Termination grace period |
|----------------|--------------------------|
| `go` (HTTP service) | `30` seconds |
| `go-worker` (background worker) | `60` seconds |

**Why it matters:**

Workers need more time to finish processing in-flight jobs before shutdown. The grace period ensures clean termination without data loss.

**Operational impact:**

During pod termination (e.g., during a rolling update), the kubelet will wait up to 60 seconds for worker pods to shut down gracefully before sending SIGKILL.

## Configuration Reference

### Health preset options

Each component must define a `health.stack` value. The preset determines all probe, port, and rollout configuration.

**Available presets:**

| Preset | Use case | Probes target | Container ports | Grace period |
|--------|----------|---------------|-----------------|--------------|
| `go` | HTTP service | `/readyz`, `/health` on `health` port | `http` + `health` | 30s |
| `go-worker` | Background worker | `/readyz`, `/health` on `health` port | `health` only | 60s |

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

> **Note:** The `health` preset is mandatory. If you set `health: {}`, you must provide complete `startupProbe`, `livenessProbe`, `readinessProbe`, `ports`, `terminationGracePeriodSeconds`, `strategy`, and `pdb` configuration manually.

### Removed configuration fields

The following fields are no longer supported and will cause the chart to fail rendering if present:

**All components:**

- `readinessProbe` (replaced by `health` preset)
- `livenessProbe` (replaced by `health` preset)
- `pdb` (replaced by `health` preset)
- `deploymentStrategy` (replaced by `health` preset)

**Worker components only (`inbound`, `outbound`, `reconciliation`, `schedule`):**

- `service` (workers do not expose services)
- `ingress` (workers do not expose ingress)

**Inbound component only:**

- `configmap.WORKER_PORT` (health port is now injected via environment variables)

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

If you want to keep a single replica of the `pix` service (instead of the new default of `2`), explicitly set:

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

**6. Preview the upgrade**

Use the helm-diff plugin to review all changes before applying:

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.0 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

**7. Perform the upgrade**

Run the upgrade command during a maintenance window:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.0 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

**8. Verify all pods are running**

Check that all components have successfully rolled out:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -l app.kubernetes.io/name=plugin-br-pix-indirect-btg
```

**9. Verify health endpoints**

Confirm that the new health endpoints are responding:

```bash
kubectl port-forward -n plugin-br-pix-indirect-btg svc/plugin-br-pix-indirect-btg 4014:4014
curl http://localhost:4014/health
curl http://localhost:4014/readyz
```

**10. Monitor logs for probe failures**

Check service logs for any health check errors:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=100 | grep -i probe
```

> **Warning:** The upgrade triggers a rolling restart of all five deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) because the probe and port configuration changes. Depending on your replica count and grace periods, this may cause brief service interruptions for the `pix` API.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.0 -n plugin-br-pix-indirect-btg
```
