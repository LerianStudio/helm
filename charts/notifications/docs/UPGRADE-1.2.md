# Helm Upgrade from v1.1.0 to v1.2.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Health preset integration](#1-health-preset-integration)
  - [2. Removed configuration fields](#2-removed-configuration-fields)
  - [3. Worker container ports removed](#3-worker-container-ports-removed)
  - [4. API default replica count increased](#4-api-default-replica-count-increased)
  - [5. API PodDisruptionBudget now enabled by default](#5-api-poddisruptionbudget-now-enabled-by-default)
- **[Features](#features)**
  - [1. Standardized health endpoints on port 8099](#1-standardized-health-endpoints-on-port-8099)
  - [2. Lerian-common-helm dependency for health preset](#2-lerian-common-helm-dependency-for-health-preset)
  - [3. Worker singleton mode](#3-worker-singleton-mode)
  - [4. Minimum image version enforcement](#4-minimum-image-version-enforcement)
- **[Configuration Reference](#configuration-reference)**
  - [New health configuration](#new-health-configuration)
  - [Removed fields](#removed-fields)
  - [Changed defaults](#changed-defaults)
  - [New environment variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `notifications` chart upgrade from `1.1.0` to `1.2.0`. This is a **minor** release that introduces the `lerian-common-helm` dependency for standardized health management, consolidates health endpoints on port 8099, and removes several deprecated configuration fields. The application version changes from `1.1.0` to `1.2.0-beta.6`.

**This upgrade contains breaking changes.** All pods will restart once. Operators must remove deprecated fields from their values files before upgrading.

## Breaking Changes

### 1. Health preset integration

The chart now depends on `lerian-common-helm` (version `2.6.0`) which provides a health preset. This preset **owns** the following configuration areas and they must be removed from your values:

- `terminationGracePeriodSeconds` (top-level)
- `api.probes`, `workerEmail.probes`, `workerSms.probes`, `workerWebhook.probes`
- `api.deploymentStrategy`, `workerEmail.deploymentStrategy`, `workerSms.deploymentStrategy`, `workerWebhook.deploymentStrategy`
- `api.pdb.maxUnavailable`, `api.pdb.minAvailable`
- `workerEmail.containerPort`, `workerSms.containerPort`, `workerWebhook.containerPort`

The health preset calculates these values automatically based on the new `<component>.health` configuration block.

**Before (v1.1.0):**

```yaml
terminationGracePeriodSeconds: 52

api:
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  probes:
    liveness:
      path: /health
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 3
      failureThreshold: 3
    readiness:
      path: /readyz
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
    startup:
      enabled: true
      path: /health
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 30
  pdb:
    enabled: false
    maxUnavailable: 1
    minAvailable: 0

workerEmail:
  containerPort: 8081
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  probes:
    liveness:
      path: /health
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 3
      failureThreshold: 3
    readiness:
      path: /readyz
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
    startup:
      enabled: true
      path: /health
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 30
```

**After (v1.2.0):**

```yaml
api:
  health:
    stack: go
    # Optional: tune drain and shutdown (defaults: drainSeconds: 15, shutdownSeconds: 30)
    # drainSeconds: 15
    # shutdownSeconds: 30
  pdb:
    enabled: true
    # maxUnavailable and minAvailable are owned by the preset

workerEmail:
  health:
    stack: go-worker
    singleton: true
    # Optional: tune shutdown (default: shutdownSeconds: 30)
    # shutdownSeconds: 30
  # containerPort is removed
```

> **Important:** The chart will **fail** to render if any of the owned fields remain in your values. Remove them before upgrading.

### 2. Removed configuration fields

The following configuration keys have been removed from `config` (ConfigMap):

| Removed Key | Reason |
|-------------|--------|
| `RABBITMQ_PORT_HOST` | No longer used by the application |
| `RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS` | Health check logic simplified |
| `RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK` | Health check logic simplified |
| `WORKER_SHUTDOWN_TIMEOUT_SEC` | Replaced by `<component>.health.shutdownSeconds` |
| `RELAXED_RATE_LIMIT_MAX` | Rate limiting tier removed |
| `RELAXED_RATE_LIMIT_WINDOW_SEC` | Rate limiting tier removed |

The following secret key has been removed from `secrets`:

| Removed Key | Reason |
|-------------|--------|
| `RABBITMQ_HEALTH_CHECK_URL` | Health check logic simplified |

**Before (v1.1.0):**

```yaml
config:
  RABBITMQ_PORT_HOST: "15672"
  RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS: "false"
  RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK: "false"
  WORKER_SHUTDOWN_TIMEOUT_SEC: "30"
  RELAXED_RATE_LIMIT_MAX: "1000"
  RELAXED_RATE_LIMIT_WINDOW_SEC: "60"

secrets:
  RABBITMQ_HEALTH_CHECK_URL: ""
```

**After (v1.2.0):**

```yaml
config:
  # Fields removed

secrets:
  # RABBITMQ_HEALTH_CHECK_URL removed
```

> **Action required:** Remove these keys from your values files. If you have overridden any of them, the chart will ignore them but they should be cleaned up.

### 3. Worker container ports removed

Workers no longer expose individual container ports (`8081`, `8082`, `8083`). All health endpoints are now served on port `8099` (managed by the health preset).

**Before (v1.1.0):**

```yaml
workerEmail:
  containerPort: 8081

workerSms:
  containerPort: 8082

workerWebhook:
  containerPort: 8083
```

**After (v1.2.0):**

```yaml
workerEmail:
  # containerPort removed; health port 8099 is automatic

workerSms:
  # containerPort removed; health port 8099 is automatic

workerWebhook:
  # containerPort removed; health port 8099 is automatic
```

Workers do not create Services. The health port is used only for probes.

### 4. API default replica count increased

The default `api.replicaCount` has changed from `1` to `2` to support the now-enabled PodDisruptionBudget.

| Setting | v1.1.0 | v1.2.0 |
|---------|--------|--------|
| `api.replicaCount` | `1` | `2` |
| `api.autoscaling.minReplicas` | `1` | `2` |

**Before (v1.1.0):**

```yaml
api:
  replicaCount: 1
  autoscaling:
    enabled: false
    minReplicas: 1
```

**After (v1.2.0):**

```yaml
api:
  replicaCount: 2
  autoscaling:
    enabled: false
    minReplicas: 2
```

> **Note:** If you have explicitly set `api.replicaCount: 1` in your values, you can keep it, but the PodDisruptionBudget will prevent voluntary disruptions when only one replica is running.

### 5. API PodDisruptionBudget now enabled by default

The API PodDisruptionBudget is now enabled by default with `maxUnavailable: 1` and `unhealthyPodEvictionPolicy: AlwaysAllow`.

| Setting | v1.1.0 | v1.2.0 |
|---------|--------|--------|
| `api.pdb.enabled` | `false` | `true` |

**Before (v1.1.0):**

```yaml
api:
  pdb:
    enabled: false
    maxUnavailable: 1
    minAvailable: 0
```

**After (v1.2.0):**

```yaml
api:
  pdb:
    enabled: true
    # maxUnavailable: 1 and unhealthyPodEvictionPolicy: AlwaysAllow are set by the health preset
```

The PDB is managed by the health preset. You can disable it by setting `api.pdb.enabled: false`, but `maxUnavailable` and `minAvailable` are no longer configurable.

## Features

### 1. Standardized health endpoints on port 8099

All components (API and workers) now serve health endpoints (`/health`, `/readyz`, `/metrics`) on port `8099`. This port is set via the `HEALTH_PORT` environment variable, which is injected automatically by the health preset.

**Impact:**

- The API Service now includes a `health` port (`8099`) in addition to the `http` port (`8080`). The `health` port is internal (ClusterIP only) and is never exposed via Ingress.
- Workers do not create Services; their health port is used only for probes.
- Probes now target the `health` port instead of the component-specific ports.

**Template change (API Service):**

**Before (v1.1.0):**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: notifications
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 8080
      targetPort: http
      protocol: TCP
```

**After (v1.2.0):**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: notifications
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 8080
      targetPort: http
      protocol: TCP
    - name: health
      port: 8099
      targetPort: health
      protocol: TCP
```

### 2. Lerian-common-helm dependency for health preset

The chart now declares a dependency on `lerian-common-helm` version `2.6.0` from `oci://ghcr.io/lerianstudio`. This subchart provides the health preset, which standardizes probes, ports, grace periods, drain logic, rollout strategies, and PodDisruptionBudgets across all Lerian charts.

**Chart.yaml change:**

**Before (v1.1.0):**

```yaml
# No dependencies: Postgres, Redis and RabbitMQ are external (provided by the
# target environment / gitops). Migrations run as a Helm pre-install/pre-upgrade
# Job against the external Postgres.
```

**After (v1.2.0):**

```yaml
dependencies:
  # Health preset only (lerian-common.health). Postgres, Redis and RabbitMQ are
  # external (provided by the target environment / gitops). Migrations run as a
  # Helm pre-install/pre-upgrade Job against the external Postgres.
  - name: lerian-common-helm
    version: "2.6.0"
    repository: "oci://ghcr.io/lerianstudio"
```

The dependency is fetched automatically during `helm upgrade`. No manual action is required.

### 3. Worker singleton mode

Workers now run in singleton mode by default (`health.singleton: true`). This prevents overlapping pods during rollouts because the retry scheduler has no row claim and overlapping pods would resend notifications.

**Impact:**

- Worker Deployments use a `Recreate` strategy instead of `RollingUpdate`.
- Only one pod runs at a time; the old pod terminates before the new one starts.
- `terminationGracePeriodSeconds` is calculated as `shutdownSeconds + 10` (no drain phase for workers).

**values.yaml change:**

```yaml
workerEmail:
  health:
    stack: go-worker
    singleton: true

workerSms:
  health:
    stack: go-worker
    singleton: true

workerWebhook:
  health:
    stack: go-worker
    singleton: true
```

### 4. Minimum image version enforcement

The chart now enforces a minimum image version of `1.2.0-beta.6` (the first version that serves health endpoints on port `8099`). If you specify an older image tag, the chart will fail to render with an error message.

**Example error:**

```
Error: template: notifications/templates/_helpers.tpl:XX:XX: executing "notifications.health" at <include "lerian-common.health" ...>: error calling include: template: lerian-common-helm/templates/_health.tpl:XX:XX: executing "lerian-common.health" at <fail ...>: fail: lerian-common.health: image 1.1.0 is below the minimum 1.2.0-beta.6 required for HEALTH_PORT support
```

> **Important:** Do not override `api.image.tag`, `workerEmail.image.tag`, `workerSms.image.tag`, or `workerWebhook.image.tag` with a version below `1.2.0-beta.6`. The chart defaults to `.Chart.AppVersion` (`1.2.0-beta.6`), which is safe.

## Configuration Reference

### New health configuration

Each component now accepts a `health` block:

| Component | Field | Default | Description |
|-----------|-------|---------|-------------|
| `api` | `health.stack` | `go` | Stack type (determines probe paths and drain behavior) |
| `api` | `health.drainSeconds` | `15` | Seconds to wait for in-flight requests to complete before shutdown |
| `api` | `health.shutdownSeconds` | `30` | Seconds to wait for graceful shutdown after drain |
| `workerEmail` | `health.stack` | `go-worker` | Stack type for workers (no drain phase) |
| `workerEmail` | `health.singleton` | `true` | Use Recreate strategy to prevent overlapping pods |
| `workerEmail` | `health.shutdownSeconds` | `30` | Seconds to wait for graceful shutdown |
| `workerSms` | `health.stack` | `go-worker` | Stack type for workers (no drain phase) |
| `workerSms` | `health.singleton` | `true` | Use Recreate strategy to prevent overlapping pods |
| `workerSms` | `health.shutdownSeconds` | `30` | Seconds to wait for graceful shutdown |
| `workerWebhook` | `health.stack` | `go-worker` | Stack type for workers (no drain phase) |
| `workerWebhook` | `health.singleton` | `true` | Use Recreate strategy to prevent overlapping pods |
| `workerWebhook` | `health.shutdownSeconds` | `30` | Seconds to wait for graceful shutdown |

**Example:**

```yaml
api:
  health:
    stack: go
    drainSeconds: 20
    shutdownSeconds: 40

workerEmail:
  health:
    stack: go-worker
    singleton: true
    shutdownSeconds: 40
```

### Removed fields

Remove these fields from your values:

**Top-level:**

- `terminationGracePeriodSeconds`

**API:**

- `api.probes`
- `api.deploymentStrategy`
- `api.pdb.maxUnavailable`
- `api.pdb.minAvailable`

**Workers:**

- `workerEmail.containerPort`
- `workerEmail.probes`
- `workerEmail.deploymentStrategy`
- `workerEmail.autoscaling` (was not implemented; now documented as removed)
- `workerEmail.pdb` (was not implemented; now documented as removed)
- `workerSms.containerPort`
- `workerSms.probes`
- `workerSms.deploymentStrategy`
- `workerSms.autoscaling` (was not implemented; now documented as removed)
- `workerSms.pdb` (was not implemented; now documented as removed)
- `workerWebhook.containerPort`
- `workerWebhook.probes`
- `workerWebhook.deploymentStrategy`
- `workerWebhook.autoscaling` (was not implemented; now documented as removed)
- `workerWebhook.pdb` (was not implemented; now documented as removed)

**Config:**

- `config.RABBITMQ_PORT_HOST`
- `config.RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS`
- `config.RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK`
- `config.WORKER_SHUTDOWN_TIMEOUT_SEC`
- `config.RELAXED_RATE_LIMIT_MAX`
- `config.RELAXED_RATE_LIMIT_WINDOW_SEC`

**Secrets:**

- `secrets.RABBITMQ_HEALTH_CHECK_URL`

### Changed defaults

| Setting | v1.1.0 | v1.2.0 |
|---------|--------|--------|
| `api.replicaCount` | `1` | `2` |
| `api.autoscaling.minReplicas` | `1` | `2` |
| `api.pdb.enabled` | `false` | `true` |

### New environment variables

The health preset injects the following environment variables automatically:

| Variable | Value | Description |
|----------|-------|-------------|
| `HEALTH_PORT` | `8099` | Port for health endpoints (`/health`, `/readyz`, `/metrics`) |
| `SHUTDOWN_DRAIN_SECONDS` | `<drainSeconds>` | Seconds to drain connections before shutdown (API only) |
| `SHUTDOWN_TIMEOUT_SECONDS` | `<shutdownSeconds>` | Seconds to wait for graceful shutdown |

These variables are set by the health preset and should not be overridden via `extraConfig` or `extraEnvVars`.

## Migration Steps

1. **Back up your current values file:**

   ```bash
   helm get values notifications -n notifications > notifications-values-backup.yaml
   ```

2. **Remove deprecated fields from your values file:**

   - Remove `terminationGracePeriodSeconds` (top-level)
   - Remove `api.probes`, `api.deploymentStrategy`, `api.pdb.maxUnavailable`, `api.pdb.minAvailable`
   - Remove `workerEmail.containerPort`, `workerEmail.probes`, `workerEmail.deploymentStrategy`, `workerEmail.autoscaling`, `workerEmail.pdb`
   - Remove `workerSms.containerPort`, `workerSms.probes`, `workerSms.deploymentStrategy`, `workerSms.autoscaling`, `workerSms.pdb`
   - Remove `workerWebhook.containerPort`, `workerWebhook.probes`, `workerWebhook.deploymentStrategy`, `workerWebhook.autoscaling`, `workerWebhook.pdb`
   - Remove `config.RABBITMQ_PORT_HOST`, `config.RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS`, `config.RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK`, `config.WORKER_SHUTDOWN_TIMEOUT_SEC`, `config.RELAXED_RATE_LIMIT_MAX`, `config.RELAXED_RATE_LIMIT_WINDOW_SEC`
   - Remove `secrets.RABBITMQ_HEALTH_CHECK_URL`

3. **Add health configuration blocks (optional):**

   If you need to tune drain or shutdown timeouts, add the `health` block to each component:

   ```yaml
   api:
     health:
       stack: go
       drainSeconds: 15
       shutdownSeconds: 30

   workerEmail:
     health:
       stack: go-worker
       singleton: true
       shutdownSeconds: 30

   workerSms:
     health:
       stack: go-worker
       singleton: true
       shutdownSeconds: 30

   workerWebhook:
     health:
       stack: go-worker
       singleton: true
       shutdownSeconds: 30
   ```

   The defaults are safe for most deployments. Only add these blocks if you need to override the defaults.

4. **Review the API replica count:**

   The default `api.replicaCount` is now `2`. If you have explicitly set `api.replicaCount: 1`, decide whether to keep it or increase it to `2` for better availability with the PodDisruptionBudget.

5. **Review the PodDisruptionBudget:**

   The API PodDisruptionBudget is now enabled by default. If you do not want a PDB, set:

   ```yaml
   api:
     pdb:
       enabled: false
   ```

6. **Verify image tags:**

   Ensure you are not overriding image tags with versions below `1.2.0-beta.6`. The chart defaults to `.Chart.AppVersion` (`1.2.0-beta.6`).

7. **Preview the upgrade:**

   Use the helm-diff plugin to review the changes (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

8. **Run the upgrade:**

   Execute the upgrade command (see [Command to upgrade](#command-to-upgrade)).

9. **Verify the rollout:**

   ```bash
   kubectl rollout status -n notifications deploy/notifications
   kubectl rollout status -n notifications deploy/notifications-worker-email
   kubectl rollout status -n notifications deploy/notifications-worker-sms
   kubectl rollout status -n notifications deploy/notifications-worker-webhook
   ```

10. **Check pod health:**

    ```bash
    kubectl get pods -n notifications -l app.kubernetes.io/instance=notifications
    ```

    All pods should reach `Running` and `Ready` after the restart.

## Preview changes before upgrading

```bash
helm diff upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.2.0 -n notifications
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.2.0 -n notifications
```
