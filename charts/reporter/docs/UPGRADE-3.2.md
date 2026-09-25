# Helm Upgrade from v3.1.1 to v3.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version bump to 2.3.0](#1-application-version-bump-to-230)
  - [2. Autoscaling-aware replica management](#2-autoscaling-aware-replica-management)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that updates the application version to `2.3.0` and fixes a template bug where static replica counts were rendered even when HorizontalPodAutoscaler was enabled. No breaking changes are introduced.

| Field | v3.1.1 | v3.2.0 |
|-------|--------|--------|
| Chart version | `3.1.1` | `3.2.0` |
| App version | `2.1.2` | `2.3.0` |
| Manager image tag | `2.1.2` | `2.3.0` |
| Worker image tag | `2.1.2` | `2.3.0` |

## Features

### 1. Application version bump to 2.3.0

The manager and worker image tags have been updated from `2.1.2` to `2.3.0`, and the chart `appVersion` field reflects this change.

| Component | v3.1.1 | v3.2.0 |
|-----------|--------|--------|
| `manager.image.tag` | `"2.1.2"` | `"2.3.0"` |
| `worker.image.tag` | `"2.1.2"` | `"2.3.0"` |
| Chart `appVersion` | `"2.1.2"` | `"2.3.0"` |

The upgrade will trigger a rolling restart of both manager and worker deployments to pull the new image versions.

### 2. Autoscaling-aware replica management

The manager and worker Deployment templates now conditionally render the `replicas` field based on whether HorizontalPodAutoscaler is enabled. This prevents conflicts between static replica counts and HPA-managed scaling.

**Before (v3.1.1):**

```yaml
# manager/deployment.yaml
spec:
  replicas: {{ .Values.manager.replicaCount }}
  selector:
    matchLabels:
      ...
```

```yaml
# worker/deployment.yaml
spec:
  replicas: {{ .Values.worker.replicaCount }}
  selector:
    matchLabels:
      ...
```

**After (v3.2.0):**

```yaml
# manager/deployment.yaml
spec:
  {{- if not .Values.manager.autoscaling.enabled }}
  replicas: {{ .Values.manager.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      ...
```

```yaml
# worker/deployment.yaml
spec:
  {{- if not .Values.worker.autoscaling.enabled }}
  replicas: {{ .Values.worker.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      ...
```

**Operational impact:**

- When `manager.autoscaling.enabled=false` (default), the Deployment renders with `replicas: <manager.replicaCount>` as before.
- When `manager.autoscaling.enabled=true`, the `replicas` field is omitted from the Deployment spec, allowing the HPA to control replica count without conflicts.
- The same logic applies to the worker component.

> **Note:** This change only affects the rendered manifest structure. If you are not using HPA (`autoscaling.enabled=false`), the upgrade behavior is identical to previous versions.

## Configuration Changes

No `values.yaml` keys were added, removed, or renamed. The change is in template rendering logic only.

| Setting | v3.1.1 | v3.2.0 | Notes |
|---------|--------|--------|-------|
| `manager.image.tag` | `"2.1.2"` | `"2.3.0"` | Updated to match new app version |
| `worker.image.tag` | `"2.1.2"` | `"2.3.0"` | Updated to match new app version |
| `manager.replicaCount` | `1` | `1` | Now conditionally rendered based on `manager.autoscaling.enabled` |
| `worker.replicaCount` | `1` | `1` | Now conditionally rendered based on `worker.autoscaling.enabled` |

## Migration Steps

This upgrade requires no mandatory values changes. The Helm upgrade will roll the manager and worker deployments to the new image version.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. If you are using HPA (`manager.autoscaling.enabled=true` or `worker.autoscaling.enabled=true`), verify that the HPA resources are correctly configured before upgrading:

```bash
kubectl get hpa -n <namespace>
kubectl describe hpa -n <namespace> reporter-manager
kubectl describe hpa -n <namespace> reporter-worker
```

3. Run the upgrade command during a maintenance window.
4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

5. Check that the new image version is deployed:

```bash
kubectl get deployment -n <namespace> reporter-manager -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get deployment -n <namespace> reporter-worker -o jsonpath='{.spec.template.spec.containers[0].image}'
```

6. If using HPA, verify that the `replicas` field is absent from the Deployment spec:

```bash
kubectl get deployment -n <namespace> reporter-manager -o yaml | grep -A2 "^spec:"
kubectl get deployment -n <namespace> reporter-worker -o yaml | grep -A2 "^spec:"
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. Ensure your cluster has sufficient capacity to handle the rollout.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 3.2.0 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 3.2.0 -n <namespace>
```
