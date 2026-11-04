<!-- {% raw %} -->
# Helm Upgrade from v4.5.1 to v4.5.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Pod label stability improved to prevent unnecessary restarts](#1-pod-label-stability-improved-to-prevent-unnecessary-restarts)
  - [2. ConfigMap and Secret checksum calculation corrected](#2-configmap-and-secret-checksum-calculation-corrected)
- **[Metadata Changes](#metadata-changes)**
  - [1. Redundant source URL removed from Chart.yaml](#1-redundant-source-url-removed-from-chartyaml)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that fixes pod label stability and checksum calculation logic. These changes prevent unnecessary pod restarts on every Helm upgrade and ensure ConfigMap/Secret changes are correctly detected. The application version is unchanged.

| Field | v4.5.1 | v4.5.2 |
|-------|--------|--------|
| Chart version | `4.5.1` | `4.5.2` |
| App version | `3.0.0` | `3.0.0` |

## Fixes

### 1. Pod label stability improved to prevent unnecessary restarts

The `helm.sh/chart` label has been removed from the pod template labels. This label includes the chart version (e.g., `product-console-4.5.1`) and changes on every chart release, causing Kubernetes to detect a pod spec change and trigger a rolling restart even when no actual configuration or image has changed.

**Before (v4.5.1):**

```yaml
# _helpers.tpl
{{- define "product-console.labels" -}}
helm.sh/chart: {{ include "product-console.chart" . }}
{{ include "product-console.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

```yaml
# deployment.yaml
spec:
  template:
    metadata:
      labels:
        {{- include "product-console.labels" . | nindent 8 }}
```

**After (v4.5.2):**

```yaml
# _helpers.tpl
{{- define "product-console.labels" -}}
helm.sh/chart: {{ include "product-console.chart" . }}
{{ include "product-console.podLabels" . }}
{{- end }}

{{/*
Labels without helm.sh/chart, for the pod template: the chart version changes on
every release and would restart every pod each time.
*/}}
{{- define "product-console.podLabels" -}}
{{ include "product-console.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

```yaml
# deployment.yaml
spec:
  template:
    metadata:
      labels:
        {{- include "product-console.podLabels" . | nindent 8 }}
```

**What changed:**

- A new template helper `product-console.podLabels` has been introduced that excludes the `helm.sh/chart` label
- The `product-console.labels` helper now includes `helm.sh/chart` and calls `product-console.podLabels` for the remaining labels
- The deployment pod template now uses `product-console.podLabels` instead of `product-console.labels`
- The `helm.sh/chart` label remains on the Deployment resource itself (via `product-console.labels`), but is no longer applied to the pod template

**Operational impact:**

- **Before this fix:** Every Helm upgrade (even with no values changes) triggered a rolling restart because the `helm.sh/chart` label in the pod spec changed from `product-console-4.5.1` to `product-console-4.5.2`
- **After this fix:** Helm upgrades that only bump the chart version will **not** trigger pod restarts. Pods will only restart when actual configuration, secrets, or image tags change
- The `helm.sh/chart` label is still present on the Deployment resource for tracking purposes, but no longer affects pod stability

> **Important:** This upgrade will trigger **one final rolling restart** to apply the new label structure. Subsequent chart version upgrades (with no other changes) will not restart pods.

> **Note:** The `helm.sh/chart` label remains visible on the Deployment resource. Only the pod template labels are affected by this change.

### 2. ConfigMap and Secret checksum calculation corrected

The checksum annotations for ConfigMap and Secret changes have been corrected to hash only the `data` section of each resource, rather than the entire rendered YAML (which includes metadata that changes on every release).

**Before (v4.5.1):**

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
```

**After (v4.5.2):**

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ (include (print $.Template.BasePath "/configmap.yaml") . | fromYaml).data | toYaml | sha256sum }}
        checksum/secret: {{ (include (print $.Template.BasePath "/secrets.yaml") . | fromYaml).data | toYaml | sha256sum }}
```

**What changed:**

- The checksum calculation now parses the rendered ConfigMap/Secret YAML with `fromYaml`
- Extracts only the `.data` section
- Converts it back to YAML with `toYaml` before hashing
- This ensures only actual configuration data changes trigger the checksum to change

**Why this matters:**

- **Before this fix:** The checksum included metadata fields like `helm.sh/chart`, `app.kubernetes.io/version`, and other labels that change on every release, causing unnecessary pod restarts even when ConfigMap/Secret data was unchanged
- **After this fix:** The checksum only changes when the actual configuration or secret data changes, preventing false-positive restarts

**Operational impact:**

- Pods will only restart when ConfigMap or Secret **data** changes, not when chart metadata changes
- This works in conjunction with the pod label stability fix to minimize unnecessary restarts

> **Important:** This upgrade will trigger **one rolling restart** to apply the new checksum calculation. After this upgrade, pods will only restart when actual ConfigMap or Secret data changes.

> **Note:** The checksum annotations remain in the pod template. Only the calculation method has changed to be more precise.

## Metadata Changes

### 1. Redundant source URL removed from Chart.yaml

A duplicate source URL entry has been removed from the chart metadata. This is a cosmetic change with no operational impact.

| Field | v4.5.1 | v4.5.2 |
|-------|--------|--------|
| `sources` array length | 2 entries | 1 entry |

**Before (v4.5.1):**

```yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/product-console
  - https://github.com/LerianStudio/product-console
```

**After (v4.5.2):**

```yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/product-console
```

The application repository URL has been removed as it was redundant with the chart repository URL. This change does not affect chart functionality or deployment behavior.

## Migration Steps

This upgrade requires no configuration changes. The fixes are applied automatically during the Helm upgrade.

**Recommended upgrade process:**

1. **Preview the changes** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. **Schedule the upgrade during a maintenance window.** This upgrade will trigger a rolling restart to apply the new label structure and checksum calculation.

3. **Run the upgrade command:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.5.2 -n product-console
```

4. **Monitor the rolling restart:**

```bash
kubectl rollout status deployment/product-console -n product-console
```

5. **Verify all pods are running and healthy:**

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console
```

6. **Verify the new label structure.** Check that the `helm.sh/chart` label is absent from pod labels but present on the Deployment:

```bash
# Should NOT include helm.sh/chart
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console --show-labels

# Should include helm.sh/chart
kubectl get deployment product-console -n product-console --show-labels
```

7. **Test that subsequent upgrades do not restart pods.** After this upgrade, run a no-op upgrade to verify pods are not restarted:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.5.2 -n product-console --reuse-values
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console
```

The pod `AGE` column should show the pods were not recently restarted.

> **Note:** This upgrade triggers **one rolling restart** to apply the label and checksum fixes. After this upgrade, chart version bumps alone will not restart pods.

> **Important:** If you have custom monitoring or alerting based on the `helm.sh/chart` label on pods, update your queries to target the Deployment resource instead.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.2
```
<!-- {% endraw %} -->
