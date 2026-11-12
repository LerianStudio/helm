# Helm Upgrade from v5.3.0 to v5.3.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version updated to stable 4.8.0 release](#1-application-version-updated-to-stable-480-release)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.7.0-beta.1` to the stable `4.8.0` release. No configuration changes or breaking changes are introduced. The upgrade only affects the container image tags for the manager and worker components.

| Field | v5.3.0 | v5.3.1 |
|-------|--------|--------|
| Chart version | `5.3.0` | `5.3.1` |
| App version | `4.7.0-beta.1` | `4.8.0` |
| Manager image tag | `4.7.0-beta.1` | `4.8.0` |
| Worker image tag | `4.7.0-beta.1` | `4.8.0` |

## Fixes

### 1. Application version updated to stable 4.8.0 release

The manager and worker container image tags have been updated from the beta release `4.7.0-beta.1` to the stable production release `4.8.0`. This change affects both the `appVersion` field in `Chart.yaml` and the default image tags in `values.yaml`.

| Component | v5.3.0 | v5.3.1 |
|-----------|--------|--------|
| Chart `appVersion` | `4.7.0-beta.1` | `4.8.0` |
| `manager.image.tag` | `4.7.0-beta.1` | `4.8.0` |
| `worker.image.tag` | `4.7.0-beta.1` | `4.8.0` |

**Before (v5.3.0):**

```yaml
manager:
  image:
    tag: "4.7.0-beta.1"

worker:
  image:
    tag: "4.7.0-beta.1"
```

**After (v5.3.1):**

```yaml
manager:
  image:
    tag: "4.8.0"

worker:
  image:
    tag: "4.8.0"
```

> **Note:** If you have pinned the image tags in your values overrides to `4.7.0-beta.1`, you may choose to remove those overrides to adopt the new default, or explicitly update them to `4.8.0`.

## Migration Steps

This upgrade requires no configuration changes or operator intervention. The Helm upgrade will automatically pull the new `4.8.0` images and perform a rolling restart of the manager Deployment.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

4. Verify the new image tags are deployed:

```bash
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-manager | grep Image:
```

5. Check application logs for any startup issues:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
```

> **Note:** Existing infrastructure components (MongoDB, RabbitMQ, Valkey) are not affected.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.3.1 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.3.1 -n <namespace>
```
