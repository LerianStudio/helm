# Helm Upgrade from v1.5.1 to v1.6.0

## Topics

- **[Features](#features)**
  - [Dedicated health check port support](#dedicated-health-check-port-support)
- **[Configuration Reference](#configuration-reference)**
  - [New health port settings](#new-health-port-settings)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Features

### Dedicated health check port support

The chart now supports serving health and readiness endpoints on a dedicated port (8099) separate from the main HTTP API port (4031). This feature is opt-in and controlled by the new `brSisbajud.serveHealthPort` flag.

**Why this matters:**

Separating health checks from the main API port provides several operational benefits:

- **Security isolation:** Health endpoints can be exposed internally without exposing the full API surface
- **Network policy flexibility:** Different network policies can be applied to health checks vs. application traffic
- **Load balancer configuration:** Some load balancers prefer dedicated health check ports
- **Monitoring isolation:** Health check traffic doesn't interfere with application metrics

**Default behavior (v1.6.0):**

```yaml
brSisbajud:
  serveHealthPort: false
```

By default, the behavior remains unchanged from v1.5.1: health endpoints (`/health` and `/readyz`) continue to be served on the main HTTP port (4031).

**Template changes:**

**Before (v1.5.1):**

```yaml
# Deployment container ports
ports:
  - name: http
    containerPort: 4031
    protocol: TCP

# Probes
livenessProbe:
  httpGet:
    path: /health
    port: http

readinessProbe:
  httpGet:
    path: /readyz
    port: http
```

**After (v1.6.0) with `serveHealthPort: false` (default):**

```yaml
# Deployment container ports
ports:
  - name: http
    containerPort: 4031
    protocol: TCP

# Probes
livenessProbe:
  httpGet:
    path: /health
    port: http

readinessProbe:
  httpGet:
    path: /readyz
    port: http
```

**After (v1.6.0) with `serveHealthPort: true`:**

```yaml
# Deployment environment variables
env:
  - name: HEALTH_PORT
    value: "8099"

# Deployment container ports
ports:
  - name: http
    containerPort: 4031
    protocol: TCP
  - name: health
    containerPort: 8099
    protocol: TCP

# Probes
livenessProbe:
  httpGet:
    path: /health
    port: health

readinessProbe:
  httpGet:
    path: /readyz
    port: health

# Service (ClusterIP only)
spec:
  ports:
    - port: 4031
      targetPort: http
      protocol: TCP
      name: http
    - port: 8099
      targetPort: health
      protocol: TCP
      name: health
```

> **Important:** The dedicated health port (8099) is only exposed on the Service when `brSisbajud.service.type` is `ClusterIP`. For `LoadBalancer` or `NodePort` services, only the main HTTP port is exposed to avoid unintended external exposure of health endpoints.

**Enabling the dedicated health port:**

To use the dedicated health port, you must:

1. Use an application image that supports the `HEALTH_PORT` environment variable and serves health endpoints on port 8099
2. Set `brSisbajud.serveHealthPort: true` in your values

```yaml
brSisbajud:
  serveHealthPort: true
  image:
    tag: "1.2.0"  # Example: use an image version that supports HEALTH_PORT
```

> **Warning:** Only enable `serveHealthPort: true` when using an application image that actually serves port 8099. If the image doesn't support this feature, the health probes will fail and pods will not become ready.

**Values.yaml comment updates:**

The chart documentation has been updated to clarify the relationship between the main HTTP port and health endpoints:

| Setting | v1.5.1 Comment | v1.6.0 Comment |
|---------|----------------|----------------|
| `brSisbajud.service.port` | "The main HTTP API (admin, institutions, /health, /readyz)" | "The main HTTP API (admin, institutions, /health; /readyz while serveHealthPort is false)" |

---

## Configuration Reference

### New health port settings

```yaml
brSisbajud:
  # -- true only with an image that serves 8099; flip it with the image tag.
  serveHealthPort: false
```

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.serveHealthPort` | `false` | Enable dedicated health check port (8099) separate from main API port |

**Environment variables:**

When `serveHealthPort: true`, the following environment variable is automatically injected into the application container:

| Variable | Value | Description |
|----------|-------|-------------|
| `HEALTH_PORT` | `"8099"` | Port number for serving health and readiness endpoints |

**Container ports:**

When `serveHealthPort: true`, an additional container port is exposed:

| Port Name | Container Port | Protocol | Condition |
|-----------|----------------|----------|-----------|
| `health` | `8099` | TCP | Only when `serveHealthPort: true` |

**Service ports:**

When `serveHealthPort: true` and `service.type: ClusterIP`, an additional service port is exposed:

| Port | Target Port | Protocol | Name | Condition |
|------|-------------|----------|------|-----------|
| `8099` | `health` | TCP | `health` | Only when `serveHealthPort: true` and `service.type: ClusterIP` |

---

## Migration Steps

This is a non-breaking change. No action is required to upgrade from v1.5.1 to v1.6.0.

### Option 1: Keep existing behavior (recommended)

If you want to maintain the current behavior where health endpoints are served on the main HTTP port:

**No changes required.** Simply upgrade the chart:

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.6.0
```

The default `serveHealthPort: false` preserves the v1.5.1 behavior.

### Option 2: Enable dedicated health port

If you want to use the dedicated health port feature:

**Step 1:** Verify your application image supports the `HEALTH_PORT` environment variable and serves health endpoints on port 8099.

> **Note:** Check your application's release notes or documentation to confirm which version introduced `HEALTH_PORT` support. Using `serveHealthPort: true` with an incompatible image will cause pod startup failures.

**Step 2:** Update your `values.yaml`:

```yaml
brSisbajud:
  serveHealthPort: true
  image:
    tag: "1.2.0"  # Replace with your actual image version that supports HEALTH_PORT
```

**Step 3:** Upgrade the chart:

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.6.0 -f values.yaml
```

**Step 4:** Verify the health port is working:

```bash
# Check that the health port is exposed
kubectl -n br-sisbajud get svc br-sisbajud -o jsonpath='{.spec.ports[?(@.name=="health")].port}'

# Port-forward and test the health endpoint
kubectl -n br-sisbajud port-forward svc/br-sisbajud 8099:8099
curl http://localhost:8099/health
```

> **Important:** If you enable `serveHealthPort: true` but the application image doesn't support it, the liveness and readiness probes will fail, preventing pods from becoming ready. Monitor pod status after the upgrade:
> ```bash
> kubectl -n br-sisbajud get pods -l app.kubernetes.io/instance=br-sisbajud
> kubectl -n br-sisbajud describe pod <pod-name>
> ```

---

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.6.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.6.0
```
