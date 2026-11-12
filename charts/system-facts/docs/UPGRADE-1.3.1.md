<!-- {% raw %} -->
# Helm Upgrade from v1.3.0 to v1.3.1

This guide covers the upgrade of the `system-facts` Helm chart from version **1.3.0** to **1.3.1**. This is a patch release that fixes selector label consistency in the PodDisruptionBudget and Service templates.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Fixes](#fixes)**
  - [Selector Label Consistency](#selector-label-consistency)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.3.1** corrects the selector label parameters passed to the `system-facts.selectorLabels` helper in two templates:

- **PodDisruptionBudget** (`pdb.yaml`): Now includes the `component` parameter in the selector labels call
- **Service** (`service.yaml`): Now includes the `component` parameter in the selector labels call

This ensures that the PDB and Service selector labels are generated consistently with the same parameters used throughout the chart. There are no changes to:

- Values schema or defaults
- Application version or image tags
- Dependencies or subcharts
- Deployment or other workload templates

The fix aligns the selector label generation across all resources, preventing potential label mismatches.

---

## Breaking Changes

**None.** This is a patch release with no breaking changes. The selector labels themselves remain unchanged in the rendered output; only the internal template call signature is corrected for consistency.

---

## Fixes

### Selector Label Consistency

The `system-facts.selectorLabels` helper is called with a dictionary containing `context`, `component`, and `name` parameters throughout the chart. In v1.3.0, the PodDisruptionBudget and Service templates omitted the `component` parameter, passing only `context` and `name`.

**Template change in `pdb.yaml`:**

**Before (v1.3.0):**

```yaml
{{- if (index .Values "system-facts").podDisruptionBudget.enabled }}
  {{- include "common.pdb" (dict
      "name" (include "system-facts.fullname" .)
      "namespace" (include "global.namespace" .)
      "labels" (include "system-facts.labels" (dict "context" . "component" (index .Values "system-facts").name "name" (index .Values "system-facts").name))
      "selector" (include "system-facts.selectorLabels" (dict "context" . "name" (index .Values "system-facts").name))
      "minAvailableDefault" 1
    ) }}
{{- end }}
```

**After (v1.3.1):**

```yaml
{{- if (index .Values "system-facts").podDisruptionBudget.enabled }}
  {{- include "common.pdb" (dict
      "name" (include "system-facts.fullname" .)
      "namespace" (include "global.namespace" .)
      "labels" (include "system-facts.labels" (dict "context" . "component" (index .Values "system-facts").name "name" (index .Values "system-facts").name))
      "selector" (include "system-facts.selectorLabels" (dict "context" . "component" (index .Values "system-facts").name "name" (index .Values "system-facts").name))
      "minAvailableDefault" 1
    ) }}
{{- end }}
```

**Template change in `service.yaml`:**

**Before (v1.3.0):**

```yaml
{{- if (index .Values "system-facts").service.enabled }}
  {{- include "common.service" (dict
      "name" (include "system-facts.fullname" .)
      "namespace" (include "global.namespace" .)
      "labels" (include "system-facts.labels" (dict "context" . "component" (index .Values "system-facts").name "name" (index .Values "system-facts").name))
      "selector" (include "system-facts.selectorLabels" (dict "context" . "name" (index .Values "system-facts").name))
      "ports" (include "system-facts.api.health" . | fromYaml).servicePorts
    ) }}
{{- end }}
```

**After (v1.3.1):**

```yaml
{{- if (index .Values "system-facts").service.enabled }}
  {{- include "common.service" (dict
      "name" (include "system-facts.fullname" .)
      "namespace" (include "global.namespace" .)
      "labels" (include "system-facts.labels" (dict "context" . "component" (index .Values "system-facts").name "name" (index .Values "system-facts").name))
      "selector" (include "system-facts.selectorLabels" (dict "context" . "component" (index .Values "system-facts").name "name" (index .Values "system-facts").name))
      "ports" (include "system-facts.api.health" . | fromYaml).servicePorts
    ) }}
{{- end }}
```

**Operational impact:**

The rendered selector labels in the PodDisruptionBudget and Service remain unchanged because the `system-facts.selectorLabels` helper uses the `name` parameter to generate the selector. The `component` parameter is now passed for consistency with other template calls, but does not alter the output.

Kubernetes will not recreate the PDB or Service during the upgrade because their specs are unchanged. No pods will roll, and no service interruption will occur.

> **Note:** This fix is purely for template consistency and maintainability. Operators do not need to take any action beyond applying the upgrade.

---

## Migration Steps

No migration steps are required. The upgrade can be applied directly without configuration changes or manual intervention.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

Expected output should show version `1.3.0`.

### Step 2: Apply the upgrade

Upgrade to version `1.3.1` using your existing values:

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --version 1.3.1 \
  --namespace system-facts \
  --reuse-values
```

> **Note:** The `--reuse-values` flag preserves your existing configuration. No values changes are required for this upgrade.

### Step 3: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

Expected output should show version `1.3.1`.

Verify that all pods remain healthy:

```bash
kubectl get pods -n system-facts
```

> **Note:** Since the rendered templates are unchanged, Kubernetes will not recreate any resources. The upgrade completes immediately without rolling restarts.

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm --namespace system-facts --version 1.3.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm --namespace system-facts --version 1.3.1
```
<!-- {% endraw %} -->
