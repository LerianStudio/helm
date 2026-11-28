# Helm Upgrade from v5.4.6 to v5.4.7

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 4.13.0](#1-application-version-bump-to-4130)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.12.0` to `4.13.0` for both the manager and worker components. No configuration changes, breaking changes, or new features are introduced.

| Field | v5.4.6 | v5.4.7 |
|-------|--------|--------|
| Chart version | `5.4.6` | `5.4.7` |
| App version | `4.12.0` | `4.13.0` |
| Manager image tag | `4.12.0` | `4.13.0` |
| Worker image tag | `4.12.0` | `4.13.0` |

## Fixes

### 1. Application version bump to 4.13.0

The manager and worker container image tags have been updated from `4.12.0` to `4.13.0`. This patch release includes bug fixes and minor improvements in the application layer.

| Component | v5.4.6 | v5.4.7 |
|-----------|--------|--------|
| `manager.image.tag` | `"4.12.0"` | `"4.13.0"` |
| `worker.image.tag` | `"4.12.0"` | `"4.13.0"` |
| Chart `appVersion` | `"4.12.0"` | `"4.13.0"` |

**Before (v5.4.6):**

```yaml
manager:
  image:
    tag: "4.12.0"

worker:
  image:
    tag: "4.12.0"
```

**After (v5.4.7):**

```yaml
manager:
  image:
    tag: "4.13.0"

worker:
  image:
    tag: "4.13.0"
```

> **Note:** The upgrade will trigger a rolling restart of both the manager and worker deployments to pull the new image tags.

## Migration Steps

This upgrade requires no configuration changes or operator intervention beyond running the upgrade command.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command during a maintenance window.

3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

4. Check that the new image tags are deployed:

```bash
kubectl get deployment -n <namespace> -l app.kubernetes.io/name=reporter-manager -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
kubectl get deployment -n <namespace> -l app.kubernetes.io/name=reporter-worker -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
```

5. Verify manager and worker logs for successful startup:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Existing configuration, secrets, and infrastructure components (MongoDB, RabbitMQ, Valkey) are not affected.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.7
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.7
```
