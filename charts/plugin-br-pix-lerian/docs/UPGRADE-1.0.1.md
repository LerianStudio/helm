<!-- {% raw %} -->
# Helm Upgrade from v1.0.0 to v1.0.1

## Topics

- **[Fixes](#fixes)**
  - [1. Proxy Components Now Ship Disabled](#1-proxy-components-now-ship-disabled)
  - [2. Library Chart Dependency Update](#2-library-chart-dependency-update)
  - [3. OTEL Endpoint Resolution Fix](#3-otel-endpoint-resolution-fix)
  - [4. ORGANIZATION_ID ConfigMap Cleanup](#4-organization_id-configmap-cleanup)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Proxy Components Now Ship Disabled

**What changed:**

The `dictProxy` and `cobProxy` components now default to `enabled: false` in `values.yaml`. These components are structural only in this release: they serve health checks, readiness probes, and an OpenAPI document with no operations, but return 404 for all business requests. The supported topology is hub-only.

| Setting | v1.0.0 | v1.0.1 |
|---------|--------|--------|
| `dictProxy.enabled` | `true` | `false` |
| `cobProxy.enabled` | `true` | `false` |

**Why it matters:**

An existing installation that relied on the v1.0.0 default (`enabled: true`) **will lose the `dict-proxy` and `cob-proxy` Deployments, Services, ConfigMaps, Secrets, ServiceAccounts, HPAs, and PodDisruptionBudgets on `helm upgrade`**. The `/dict-proxy` and `/cob-proxy` routes in `appsIngress.routes` will be skipped while their components are disabled.

**No business impact:** The proxy tiers serve no business routes in this release, so disabling them does not affect production traffic.

**How to handle it:**

#### Option 1: Accept the new default (recommended)

If you are running the hub-only topology (the supported configuration), no action is required. The proxy components will be removed on upgrade, and the hub components will continue to handle all business traffic.

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 1.0.1 -n plugin-br-pix-lerian
```

#### Option 2: Keep the proxy components

If your provider topology requires the proxy tiers to exist (for structural reasons or future readiness), explicitly enable them before upgrading:

```yaml
dictProxy:
  enabled: true

cobProxy:
  enabled: true
```

> **Warning:** Do not route client traffic to the proxy components. They return 404 for all business requests. Enable them only if your infrastructure requires the Deployments and Services to exist.

**After (v1.0.1) values.yaml:**

```yaml
dictProxy:
  # -- Ships DISABLED. The proxy tier is structural only in this release: it serves
  # health, readyz and an OpenAPI document with no operations, and answers 404 to
  # every business request while its probes stay green. The supported topology is
  # hub-only (README, "Production quickstart"). Enable it only if your provider
  # topology requires the tier to exist, and never route client traffic to it.
  enabled: false
  name: "dict-proxy"
  description: "DICT proxy to BCB"
  # ...

cobProxy:
  # -- Ships DISABLED. The proxy tier is structural only in this release: it serves
  # health, readyz and an OpenAPI document with no operations, and answers 404 to
  # every business request while its probes stay green. The supported topology is
  # hub-only (README, "Production quickstart"). Enable it only if your provider
  # topology requires the tier to exist, and never route client traffic to it.
  enabled: false
  name: "cob-proxy"
  description: "COB proxy to BCB"
  # ...
```

**Ingress behavior:**

The `/dict-proxy` and `/cob-proxy` routes remain listed in the default `appsIngress.routes`, but the chart skips rendering them while the components are disabled. If you enable `dictProxy` or `cobProxy`, the routes will be rendered automatically.

### 2. Library Chart Dependency Update

**What changed:**

The `lerian-common-helm` library chart dependency has been updated from version `2.1.0` to `2.1.2`, and the repository has been changed from a local file path to an OCI registry.

| Setting | v1.0.0 | v1.0.1 |
|---------|--------|--------|
| `dependencies[0].version` | `2.1.0` | `2.1.2` |
| `dependencies[0].repository` | `file://../lerian-common` | `oci://ghcr.io/lerianstudio` |

**Why it matters:**

The library chart provides shared workload fragments (Service, HPA, ServiceAccount, scheduling helpers) used by all components. The update to `2.1.2` includes fixes and improvements to these shared templates. The move to an OCI registry simplifies dependency management and eliminates the need for a local `lerian-common` directory.

**How to handle it:**

No action is required. Helm will automatically fetch the updated library chart from the OCI registry during the upgrade.

**Before (v1.0.0) Chart.yaml:**

```yaml
dependencies:
  - name: lerian-common-helm
    version: 2.1.0
    repository: "file://../lerian-common"
```

**After (v1.0.1) Chart.yaml:**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.1.2"
    repository: "oci://ghcr.io/lerianstudio"
```

### 3. OTEL Endpoint Resolution Fix

**What changed:**

The template logic for determining whether an OpenTelemetry endpoint is configured has been corrected in all component Deployments. Previously, the check only read the component's native `OTEL_EXPORTER_OTLP_ENDPOINT` ConfigMap key, which allowed a node-local default (injected by infrastructure) to clobber a global endpoint set via `global.observability.otlpEndpoint`.

**Why it matters:**

If you set `global.observability.otlpEndpoint` but a component's ConfigMap did not explicitly override it, and a node-local default was injected (e.g., via a mutating webhook or init container), the template would incorrectly conclude that no endpoint was configured and skip telemetry setup. This resulted in missing traces and metrics for components that should have been instrumented.

**How to handle it:**

No action is required. The fix ensures that the global `otlpEndpoint` is respected unless explicitly overridden by a component-specific `configmap.OTEL_EXPORTER_OTLP_ENDPOINT` value.

**Before (v1.0.0) deployment.yaml:**

```yaml
{{- $hasOtelEndpoint := ne (toString (default "" $cm.OTEL_EXPORTER_OTLP_ENDPOINT)) "" }}
```

**After (v1.0.1) deployment.yaml:**

```yaml
{{- /* Same resolution as the ConfigMap's OTEL_EXPORTER_OTLP_ENDPOINT: native
     configmap key > global.observability.otlpEndpoint > "". Reading only the
     native key let the injected node-local default clobber a global endpoint. */}}
{{- $hasOtelEndpoint := ne (toString (include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "observability" "field" "otlpEndpoint" "nativeKey" "OTEL_EXPORTER_OTLP_ENDPOINT" "default" ""))) "" }}
```

**Affected components:**

- `adapter-lerian`
- `adapter-lerian-systemplane`
- `adapter-provider-mock`
- `cob-hub`
- `cob-proxy`
- `cob-systemplane`
- `dict-hub`
- `dict-hub-vsync`
- `dict-proxy`
- `dict-systemplane`

### 4. ORGANIZATION_ID ConfigMap Cleanup

**What changed:**

The `ORGANIZATION_ID` environment variable has been removed from the enumerated ConfigMap keys for several components. This variable is **not** superseded by `ORGANIZATION_IDS` (the license allow-list). `ORGANIZATION_ID` is a single-tenant business identity read by specific components, and it is now passed through only when explicitly set via `<component>.configmap.ORGANIZATION_ID`.

**Why it matters:**

The previous enumeration of `ORGANIZATION_ID` in the ConfigMap templates was misleading, as it suggested the variable was always emitted. In reality, `ORGANIZATION_ID` is component-specific and should only be set when required by the application logic. The removal from the enumerated list clarifies that it is an optional pass-through variable, not a standard configuration key.

**How to handle it:**

If your deployment sets `ORGANIZATION_ID` for any component, continue to set it via the component's `configmap` block:

```yaml
cobHub:
  configmap:
    ORGANIZATION_ID: "your-organization-id"
```

The variable will be passed through to the component's ConfigMap as before. If you do not set it, the variable will not be emitted.

**Affected components:**

- `cob-hub`
- `cob-systemplane`
- `dict-hub`
- `dict-hub-vsync`
- `dict-proxy`
- `dict-systemplane`

**Before (v1.0.0) configmap.yaml:**

```yaml
{{- range $k := (list
    "ENABLE_TELEMETRY" "ORGANIZATION_ID" "ORGANIZATION_IDS"
    "OTEL_EXPORTER_OTLP_ENDPOINT" "LOG_LEVEL"
    # ...
  )}}
```

**After (v1.0.1) configmap.yaml:**

```yaml
{{- range $k := (list
    "ENABLE_TELEMETRY" "ORGANIZATION_IDS"
    "OTEL_EXPORTER_OTLP_ENDPOINT" "LOG_LEVEL"
    # ...
  )}}
```

> **Note:** `ORGANIZATION_ID` is not enumerated in the list, so `<component>.configmap.ORGANIZATION_ID` passes through when set. This is the intended behavior.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 1.0.1 -n plugin-br-pix-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 1.0.1 -n plugin-br-pix-lerian
```
<!-- {% endraw %} -->
