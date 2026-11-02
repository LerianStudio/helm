# Helm Upgrade from v2.1.0 to v2.2.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Health preset replaces manual probe and PDB configuration](#1-health-preset-replaces-manual-probe-and-pdb-configuration)
  - [2. Probes now target health port 8099](#2-probes-now-target-health-port-8099)
  - [3. Shutdown environment variables now managed by preset](#3-shutdown-environment-variables-now-managed-by-preset)
- **[Features](#features)**
  - [1. lerian-common-helm dependency upgraded to 2.6.0](#1-lerian-common-helm-dependency-upgraded-to-260)
  - [2. Application version upgraded to 1.2.0-beta.1](#2-application-version-upgraded-to-120-beta1)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.1.0` to `2.2.0`. The application version is upgraded from `1.0.2` to `1.2.0-beta.1`, and the chart introduces a **breaking change**: the health preset pattern from `lerian-common-helm` now owns all probe configuration, termination grace period, deployment strategy, PodDisruptionBudget, and shutdown environment variables. Operators must remove the now-retired `app.pdb`, `app.deploymentStrategy`, `app.readinessProbe`, `app.startupProbe`, `app.livenessProbe`, and `app.terminationGracePeriodSeconds` keys from their values overlays and adopt the new `app.health` configuration block.

The application now serves health endpoints (`/health` and `/readyz`) on a dedicated internal port `8099` instead of the main HTTP service port. This change requires application version `1.2.0-beta.1` or later.

## Breaking Changes

### 1. Health preset replaces manual probe and PDB configuration

The chart now uses the `lerian-common.health` preset to manage probes, termination grace period, deployment strategy, PodDisruptionBudget, and shutdown environment variables. The following values keys are **retired** and will cause the chart to fail if present in your values overlay:

- `app.pdb`
- `app.deploymentStrategy`
- `app.readinessProbe`
- `app.startupProbe`
- `app.livenessProbe`
- `app.terminationGracePeriodSeconds`

**Before (v2.1.0):**

```yaml
app:
  terminationGracePeriodSeconds: 60
  pdb:
    enabled: true
    minAvailable: 1
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  readinessProbe:
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 3
    successThreshold: 1
    failureThreshold: 2
  startupProbe:
    periodSeconds: 10
    timeoutSeconds: 3
    failureThreshold: 40
  livenessProbe:
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 3
    successThreshold: 1
    failureThreshold: 3
```

**After (v2.2.0):**

```yaml
app:
  health:
    stack: go
    shutdownSeconds: 35
```

The preset calculates the termination grace period as `drain (15s) + shutdownSeconds + buffer (10s)`, resulting in `60s` total grace period when `shutdownSeconds: 35`. The preset also configures:

- **PodDisruptionBudget:** `maxUnavailable: 1`
- **Deployment strategy:** `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0`
- **Probes:** All probes target the health port `8099` (see next section)
- **Environment variables:** `HEALTH_PORT=8099`, `SHUTDOWN_DRAIN_DELAY=15s`, `SHUTDOWN_TIMEOUT=35s`

> **Important:** If you customized any of the retired probe, PDB, or strategy values in v2.1.0, those customizations are no longer supported. The preset enforces canonical values for the Go stack. If you require different probe timings or PDB settings, you must override the preset behavior by forking the chart or submitting a feature request to the `lerian-common-helm` repository.

> **Warning:** The chart will fail at install/upgrade time with an explicit error if any of the retired keys are present in your values overlay. Remove them before upgrading.

**Operational impact:**

- The termination grace period remains `60s` if you set `shutdownSeconds: 35` (the default). If you previously set `terminationGracePeriodSeconds` to a different value, calculate the equivalent `shutdownSeconds` as `terminationGracePeriodSeconds - 25` (drain 15s + buffer 10s).
- The PDB now uses `maxUnavailable: 1` instead of `minAvailable: 1`. For deployments with 2 replicas, this is equivalent. For deployments with 3+ replicas, `maxUnavailable: 1` allows more pods to be disrupted simultaneously than `minAvailable: 1` would.
- The deployment strategy remains `RollingUpdate` with the same surge and unavailable settings, so no rollout behavior changes.

### 2. Probes now target health port 8099

All probes (startup, liveness, readiness) now target the dedicated health port `8099` instead of the main HTTP service port. The application version `1.2.0-beta.1` is the first version that serves `/health` and `/readyz` on port `8099`.

**Before (v2.1.0):**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: http
livenessProbe:
  httpGet:
    path: /health
    port: http
startupProbe:
  httpGet:
    path: /health
    port: http
```

**After (v2.2.0):**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: health
livenessProbe:
  httpGet:
    path: /health
    port: health
startupProbe:
  httpGet:
    path: /health
    port: health
```

The `health` port is defined as a named container port in the Deployment template:

```yaml
ports:
  - name: http
    containerPort: 8080
    protocol: TCP
  - name: health
    containerPort: 8099
    protocol: TCP
```

> **Important:** The health port is **internal only** and is not exposed via the Service. The Service continues to expose only the main HTTP port (`8080` by default). The health port is used exclusively by Kubernetes probes.

> **Warning:** If you are upgrading from an application version older than `1.2.0-beta.1`, the probes will fail because the older application does not serve health endpoints on port `8099`. Ensure your deployment is running application version `1.2.0-beta.1` or later before upgrading the chart to `2.2.0`.

**Operational impact:**

- The probes will fail during the upgrade if the application image is older than `1.2.0-beta.1`. The rolling update will stall because new pods will not pass readiness checks. Roll back the chart upgrade and ensure the application image is `1.2.0-beta.1` or later before retrying.
- The health port is not exposed externally, so no ingress or service configuration changes are required.

### 3. Shutdown environment variables now managed by preset

The `SHUTDOWN_DRAIN_DELAY` environment variable is no longer hardcoded in the Deployment template. The preset injects `SHUTDOWN_DRAIN_DELAY`, `SHUTDOWN_TIMEOUT`, and `HEALTH_PORT` based on the `app.health` configuration.

**Before (v2.1.0):**

```yaml
env:
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
```

**After (v2.2.0):**

```yaml
env:
  - name: HEALTH_PORT
    value: "8099"
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
  - name: SHUTDOWN_TIMEOUT
    value: "35s"
```

The preset calculates these values from `app.health.shutdownSeconds`:

| Variable | Value | Description |
|----------|-------|-------------|
| `HEALTH_PORT` | `8099` | Port on which the application serves `/health` and `/readyz` |
| `SHUTDOWN_DRAIN_DELAY` | `15s` | Fixed drain delay before shutdown begins (preset constant) |
| `SHUTDOWN_TIMEOUT` | `app.health.shutdownSeconds` | Total budget for graceful shutdown after drain delay |

> **Note:** The `SHUTDOWN_TIMEOUT` environment variable is new in application version `1.2.0-beta.1`. Older application versions do not read this variable. If you are running an older application version, the variable will be ignored.

**Operational impact:**

- If you previously overrode `SHUTDOWN_DRAIN_DELAY` via `app.env` or `app.configmap`, that override will be ignored. The preset always sets `SHUTDOWN_DRAIN_DELAY=15s`.
- The `SHUTDOWN_TIMEOUT` variable is new and controls the application's graceful shutdown budget. The default `35s` matches the previous implicit behavior (60s grace period - 15s drain - 10s buffer).

## Features

### 1. lerian-common-helm dependency upgraded to 2.6.0

The `lerian-common-helm` subchart dependency is upgraded from `2.1.2` to `2.6.0`. This version introduces the `lerian-common.health` preset used by this chart. No operator action is required beyond the migration steps for the health preset.

### 2. Application version upgraded to 1.2.0-beta.1

The application version is upgraded from `1.0.2` to `1.2.0-beta.1`. This version introduces:

- Health endpoints (`/health` and `/readyz`) served on dedicated port `8099`
- Support for the `HEALTH_PORT` and `SHUTDOWN_TIMEOUT` environment variables
- Multi-tenant readiness endpoint `/readyz/tenant/:id` on the health port

> **Note:** The multi-tenant readiness endpoint is only available when multi-tenant mode is enabled via `app.configmap.MULTI_TENANT_ENABLED=true`.

## Configuration Changes

| Setting | v2.1.0 | v2.2.0 |
|---------|--------|--------|
| `app.terminationGracePeriodSeconds` | `60` | **removed** (managed by preset) |
| `app.pdb` | `{ enabled: true, minAvailable: 1 }` | **removed** (managed by preset) |
| `app.deploymentStrategy` | `{ type: RollingUpdate, ... }` | **removed** (managed by preset) |
| `app.readinessProbe` | `{ initialDelaySeconds: 5, ... }` | **removed** (managed by preset) |
| `app.startupProbe` | `{ periodSeconds: 10, ... }` | **removed** (managed by preset) |
| `app.livenessProbe` | `{ initialDelaySeconds: 30, ... }` | **removed** (managed by preset) |
| `app.health` | not present | `{ stack: go, shutdownSeconds: 35 }` |
| `appVersion` | `1.0.2` | `1.2.0-beta.1` |
| `dependencies[0].version` (lerian-common-helm) | `2.1.2` | `2.6.0` |

**New configuration block:**

```yaml
app:
  health:
    stack: go
    shutdownSeconds: 35
```

| Flag | Default | Description |
|------|---------|-------------|
| `stack` | `go` | Application stack type (preset constant; do not change) |
| `shutdownSeconds` | `35` | Total budget for graceful shutdown after drain delay; grace period = drain (15s) + this + buffer (10s) |

**Environment variables added by preset:**

| Variable | Value | Description |
|----------|-------|-------------|
| `HEALTH_PORT` | `8099` | Port on which the application serves health endpoints |
| `SHUTDOWN_DRAIN_DELAY` | `15s` | Fixed drain delay before shutdown begins |
| `SHUTDOWN_TIMEOUT` | `35s` (from `shutdownSeconds`) | Total budget for graceful shutdown |

## Migration Steps

1. **Remove retired configuration keys from your values overlay.** The following keys are no longer supported and will cause the chart to fail if present:

   - `app.pdb`
   - `app.deploymentStrategy`
   - `app.readinessProbe`
   - `app.startupProbe`
   - `app.livenessProbe`
   - `app.terminationGracePeriodSeconds`

2. **Add the `app.health` configuration block to your values overlay:**

   ```yaml
   app:
     health:
       stack: go
       shutdownSeconds: 35
   ```

   If you previously customized `terminationGracePeriodSeconds`, calculate the equivalent `shutdownSeconds` as:

   ```
   shutdownSeconds = terminationGracePeriodSeconds - 25
   ```

   For example, if you set `terminationGracePeriodSeconds: 90`, use `shutdownSeconds: 65`.

3. **Verify your application image is `1.2.0-beta.1` or later.** The chart defaults to `appVersion: 1.2.0-beta.1`, but if you override `app.image.tag` in your values overlay, ensure it points to a version that serves health endpoints on port `8099`. Older versions will fail readiness checks.

4. **Preview the rendered diff** with the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

5. **Run the upgrade command** during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

6. **Verify all pods are running and healthy** after the upgrade:

   ```bash
   kubectl get pods -n <namespace>
   ```

7. **Check that probes target the health port:**

   ```bash
   kubectl get deployment -n <namespace> plugin-br-payments -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}'
   ```

   Expected output:

   ```
   health
   ```

8. **Verify the termination grace period:**

   ```bash
   kubectl get deployment -n <namespace> plugin-br-payments -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}'
   ```

   Expected output (if `shutdownSeconds: 35`):

   ```
   60
   ```

9. **Check service logs** to confirm the application is serving health endpoints on port `8099`:

   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-br-payments --tail=50 | grep "health server"
   ```

> **Important:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and the preset's readiness probe configuration, this may cause brief request handling interruptions. The preset enforces `maxUnavailable: 0` in the deployment strategy to minimize disruption.

> **Warning:** If the upgrade fails with pods stuck in `CrashLoopBackOff` or failing readiness checks, verify that your application image is `1.2.0-beta.1` or later. Roll back the chart upgrade if necessary:

```bash
helm rollback plugin-br-payments -n <namespace>
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 2.2.0 -n plugin-br-payments
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 2.2.0 -n plugin-br-payments
```
