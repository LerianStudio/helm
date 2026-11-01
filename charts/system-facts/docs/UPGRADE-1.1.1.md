<!-- {% raw %} -->
# Helm Upgrade from v1.1.0 to v1.1.1

This guide covers the upgrade of the `system-facts` Helm chart from version **1.1.0** to **1.1.1**. This is a patch release that removes the deprecated `LICENSE_ENABLED` configuration option from the ConfigMap template.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Configuration Changes](#configuration-changes)**
  - [Removed: LICENSE_ENABLED Environment Variable](#removed-license_enabled-environment-variable)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.1.1** removes the `LICENSE_ENABLED` configuration option from the ConfigMap template. This release changes only the `templates/configmap.yaml` file. There are no changes to:

- Chart metadata (`appVersion` remains `1.1.0`)
- Values schema or defaults in `values.yaml`
- Image tags or container specifications
- Other template files (Deployments, Services, etc.)
- Dependencies or subcharts

The `ORGANIZATION_IDS` configuration option remains unchanged and continues to function as before.

Because the ConfigMap template changes, Kubernetes will detect a ConfigMap content change and the System Facts Deployment will roll to pick up the new ConfigMap. The worker Deployment will also roll if `worker.enabled` is `true`.

---

## Breaking Changes

**None.** The `LICENSE_ENABLED` environment variable was removed from the ConfigMap template, but this is not a breaking change for operators:

- If you never set `system-facts.configmap.LICENSE_ENABLED` in your values, the ConfigMap did not include the variable, so nothing changes for you.
- If you did set `system-facts.configmap.LICENSE_ENABLED`, the chart will no longer render it into the ConfigMap. The application will use its internal default behavior for license enforcement.

The values schema itself is unchanged — you can still set `system-facts.configmap.LICENSE_ENABLED` in your values file, but the chart will ignore it.

---

## Configuration Changes

### Removed: LICENSE_ENABLED Environment Variable

The `LICENSE_ENABLED` environment variable has been removed from the ConfigMap template. Previously, operators could set `system-facts.configmap.LICENSE_ENABLED` to control license enforcement behavior. This option is no longer supported by the chart.

**Template change:**

**Before (v1.1.0):**

```yaml
  {{- /* License gate inputs (README: system-facts.configmap.ORGANIZATION_IDS / LICENSE_ENABLED).
         Rendered only when set, so an install that leaves them out keeps the app defaults. */}}
  {{- with (index .Values "system-facts").configmap.ORGANIZATION_IDS }}
  ORGANIZATION_IDS: {{ . | toString | quote }}
  {{- end }}
  {{- if hasKey ((index .Values "system-facts").configmap | default dict) "LICENSE_ENABLED" }}
  LICENSE_ENABLED: {{ (index .Values "system-facts").configmap.LICENSE_ENABLED | toString | quote }}
  {{- end }}
```

**After (v1.1.1):**

```yaml
  {{- /* License gate inputs (README: system-facts.configmap.ORGANIZATION_IDS).
         Rendered only when set, so an install that leaves it out keeps the app default. */}}
  {{- with (index .Values "system-facts").configmap.ORGANIZATION_IDS }}
  ORGANIZATION_IDS: {{ . | toString | quote }}
  {{- end }}
```

**Operational impact:**

If you have `system-facts.configmap.LICENSE_ENABLED` set in your values file, the chart will no longer render it into the ConfigMap. The System Facts application will use its internal default for license enforcement.

The `ORGANIZATION_IDS` configuration option remains unchanged and continues to control which organization IDs are subject to license checks.

> **Note:** If you were using `LICENSE_ENABLED` to disable license enforcement, review the System Facts application documentation for alternative configuration methods. The chart no longer provides this option.

---

## Migration Steps

No values changes are required. If you have `system-facts.configmap.LICENSE_ENABLED` set in your values file, you may remove it, but leaving it in place will not cause errors — the chart will simply ignore it.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.1.0`.

### Step 2: (Optional) Remove LICENSE_ENABLED from your values

If your values file includes `system-facts.configmap.LICENSE_ENABLED`, you may remove it:

**Before:**

```yaml
system-facts:
  configmap:
    ORGANIZATION_IDS: "org-123,org-456"
    LICENSE_ENABLED: "false"
```

**After:**

```yaml
system-facts:
  configmap:
    ORGANIZATION_IDS: "org-123,org-456"
```

> **Note:** This step is optional. Leaving `LICENSE_ENABLED` in your values file will not cause errors; the chart will simply ignore it.

### Step 3: Apply the upgrade

Upgrade to version `1.1.1` using your existing values:

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.1.1 \
  --namespace system-facts \
  --reuse-values
```

> **Note:** The `--reuse-values` flag preserves your existing configuration. No values changes are required for this upgrade.

### Step 4: Monitor the upgrade

Watch the rollout status for the System Facts service:

```bash
kubectl rollout status deployment/system-facts -n system-facts
```

If the worker is enabled, monitor its rollout:

```bash
kubectl rollout status deployment/system-facts-worker -n system-facts
```

> **Note:** The ConfigMap content changed, so Kubernetes will perform a rolling update of the Deployment. With the default single replica and `maxUnavailable: 1`, expect a short interruption. Run two or more replicas to keep the service available during the rollout.

### Step 5: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.1.1`.

Verify that all pods are running and healthy:

```bash
kubectl get pods -n system-facts
```

### Step 6: Verify ConfigMap changes

Inspect the ConfigMap to confirm `LICENSE_ENABLED` is no longer present:

```bash
kubectl get configmap system-facts -n system-facts -o yaml
```

The `LICENSE_ENABLED` key should not appear in the `data` section. The `ORGANIZATION_IDS` key should still be present if you have it configured.

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.1 -n system-facts
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.1 -n system-facts
```
<!-- {% endraw %} -->
