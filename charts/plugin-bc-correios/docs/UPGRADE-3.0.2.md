<!-- {% raw %} -->
# Helm Upgrade from v3.0.1 to v3.0.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Health probe endpoints updated](#1-health-probe-endpoints-updated)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the default health probe endpoints for the BC Correios plugin. The chart version moves from 3.0.1 to 3.0.2. The liveness and startup probes now use `/health` instead of `/health/live`, and the readiness probe now uses `/readyz` instead of `/health/ready`. This change aligns the chart with updated application health check endpoints. No breaking changes are introduced, and the upgrade requires no manual data migration.

## Fixes

### 1. Health probe endpoints updated

The default health probe paths have been updated to match the application's current health check endpoints. This change affects the default values in `values.yaml` and the fallback defaults in the deployment template.

**Before (v3.0.1):**

```yaml
bc-correios:
  livenessProbe:
    path: "/health/live"
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  readinessProbe:
    path: "/health/ready"
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  startupProbe:
    path: "/health/live"
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 30
```

**After (v3.0.2):**

```yaml
bc-correios:
  livenessProbe:
    path: "/health"
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  readinessProbe:
    path: "/readyz"
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  startupProbe:
    path: "/health"
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 30
```

**Template changes:**

The deployment template's default probe paths have also been updated to match:

**Before (v3.0.1):**

```yaml
livenessProbe:
  httpGet:
    path: {{ $component.livenessProbe.path | default "/health/live" }}
    port: http
readinessProbe:
  httpGet:
    path: {{ $component.readinessProbe.path | default "/health/ready" }}
    port: http
startupProbe:
  httpGet:
    path: {{ $component.startupProbe.path | default "/health/live" }}
    port: http
```

**After (v3.0.2):**

```yaml
livenessProbe:
  httpGet:
    path: {{ $component.livenessProbe.path | default "/health" }}
    port: http
readinessProbe:
  httpGet:
    path: {{ $component.readinessProbe.path | default "/readyz" }}
    port: http
startupProbe:
  httpGet:
    path: {{ $component.startupProbe.path | default "/health" }}
    port: http
```

**Operational impact:**

- Pods will be recreated during the upgrade with the new probe paths
- If you have not overridden probe paths in your values file, the upgrade will automatically use the new endpoints
- If you have explicitly set probe paths in your values file to the old endpoints (`/health/live`, `/health/ready`), you should update them to match the new defaults unless you have a specific reason to keep the old paths
- The new endpoints are expected to be available in the application version you are running; verify your application supports these endpoints before upgrading

> **Important:** If you have customized probe paths in your values file and want to keep using the old endpoints, ensure your application version still supports `/health/live` and `/health/ready`. The chart defaults now assume the application exposes `/health` and `/readyz`.

## Configuration Changes

The following table summarizes the probe path changes:

| Setting                          | v3.0.1          | v3.0.2     |
|----------------------------------|-----------------|------------|
| `bc-correios.livenessProbe.path` | `/health/live`  | `/health`  |
| `bc-correios.readinessProbe.path`| `/health/ready` | `/readyz`  |
| `bc-correios.startupProbe.path`  | `/health/live`  | `/health`  |

All other probe settings (timings, thresholds) remain unchanged. If you have overridden any of these paths in your values file, review your overrides against the new defaults.

## Migration Steps

This upgrade requires no mandatory manual migration steps if you are using default probe settings or if your application supports both the old and new health check endpoints.

**Recommended upgrade process:**

1. Verify your application version supports the new health check endpoints (`/health` and `/readyz`). If you are unsure, check the application logs or documentation.

2. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))

3. If you have explicitly overridden probe paths in your values file, decide whether to:
   - Update your overrides to use the new endpoints (recommended)
   - Keep your existing overrides if your application still supports the old endpoints

4. Ensure you have a recent backup of your data (if using chart-managed databases)

5. Run the upgrade command during a maintenance window

6. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

7. Check that the new health probe endpoints are responding correctly:

```bash
kubectl exec -n <namespace> -it <pod-name> -- wget -qO- http://localhost:9090/health
kubectl exec -n <namespace> -it <pod-name> -- wget -qO- http://localhost:9090/readyz
```

8. Check service logs for any probe-related issues:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=bc-correios,app.kubernetes.io/instance=plugin-bc-correios --tail=50
```

> **Note:** The upgrade will trigger a rolling restart of the BC Correios pods. Depending on your replica count and readiness probe configuration, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 3.0.2 -n plugin-bc-correios
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 3.0.2 -n plugin-bc-correios
```
<!-- {% endraw %} -->
