# Helm Upgrade from v4.3.4 to v4.3.5

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 4.2.0](#1-application-version-bump-to-420)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.1.0` to `4.2.0` for both manager and worker components. No configuration changes, breaking changes, or new features are introduced. The upgrade is a straightforward image tag update.

| Field | v4.3.4 | v4.3.5 |
|-------|--------|--------|
| Chart version | `4.3.4` | `4.3.5` |
| App version | `4.1.0` | `4.2.0` |
| Manager image tag | `4.1.0` | `4.2.0` |
| Worker image tag | `4.1.0` | `4.2.0` |

## Fixes

### 1. Application version bump to 4.2.0

The manager and worker container image tags have been updated from `4.1.0` to `4.2.0`. This update includes bug fixes and improvements in the application layer. The chart `appVersion` field has been updated to reflect this change.

| Component | v4.3.4 | v4.3.5 |
|-----------|--------|--------|
| Chart `appVersion` | `"4.1.0"` | `"4.2.0"` |
| `manager.image.tag` | `"4.1.0"` | `"4.2.0"` |
| `worker.image.tag` | `"4.1.0"` | `"4.2.0"` |

**Before (v4.3.4):**

```yaml
manager:
  image:
    tag: "4.1.0"

worker:
  image:
    tag: "4.1.0"
```

**After (v4.3.5):**

```yaml
manager:
  image:
    tag: "4.2.0"

worker:
  image:
    tag: "4.2.0"
```

> **Note:** The upgrade will trigger a rolling restart of both manager and worker deployments to pull and deploy the new image versions.

## Configuration Changes

No `values.yaml` keys were added, removed, or renamed. The only change is the default image tag values for manager and worker components.

| Setting | v4.3.4 | v4.3.5 | Notes |
|---------|--------|--------|-------|
| `manager.image.tag` | `"4.1.0"` | `"4.2.0"` | Automatic update unless pinned |
| `worker.image.tag` | `"4.1.0"` | `"4.2.0"` | Automatic update unless pinned |

> **Important:** If you have explicitly pinned image tags in your values override file, you must update them manually to `4.2.0` to receive the application updates. If you rely on chart defaults, the new tags will be applied automatically.

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will update the image tags and perform a rolling restart of the manager and worker deployments.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command during a maintenance window (optional, as rolling restart minimizes downtime).

3. Verify all pods are running with the new image version:

```bash
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
```

4. Check manager and worker logs for successful startup:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

5. Verify application health:

```bash
kubectl get pods -n <namespace>
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Pods will be replaced one at a time according to the deployment strategy configured in your values.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.5 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.5 -n <namespace>
```
