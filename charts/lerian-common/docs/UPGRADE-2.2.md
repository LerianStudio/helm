# Helm Upgrade from v2.1.2 to v2.2.0

## Topics ToC

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Pod Topology Spread Constraints](#1-pod-topology-spread-constraints)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v2.2.0 introduces **opt-in pod topology spread constraints** for Deployments. This feature enables operators to configure pod spreading across availability zones and nodes to improve high availability and fault tolerance.

**What's new:**

- A new `global.scheduling.spread` configuration block that defines topology spread constraints as a preset
- Enhanced `lerian-common.scheduling` helper that can now render `topologySpreadConstraints` alongside the existing `nodeSelector`, `affinity`, and `tolerations` blocks
- A standalone `lerian-common.topologySpreadConstraints` helper for charts that hand-write their scheduling blocks
- Support for both global (umbrella-level) and component-level spread configuration with field-by-field precedence

**Backward compatibility:**

This is a **non-breaking change**. The spread preset is **opt-in** (disabled by default). Existing deployments that do not set `global.scheduling.spread.enabled: true` will see no changes in rendered output. Product charts must be updated to pass the new input shape to `lerian-common.scheduling` to enable spread constraints.

## Features

### 1. Pod Topology Spread Constraints

The library now supports rendering `topologySpreadConstraints` for Deployments via a configurable preset. This allows operators to spread pods across availability zones and nodes to avoid single points of failure.

**What changed:**

The `lerian-common.scheduling` helper has been enhanced to accept a new input shape that includes `selectorLabels`. When this shape is used, the helper resolves and renders topology spread constraints based on the `spread` preset configuration.

A new standalone helper `lerian-common.topologySpreadConstraints` is also available for charts that hand-write their `nodeSelector`, `affinity`, and `tolerations` blocks.

**Why it matters:**

Without topology spread constraints, Kubernetes may schedule all replicas of a Deployment on the same node or in the same availability zone. If that node or zone fails, the entire service becomes unavailable. Topology spread constraints distribute pods across failure domains to improve resilience.

**How it works:**

Operators configure the spread preset at the umbrella level (`global.scheduling.spread`) or per-component (`<component>.spread`). The preset defines:

- **`enabled`**: Master switch (default: `false`)
- **`hostname`**: Spread across nodes (`kubernetes.io/hostname`) — values: `ScheduleAnyway`, `DoNotSchedule`, or `""` (off)
- **`zone`**: Spread across availability zones (`topology.kubernetes.io/zone`) — same values
- **`maxSkew`**: Maximum difference in pod count between any two topology domains (default: `1`)

Component-level `spread` fields override global fields **field by field**. A component's raw `topologySpreadConstraints` list (if non-empty) replaces the preset entirely.

**Configuration block (umbrella `values.yaml`):**

```yaml
global:
  scheduling:
    spread:
      enabled: true            # Master switch for the preset
      hostname: ScheduleAnyway # Spread across nodes (ScheduleAnyway | DoNotSchedule | "")
      zone: ScheduleAnyway     # Spread across zones (ScheduleAnyway | DoNotSchedule | "")
      maxSkew: 1               # Maximum pod count difference between domains
```

**Per-component override:**

```yaml
myapp:
  spread:
    hostname: DoNotSchedule  # Override global hostname behavior
    zone: ""                 # Disable zone spreading for this component
```

**Raw constraints (replaces preset entirely):**

```yaml
myapp:
  topologySpreadConstraints:
    - maxSkew: 2
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app: myapp
```

**Precedence:**

1. Component `topologySpreadConstraints` (raw list) — wins entirely, preset ignored
2. Spread preset resolved field by field: `component.spread.<field>` > `global.scheduling.spread.<field>` > built-in default
3. Nothing (when `enabled: false` or absent)

**Built-in defaults:**

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `false` | Master switch for the spread preset |
| `hostname` | `""` | Spread across nodes (off by default) |
| `zone` | `""` | Spread across zones (off by default) |
| `maxSkew` | `1` | Maximum pod count difference |

**whenUnsatisfiable values:**

- **`ScheduleAnyway`** (soft constraint): Kubernetes prefers to spread pods but will schedule them even if spreading is not possible (e.g., only one zone available)
- **`DoNotSchedule`** (hard constraint): Kubernetes will not schedule a pod if it violates the spread constraint (may cause pods to remain Pending)
- **`""`** (empty string): Disables spreading for that topology key

**matchLabelKeys behavior:**

Every preset constraint includes `matchLabelKeys: [pod-template-hash]` so only pods from the **same ReplicaSet** are counted. During a rolling update, the old ReplicaSet's pods do not block the new ones, avoiding a `DoNotSchedule` deadlock.

> **Important:** `matchLabelKeys` requires Kubernetes >= 1.27 with the `MatchLabelKeysInPodTopologySpread` feature gate enabled (beta since 1.27, enabled by default). If you are running Kubernetes < 1.27 or have disabled this feature gate, do not enable the spread preset.

**Usage in product charts (spread-aware shape):**

Product chart maintainers must update their Deployment templates to pass the new input shape to `lerian-common.scheduling`:

**Before (v2.1.2):**

```yaml
# templates/deployment.yaml
spec:
  template:
    spec:
      {{- if or .Values.myapp.nodeSelector .Values.myapp.affinity .Values.myapp.tolerations }}
      {{- include "lerian-common.scheduling" .Values.myapp | nindent 6 }}
      {{- end }}
```

**After (v2.2.0):**

```yaml
# templates/deployment.yaml
spec:
  template:
    spec:
      {{- with (include "lerian-common.scheduling" (dict
            "component"      .Values.myapp
            "global"         .Values.global
            "selectorLabels" (include "myapp.selectorLabels" .)) | trim) }}
      {{- . | nindent 6 }}
      {{- end }}
```

> **Note:** The `selectorLabels` input must be exactly the Deployment's `spec.selector.matchLabels` (either a dict or the rendered YAML string from the chart's `selectorLabels` helper). The library never guesses labels.

**Standalone helper usage:**

For charts that hand-write their `nodeSelector`, `affinity`, and `tolerations` blocks, use the standalone `lerian-common.topologySpreadConstraints` helper:

```yaml
# templates/deployment.yaml
spec:
  template:
    spec:
      nodeSelector:
        disktype: ssd
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: myapp
              topologyKey: kubernetes.io/hostname
      {{- with (include "lerian-common.topologySpreadConstraints" (dict
            "component"      .Values.myapp
            "global"         .Values.global
            "selectorLabels" (include "myapp.selectorLabels" .)) | trim) }}
      {{- . | nindent 6 }}
      {{- end }}
```

**Operational impact:**

- **No impact for existing deployments** unless `global.scheduling.spread.enabled: true` is set
- When enabled, Kubernetes will attempt to spread pods according to the configured constraints
- With `ScheduleAnyway` (soft constraint), scheduling behavior is best-effort and should not cause pods to remain Pending
- With `DoNotSchedule` (hard constraint), pods may remain Pending if the cluster cannot satisfy the spread constraint (e.g., insufficient nodes or zones)
- The `matchLabelKeys` feature requires Kubernetes >= 1.27; on older clusters, the preset will fail to render

**Example rendered output (global preset with both hostname and zone):**

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: myapp
        release: prod
    matchLabelKeys:
      - pod-template-hash
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: myapp
        release: prod
    matchLabelKeys:
      - pod-template-hash
```

**Error handling:**

The helper validates all input and fails the render with an explicit error message if:

- `spread.enabled` is not a boolean
- `spread.hostname` or `spread.zone` is not one of `ScheduleAnyway`, `DoNotSchedule`, or `""`
- `spread.maxSkew` is not an integer >= 1
- `topologySpreadConstraints` is not a list
- `selectorLabels` is empty when a constraint would be rendered
- An unknown field is set in `spread`

## Configuration Reference

The following new configuration block is available in v2.2.0:

**Umbrella `values.yaml` (global preset):**

```yaml
global:
  scheduling:
    spread:
      enabled: true            # bool — master switch (default: false)
      hostname: ScheduleAnyway # ScheduleAnyway | DoNotSchedule | "" (off)
      zone: ScheduleAnyway     # ScheduleAnyway | DoNotSchedule | "" (off)
      maxSkew: 1               # int >= 1
```

**Component-level override:**

```yaml
<component>:
  spread:
    enabled: true              # Override global enabled
    hostname: DoNotSchedule    # Override global hostname
    zone: ""                   # Disable zone spreading for this component
    maxSkew: 2                 # Override global maxSkew
  topologySpreadConstraints: [] # Raw k8s list; non-empty = wins entirely
```

**Configuration flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `global.scheduling.spread.enabled` | `false` | Master switch for the topology spread preset |
| `global.scheduling.spread.hostname` | `""` | Spread across nodes (`kubernetes.io/hostname`). Values: `ScheduleAnyway`, `DoNotSchedule`, or `""` (off) |
| `global.scheduling.spread.zone` | `""` | Spread across availability zones (`topology.kubernetes.io/zone`). Values: `ScheduleAnyway`, `DoNotSchedule`, or `""` (off) |
| `global.scheduling.spread.maxSkew` | `1` | Maximum difference in pod count between any two topology domains (integer >= 1) |
| `<component>.spread` | `{}` | Component-level spread configuration; each field overrides the global one |
| `<component>.topologySpreadConstraints` | `[]` | Raw Kubernetes `topologySpreadConstraints` list; non-empty = replaces preset entirely |

## Migration Steps

### For Operators (Umbrella Deployments)

If you want to enable topology spread constraints for your Lerian deployments:

1. **Verify Kubernetes version.** Ensure your cluster is running Kubernetes >= 1.27 with the `MatchLabelKeysInPodTopologySpread` feature gate enabled (it is enabled by default since 1.27).

2. **Update the `lerian-common` dependency** in your umbrella `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 2.2.0
    repository: oci://registry-1.docker.io/lerianstudio
```

3. **Update dependencies:**

```bash
helm dependency update
```

4. **Add the `global.scheduling.spread` block** to your umbrella `values.yaml`:

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ScheduleAnyway
      maxSkew: 1
```

5. **Ensure product charts are updated.** The spread preset only takes effect if product charts have been updated to pass the new input shape to `lerian-common.scheduling`. Coordinate with chart maintainers or verify that the product chart versions you are using support the spread preset.

6. **Preview the changes** using `helm diff` (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

7. **Upgrade the umbrella chart:**

```bash
helm upgrade my-umbrella . -n lerian --values values.yaml
```

8. **Verify pod distribution.** After the upgrade, check that pods are distributed according to the configured constraints:

```bash
kubectl get pods -n lerian -o wide
```

> **Note:** With `ScheduleAnyway` (soft constraint), Kubernetes will make a best effort to spread pods but will still schedule them if spreading is not possible. With `DoNotSchedule` (hard constraint), pods may remain Pending if the cluster cannot satisfy the constraint.

### For Chart Maintainers (Product Charts)

If you maintain a Lerian product chart and want to enable the spread preset for Deployments:

1. **Update the `lerian-common` dependency** in your product chart's `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 2.2.0
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Update Deployment templates** to pass the new input shape to `lerian-common.scheduling`:

**Before (v2.1.2):**

```yaml
# templates/deployment.yaml
spec:
  template:
    spec:
      {{- if or .Values.myapp.nodeSelector .Values.myapp.affinity .Values.myapp.tolerations }}
      {{- include "lerian-common.scheduling" .Values.myapp | nindent 6 }}
      {{- end }}
```

**After (v2.2.0):**

```yaml
# templates/deployment.yaml
spec:
  template:
    spec:
      {{- with (include "lerian-common.scheduling" (dict
            "component"      .Values.myapp
            "global"         .Values.global
            "selectorLabels" (include "myapp.selectorLabels" .)) | trim) }}
      {{- . | nindent 6 }}
      {{- end }}
```

4. **Test render equivalence** with `global.scheduling.spread` absent (ensure output is byte-identical for existing users):

```bash
helm template my-chart . --values test-values.yaml > before.yaml
# (after refactor)
helm template my-chart . --values test-values.yaml > after.yaml
diff before.yaml after.yaml
```

5. **Test with spread enabled:**

```bash
helm template my-chart . --values test-values.yaml --set global.scheduling.spread.enabled=true --set global.scheduling.spread.hostname=ScheduleAnyway --set global.scheduling.spread.zone=ScheduleAnyway
```

6. **Document the change** in your product chart's CHANGELOG and upgrade guide.

> **Important:** Do not update Job or CronJob templates to use the spread-aware shape. Spreading run-to-completion pods is meaningless. Keep the legacy input shape (component values map only) for Jobs and CronJobs.

### For Standalone Deployments

If you deploy a single product chart without an umbrella:

**No action required** unless you want to enable topology spread constraints. The spread preset is opt-in and disabled by default. Existing deployments will see no changes in rendered output.

To enable the spread preset for a standalone deployment:

1. **Verify the product chart version** supports the spread preset (check the chart's CHANGELOG or upgrade guide).

2. **Set the `global.scheduling.spread` block** in your `values.yaml`:

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ScheduleAnyway
      maxSkew: 1
```

3. **Upgrade the chart:**

```bash
helm upgrade my-chart oci://registry-1.docker.io/lerianstudio/my-chart --version <version> -n lerian --values values.yaml
```

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.2.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of the spread preset, run `helm diff` on the **product charts** that consume it, with `global.scheduling.spread.enabled: true` set in your values.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.2.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` and run `helm dependency update`.
