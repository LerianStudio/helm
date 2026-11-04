<!-- {% raw %} -->
# Helm Upgrade from v1.0.4 to v1.0.5

This guide helps operators upgrade the **Lerian BYOC agent** chart from version **1.0.4** to **1.0.5**. This is a patch release that fixes pod restart behavior during chart upgrades and removes an unused source reference.

## Topics

- **[Overview](#overview)**
- **[Changes in v1.0.5](#changes-in-v105)**
  - [Pod Label Template Fix](#pod-label-template-fix)
  - [Chart Metadata Cleanup](#chart-metadata-cleanup)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version **1.0.5** is a patch release that prevents unnecessary pod restarts during chart upgrades by removing the `helm.sh/chart` label from pod templates. It also removes an unused source reference from the chart metadata.

**What changed:**

- Pod template labels no longer include `helm.sh/chart` (prevents restarts on every chart upgrade)
- Removed unused source reference from `Chart.yaml`

**What stayed the same:**

- Application version remains `1.0.2`
- All configuration options remain unchanged
- All default values remain unchanged
- All RBAC, networking, and security settings remain unchanged

**Operational impact:**

This upgrade will **restart the agent pod once** to apply the new label structure. After this upgrade, future chart upgrades (that don't change the application version or configuration) will **not** restart the pod unnecessarily.

## Changes in v1.0.5

### Pod Label Template Fix

The chart now uses a separate template helper (`lerian-agent.podLabels`) for pod labels that excludes the `helm.sh/chart` label. This prevents pod restarts on every chart upgrade when only the chart version changes.

**Why this matters:**

Previously, every chart upgrade would restart the agent pod because the `helm.sh/chart` label (which includes the chart version) was applied to the pod template. Kubernetes detects this as a change to the pod spec and triggers a rollout. Since the agent uses a `Recreate` deployment strategy, this caused downtime on every chart upgrade—even when only documentation or non-functional chart metadata changed.

**Before (v1.0.4):**

The `lerian-agent.labels` helper was used directly in the pod template:

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "lerian-agent.labels" (dict "context" . "component" .Values.agent.name "name" .Values.agent.name) | nindent 8 }}
```

This included the `helm.sh/chart` label in the pod spec, causing restarts on every chart version bump.

**After (v1.0.5):**

A new `lerian-agent.podLabels` helper is used in the pod template:

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "lerian-agent.podLabels" (dict "context" . "component" .Values.agent.name "name" .Values.agent.name) | nindent 8 }}
```

The `lerian-agent.podLabels` helper includes all standard labels except `helm.sh/chart`:

```yaml
{{- define "lerian-agent.podLabels" -}}
{{ include "lerian-agent.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "lerian-agent.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}
```

The `helm.sh/chart` label is still present on the Deployment resource itself (via `lerian-agent.labels`), but not on the pod template.

**Operational impact:**

- **This upgrade (v1.0.4 → v1.0.5):** The agent pod will restart once to apply the new label structure
- **Future upgrades:** Chart upgrades that only bump the chart version (without changing app version or configuration) will **not** restart the pod
- **Label visibility:** The `helm.sh/chart` label remains on the Deployment resource for tracking purposes, but is removed from pods

> **Note:** The agent pod will restart during this upgrade. Any in-progress Helm operations will be interrupted. The agent will resume work after reconnecting to the control plane.

### Chart Metadata Cleanup

An unused source reference has been removed from the chart metadata.

**Before (v1.0.4):**

```yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/agent
  - https://github.com/LerianStudio/agent
```

**After (v1.0.5):**

```yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/agent
```

**Operational impact:**

This change has no functional impact on deployed resources. It only affects the chart metadata visible via `helm show chart`.

## Migration Steps

This upgrade requires no manual migration steps. The changes are applied automatically during the upgrade.

**To upgrade:**

1. Review your current values file (if you have one):

```bash
helm get values agent -n agent > current-values.yaml
```

2. Run the upgrade command (see below)

3. Verify the new pod is running with updated labels:

```bash
kubectl -n agent get pods -l app.kubernetes.io/name=agent
kubectl -n agent get pods -l app.kubernetes.io/name=agent -o jsonpath='{.items[0].metadata.labels}' | jq
```

4. Verify the `helm.sh/chart` label is present on the Deployment but not on the pod:

```bash
# Check Deployment labels (should include helm.sh/chart)
kubectl -n agent get deployment lerian-agent -o jsonpath='{.metadata.labels}' | jq

# Check pod labels (should NOT include helm.sh/chart)
kubectl -n agent get pods -l app.kubernetes.io/name=agent -o jsonpath='{.items[0].metadata.labels}' | jq
```

> **Note:** The agent pod will restart during the upgrade. Any in-progress Helm operations will be interrupted. The agent will resume work after reconnecting to the control plane.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.5
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.5
```
<!-- {% endraw %} -->
