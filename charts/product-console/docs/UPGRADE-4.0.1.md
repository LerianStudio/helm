# Helm Upgrade from v4.0.0 to v4.0.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Readiness probe path default corrected](#1-readiness-probe-path-default-corrected)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that corrects the default readiness probe path in the deployment template. The application version is unchanged.

| Field | v4.0.0 | v4.0.1 |
|-------|--------|--------|
| Chart version | `4.0.0` | `4.0.1` |
| App version | `1.10.0` | `1.10.0` |

## Fixes

### 1. Readiness probe path default corrected

The readiness probe default path has been updated to match the application's actual health check endpoint. This fix ensures that the readiness probe correctly checks MongoDB and other dependency health before marking pods as Ready.

| Setting | v4.0.0 | v4.0.1 |
|---------|--------|--------|
| `readinessProbe.path` (default) | `/` | `/api/admin/health/readyz` |

**Before (v4.0.0):**

```yaml
readinessProbe:
  httpGet:
    path: {{ .Values.readinessProbe.path | default "/" }}
    port: http
```

**After (v4.0.1):**

```yaml
readinessProbe:
  httpGet:
    path: {{ .Values.readinessProbe.path | default "/api/admin/health/readyz" }}
    port: http
```

**Impact:**

- Pods will now use `/api/admin/health/readyz` for readiness checks by default, which properly validates MongoDB connectivity and other dependencies
- The previous default path `/` bypassed dependency health checks, potentially allowing traffic to pods that were not fully ready
- If you have explicitly set `readinessProbe.path` in your `values.yaml`, your custom value will continue to be used

> **Important:** This change improves the reliability of readiness checks. Pods will only become Ready when all dependencies are healthy, preventing premature traffic routing during startup or database connectivity issues.

## Configuration Changes

No configuration keys were added, removed, or renamed. The change only affects the built-in default value for `readinessProbe.path`.

| Setting | v4.0.0 default | v4.0.1 default | Notes |
|---------|----------------|----------------|-------|
| `readinessProbe.path` | `/` | `/api/admin/health/readyz` | Only affects deployments that do not explicitly set this value |

## Migration Steps

This upgrade requires no mandatory values changes. The Helm upgrade will roll the deployment and update the readiness probe path to the corrected default.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify that your application image (version `1.10.0`) exposes the `/api/admin/health/readyz` endpoint. This endpoint has been available since earlier versions.

3. Run the upgrade command during a maintenance window.

4. Monitor the pod rollout to ensure pods become Ready:

```bash
kubectl get pods -n product-console -w
```

5. Verify readiness probe status after the upgrade:

```bash
kubectl describe pod -n product-console -l app.kubernetes.io/name=product-console | grep -A5 "Readiness"
```

6. Check application logs for any health check failures:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50 | grep -i health
```

> **Note:** The upgrade triggers a rolling restart of the `product-console` deployment. Pods will only become Ready when the `/api/admin/health/readyz` endpoint returns a successful response, which includes MongoDB connectivity validation.

### If you need to temporarily revert to the old behavior

If you encounter issues and need to temporarily use the previous readiness path, you can override it:

```yaml
readinessProbe:
  path: /
```

> **Warning:** Using `/` as the readiness path bypasses dependency health checks. This should only be used as a temporary workaround. Investigate and resolve the underlying health check failures instead.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.1 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.1 -n product-console
```
