# Helm Upgrade from v2.1.3 to v2.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Global Pod Scheduling Configuration](#1-global-pod-scheduling-configuration)
  - [2. Component-Level Scheduling Overrides](#2-component-level-scheduling-overrides)
  - [3. Dependency Update](#3-dependency-update)
- **[Configuration Reference](#configuration-reference)**
  - [Global Scheduling Fields](#global-scheduling-fields)
  - [Component Scheduling Fields](#component-scheduling-fields)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.2.0 introduces a new global pod scheduling system that allows operators to configure topology spread constraints across all components from a single location. This release adds `global.scheduling.spread` configuration for environment-wide pod distribution policies (spread across nodes and zones) and per-component overrides for fine-grained control. The chart also updates the `lerian-common-helm` dependency from `2.0.0` to `2.3.0`, which provides the underlying scheduling template helpers.

This is a **non-breaking** release. All new fields are optional and default to backward-compatible behavior. Existing `nodeSelector`, `affinity`, and `tolerations` configurations continue to work unchanged.

## Features

### 1. Global Pod Scheduling Configuration

**What changed:**  
A new `global.scheduling.spread` configuration block has been added to `values.yaml`. This block defines environment-wide topology spread constraints that apply to all components (currently the bank-transfer Deployment).

**New configuration:**

```yaml
global:
  scheduling:
    spread:
      # -- Master switch for the spread preset.
      enabled: true
      # -- Spread across nodes (kubernetes.io/hostname): ScheduleAnyway (soft) | DoNotSchedule (hard) | "" (off).
      hostname: ScheduleAnyway
      # -- Spread across zones (topology.kubernetes.io/zone): ScheduleAnyway | DoNotSchedule | "" (off).
      zone: ""
      # -- Max allowed pod-count difference between topology domains (integer >= 1).
      maxSkew: 1
      # -- Minimum eligible domains for DoNotSchedule constraints (0 = off).
      minDomains: 0
      # -- Honor | Ignore | "" (omitted = Kubernetes default Ignore).
      nodeTaintsPolicy: ""
```

**Why it matters:**  
- **Simplified multi-replica deployments:** Operators can now configure pod distribution policies once at the global level instead of manually crafting `topologySpreadConstraints` for each component
- **High availability:** The default `hostname: ScheduleAnyway` setting encourages the scheduler to spread replicas across nodes, reducing the impact of node failures
- **Zone-aware scheduling:** Operators can enable zone spreading (`zone: ScheduleAnyway` or `zone: DoNotSchedule`) on cloud platforms (EKS, GKE, AKS) where every node has `topology.kubernetes.io/zone` labels
- **Autoscaler integration:** The `minDomains` field supports cluster autoscalers (Karpenter, Cluster Autoscaler) by preventing hard constraints from blocking pod scheduling when fewer domains exist than required

**Default behavior:**

| Setting | Default | Effect |
|---------|---------|--------|
| `enabled` | `true` | Spread preset is active |
| `hostname` | `ScheduleAnyway` | Soft spread across nodes (scheduler prefers distribution but allows stacking if necessary) |
| `zone` | `""` (off) | No zone spreading (safe for bare-metal/k3s clusters without zone labels) |
| `maxSkew` | `1` | Maximum 1-pod difference between nodes |
| `minDomains` | `0` (off) | No minimum domain requirement |
| `nodeTaintsPolicy` | `""` (omitted) | Kubernetes default behavior (Ignore) |

**Operational impact:**  
- When `enabled: true` and `hostname: ScheduleAnyway`, the bank-transfer Deployment will have a soft topology spread constraint that encourages replicas to distribute across nodes
- The constraint uses `matchLabelKeys: [pod-template-hash]` to count only pods from the same ReplicaSet, preventing rolling update deadlocks
- The constraint's `labelSelector` matches the Deployment's selector labels automatically

**Example: Enable hard node spreading for production:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule  # Hard constraint: never stack replicas on the same node
      maxSkew: 1
      minDomains: 2  # Require at least 2 nodes; extra replicas wait for new nodes (Karpenter)
```

**Example: Enable zone spreading for cloud deployments:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ScheduleAnyway  # Soft spread across availability zones
      maxSkew: 1
```

**Example: Disable the spread preset:**

```yaml
global:
  scheduling:
    spread:
      enabled: false
```

### 2. Component-Level Scheduling Overrides

**What changed:**  
Two new fields have been added to the `bankTransfer` component configuration: `spread` and `topologySpreadConstraints`. These fields allow operators to override or replace the global scheduling preset for the bank-transfer Deployment.

**New configuration:**

```yaml
bankTransfer:
  # -- Override of global.scheduling.spread for the bank-transfer Deployment (same fields: enabled,
  # hostname, zone, maxSkew, minDomains, nodeTaintsPolicy); each field set here wins over the global one.
  spread: {}
  # -- Raw Kubernetes topologySpreadConstraints. Non-empty = replaces the spread preset
  # entirely; an entry without labelSelector gets the Deployment's selector labels.
  topologySpreadConstraints: []
```

**Why it matters:**  
- **Fine-grained control:** Operators can customize scheduling for the bank-transfer component without affecting other components (future-proofing for multi-component charts)
- **Gradual migration:** Operators can test new scheduling policies on a single component before applying them globally
- **Advanced use cases:** The raw `topologySpreadConstraints` field supports complex scenarios not covered by the preset (e.g., multiple constraints with different `whenUnsatisfiable` modes)

**Override behavior:**

| Field | Behavior |
|-------|----------|
| `bankTransfer.spread` | Merges with `global.scheduling.spread` — each field set in `bankTransfer.spread` overrides the corresponding global field |
| `bankTransfer.topologySpreadConstraints` | Replaces the spread preset entirely when non-empty — gives full control over raw Kubernetes constraints |

**Example: Override hostname spreading for bank-transfer only:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway  # Global default: soft spread

bankTransfer:
  spread:
    hostname: DoNotSchedule  # Override for bank-transfer: hard spread
```

**Example: Use raw topologySpreadConstraints:**

```yaml
bankTransfer:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      # labelSelector is auto-filled with the Deployment's selector labels
    - maxSkew: 2
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: bank-transfer
```

> **Note:** When `bankTransfer.topologySpreadConstraints` is non-empty, the spread preset is completely replaced. The chart will not merge or apply `global.scheduling.spread` or `bankTransfer.spread` settings.

### 3. Dependency Update

**What changed:**  
The `lerian-common-helm` dependency has been updated from version `2.0.0` to `2.3.0`.

| Dependency | v2.1.3 | v2.2.0 | Change Type |
|------------|--------|--------|-------------|
| `lerian-common-helm` | `2.0.0` | `2.3.0` | Minor |

**Why it matters:**  
The `lerian-common-helm` library chart provides shared template helpers used across Lerian Studio charts. Version `2.3.0` introduces the `lerian-common.scheduling` helper that powers the new global scheduling feature. This update also includes bug fixes and improvements to existing helpers.

**Operational impact:**  
The dependency update is transparent to operators. No configuration changes are required.

**Template changes:**

The bank-transfer Deployment template (`templates/deployment.yaml`) has been refactored to use the new `lerian-common.scheduling` helper instead of directly rendering `nodeSelector`, `affinity`, and `tolerations`.

**Before (v2.1.3):**

```yaml
spec:
  template:
    spec:
      # ... container spec ...
      {{- with .Values.bankTransfer.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.bankTransfer.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.bankTransfer.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

**After (v2.2.0):**

```yaml
spec:
  template:
    spec:
      # ... container spec ...
      {{- /* nodeSelector / affinity / tolerations + topologySpreadConstraints
             (global.scheduling.spread preset, bankTransfer.spread, bankTransfer.topologySpreadConstraints).
             selectorLabels MUST equal spec.selector.matchLabels above. */}}
      {{- with (include "lerian-common.scheduling" (dict
            "component" .Values.bankTransfer
            "global" .Values.global
            "selectorLabels" (include "bank-transfer.selectorLabels" (dict "context" . "name" .Values.bankTransfer.name))) | trim) }}
      {{- . | nindent 6 }}
      {{- end }}
```

**Operational impact:**  
- The `lerian-common.scheduling` helper renders `nodeSelector`, `affinity`, `tolerations`, and `topologySpreadConstraints` in a single block
- Existing `bankTransfer.nodeSelector`, `bankTransfer.affinity`, and `bankTransfer.tolerations` configurations continue to work unchanged — the helper passes them through to the rendered manifest
- The new `topologySpreadConstraints` are added alongside existing scheduling fields (they do not replace `nodeSelector`, `affinity`, or `tolerations`)

## Configuration Reference

### Global Scheduling Fields

Add these fields to `global.scheduling.spread` to configure environment-wide pod distribution:

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ""
      maxSkew: 1
      minDomains: 0
      nodeTaintsPolicy: ""
```

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `true` | Master switch for the spread preset. Set to `false` to disable topology spread constraints entirely. |
| `hostname` | `ScheduleAnyway` | Spread across nodes (`kubernetes.io/hostname`). Options: `ScheduleAnyway` (soft), `DoNotSchedule` (hard), `""` (off). |
| `zone` | `""` (off) | Spread across zones (`topology.kubernetes.io/zone`). Options: `ScheduleAnyway` (soft), `DoNotSchedule` (hard), `""` (off). Off by default because clusters without zone labels (bare-metal, k3s) will silently cancel hostname spreading when a zone constraint is present. |
| `maxSkew` | `1` | Maximum allowed pod-count difference between topology domains (integer >= 1). |
| `minDomains` | `0` (off) | Minimum eligible domains for `DoNotSchedule` constraints. With fewer domains, the scheduler treats the global minimum as 0 (allows stacking). Use on autoscaled clusters to let hard constraints trigger node provisioning. |
| `nodeTaintsPolicy` | `""` (omitted) | Whether to honor node taints when counting domains. Options: `Honor` (skip tainted nodes), `Ignore` (count all nodes), `""` (omitted = Kubernetes default `Ignore`). `Honor` is useful with Karpenter disruption taints. |

### Component Scheduling Fields

Add these fields to `bankTransfer` to override or replace the global scheduling preset:

```yaml
bankTransfer:
  spread:
    hostname: DoNotSchedule
    maxSkew: 2
  topologySpreadConstraints: []
```

| Field | Default | Description |
|-------|---------|-------------|
| `spread` | `{}` | Override of `global.scheduling.spread` for the bank-transfer Deployment. Supports the same fields: `enabled`, `hostname`, `zone`, `maxSkew`, `minDomains`, `nodeTaintsPolicy`. Each field set here wins over the global one. |
| `topologySpreadConstraints` | `[]` | Raw Kubernetes `topologySpreadConstraints` list. Non-empty = replaces the spread preset entirely. An entry without `labelSelector` gets the Deployment's selector labels auto-filled. |

> **Important:** `bankTransfer.spread` and `bankTransfer.topologySpreadConstraints` are mutually exclusive in practice. If you set `topologySpreadConstraints` to a non-empty list, the spread preset (global + component overrides) is ignored.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.2.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.2.0 -n plugin-br-bank-transfer
```
