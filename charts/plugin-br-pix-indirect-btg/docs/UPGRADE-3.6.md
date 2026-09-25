# Helm Upgrade from v3.5.0 to v3.6.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Conditional replica count for autoscaling compatibility](#1-conditional-replica-count-for-autoscaling-compatibility)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that adds conditional rendering of the `replicas` field in all component deployments to prevent conflicts when Horizontal Pod Autoscaler (HPA) is enabled. The application version remains `1.8.0` and no values are removed or renamed, so existing custom values continue to work without changes.

The expected upgrade path is an in-place Helm upgrade with no required configuration changes.

## Features

### 1. Conditional replica count for autoscaling compatibility

All five component deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) now conditionally render the `replicas` field based on whether autoscaling is enabled for that component.

**What changed:**

Previously, the `replicas` field was always rendered in the Deployment spec, even when autoscaling was enabled. This could cause conflicts with the HPA controller, which manages replica count dynamically. Now, when `<component>.autoscaling.enabled` is set to `true`, the `replicas` field is omitted from the Deployment spec entirely, allowing the HPA to take full control.

**Before (v3.5.0):**

```yaml
spec:
  revisionHistoryLimit: {{ .Values.pix.revisionHistoryLimit | default 10 }}
  strategy:
    {{- toYaml .Values.pix.deploymentStrategy | nindent 4 }}
  replicas: {{ .Values.pix.replicaCount }}
  selector:
    matchLabels:
      {{- include "plugin-br-pix-indirect-btg.selectorLabels" (dict "context" . "name" .Values.pix.name) | nindent 6 }}
```

**After (v3.6.0):**

```yaml
spec:
  revisionHistoryLimit: {{ .Values.pix.revisionHistoryLimit | default 10 }}
  strategy:
    {{- toYaml .Values.pix.deploymentStrategy | nindent 4 }}
  {{- if not .Values.pix.autoscaling.enabled }}
  replicas: {{ .Values.pix.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "plugin-br-pix-indirect-btg.selectorLabels" (dict "context" . "name" .Values.pix.name) | nindent 6 }}
```

**Why it matters:**

When both a static `replicas` field and an HPA are present, Kubernetes behavior can be unpredictable. The HPA may scale the deployment, but subsequent Helm upgrades or reconciliations could reset the replica count back to the static value, causing service disruptions or preventing proper autoscaling.

By conditionally omitting the `replicas` field when autoscaling is enabled, this release ensures clean HPA operation and prevents replica count conflicts.

**Operational impact:**

| Component | Autoscaling disabled | Autoscaling enabled |
|-----------|---------------------|---------------------|
| `pix` | `replicas` field rendered from `pix.replicaCount` | `replicas` field omitted, HPA controls count |
| `inbound` | `replicas` field rendered from `inbound.replicaCount` | `replicas` field omitted, HPA controls count |
| `outbound` | `replicas` field rendered from `outbound.replicaCount` | `replicas` field omitted, HPA controls count |
| `reconciliation` | `replicas` field rendered from `reconciliation.replicaCount` | `replicas` field omitted, HPA controls count |
| `schedule` | `replicas` field rendered from `schedule.replicaCount` | `replicas` field omitted, HPA controls count |

**If you are not using autoscaling** (the default), this change has **no runtime impact**. The `replicas` field will continue to be rendered exactly as before.

**If you have autoscaling enabled** for any component, this upgrade will remove the static `replicas` field from the Deployment spec, allowing the HPA to manage replicas without interference. The current replica count managed by the HPA will be preserved during the upgrade.

**Example configuration with autoscaling enabled:**

```yaml
pix:
  replicaCount: 2  # Ignored when autoscaling.enabled is true
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
```

**Example configuration with autoscaling disabled (default):**

```yaml
pix:
  replicaCount: 3
  autoscaling:
    enabled: false
```

> **Note:** This change applies to all five components: `pix`, `inbound`, `outbound`, `reconciliation`, and `schedule`. Review your autoscaling configuration for each component before upgrading.

## Configuration Changes

No values are removed or renamed. The conditional rendering logic is additive and respects existing `<component>.autoscaling.enabled` settings.

| Setting | v3.5.0 | v3.6.0 |
|---------|--------|--------|
| Chart version | `3.5.0` | `3.6.0` |
| App version | `1.8.0` | `1.8.0` |
| `<component>.replicas` rendering | Always rendered | Rendered only when `<component>.autoscaling.enabled` is `false` |

## Migration Steps

This upgrade requires no destructive migration steps. The conditional rendering logic automatically adapts to your existing autoscaling configuration.

**Recommended upgrade process:**

1. Review your current autoscaling configuration for each component (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`).

```bash
helm get values plugin-br-pix-indirect-btg -n plugin-br-pix-indirect-btg
```

2. Verify which components have `autoscaling.enabled: true`. For those components, confirm that your HPA resources are properly configured and active.

```bash
kubectl get hpa -n plugin-br-pix-indirect-btg
```

3. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. Run the upgrade command during a maintenance window.

5. Verify all pods are running and healthy after the upgrade.

```bash
kubectl get pods -n plugin-br-pix-indirect-btg
```

6. For components with autoscaling enabled, confirm the HPA is managing replicas correctly.

```bash
kubectl describe hpa -n plugin-br-pix-indirect-btg
```

> **Important:** If you have autoscaling enabled for any component, the upgrade will trigger a Deployment update that removes the static `replicas` field. This change is non-disruptive — the HPA will continue to manage the current replica count, and no pods will be terminated unless the HPA determines scaling is needed based on current metrics.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.6.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.6.0 -n plugin-br-pix-indirect-btg
```
