# Helm Upgrade from v4.0.2 to v4.0.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Liveness probe default path corrected](#1-liveness-probe-default-path-corrected)
  - [2. Probe port now configurable](#2-probe-port-now-configurable)
  - [3. Enhanced NOTES.txt with MongoDB readiness guidance](#3-enhanced-notestxt-with-mongodb-readiness-guidance)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that corrects the liveness probe default path and adds configurability for probe ports. The application version is unchanged.

| Field | v4.0.2 | v4.0.3 |
|-------|--------|--------|
| Chart version | `4.0.2` | `4.0.3` |
| App version | `1.12.0` | `1.12.0` |

## Fixes

### 1. Liveness probe default path corrected

The liveness probe default path has been changed from `/` to `/api/admin/health/alive`. This endpoint returns 200 unconditionally and does not depend on MongoDB connectivity, making it suitable for liveness checks.

| Probe | v4.0.2 default | v4.0.3 default |
|-------|----------------|----------------|
| `livenessProbe.path` | `/` | `/api/admin/health/alive` |
| `readinessProbe.path` | `/api/admin/health/readyz` | `/api/admin/health/readyz` |

**Before (v4.0.2):**

```yaml
livenessProbe:
  httpGet:
    path: {{ .Values.livenessProbe.path | default "/" }}
    port: http
```

**After (v4.0.3):**

```yaml
livenessProbe:
  httpGet:
    path: {{ .Values.livenessProbe.path | default "/api/admin/health/alive" }}
    port: {{ .Values.livenessProbe.port | default "http" }}
```

> **Important:** The `/api/admin/health/alive` endpoint is available since application image `1.10.0`. If you are running an older image, override the liveness path back to `/` in your values.yaml.

**Operational impact:**

- Pods running application image `1.10.0` or later will use the new MongoDB-independent liveness endpoint by default
- If MongoDB becomes unavailable, pods will remain alive (not crash-loop) but will fail readiness checks
- This separation prevents unnecessary pod restarts during transient database issues

> **Warning:** Do NOT point liveness at `/api/admin/health/readyz` or any MongoDB-dependent path. A disconnected MongoDB would cause pods to crash-loop instead of remaining alive and waiting for the database to recover.

### 2. Probe port now configurable

Both liveness and readiness probes now support a configurable `port` field in `values.yaml`. The default remains `http` (the named container port).

| Setting | v4.0.2 | v4.0.3 |
|---------|--------|--------|
| `livenessProbe.port` | hardcoded `http` | `{{ .Values.livenessProbe.port \| default "http" }}` |
| `readinessProbe.port` | hardcoded `http` | `{{ .Values.readinessProbe.port \| default "http" }}` |

**Example override:**

```yaml
livenessProbe:
  port: 8080
readinessProbe:
  port: 8080
```

This is useful when the container port name differs from `http` or when using a numeric port directly.

### 3. Enhanced NOTES.txt with MongoDB readiness guidance

The post-install/upgrade notes now include a detailed section explaining the relationship between readiness probes and MongoDB connectivity. This addresses a common deadlock scenario on fresh installs.

**Key points added to NOTES.txt:**

- The readiness endpoint `/api/admin/health/readyz` requires MongoDB connectivity to return 200
- Application images that connect to MongoDB lazily (only on first business request) will deadlock: the pod never becomes Ready, so it never receives traffic, so it never connects to MongoDB
- Operators must use an application image that connects to MongoDB eagerly at startup, or use a readiness endpoint that does not depend on MongoDB
- Liveness must remain on a MongoDB-independent endpoint to prevent crash-loops during database outages

> **Note:** This is documentation-only; no configuration changes are required unless you encounter the described deadlock scenario.

## Configuration Changes

No existing keys were removed or renamed. Two new optional fields have been added to the probe configuration blocks.

| Setting | v4.0.2 | v4.0.3 | Notes |
|---------|--------|--------|-------|
| `livenessProbe.path` (default) | `/` | `/api/admin/health/alive` | Requires app image ≥ 1.10.0 |
| `livenessProbe.port` | hardcoded `http` | configurable, defaults to `http` | New optional field |
| `readinessProbe.port` | hardcoded `http` | configurable, defaults to `http` | New optional field |

## Migration Steps

This upgrade requires no mandatory values changes for most installations. The Helm upgrade will roll the deployment and update the liveness probe path.

**Recommended upgrade process:**

1. **Verify application image version.** Check that your deployment uses application image `1.10.0` or later:

```bash
kubectl get deployment product-console -n product-console -o jsonpath='{.spec.template.spec.containers[0].image}'
```

2. **If running image < 1.10.0**, override the liveness path to preserve the old behavior:

```yaml
livenessProbe:
  path: /
```

3. **Preview the changes** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. **Run the upgrade** during a maintenance window:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.3 -n product-console
```

5. **Verify all pods are running and healthy** after the upgrade:

```bash
kubectl get pods -n product-console
```

6. **Check probe status** in pod events:

```bash
kubectl describe pod -n product-console -l app.kubernetes.io/name=product-console | grep -A5 -E "Liveness|Readiness"
```

7. **Verify the new liveness endpoint** is responding:

```bash
kubectl exec -n product-console deployment/product-console -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/admin/health/alive
```

Expected output: `200`

> **Note:** The upgrade triggers a rolling restart of the `product-console` deployment. If the new liveness path returns non-2xx, pods will be restarted by Kubernetes.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.3 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.3 -n product-console
```
