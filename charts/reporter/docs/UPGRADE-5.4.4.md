<!-- {% raw %} -->
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

The worker resource limits have been increased to accommodate larger report generation workloads. The worker is the `reporter-worker` ScaledJob with `keda.enabled: true` (the default) and the `reporter-worker` Deployment with `keda.enabled: false`. The worker holds all rows of a report in memory while rendering, so the memory limit directly bounds the maximum report size that can be generated without triggering an out-of-memory (OOM) kill.

| Setting | v5.4.3 | v5.4.4 | Notes |
|---------|--------|--------|-------|
| `worker.resources.limits.cpu` | `200m` | `1000m` | 5× increase |
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

> **Note:** The comment in `values.yaml` now explicitly documents that the memory limit bounds the size of the report the worker can generate. The scheduler places pods by their requests, which stay at `100m`/`128Mi`, so the 4Gi limit does not prevent scheduling on small nodes. What can block the worker is a `ResourceQuota` with `limits.memory` (or `limits.cpu`) in the namespace: see [Migration Steps](#migration-steps).

**Operational impact:**

- Only the worker changes. The manager pod template is identical in v5.4.3 and v5.4.4, so the manager does not restart.
- With `keda.enabled: true` (default), the worker runs as Jobs that the `reporter-worker` ScaledJob creates. No long-running worker pod exists to restart. The ScaledJob does not set `spec.rollout`, so when the upgrade changes it, KEDA deletes the Jobs of the previous spec, including Jobs that are generating a report. Their pods get the default 30 s termination grace period, not an unbounded graceful shutdown. Jobs created after the upgrade use the new limits.
- With `keda.enabled: false`, the worker is the `reporter-worker` Deployment. It rolls with `RollingUpdate` (`maxUnavailable: 0`), and each old pod gets the same 30 s grace period.
- A report interrupted this way runs again if its message returns to the queue. If it does not, the manager's stale-report reaper marks the report `Error` after 180 s without a worker heartbeat (`WORKER_HEARTBEAT_STALE_SEC`, default in app `4.10.0`). Upgrade when no report is in generation.
- The scheduler uses the requests (`100m`/`128Mi`, unchanged), so nodes with less than 4Gi allocatable still accept worker pods. The limit is what a `ResourceQuota` with `limits.memory` counts: with `maxReplicaCount: 5`, the worker Jobs can sum 5 CPU and 20Gi of limits, and Kubernetes refuses to create a Job pod that exceeds the quota. If your namespace has such a quota, raise it or override the limits:

```yaml
worker:
  resources:
    limits:
      memory: 2Gi  # Adjust to fit your quota and report sizes
```

> **Warning:** Reducing the memory limit below the default 4Gi may cause OOM failures when generating large reports. Monitor worker pod memory usage and adjust limits based on your actual report sizes.

## Configuration Changes

No new keys were added or removed. The change is in default values only.

| Setting | v5.4.3 | v5.4.4 | Notes |
|---------|--------|--------|-------|
| `worker.resources.limits.cpu` (default) | `200m` | `1000m` | Override if cluster CPU quota is constrained |
| `worker.resources.limits.memory` (default) | `256Mi` | `4Gi` | Override if cluster memory quota is constrained |

## Migration Steps

This upgrade requires no mandatory values changes. Only the worker changes: the ScaledJob (default) or the worker Deployment (`keda.enabled: false`). The manager does not restart.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Check whether the namespace has a `ResourceQuota` that counts limits. Node allocatable memory does not matter here, because the scheduler uses the requests:

```bash
kubectl get resourcequota -n <namespace>
kubectl describe resourcequota -n <namespace>
```

3. If the quota (`limits.memory`, `limits.cpu`) cannot hold up to 5 worker pods at the new limits next to the other pods, raise the quota or override the worker resources in your values file:

```yaml
worker:
  resources:
    limits:
      cpu: 500m      # Adjust to fit your cluster
      memory: 2Gi    # Adjust to fit your cluster
```

4. Wait until no report is in generation, then run the [upgrade command](#command-to-upgrade) with your values file (`-f`). Without `-f`, Helm reuses the stored values and an override from step 3 never reaches the release.

5. Check the new worker limits. The commands assume the release name `reporter`.

With `keda.enabled: true` (default), read the ScaledJob spec. Worker pods exist only while a report is in generation, and they carry only the `scaledjob.keda.sh/name=reporter-worker` label, so `-l app.kubernetes.io/name=reporter-worker` finds nothing:

```bash
kubectl get scaledjob reporter-worker -n <namespace> -o jsonpath='{.spec.jobTargetRef.template.spec.containers[0].resources}'
kubectl get pods -n <namespace> -l scaledjob.keda.sh/name=reporter-worker
```

With `keda.enabled: false`:

```bash
kubectl rollout status deployment/reporter-worker -n <namespace>
kubectl get deployment reporter-worker -n <namespace> -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

6. Monitor worker memory usage during report generation. Use `-l scaledjob.keda.sh/name=reporter-worker` with KEDA, and `-l app.kubernetes.io/name=reporter-worker` without it:

```bash
kubectl top pod -n <namespace> -l scaledjob.keda.sh/name=reporter-worker
```

> **Note:** With KEDA (default), the upgrade deletes the worker Jobs that are running; with `keda.enabled: false`, it rolls the worker Deployment. In both cases a report in generation is interrupted. See [Operational impact](#1-worker-resource-limits-increased-for-large-report-generation).

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n <namespace> --version 5.4.4 -f <your-values>.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n <namespace> --version 5.4.4 -f <your-values>.yaml
```

> **Note:** Pass the same values files (and any `--set`/`--set-file` flags) that you used at install time. When you pass any value, Helm does not reuse the stored values.
<!-- {% endraw %} -->
