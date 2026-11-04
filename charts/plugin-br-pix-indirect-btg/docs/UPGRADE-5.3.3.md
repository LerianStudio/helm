<!-- {% raw %} -->
# Helm Upgrade from v5.3.2 to v5.3.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Removed helm.sh/chart label from pod templates](#1-removed-helmshchart-label-from-pod-templates)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that removes the `helm.sh/chart` label from pod template labels in all five service deployments. The application version remains `1.14.0` and no configuration changes are required. This is a non-breaking change that improves Helm upgrade behavior by preventing unnecessary pod restarts when the chart version changes.

The expected upgrade path is an in-place Helm upgrade with no required operator actions.

| Component | v5.3.2 | v5.3.3 |
|-----------|--------|--------|
| Chart version | `5.3.2` | `5.3.3` |
| App version | `1.14.0` | `1.14.0` |

## Fixes

### 1. Removed helm.sh/chart label from pod templates

The `helm.sh/chart` label has been removed from the pod template labels in all five service deployments (inbound, outbound, pix, reconciliation, and schedule).

**What changed:**

The pod template label generation has been modified to exclude the `helm.sh/chart` label while retaining all other standard labels:

**Before (v5.3.2):**

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "inbound.labels" (dict "context" . "name" .Values.inbound.name ) | nindent 8 }}
```

**After (v5.3.3):**

```yaml
spec:
  template:
    metadata:
      labels:
        {{- omit (include "inbound.labels" (dict "context" . "name" .Values.inbound.name ) | fromYaml) "helm.sh/chart" | toYaml | nindent 8 }}
```

This change applies to all five deployment templates:

- `templates/inbound/deployment.yaml`
- `templates/outbound/deployment.yaml`
- `templates/pix/deployment.yaml`
- `templates/reconciliation/deployment.yaml`
- `templates/schedule/deployment.yaml`

**Why it matters:**

The `helm.sh/chart` label includes the chart version (e.g., `plugin-br-pix-indirect-btg-5.3.2`). When this label is present in the pod template, Kubernetes detects a change in the Deployment spec every time the chart version is bumped, triggering a rolling restart of all pods even when no actual application or configuration changes have occurred.

By removing this label from the pod template (while keeping it on the Deployment resource itself), Helm upgrades that only bump the chart version will no longer cause unnecessary pod restarts.

**Operational impact:**

After upgrading to v5.3.3, future chart upgrades that only change the chart version (e.g., v5.3.3 → v5.3.4) will **not** trigger pod restarts unless there are actual changes to the pod template (image tags, environment variables, volumes, etc.).

The `helm.sh/chart` label remains present on:
- Deployment metadata labels
- Service metadata labels
- ConfigMap metadata labels
- Secret metadata labels
- All other resource types

Only the pod template labels are affected by this change.

**Labels retained on pod templates:**

The following standard labels continue to be applied to all pod templates:

- `app.kubernetes.io/name`
- `app.kubernetes.io/instance`
- `app.kubernetes.io/version`
- `app.kubernetes.io/managed-by`
- `app.kubernetes.io/component`

> **Note:** This change does **not** affect existing pods. The label removal only takes effect when pods are recreated (either through a rolling update triggered by actual configuration changes, or through manual pod deletion).

> **Important:** This upgrade from v5.3.2 to v5.3.3 **will** trigger a rolling restart of all five service deployments because the pod template label set is changing. However, subsequent chart-only version bumps will not trigger restarts.

## Migration Steps

No operator actions are required for this upgrade. The change is fully backward-compatible and will take effect automatically.

**Optional verification steps:**

1. After upgrading, verify that all pods are running and healthy:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg
```

2. Inspect a pod's labels to confirm the `helm.sh/chart` label is no longer present:

```bash
kubectl get pod -n midaz-plugins -l app.kubernetes.io/component=pix -o jsonpath='{.items[0].metadata.labels}' | jq
```

Expected output should **not** include a `helm.sh/chart` key.

3. Verify that the Deployment resource still has the `helm.sh/chart` label:

```bash
kubectl get deployment -n midaz-plugins plugin-br-pix-indirect-btg-pix -o jsonpath='{.metadata.labels}' | jq
```

Expected output **should** include `"helm.sh/chart": "plugin-br-pix-indirect-btg-5.3.3"`.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.3.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.3.3
```
<!-- {% endraw %} -->
