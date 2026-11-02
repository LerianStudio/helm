# Helm Upgrade from v10.3.0 to v10.4.0

# Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Health Preset Integration](#1-health-preset-integration)
  - [2. Increased Default Replica Counts](#2-increased-default-replica-counts)
  - [3. Application Version Update](#3-application-version-update)
  - [4. Dependency Updates](#4-dependency-updates)
- **[Configuration Reference](#configuration-reference)**
  - [Health Configuration](#health-configuration)
  - [Removed Configuration Fields](#removed-configuration-fields)
  - [New Environment Variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This minor release upgrades the chart from 10.3.0 to 10.4.0 and introduces a standardized health preset system for the auth and identity components. The upgrade replaces manual probe, PodDisruptionBudget, and deployment strategy configuration with an opinionated preset from the `lerian-common-helm` library chart.

| Component | v10.3.0 | v10.4.0 |
|-----------|---------|---------|
| Chart version | 10.3.0 | 10.4.0 |
| App version | 3.14.0 | 3.16.0-beta.5 |
| lerian-common-helm | 2.3.0 | 2.6.0 |
| Identity image | 3.14.0 | 3.16.0-beta.5 |
| Auth image | 3.14.0 | 3.16.0-beta.5 |
| Identity replicas (default) | 1 | 2 |
| Auth replicas (default) | 1 | *(unchanged)* |
| Identity HPA minReplicas | 1 | 2 |

**Key changes:**

- Health probes, PodDisruptionBudget, and deployment strategy are now managed by a health preset
- A dedicated health port (8099) is added to auth and identity pods
- Default replica counts increase to improve availability
- Application images upgrade to 3.16.0-beta.5
- Init containers that wait for dependencies are removed from auth and identity

**Action required:**

Operators who have customized probe settings, `deploymentStrategy`, or PDB `minAvailable`/`maxUnavailable` fields must migrate to the new health preset configuration or remove those overrides. See [Migration Steps](#migration-steps).

# Features

### 1. Health Preset Integration

**What changed:**

Auth and identity now use a standardized health preset (`lerian-common.health`) that consolidates probe configuration, graceful shutdown behavior, deployment strategy, and PodDisruptionBudget settings into a single opinionated block.

**Before (v10.3.0):**

Probes, strategy, and PDB were configured separately:

```yaml
identity:
  readinessProbe: {}
  livenessProbe: {}
  startupProbe:
    enabled: false
    failureThreshold: 5
    periodSeconds: 10
    timeoutSeconds: 10
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  pdb:
    enabled: true
    maxUnavailable: 1
    minAvailable: 0
```

**After (v10.4.0):**

All health-related settings are managed through the `health` preset:

```yaml
identity:
  health:
    stack: go
```

The preset automatically configures:

- **Probes:** Startup, liveness, and readiness probes targeting the health port (8099)
- **Graceful shutdown:** `DRAIN_SECONDS` and `SHUTDOWN_SECONDS` environment variables
- **Deployment strategy:** `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 1`
- **PodDisruptionBudget:** `maxUnavailable: 1`
- **Termination grace period:** Calculated from drain and shutdown seconds

**Why this matters:**

The health preset ensures consistent behavior across all Go-based services in the Lerian stack. It eliminates configuration drift and reduces the surface area for misconfiguration.

**Operational impact:**

- **New health port:** Auth and identity pods now expose port 8099 for health checks. The main service port (4000 for auth, 4001 for identity) remains unchanged.
- **Probe changes:** Probes now target `/health` on port 8099 instead of the main service port. The startup probe is always enabled with a 60-second failure threshold (6 failures × 10s period).
- **Graceful shutdown:** Pods set `DRAIN_SECONDS=15` and `SHUTDOWN_SECONDS=30` by default. The termination grace period is automatically set to 50 seconds (drain + shutdown + 5s buffer).
- **Init containers removed:** The `wait-for-dependencies` init containers in auth and identity are removed. The application now handles dependency readiness internally or relies on Kubernetes retry behavior.

**Pod restart behavior:**

All auth and identity pods will restart during the upgrade because:

1. The pod template changes (new health port, environment variables, probe configuration)
2. The image tag updates to `3.16.0-beta.5`
3. The `helm.sh/chart` label changes to `plugin-access-manager-10.4.0`

The rolling update strategy ensures that new pods pass readiness checks before old pods terminate. With the default `maxUnavailable: 1`, identity (2 replicas) can briefly serve traffic from a single pod during the rollout.

**Customization:**

Operators can tune drain and shutdown timings if needed:

```yaml
identity:
  health:
    stack: go
    drainSeconds: 20
    shutdownSeconds: 40
```

> **Important:** The health preset owns `deploymentStrategy` and `pdb.minAvailable`/`pdb.maxUnavailable`. Setting these fields directly will cause the Helm render to fail. See [Removed Configuration Fields](#removed-configuration-fields).

### 2. Increased Default Replica Counts

**What changed:**

The default replica count for identity increases from 1 to 2, and the HPA minimum for identity increases from 1 to 2.

| Component | Setting | v10.3.0 | v10.4.0 |
|-----------|---------|---------|---------|
| Identity | `replicaCount` | 1 | 2 |
| Identity | `autoscaling.minReplicas` | 1 | 2 |
| Auth | `replicaCount` | 1 | *(unchanged)* |

**Why this matters:**

Running 2 replicas improves availability during rolling updates and node failures. With `maxUnavailable: 1`, at least one identity pod remains available during upgrades.

**Operational impact:**

- **Resource usage:** Identity will consume approximately double the CPU and memory after the upgrade.
- **HPA behavior:** If autoscaling is enabled, the HPA will maintain at least 2 identity replicas even under low load.

**Customization:**

Operators who need to conserve resources can override the replica count:

```yaml
identity:
  replicaCount: 1
  autoscaling:
    minReplicas: 1
```

> **Warning:** Running a single replica means identity will be unavailable during pod restarts and rolling updates.

### 3. Application Version Update

**What changed:**

The application version (appVersion) upgrades from `3.14.0` to `3.16.0-beta.5`. Both auth and identity image tags update to match.

| Component | v10.3.0 | v10.4.0 |
|-----------|---------|---------|
| appVersion | 3.14.0 | 3.16.0-beta.5 |
| identity.image.tag | 3.14.0 | 3.16.0-beta.5 |
| auth.image.tag | 3.14.0 | 3.16.0-beta.5 |

**Why this matters:**

Version `3.16.0-beta.5` is the first release that serves the dedicated health port (8099). The health preset requires this version or newer.

**Operational impact:**

The image upgrade triggers a rolling restart of all auth and identity pods. The new images include:

- Health endpoint on port 8099
- Support for `DRAIN_SECONDS` and `SHUTDOWN_SECONDS` environment variables
- Internal dependency readiness handling (replacing init containers)

> **Note:** This is a beta release. Operators should monitor logs and metrics closely after the upgrade.

### 4. Dependency Updates

**What changed:**

The `lerian-common-helm` dependency upgrades from `2.3.0` to `2.6.0`.

| Dependency | v10.3.0 | v10.4.0 |
|-----------|---------|---------|
| lerian-common-helm | 2.3.0 | 2.6.0 |

**Why this matters:**

Version `2.6.0` introduces the `lerian-common.health` template that powers the health preset feature. It also includes updates to the `lerian-common.service`, `lerian-common.pdb`, and `lerian-common.ingress` templates.

**Operational impact:**

The dependency upgrade is transparent. All changes surface through the health preset and updated template behavior.

# Configuration Reference

## Health Configuration

The `health` preset replaces manual probe, strategy, and PDB configuration. Both auth and identity use the same structure:

```yaml
identity:
  health:
    stack: go                # Required: preset type (only "go" is supported)
    drainSeconds: 15         # Optional: connection drain time before shutdown
    shutdownSeconds: 30      # Optional: graceful shutdown timeout
```

```yaml
auth:
  health:
    stack: go
    drainSeconds: 15
    shutdownSeconds: 30
```

| Field | Default | Description |
|-------|---------|-------------|
| `stack` | *(required)* | Preset type. Must be `go` for auth and identity. |
| `drainSeconds` | 15 | Seconds to drain active connections before shutdown. Sets `DRAIN_SECONDS` env var. |
| `shutdownSeconds` | 30 | Seconds to wait for graceful shutdown. Sets `SHUTDOWN_SECONDS` env var. |

The preset automatically configures:

- **Startup probe:** `/health` on port 8099, 10s period, 6 failures (60s total)
- **Liveness probe:** `/health` on port 8099, 10s period, 3 failures, 30s initial delay
- **Readiness probe:** `/health` on port 8099, 5s period, 3 failures, 10s initial delay
- **Termination grace period:** `drainSeconds + shutdownSeconds + 5` (default: 50s)
- **Deployment strategy:** `RollingUpdate` with `maxSurge: 1`, `maxUnavailable: 1`
- **PodDisruptionBudget:** `maxUnavailable: 1`

## Removed Configuration Fields

The following fields are now owned by the health preset and must be removed from `values.yaml`:

**Identity:**

```yaml
identity:
  readinessProbe: {}           # REMOVE: now managed by health preset
  livenessProbe: {}            # REMOVE: now managed by health preset
  startupProbe:                # REMOVE: now managed by health preset
    enabled: false
    failureThreshold: 5
    periodSeconds: 10
    timeoutSeconds: 10
  deploymentStrategy:          # REMOVE: now managed by health preset
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  pdb:
    enabled: true
    maxUnavailable: 1          # REMOVE: now managed by health preset
    minAvailable: 0            # REMOVE: now managed by health preset
```

**Auth:**

```yaml
auth:
  readinessProbe: {}           # REMOVE: now managed by health preset
  livenessProbe: {}            # REMOVE: now managed by health preset
  startupProbe:                # REMOVE: now managed by health preset
    enabled: false
    failureThreshold: 5
    periodSeconds: 10
    timeoutSeconds: 10
  deploymentStrategy:          # REMOVE: now managed by health preset
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  pdb:
    enabled: true
    maxUnavailable: 1          # REMOVE: now managed by health preset
    minAvailable: 0            # REMOVE: now managed by health preset
```

**What to keep:**

The `pdb.enabled` and `pdb.annotations` fields are still valid:

```yaml
identity:
  pdb:
    enabled: true              # OK: controls whether PDB is created
    annotations:               # OK: custom annotations for the PDB
      example.com/owner: platform-team
```

> **Important:** If you have customized any of the removed fields, the Helm upgrade will fail with an error message indicating which field must be removed. The health preset does not support overriding individual probe settings, strategy parameters, or PDB thresholds.

## New Environment Variables

The health preset adds the following environment variables to auth and identity pods:

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTH_PORT` | 8099 | Port for health check endpoints (`/health`, `/readyz`, `/livez`) |
| `DRAIN_SECONDS` | 15 | Seconds to drain active connections before shutdown |
| `SHUTDOWN_SECONDS` | 30 | Seconds to wait for graceful shutdown |

These variables are set automatically by the health preset and cannot be overridden through `values.yaml`.

# Migration Steps

**Step 1: Review your current values**

Check if you have customized any of the following fields in your `values.yaml`:

- `identity.readinessProbe`, `identity.livenessProbe`, `identity.startupProbe`
- `identity.deploymentStrategy`
- `identity.pdb.minAvailable`, `identity.pdb.maxUnavailable`
- `auth.readinessProbe`, `auth.livenessProbe`, `auth.startupProbe`
- `auth.deploymentStrategy`
- `auth.pdb.minAvailable`, `auth.pdb.maxUnavailable`

**Step 2: Remove conflicting fields**

If any of the above fields are present, remove them from your `values.yaml`. The health preset now manages these settings.

**Before:**

```yaml
identity:
  readinessProbe:
    initialDelaySeconds: 30
    periodSeconds: 10
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 0
  pdb:
    enabled: true
    maxUnavailable: 1
```

**After:**

```yaml
identity:
  health:
    stack: go
  pdb:
    enabled: true
```

**Step 3: Add health configuration (optional)**

If you need to customize drain or shutdown timings, add the `health` block:

```yaml
identity:
  health:
    stack: go
    drainSeconds: 20
    shutdownSeconds: 40
```

```yaml
auth:
  health:
    stack: go
    drainSeconds: 20
    shutdownSeconds: 40
```

**Step 4: Review replica counts**

The default `identity.replicaCount` increases from 1 to 2. If you need to override this:

```yaml
identity:
  replicaCount: 1
  autoscaling:
    minReplicas: 1
```

**Step 5: Preview the upgrade**

Run `helm diff` to verify the changes before applying:

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.4.0 -n plugin-access-manager -f values.yaml
```

**Step 6: Apply the upgrade**

See [Command to upgrade](#command-to-upgrade).

> **Note:** If you encounter a render error mentioning `deploymentStrategy`, `pdb.minAvailable`, or `pdb.maxUnavailable`, you have not removed all conflicting fields. Review Step 2 and ensure all preset-owned fields are removed.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.4.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.4.0 -n plugin-access-manager
```
