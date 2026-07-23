# Helm Upgrade from v1.0.0 to v1.0.1

## Topics ToC

- **[Chart Name Change](#chart-name-change)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Chart Name Change

The chart name has been updated in the Chart.yaml metadata. This is an internal metadata change that affects the chart's published name in the OCI registry.

| Setting | v1.0.0 | v1.0.1 |
|---------|---------|---------|
| Chart name | `lerian-common` | `lerian-common-helm` |

### What changed

The `name` field in Chart.yaml has been changed from `lerian-common` to `lerian-common-helm`. This aligns the chart name with the OCI registry path where it is published.

### Why it matters

This change affects how the chart is referenced when pulling from the OCI registry. The chart is now published under the name `lerian-common-helm` instead of `lerian-common`.

### Operational impact

> **Important:** This is a library chart (type: library) that is consumed as a dependency by other charts. It does not deploy resources directly.

If you are consuming this chart as a dependency in other Helm charts, no changes are required to your existing deployments. The chart continues to provide the same helper templates with identical rendered output.

For operators who reference this chart in `Chart.yaml` dependencies of other charts, the dependency reference should be updated to use the new chart name:

**Before (v1.0.0):**

```yaml
dependencies:
  - name: lerian-common
    version: 1.0.0
    repository: oci://registry-1.docker.io/lerianstudio
```

**After (v1.0.1):**

```yaml
dependencies:
  - name: lerian-common-helm
    version: 1.0.1
    repository: oci://registry-1.docker.io/lerianstudio
```

> **Note:** The alias field can be used to maintain backward compatibility with existing template references if needed.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.0.1 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.0.1 -n lerian-common
```
