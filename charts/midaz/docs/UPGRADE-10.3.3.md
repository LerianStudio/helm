<!-- {% raw %} -->
# Helm Upgrade from v10.3.2 to v10.3.3

## Topics

- **[Application Version Rollback](#application-version-rollback)**
  - [1. Midaz application rollback to stable 4.4.0](#1-midaz-application-rollback-to-stable-440)
  - [2. Image tag updates](#2-image-tag-updates)
- **[Health Preset Backward Compatibility](#health-preset-backward-compatibility)**
  - [1. Legacy health layout for 4.4.x images](#1-legacy-health-layout-for-44x-images)
  - [2. New environment variables for legacy images](#2-new-environment-variables-for-legacy-images)
  - [3. Template changes for conditional health preset](#3-template-changes-for-conditional-health-preset)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Rollback

### 1. Midaz application rollback to stable 4.4.0

This patch release rolls back the Midaz application from the beta version `4.5.0-beta.94` to the stable version `4.4.0`. This is a stability-focused change that returns the chart to the last production-ready release.

| Component | v10.3.2 | v10.3.3 |
|-----------|---------|---------|
| appVersion | 4.5.0-beta.94 | 4.4.0 |

The 4.4.0 release is the stable baseline that does not include the health preset infrastructure introduced in 4.5.0-beta.94. Operators who need the beta features can explicitly override the image tags (see [Image tag updates](#2-image-tag-updates) below).

### 2. Image tag updates

The following container image tags have been rolled back to align with the stable application version:

| Component | v10.3.2 | v10.3.3 |
|-----------|---------|---------|
| ledger.image.tag | 4.5.0-beta.94 | 4.4.0 |
| tracer.image.tag | 4.5.0-beta.94 | 4.4.0 |

**Before (v10.3.2):**

```yaml
ledger:
  image:
    tag: "4.5.0-beta.94"

tracer:
  image:
    tag: "4.5.0-beta.94"
```

**After (v10.3.3):**

```yaml
ledger:
  image:
    tag: "4.4.0"

tracer:
  image:
    tag: "4.4.0"
```

#### Operational Impact

This is a rollback to a stable release with no breaking changes for operators using the default configuration. The upgrade will:

- Pull the stable `4.4.0` container images for the `ledger` and `tracer` components
- Perform a rolling update of the affected deployments
- Automatically switch to the legacy health layout (see [Health Preset Backward Compatibility](#health-preset-backward-compatibility) below)

> **Note:** If you have explicitly overridden `ledger.image.tag` or `tracer.image.tag` to `4.5.0-beta.94` in your `values.yaml`, you can keep that override to continue using the beta version. The chart now supports both the stable 4.4.x layout and the beta 4.5.x health preset.

#### Opting into the beta version

To continue using the 4.5.0-beta.94 features (health preset, HEALTH_PORT 8099, preset probes and PDB), override the image tags:

```yaml
ledger:
  image:
    tag: "4.5.0-beta.94"

tracer:
  image:
    tag: "4.5.0-beta.94"
```

The chart will automatically detect the beta tag and enable the health preset behavior.

## Health Preset Backward Compatibility

### 1. Legacy health layout for 4.4.x images

Chart v10.3.3 introduces backward compatibility logic that automatically detects the image tag and applies the appropriate health configuration:

- **Images below `4.5.0-beta.94`** (including the new default `4.4.0`) use the **legacy health layout**: probes target the main HTTP port, no `HEALTH_PORT` environment variable is set, and the 4.4.x probe timings and rollout strategy are preserved.
- **Images at or above `4.5.0-beta.94`** use the **health preset**: probes target port 8099, `HEALTH_PORT=8099` is set, and the lerian-common.health preset owns probes, PDB, and rollout strategy.

| Image Tag | Health Layout | HEALTH_PORT | Probe Port | PDB/Rollout Ownership |
|-----------|---------------|-------------|------------|----------------------|
| 4.4.0 (default) | Legacy | (not set) | Main HTTP port | Operator-controlled via values |
| 4.5.0-beta.94+ | Preset | 8099 | 8099 | Preset-owned (operator override fails render) |

This detection is automatic and requires no operator action. The chart inspects the effective image tag (from `<component>.image.tag` or `Chart.appVersion`) and applies the correct layout.

#### What changed in the legacy layout

The legacy health layout for 4.4.x images preserves the following behavior:

**Ledger:**

- Liveness probe: `httpGet` on `http` port, path `/health`, initial delay 0s, period 10s, timeout 3s
- Readiness probe: `httpGet` on `http` port, path `/readyz`, initial delay 0s, period 10s, timeout 16s
- Termination grace period: 72s
- Shutdown drain delay: `SHUTDOWN_DRAIN_DELAY=15s` environment variable
- Rollout strategy: `RollingUpdate` with `maxSurge: 100%`, `maxUnavailable: 0`
- PDB: `maxUnavailable: 1` (or operator-specified `minAvailable`)

**Tracer:**

- Liveness probe: `httpGet` on main port, path `/health`, initial delay 15s, period 20s, timeout 5s
- Readiness probe: `httpGet` on main port, path `/readyz`, initial delay 5s, period 10s, timeout 5s
- Termination grace period: 55s
- Shutdown drain delay: `SHUTDOWN_DRAIN_DELAY=15s` environment variable
- Rollout strategy: `RollingUpdate` with `maxSurge: 1`, `maxUnavailable: 0`
- PDB: `maxUnavailable: 1` (or operator-specified `minAvailable`)

> **Important:** When using the legacy layout (4.4.x images), the operator retains full control over `livenessProbe`, `readinessProbe`, `terminationGracePeriodSeconds`, `deploymentUpdate`, and `pdb` fields in `values.yaml`. These are **not** owned by the health preset.

### 2. New environment variables for legacy images

The chart now conditionally renders additional environment variables for images below `4.5.0-beta.94`:

#### Ledger legacy variables

The ledger ConfigMap now includes RabbitMQ management API configuration for the `/readyz` health check when the image tag is below `4.5.0-beta.94`:

| Variable | Default | Description |
|----------|---------|-------------|
| `RABBITMQ_PROTOCOL` | `http` | URL scheme for the RabbitMQ management API |
| `RABBITMQ_PORT_AMQP` | `15672` | Management API port |
| `RABBITMQ_HEALTH_CHECK_URL` | `http://<host>:<port>` | Full management API URL (auto-constructed from protocol, host, and port) |

**Example (auto-constructed):**

```yaml
ledger:
  configmap:
    RABBITMQ_PROTOCOL: "http"
    RABBITMQ_PORT_AMQP: "15672"
    RABBITMQ_HOST: "midaz-rabbitmq"
    # RABBITMQ_HEALTH_CHECK_URL is auto-constructed as: http://midaz-rabbitmq:15672
```

**Example (explicit override):**

```yaml
ledger:
  configmap:
    RABBITMQ_HEALTH_CHECK_URL: "https://rabbitmq.external.example.com"
```

> **Note:** These variables are **only rendered** when the ledger image tag is below `4.5.0-beta.94`. Images at or above that version do not read them (the health preset uses port 8099 probes that do not call the RabbitMQ API).

#### Tracer legacy variables

The tracer ConfigMap now includes a drain grace period for the `/readyz` endpoint when the image tag is below `4.5.0-beta.94`:

| Variable | Default | Description |
|----------|---------|-------------|
| `READYZ_DRAIN_GRACE_SECONDS` | `12` | Seconds the `/readyz` endpoint waits before returning 503 after receiving SIGTERM |

**Example:**

```yaml
tracer:
  configmap:
    READYZ_DRAIN_GRACE_SECONDS: "12"
```

> **Note:** This variable is **only rendered** when the tracer image tag is below `4.5.0-beta.94`. Images at or above that version do not read it (the health preset uses the `SHUTDOWN_DRAIN_DELAY` environment variable from lerian-common.health instead).

### 3. Template changes for conditional health preset

The chart's `_helpers.tpl` now includes logic to detect the image tag and select the appropriate health layout:

**Before (v10.3.2):**

```yaml
{{- define "midaz-ledger.health" -}}
{{- include "midaz.presetOwned" (dict "name" "ledger" "component" .Values.ledger) -}}
{{- include "lerian-common.health" (dict "name" "ledger" "component" .Values.ledger "health" .Values.ledger.health "port" (int .Values.ledger.service.port) "minImage" (include "midaz.healthMinImage" .) "replicas" .Values.ledger.replicaCount "autoscaling" .Values.ledger.autoscaling) -}}
{{- end -}}
```

**After (v10.3.3):**

```yaml
{{- define "midaz-ledger.health" -}}
{{- if include "midaz.belowHealthMin" (dict "component" .Values.ledger "context" .) -}}
{{- include "midaz.healthLegacy" (dict "name" "ledger" "component" .Values.ledger) -}}
{{- else -}}
{{- include "midaz.presetOwned" (dict "name" "ledger" "component" .Values.ledger) -}}
{{- include "lerian-common.health" (dict "name" "ledger" "component" .Values.ledger "health" .Values.ledger.health "port" (int .Values.ledger.service.port) "minImage" (include "midaz.healthMinImage" .) "replicas" .Values.ledger.replicaCount "autoscaling" .Values.ledger.autoscaling) -}}
{{- end -}}
{{- end -}}
```

The new `midaz.belowHealthMin` helper performs a semantic version comparison:

- If the effective image tag is a valid SemVer below `4.5.0-beta.94`, it returns `"true"`
- Otherwise, it returns an empty string (falsy in Helm conditionals)

The new `midaz.healthLegacy` helper constructs the 4.4.x health layout (probes, ports, PDB, rollout strategy) from operator-supplied values, preserving the pre-10.3.2 behavior.

#### Operational Impact

This change is **fully backward compatible**. Operators using the default `4.4.0` image tag will see no functional difference from v10.3.2 — the chart automatically applies the legacy layout. Operators who have overridden the image tag to `4.5.0-beta.94` or higher will continue to use the health preset.

> **Warning:** The health preset validation (`midaz.presetOwned`) still applies when the image tag is at or above `4.5.0-beta.94`. Setting `pdb.minAvailable`, `pdb.maxUnavailable`, or `deploymentUpdate` in `values.yaml` will fail the render with a descriptive error. To override these fields, either downgrade to a 4.4.x image tag or remove the overrides and let the preset manage them.

## Migration Steps

This release requires **no migration steps** for operators using the default configuration. The chart automatically detects the image tag and applies the correct health layout.

### Optional: Continue using the beta version

If you want to keep using the `4.5.0-beta.94` features (health preset, HEALTH_PORT 8099, preset probes and PDB), override the image tags in your `values.yaml`:

```yaml
ledger:
  image:
    tag: "4.5.0-beta.94"

tracer:
  image:
    tag: "4.5.0-beta.94"
```

The chart will automatically enable the health preset behavior for these images.

### Optional: Customize legacy health configuration

If you are using the default `4.4.0` image tag and need to adjust the legacy health layout, you can override the following fields in `values.yaml`:

```yaml
ledger:
  livenessProbe:
    initialDelaySeconds: 5
    periodSeconds: 15
  readinessProbe:
    initialDelaySeconds: 10
    timeoutSeconds: 20
  terminationGracePeriodSeconds: 90
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: "50%"
    maxUnavailable: 1
  pdb:
    maxUnavailable: 2
```

> **Note:** These overrides are **only respected** when the image tag is below `4.5.0-beta.94`. For images at or above that version, the health preset owns these fields and operator overrides will fail the render.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.3.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.3.3
```
<!-- {% endraw %} -->
