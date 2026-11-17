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

For each enabled component, remove nonempty `livenessProbe`, `readinessProbe`, `startupProbe`, and `terminationGracePeriodSeconds` overrides. Remove `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY`, and `SHUTDOWN_TIMEOUT` from both `configmap` and `extraEnvVars`; those names are owned by the preset and are rejected there. Audit Secret-sourced duplicates too: explicit generated container environment entries take precedence over `envFrom`, so such duplicates must not be treated as effective tuning. Use `health.drainSeconds` and `health.shutdownSeconds` for supported shutdown tuning. Paths and probe timing are not configurable through the shipped Go preset. Do not treat editing rendered manifests as a durable Helm values migration.

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

> Probe paths and timings are not configurable through the shipped Go preset. Editing rendered manifests is not a durable values migration; use the supported shutdown tuning above and consult the maintainers for other requirements.

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

```yaml
startupProbe:
  failureThreshold: 60
  httpGet:
    path: /health
    port: health
  periodSeconds: 5
  timeoutSeconds: 3
livenessProbe:
  failureThreshold: 3
  httpGet:
    path: /health
    port: health
  periodSeconds: 10
  timeoutSeconds: 3
readinessProbe:
  failureThreshold: 3
  httpGet:
    path: /readyz
    port: health
  periodSeconds: 5
  timeoutSeconds: 3
```

**Environment variables:**

```yaml
env:
  - name: HEALTH_PORT
    value: "8099"
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
  - name: SHUTDOWN_TIMEOUT
    value: "30s"
```

**Service ports:**

The health preset adds a `health` port to each component's Service:

```yaml
ports:
  - name: http
    port: 4101 # spi; the main port is component-specific
    targetPort: http
    protocol: TCP
  - name: health
    port: 8099
    targetPort: 8099
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

Components without explicit image tag overrides select 1.3.0. First satisfy the values migration and database/recovery prerequisites below; this is not a no-action application upgrade.

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

> The chart compares SemVer-shaped effective image tags against 1.3.0 and rejects those below it, including 1.3.0 prereleases. It does not reject every prerelease or validate an arbitrary tag’s runtime capabilities. Use separately validated compatible images; passing this guard is not a runtime compatibility check.

### 3. Library Chart Dependency Update

**What changed:**

The `lerian-common-helm` library chart dependency has been updated from version `2.1.2` to `2.6.0`.

| Setting | v2.0.5 | v2.1.0 |
|---------|--------|--------|
| `dependencies[0].version` | `2.1.2` | `2.6.0` |

**Why it matters:**

The library chart provides shared workload fragments (Service, HPA, ServiceAccount, scheduling helpers) and the new `lerian-common.health` preset used by all components. Version 2.6.0 includes the health preset and related template helpers.

**How to handle it:**

The published OCI chart package already includes its dependencies, including lerian-common-helm 2.6.0. No separate dependency-fetch step is required for that packaged upgrade. For a local source chart, prepare dependencies from the committed Chart.lock in an isolated environment; do not update dependencies as part of this migration.

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

The chart rejects Ingress paths containing reserved `readyz` or `metrics` segments to prevent publishing those endpoints. Probe readiness uses the internal health port. This validation is a chart exposure rule, not proof that every rejected path returns 404 from the application.

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
{{- if regexMatch "(^|/)(readyz|metrics)(/|$)" . -}}
{{- fail (printf "plugin-br-pix-lerian: ingress path %q contains a reserved health or metrics segment" .) -}}
{{- end -}}
```

### 5. VSync Gate TTL Configuration

**What changed:**

Chart 2.0.5 emitted `VSYNC_GATE_TTL_SEC: "300"` in the VSync ConfigMap and `"3600"` in the DICT systemplane ConfigMap unless overridden. Chart 2.1.0 emits this key in those ConfigMaps only when explicitly configured. When no environment or persisted systemplane override supplies another effective value, application 1.3.0 uses 57600 seconds.

**Why it matters:**

This setting is the TTL of the Valkey mutation-gate cache key used during reconciliation; it is not a synchronization retry interval. The application revalidates mutation eligibility against the durable reconciliation record. Application 1.3.0 refuses startup when the effective TTL is below its derived minimum: the longest gate-required recovery deadline plus two stuck-job sweeper ticks. With the shipped 120-second tick, that minimum is 45540 seconds. Changing the sweeper tick changes the minimum.

**How to handle it:**

Audit `dictHubVsync.configmap`, `dictSystemplane.configmap`, any corresponding Secret/extra environment sources, and persisted systemplane `vsync.gate_ttl_sec` overrides. Remove obsolete low TTL overrides or replace them with a value satisfying the minimum for the actual sweeper configuration. Do not carry forward 300, 3600, or the previously illustrated 28800 seconds. Helm rendering does not enforce this application-level minimum.

If an explicit value is needed with the default sweeper configuration:

```yaml
dictHubVsync:
  configmap:
    VSYNC_GATE_TTL_SEC: "57600"
```

> Ensure that any persisted systemplane override and the DICT systemplane environment configuration agree with the intended effective value. A valid ConfigMap alone does not validate an override loaded later by the worker. Recheck the derived minimum if the sweeper configuration changes.

### 6. Pixauto Ingress Route Change

**What changed:**

The `appsIngress` routes for the `pixauto` component have been updated. The `/pixauto/readyz` route (Exact) has been replaced with `/pixauto/health` (Exact).

| Setting | v2.0.5 | v2.1.0 |
|---------|--------|--------|
| `appsIngress.routes[].path` | `/pixauto/readyz` | `/pixauto/health` |

**Why it matters:**

Kubernetes startup and liveness probes use `/health`, and readiness uses `/readyz`, on the named `health` container port (8099). The optional Exact `/pixauto/health` Ingress route targets the main application port for compatibility/dashboard use; it is not the Kubernetes liveness probe. The chart does not route the health Service port through Ingress.

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

**After (v2.1.0), Pixauto route fragment:**

```yaml
appsIngress:
  routes:
    # Client-facing API, including the public streaming manifest.
    - path: /pixauto/v1
      pathType: Prefix
      component: pixauto
      serviceName: pixauto
    # Optional compatibility health route for dashboard links.
    - path: /pixauto/health
      pathType: Exact
      component: pixauto
      serviceName: pixauto
```

> This is the Pixauto portion of the route list, not a complete replacement for your existing routes. Preserve the intended routes for other components. Never publish `/pixauto` with `pathType: Prefix`, `/` targeting Pixauto with Prefix semantics, or the `/pixauto/internal/v1/*` namespace. A broad Prefix also publishes the internal callbacks and scheduler endpoints; chart 2.1.0 rejects it. The client-facing routes must have effective authentication enabled. If Pixauto uses an existing Secret, verify its authentication configuration through your approved secret-management process; Helm cannot inspect that Secret. Do not disable authentication or bypass these guards to make a render pass.

## Configuration Reference

### Health Preset Configuration

All components now support the `health` configuration block:

| Field | Shipped default | Description |
|---|---|---|
| `<component>.health.stack` | `go` | Retain the shipped Go stack for these application images. The shared helper also recognizes other stacks; acceptance by the helper is not evidence that a different stack is compatible with these components. |
| `<component>.health.drainSeconds` | `15` | Integer seconds, minimum 0. Changes the generated `SHUTDOWN_DRAIN_DELAY` duration and termination grace. |
| `<component>.health.shutdownSeconds` | `30` | Integer seconds, minimum 1. Changes the generated `SHUTDOWN_TIMEOUT` duration and termination grace. |

**Example:**

```yaml
spi:
  health:
    stack: go
```

**Owned fields (do not set manually):**

For each enabled component, remove nonempty `livenessProbe`, `readinessProbe`, `startupProbe`, and `terminationGracePeriodSeconds` overrides. Remove `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY`, and `SHUTDOWN_TIMEOUT` from both `configmap` and `extraEnvVars`; those names are owned by the preset and are rejected there. Audit Secret-sourced duplicates too: explicit generated container environment entries take precedence over `envFrom`, so such duplicates must not be treated as effective tuning. Use `health.drainSeconds` and `health.shutdownSeconds` for supported shutdown tuning. Paths and probe timing are not configurable through the shipped Go preset. Do not treat editing rendered manifests as a durable Helm values migration.

### New Environment Variables

The health preset injects the following environment variables into all components:

| Variable | Value | Description |
|----------|-------|-------------|
| `HEALTH_PORT` | `8099` | Port for health and readiness probes |
| `SHUTDOWN_DRAIN_DELAY` | `15s` | Seconds to wait after receiving SIGTERM before starting shutdown (allows load balancers to deregister the pod) |
| `SHUTDOWN_TIMEOUT` | `30s` | Seconds to wait for graceful shutdown before forcing termination |

### Service Port Changes

All component Services now include a `health` port:

| Port Name | Port | Target Port | Protocol | Description |
|-----------|------|-------------|----------|-------------|
| `http` | (component-specific) | `http` | TCP | Main application port |
| `health` | `8099` | `8099` | TCP | Health and readiness probe port (not exposed via Ingress) |

## Database migration and recovery prerequisites

This upgrade changes the default application images from 1.1.0 to 1.3.0, not only Kubernetes probes. The source range adds DICT migrations 000045–000052, Pixauto migrations 000038–000047, and SPI migrations 000046–000061, and modifies some earlier migration SQL. Confirm the actual deployed image versions and database migration state before proceeding; retained image pins can change which migration code runs.

Pixauto migration 000047 drops `payer_payment_instructions.receiver_ispb`. Treat this as a destructive schema change: a Helm rollback cannot restore that column's prior data. Before starting, take protected, consistent database backups and preserve the current release configuration and external Secret references. Rehearse a restore/cutover plan with a known compatible application/schema combination and arrange the required maintenance or traffic controls.

For enabled migrating components, chart migration Jobs are rendered when migrations are enabled and a database URL is configured (or an existing Secret is selected). They run before installation/upgrade and execute the component image's migrator. Ensure every selected existing Secret is already available and contains the required database URL, and that the migrator can reach the database with the required privileges. If chart-managed migrations are disabled or skipped, perform the validated external migration procedure before allowing the new application to serve traffic.

Do not equate a successful Helm rollback, `--atomic`, a successful render, or a passing probe with reversal of database changes. The chart has no database-reversal rollback hook. Successful Helm migration hooks may be deleted, so do not require a retained successful Job as the only proof; retain migration execution evidence and verify database migration state through the approved operational process. Do not prescribe `migrate force` or `down` as a generic recovery procedure. If migration fails or old-image schema compatibility is unknown, stop and use the rehearsed database recovery plan rather than repeatedly redeploying.

Before upgrading, privately export the current user-supplied overrides and release manifests and preserve all referenced operator-managed Secrets through the approved backup process. These artifacts can contain credentials: restrict permissions, keep them out of Git, and do not paste them into logs, tickets, or this guide. Do not decode or print Secrets as a verification step.

Create `values.migrated.yaml` containing the complete intended user configuration for 2.1.0. Preserve unrelated settings, component enablement, image pins, storage and network configuration, authentication, and Secret references. Remove the old preset-owned fields, correct the Pixauto routes, and audit VSync TTL environment and persisted systemplane overrides as described above. Do not use the unedited 2.0.5 values file or `--reuse-values` to bypass this migration.

### Preview changes before upgrading

```bash
helm template <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm \
  --namespace <namespace> --version 2.1.0 --is-upgrade \
  -f values.migrated.yaml > rendered.private.yaml

helm diff upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm \
  --namespace <namespace> --version 2.1.0 \
  --reset-values -f values.migrated.yaml
```

> Protect `rendered.private.yaml`: rendered manifests can contain Secrets. `helm diff` requires the helm-diff plugin and can also expose sensitive differences; use it only in an approved private environment. A successful render is not an application boot, migration, or recovery test.

### Command to upgrade

Run only after the migration and recovery prerequisites above are satisfied:

```bash
helm upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm \
  --namespace <namespace> --version 2.1.0 \
  --reset-values -f values.migrated.yaml
```

> `--reset-values` prevents removed keys from being inherited from the stored release. It also discards old overrides that are absent from the supplied file: therefore the file must contain the complete intended user configuration, not only the snippets in this guide.

## Validation limits

Published chart lint and synthetic rendering do not certify an application boot or a live upgrade. No live migration, rollback, restore or helm-diff execution is asserted here. Optional mock image publication/provenance remains unverified; enable it only after separate validation.

<!-- {% endraw %} -->
