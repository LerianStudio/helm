# Helm Upgrade from v10.2.1 to v10.3.0

## Topics

- **[Application Version Update](#application-version-update)**
  - [1. Midaz application bump to 4.5.0-beta.94](#1-midaz-application-bump-to-450-beta94)
  - [2. Image tag updates](#2-image-tag-updates)
- **[Features](#features)**
  - [1. Health preset for ledger and tracer components](#1-health-preset-for-ledger-and-tracer-components)
  - [2. Automatic startup probe configuration](#2-automatic-startup-probe-configuration)
  - [3. Dedicated health port on 8099](#3-dedicated-health-port-on-8099)
  - [4. Simplified RabbitMQ configuration](#4-simplified-rabbitmq-configuration)
  - [5. Tracer readiness probe configuration update](#5-tracer-readiness-probe-configuration-update)
- **[Breaking Changes](#breaking-changes)**
  - [1. Removed manual probe configuration fields](#1-removed-manual-probe-configuration-fields)
  - [2. Removed manual PDB and deployment strategy fields](#2-removed-manual-pdb-and-deployment-strategy-fields)
  - [3. Removed manual termination grace period configuration](#3-removed-manual-termination-grace-period-configuration)
  - [4. Removed manual shutdown drain delay configuration](#4-removed-manual-shutdown-drain-delay-configuration)
  - [5. Removed RabbitMQ management API configuration](#5-removed-rabbitmq-management-api-configuration)
  - [6. Removed tracer readiness drain grace configuration](#6-removed-tracer-readiness-drain-grace-configuration)
  - [7. `/readyz` no longer served on the main ports](#7-readyz-no-longer-served-on-the-main-ports)
  - [8. Ledger and tracer require `LICENSE_KEY`](#8-ledger-and-tracer-require-license_key)
- **[Configuration Reference](#configuration-reference)**
  - [1. New health preset configuration](#1-new-health-preset-configuration)
  - [2. Minimum image version requirement](#2-minimum-image-version-requirement)
- **[Migration Steps](#migration-steps)**
  - [1. Remove deprecated probe overrides](#1-remove-deprecated-probe-overrides)
  - [2. Remove deprecated PDB and deployment strategy overrides](#2-remove-deprecated-pdb-and-deployment-strategy-overrides)
  - [3. Remove deprecated termination grace period overrides](#3-remove-deprecated-termination-grace-period-overrides)
  - [4. Remove deprecated RabbitMQ management API configuration](#4-remove-deprecated-rabbitmq-management-api-configuration)
  - [5. Remove deprecated tracer readiness configuration](#5-remove-deprecated-tracer-readiness-configuration)
  - [6. Verify image tags meet minimum requirements](#6-verify-image-tags-meet-minimum-requirements)
  - [7. Set the license key](#7-set-the-license-key)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

### 1. Midaz application bump to 4.5.0-beta.94

This minor release updates the Midaz application from version `4.4.0` to `4.5.0-beta.94`. This is a beta release that introduces the health preset system and standardized health check endpoints.

| Component | v10.2.1 | v10.3.0 |
|-----------|---------|---------|
| appVersion | 4.4.0 | 4.5.0-beta.94 |

### 2. Image tag updates

The following container image tags have been updated to align with the new application version:

| Component | v10.2.1 | v10.3.0 |
|-----------|---------|---------|
| ledger.image.tag | 4.4.0 | 4.5.0-beta.94 |
| tracer.image.tag | 4.4.0 | 4.5.0-beta.94 |

**Before (v10.2.1):**

```yaml
ledger:
  image:
    tag: "4.4.0"

tracer:
  image:
    tag: "4.4.0"
```

**After (v10.3.0):**

```yaml
ledger:
  image:
    tag: "4.5.0-beta.94"

tracer:
  image:
    tag: "4.5.0-beta.94"
```

> **Important:** If you have overridden these image tags in your `values.yaml`, ensure they are updated to `4.5.0-beta.94` or later, or removed to use the chart defaults. Images older than `4.5.0-beta.94` do not serve the required health endpoints and will cause the chart to fail rendering.

## Features

### 1. Health preset for ledger and tracer components

The chart now uses a centralized health preset system from the `lerian-common-helm` dependency (upgraded from `2.3.0` to `2.6.0`). This preset automatically configures probes, health ports, shutdown drain delays, termination grace periods, rollout strategies, and PodDisruptionBudgets based on the component's runtime stack.

| Component | v10.2.1 | v10.3.0 |
|-----------|---------|---------|
| lerian-common-helm dependency | 2.3.0 | 2.6.0 |
| Health preset configuration | Not available | `ledger.health` and `tracer.health` |

The health preset is configured via a new `health` block under each component:

```yaml
ledger:
  health:
    stack: go

tracer:
  health:
    stack: go
```

| Field | Default | Description |
|-------|---------|-------------|
| `health.stack` | `go` | Runtime stack of the image. Set to `go` for Midaz components that serve `/health` and `/readyz` on port 8099 from lib-commons. |

The preset automatically derives:

- **Probes:** startup, liveness, and readiness probes targeting the health port
- **Health port:** `HEALTH_PORT=8099` environment variable and container port
- **Shutdown drain:** `SHUTDOWN_DRAIN_DELAY` environment variable (15 seconds for Go services)
- **Termination grace period:** calculated based on drain delay and shutdown budget
- **Rollout strategy:** `RollingUpdate` with `maxSurge: 25%` and `maxUnavailable: 0` for zero-downtime deployments
- **PodDisruptionBudget:** `maxUnavailable: 1` to maintain availability during voluntary disruptions, plus `unhealthyPodEvictionPolicy: AlwaysAllow`

> **Note:** The health preset owns these configuration fields. Manual overrides via `readinessProbe`, `livenessProbe`, `terminationGracePeriodSeconds`, `deploymentUpdate`, or `pdb.maxUnavailable`/`pdb.minAvailable` will cause the chart to fail rendering with a clear error message.

### 2. Automatic startup probe configuration

The health preset now configures a startup probe for both ledger and tracer components. The startup probe allows the application up to 5 minutes to become ready on first boot, protecting slow-starting pods from being killed prematurely.

**Startup probe configuration (derived by preset):**

```yaml
startupProbe:
  httpGet:
    path: /health
    port: health
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 60  # 60 * 5s = 5 minutes
```

Once the startup probe succeeds, the liveness and readiness probes take over with their normal failure thresholds.

### 3. Dedicated health port on 8099

The ledger and tracer Deployments now expose a dedicated `health` port on `8099` for health check endpoints. This port is automatically added to the container ports and published on the Service (for `ClusterIP` type only).

**Container ports (ledger and tracer):**

```yaml
ports:
  - name: http
    containerPort: 3002  # or 4020 for tracer
    protocol: TCP
  - name: health
    containerPort: 8099
    protocol: TCP
```

**Service ports (ledger and tracer, ClusterIP only):**

```yaml
ports:
  - port: 3002  # or 4020 for tracer
    targetPort: http
    protocol: TCP
    name: http
  - port: 8099
    targetPort: 8099
    protocol: TCP
    name: health
```

**Environment variable:**

```yaml
env:
  - name: HEALTH_PORT
    value: "8099"
```

> **Note:** The health port is only published on the Service when `service.type` is `ClusterIP`. For `LoadBalancer` or `NodePort` services, the health port is not exposed externally.

### 4. Simplified RabbitMQ configuration

The ledger ConfigMap template has been simplified to remove unused RabbitMQ management API configuration. The ledger application no longer performs health checks against the RabbitMQ management API, so the related environment variables have been removed.

| Variable | v10.2.1 | v10.3.0 |
|----------|---------|---------|
| `RABBITMQ_PROTOCOL` | Set (default `http`) | Removed |
| `RABBITMQ_PORT_AMQP` | Set (default `15672`) | Removed |
| `RABBITMQ_HEALTH_CHECK_URL` | Set (derived from protocol/host/port) | Removed |

**Before (v10.2.1):**

```yaml
data:
  RABBITMQ_URI: "amqp"
  RABBITMQ_PROTOCOL: "http"
  RABBITMQ_HOST: "midaz-rabbitmq"
  RABBITMQ_PORT_HOST: "5672"
  RABBITMQ_PORT_AMQP: "15672"
  RABBITMQ_HEALTH_CHECK_URL: "http://midaz-rabbitmq:15672"
```

**After (v10.3.0):**

```yaml
data:
  RABBITMQ_URI: "amqp"
  RABBITMQ_HOST: "midaz-rabbitmq"
  RABBITMQ_PORT_HOST: "5672"
```

> **Note:** The `RABBITMQ_PORT_HOST` variable now only represents the AMQP transport port (default `5672`). The management API port is no longer configured or used by the ledger.

### 5. Tracer readiness probe configuration update

The tracer ConfigMap template has been updated to remove the `READYZ_DRAIN_GRACE_SECONDS` environment variable. The shutdown drain delay is now managed by the health preset via `SHUTDOWN_DRAIN_DELAY`, and the readiness probe no longer needs a separate drain grace configuration.

| Variable | v10.2.1 | v10.3.0 |
|----------|---------|---------|
| `READYZ_DRAIN_GRACE_SECONDS` | Set (default `12`) | Removed |
| `READYZ_CACHE_STALENESS_THRESHOLD_SECONDS` | Set (default `300`) | Set (default `300`) |

**Before (v10.2.1):**

```yaml
data:
  READYZ_DRAIN_GRACE_SECONDS: "12"
  READYZ_CACHE_STALENESS_THRESHOLD_SECONDS: "300"
```

**After (v10.3.0):**

```yaml
data:
  READYZ_CACHE_STALENESS_THRESHOLD_SECONDS: "300"
```

The comment in the ConfigMap template has been updated to clarify that `READYZ_CACHE_STALENESS_THRESHOLD_SECONDS` controls the rule-cache staleness threshold that `/readyz` tolerates (reported as degraded, but never returns a 503).

## Breaking Changes

### 1. Removed manual probe configuration fields

The `readinessProbe` and `livenessProbe` configuration blocks under `ledger` and `tracer` have been removed. These fields are now owned by the health preset and cannot be overridden manually.

| Field | v10.2.1 | v10.3.0 |
|-------|---------|---------|
| `ledger.readinessProbe` | Supported (manual override) | Removed (owned by health preset) |
| `ledger.livenessProbe` | Supported (manual override) | Removed (owned by health preset) |
| `tracer.readinessProbe` | Supported (manual override) | Removed (owned by health preset) |
| `tracer.livenessProbe` | Supported (manual override) | Removed (owned by health preset) |

**Before (v10.2.1):**

```yaml
ledger:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 16
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: /health
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 3
    successThreshold: 1
    failureThreshold: 3
```

**After (v10.3.0):**

```yaml
ledger:
  health:
    stack: go
  # readinessProbe and livenessProbe are removed; probes are derived by the health preset
```

If you attempt to set these fields in v10.3.0, the chart fails to render; remove them.

### 2. Removed manual PDB and deployment strategy fields

The `pdb.maxUnavailable`, `pdb.minAvailable`, and `deploymentUpdate` configuration blocks under `ledger` and `tracer` have been removed. These fields are now owned by the health preset and cannot be overridden manually.

| Field | v10.2.1 | v10.3.0 |
|-------|---------|---------|
| `ledger.pdb.maxUnavailable` | Supported (default `1`) | Removed (owned by health preset) |
| `ledger.pdb.minAvailable` | Supported (manual override) | Removed (owned by health preset) |
| `ledger.deploymentUpdate` | Supported (manual override) | Removed (owned by health preset) |
| `tracer.pdb.maxUnavailable` | Supported (default `1`) | Removed (owned by health preset) |
| `tracer.pdb.minAvailable` | Supported (manual override) | Removed (owned by health preset) |
| `tracer.deploymentUpdate` | Supported (manual override) | Removed (owned by health preset) |

**Before (v10.2.1):**

```yaml
ledger:
  pdb:
    enabled: true
    maxUnavailable: 1
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 100%
    maxUnavailable: 0
```

**After (v10.3.0):**

```yaml
ledger:
  pdb:
    enabled: true
    # maxUnavailable and minAvailable are removed; PDB spec is derived by the health preset
  # deploymentUpdate is removed; rollout strategy is derived by the health preset
```

If you attempt to set `pdb.maxUnavailable`, `pdb.minAvailable`, or `deploymentUpdate` in v10.3.0, the chart will fail to render with the following error:

```
midaz: ledger.pdb.maxUnavailable is owned by the health preset (PDB maxUnavailable 1); remove it
```

or

```
midaz: ledger.deploymentUpdate is owned by the health preset (RollingUpdate); remove it
```

### 3. Removed manual termination grace period configuration

The `terminationGracePeriodSeconds` field under `ledger` and `tracer` has been removed. This value is now calculated by the health preset based on the shutdown drain delay and shutdown budget.

| Field | v10.2.1 | v10.3.0 |
|-------|---------|---------|
| `ledger.terminationGracePeriodSeconds` | Supported (default `72`) | Removed (owned by health preset) |
| `tracer.terminationGracePeriodSeconds` | Supported (default `55`) | Removed (owned by health preset) |

**Before (v10.2.1):**

```yaml
ledger:
  terminationGracePeriodSeconds: 72

tracer:
  terminationGracePeriodSeconds: 55
```

**After (v10.3.0):**

```yaml
ledger:
  health:
    stack: go
  # terminationGracePeriodSeconds is removed; value is derived by the health preset

tracer:
  health:
    stack: go
  # terminationGracePeriodSeconds is removed; value is derived by the health preset
```

The health preset calculates the termination grace period as:

```
terminationGracePeriodSeconds = SHUTDOWN_DRAIN_DELAY + shutdown_budget + margin
```

For `stack: go` with the defaults, this results in `55` seconds (15s drain + 30s shutdown budget + 10s margin). The ledger value drops from `72` to `55`.

### 4. Removed manual shutdown drain delay configuration

The `SHUTDOWN_DRAIN_DELAY` environment variable is no longer set manually in the Deployment templates. It is now managed by the health preset and injected automatically.

| Variable | v10.2.1 | v10.3.0 |
|----------|---------|---------|
| `SHUTDOWN_DRAIN_DELAY` (ledger) | Set manually (`15s`) | Set by health preset (`15s`) |
| `SHUTDOWN_DRAIN_DELAY` (tracer) | Set manually (`15s`) | Set by health preset (`15s`) |

**Before (v10.2.1):**

```yaml
env:
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
```

**After (v10.3.0):**

```yaml
env:
  - name: HEALTH_PORT
    value: "8099"
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
  - name: SHUTDOWN_TIMEOUT
    value: "30s"
```

The value is still `15s` for Go services, but it is now derived by the health preset and cannot be overridden manually. The preset also sets the new `SHUTDOWN_TIMEOUT` (`30s` by default); `ledger.health.shutdownSeconds` tunes it.

### 5. Removed RabbitMQ management API configuration

The ledger ConfigMap no longer includes RabbitMQ management API configuration. The following environment variables have been removed:

| Variable | v10.2.1 | v10.3.0 |
|----------|---------|---------|
| `RABBITMQ_PROTOCOL` | Set (default `http`) | Removed |
| `RABBITMQ_PORT_AMQP` | Set (default `15672`) | Removed |
| `RABBITMQ_HEALTH_CHECK_URL` | Set (derived) | Removed |

If you set `RABBITMQ_HEALTH_CHECK_URL` in `ledger.configmap`, v10.3.0 fails schema validation; remove it. `RABBITMQ_PROTOCOL` and `RABBITMQ_PORT_AMQP` are still accepted but no longer rendered. The ledger application no longer uses them.

### 6. Removed tracer readiness drain grace configuration

The tracer ConfigMap no longer includes the `READYZ_DRAIN_GRACE_SECONDS` environment variable. This setting is replaced by the health preset's `SHUTDOWN_DRAIN_DELAY`.

| Variable | v10.2.1 | v10.3.0 |
|----------|---------|---------|
| `READYZ_DRAIN_GRACE_SECONDS` | Set (default `12`) | Removed |

If you set `READYZ_DRAIN_GRACE_SECONDS` in `tracer.configmap`, v10.3.0 fails schema validation; remove it. The tracer application now uses `SHUTDOWN_DRAIN_DELAY` for shutdown coordination.

### 7. `/readyz` no longer served on the main ports

The ledger and tracer images no longer serve `/readyz` on their main ports (`3002`, `4020`); `/readyz` is served only on the internal health port `8099`. If an Ingress or load-balancer health check (for example `alb.ingress.kubernetes.io/healthcheck-path`) or a monitor uses `/readyz` on the main port, change it to `/health`.

### 8. Ledger and tracer require `LICENSE_KEY`

The `4.5.0-beta.94` ledger and tracer images refuse to boot when `LICENSE_KEY` is empty; the `4.4.0` images did not read it. The chart does not check the value: it writes `LICENSE_KEY` into the service Secret only when `ledger.secrets.LICENSE_KEY` or `tracer.secrets.LICENSE_KEY` is set, so a release without it renders and the pods fail at boot. Set it before you upgrade (the tracer key only when `tracer.enabled` is true):

```yaml
ledger:
  secrets:
    LICENSE_KEY: "<your-license-key>"

tracer:
  secrets:
    LICENSE_KEY: "<your-license-key>"
```

With `useExistingSecret: true`, add the `LICENSE_KEY` key to the existing Secret instead.

## Configuration Reference

### 1. New health preset configuration

The health preset is configured via a new `health` block under each component.

```yaml
ledger:
  health:
    stack: go

tracer:
  health:
    stack: go
```

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `health.stack` | No | `go` | Runtime stack of the image. Set to `go` for Midaz components that serve `/health` and `/readyz` on port 8099 from lib-commons. |

The preset derives the following configuration automatically:

| Derived Field | Value (Go stack) | Description |
|---------------|------------------|-------------|
| `HEALTH_PORT` | `8099` | Port where `/health` and `/readyz` endpoints are served |
| `SHUTDOWN_DRAIN_DELAY` | `15s` | Delay before shutdown begins, allowing in-flight requests to complete |
| `terminationGracePeriodSeconds` | `55` | Kubernetes grace period before SIGKILL (15s drain + 30s shutdown + 10s margin) |
| `startupProbe.failureThreshold` | `60` | Allows up to 5 minutes for first boot (60 * 5s) |
| `livenessProbe.failureThreshold` | `3` | Kills pod after 3 consecutive failures (30 seconds) |
| `readinessProbe.failureThreshold` | `3` | Removes pod from Service after 3 consecutive failures (15 seconds) |
| `deploymentUpdate.type` | `RollingUpdate` | Rolling update strategy |
| `deploymentUpdate.maxSurge` | `25%` | Extra pods allowed during rollout |
| `deploymentUpdate.maxUnavailable` | `0` | Ensures zero-downtime rollouts |
| `pdb.maxUnavailable` | `1` | Allows one pod to be unavailable during voluntary disruptions |

### 2. Minimum image version requirement

The health preset requires images that serve `/health` and `/readyz` on port 8099. For Midaz components, the minimum supported image version is `4.5.0-beta.94`.

| Component | Minimum Image Version |
|-----------|-----------------------|
| ledger | 4.5.0-beta.94 |
| tracer | 4.5.0-beta.94 |

If you override `ledger.image.tag` or `tracer.image.tag` with a version older than `4.5.0-beta.94`, the chart will fail to render with the following error:

```
lerian-common.health: ledger: image.tag 4.4.0 is below 4.5.0-beta.94, the first image that serves the health port
```

## Migration Steps

### 1. Remove deprecated probe overrides

If you have overridden `readinessProbe` or `livenessProbe` under `ledger` or `tracer`, remove these blocks from your `values.yaml`. The health preset now owns probe configuration.

**Before (v10.2.1):**

```yaml
ledger:
  readinessProbe:
    path: /readyz
    timeoutSeconds: 20
  livenessProbe:
    path: /health
    periodSeconds: 15
```

**After (v10.3.0):**

```yaml
ledger:
  health:
    stack: go
  # readinessProbe and livenessProbe removed
```

### 2. Remove deprecated PDB and deployment strategy overrides

If you have overridden `pdb.maxUnavailable`, `pdb.minAvailable`, or `deploymentUpdate` under `ledger` or `tracer`, remove these fields from your `values.yaml`. The health preset now owns these settings.

**Before (v10.2.1):**

```yaml
ledger:
  pdb:
    enabled: true
    maxUnavailable: 1
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 100%
    maxUnavailable: 0
```

**After (v10.3.0):**

```yaml
ledger:
  pdb:
    enabled: true
    # maxUnavailable removed; derived by health preset
  # deploymentUpdate removed; derived by health preset
```

If you attempt to set these fields, the chart will fail to render with a clear error message.

### 3. Remove deprecated termination grace period overrides

If you have overridden `terminationGracePeriodSeconds` under `ledger` or `tracer`, remove this field from your `values.yaml`. The health preset now calculates this value automatically.

**Before (v10.2.1):**

```yaml
ledger:
  terminationGracePeriodSeconds: 72

tracer:
  terminationGracePeriodSeconds: 55
```

**After (v10.3.0):**

```yaml
ledger:
  health:
    stack: go
  # terminationGracePeriodSeconds removed; derived by health preset

tracer:
  health:
    stack: go
  # terminationGracePeriodSeconds removed; derived by health preset
```

### 4. Remove deprecated RabbitMQ management API configuration

If you have overridden `RABBITMQ_PROTOCOL`, `RABBITMQ_PORT_AMQP`, or `RABBITMQ_HEALTH_CHECK_URL` in `ledger.configmap`, remove these fields from your `values.yaml`. The ledger application no longer uses them.

**Before (v10.2.1):**

```yaml
ledger:
  configmap:
    RABBITMQ_PROTOCOL: "https"
    RABBITMQ_PORT_AMQP: "443"
    RABBITMQ_HEALTH_CHECK_URL: "https://my-broker.example.com"
```

### 5. Remove deprecated tracer readiness configuration

If you have overridden `READYZ_DRAIN_GRACE_SECONDS` in `tracer.configmap`, remove this field from your `values.yaml`. The tracer application now uses `SHUTDOWN_DRAIN_DELAY` (managed by the health preset).

**Before (v10.2.1):**

```yaml
tracer:
  configmap:
    READYZ_DRAIN_GRACE_SECONDS: "20"
```

### 6. Verify image tags meet minimum requirements

Ensure that `ledger.image.tag` and `tracer.image.tag` are set to `4.5.0-beta.94` or later. If you have overridden these tags with older versions, update them or remove the overrides to use the chart defaults.

**Check your current configuration:**

```bash
helm get values midaz -n midaz
```

**If you see:**

```yaml
ledger:
  image:
    tag: "4.4.0"
```

**Update to:**

```yaml
ledger:
  image:
    tag: "4.5.0-beta.94"
```

### 7. Set the license key

Set `ledger.secrets.LICENSE_KEY`, and `tracer.secrets.LICENSE_KEY` when the tracer is enabled, as described in [Breaking change 8](#8-ledger-and-tracer-require-license_key). Without it the new images refuse to boot.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.0 -n midaz
```
