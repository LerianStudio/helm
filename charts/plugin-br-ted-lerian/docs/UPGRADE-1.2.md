# Helm Upgrade from v1.1.4 to v1.2.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [Health Preset Migration](#health-preset-migration)
  - [Removed Configuration Fields](#removed-configuration-fields)
- **[Features](#features)**
  - [1. Health Preset System](#1-health-preset-system)
  - [2. Increased Default Replica Count](#2-increased-default-replica-count)
  - [3. Application Version Update](#3-application-version-update)
  - [4. Dependency Updates](#4-dependency-updates)
- **[Configuration Reference](#configuration-reference)**
  - [New Health Preset Configuration](#new-health-preset-configuration)
  - [New Environment Variables](#new-environment-variables)
  - [New Service Ports](#new-service-ports)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a minor release that introduces a health preset system to standardize probe configuration, graceful shutdown behavior, and deployment strategies. The upgrade includes breaking changes that require configuration migration.

| Setting | v1.1.4 | v1.2.0 |
|---------|--------|--------|
| Chart version | `1.1.4` | `1.2.0` |
| App version | `1.0.0-beta.64` | `1.0.0-beta.86` |
| Image tag | `1.0.0-beta.64` | `1.0.0-beta.86` |
| Default replicas | `1` | `2` |
| lerian-common-helm | `2.0.0` | `2.6.1` |

---

## Breaking Changes

### Health Preset Migration

The chart now uses a centralized **health preset system** that manages probes, graceful shutdown, deployment strategy, and PodDisruptionBudget configuration. This replaces the previous manual configuration approach.

**What changed:**
- Health checks now use a dedicated internal port (8099) instead of the main service port
- Probes are served on `/readyz` and `/livez` endpoints on the health port
- Graceful shutdown behavior is now controlled by the preset via environment variables
- Deployment rollout strategy is now preset-managed
- PodDisruptionBudget configuration is now preset-managed

**Impact:** If you have customized any of the following fields in your values file, you must remove them before upgrading:

- `plugin-br-ted-lerian.terminationGracePeriodSeconds`
- `plugin-br-ted-lerian.pdb`
- `plugin-br-ted-lerian.deploymentUpdate`
- `plugin-br-ted-lerian.livenessProbe`
- `plugin-br-ted-lerian.readinessProbe`

> **Warning:** The upgrade will fail with an error message if `pdb` or `deploymentUpdate` keys are present in your values file. These fields are now owned by the health preset and cannot be overridden.

### Removed Configuration Fields

The following configuration fields have been removed and replaced by the health preset:

| Removed Field | v1.1.4 Default | Replacement |
|---------------|----------------|-------------|
| `terminationGracePeriodSeconds` | `55` | Managed by `health.stack` preset |
| `pdb.enabled` | `true` | Always enabled when replicas ≥ 2 |
| `pdb.minAvailable` | `1` | Removed (uses `maxUnavailable: 1`) |
| `pdb.maxUnavailable` | `1` | Managed by health preset |
| `deploymentUpdate.type` | `RollingUpdate` | Managed by health preset |
| `deploymentUpdate.maxSurge` | `1` | Now `25%` (preset default) |
| `deploymentUpdate.maxUnavailable` | `0` | Remains `0` (preset default) |

**Before (v1.1.4):**
```yaml
plugin-br-ted-lerian:
  terminationGracePeriodSeconds: 55
  pdb:
    enabled: true
    minAvailable: 1
    maxUnavailable: 1
    annotations: {}
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 0
```

**After (v1.2.0):**
```yaml
plugin-br-ted-lerian:
  health:
    stack: go
```

---

## Features

### 1. Health Preset System

The chart now implements a health preset system via the `lerian-common.health` helper. This standardizes health check configuration, graceful shutdown, and availability management across all Lerian Studio charts.

**Key capabilities:**
- Automatic probe configuration based on application stack (Go)
- Dedicated health port (8099) for internal monitoring
- Standardized graceful shutdown with drain delay
- Preset-managed deployment strategy and PodDisruptionBudget
- Version-aware health endpoint routing (requires app version ≥ 1.0.0-beta.86)

**Configuration:**

```yaml
plugin-br-ted-lerian:
  health:
    stack: go
```

| Field | Default | Description |
|-------|---------|-------------|
| `health.stack` | `go` | Application stack type; controls probe paths and timing |

The preset automatically configures:
- **Startup probe:** HTTP GET on port 8099, path `/readyz`, 30s timeout, 60 retries (10s period)
- **Liveness probe:** HTTP GET on port 8099, path `/livez`, 5s timeout, 3 failures
- **Readiness probe:** HTTP GET on port 8099, path `/readyz`, 5s timeout, 3 failures
- **Grace period:** 55 seconds (15s drain + 30s shutdown budget + 10s margin)
- **Rollout strategy:** RollingUpdate with maxSurge 25%, maxUnavailable 0
- **PodDisruptionBudget:** maxUnavailable 1 (when replicas ≥ 2)

> **Important:** The health preset requires application version `1.0.0-beta.86` or later. Earlier versions do not serve the `/readyz` endpoint on the health port and will fail health checks.

### 2. Increased Default Replica Count

The default replica count has been increased from 1 to 2 to improve availability and enable the PodDisruptionBudget.

| Setting | v1.1.4 | v1.2.0 |
|---------|--------|--------|
| `replicaCount` | `1` | `2` |
| `autoscaling.minReplicas` | `1` | `2` |

**Before (v1.1.4):**
```yaml
plugin-br-ted-lerian:
  replicaCount: 1
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 5
```

**After (v1.2.0):**
```yaml
plugin-br-ted-lerian:
  replicaCount: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
```

**Impact:** Deployments will now run 2 pods by default. If autoscaling is enabled, the minimum replica count is also 2. This ensures zero-downtime deployments with the PodDisruptionBudget (maxUnavailable: 1).

> **Note:** If you have explicitly set `replicaCount: 1` in your values file and want to keep a single replica, you must also disable autoscaling or set `autoscaling.minReplicas: 1`. However, running with 1 replica disables the PodDisruptionBudget and may cause brief downtime during upgrades.

### 3. Application Version Update

The application version has been updated from `1.0.0-beta.64` to `1.0.0-beta.86`, incorporating 22 beta iterations.

| Setting | v1.1.4 | v1.2.0 |
|---------|--------|--------|
| App version | `1.0.0-beta.64` | `1.0.0-beta.86` |
| Image tag | `1.0.0-beta.64` | `1.0.0-beta.86` |

**Before (v1.1.4):**
```yaml
plugin-br-ted-lerian:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-ted-lerian
    pullPolicy: IfNotPresent
    tag: "1.0.0-beta.64"
```

**After (v1.2.0):**
```yaml
plugin-br-ted-lerian:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-ted-lerian
    pullPolicy: IfNotPresent
    tag: "1.0.0-beta.86"
```

**Impact:** The upgrade will trigger a rolling update with the new container image. Version `1.0.0-beta.86` is the minimum version required for the health preset system, as it serves health endpoints on the dedicated health port (8099).

> **Note:** If you have overridden `plugin-br-ted-lerian.image.tag` in your values file with a version earlier than `1.0.0-beta.86`, you must remove that override or update it to `1.0.0-beta.86` or later. Earlier versions are incompatible with the health preset.

### 4. Dependency Updates

The `lerian-common-helm` dependency has been updated from `2.0.0` to `2.6.1`, bringing the new health preset system and other common chart improvements.

| Dependency | v1.1.4 | v1.2.0 |
|------------|--------|--------|
| lerian-common-helm | `2.0.0` | `2.6.1` |
| postgresql | `16.3.5` | `16.3.5` |

**Impact:** The `lerian-common-helm` update provides the `lerian-common.health` helper used by the health preset. No configuration changes are required for this dependency update.

---

## Configuration Reference

### New Health Preset Configuration

The health preset is configured via the `plugin-br-ted-lerian.health` field:

```yaml
plugin-br-ted-lerian:
  health:
    stack: go
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `health` | object | `{"stack": "go"}` | Health preset configuration |
| `health.stack` | string | `go` | Application stack type; determines probe configuration |

The preset outputs the following computed values (read-only, not configurable):

| Computed Field | Value | Description |
|----------------|-------|-------------|
| `terminationGracePeriodSeconds` | `55` | Pod termination grace period |
| `strategy.type` | `RollingUpdate` | Deployment update strategy |
| `strategy.rollingUpdate.maxSurge` | `25%` | Maximum pods above desired count |
| `strategy.rollingUpdate.maxUnavailable` | `0` | Maximum unavailable pods during rollout |
| `pdb.maxUnavailable` | `1` | Maximum unavailable pods (when replicas ≥ 2) |

### New Environment Variables

The health preset injects the following environment variables into the deployment:

| Variable | Value | Description |
|----------|-------|-------------|
| `HEALTH_PORT` | `8099` | Port for health check endpoints |
| `SHUTDOWN_DRAIN_DELAY` | `15s` | Delay before starting shutdown (allows load balancer drain) |
| `SHUTDOWN_TIMEOUT` | `30s` | Maximum time for graceful shutdown |

**Before (v1.1.4):**
```yaml
env:
- name: SHUTDOWN_DRAIN_DELAY
  value: "15s"
```

**After (v1.2.0):**
```yaml
env:
- name: HEALTH_PORT
  value: "8099"
- name: SHUTDOWN_DRAIN_DELAY
  value: "15s"
- name: SHUTDOWN_TIMEOUT
  value: "30s"
```

> **Note:** These environment variables are automatically injected by the health preset and cannot be overridden via values.yaml.

### New Service Ports

The Service now exposes an additional internal port for health checks:

**Before (v1.1.4):**
```yaml
ports:
- name: http
  port: 3000
  targetPort: http
  protocol: TCP
```

**After (v1.2.0):**
```yaml
ports:
- name: http
  port: 3000
  targetPort: http
  protocol: TCP
- name: health
  port: 8099
  targetPort: health
  protocol: TCP
```

**Impact:** The health port (8099) is used internally by Kubernetes probes and is not exposed via Ingress. No changes to external access or routing are required.

---

## Migration Steps

Follow these steps to migrate your configuration from v1.1.4 to v1.2.0:

### Step 1: Review your current values file

Check if you have customized any of the following fields:

```bash
grep -E "(terminationGracePeriodSeconds|pdb:|deploymentUpdate:|livenessProbe:|readinessProbe:)" your-values.yaml
```

### Step 2: Remove incompatible fields

If any of the following fields are present in your values file, remove them:

- `plugin-br-ted-lerian.terminationGracePeriodSeconds`
- `plugin-br-ted-lerian.pdb` (entire block)
- `plugin-br-ted-lerian.deploymentUpdate` (entire block)

**Example migration:**

**Before (your-values.yaml):**
```yaml
plugin-br-ted-lerian:
  replicaCount: 2
  terminationGracePeriodSeconds: 60
  pdb:
    enabled: true
    minAvailable: 1
    annotations:
      custom.annotation: "value"
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 2
    maxUnavailable: 0
  image:
    tag: "1.0.0-beta.64"
```

**After (your-values.yaml):**
```yaml
plugin-br-ted-lerian:
  replicaCount: 2
  health:
    stack: go
  image:
    tag: "1.0.0-beta.86"
```

> **Important:** If you had custom PDB annotations, these are no longer supported. The health preset manages the PDB without custom annotations.

### Step 3: Update image tag if pinned

If you have explicitly set `plugin-br-ted-lerian.image.tag` to a version earlier than `1.0.0-beta.86`, update it:

```yaml
plugin-br-ted-lerian:
  image:
    tag: "1.0.0-beta.86"
```

Or remove the override to use the chart's default appVersion.

### Step 4: Adjust replica count if needed

If you were running with `replicaCount: 1` and want to continue with a single replica:

```yaml
plugin-br-ted-lerian:
  replicaCount: 1
  autoscaling:
    enabled: false
```

> **Warning:** Running with 1 replica disables the PodDisruptionBudget and may cause brief service interruption during deployments.

### Step 5: Validate your updated values

Ensure your values file only contains supported fields:

```bash
helm template plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.2.0 -f your-values.yaml --dry-run
```

If the command fails with an error about `pdb` or `deploymentUpdate`, those fields are still present and must be removed.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.2.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.2.0
```
