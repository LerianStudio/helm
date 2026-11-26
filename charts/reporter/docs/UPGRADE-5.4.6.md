# Helm Upgrade from v5.4.5 to v5.4.6

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 4.12.0](#1-application-version-bump-to-4120)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.11.0` to `4.12.0` for both the manager and worker components. No configuration changes, breaking changes, or new features are introduced.

| Field | v5.4.5 | v5.4.6 |
|-------|--------|--------|
| Chart version | `5.4.5` | `5.4.6` |
| App version | `4.11.0` | `4.12.0` |
| Manager image tag | `4.11.0` | `4.12.0` |
| Worker image tag | `4.11.0` | `4.12.0` |

## Fixes

### 1. Application version bump to 4.12.0

The manager and worker image tags have been updated from `4.11.0` to `4.12.0`. This patch release includes bug fixes and minor improvements in the application layer.

| Component | v5.4.5 | v5.4.6 |
|-----------|--------|--------|
| `manager.image.tag` | `"4.11.0"` | `"4.12.0"` |
| `worker.image.tag` | `"4.11.0"` | `"4.12.0"` |
| Chart `appVersion` | `"4.11.0"` | `"4.12.0"` |

**Before (v5.4.5):**

```yaml
manager:
  image:
    tag: "4.11.0"

worker:
  image:
    tag: "4.11.0"
```

**After (v5.4.6):**

```yaml
manager:
  image:
    tag: "4.12.0"

worker:
  image:
    tag: "4.12.0"
```

> **Note:** The upgrade will trigger a rolling restart of both the manager and worker deployments to pull the new image tags.

## Migration Steps

This upgrade requires no configuration changes or operator intervention. The Helm upgrade will automatically update the image tags and perform a rolling restart of the manager and worker deployments.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running with the new image version:

```bash
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
```

4. Check manager and worker logs to confirm successful startup:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

> **Note:** The rolling restart strategy ensures zero-downtime deployment. Existing pods will continue serving traffic until new pods are ready.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.6
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.6
```
