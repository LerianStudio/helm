<!-- {% raw %} -->
# Helm Upgrade from v1.0.1 to v1.0.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Pod labels no longer include `helm.sh/chart` to prevent unnecessary restarts](#1-pod-labels-no-longer-include-helmshchart-to-prevent-unnecessary-restarts)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `notifications` chart upgrade from `1.0.1` to `1.0.2`. This is a **patch** release that fixes unnecessary pod restarts on every Helm upgrade by removing the `helm.sh/chart` label from pod templates. The application version (`appVersion: "1.1.0"`) remains unchanged.

This upgrade requires no configuration changes and is safe to apply without modification to your existing values.

## Fixes

### 1. Pod labels no longer include `helm.sh/chart` to prevent unnecessary restarts

In v1.0.1, the `notifications.labels` helper included the `helm.sh/chart` label, which encodes the chart version (e.g., `notifications-1.0.1`). Because this label was applied to the pod template's `metadata.labels` in every Deployment, Kubernetes detected a change to the pod spec on every chart upgrade—even when no application configuration changed—and triggered a rolling restart of all pods.

Starting in v1.0.2, the chart introduces a new helper, `notifications.podLabels`, which includes all standard labels **except** `helm.sh/chart`. The `helm.sh/chart` label remains on the Deployment, Service, and other top-level resources (where it belongs), but is no longer part of the pod template.

**Before (v1.0.1):**

```yaml
# templates/_helpers.tpl
{{- define "notifications.labels" -}}
helm.sh/chart: {{ include "notifications.chart" .context }}
{{ include "notifications.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "notifications.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

# templates/api/deployment.yaml
spec:
  template:
    metadata:
      labels:
        {{- include "notifications.labels" (dict "context" . "name" .Values.api.name) | nindent 8 }}
```

**After (v1.0.2):**

```yaml
# templates/_helpers.tpl
{{- define "notifications.labels" -}}
helm.sh/chart: {{ include "notifications.chart" .context }}
{{ include "notifications.podLabels" . }}
{{- end }}

{{- define "notifications.podLabels" -}}
{{ include "notifications.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "notifications.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

# templates/api/deployment.yaml
spec:
  template:
    metadata:
      labels:
        {{- include "notifications.podLabels" (dict "context" . "name" .Values.api.name) | nindent 8 }}
```

#### Impact

- **Upgrades from v1.0.1 to v1.0.2:** Kubernetes will detect the removal of `helm.sh/chart` from the pod template as a change and perform **one final rolling restart** of all deployments (`api`, `workerEmail`, `workerSms`, `workerWebhook`). This is expected and unavoidable.
- **Subsequent upgrades (v1.0.2 → v1.0.3+):** Pods will **not** restart unless the chart changes application configuration, image tags, or other pod spec fields. Chart version bumps alone will no longer trigger restarts.

> **Important:** The first upgrade to v1.0.2 will restart all pods once. Plan the upgrade during a maintenance window if zero-downtime is critical. After this upgrade, future chart version bumps will not restart pods unless actual configuration changes.

## Configuration Changes

Summary of template impact:

| Category | Detail |
|----------|--------|
| Changed | `templates/_helpers.tpl`: new `notifications.podLabels` helper excludes `helm.sh/chart` |
| Changed | `templates/api/deployment.yaml`: pod template now uses `notifications.podLabels` |
| Changed | `templates/worker-email/deployment.yaml`: pod template now uses `notifications.podLabels` |
| Changed | `templates/worker-sms/deployment.yaml`: pod template now uses `notifications.podLabels` |
| Changed | `templates/worker-webhook/deployment.yaml`: pod template now uses `notifications.podLabels` |

No changes to `values.yaml` or default configuration values.

## Migration Steps

1. **Review the rendered diff** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)). You will see the `helm.sh/chart` label removed from the pod template `metadata.labels` block in all four Deployments.

2. **Plan for a rolling restart.** The upgrade will trigger a rolling restart of all deployments. If you have PodDisruptionBudgets configured, ensure they allow at least one pod to be unavailable during the rollout.

3. **Run the upgrade.** After the upgrade completes, verify the rollout:

```bash
kubectl rollout status -n notifications deploy/notifications-api
kubectl rollout status -n notifications deploy/notifications-worker-email
kubectl rollout status -n notifications deploy/notifications-worker-sms
kubectl rollout status -n notifications deploy/notifications-worker-webhook
```

4. **Verify labels on running pods.** Confirm that the `helm.sh/chart` label is no longer present on pod resources:

```bash
kubectl get pods -n notifications -l app.kubernetes.io/name=notifications -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.helm\.sh/chart}{"\n"}{end}'
```

The output should show pod names with an empty second column (no `helm.sh/chart` value).

> **Note:** The `helm.sh/chart` label remains on the Deployment resource itself and on Services, ConfigMaps, and Secrets. Only the pod template is affected by this change.

## Preview changes before upgrading

```bash
helm diff upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.0.2 -n notifications
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.0.2 -n notifications
```
<!-- {% endraw %} -->
