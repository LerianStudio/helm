<!-- {% raw %} -->
# Helm Upgrade from v9.0.2 to v9.0.3

# Topics

- ***[Fixes](#fixes)***
    - [1. Pod Label Stability During Upgrades](#1-pod-label-stability-during-upgrades)
- ***[Documentation Changes](#documentation-changes)***
    - [1. Chart.yaml Comment Cleanup](#1-chartyaml-comment-cleanup)
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Fixes

### 1. Pod Label Stability During Upgrades

The chart now prevents unnecessary pod restarts during Helm upgrades by excluding the `helm.sh/chart` label from pod templates.

**What changed:**

A new helper template `plugin-fees.podLabels` has been introduced that generates labels without the `helm.sh/chart` label. This new template is used in the pod template section of the Deployment, while the full label set (including `helm.sh/chart`) continues to be used for the Deployment resource itself.

**Before (v9.0.2):**

```yaml
# In deployment.yaml pod template
metadata:
  labels:
    {{- include "plugin-fees.labels" (dict "context" . "name" .Values.fees.name ) | nindent 8 }}
```

**After (v9.0.3):**

```yaml
# In deployment.yaml pod template
metadata:
  labels:
    {{- include "plugin-fees.podLabels" (dict "context" . "name" .Values.fees.name ) | nindent 8 }}
```

**Why this matters:**

In v9.0.2, the `helm.sh/chart` label (which includes the chart version number) was applied to pod templates. Every time you upgraded the chart version, Kubernetes detected a change in the pod template spec and triggered a rolling restart of all pods — even when no actual application configuration or image had changed.

With v9.0.3, the `helm.sh/chart` label is only applied to the Deployment resource metadata, not to the pod template. This means:

- Pods will **not** restart automatically when upgrading between patch versions if no other configuration changes
- The Deployment resource itself still carries the full label set for tracking and management
- You retain full control over when pods restart (e.g., via image updates, config changes, or manual rollout)

**Migration impact:**

- **No action required** — this change is backward-compatible and automatic
- After upgrading to v9.0.3, subsequent patch upgrades will not trigger unnecessary pod restarts
- Existing pods from v9.0.2 will be gradually updated during the next natural rollout (e.g., when you change an image, environment variable, or other pod spec field)

> **Note:** This is a stability improvement with no breaking changes. Your existing label selectors and monitoring queries will continue to work as before.

# Documentation Changes

### 1. Chart.yaml Comment Cleanup

The Chart.yaml file has been simplified by removing an inline documentation comment that referenced external documentation.

| Setting | v9.0.2 | v9.0.3 |
|---------|--------|--------|
| Dependencies comment | Included reference to external docs URL | Comment removed |

**What was removed:**

```yaml
# To understand the purpose and configuration of each dependency, visit:
# https://docs.lerian.studio/docs/midaz-components
```

**Why this matters:**

This is a documentation-only change with no operational impact. The dependencies section remains unchanged — only the inline comment was removed. Operators can still reference the external documentation URL if needed, but it is no longer embedded in the Chart.yaml file.

**Migration impact:**

- **No action required** — this change has no effect on chart functionality or deployment behavior
- The `lerian-common-helm` dependency remains at version `2.0.0` with no changes

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.3 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.3 -n plugin-fees
```
<!-- {% endraw %} -->
