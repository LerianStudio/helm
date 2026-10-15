# Helm Upgrade from v4.3.1 to v4.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version upgrade to 2.8.0](#1-application-version-upgrade-to-280)
  - [2. Common library upgrade to 2.3.0](#2-common-library-upgrade-to-230)
  - [3. Global pod scheduling configuration](#3-global-pod-scheduling-configuration)
  - [4. Topology spread constraints support](#4-topology-spread-constraints-support)
  - [5. Simplified deployment template scheduling](#5-simplified-deployment-template-scheduling)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This minor release upgrades the product-console application to version 2.8.0 and introduces a new global pod scheduling system with topology spread constraints. The lerian-common-helm dependency has been upgraded from 2.0.0 to 2.3.0, bringing new scheduling capabilities that help distribute pods across nodes and availability zones.

| Field | v4.3.1 | v4.4.0 |
|-------|--------|--------|
| Chart version | `4.3.1` | `4.4.0` |
| App version | `2.6.0` | `2.8.0` |
| Image tag | `2.6.0` | `2.8.0` |
| lerian-common-helm | `2.0.0` | `2.3.0` |

## Features

### 1. Application version upgrade to 2.8.0

The product-console application has been upgraded from version 2.6.0 to 2.8.0. The image tag is automatically updated to match the new appVersion.

| Setting | v4.3.1 | v4.4.0 |
|---------|--------|--------|
| `image.tag` | `"2.6.0"` | `"2.8.0"` |

No configuration changes are required for this upgrade. The new application version will be deployed automatically during the Helm upgrade.

### 2. Common library upgrade to 2.3.0

The lerian-common-helm dependency has been upgraded from 2.0.0 to 2.3.0. This upgrade brings new scheduling capabilities, including the `lerian-common.scheduling` helper template and the `lerian-common.topologySpreadConstraints` preset.

| Dependency | v4.3.1 | v4.4.0 |
|------------|--------|--------|
| `lerian-common-helm` | `2.0.0` | `2.3.0` |

### 3. Global pod scheduling configuration

A new `global.scheduling` configuration block has been added to provide environment-wide pod scheduling defaults. This block controls topology spread constraints that distribute pods across nodes and availability zones.

**New configuration block:**

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
      zone: ""
      # Max allowed pod-count difference between topology domains
      maxSkew: 1
      # Minimum eligible domains for DoNotSchedule constraints (0 = off)
      minDomains: 0
      # Honor | Ignore | "" (omitted = Kubernetes default Ignore)
      nodeTaintsPolicy: ""
```

**Default values:**

| Flag | Default | Description |
|------|---------|-------------|
| `global.scheduling.spread.enabled` | `true` | Master switch for the spread preset |
| `global.scheduling.spread.hostname` | `ScheduleAnyway` | Soft spread across nodes (kubernetes.io/hostname) |
| `global.scheduling.spread.zone` | `""` | Zone spread disabled by default (topology.kubernetes.io/zone) |
| `global.scheduling.spread.maxSkew` | `1` | Maximum pod-count difference between domains |
| `global.scheduling.spread.minDomains` | `0` | Minimum eligible domains (0 = off) |
| `global.scheduling.spread.nodeTaintsPolicy` | `""` | Node taints policy (omitted = Kubernetes default Ignore) |

> **Important:** The zone spread is disabled by default because the scheduler skips nodes without the zone label when scoring a soft spread. On clusters missing zone labels (bare-metal, k3s), a zone constraint silently cancels the hostname spread. Enable zone spread only on clusters where every node has zone labels (EKS, GKE, AKS).

**Example: Enable hard spread across nodes on autoscaled clusters:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule
      minDomains: 0
```

**Example: Enable soft spread across both nodes and zones:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ScheduleAnyway
      maxSkew: 1
```

### 4. Topology spread constraints support

Two new top-level configuration keys have been added to control pod scheduling at the component level: `spread` and `topologySpreadConstraints`.

**New configuration keys:**

```yaml
# Override global.scheduling.spread for the console Deployment
spread: {}

# Raw Kubernetes topologySpreadConstraints
topologySpreadConstraints: []
```

| Key | Default | Description |
|-----|---------|-------------|
| `spread` | `{}` | Override of `global.scheduling.spread` for the console Deployment; each field set here wins over the global one |
| `topologySpreadConstraints` | `[]` | Raw Kubernetes topologySpreadConstraints; non-empty replaces the spread preset entirely |

**How it works:**

1. If `topologySpreadConstraints` is non-empty, it replaces the spread preset entirely
2. If `topologySpreadConstraints` is empty, the chart uses the spread preset from `global.scheduling.spread` merged with component-level `spread` overrides
3. Each constraint without `labelSelector` automatically gets the Deployment's selector labels
4. Each constraint counts only this component's own pods of the same ReplicaSet (matchLabelKeys: [pod-template-hash]), so rolling updates never deadlock

**Example: Override global spread for console only:**

```yaml
spread:
  hostname: DoNotSchedule
  maxSkew: 2
```

**Example: Use raw topologySpreadConstraints:**

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
  - maxSkew: 2
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
```

### 5. Simplified deployment template scheduling

The deployment template has been refactored to use the new `lerian-common.scheduling` helper template. This change consolidates `nodeSelector`, `affinity`, `tolerations`, and `topologySpreadConstraints` into a single template call.

**Before (v4.3.1):**

```yaml
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 8 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 8 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

**After (v4.4.0):**

```yaml
{{- /* nodeSelector / affinity / tolerations + topologySpreadConstraints
       (global.scheduling.spread preset, top-level spread / topologySpreadConstraints).
       selectorLabels MUST equal spec.selector.matchLabels above. */}}
{{- with (include "lerian-common.scheduling" (dict
      "component" .Values
      "global" .Values.global
      "selectorLabels" (include "product-console.selectorLabels" .)) | trim) }}
{{- . | nindent 6 }}
{{- end }}
```

**Operational impact:**

- Existing `nodeSelector`, `affinity`, and `tolerations` configurations continue to work without changes
- The new template adds topology spread constraints based on `global.scheduling.spread`, component-level `spread`, or raw `topologySpreadConstraints`
- The spread preset is enabled by default with soft hostname spread (`ScheduleAnyway`), which improves pod distribution across nodes without blocking scheduling
- Rolling updates will not deadlock because each constraint uses `matchLabelKeys: [pod-template-hash]` to count only pods of the same ReplicaSet

## Configuration Reference

### Global scheduling configuration

```yaml
global:
  scheduling:
    spread:
      # Master switch for the spread preset
      enabled: true
      
      # Spread across nodes (kubernetes.io/hostname)
      # ScheduleAnyway = soft (prefer spreading, but schedule anyway)
      # DoNotSchedule = hard (never violate maxSkew)
      # "" = off (no hostname constraint)
      hostname: ScheduleAnyway
      
      # Spread across zones (topology.kubernetes.io/zone)
      # ScheduleAnyway | DoNotSchedule | "" (off)
      # Off by default: enable only on clusters where every node has zone labels
      zone: ""
      
      # Max allowed pod-count difference between topology domains (integer >= 1)
      maxSkew: 1
      
      # Minimum eligible domains for DoNotSchedule constraints (0 = off)
      # With fewer domains the scheduler treats the global minimum as 0
      # Use on autoscaled clusters to prevent stacking replicas on a single node
      minDomains: 0
      
      # Honor | Ignore | "" (omitted = Kubernetes default Ignore)
      # Honor counts only nodes whose taints the pod tolerates
      nodeTaintsPolicy: ""
```

### Component-level scheduling configuration

```yaml
# Override of global.scheduling.spread for the console Deployment
# Each field set here wins over the global one
spread:
  hostname: DoNotSchedule
  maxSkew: 2

# Raw Kubernetes topologySpreadConstraints
# Non-empty = replaces the spread preset entirely
# An entry without labelSelector gets the Deployment's selector labels
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
```

### Existing scheduling configuration (unchanged)

```yaml
# Node selector for scheduling pods on specific nodes
nodeSelector: {}

# Tolerations for scheduling on tainted nodes
tolerations: []

# Affinity rules for pod scheduling
affinity: {}
```

## Migration Steps

This upgrade requires no mandatory configuration changes. The new scheduling features are enabled by default with safe settings that improve pod distribution without blocking scheduling.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify your cluster setup:
   - Check if your nodes have zone labels (required for zone spread):
     ```bash
     kubectl get nodes --show-labels | grep topology.kubernetes.io/zone
     ```
   - If zone labels are present on all nodes, consider enabling zone spread:
     ```yaml
     global:
       scheduling:
         spread:
           zone: ScheduleAnyway
     ```

3. Run the upgrade command during a maintenance window.

4. Verify all pods are running and properly distributed after the upgrade:
   ```bash
   kubectl get pods -n product-console -o wide
   ```

5. Check that topology spread constraints are applied:
   ```bash
   kubectl get pod -n product-console -l app.kubernetes.io/name=product-console -o yaml | grep -A10 topologySpreadConstraints
   ```

6. Monitor for any scheduling issues in the deployment events:
   ```bash
   kubectl describe deployment -n product-console product-console | grep -A10 Events
   ```

> **Note:** The default soft hostname spread (`ScheduleAnyway`) will not block pod scheduling. Pods will be distributed across nodes when possible, but will still schedule even if optimal spreading cannot be achieved.

> **Warning:** If you enable hard spread (`DoNotSchedule`) on clusters with fewer nodes than replicas, pods may remain Pending until additional nodes are available. Use `minDomains: 0` on autoscaled clusters to prevent this issue.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.0 -n product-console
```
