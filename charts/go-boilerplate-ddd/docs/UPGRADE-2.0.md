# Helm Upgrade from v1.x to v2.x

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Readiness Probe Path Updated](#readiness-probe-path-updated)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### Readiness Probe Path Updated

The readiness probe endpoint has been changed from `/ready` to `/readyz` to align with Kubernetes standard health check conventions.

**Before (v1.0.0):**

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
```

**After (v2.0.0):**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
```

| Setting | v1.0.0 | v2.0.0 |
|---------|--------|--------|
| Readiness probe path | `/ready` | `/readyz` |

#### Operational Impact

This change requires that your application exposes a `/readyz` endpoint instead of `/ready`. The readiness probe is used by Kubernetes to determine when a pod is ready to accept traffic.

> **Warning:** If your application does not expose a `/readyz` endpoint, pods will fail readiness checks and will not receive traffic from the Service. This will cause service disruption.

#### Migration Steps

1. **Verify your application exposes the `/readyz` endpoint** before upgrading the chart. If your application currently only exposes `/ready`, you must either:
   - Update your application code to expose `/readyz`, or
   - Override the readiness probe path in your values to continue using `/ready`

2. **Option 1: Update your application** (recommended)

   Ensure your application serves health checks at `/readyz`. This is the standard Kubernetes convention and aligns with best practices.

3. **Option 2: Override the probe path temporarily**

   If you cannot update your application immediately, override the readiness probe path in your `values.yaml`:

   ```yaml
   readinessProbe:
     httpGet:
       path: /ready
   ```

   Then upgrade using:

   ```bash
   helm upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.0.0 -n go-boilerplate-ddd -f values.yaml
   ```

> **Important:** Option 2 is a temporary workaround. Plan to update your application to use `/readyz` to maintain compatibility with future chart versions.

## Preview changes before upgrading

```bash
helm diff upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.0.0 -n go-boilerplate-ddd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.0.0 -n go-boilerplate-ddd
```
