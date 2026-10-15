# Helm Upgrade from v9.5.0 to v9.6.0

## Topics

- **[Features](#features)**
  - [1. Pod Topology Spread Constraints (Global Scheduling)](#1-pod-topology-spread-constraints-global-scheduling)
  - [2. Lerian Common Helm Library Upgrade](#2-lerian-common-helm-library-upgrade)
- **[Configuration Reference](#configuration-reference)**
  - [Global Scheduling Configuration](#global-scheduling-configuration)
  - [Component-Level Overrides](#component-level-overrides)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Pod Topology Spread Constraints (Global Scheduling)

Version 9.6.0 introduces a new global scheduling framework that enables operators to control pod distribution across nodes and availability zones using Kubernetes topology spread constraints. This feature improves high availability and resilience by preventing pod concentration on single nodes or zones.

#### What Changed

The chart now supports a centralized `global.scheduling.spread` configuration that applies topology spread constraints to all three Midaz components (ledger, crm, tracer). Each component can override these global settings or provide raw `topologySpreadConstraints` for advanced use cases.

The deployment templates for ledger, crm, and tracer have been refactored to use the `lerian-common.scheduling` helper template, which generates `nodeSelector`, `affinity`, `tolerations`, and `topologySpreadConstraints` fields based on the merged global and component-level configuration.

#### Why This Matters

- **High Availability**: Spread replicas across nodes and zones to survive node or zone failures
- **Resource Efficiency**: Prevent hotspots by distributing load evenly
- **Autoscaling Support**: Use `minDomains` to ensure new nodes are provisioned when needed (e.g., with Karpenter)
- **Rolling Update Safety**: Constraints automatically scope to the current ReplicaSet using `matchLabelKeys: [pod-template-hash]`, preventing deadlocks during rollouts

#### Default Behavior

| Setting | v9.5.0 | v9.6.0 |
|---------|--------|--------|
| Topology spread constraints | Not available | Enabled by default with soft hostname spread |
| Global scheduling config | Not available | `global.scheduling.spread` |
| Component overrides | Not available | `<component>.spread` and `<component>.topologySpreadConstraints` |

By default, the spread preset is **enabled** with a **soft** (ScheduleAnyway) hostname constraint:

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

This means:
- Pods will be distributed across nodes when possible, but the scheduler will still place pods even if it violates the constraint
- Zone spreading is **disabled by default** to avoid issues on clusters without zone labels (bare-metal, k3s)
- No minimum domain requirement

### 2. Lerian Common Helm Library Upgrade

The `lerian-common-helm` dependency has been upgraded from version `2.1.2` to `2.3.0`. This upgrade provides the new `lerian-common.scheduling` template helper that powers the topology spread constraints feature.

| Dependency | v9.5.0 | v9.6.0 |
|------------|--------|--------|
| lerian-common-helm | 2.1.2 | 2.3.0 |

## Configuration Reference

### Global Scheduling Configuration

The new `global.scheduling.spread` section controls the default topology spread behavior for all components:

```yaml
global:
  scheduling:
    spread:
      # Master switch for the spread preset
      enabled: true
      
      # Spread across nodes (kubernetes.io/hostname)
      # Options: ScheduleAnyway (soft) | DoNotSchedule (hard) | "" (off)
      hostname: ScheduleAnyway
      
      # Spread across zones (topology.kubernetes.io/zone)
      # Options: ScheduleAnyway | DoNotSchedule | "" (off)
      # Default: "" (disabled) - enable only on clusters with zone labels
      zone: ""
      
      # Max allowed pod-count difference between topology domains
      maxSkew: 1
      
      # Minimum eligible domains for DoNotSchedule constraints
      # 0 = off, >0 = scheduler treats global minimum as 0
      minDomains: 0
      
      # Honor pod tolerations when counting domains
      # Options: Honor | Ignore | "" (omitted = Kubernetes default Ignore)
      nodeTaintsPolicy: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `enabled` | `true` | Master switch for the spread preset |
| `hostname` | `ScheduleAnyway` | Spread across nodes: soft (ScheduleAnyway), hard (DoNotSchedule), or disabled ("") |
| `zone` | `""` | Spread across zones: soft, hard, or disabled (default: disabled) |
| `maxSkew` | `1` | Maximum pod count difference between domains |
| `minDomains` | `0` | Minimum domains required for hard constraints (0 = disabled) |
| `nodeTaintsPolicy` | `""` | Whether to honor pod tolerations when counting domains |

> **Important:** Zone spreading is disabled by default because the scheduler skips nodes without the `topology.kubernetes.io/zone` label when scoring soft constraints. On clusters without zone labels (bare-metal, k3s), enabling zone spread will silently cancel the hostname spread. Only enable zone spreading on managed Kubernetes clusters (EKS, GKE, AKS) where every node has zone labels.

### Component-Level Overrides

Each component (ledger, crm, tracer) can override the global spread settings or provide raw topology spread constraints:

#### Option 1: Override specific spread fields

```yaml
ledger:
  spread:
    # Override only the hostname policy to hard constraint
    hostname: DoNotSchedule
    # Other fields inherit from global.scheduling.spread
```

#### Option 2: Provide raw topologySpreadConstraints

```yaml
ledger:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      # labelSelector is auto-injected with component's selector labels
    - maxSkew: 2
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
```

> **Note:** When `topologySpreadConstraints` is non-empty, it completely replaces the spread preset. The `labelSelector` field is automatically injected with the component's selector labels if omitted.

#### Template Changes

**Before (v9.5.0):**

```yaml
# ledger/deployment.yaml
      {{- with .Values.ledger.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.ledger.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.ledger.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

**After (v9.6.0):**

```yaml
# ledger/deployment.yaml
      {{- /* nodeSelector / affinity / tolerations + topologySpreadConstraints
             (global.scheduling.spread preset, ledger.spread, ledger.topologySpreadConstraints).
             selectorLabels MUST equal spec.selector.matchLabels above. */}}
      {{- with (include "lerian-common.scheduling" (dict
            "component" .Values.ledger
            "global" .Values.global
            "selectorLabels" (include "midaz.selectorLabels" (dict "context" . "name" .Values.ledger.name ))) | trim) }}
      {{- . | nindent 6 }}
      {{- end }}
```

The same pattern applies to `crm/deployment.yaml` and `tracer/deployment.yaml`.

**Operational Impact:**

- Existing `nodeSelector`, `affinity`, and `tolerations` configurations continue to work unchanged
- New `topologySpreadConstraints` are automatically added based on the spread preset
- The `lerian-common.scheduling` helper merges all scheduling fields into a single block
- Component selector labels are automatically injected into topology spread constraints to ensure correct pod counting

## Migration Steps

### Step 1: Review Current Deployment Topology

Before upgrading, check how your pods are currently distributed:

```bash
kubectl get pods -n midaz -o wide --selector='app.kubernetes.io/name=midaz' --sort-by='.spec.nodeName'
```

### Step 2: Decide on Spread Strategy

Choose one of the following strategies based on your cluster topology and availability requirements:

#### Option 1: Keep Default Soft Hostname Spread

No action required. The default configuration provides soft hostname spreading with no zone constraints:

```yaml
# Default behavior - no values override needed
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ""
```

#### Option 2: Enable Hard Hostname Spread

Force pods to different nodes (requires sufficient nodes for all replicas):

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule
      maxSkew: 1
```

> **Warning:** With `DoNotSchedule`, pods will remain pending if there aren't enough nodes. Use `minDomains: 0` on autoscaled clusters to allow the scheduler to provision new nodes.

#### Option 3: Enable Zone Spreading (Managed Kubernetes Only)

Add zone-level spreading on EKS, GKE, or AKS:

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ScheduleAnyway
      maxSkew: 1
```

> **Important:** Only enable zone spreading if every node in your cluster has the `topology.kubernetes.io/zone` label. Verify with:

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone
```

#### Option 4: Configure Per-Component Spread

Override spread settings for specific components:

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway

ledger:
  spread:
    hostname: DoNotSchedule  # Hard constraint for ledger only
    minDomains: 0

crm:
  spread:
    hostname: ScheduleAnyway  # Inherits global (explicit)

tracer:
  # Uses global settings (implicit)
```

#### Option 5: Disable Spread Constraints

If you prefer to manage pod placement manually or have custom affinity rules:

```yaml
global:
  scheduling:
    spread:
      enabled: false
```

### Step 3: Test with Helm Diff

Preview the changes before applying:

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm \
  --version 9.6.0 \
  -n midaz \
  -f your-values.yaml
```

Look for new `topologySpreadConstraints` sections in the Deployment specs.

### Step 4: Upgrade and Verify

After upgrading, verify that topology spread constraints are applied:

```bash
kubectl get deployment -n midaz midaz-ledger -o yaml | grep -A 20 topologySpreadConstraints
```

Check pod distribution:

```bash
kubectl get pods -n midaz -o wide --selector='app.kubernetes.io/component=ledger' --sort-by='.spec.nodeName'
```

### Step 5: Monitor Rolling Updates

The spread constraints use `matchLabelKeys: [pod-template-hash]` to prevent deadlocks during rolling updates. Monitor the rollout:

```bash
kubectl rollout status deployment/midaz-ledger -n midaz
```

> **Note:** If pods remain pending during a rollout with `DoNotSchedule` constraints, check node availability and consider using `minDomains: 0` or switching to `ScheduleAnyway`.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.6.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.6.0 -n midaz
```
