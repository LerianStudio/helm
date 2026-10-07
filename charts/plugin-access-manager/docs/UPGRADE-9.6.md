# Helm Upgrade from v9.5.10 to v9.6.0

# Topics

- **[Features](#features)**
  - [1. Dependency Update: lerian-common-helm](#1-dependency-update-lerian-common-helm)
  - [2. Pod Topology Spread Constraints](#2-pod-topology-spread-constraints)
- **[Configuration Reference](#configuration-reference)**
  - [Global Scheduling Configuration](#global-scheduling-configuration)
  - [Per-Component Spread Overrides](#per-component-spread-overrides)
  - [Raw Topology Spread Constraints](#raw-topology-spread-constraints)
- **[Migration Scenarios](#migration-scenarios)**
  - [Scenario 1: Default Upgrade (No Action Required)](#scenario-1-default-upgrade-no-action-required)
  - [Scenario 2: Customizing Spread Behavior](#scenario-2-customizing-spread-behavior)
  - [Scenario 3: Using Raw Topology Spread Constraints](#scenario-3-using-raw-topology-spread-constraints)
  - [Scenario 4: Disabling Spread Constraints](#scenario-4-disabling-spread-constraints)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Dependency Update: lerian-common-helm

The chart dependency `lerian-common-helm` has been upgraded from version 2.0.0 to 2.3.0.

| Dependency | v9.5.10 | v9.6.0 |
|------------|---------|--------|
| lerian-common-helm | 2.0.0 | 2.3.0 |

**What this means for operators:**

This dependency update brings new shared template helpers, specifically the `lerian-common.scheduling` template that enables the pod topology spread constraints feature described below. The upgrade is transparent and requires no configuration changes unless you want to use the new scheduling features.

### 2. Pod Topology Spread Constraints

Version 9.6.0 introduces environment-wide pod scheduling controls through topology spread constraints. This feature helps distribute pods across nodes and availability zones to improve availability and resilience.

**What changed:**

All four component deployments (identity, auth, caradhras, and caradhras.ui) now support:

- **Global spread preset** via `global.scheduling.spread` that applies to all components
- **Per-component overrides** via `<component>.spread` that override specific global settings
- **Raw constraints** via `<component>.topologySpreadConstraints` for full Kubernetes control

The deployment templates have been refactored to replace hardcoded `nodeSelector`, `affinity`, and `tolerations` blocks with a call to the new `lerian-common.scheduling` helper template.

**Before (v9.5.10):**

```yaml
# auth deployment - hardcoded scheduling fields
{{- with .Values.auth.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 8 }}
{{- end }}
{{- with .Values.auth.affinity }}
affinity:
  {{- toYaml . | nindent 8 }}
{{- end }}
{{- with .Values.auth.tolerations }}
tolerations:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

**After (v9.6.0):**

```yaml
# auth deployment - unified scheduling helper
{{- with (include "lerian-common.scheduling" (dict
      "component" .Values.auth
      "global" .Values.global
      "selectorLabels" (include "plugin-auth.selectorLabels" (dict "context" . "name" .Values.auth.name))) | trim) }}
{{- . | nindent 6 }}
{{- end }}
```

**Why this matters:**

- **Improved availability**: Pods are automatically spread across nodes and zones (when enabled) to reduce the impact of node or zone failures
- **Rolling update safety**: Spread constraints count only pods from the same ReplicaSet (via `matchLabelKeys: [pod-template-hash]`), preventing deadlocks during deployments
- **Flexible control**: Choose between soft (ScheduleAnyway) and hard (DoNotSchedule) spreading, or disable it entirely
- **Autoscaler-friendly**: The `minDomains` setting works with cluster autoscalers like Karpenter to provision new nodes when needed

**Default behavior:**

By default, `global.scheduling.spread.enabled` is `true` with soft hostname spreading (`hostname: ScheduleAnyway`). This means pods will be distributed across nodes when possible, but won't block scheduling if spreading isn't achievable. Zone spreading is disabled by default (`zone: ""`).

> **Important:** Existing `nodeSelector`, `affinity`, and `tolerations` configurations in your values.yaml continue to work exactly as before. The new spread constraints are additive and don't replace your existing scheduling rules.

# Configuration Reference

### Global Scheduling Configuration

The new `global.scheduling.spread` block controls the default topology spread behavior for all components:

```yaml
global:
  scheduling:
    spread:
      # Master switch for the spread preset
      enabled: true
      # Spread across nodes: ScheduleAnyway (soft) | DoNotSchedule (hard) | "" (off)
      hostname: ScheduleAnyway
      # Spread across zones: ScheduleAnyway | DoNotSchedule | "" (off)
      zone: ""
      # Max allowed pod-count difference between topology domains
      maxSkew: 1
      # Minimum eligible domains for DoNotSchedule constraints (0 = off)
      minDomains: 0
      # Honor | Ignore | "" (omitted = Kubernetes default Ignore)
      nodeTaintsPolicy: ""
```

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `true` | Master switch for the spread preset. Set to `false` to disable all spread constraints. |
| `hostname` | `ScheduleAnyway` | Spread pods across nodes (topology key: `kubernetes.io/hostname`). `ScheduleAnyway` = soft constraint (prefer spreading), `DoNotSchedule` = hard constraint (require spreading), `""` = disabled. |
| `zone` | `""` | Spread pods across availability zones (topology key: `topology.kubernetes.io/zone`). Same values as `hostname`. Off by default because clusters without zone labels (bare-metal, k3s) may have scheduling issues. |
| `maxSkew` | `1` | Maximum allowed difference in pod count between any two topology domains. Must be >= 1. |
| `minDomains` | `0` | Minimum number of eligible domains for `DoNotSchedule` constraints. With fewer domains, the scheduler treats the global minimum as 0. Useful for autoscaled clusters (e.g., Karpenter). `0` = disabled. |
| `nodeTaintsPolicy` | `""` | Whether to honor node taints when counting domains. `Honor` = only count nodes the pod tolerates, `Ignore` = count all nodes, `""` = omit field (Kubernetes defaults to `Ignore`). |

> **Note:** The `zone` constraint is disabled by default because the Kubernetes scheduler skips nodes without the zone label when scoring soft spread constraints. On clusters where not all nodes have zone labels, enabling zone spreading can silently cancel the hostname spread. Enable it only on cloud-managed clusters (EKS, GKE, AKS) where every node has zone labels.

### Per-Component Spread Overrides

Each component (identity, auth, caradhras, caradhras.ui) can override individual global spread settings:

```yaml
identity:
  spread:
    # Override any global.scheduling.spread field
    hostname: DoNotSchedule
    maxSkew: 2

auth:
  spread:
    zone: ScheduleAnyway
    minDomains: 2

caradhras:
  spread:
    enabled: false

caradhras:
  ui:
    spread:
      hostname: DoNotSchedule
```

**How overrides work:**

- Each field set in `<component>.spread` overrides the corresponding field from `global.scheduling.spread`
- Unset fields inherit the global value
- Setting `spread: {}` (empty) means "use all global defaults"
- Setting `spread.enabled: false` disables the spread preset for that component only

> **Important:** For the caradhras component, `nodeSelector`, `affinity`, and `tolerations` still come from `auth.*` (unchanged behavior), but spreading is controlled by `caradhras.spread` and `caradhras.topologySpreadConstraints`.

### Raw Topology Spread Constraints

For full control, you can provide raw Kubernetes `topologySpreadConstraints`:

```yaml
identity:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      # labelSelector is auto-filled with the component's selector labels
    - maxSkew: 2
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          custom-label: custom-value
```

**How raw constraints work:**

- A non-empty `topologySpreadConstraints` list replaces the spread preset entirely for that component
- If an entry omits `labelSelector`, the chart automatically fills it with the component's selector labels (matching `spec.selector.matchLabels`)
- If you provide your own `labelSelector`, it's used as-is

> **Warning:** When using raw `topologySpreadConstraints`, the `spread` settings (both global and per-component) are ignored for that component. You must configure all desired constraints manually.

# Migration Scenarios

### Scenario 1: Default Upgrade (No Action Required)

If you're satisfied with the default soft hostname spreading, no changes are needed.

**What happens:**

- All components will have soft hostname spreading enabled (`hostname: ScheduleAnyway`, `maxSkew: 1`)
- Pods will be distributed across nodes when possible, but scheduling won't fail if spreading isn't achievable
- Your existing `nodeSelector`, `affinity`, and `tolerations` settings continue to work

**Upgrade command:**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.6.0 -n plugin-access-manager
```

### Scenario 2: Customizing Spread Behavior

If you want to adjust the spread behavior (e.g., enable zone spreading, use hard constraints, or change maxSkew), override the global or per-component settings.

**Example: Enable zone spreading on a cloud-managed cluster**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ScheduleAnyway
      maxSkew: 1
```

**Example: Use hard hostname spreading for auth and caradhras**

```yaml
global:
  scheduling:
    spread:
      hostname: ScheduleAnyway

auth:
  spread:
    hostname: DoNotSchedule

caradhras:
  spread:
    hostname: DoNotSchedule
```

**Example: Configure for autoscaled clusters (Karpenter)**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule
      minDomains: 0
      nodeTaintsPolicy: Honor
```

> **Note:** With `minDomains: 0` and `hostname: DoNotSchedule`, if you have fewer nodes than replicas, the scheduler treats the global minimum as 0, allowing extra replicas to wait for new nodes. Karpenter will provision them automatically. `nodeTaintsPolicy: Honor` ensures the scheduler skips nodes being drained.

**Upgrade command:**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.6.0 -n plugin-access-manager -f values.yaml
```

### Scenario 3: Using Raw Topology Spread Constraints

If you need full control over topology spread constraints (e.g., custom topology keys, multiple constraints, or specific label selectors), use the raw `topologySpreadConstraints` field.

**Example: Custom spread constraints for identity**

```yaml
identity:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      # labelSelector auto-filled with identity's selector labels
    - maxSkew: 2
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      matchLabelKeys:
        - pod-template-hash
```

> **Important:** When you provide `topologySpreadConstraints`, the `spread` preset is completely replaced for that component. You must define all desired constraints manually.

**Upgrade command:**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.6.0 -n plugin-access-manager -f values.yaml
```

### Scenario 4: Disabling Spread Constraints

If you don't want topology spread constraints (e.g., single-node development clusters), disable them globally or per-component.

**Example: Disable globally**

```yaml
global:
  scheduling:
    spread:
      enabled: false
```

**Example: Disable for specific components**

```yaml
identity:
  spread:
    enabled: false

auth:
  spread:
    enabled: false
```

**Upgrade command:**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.6.0 -n plugin-access-manager --set global.scheduling.spread.enabled=false
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.6.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.6.0 -n plugin-access-manager
```
