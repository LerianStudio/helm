# Helm Upgrade from v4.3.12 to v4.3.13

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
  - [1. Manager image updated to 4.5.0](#1-manager-image-updated-to-450)
  - [2. Worker image updated to 4.5.0](#2-worker-image-updated-to-450)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.2.0` to `4.5.0` for both manager and worker components. No configuration changes, breaking changes, or new features are introduced in the chart itself — this is purely an application image version bump.

| Field | v4.3.12 | v4.3.13 |
|-------|---------|---------|
| Chart version | `4.3.12` | `4.3.13` |
| App version | `4.2.0` | `4.5.0` |
| Manager image tag | `4.2.0` | `4.5.0` |
| Worker image tag | `4.2.0` | `4.5.0` |

## Application Version Update

### 1. Manager image updated to 4.5.0

The manager deployment image tag has been updated from `4.2.0` to `4.5.0`.

| Setting | v4.3.12 | v4.3.13 |
|---------|---------|---------|
| `manager.image.tag` | `"4.2.0"` | `"4.5.0"` |

**Before (v4.3.12):**

```yaml
manager:
  image:
    tag: "4.2.0"
```

**After (v4.3.13):**

```yaml
manager:
  image:
    tag: "4.5.0"
```

> **Note:** If you have pinned the manager image tag in your values override file, you may choose to keep the existing version or update to `4.5.0`. The chart default will use `4.5.0` if no override is provided.

### 2. Worker image updated to 4.5.0

The worker deployment image tag has been updated from `4.2.0` to `4.5.0`.

| Setting | v4.3.12 | v4.3.13 |
|---------|---------|---------|
| `worker.image.tag` | `"4.2.0"` | `"4.5.0"` |

**Before (v4.3.12):**

```yaml
worker:
  image:
    tag: "4.2.0"
```

**After (v4.3.13):**

```yaml
worker:
  image:
    tag: "4.5.0"
```

> **Note:** If you have pinned the worker image tag in your values override file, you may choose to keep the existing version or update to `4.5.0`. The chart default will use `4.5.0` if no override is provided.

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will trigger a rolling restart of both manager and worker deployments to pull the new image versions.

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

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Ensure your deployment strategy and replica counts are configured to maintain availability during the rollout.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.13 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.13 -n reporter
```
