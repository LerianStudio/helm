<!-- {% raw %} -->
# Helm Upgrade from v5.4.4 to v5.4.5

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 4.11.0](#1-application-version-bump-to-4110)
  - [2. MongoDB existingSecret value formatting corrected](#2-mongodb-existingsecret-value-formatting-corrected)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.10.0` to `4.11.0` and corrects a YAML formatting issue in the MongoDB subchart configuration. No breaking changes or configuration migrations are required.

| Field | v5.4.4 | v5.4.5 |
|-------|--------|--------|
| Chart version | `5.4.4` | `5.4.5` |
| App version | `4.10.0` | `4.11.0` |
| Manager image tag | `4.10.0` | `4.11.0` |
| Worker image tag | `4.10.0` | `4.11.0` |

## Fixes

### 1. Application version bump to 4.11.0

The manager and worker image tags have been updated from `4.10.0` to `4.11.0`, and the chart `appVersion` field reflects this change.

| Component | v5.4.4 | v5.4.5 |
|-----------|--------|--------|
| Chart `appVersion` | `"4.10.0"` | `"4.11.0"` |
| `manager.image.tag` | `"4.10.0"` | `"4.11.0"` |
| `worker.image.tag` | `"4.10.0"` | `"4.11.0"` |

**Before (v5.4.4):**

```yaml
manager:
  image:
    tag: "4.10.0"

worker:
  image:
    tag: "4.11.0"
```

**After (v5.4.5):**

```yaml
manager:
  image:
    tag: "4.11.0"

worker:
  image:
    tag: "4.11.0"
```

> **Note:** This upgrade will trigger a rolling restart of both manager and worker deployments to pull the new image tags.

### 2. MongoDB existingSecret value formatting corrected

The `mongodb.auth.existingSecret` field in `values.yaml` has been reformatted to improve readability. The template logic remains functionally identical — this is a cosmetic change that splits a long line across two lines.

| Setting | v5.4.4 | v5.4.5 |
|---------|--------|--------|
| `mongodb.auth.existingSecret` | Single-line template string | Multi-line template string (same logic) |

**Before (v5.4.4):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

**After (v5.4.5):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname"
      . }}{{ end }}'
```

The rendered output is unchanged. When the MongoDB subchart is enabled, the template evaluates to the subchart's generated Secret name; when disabled, it evaluates to an empty string.

> **Note:** This change does not affect the behavior of the chart. No values override is required.

## Migration Steps

This upgrade requires no configuration changes or manual intervention. The Helm upgrade will automatically:

1. Update the manager and worker deployments to use image tag `4.11.0`
2. Trigger a rolling restart of both deployments

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

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Existing MongoDB, RabbitMQ, and Valkey pods are not affected.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.5
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.5
```
<!-- {% endraw %} -->
