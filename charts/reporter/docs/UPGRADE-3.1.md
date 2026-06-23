# Helm Upgrade from v3.0.0 to v3.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version bump to 2.1.1](#1-application-version-bump-to-211)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor maintenance release that updates the application version from `2.0.0` to `2.1.1` for both manager and worker components. No breaking changes, new configuration fields, or template modifications are included.

| Field | v3.0.0 | v3.1.0 |
|-------|--------|--------|
| Chart version | `3.0.0` | `3.1.0` |
| App version | `1.2.0` | `2.1.1` |
| Manager image tag | `2.0.0` | `2.1.1` |
| Worker image tag | `2.0.0` | `2.1.1` |

## Features

### 1. Application version bump to 2.1.1

The manager and worker container image tags have been updated from `2.0.0` to `2.1.1`, and the chart `appVersion` field has been updated to reflect this change.

| Component | v3.0.0 | v3.1.0 |
|-----------|--------|--------|
| `manager.image.tag` | `"2.0.0"` | `"2.1.1"` |
| `worker.image.tag` | `"2.0.0"` | `"2.1.1"` |
| Chart `appVersion` | `"1.2.0"` | `"2.1.1"` |

**Updated image configuration (v3.1.0):**

```yaml
manager:
  image:
    repository: lerianstudio/midaz-reporter-manager
    pullPolicy: IfNotPresent
    tag: "2.1.1"

worker:
  image:
    repository: lerianstudio/midaz-reporter-worker
    pullPolicy: IfNotPresent
    tag: "2.1.1"
```

> **Note:** The upgrade will trigger a rolling restart of both manager and worker deployments to pull the new image versions. Ensure the `2.1.1` images are available in your container registry before upgrading.

## Configuration Changes

No `values.yaml` keys were added, removed, or renamed. The only change is the default image tag for manager and worker components.

| Setting | v3.0.0 | v3.1.0 | Notes |
|---------|--------|--------|-------|
| `manager.image.tag` | `"2.0.0"` | `"2.1.1"` | Updated to match new application version |
| `worker.image.tag` | `"2.0.0"` | `"2.1.1"` | Updated to match new application version |

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will automatically update the manager and worker image tags and trigger a rolling restart of both deployments.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Verify that the `2.1.1` images are available in your container registry:

```bash
docker pull lerianstudio/midaz-reporter-manager:2.1.1
docker pull lerianstudio/midaz-reporter-worker:2.1.1
```

3. Run the upgrade command during a maintenance window.
4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

5. Check that the new image versions are deployed:

```bash
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-manager | grep Image:
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-worker | grep Image:
```

6. Verify application logs for both components:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Existing pods will be terminated gracefully and replaced with new pods running the `2.1.1` images.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 3.1.0 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 3.1.0 -n <namespace>
```
