# Helm Upgrade from v4.1.0 to v4.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version bump to 3.0.0](#1-application-version-bump-to-300)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that updates the reporter application from version `2.4.0` to `3.0.0`. Both the manager and worker components are upgraded to the new application version. No configuration changes, breaking changes, or template modifications are included in this release.

| Field | v4.1.0 | v4.2.0 |
|-------|--------|--------|
| Chart version | `4.1.0` | `4.2.0` |
| App version | `2.4.0` | `3.0.0` |
| Manager image tag | `2.4.0` | `3.0.0` |
| Worker image tag | `2.4.0` | `3.0.0` |

## Features

### 1. Application version bump to 3.0.0

The manager and worker container images have been updated from `2.4.0` to `3.0.0`. This upgrade includes application-level changes in the reporter service. The chart's `appVersion` field has been updated to reflect this change.

| Component | v4.1.0 | v4.2.0 |
|-----------|--------|--------|
| Chart `appVersion` | `"2.4.0"` | `"3.0.0"` |
| `manager.image.tag` | `"2.4.0"` | `"3.0.0"` |
| `worker.image.tag` | `"2.4.0"` | `"3.0.0"` |

**Before (v4.1.0):**

```yaml
manager:
  image:
    tag: "2.4.0"

worker:
  image:
    tag: "2.4.0"
```

**After (v4.2.0):**

```yaml
manager:
  image:
    tag: "3.0.0"

worker:
  image:
    tag: "3.0.0"
```

> **Note:** Consult the reporter application release notes for version `3.0.0` to understand application-level changes, new features, bug fixes, or behavioral modifications included in this image update.

## Configuration Changes

No `values.yaml` keys were added, removed, or renamed in this release. The only changes are the default image tag values for the manager and worker components.

| Setting | v4.1.0 | v4.2.0 | Notes |
|---------|--------|--------|-------|
| `manager.image.tag` | `"2.4.0"` | `"3.0.0"` | Application version update |
| `worker.image.tag` | `"2.4.0"` | `"3.0.0"` | Application version update |

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will trigger a rolling restart of both the manager and worker deployments to pull and run the new `3.0.0` image tags.

**Recommended upgrade process:**

1. Review the reporter application release notes for version `3.0.0` to understand any application-level changes or new requirements.

2. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

3. Run the upgrade command during a maintenance window if required by application-level changes.

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

5. Check manager and worker logs to confirm successful startup with the new version:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

6. Verify the deployed image versions:

```bash
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-manager | grep Image:
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-worker | grep Image:
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Ensure your deployment strategy and replica counts provide adequate availability during the rollout.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.2.0 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.2.0 -n <namespace>
```
