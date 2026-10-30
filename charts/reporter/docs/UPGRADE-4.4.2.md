<!-- {% raw %} -->
# Helm Upgrade from v4.4.1 to v4.4.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Worker container port now references HEALTH_PORT from configmap](#1-worker-container-port-now-references-health_port-from-configmap)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that fixes the worker deployment container port configuration to correctly reference the health check port from the configmap. The application version remains unchanged.

| Field | v4.4.1 | v4.4.2 |
|-------|--------|--------|
| Chart version | `4.4.1` | `4.4.2` |
| App version | `4.5.0` | `4.5.0` |

## Fixes

### 1. Worker container port now references HEALTH_PORT from configmap

The worker deployment container port definition has been corrected to read the port value from `worker.configmap.HEALTH_PORT` instead of `worker.service.port`. This ensures the container port matches the actual health check endpoint port configured in the application.

| Setting | v4.4.1 | v4.4.2 |
|---------|--------|--------|
| Worker container port source | `worker.service.port` | `worker.configmap.HEALTH_PORT` (defaults to `4006`) |

**Before (v4.4.1):**

```yaml
ports:
  - name: http
    containerPort: {{ .Values.worker.service.port }}
    protocol: TCP
```

**After (v4.4.2):**

```yaml
ports:
  - name: http
    containerPort: {{ .Values.worker.configmap.HEALTH_PORT | default 4006 }}
    protocol: TCP
```

**Operational impact:**

- If `worker.service.port` and `worker.configmap.HEALTH_PORT` were already aligned in your deployment, this change has no effect
- If they were misaligned, the worker container port will now correctly match the health endpoint port, fixing potential probe failures
- The default fallback value is `4006` if `HEALTH_PORT` is not explicitly set in the configmap

> **Note:** This fix ensures that the container port declaration matches the port on which the worker application actually serves health check endpoints. Misalignment between these values could cause readiness and liveness probes to fail even when the application is healthy.

## Migration Steps

This upgrade requires no configuration changes. The fix is transparent and will automatically align the worker container port with the health check port.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))
2. Run the upgrade command during a maintenance window
3. Verify worker pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=reporter-worker
```

4. Verify the container port matches the health port configuration:

```bash
kubectl get pod -n <namespace> -l app.kubernetes.io/name=reporter-worker -o jsonpath='{.items[0].spec.containers[0].ports[0].containerPort}'
kubectl get configmap -n <namespace> reporter-worker -o jsonpath='{.data.HEALTH_PORT}'
```

> **Note:** The upgrade triggers a rolling restart of the worker deployment. If your `worker.configmap.HEALTH_PORT` was previously misaligned with `worker.service.port`, the new pods will expose the correct port.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.4.2 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.4.2 -n <namespace>
```
<!-- {% endraw %} -->
