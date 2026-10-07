# Helm Upgrade from v4.3.13 to v4.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Global pod scheduling configuration](#1-global-pod-scheduling-configuration)
  - [2. Per-component scheduling overrides](#2-per-component-scheduling-overrides)
  - [3. Topology spread constraints support](#3-topology-spread-constraints-support)
  - [4. lerian-common-helm dependency upgrade](#4-lerian-common-helm-dependency-upgrade)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that introduces environment-wide pod scheduling configuration with topology spread constraints. The new `global.scheduling.spread` preset enables operators to control pod distribution across nodes and availability zones for both the manager and worker components. The `lerian-common-helm` dependency has been upgraded from `2.1.2` to `2.3.0` to provide the underlying scheduling template helpers. The application version remains unchanged at `4.5.0`.

| Field | v4.3.13 | v4.4.0 |
|-------|---------|--------|
| Chart version | `4.3.13` | `4.4.0` |
| App version | `4.5.0` | `4.5.0` |
| lerian-common-helm dependency | `2.1.2` | `2.3.0` |

## Features

### 1. Global pod scheduling configuration

A new `global.scheduling.spread` configuration block has been added to control pod distribution across topology domains (nodes and availability zones) for all components. This preset applies to both the manager Deployment and the worker Deployment (when `keda.enabled=false`).

**New fields added:**

| Field | Default | Description |
|-------|---------|-------------|
| `global.scheduling.spread.enabled` | `true` | Master switch for the spread preset |
| `global.scheduling.spread.hostname` | `ScheduleAnyway` | Spread across nodes (kubernetes.io/hostname): `ScheduleAnyway` (soft) \| `DoNotSchedule` (hard) \| `""` (off) |
| `global.scheduling.spread.zone` | `""` | Spread across zones (topology.kubernetes.io/zone): `ScheduleAnyway` \| `DoNotSchedule` \| `""` (off) |
| `global.scheduling.spread.maxSkew` | `1` | Max allowed pod-count difference between topology domains (integer >= 1) |
| `global.scheduling.spread.minDomains` | `0` | Minimum eligible domains for DoNotSchedule constraints (0 = off) |
| `global.scheduling.spread.nodeTaintsPolicy` | `""` | `Honor` \| `Ignore` \| `""` (omitted = Kubernetes default Ignore) |

**Default configuration (v4.4.0):**

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

The default configuration enables soft spreading across nodes (`hostname: ScheduleAnyway`) with a maximum skew of 1 pod. Zone spreading is disabled by default because the scheduler skips nodes without the `topology.kubernetes.io/zone` label when scoring a soft spread constraint, which can silently cancel the hostname spread on bare-metal or k3s clusters.

**Rendered topologySpreadConstraints (default):**

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: reporter-manager
        app.kubernetes.io/instance: reporter
    matchLabelKeys:
      - pod-template-hash
```

> **Note:** Each constraint counts only the component's own pods (via `labelSelector`) of the same ReplicaSet (via `matchLabelKeys: [pod-template-hash]`), so rolling updates never deadlock. The `matchLabelKeys` field requires Kubernetes 1.25+.

**Example: Hard spreading across nodes and zones on EKS/GKE/AKS:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule
      zone: DoNotSchedule
      maxSkew: 1
```

**Example: Soft spreading with minDomains for autoscaled clusters:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule
      zone: DoNotSchedule
      maxSkew: 1
      minDomains: 2
```

With `minDomains: 2` and `hostname: DoNotSchedule`, the scheduler treats the global minimum as 0 when fewer than 2 nodes exist, so a hard hostname spread never stacks replicas on a single node. The extra replica waits for a new node, which Karpenter or Cluster Autoscaler will launch.

**Example: Honor node taints (skip draining nodes):**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      nodeTaintsPolicy: Honor
```

With `nodeTaintsPolicy: Honor`, the scheduler counts only nodes whose taints the pod tolerates. This skips nodes that Karpenter is draining (tainted `karpenter.sh/disrupted`) when calculating pod distribution.

### 2. Per-component scheduling overrides

Both `manager` and `worker` now support a `spread` configuration block that overrides individual fields from `global.scheduling.spread`. Each field set at the component level wins over the global one.

**New fields added:**

| Component | Field | Description |
|-----------|-------|-------------|
| `manager` | `spread` | Per-component override of `global.scheduling.spread` (same fields: `enabled`, `hostname`, `zone`, `maxSkew`, `minDomains`, `nodeTaintsPolicy`) |
| `worker` | `spread` | Per-component override of `global.scheduling.spread` (same fields: `enabled`, `hostname`, `zone`, `maxSkew`, `minDomains`, `nodeTaintsPolicy`) |

**Example: Override hostname spread for manager only:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway

manager:
  spread:
    hostname: DoNotSchedule
```

The manager will use hard spreading (`DoNotSchedule`) while the worker inherits the global soft spreading (`ScheduleAnyway`).

**Example: Disable spread for worker only:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway

worker:
  spread:
    enabled: false
```

The manager will use the global spread preset, while the worker will have no topology spread constraints.

### 3. Topology spread constraints support

Both `manager` and `worker` now support raw Kubernetes `topologySpreadConstraints` via a new `topologySpreadConstraints` field. When this field is non-empty, it replaces the spread preset entirely for that component.

**New fields added:**

| Component | Field | Description |
|-----------|-------|-------------|
| `manager` | `topologySpreadConstraints` | Raw Kubernetes topologySpreadConstraints list. Non-empty = replaces the spread preset entirely |
| `worker` | `topologySpreadConstraints` | Raw Kubernetes topologySpreadConstraints list. Non-empty = replaces the spread preset entirely |

**Example: Custom topology spread constraints for manager:**

```yaml
manager:
  topologySpreadConstraints:
    - maxSkew: 2
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: reporter-manager
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
```

> **Important:** When using raw `topologySpreadConstraints`, you must provide the `labelSelector` for each constraint. If you omit `labelSelector`, the chart will inject the component's selector labels automatically.

### 4. lerian-common-helm dependency upgrade

The `lerian-common-helm` subchart dependency has been upgraded from `2.1.2` to `2.3.0`. This upgrade provides the `lerian-common.scheduling` template helper that renders the combined scheduling configuration (nodeSelector, affinity, tolerations, and topologySpreadConstraints).

| Dependency | v4.3.13 | v4.4.0 |
|------------|---------|--------|
| `lerian-common-helm` | `2.1.2` | `2.3.0` |

The template changes in `manager/deployment.yaml` and `worker/deployment.yaml` replace the inline `nodeSelector`, `affinity`, and `tolerations` blocks with a single call to `lerian-common.scheduling`:

**Before (v4.3.13):**

```yaml
{{- with .Values.manager.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 8 }}
{{- end }}
{{- with .Values.manager.affinity }}
affinity:
  {{- toYaml . | nindent 8 }}
{{- end }}
{{- with .Values.manager.tolerations }}
tolerations:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

**After (v4.4.0):**

```yaml
{{- /* nodeSelector / affinity / tolerations + topologySpreadConstraints
       (global.scheduling.spread preset, manager.spread, manager.topologySpreadConstraints).
       selectorLabels MUST equal spec.selector.matchLabels above. */}}
{{- with (include "lerian-common.scheduling" (dict
      "component" .Values.manager
      "global" .Values.global
      "selectorLabels" (include "plugin-manager.selectorLabels" (dict "context" . "name" .Values.manager.name))) | trim) }}
{{- . | nindent 6 }}
{{- end }}
```

The `lerian-common.scheduling` helper merges the component's `nodeSelector`, `affinity`, and `tolerations` with the topology spread constraints generated from the spread preset or raw `topologySpreadConstraints` field.

> **Note:** The existing `manager.nodeSelector`, `manager.affinity`, `manager.tolerations`, `worker.nodeSelector`, `worker.affinity`, and `worker.tolerations` fields remain fully supported and are merged into the final scheduling configuration.

## Configuration Reference

### Global scheduling fields

| Field | Default | Description |
|-------|---------|-------------|
| `global.scheduling.spread.enabled` | `true` | Master switch for the spread preset |
| `global.scheduling.spread.hostname` | `ScheduleAnyway` | Spread across nodes (kubernetes.io/hostname): `ScheduleAnyway` (soft) \| `DoNotSchedule` (hard) \| `""` (off) |
| `global.scheduling.spread.zone` | `""` | Spread across zones (topology.kubernetes.io/zone): `ScheduleAnyway` \| `DoNotSchedule` \| `""` (off) |
| `global.scheduling.spread.maxSkew` | `1` | Max allowed pod-count difference between topology domains (integer >= 1) |
| `global.scheduling.spread.minDomains` | `0` | Minimum eligible domains for DoNotSchedule constraints (0 = off) |
| `global.scheduling.spread.nodeTaintsPolicy` | `""` | `Honor` \| `Ignore` \| `""` (omitted = Kubernetes default Ignore) |

### Per-component scheduling fields

| Component | Field | Default | Description |
|-----------|-------|---------|-------------|
| `manager` | `spread` | `{}` | Per-component override of `global.scheduling.spread` (same fields: `enabled`, `hostname`, `zone`, `maxSkew`, `minDomains`, `nodeTaintsPolicy`) |
| `manager` | `topologySpreadConstraints` | `[]` | Raw Kubernetes topologySpreadConstraints. Non-empty = replaces the spread preset entirely |
| `worker` | `spread` | `{}` | Per-component override of `global.scheduling.spread` (same fields: `enabled`, `hostname`, `zone`, `maxSkew`, `minDomains`, `nodeTaintsPolicy`) |
| `worker` | `topologySpreadConstraints` | `[]` | Raw Kubernetes topologySpreadConstraints. Non-empty = replaces the spread preset entirely |

## Migration Steps

This upgrade requires no mandatory configuration changes. The default spread preset (`global.scheduling.spread.enabled=true`, `hostname=ScheduleAnyway`) applies automatically to both manager and worker Deployments.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Decide whether to enable zone spreading. If your cluster runs on EKS, GKE, or AKS (where every node has a `topology.kubernetes.io/zone` label), enable zone spreading:

   ```yaml
   global:
     scheduling:
       spread:
         enabled: true
         hostname: ScheduleAnyway
         zone: ScheduleAnyway
   ```

   If your cluster runs on bare-metal or k3s (where nodes may lack zone labels), leave zone spreading disabled (the default).

3. If you run on an autoscaled cluster (Karpenter, Cluster Autoscaler), consider enabling `minDomains` to prevent hard constraints from blocking pod scheduling when fewer domains exist than `maxSkew`:

   ```yaml
   global:
     scheduling:
       spread:
         enabled: true
         hostname: DoNotSchedule
         minDomains: 2
   ```

4. If you want the scheduler to skip nodes that are being drained (e.g., Karpenter's `karpenter.sh/disrupted` taint), enable `nodeTaintsPolicy: Honor`:

   ```yaml
   global:
     scheduling:
       spread:
         enabled: true
         hostname: ScheduleAnyway
         nodeTaintsPolicy: Honor
   ```

5. Run the upgrade command during a maintenance window.

6. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n <namespace>
   ```

7. Check the rendered topology spread constraints for both components:

   ```bash
   kubectl get deployment -n <namespace> reporter-manager -o yaml | grep -A20 topologySpreadConstraints
   kubectl get deployment -n <namespace> reporter-worker -o yaml | grep -A20 topologySpreadConstraints
   ```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. The new topology spread constraints take effect immediately, but existing pods are not rescheduled unless they are replaced during the rolling update.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.4.0 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.4.0 -n reporter
```
