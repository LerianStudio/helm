# Helm Upgrade from v4.3.3 to v4.3.4

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
  - [1. Manager image updated to 4.1.0](#1-manager-image-updated-to-410)
  - [2. Worker image updated to 4.1.0](#2-worker-image-updated-to-410)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.0.0` to `4.1.0` for both the manager and worker components. No configuration changes, breaking changes, or new features are introduced in the chart itself.

| Field | v4.3.3 | v4.3.4 |
|-------|--------|--------|
| Chart version | `4.3.3` | `4.3.4` |
| App version | `4.0.0` | `4.1.0` |
| Manager image tag | `4.0.0` | `4.1.0` |
| Worker image tag | `4.0.0` | `4.1.0` |

## Application Version Update

### 1. Manager image updated to 4.1.0

The manager component image tag has been updated from `4.0.0` to `4.1.0`.

| Setting | v4.3.3 | v4.3.4 |
|---------|--------|--------|
| `manager.image.tag` | `"4.0.0"` | `"4.1.0"` |

**Before (v4.3.3):**

```yaml
manager:
  image:
    tag: "4.0.0"
```

**After (v4.3.4):**

```yaml
manager:
  image:
    tag: "4.1.0"
```

### 2. Worker image updated to 4.1.0

The worker component image tag has been updated from `4.0.0` to `4.1.0`.

| Setting | v4.3.3 | v4.3.4 |
|---------|--------|--------|
| `worker.image.tag` | `"4.0.0"` | `"4.1.0"` |

**Before (v4.3.3):**

```yaml
worker:
  image:
    tag: "4.0.0"
```

**After (v4.3.4):**

```yaml
worker:
  image:
    tag: "4.1.0"
```

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will trigger a rolling restart of both the manager and worker deployments to pull the new image versions.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command during a maintenance window.

3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

4. Check that the new image versions are deployed:

```bash
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-manager | grep Image:
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-worker | grep Image:
```

5. Verify application logs for both components:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Ensure your deployment strategy and replica counts support zero-downtime updates.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.4 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.4 -n reporter
```
