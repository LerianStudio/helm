<!-- {% raw %} -->
# Helm Upgrade from v10.3.3 to v10.3.4

## Topics

- **[Fixes](#fixes)**
  - [1. Pod label template fix for immutable chart version label](#1-pod-label-template-fix-for-immutable-chart-version-label)
- **[Documentation Updates](#documentation-updates)**
  - [1. Removed external documentation links](#1-removed-external-documentation-links)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Pod label template fix for immutable chart version label

This release fixes a critical template issue where the `helm.sh/chart` label was included in pod templates, causing unnecessary pod restarts on every chart upgrade. The chart now uses separate label templates for pod specs (`podLabels`) and other resources (`labels`).

#### What Changed

The chart introduces new helper templates that exclude the `helm.sh/chart` label from pod templates:

- `midaz.podLabels` — labels for ledger pod templates (without `helm.sh/chart`)
- `midaz-crm.podLabels` — labels for CRM pod templates (without `helm.sh/chart`)
- `midaz-tracer.podLabels` — labels for tracer pod templates (without `helm.sh/chart`)

The existing `midaz.labels`, `midaz-crm.labels`, and `midaz-tracer.labels` templates continue to include the `helm.sh/chart` label for use on Deployments, Jobs, CronJobs, Services, and other non-pod resources.

**Before (v10.3.3):**

```yaml
# _helpers.tpl
{{- define "midaz.labels" -}}
helm.sh/chart: {{ include "midaz.chart" .context }}
{{ include "midaz.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "ledger.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}
```

```yaml
# ledger/deployment.yaml (pod template)
labels:
  {{- include "midaz.labels" (dict "context" . "component" .Values.ledger.name "name" .Values.ledger.name ) | nindent 8 }}
```

**After (v10.3.4):**

```yaml
# _helpers.tpl
{{- define "midaz.podLabels" -}}
{{ include "midaz.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "ledger.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{- define "midaz.labels" -}}
helm.sh/chart: {{ include "midaz.chart" .context }}
{{ include "midaz.podLabels" . }}
{{- end }}
```

```yaml
# ledger/deployment.yaml (pod template)
labels:
  {{- include "midaz.podLabels" (dict "context" . "component" .Values.ledger.name "name" .Values.ledger.name ) | nindent 8 }}
```

The following pod templates now use the new `podLabels` helpers:

| Resource | Template Changed |
|----------|------------------|
| `ledger/deployment.yaml` | `midaz.labels` → `midaz.podLabels` |
| `ledger/migrations-job.yaml` | `midaz.labels` → `midaz.podLabels` |
| `ledger/partition-cronjob.yaml` | `midaz.labels` → `midaz.podLabels` |
| `ledger/partition-reconcile-job.yaml` | `midaz.labels` → `midaz.podLabels` |
| `crm/deployment.yaml` | `midaz-crm.labels` → `midaz-crm.podLabels` |
| `tracer/deployment.yaml` | `midaz-tracer.labels` → `midaz-tracer.podLabels` |
| `tracer/migrations-job.yaml` | `midaz-tracer.labels` → `midaz-tracer.podLabels` |

#### Why This Matters

In Kubernetes, labels in a Deployment's pod template are immutable once the Deployment is created. When the `helm.sh/chart` label (which includes the chart version) was part of the pod template, every chart upgrade — even a patch version bump with no functional changes — triggered a rolling restart of all pods because Kubernetes detected a change in the pod template.

By removing the `helm.sh/chart` label from pod templates, this release ensures that:

- **Pods only restart when necessary**: Future chart upgrades will only trigger pod restarts when the pod spec actually changes (image version, environment variables, resource limits, etc.)
- **Faster upgrades**: Upgrades that only change chart metadata or non-pod resources (like Services or ConfigMaps) will complete without restarting pods
- **Reduced downtime**: Applications with long startup times or strict availability requirements benefit from fewer unnecessary restarts

> **Important:** This upgrade **will still trigger a pod restart** because the pod template labels are changing from the old format (with `helm.sh/chart`) to the new format (without `helm.sh/chart`). This is a one-time change. Subsequent upgrades (v10.3.4 → v10.3.5, etc.) will not restart pods unless the pod spec changes.

#### Operational Impact

- **One-time pod restart**: All Midaz pods (ledger, CRM, tracer) will roll once during this upgrade
- **Ledger migrations Job**: Runs as a `pre-upgrade` hook (standard behavior for all upgrades)
- **Future upgrades**: Chart version bumps alone will no longer trigger pod restarts

> **Note:** The `helm.sh/chart` label remains on Deployment, Job, CronJob, Service, and other resource metadata. Only the pod template labels are affected.

## Documentation Updates

### 1. Removed external documentation links

This release removes several inline documentation links from `Chart.yaml` and `values.yaml` that pointed to external documentation sites. The chart now includes brief inline descriptions instead of external references.

#### What Changed

**Chart.yaml:**

| Field | v10.3.3 | v10.3.4 |
|-------|---------|---------|
| `sources` | Included `https://github.com/LerianStudio/midaz` | Removed |
| `dependencies` comment | Multi-line comment with external link | Single-line comment: "The dependencies provide the datastores and messaging the Midaz components use." |

**values.yaml:**

| Field | v10.3.3 | v10.3.4 |
|-------|---------|---------|
| `postgresql` comment | Included external link to component documentation | Removed external link, kept inline description |

**Before (v10.3.3):**

```yaml
# Chart.yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/midaz
  - https://github.com/LerianStudio/midaz

# This Helm chart includes multiple dependencies required for the application.
# To understand the purpose and configuration of each dependency, visit:
# https://docs.lerian.studio/docs/midaz-components
dependencies:
  - name: lerian-common-helm
    version: "2.6.0"
```

```yaml
# values.yaml
postgresql:
  # PostgreSQL is the backbone of Midaz for managing structured data that demands transactional reliability and consistency.
  # This component is responsible for providing a robust relational database
  # For more details, refer to the documentation:
  # https://docs.lerian.studio/docs/midaz-components#why-postgresql
  enabled: true
```

**After (v10.3.4):**

```yaml
# Chart.yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/midaz

# This Helm chart includes multiple dependencies required for the application.
# The dependencies provide the datastores and messaging the Midaz components use.
dependencies:
  - name: lerian-common-helm
    version: "2.6.0"
```

```yaml
# values.yaml
postgresql:
  # PostgreSQL is the backbone of Midaz for managing structured data that demands transactional reliability and consistency.
  # This component is responsible for providing a robust relational database
  enabled: true
```

#### Operational Impact

This is a **documentation-only change**. No configuration values or runtime behavior are affected. No action is required.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.3.4
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.3.4
```
<!-- {% endraw %} -->
