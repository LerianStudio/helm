<!-- {% raw %} -->
# Helm Upgrade from v2.5.0 to v2.6.0

## Topics ToC

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Health Port Service Exposure (Go Stack Only)](#1-health-port-service-exposure-go-stack-only)
  - [2. Health Port Ingress Protection](#2-health-port-ingress-protection)
  - [3. Multi-Tenant Health Check Documentation](#3-multi-tenant-health-check-documentation)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v2.6.0 introduces **health port Service exposure for Go stack applications** and **Ingress-level protection** to prevent accidental routing to internal health endpoints. This is a **minor release** with no breaking changes.

**What changed:**

- The `lerian-common.health` preset now returns a `servicePorts` key for Go stack applications, exposing port 8099 as a ClusterIP Service port (internal only)
- The `lerian-common.ingress` helper now validates that `svcPort` is never `8099`, failing the render if operators attempt to route external traffic to the health port
- Documentation in `_health.tpl` clarifies that port 8099 serves `/readyz/tenant/:id` for multi-tenant apps (via lib-commons `commons/health WithTenantChecks`)

**Who should upgrade:**

- Chart maintainers who consume `lerian-common.health` and `lerian-common.service` helpers in Go stack product charts
- Operators managing Lerian product charts that use the health preset (no action required unless you are exposing the health port via Ingress, which is now blocked)

**Backward compatibility:**

This release is **fully backward compatible**. The new `servicePorts` key is only emitted for Go stack applications and is optional for the `lerian-common.service` helper. Existing charts that do not pass `servicePorts` will continue to work unchanged. The Ingress validation is a safety guard that prevents misconfigurations; it does not affect correctly configured deployments.

## Features

### 1. Health Port Service Exposure (Go Stack Only)

The `lerian-common.health` preset now returns a `servicePorts` key for **Go stack applications only** (`stack: go`). This key contains a single port definition for the internal health endpoint (port 8099), which should be passed to the `lerian-common.service` helper to expose it as a ClusterIP Service port.

**What changed:**

| Setting | v2.5.0 | v2.6.0 |
|---------|---------|---------|
| `servicePorts` key in health preset output | Not present | Present for `stack: go` only |
| Health port 8099 Service exposure | Not exposed | Exposed as ClusterIP port (internal only) |

**Why it matters:**

Go stack applications serve health endpoints on port 8099 (via `HEALTH_PORT` environment variable). Exposing this port as a Service port enables:

- Internal health checks from within the cluster (e.g. monitoring tools, sidecar containers)
- Multi-tenant health checks via `/readyz/tenant/:id` (lib-commons `commons/health WithTenantChecks`)

The port is **never exposed via Ingress** (external traffic is blocked by the new validation in `lerian-common.ingress`).

**Operational impact:**

> **Important:** This change **only affects Go stack applications** (`stack: go`). Other stacks (`next`, `static`, `external`, `go-worker`) do not emit `servicePorts` and are unaffected.

For chart maintainers consuming `lerian-common.health` in Go stack product charts:

1. The health preset now returns a `servicePorts` key (a list with one port definition)
2. Pass this key to `lerian-common.service` as the `ports` input to expose port 8099 on the Service

**Before (v2.5.0):**

```yaml
# templates/service.yaml
{{- $health := include "lerian-common.health" (dict "context" $ "stack" "go" "port" .Values.myapp.service.port "replicas" .Values.myapp.replicaCount "autoscaling" .Values.myapp.autoscaling) | fromYaml }}
{{- include "lerian-common.service" (dict
      "name" (include "myapp.fullname" .)
      "labels" (include "myapp.labels" . | nindent 4)
      "selector" (include "myapp.selectorLabels" . | nindent 4)
      "namespace" .Release.Namespace
      "annotations" .Values.myapp.service.annotations
      "type" .Values.myapp.service.type
      "port" .Values.myapp.service.port) }}
```

**After (v2.6.0):**

```yaml
# templates/service.yaml
{{- $health := include "lerian-common.health" (dict "context" $ "stack" "go" "port" .Values.myapp.service.port "replicas" .Values.myapp.replicaCount "autoscaling" .Values.myapp.autoscaling) | fromYaml }}
{{- include "lerian-common.service" (dict
      "name" (include "myapp.fullname" .)
      "labels" (include "myapp.labels" . | nindent 4)
      "selector" (include "myapp.selectorLabels" . | nindent 4)
      "namespace" .Release.Namespace
      "annotations" .Values.myapp.service.annotations
      "type" .Values.myapp.service.type
      "port" .Values.myapp.service.port
      "ports" $health.servicePorts) }}
```

**Service output (v2.6.0):**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: production
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: http
      protocol: TCP
      name: http
    - name: health
      port: 8099
      targetPort: 8099
      protocol: TCP
  selector:
    app.kubernetes.io/name: myapp
```

> **Note:** The `servicePorts` key is only rendered when the Service type is `ClusterIP`. LoadBalancer and NodePort Services do not expose the health port.

> **Note:** For `go-worker` stack applications, `servicePorts` is **not** emitted (workers have no Service).

### 2. Health Port Ingress Protection

The `lerian-common.ingress` helper now validates that the `svcPort` input is **never `8099`** (the internal health port). If an operator attempts to route external traffic to port 8099 via Ingress, the render will fail with a clear error message.

**What changed:**

| Setting | v2.5.0 | v2.6.0 |
|---------|---------|---------|
| Ingress `svcPort` validation | None | Fails if `svcPort` is `8099` |

**Why it matters:**

Port 8099 is an **internal-only** health endpoint that should never be exposed to external traffic. This validation prevents accidental misconfigurations where operators might route Ingress traffic to the health port instead of the application's main HTTP port.

**Operational impact:**

If you have an Ingress configuration that routes to port 8099, the render will fail with the following error:

```
Error: template: myapp/templates/ingress.yaml:X:X: executing "myapp/templates/ingress.yaml" at <include "lerian-common.ingress" ...>: error calling include: template: lerian-common/templates/_ingress.tpl:58:5: executing "lerian-common.ingress" at <fail ...>: fail: lerian-common.ingress: myapp: never route to the health port (svcPort 8099)
```

**Migration steps:**

1. Review your Ingress configuration and ensure `svcPort` is set to your application's main HTTP port (e.g. `8080`, `3000`, `80`), **not** `8099`
2. If you need to expose health checks externally, use the application's main port with a path-based route (e.g. `/health`, `/readyz`) instead of routing to port 8099

**Example (correct configuration):**

```yaml
# values.yaml
myapp:
  service:
    port: 8080  # Main application port
  ingress:
    enabled: true
    hosts:
      - host: myapp.example.com
        paths:
          - path: /
            pathType: Prefix
    # Health checks can be exposed via the main port if needed
    healthcheck:
      path: /health
      port: 8080
```

> **Warning:** Do **not** set `ingress.healthcheck.port` to `8099`. The ALB healthcheck should use the main application port, not the internal health port.

### 3. Multi-Tenant Health Check Documentation

The `_health.tpl` template documentation has been updated to clarify that port 8099 serves `/readyz/tenant/:id` for multi-tenant applications (via lib-commons `commons/health WithTenantChecks`).

**What changed:**

The documentation now explicitly states:

- Port 8099 is an **internal ClusterIP Service port only** (never an Ingress backend)
- Multi-tenant apps serve `/readyz/tenant/:id` on port 8099 (in addition to `/health` and `/readyz`)

**Why it matters:**

This clarifies the intended use of port 8099 for operators and chart maintainers:

- Port 8099 is for **internal health checks only** (within the cluster)
- Multi-tenant apps can check tenant-specific readiness via `/readyz/tenant/:id`
- External health checks (ALB, Ingress) should use the main application port, not port 8099

**Operational impact:**

No action required. This is a documentation-only change that clarifies existing behavior.

## Configuration Reference

The `lerian-common` chart has **no new values** in v2.6.0. All changes are internal to the template helpers.

**Health preset output (Go stack only):**

| Key | Type | Description |
|-----|------|-------------|
| `servicePorts` | list | Port definition for the internal health endpoint (port 8099); pass to `lerian-common.service` as `ports` input |

**Service helper inputs:**

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `ports` | list | Optional | Extra ports appended after the main `http` port; only rendered for ClusterIP Services |

**Ingress helper validation:**

| Validation | Behavior |
|------------|----------|
| `svcPort == 8099` | Render fails with error: `lerian-common.ingress: <name>: never route to the health port (svcPort 8099)` |

## Migration Steps

### For Chart Maintainers (Go Stack Product Charts)

If you maintain a Go stack product chart that consumes `lerian-common.health` and `lerian-common.service`:

1. **Update the `lerian-common` dependency** in your product chart's `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 2.6.0
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Pass `servicePorts` to the Service helper** in your `templates/service.yaml`:

```yaml
{{- $health := include "lerian-common.health" (dict "context" $ "stack" "go" "port" .Values.myapp.service.port "replicas" .Values.myapp.replicaCount "autoscaling" .Values.myapp.autoscaling) | fromYaml }}
{{- include "lerian-common.service" (dict
      "name" (include "myapp.fullname" .)
      "labels" (include "myapp.labels" . | nindent 4)
      "selector" (include "myapp.selectorLabels" . | nindent 4)
      "namespace" .Release.Namespace
      "annotations" .Values.myapp.service.annotations
      "type" .Values.myapp.service.type
      "port" .Values.myapp.service.port
      "ports" $health.servicePorts) }}
```

4. **Test the render** to ensure port 8099 is exposed on the Service:

```bash
helm template myapp . --values test-values.yaml | grep -A 10 "kind: Service"
```

5. **Verify Ingress configuration** does not route to port 8099:

```bash
helm template myapp . --values test-values.yaml | grep -A 20 "kind: Ingress"
```

### For Operators (Umbrella Deployments)

If you manage Lerian product charts via an umbrella chart:

1. **Update the `lerian-common` dependency** in your umbrella `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 2.6.0
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Review Ingress configurations** to ensure no routes target port 8099:

```bash
helm template my-umbrella . --values values.yaml | grep -B 5 -A 5 "port: 8099"
```

If you find any Ingress rules routing to port 8099, update your `values.yaml` to use the main application port instead.

4. **Upgrade the umbrella chart:**

```bash
helm upgrade my-umbrella . -n lerian --values values.yaml
```

### For Standalone Deployments

If you deploy a single product chart without an umbrella:

**No action required** unless:

- You have manually configured an Ingress to route to port 8099 (the render will fail; update `svcPort` to the main application port)
- You are a chart maintainer adopting the new `servicePorts` key (see [For Chart Maintainers](#for-chart-maintainers-go-stack-product-charts))

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.6.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of adopting v2.6.0, run `helm diff` on the **product charts** that consume it.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.6.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `2.6.0` and run `helm dependency update`.
<!-- {% endraw %} -->
