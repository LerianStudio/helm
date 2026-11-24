# Helm Upgrade from v5.4.3 to v5.4.4

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Worker resource limits increased for large report generation](#1-worker-resource-limits-increased-for-large-report-generation)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that increases the default CPU and memory limits for the `worker` component to support generation of larger reports. The worker holds report rows in memory during rendering, and the previous limits could cause out-of-memory failures for large datasets. The application version remains unchanged.

| Field | v5.4.3 | v5.4.4 |
|-------|--------|--------|
| Chart version | `5.4.3` | `5.4.4` |
| App version | `4.10.0` | `4.10.0` |

## Fixes

### 1. Worker resource limits increased for large report generation

The `worker` deployment resource limits have been increased to accommodate larger report generation workloads. The worker holds all rows of a report in memory while rendering, so the memory limit directly bounds the maximum report size that can be generated without triggering an out-of-memory (OOM) kill.

| Setting | v5.4.3 | v5.4.4 | Notes |
|---------|--------|--------|-------|
| `worker.resources.limits.cpu` | `200m` | `1000m` | 5× increase to support CPU-intensive rendering |
| `worker.resources.limits.memory` | `256Mi` | `4Gi` | ~16× increase to hold larger datasets in memory |
| `worker.resources.requests.cpu` | `100m` | `100m` | Unchanged |
| `worker.resources.requests.memory` | `128Mi` | `128Mi` | Unchanged |

**Before (v5.4.3):**

```yaml
worker:
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
```

**After (v5.4.4):**

```yaml
worker:
  resources:
    limits:
      cpu: 1000m
      memory: 4Gi
    requests:
      cpu: 100m
      memory: 128Mi
```

> **Note:** The comment in `values.yaml` now explicitly documents that the memory limit bounds the size of the report the worker can generate. If your cluster has resource quotas or node memory constraints, verify that worker pods can be scheduled with the new 4Gi limit.

**Operational impact:**

- Worker pods will be recreated during the upgrade with the new resource limits
- Existing worker pods with in-flight report generation will be terminated gracefully
- If your cluster nodes have less than 4Gi of allocatable memory per node, worker pods may fail to schedule. In this case, override the limits to fit your cluster capacity:

```yaml
worker:
  resources:
    limits:
      memory: 2Gi  # Adjust to fit your node capacity
```

> **Warning:** Reducing the memory limit below the default 4Gi may cause OOM failures when generating large reports. Monitor worker pod memory usage and adjust limits based on your actual report sizes.

## Configuration Changes

No new keys were added or removed. The change is in default values only.

| Setting | v5.4.3 | v5.4.4 | Notes |
|---------|--------|--------|-------|
| `worker.resources.limits.cpu` (default) | `200m` | `1000m` | Override if cluster CPU quota is constrained |
| `worker.resources.limits.memory` (default) | `256Mi` | `4Gi` | Override if cluster memory quota is constrained |

## Migration Steps

This upgrade requires no mandatory values changes. The Helm upgrade will roll the worker deployment with the new resource limits.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify that your cluster nodes have sufficient allocatable memory to schedule worker pods with a 4Gi limit:

```bash
kubectl describe nodes | grep -A5 "Allocatable:"
```

3. If your nodes cannot accommodate 4Gi memory limits, override the worker resources in your values:

```yaml
worker:
  resources:
    limits:
      cpu: 500m      # Adjust to fit your cluster
      memory: 2Gi    # Adjust to fit your cluster
```

4. Run the upgrade command during a maintenance window.

5. Verify all worker pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=reporter-worker
```

6. Check worker pod resource allocation:

```bash
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-worker | grep -A10 "Limits:"
```

7. Monitor worker memory usage during report generation:

```bash
kubectl top pod -n <namespace> -l app.kubernetes.io/name=reporter-worker
```

> **Note:** The upgrade triggers a rolling restart of the worker deployment. In-flight report generation jobs will be interrupted and may need to be retried by the application.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.4
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.4
```
