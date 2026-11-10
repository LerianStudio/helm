<!-- {% raw %} -->
# Helm Upgrade from v5.4.0 to v5.4.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
  - [1. Manager image updated to 4.9.0](#1-manager-image-updated-to-490)
  - [2. Worker image updated to 4.9.0](#2-worker-image-updated-to-490)
- **[Fixes](#fixes)**
  - [1. MongoDB existingSecret template formatting corrected](#1-mongodb-existingsecret-template-formatting-corrected)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.8.0` to `4.9.0` for both the manager and worker components. The release also includes a minor formatting fix for the MongoDB `existingSecret` template. No configuration changes, breaking changes, or new features are introduced in the chart itself.

| Field | v5.4.0 | v5.4.1 |
|-------|--------|--------|
| Chart version | `5.4.0` | `5.4.1` |
| App version | `4.8.0` | `4.9.0` |
| Manager image tag | `4.8.0` | `4.9.0` |
| Worker image tag | `4.8.0` | `4.9.0` |

## Application Version Update

### 1. Manager image updated to 4.9.0

The manager component image tag has been updated from `4.8.0` to `4.9.0`.

| Setting | v5.4.0 | v5.4.1 |
|---------|--------|--------|
| `manager.image.tag` | `"4.8.0"` | `"4.9.0"` |

**Before (v5.4.0):**

```yaml
manager:
  image:
    tag: "4.8.0"
```

**After (v5.4.1):**

```yaml
manager:
  image:
    tag: "4.9.0"
```

### 2. Worker image updated to 4.9.0

The worker component image tag has been updated from `4.8.0` to `4.9.0`.

| Setting | v5.4.0 | v5.4.1 |
|---------|--------|--------|
| `worker.image.tag` | `"4.8.0"` | `"4.9.0"` |

**Before (v5.4.0):**

```yaml
worker:
  image:
    tag: "4.8.0"
```

**After (v5.4.1):**

```yaml
worker:
  image:
    tag: "4.9.0"
```

## Fixes

### 1. MongoDB existingSecret template formatting corrected

The `mongodb.auth.existingSecret` template has been reformatted to remove unnecessary line breaks. This change improves readability but does not affect the rendered output or functionality.

| Setting | v5.4.0 | v5.4.1 |
|---------|--------|--------|
| `mongodb.auth.existingSecret` | Multi-line template with line break | Single-line template |

**Before (v5.4.0):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname"
      . }}{{ end }}'
```

**After (v5.4.1):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

> **Note:** This is a cosmetic change that does not affect the behavior of the chart. The rendered secret name remains identical.

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will trigger a rolling restart of both the manager and worker deployments to pull the new image versions.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command during a maintenance window.

3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n reporter
```

4. Check that the new image versions are deployed:

```bash
kubectl describe pod -n reporter -l app.kubernetes.io/name=reporter-manager | grep Image:
kubectl describe pod -n reporter -l app.kubernetes.io/name=reporter-worker | grep Image:
```

5. Verify application logs for both components:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n reporter -l scaledjob.keda.sh/name=reporter-worker --tail=50
```

> **Note:** The upgrade triggers a rolling restart of the manager Deployment (and of the worker Deployment when KEDA is disabled). With the default KEDA ScaledJob configuration, KEDA will delete existing worker Jobs and create new ones with the updated image version.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.1
```
<!-- {% endraw %} -->
