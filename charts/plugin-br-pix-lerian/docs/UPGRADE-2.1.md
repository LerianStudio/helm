<!-- {% raw %} -->
# Helm Upgrade from v2.0.5 to v2.1.0

## Topics

- **[Features](#features)**
  - [1. Health Preset Migration](#1-health-preset-migration)
  - [2. Application Version Update](#2-application-version-update)
  - [3. Library Chart Dependency Update](#3-library-chart-dependency-update)
  - [4. Ingress Path Validation](#4-ingress-path-validation)
  - [5. VSync Gate TTL Configuration](#5-vsync-gate-ttl-configuration)
  - [6. Pixauto Ingress Route Change](#6-pixauto-ingress-route-change)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Health Preset Migration

**What changed:**

All components now use the `lerian-common.health` preset for health probes, graceful shutdown, and port configuration. The previous `readinessProbe` and `livenessProbe` configuration blocks have been replaced with a single `health` block that sets the stack type.

| Setting | v2.0.5 | v2.1.0 |
|---------|--------|--------|
| `<component>.readinessProbe` | `{ path: "/path/readyz" }` | (removed) |
| `<component>.livenessProbe` | `{ path: "/path/health" }` | (removed) |
| `<component>.health` | (not present) | `{ stack: "go" }` |

**Why it matters:**

The health preset standardizes probe configuration, graceful shutdown timing, and health port management across all components. The preset:

- Configures probes on `HEALTH_PORT` 8099 with paths `/health` (liveness) and `/readyz` (readiness)
- Sets drain delay to 15 seconds, shutdown timeout to 30 seconds, and grace period to 55 seconds
- Adds a startup probe to prevent premature liveness failures during slow boot
- Injects `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY`, and `SHUTDOWN_TIMEOUT` environment variables
- Adds a `health` service port (8099) alongside the main application port

**The preset owns these configuration keys and will fail the render if you set them manually:**

- `livenessProbe`
- `readinessProbe`
- `terminationGracePeriodSeconds`
- `extraEnvVars.HEALTH_PORT`
- `extraEnvVars.SHUTDOWN_DRAIN_DELAY`
- `extraEnvVars.SHUTDOWN_TIMEOUT`

**How to handle it:**

#### If you have not customized probe configuration

No action is required. The health preset will automatically configure probes with the standard settings.

#### If you have customized readinessProbe or livenessProbe

Remove the `readinessProbe` and `livenessProbe` blocks from your values and replace them with the `health` block:

**Before (v2.0.5):**

```yaml
spi:
  readinessProbe:
    path: "/spi/readyz"
    initialDelaySeconds: 15
    periodSeconds: 10
  livenessProbe:
    path: "/spi/health"
    initialDelaySeconds: 10
    periodSeconds: 20
```

**After (v2.1.0):**

```yaml
spi:
  health:
    stack: go
```

> **Important:** The health preset does not support custom probe paths, delays, or periods. If your deployment requires non-standard probe configuration, you must override the entire probe definition in the rendered manifests or contact the chart maintainers to discuss your use case.

#### If you have set HEALTH_PORT or SHUTDOWN_* in extraEnvVars

Remove these keys from `extraEnvVars`. The health preset owns them and will fail the render if they are present:

**Before (v2.0.5):**

```yaml
spi:
  extraEnvVars:
    HEALTH_PORT: "9090"
    SHUTDOWN_DRAIN_DELAY: "20"
```

**After (v2.1.0):**

```yaml
spi:
  health:
    stack: go
  # HEALTH_PORT and SHUTDOWN_* are now managed by the health preset
```

> **Warning:** The render will fail with an error message if you attempt to set `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY`, or `SHUTDOWN_TIMEOUT` in `extraEnvVars` while using the health preset.

**Affected components:**

- `spi`
- `spiSystemplane`
- `adapterProviderMock`
- `dictHub`
- `dictHubVsync`
- `dictProxy`
- `dictSystemplane`
- `cobHub`
- `cobProxy`
- `cobSystemplane`
- `adapterLerian`
- `adapterLerianSystemplane`
- `pixauto`
- `pixautoSystemplane`

**Probe configuration details:**

The health preset configures the following probes:

**Startup probe:**

```yaml
startupProbe:
  httpGet:
    path: /health
    port: health
  initialDelaySeconds: 0
  periodSeconds: 2
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 30
```

**Liveness probe:**

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: health
  initialDelaySeconds: 0
  periodSeconds: 10
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3
```

**Readiness probe:**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: health
  initialDelaySeconds: 0
  periodSeconds: 5
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3
```

**Environment variables:**

```yaml
env:
  - name: HEALTH_PORT
    value: "8099"
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15"
  - name: SHUTDOWN_TIMEOUT
    value: "30"
```

**Service ports:**

The health preset adds a `health` port to each component's Service:

```yaml
ports:
  - name: http
    port: 4000
    targetPort: http
    protocol: TCP
  - name: health
    port: 8099
    targetPort: health
    protocol: TCP
```

> **Note:** The health port is not exposed via Ingress. It is used only for Kubernetes probes and internal monitoring.

**Minimum image version:**

The health preset requires application version 1.3.0 or later. The chart will fail the render if the effective image tag (component tag or `Chart.appVersion`) is earlier than 1.3.0.

### 2. Application Version Update

**What changed:**

The `appVersion` field in `Chart.yaml` has been updated from `1.1.0` to `1.3.0`.

| Setting | v2.0.5 | v2.1.0 |
|---------|--------|--------|
| `appVersion` | `1.1.0` | `1.3.0` |

**Why it matters:**

The application version determines the default image tag for all components that do not specify an explicit `image.tag`. Version 1.3.0 introduces the health port and graceful shutdown features required by the health preset.

**How to handle it:**

#### If you use the default image tags

No action is required. All components will automatically use version 1.3.0 images on upgrade.

#### If you pin component image tags

Ensure that all pinned tags are version 1.3.0 or later. The health preset will fail the render if a component uses an image earlier than 1.3.0.

**Before (v2.0.5):**

```yaml
spi:
  image:
    tag: "1.1.0"
```

**After (v2.1.0):**

```yaml
spi:
  image:
    tag: "1.3.0"
```

> **Important:** Pre-release versions (e.g., `1.3.0-rc.1`) are refused by the health preset. Only stable releases (1.3.0 or later) are supported.

### 3. Library Chart Dependency Update

**What changed:**

The `lerian-common-helm` library chart dependency has been updated from version `2.1.2` to `2.6.0`.

| Setting | v2.0.5 | v2.1.0 |
|---------|--------|--------|
| `dependencies[0].version` | `2.1.2` | `2.6.0` |

**Why it matters:**

The library chart provides shared workload fragments (Service, HPA, ServiceAccount, scheduling helpers) and the new `lerian-common.health` preset used by all components. Version 2.6.0 introduces the health preset and related template helpers.

**How to handle it:**

No action is required. Helm will automatically fetch the updated library chart from the OCI registry during the upgrade.

**Before (v2.0.5) Chart.yaml:**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.1.2"
    repository: "oci://ghcr.io/lerianstudio"
```

**After (v2.1.0) Chart.yaml:**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.6.0"
    repository: "oci://ghcr.io/lerianstudio"
```

### 4. Ingress Path Validation

**What changed:**

The chart now validates Ingress paths to prevent routing to reserved health and metrics segments. The new `plugin-br-pix-lerian.validateIngressPath` helper fails the render if an Ingress path contains `/readyz` or `/metrics` as a path segment.

**Why it matters:**

With the health preset, readiness probes now target port 8099 (`/readyz`), which is not exposed via Ingress. Routing external traffic to `/readyz` or `/metrics` would fail (404) and could expose internal monitoring endpoints.

**How to handle it:**

#### If you have not customized Ingress paths

No action is required. The default Ingress routes do not contain reserved segments.

#### If you have customized Ingress paths

Review your custom Ingress routes and remove any paths that contain `/readyz` or `/metrics`:

**Before (v2.0.5):**

```yaml
appsIngress:
  routes:
    - path: /spi/readyz
      pathType: Exact
      component: spi
      serviceName: spi
```

**After (v2.1.0):**

```yaml
appsIngress:
  routes:
    # Remove /readyz route — readiness is now on port 8099, not exposed via Ingress
    - path: /spi
      pathType: Prefix
      component: spi
      serviceName: spi
```

> **Warning:** The render will fail with an error message if any Ingress path contains `/readyz` or `/metrics` as a path segment (e.g., `/spi/readyz`, `/metrics`, `/app/metrics/export`).

**Validation logic:**

The chart uses a regular expression to detect reserved segments:

```yaml
{{- if regexMatch "(^|/)(readyz|metrics)(/|$)" .path -}}
{{- fail (printf "plugin-br-pix-lerian: ingress path %q contains a reserved health or metrics segment" .) -}}
{{- end -}}
```

### 5. VSync Gate TTL Configuration

**What changed:**

The `dictHubVsync` component now documents the `VSYNC_GATE_TTL_SEC` configuration key in the ConfigMap comments. This key has no chart default; when unset, VSync uses the application default of 57600 seconds (16 hours).

**Why it matters:**

The gate TTL controls how long VSync waits before retrying a failed synchronization attempt. The application default (16 hours) is suitable for most deployments, but operators can now override it if needed.

**How to handle it:**

#### If you do not need to customize the gate TTL

No action is required. VSync will use the application default of 57600 seconds.

#### If you need to customize the gate TTL

Set `VSYNC_GATE_TTL_SEC` in the `dictHubVsync.configmap` block:

```yaml
dictHubVsync:
  configmap:
    VSYNC_GATE_TTL_SEC: "28800"  # 8 hours
```

**After (v2.1.0) values.yaml:**

```yaml
dictHubVsync:
  # -- Application config (ConfigMap). Each KEY is rendered in
  #    templates/dict-hub-vsync/configmap.yaml as `$cm.<KEY> | default "<value>"`.
  #    Set a KEY here ONLY to override a default; un-enumerated keys pass
  #    through too. Credentials are NOT configmap -- see `secrets` below.
  #    VSYNC_GATE_TTL_SEC has no chart default. When unset, VSync uses the
  #    application default of 57600 seconds.
  configmap: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `dictHubVsync.configmap.VSYNC_GATE_TTL_SEC` | `57600` (application default) | Gate TTL in seconds — how long VSync waits before retrying a failed synchronization attempt |

### 6. Pixauto Ingress Route Change

**What changed:**

The `appsIngress` routes for the `pixauto` component have been updated. The `/pixauto/readyz` route (Exact) has been replaced with `/pixauto/health` (Exact).

| Setting | v2.0.5 | v2.1.0 |
|---------|--------|--------|
| `appsIngress.routes[].path` | `/pixauto/readyz` | `/pixauto/health` |

**Why it matters:**

With the health preset, readiness probes now target port 8099 (`/readyz`), which is not exposed via Ingress. The liveness probe remains on the main port (`/health`), so the Ingress route has been updated to target the liveness endpoint instead.

**How to handle it:**

#### If you have not customized the pixauto Ingress routes

No action is required. The chart will automatically update the route on upgrade.

#### If you have customized the pixauto Ingress routes

Update your custom routes to target `/pixauto/health` instead of `/pixauto/readyz`:

**Before (v2.0.5):**

```yaml
appsIngress:
  routes:
    - path: /pixauto/readyz
      pathType: Exact
      component: pixauto
      serviceName: pixauto
```

**After (v2.1.0):**

```yaml
appsIngress:
  routes:
    - path: /pixauto/health
      pathType: Exact
      component: pixauto
      serviceName: pixauto
```

> **Note:** The `/pixauto/health` route is kept as an Exact route for dashboard integrations (e.g., gethomepage.dev/href annotations). The readiness endpoint (`/readyz`) is now on port 8099 and is not exposed via Ingress.

**After (v2.1.0) values.yaml:**

```yaml
appsIngress:
  routes:
    # /pixauto: Prefix route for the main API, the streaming manifest, and the
    # notification-outbox reprocess endpoint, which the app mounts at
    # {prefix}/v1/streaming/manifest.
    #
    # /pixauto/health: Exact liveness route on the main port; readiness is on 8099,
    # which no Ingress routes to.
    #
    # /pixauto/internal/v1/* is deliberately absent and must stay absent.
    # templates/ingress-apps.yaml fails the render if a route reintroduces it.
    - path: /pixauto
      pathType: Prefix
      component: pixauto
      serviceName: pixauto
    - path: /pixauto/health
      pathType: Exact
      component: pixauto
      serviceName: pixauto
```

## Configuration Reference

### Health Preset Configuration

All components now support the `health` configuration block:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `<component>.health.stack` | string | `"go"` | Stack type for the health preset (currently only `"go"` is supported) |

**Example:**

```yaml
spi:
  health:
    stack: go
```

**Owned fields (do not set manually):**

The health preset owns the following fields and will fail the render if you set them:

- `<component>.livenessProbe`
- `<component>.readinessProbe`
- `<component>.terminationGracePeriodSeconds`
- `<component>.extraEnvVars.HEALTH_PORT`
- `<component>.extraEnvVars.SHUTDOWN_DRAIN_DELAY`
- `<component>.extraEnvVars.SHUTDOWN_TIMEOUT`

### New Environment Variables

The health preset injects the following environment variables into all components:

| Variable | Value | Description |
|----------|-------|-------------|
| `HEALTH_PORT` | `8099` | Port for health and readiness probes |
| `SHUTDOWN_DRAIN_DELAY` | `15` | Seconds to wait after receiving SIGTERM before starting shutdown (allows load balancers to deregister the pod) |
| `SHUTDOWN_TIMEOUT` | `30` | Seconds to wait for graceful shutdown before forcing termination |

### Service Port Changes

All component Services now include a `health` port:

| Port Name | Port | Target Port | Protocol | Description |
|-----------|------|-------------|----------|-------------|
| `http` | (component-specific) | `http` | TCP | Main application port |
| `health` | `8099` | `health` | TCP | Health and readiness probe port (not exposed via Ingress) |

## Preview changes before upgrading

```bash
helm diff upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.1.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.1.0
```
<!-- {% endraw %} -->
