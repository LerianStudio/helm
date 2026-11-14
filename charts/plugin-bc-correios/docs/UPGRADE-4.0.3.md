<!-- {% raw %} -->
# Helm Upgrade from v4.0.2 to v4.0.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Automatic pod restart on configuration changes](#1-automatic-pod-restart-on-configuration-changes)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that improves the deployment's ability to automatically detect configuration changes. The chart version moves from 4.0.2 to 4.0.3, while the application version remains unchanged at 1.1.0. This upgrade introduces automatic pod restarts when ConfigMaps or Secrets are modified, ensuring that configuration changes are immediately applied without manual intervention.

## Fixes

### 1. Automatic pod restart on configuration changes

The deployment template now includes checksum annotations for ConfigMaps and Secrets in the pod template. This ensures that pods are automatically restarted whenever the configuration or secrets change, eliminating the need for manual pod deletion or rollout restarts.

**Before (v4.0.2):**

```yaml
template:
  metadata:
    {{- with $component.podAnnotations }}
    annotations:
      {{- toYaml . | nindent 8 }}
    {{- end }}
    labels:
      {{- include "bc-correios.selectorLabels" (dict "context" . "component" $component.name "name" $component.name) | nindent 8 }}
```

**After (v4.0.3):**

```yaml
template:
  metadata:
    annotations:
      checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
      {{- with $component.podAnnotations }}
      {{- toYaml . | nindent 8 }}
      {{- end }}
    labels:
      {{- include "bc-correios.selectorLabels" (dict "context" . "component" $component.name "name" $component.name) | nindent 8 }}
```

**What changed:**

Two new annotations are now automatically added to every pod:

- `checksum/config`: A SHA256 hash of the rendered ConfigMap template
- `checksum/secret`: A SHA256 hash of the rendered Secrets template

These annotations are computed at Helm render time and injected into the pod template. When you modify any value that affects the ConfigMap or Secret (e.g., environment variables, database credentials, feature flags), Helm will render a new checksum, causing Kubernetes to detect a pod template change and trigger a rolling restart.

**Why it matters:**

Previously, when you updated configuration values in `values.yaml` and ran `helm upgrade`, the ConfigMap and Secret resources would be updated in the cluster, but running pods would continue using the old configuration until manually restarted. This created operational friction and potential inconsistencies between the desired and actual state.

With this change:

- Configuration updates are automatically propagated to running pods
- No manual `kubectl rollout restart` or pod deletion is required
- The deployment state remains consistent with the Helm release
- Rollbacks automatically revert pods to the previous configuration

**Operational impact:**

- **First upgrade to v4.0.3:** All pods will be restarted during the upgrade because the new checksum annotations are added to the pod template
- **Subsequent configuration changes:** Any `helm upgrade` that modifies ConfigMap or Secret values will trigger an automatic rolling restart
- **No configuration changes:** If you upgrade to v4.0.3 without changing any configuration values, pods will still restart once due to the new annotations being added
- **Custom pod annotations:** If you have custom `podAnnotations` defined in your values file, they will be preserved and merged with the new checksum annotations

> **Note:** The checksum annotations only track changes to the ConfigMap and Secret templates managed by this chart. Changes to external ConfigMaps or Secrets referenced in your values file will not trigger automatic restarts.

> **Important:** This change affects the pod template, which means all pods will be recreated during the upgrade. Plan the upgrade during a maintenance window if you run a single replica or have strict availability requirements.

**Example scenario:**

Before v4.0.3, updating a database password required two steps:

```bash
# Step 1: Update the Helm release
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 4.0.2 -n plugin-bc-correios --set bc-correios.database.password=newpassword

# Step 2: Manually restart pods to pick up the new password
kubectl rollout restart deployment/plugin-bc-correios-bc-correios -n plugin-bc-correios
```

With v4.0.3, only one step is required:

```bash
# The pods will automatically restart with the new password
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 4.0.3 -n plugin-bc-correios --set bc-correios.database.password=newpassword
```

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will automatically add the checksum annotations and roll the pods.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))

2. Ensure you have a recent backup of your data (if using chart-managed databases)

3. Run the upgrade command during a maintenance window

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n plugin-bc-correios
```

5. Confirm the new checksum annotations are present:

```bash
kubectl get pods -n plugin-bc-correios -l app.kubernetes.io/name=bc-correios -o jsonpath='{.items[0].metadata.annotations}' | grep checksum
```

6. Verify application logs for any startup issues:

```bash
kubectl logs -n plugin-bc-correios -l app.kubernetes.io/name=bc-correios,app.kubernetes.io/instance=plugin-bc-correios --tail=50
```

7. Test a configuration change to verify automatic restart behavior:

```bash
# Update any configuration value
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 4.0.3 -n plugin-bc-correios --set bc-correios.someConfigValue=newValue

# Watch pods restart automatically
kubectl get pods -n plugin-bc-correios -w
```

> **Warning:** The upgrade will trigger a rolling restart of all BC Correios pods. Depending on your replica count and readiness probe configuration, this may cause brief service interruptions. Plan the upgrade during a maintenance window if you run a single replica.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 4.0.3 -n plugin-bc-correios
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 4.0.3 -n plugin-bc-correios
```
<!-- {% endraw %} -->
