# Helm Upgrade from v3.1.0 to v3.1.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 3.1.0](#1-application-version-bump-to-310)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.1.0` to `3.1.1`. This is a **patch** release that updates the application version for both `manager` and `worker` components from `3.0.2` to `3.1.0`.

No breaking changes, no required `values.yaml` modifications, and no data migration are needed. The upgrade will trigger a rolling restart of both `manager` and `worker` Deployments to pull the new container images.

## Fixes

### 1. Application version bump to 3.1.0

Both `manager` and `worker` components have been updated to application version `3.1.0` (from `3.0.2`). The chart's `appVersion` field has also been updated to reflect this change.

| Component | v3.1.0 | v3.1.1 |
|-----------|--------|--------|
| Chart `appVersion` | `"3.0.2"` | `"3.1.0"` |
| `manager.image.tag` | `"3.0.2"` | `"3.1.0"` |
| `worker.image.tag` | `"3.0.2"` | `"3.1.0"` |

**Before (v3.1.0):**

```yaml
manager:
  image:
    repository: lerianstudio/fetcher-manager
    pullPolicy: IfNotPresent
    tag: "3.0.2"

worker:
  image:
    repository: lerianstudio/fetcher-worker
    pullPolicy: IfNotPresent
    tag: "3.0.2"
```

**After (v3.1.1):**

```yaml
manager:
  image:
    repository: lerianstudio/fetcher-manager
    pullPolicy: IfNotPresent
    tag: "3.1.0"

worker:
  image:
    repository: lerianstudio/fetcher-worker
    pullPolicy: IfNotPresent
    tag: "3.1.0"
```

> **Note:** Consult the upstream `fetcher` application release notes for details on changes between `3.0.2` and `3.1.0`. This upgrade will cause both `manager` and `worker` pods to restart with the new image versions.

> **Important:** The upgrade will perform a rolling restart of both Deployments. Ensure your `manager` and `worker` replicas are configured with appropriate values to maintain availability during the rollout. If you have `replicas: 1` for either component, expect brief downtime during the pod restart.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.1 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.1 -n fetcher
```

After the upgrade completes, verify all pods are running with the new image version:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager -o jsonpath='{.items[*].spec.containers[0].image}'
kubectl get pods -n fetcher -l app.kubernetes.io/component=worker -o jsonpath='{.items[*].spec.containers[0].image}'
```

Check manager and worker logs to confirm successful startup:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50
```
