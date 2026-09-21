# Helm Upgrade from v4.3.2 to v4.3.3

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
  - [1. Manager image updated to 4.0.0](#1-manager-image-updated-to-400)
  - [2. Worker image updated to 4.0.0](#2-worker-image-updated-to-400)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `3.0.2` to `4.0.0` for both manager and worker components. No configuration changes, breaking changes, or new features are introduced. The upgrade only updates the container image tags.

| Field | v4.3.2 | v4.3.3 |
|-------|--------|--------|
| Chart version | `4.3.2` | `4.3.3` |
| App version | `3.0.2` | `4.0.0` |
| Manager image tag | `3.0.2` | `4.0.0` |
| Worker image tag | `3.0.2` | `4.0.0` |

## Application Version Update

### 1. Manager image updated to 4.0.0

The manager deployment image tag has been updated from `3.0.2` to `4.0.0`.

| Setting | v4.3.2 | v4.3.3 |
|---------|--------|--------|
| `manager.image.tag` | `"3.0.2"` | `"4.0.0"` |

**Before (v4.3.2):**

```yaml
manager:
  image:
    repository: lerianstudio/midaz-reporter-manager
    pullPolicy: IfNotPresent
    tag: "3.0.2"
```

**After (v4.3.3):**

```yaml
manager:
  image:
    repository: lerianstudio/midaz-reporter-manager
    pullPolicy: IfNotPresent
    tag: "4.0.0"
```

### 2. Worker image updated to 4.0.0

The worker deployment image tag has been updated from `3.0.2` to `4.0.0`.

| Setting | v4.3.2 | v4.3.3 |
|---------|--------|--------|
| `worker.image.tag` | `"3.0.2"` | `"4.0.0"` |

**Before (v4.3.2):**

```yaml
worker:
  image:
    repository: lerianstudio/midaz-reporter-worker
    pullPolicy: IfNotPresent
    tag: "3.0.2"
```

**After (v4.3.3):**

```yaml
worker:
  image:
    repository: lerianstudio/midaz-reporter-worker
    pullPolicy: IfNotPresent
    tag: "4.0.0"
```

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will trigger a rolling restart of both manager and worker deployments to pull the new `4.0.0` images.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

4. Check manager and worker logs to confirm the new version is running:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Existing configuration and secrets remain unchanged.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.3 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.3 -n <namespace>
```
