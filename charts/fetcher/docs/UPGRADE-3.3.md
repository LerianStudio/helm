# Helm Upgrade from v3.2.0 to v3.3.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Topology spread constraint enhancements](#1-topology-spread-constraint-enhancements)
  - [2. lerian-common-helm dependency update](#2-lerian-common-helm-dependency-update)
- **[Configuration Reference](#configuration-reference)**
  - [New topology spread constraint fields](#new-topology-spread-constraint-fields)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.2.0` to `3.3.0`. This is a minor release that enhances pod topology spread constraints with two new optional fields for improved scheduling behavior in autoscaled clusters.

The application version (`appVersion: 3.1.0`) is unchanged. The `lerian-common-helm` dependency has been updated from `2.2.0` to `2.3.0`. No breaking changes, no required `values.yaml` modifications, and no data migration are needed.

## Features

### 1. Topology spread constraint enhancements

The global topology spread constraint configuration now supports two additional fields to fine-tune pod scheduling behavior in autoscaled environments:

**Before (v3.2.0):**

```yaml
global:
  topologySpreadConstraints:
    enabled: true
    zone: ""
    maxSkew: 1
```

**After (v3.3.0):**

```yaml
global:
  topologySpreadConstraints:
    enabled: true
    zone: ""
    maxSkew: 1
    minDomains: 0
    nodeTaintsPolicy: ""
```

| Setting | v3.2.0 | v3.3.0 |
|---------|--------|--------|
| `global.topologySpreadConstraints.minDomains` | (not set) | `0` (default) |
| `global.topologySpreadConstraints.nodeTaintsPolicy` | (not set) | `""` (default, omitted) |

#### minDomains

The `minDomains` field controls the minimum number of eligible topology domains required for `DoNotSchedule` (hard) topology spread constraints. When set to a value greater than `0`, if the number of eligible domains is less than `minDomains`, the scheduler treats the global minimum as `0`. This prevents a hard hostname spread from stacking replicas on a single node when insufficient nodes are available — instead, the extra replica waits for a new node to be provisioned.

**Use case:** In autoscaled clusters (e.g., with Karpenter), setting `minDomains: 1` ensures that when a hard hostname spread constraint is active and only one node exists, the scheduler will trigger node autoscaling rather than violating the spread constraint by placing multiple replicas on the same node.

**Example configuration:**

```yaml
global:
  topologySpreadConstraints:
    enabled: true
    zone: "kubernetes.io/hostname"
    maxSkew: 1
    minDomains: 1
```

> **Note:** `minDomains` only affects `DoNotSchedule` constraints. If your topology spread constraints use `ScheduleAnyway` (soft constraints), this field has no effect. The default value of `0` disables this behavior, maintaining backward compatibility.

#### nodeTaintsPolicy

The `nodeTaintsPolicy` field controls whether the scheduler considers node taints when counting eligible domains for topology spread constraints. Valid values are:

- `Honor`: Only count nodes whose taints the pod tolerates
- `Ignore`: Count all nodes regardless of taints (Kubernetes default)
- `""` (empty string): Omit the field, allowing Kubernetes to apply its default behavior (`Ignore`)

**Use case:** In clusters with node lifecycle management (e.g., Karpenter draining nodes with `karpenter.sh/disrupted` taints), setting `nodeTaintsPolicy: Honor` ensures the scheduler skips nodes being drained when calculating topology spread, improving pod placement during node churn.

**Example configuration:**

```yaml
global:
  topologySpreadConstraints:
    enabled: true
    zone: "kubernetes.io/hostname"
    maxSkew: 1
    nodeTaintsPolicy: "Honor"
```

> **Note:** The default value is an empty string (`""`), which omits the field from the rendered topology spread constraint. This maintains backward compatibility with Kubernetes versions that do not support `nodeTaintsPolicy` or clusters where the default `Ignore` behavior is desired.

### 2. lerian-common-helm dependency update

The `lerian-common-helm` dependency has been updated from version `2.2.0` to `2.3.0`. This is a minor update to the shared library chart that provides common templates and helpers for Lerian Studio charts.

| Dependency | v3.2.0 | v3.3.0 |
|------------|--------|--------|
| `lerian-common-helm` | `2.2.0` | `2.3.0` |

> **Note:** Consult the `lerian-common-helm` release notes for details on changes between `2.2.0` and `2.3.0`. This dependency update is transparent to operators and requires no configuration changes.

## Configuration Reference

### New topology spread constraint fields

The following fields have been added to the global topology spread constraint configuration:

| Flag | Default | Description |
|------|---------|-------------|
| `minDomains` | `0` | Minimum eligible domains for `DoNotSchedule` constraints. When set to a value greater than `0`, if fewer domains exist, the scheduler treats the global minimum as `0`, allowing autoscalers to provision new nodes instead of violating hard spread constraints. Use on autoscaled clusters. |
| `nodeTaintsPolicy` | `""` (omitted) | Controls whether the scheduler honors node taints when counting eligible domains. `Honor` counts only nodes the pod tolerates (e.g., skips nodes with `karpenter.sh/disrupted` taints). `Ignore` counts all nodes. Empty string omits the field (Kubernetes default `Ignore`). |

**Example configuration for autoscaled clusters:**

```yaml
global:
  topologySpreadConstraints:
    enabled: true
    zone: "kubernetes.io/hostname"
    maxSkew: 1
    minDomains: 1
    nodeTaintsPolicy: "Honor"
```

**Example configuration to maintain v3.2.0 behavior:**

```yaml
global:
  topologySpreadConstraints:
    enabled: true
    zone: ""
    maxSkew: 1
    minDomains: 0
    nodeTaintsPolicy: ""
```

> **Important:** Both fields are optional and default to values that maintain backward compatibility. No action is required unless you want to enable the new scheduling behaviors.

## Migration Steps

This upgrade requires no manual migration steps. The new topology spread constraint fields are optional and default to backward-compatible values.

**Recommended upgrade process:**

1. Review the new `minDomains` and `nodeTaintsPolicy` fields to determine if they are beneficial for your cluster environment.
2. If running on an autoscaled cluster (e.g., with Karpenter), consider setting `minDomains: 1` and `nodeTaintsPolicy: "Honor"` to improve pod scheduling behavior.
3. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
4. Run the upgrade command during a maintenance window.
5. Verify all pods are running and properly distributed:

```bash
kubectl get pods -n fetcher -o wide
```

6. Check for any pod scheduling events related to topology spread constraints:

```bash
kubectl get events -n fetcher --sort-by='.lastTimestamp' | grep -i topology
```

> **Note:** If you do not set the new fields explicitly, the chart will render topology spread constraints identical to v3.2.0, ensuring no change in scheduling behavior.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.3.0 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.3.0 -n fetcher
```
