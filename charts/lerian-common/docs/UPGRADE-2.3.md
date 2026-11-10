# Helm Upgrade from v2.2.0 to v2.3.0

## Topics ToC

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Topology Spread minDomains Support](#1-topology-spread-mindomains-support)
  - [2. Topology Spread nodeTaintsPolicy Support](#2-topology-spread-nodetaintspolicy-support)
  - [3. Enhanced maxSkew Validation](#3-enhanced-maxskew-validation)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v2.3.0 adds two new **optional** fields to the topology spread constraints preset: `minDomains` and `nodeTaintsPolicy`. These fields enhance pod spreading behavior for Kubernetes >= 1.26 (nodeTaintsPolicy) and >= 1.30 (minDomains).

**What changed:**

- The `lerian-common.topologySpreadConstraints` helper now supports `minDomains` (Kubernetes >= 1.30, GA) to prevent hard spread constraints from being satisfied by a single node when fewer eligible domains exist than the threshold
- The helper now supports `nodeTaintsPolicy` (Kubernetes >= 1.26 beta, GA 1.33) to control whether tainted nodes count toward topology spread skew calculations
- The `maxSkew` validation now enforces an upper bound (int32 max: 2147483647) and uses numeric integrality checks to handle large YAML numbers correctly

**Who should upgrade:**

- Operators running Kubernetes >= 1.30 who want to enforce minimum domain counts for hard spread constraints (e.g. prevent 2 replicas from sharing a single node in a Karpenter pool)
- Operators running Kubernetes >= 1.26 who want tainted nodes (e.g. nodes being drained by Karpenter) to be excluded from topology spread skew calculations
- All operators consuming product charts that use the `lerian-common.topologySpreadConstraints` helper (the new fields are optional and backward-compatible)

**Backward compatibility:**

This is a **non-breaking** change. The new fields default to off (`minDomains: 0`, `nodeTaintsPolicy: ""`), and the helper produces identical output for existing configurations. Operators who do not set these fields will see no change in behavior.

## Features

### 1. Topology Spread minDomains Support

The `minDomains` field (Kubernetes >= 1.30, GA) allows operators to enforce a minimum number of eligible topology domains for **hard (DoNotSchedule) spread constraints**. When fewer eligible domains exist than `minDomains`, the scheduler treats the global minimum as 0, keeping pods Pending until enough domains are available.

**Why it matters:**

Without `minDomains`, a hard hostname spread constraint is satisfied by a **single eligible node** holding every replica (skew is measured only against domains that exist). For example, 2 replicas on a 1-node Karpenter pool will share that node. Setting `minDomains: 2` keeps the second replica Pending until another node exists, and Karpenter honors this signal to provision a second node.

**Configuration:**

The `minDomains` field is added to the `spread` preset block at both global and component levels:

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule
      zone: ScheduleAnyway
      maxSkew: 1
      minDomains: 2  # NEW: require at least 2 eligible nodes for hostname spread
```

**Per-component override:**

```yaml
myapp:
  spread:
    minDomains: 3  # Override global minDomains for this component
```

**Behavior:**

- `minDomains` is **only emitted** on `DoNotSchedule` constraints (the Kubernetes API rejects `minDomains` with `ScheduleAnyway`)
- A value of `0` (the default) disables the feature (field is omitted from the rendered constraint)
- The field is applied to **both** hostname and zone constraints when they use `DoNotSchedule`

**Rendered output example:**

With the configuration above, the helper emits:

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: myapp
    matchLabelKeys:
      - pod-template-hash
    minDomains: 2  # NEW
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: myapp
    matchLabelKeys:
      - pod-template-hash
    # minDomains omitted (ScheduleAnyway)
```

**Kubernetes version requirement:**

- Kubernetes >= 1.30 (GA)
- The field is silently ignored on older clusters (no validation error)

### 2. Topology Spread nodeTaintsPolicy Support

The `nodeTaintsPolicy` field (Kubernetes >= 1.26 beta, GA 1.33) controls whether nodes carrying taints the pod does not tolerate count as topology domains for skew calculations.

**Why it matters:**

With the default behavior (`Ignore`), nodes carrying taints the pod does not tolerate still count as domains. This distorts skew calculations and can satisfy `minDomains` while being unable to schedule the pod. Common scenarios:

- A node Karpenter is draining (`karpenter.sh/disrupted:NoSchedule`) counts toward skew but cannot accept new pods
- A dedicated tainted pool matched by node affinity counts toward skew even if the pod does not tolerate the taint

Setting `nodeTaintsPolicy: Honor` excludes tainted nodes the pod does not tolerate from skew calculations, and Karpenter honors this signal when provisioning nodes.

**Configuration:**

The `nodeTaintsPolicy` field is added to the `spread` preset block at both global and component levels:

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule
      zone: ScheduleAnyway
      maxSkew: 1
      nodeTaintsPolicy: Honor  # NEW: exclude tainted nodes from skew
```

**Per-component override:**

```yaml
myapp:
  spread:
    nodeTaintsPolicy: Ignore  # Override global nodeTaintsPolicy for this component
```

**Allowed values:**

| Value | Behavior |
|-------|----------|
| `Honor` | Only nodes whose taints the pod tolerates count as domains |
| `Ignore` | All nodes count as domains (Kubernetes default) |
| `""` (empty string) | Field is omitted (Kubernetes applies its default: `Ignore`) |

**Rendered output example:**

With the configuration above, the helper emits:

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: myapp
    matchLabelKeys:
      - pod-template-hash
    nodeTaintsPolicy: Honor  # NEW
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: myapp
    matchLabelKeys:
      - pod-template-hash
    nodeTaintsPolicy: Honor  # NEW (applied to both constraints)
```

**Kubernetes version requirement:**

- Kubernetes >= 1.26 (beta, enabled by default)
- GA in Kubernetes 1.33
- The field is silently ignored on older clusters (no validation error)

### 3. Enhanced maxSkew Validation

The `maxSkew` validation has been improved to handle large YAML numbers correctly and enforce the Kubernetes API's int32 upper bound.

**What changed:**

- The validation now uses **numeric integrality checks** instead of string comparison to detect non-integer values (prevents scientific notation issues with large numbers)
- The validation now enforces an **upper bound** of `2147483647` (int32 max) to match the Kubernetes API limit

**Before (v2.2.0):**

```yaml
# Large maxSkew values could pass validation but fail at apply time
spread:
  maxSkew: 9999999999  # Would render but fail when applied to Kubernetes
```

**After (v2.3.0):**

```yaml
# Large maxSkew values are rejected at render time with a clear error
spread:
  maxSkew: 9999999999  # Fails: "maxSkew must be an integer between 1 and 2147483647"
```

**Error message example:**

```
Error: template: lerian-common/templates/_deployment.tpl:212:5: executing "lerian-common.topologySpreadConstraints" at <fail ...>: error calling fail: lerian-common.topologySpreadConstraints: spread.maxSkew must be an integer between 1 and 2147483647, got 9999999999
```

**Operational impact:**

Operators using valid `maxSkew` values (1–2147483647) will see no change. Operators using invalid values will now receive a clear error at render time instead of a cryptic API rejection at apply time.

## Configuration Reference

The `spread` preset block now supports two additional **optional** fields:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `minDomains` | integer | `0` (off) | Minimum number of eligible topology domains (Kubernetes >= 1.30, GA). Applied to `DoNotSchedule` constraints only. A value of `0` disables the feature. |
| `nodeTaintsPolicy` | string | `""` (omitted) | Controls whether tainted nodes count toward skew. Allowed values: `Honor`, `Ignore`, `""` (omitted = Kubernetes default `Ignore`). Kubernetes >= 1.26 beta, GA 1.33. |

**Full spread configuration example:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule       # ScheduleAnyway | DoNotSchedule | "" (off)
      zone: ScheduleAnyway          # ScheduleAnyway | DoNotSchedule | "" (off)
      maxSkew: 1                    # integer >= 1, <= 2147483647
      minDomains: 2                 # NEW: integer >= 0, 0 = off; DoNotSchedule only
      nodeTaintsPolicy: Honor       # NEW: Honor | Ignore | "" (omitted)
```

**Per-component override example:**

```yaml
myapp:
  spread:
    enabled: true
    hostname: DoNotSchedule
    zone: ""                        # Disable zone spread for this component
    maxSkew: 2
    minDomains: 3                   # Override global minDomains
    nodeTaintsPolicy: Ignore        # Override global nodeTaintsPolicy
```

**Precedence (unchanged):**

Component-level `spread.<field>` > `global.scheduling.spread.<field>` > built-in default

**Built-in defaults:**

| Field | Default |
|-------|---------|
| `enabled` | `false` |
| `hostname` | `""` (off) |
| `zone` | `""` (off) |
| `maxSkew` | `1` |
| `minDomains` | `0` (off) |
| `nodeTaintsPolicy` | `""` (omitted) |

## Migration Steps

### For Operators (Umbrella or Standalone Deployments)

The new fields are **optional** and backward-compatible. No action is required unless you want to adopt the new features.

#### Option 1: Keep Existing Configuration (No Action Required)

If you do not set `minDomains` or `nodeTaintsPolicy`, the helper produces identical output to v2.2.0. Your existing spread configuration continues to work without changes.

#### Option 2: Adopt minDomains (Kubernetes >= 1.30)

If you want to enforce minimum domain counts for hard spread constraints (e.g. prevent replicas from sharing a single node in a Karpenter pool):

1. **Verify your Kubernetes version** is >= 1.30:

```bash
kubectl version --short
```

2. **Add `minDomains` to your umbrella or product chart `values.yaml`:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule
      zone: ScheduleAnyway
      maxSkew: 1
      minDomains: 2  # Require at least 2 eligible nodes
```

3. **Upgrade your chart:**

```bash
helm upgrade my-chart . -n my-namespace --values values.yaml
```

4. **Verify the rendered constraints** include `minDomains`:

```bash
kubectl get deployment my-app -n my-namespace -o yaml | grep -A 10 topologySpreadConstraints
```

> **Note:** On Kubernetes < 1.30, the `minDomains` field is silently ignored (no error). Verify your cluster version before relying on this feature.

#### Option 3: Adopt nodeTaintsPolicy (Kubernetes >= 1.26)

If you want tainted nodes (e.g. nodes being drained by Karpenter) to be excluded from skew calculations:

1. **Verify your Kubernetes version** is >= 1.26:

```bash
kubectl version --short
```

2. **Add `nodeTaintsPolicy` to your umbrella or product chart `values.yaml`:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: DoNotSchedule
      zone: ScheduleAnyway
      maxSkew: 1
      nodeTaintsPolicy: Honor  # Exclude tainted nodes from skew
```

3. **Upgrade your chart:**

```bash
helm upgrade my-chart . -n my-namespace --values values.yaml
```

4. **Verify the rendered constraints** include `nodeTaintsPolicy`:

```bash
kubectl get deployment my-app -n my-namespace -o yaml | grep -A 10 topologySpreadConstraints
```

> **Note:** On Kubernetes < 1.26, the `nodeTaintsPolicy` field is silently ignored (no error). Verify your cluster version before relying on this feature.

### For Chart Maintainers (Product Charts)

If you maintain a product chart that consumes `lerian-common`:

1. **Update the `lerian-common` dependency** in your product chart's `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 2.3.0
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Document the new fields** in your product chart's `values.yaml` (if you expose the `spread` preset):

```yaml
myapp:
  spread:
    enabled: false
    hostname: ""
    zone: ""
    maxSkew: 1
    minDomains: 0            # NEW: int >= 0; 0 = off. Kubernetes >= 1.30
    nodeTaintsPolicy: ""     # NEW: Honor | Ignore | "" (omitted). Kubernetes >= 1.26
```

4. **Test render equivalence** for existing configurations (ensure output is identical when new fields are not set):

```bash
helm template my-chart . --values test-values.yaml > before.yaml
# (after updating lerian-common to 2.3.0)
helm template my-chart . --values test-values.yaml > after.yaml
diff before.yaml after.yaml
```

> **Important:** The diff should be empty for existing configurations. The new fields only affect output when explicitly set.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.3.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.3.0 -n lerian-common
```
