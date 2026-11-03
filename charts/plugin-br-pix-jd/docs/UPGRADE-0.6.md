# Helm Upgrade from v0.5.9 to v0.6.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Health Preset Ownership](#1-health-preset-ownership)
  - [2. Removed Configuration Fields](#2-removed-configuration-fields)
- **[Features](#features)**
  - [1. Health Preset Integration](#1-health-preset-integration)
  - [2. Increased Default Replica Count](#2-increased-default-replica-count)
  - [3. Dedicated Health Port](#3-dedicated-health-port)
  - [4. Worker Health Probes](#4-worker-health-probes)
  - [5. Application Version Update](#5-application-version-update)
  - [6. Common Library Upgrade](#6-common-library-upgrade)
- **[Configuration Reference](#configuration-reference)**
  - [API Health Configuration](#api-health-configuration)
  - [Worker Health Configuration](#worker-health-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Remove Deprecated Configuration](#step-1-remove-deprecated-configuration)
  - [Step 2: Review Grace Period Settings](#step-2-review-grace-period-settings)
  - [Step 3: Update Image Tags](#step-3-update-image-tags)
  - [Step 4: Validate Health Port Accessibility](#step-4-validate-health-port-accessibility)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 0.6.0 introduces the **health preset** from `lerian-common-helm` v2.6.0, which consolidates probe configuration, grace periods, deployment strategies, and PodDisruptionBudgets under a single declarative block. This release also updates the application to version 1.6.0-beta.3 and increases the default API replica count from 1 to 2 for improved availability during rollouts.

| Setting | v0.5.9 | v0.6.0 |
|---------|--------|--------|
| Chart Version | 0.5.9 | 0.6.0 |
| App Version | 1.5.0 | 1.6.0-beta.3 |
| lerian-common-helm | 2.1.2 | 2.6.0 |
| Default API Replicas | 1 | 2 |
| Health Port | N/A | 8099 (internal) |

## Breaking Changes

### 1. Health Preset Ownership

The health preset **owns** the following configuration blocks. If your `values.yaml` still contains any of these fields, the chart will **fail to render** with an explicit error message:

**Removed fields (API):**

- `api.livenessProbe`
- `api.readinessProbe`
- `api.startupProbe`
- `api.pdb`
- `api.deploymentStrategy`
- `api.terminationGracePeriodSeconds`

**Removed fields (Worker):**

- `worker.pdb`
- `worker.deploymentStrategy`
- `worker.terminationGracePeriodSeconds`

**Error example:**

```
plugin-br-pix-jd: api.pdb.enabled is owned by the health preset (PDB maxUnavailable 1, AlwaysAllow); remove it
```

> **Important:** The chart will not render if any of these fields are present in your values file. You must remove them before upgrading.

If the worker runs with `worker.replicaCount` above 1, set it to 1 before upgrading: with `worker.health.singleton: true` the render fails with more than 1 replica.

### 2. Removed Configuration Fields

The following fields have been removed from `values.yaml` and replaced by the health preset:

| Component | Removed Field | Replacement |
|-----------|---------------|-------------|
| API | `livenessProbe.*` | `api.health.stack` (preset manages probes) |
| API | `readinessProbe.*` | `api.health.stack` (preset manages probes) |
| API | `startupProbe.*` | `api.health.stack` (preset manages probes) |
| API | `pdb.enabled` | `api.health` (preset manages PDB) |
| API | `pdb.minAvailable` | `api.health` (preset sets maxUnavailable 1) |
| API | `deploymentStrategy.type` | `api.health.stack` (preset sets RollingUpdate) |
| API | `deploymentStrategy.rollingUpdate.*` | `api.health.stack` (preset sets maxUnavailable 0) |
| API | `terminationGracePeriodSeconds` | `api.health.shutdownSeconds` |
| Worker | `pdb.*` | `worker.health.singleton` (no PDB for singleton) |
| Worker | `deploymentStrategy.type` | `worker.health.singleton` (preset sets Recreate) |
| Worker | `terminationGracePeriodSeconds` | `worker.health.shutdownSeconds` |

## Features

### 1. Health Preset Integration

The chart now uses the `lerian-common.health` preset, which provides a unified configuration model for probes, ports, grace periods, deployment strategies, and PodDisruptionBudgets.

**Before (v0.5.9):**

```yaml
api:
  replicaCount: 1
  livenessProbe:
    path: /health
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    failureThreshold: 3
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  startupProbe:
    enabled: false
  pdb:
    enabled: true
    minAvailable: 1
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  terminationGracePeriodSeconds: 60
```

**After (v0.6.0):**

```yaml
api:
  replicaCount: 2
  health:
    stack: go
    shutdownSeconds: 45
```

**What the preset provides:**

| Preset Output | Value | Purpose |
|---------------|-------|---------|
| `livenessProbe` | HTTP GET `/health` on port 8099 | Detects unresponsive pods |
| `readinessProbe` | HTTP GET `/readyz` on port 8099 | Gates traffic during startup/shutdown |
| `startupProbe` | HTTP GET `/health` on port 8099 | Protects slow cold starts |
| `terminationGracePeriodSeconds` | `shutdownSeconds + 25` (70s) | Drain (15s) + shutdown (45s) + buffer (10s) |
| `strategy` | RollingUpdate, maxUnavailable 0 | Zero-downtime rollouts |
| `pdb` | maxUnavailable 1, AlwaysAllow | Permits voluntary disruptions |
| `HEALTH_PORT` | 8099 | Internal health check port |

> **Note:** The preset calculates `terminationGracePeriodSeconds` as `drain (15s) + shutdownSeconds + buffer (10s)`. For the API with `shutdownSeconds: 45`, the grace period is 70 seconds. This **must** stay above `STREAMING_CLOSE_TIMEOUT_S` (default 30s) or buffered CloudEvents are cut off mid-close.

### 2. Increased Default Replica Count

The default API replica count has been increased from **1 to 2** to ensure at least one pod remains ready during rollouts or node drains.

| Setting | v0.5.9 | v0.6.0 |
|---------|--------|--------|
| `api.replicaCount` | 1 | 2 |

**Operational impact:**

- With `replicaCount: 2`, one pod always remains ready during rollouts

> **Important:** If you explicitly set `api.replicaCount: 1` in your values file, consider increasing it to 2 or enabling autoscaling to avoid availability gaps during upgrades.

### 3. Dedicated Health Port

The application now serves health endpoints on a **dedicated internal port 8099**, separate from the main HTTP port 8080.

Port 8080 no longer serves `/readyz` or `/metrics`: `/readyz` and `/readyz/tenant/:id` answer only on the health port 8099, and there is no `/metrics`. Repoint any monitor or scraper that reads them on port 8080.

**Port allocation:**

| Port | Purpose | Exposed via |
|------|---------|-------------|
| 8080 | Application HTTP API | Service, Ingress |
| 8099 | Health checks (`/health`, `/readyz`) | Internal Service port only |

**Service configuration (generated by preset):**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: plugin-br-pix-jd-api
spec:
  ports:
    - name: http
      port: 8080
      targetPort: http
    - name: health
      port: 8099
      targetPort: 8099
```

> **Note:** The health port is **not** exposed via Ingress. It is an internal Service port used only by Kubernetes probes and cluster-internal health checks.

**Environment variable:**

The preset injects `HEALTH_PORT=8099` into the container environment. The application must be running version **1.6.0-beta.3 or later** to serve on this port.

### 4. Worker Health Probes

The worker component now has **health probes** enabled, served on the same dedicated port 8099.

In v0.5.9 the worker had no ports and no probes.

**After (v0.6.0):**

```yaml
worker:
  health:
    stack: go-worker
    singleton: true
    shutdownSeconds: 50
```

**What the preset provides for workers:**

| Preset Output | Value | Purpose |
|---------------|-------|---------|
| `livenessProbe` | HTTP GET `/health` on port 8099 | Detects unresponsive worker |
| `readinessProbe` | HTTP GET `/readyz` on port 8099 | Gates readiness during startup |
| `startupProbe` | HTTP GET `/health` on port 8099 | Protects slow cold starts |
| `terminationGracePeriodSeconds` | `shutdownSeconds + 10` (60s) | Shutdown (50s) + buffer (10s), no drain |
| `strategy` | Recreate | No overlapping workers (advisory lock contention) |
| `pdb` | None | Singleton has no availability target |
| `HEALTH_PORT` | 8099 | Internal health check port |

> **Note:** The worker uses `Recreate` strategy (not `RollingUpdate`) because two overlapping workers would contend on the same Postgres advisory locks during a rollout with no availability benefit.

### 5. Application Version Update

The application version has been updated from **1.5.0** to **1.6.0-beta.3**.

| Component | v0.5.9 | v0.6.0 |
|-----------|--------|--------|
| `api.image.tag` | 1.5.0 | 1.6.0-beta.3 |
| `worker.image.tag` | 1.5.0 | 1.6.0-beta.3 |
| `Chart.appVersion` | 1.5.0 | 1.6.0-beta.3 |

**Minimum image requirement:**

The health preset requires the application to serve health endpoints on port 8099. The chart enforces a **minimum image version of 1.6.0-beta.3** via the `plugin-br-pix-jd.minImage` helper.

> **Warning:** If you pin `api.image.tag` or `worker.image.tag` to a version earlier than 1.6.0-beta.3, the chart will fail to render with an error. You must upgrade to 1.6.0-beta.3 or later.

### 6. Common Library Upgrade

The `lerian-common-helm` dependency has been upgraded from **2.1.2** to **2.6.0**, introducing the health preset and ALB healthcheck annotations.

| Dependency | v0.5.9 | v0.6.0 |
|------------|--------|--------|
| `lerian-common-helm` | 2.1.2 | 2.6.0 |

**New capabilities from lerian-common-helm 2.6.0:**

- `lerian-common.health` preset for unified probe/grace/strategy/PDB management
- ALB Ingress healthcheck annotations (automatic when `api.ingress.className: alb`)

## Configuration Reference

### API Health Configuration

```yaml
api:
  # Replicas when autoscaling is disabled (two, so a rollout or drain keeps one ready)
  replicaCount: 2
  
  # Health preset (lerian-common.health): probes, HEALTH_PORT 8099, drain, grace,
  # strategy and PDB are owned by it. Grace = drain 15 + shutdownSeconds + 10; it MUST
  # stay above STREAMING_CLOSE_TIMEOUT_S (lib-streaming default 30s) or buffered
  # CloudEvents are cut off mid-close.
  health:
    stack: go
    shutdownSeconds: 45
```

**Health preset fields:**

| Field | Default | Description |
|-------|---------|-------------|
| `stack` | `go` | Preset profile |
| `shutdownSeconds` | `45` | Application shutdown timeout; grace = drain + this + 10 |

**Preset outputs (read-only, generated by chart):**

| Output | Value | Notes |
|--------|-------|-------|
| `terminationGracePeriodSeconds` | 70 | drain (15) + shutdownSeconds (45) + buffer (10) |
| `strategy.type` | RollingUpdate | |
| `strategy.rollingUpdate.maxUnavailable` | 0 | Zero-downtime rollouts |
| `strategy.rollingUpdate.maxSurge` | `25%` | |
| `pdb.maxUnavailable` | 1 | |
| `pdb.unhealthyPodEvictionPolicy` | AlwaysAllow | |
| `env.HEALTH_PORT` | 8099 | |
| `ports[].name` | health | |
| `ports[].containerPort` | 8099 | |

### Worker Health Configuration

```yaml
worker:
  # Health preset for the singleton cron worker: Recreate, 1 replica, no PDB, served
  # on HEALTH_PORT 8099 only. Grace = shutdownSeconds + 10 (no drain: no Service).
  health:
    stack: go-worker
    singleton: true
    shutdownSeconds: 50
```

**Health preset fields:**

| Field | Default | Description |
|-------|---------|-------------|
| `stack` | `go-worker` | Preset profile for workers |
| `singleton` | `true` | Disables PDB, refuses more than 1 replica, uses Recreate strategy |
| `shutdownSeconds` | `50` | Application shutdown timeout; grace = this + 10 (no drain) |

**Preset outputs (read-only, generated by chart):**

| Output | Value | Notes |
|--------|-------|-------|
| `replicas` | `worker.replicaCount` | A singleton refuses more than 1 |
| `terminationGracePeriodSeconds` | 60 | shutdownSeconds (50) + buffer (10), no drain |
| `strategy.type` | Recreate | No overlapping workers |
| `pdb` | None | Singleton has no availability target |
| `env.HEALTH_PORT` | 8099 | |
| `ports[].name` | health | |
| `ports[].containerPort` | 8099 | |

## Migration Steps

### Step 1: Remove Deprecated Configuration

Remove all fields now owned by the health preset from your `values.yaml`:

**API fields to remove:**

```yaml
api:
  # REMOVE THESE:
  livenessProbe: {}
  readinessProbe: {}
  startupProbe: {}
  pdb: {}
  deploymentStrategy: {}
  terminationGracePeriodSeconds: 60
```

**Worker fields to remove:**

```yaml
worker:
  # REMOVE THESE:
  pdb: {}
  deploymentStrategy: {}
  terminationGracePeriodSeconds: 60
```

**After removal, add the health preset:**

```yaml
api:
  health:
    stack: go
    shutdownSeconds: 45

worker:
  health:
    stack: go-worker
    singleton: true
    shutdownSeconds: 50
```

> **Important:** If you customized probe timings, grace periods, or deployment strategies in v0.5.9, those customizations are now controlled by the preset. Review the [Configuration Reference](#configuration-reference) to understand the new defaults.

### Step 2: Review Grace Period Settings

The preset calculates `terminationGracePeriodSeconds` based on `shutdownSeconds`. If you previously set a custom grace period, map it to the new model:

**Mapping formula:**

| Component | Old Grace | New shutdownSeconds |
|-----------|-----------|---------------------|
| API | `terminationGracePeriodSeconds` | `(grace - 25)` |
| Worker | `terminationGracePeriodSeconds` | `(grace - 10)` |

**Example:**

If you had:

```yaml
api:
  terminationGracePeriodSeconds: 90
```

The equivalent in v0.6.0 is:

```yaml
api:
  health:
    shutdownSeconds: 65  # 90 - 25 = 65
```

> **Warning:** The grace period **must** stay above `STREAMING_CLOSE_TIMEOUT_S` (default 30s) or buffered CloudEvents are cut off mid-close. The default `shutdownSeconds: 45` provides a grace of 70s, which is safe.

### Step 3: Update Image Tags

If you explicitly pin image tags in your values file, update them to 1.6.0-beta.3 or later:

```yaml
api:
  image:
    tag: "1.6.0-beta.3"

worker:
  image:
    tag: "1.6.0-beta.3"
```

> **Note:** If you leave `tag` empty, it falls back to `.Chart.AppVersion` (1.6.0-beta.3). Explicit pinning is recommended for production.

### Step 4: Validate Health Port Accessibility

After upgrading, verify that health probes are working:

```bash
kubectl -n midaz-plugins get pods -l app.kubernetes.io/component=api
kubectl -n midaz-plugins describe pod <pod-name>
```


**Port-forward test:**

```bash
kubectl -n midaz-plugins port-forward deployment/plugin-br-pix-jd-api 8099:8099
curl http://localhost:8099/health
curl http://localhost:8099/readyz
```

## Preview changes before upgrading

```bash
helm diff upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.6.0 -n midaz-plugins -f my-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.6.0 -n midaz-plugins -f my-values.yaml
```

If you set the payment signing key and certificate with `--set-file`, add the same two `--set-file` flags to these commands. Otherwise the upgrade drops them and payment orders go out unsigned.
