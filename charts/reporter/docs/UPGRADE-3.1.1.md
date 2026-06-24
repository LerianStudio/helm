# Helm Upgrade from v3.1.0 to v3.1.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 2.1.2](#1-application-version-bump-to-212)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `2.1.1` to `2.1.2` for both manager and worker components. No configuration changes, breaking changes, or new features are introduced.

| Field | v3.1.0 | v3.1.1 |
|-------|--------|--------|
| Chart version | `3.1.0` | `3.1.1` |
| App version | `2.1.1` | `2.1.2` |
| Manager image tag | `2.1.1` | `2.1.2` |
| Worker image tag | `2.1.1` | `2.1.2` |

## Fixes

### 1. Application version bump to 2.1.2

The manager and worker image tags have been updated from `2.1.1` to `2.1.2`. This patch release includes bug fixes and stability improvements in the application layer.

| Component | v3.1.0 | v3.1.1 |
|-----------|--------|--------|
| `manager.image.tag` | `"2.1.1"` | `"2.1.2"` |
| `worker.image.tag` | `"2.1.1"` | `"2.1.2"` |
| Chart `appVersion` | `"2.1.1"` | `"2.1.2"` |

**Before (v3.1.0):**

```yaml
manager:
  image:
    tag: "2.1.1"

worker:
  image:
    tag: "2.1.1"
```

**After (v3.1.1):**

```yaml
manager:
  image:
    tag: "2.1.2"

worker:
  image:
    tag: "2.1.2"
```

> **Note:** The upgrade will trigger a rolling restart of both manager and worker deployments to pull the new image tags.

## Migration Steps

This upgrade requires no configuration changes or manual intervention. The Helm upgrade will automatically update the image tags and perform a rolling restart of the manager and worker deployments.

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

5. Verify the deployed image tags:

```bash
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-manager | grep Image:
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-worker | grep Image:
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Existing configuration, secrets, and infrastructure components (MongoDB, RabbitMQ, Valkey) are not affected.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 3.1.1 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 3.1.1 -n <namespace>
```
