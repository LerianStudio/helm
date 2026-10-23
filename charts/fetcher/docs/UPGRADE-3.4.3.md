# Helm Upgrade from v3.4.2 to v3.4.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 3.1.1](#1-application-version-bump-to-311)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.4.2` to `3.4.3`. This is a **patch** release that updates the application version for both `manager` and `worker` components from `3.1.0` to `3.1.1`.

No breaking changes, no required `values.yaml` modifications, and no data migration are needed. The upgrade will roll both the `manager` and `worker` Deployments with the new image tags.

## Fixes

### 1. Application version bump to 3.1.1

Both `manager` and `worker` components have been updated to application version `3.1.1` (from `3.1.0`). This patch release includes bug fixes and minor improvements in the upstream `fetcher` application.

| Component | v3.4.2 | v3.4.3 |
|-----------|--------|--------|
| `manager.image.tag` | `"3.1.0"` | `"3.1.1"` |
| `worker.image.tag` | `"3.1.0"` | `"3.1.1"` |

**Image tags updated:**

```yaml
manager:
  image:
    repository: lerianstudio/fetcher-manager
    pullPolicy: IfNotPresent
    tag: "3.1.1"

worker:
  image:
    repository: lerianstudio/fetcher-worker
    pullPolicy: IfNotPresent
    tag: "3.1.1"
```

> **Note:** Consult the upstream `fetcher` application release notes for details on changes between `3.1.0` and `3.1.1`.

## Configuration Changes

No `values.yaml` keys were added, removed, or changed. The only modification is the default image tag values for both components.

| Setting | v3.4.2 | v3.4.3 |
|---------|--------|--------|
| `manager.image.tag` | `"3.1.0"` | `"3.1.1"` |
| `worker.image.tag` | `"3.1.0"` | `"3.1.1"` |

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will automatically roll both the `manager` and `worker` Deployments with the new image tags.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running after the upgrade:

```bash
kubectl get pods -n fetcher
```

4. Check manager and worker logs for any issues:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50
```

> **Note:** The upgrade will perform a rolling update of both Deployments. Existing pods will be terminated gracefully and replaced with new pods running version `3.1.1`.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.3 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.3 -n fetcher
```
