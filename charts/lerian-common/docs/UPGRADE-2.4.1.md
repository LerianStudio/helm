# Helm Upgrade from v2.4.0 to v2.4.1

## Topics ToC

- **[Overview](#overview)**
- **[Documentation Updates](#documentation-updates)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v2.4.1 is a **patch release** that updates internal documentation comments in the `_cloud.tpl` template file. This release contains **no functional changes** — all helpers produce identical rendered output.

**What changed:**

- Documentation comments in the `_cloud.tpl` template have been updated to remove references to the "opensource" cloud mode

**What did NOT change:**

- No template logic changes
- No helper function changes
- No values schema changes
- No rendered output changes

**Who is affected:**

This release affects **no operators**. The changes are purely internal documentation improvements for chart maintainers.

> **Important:** This is a library chart (type: library) that is consumed as a dependency by other charts. It does not deploy resources directly and renders nothing on its own.

## Documentation Updates

The `_cloud.tpl` template file contains documentation comments that describe the cloud-aware configuration system. Two comments have been updated to remove references to the "opensource" cloud mode.

### What changed

Documentation comments describing the behavior when `global.cloud` is unset have been simplified.

**Before (v2.4.0):**

```
`global.cloud` unset (or "opensource") => no column matches => hardcoded defaults
(bundled in-cluster infra, plaintext). Nobody running open source needs to know
this knob exists.
```

**After (v2.4.1):**

```
`global.cloud` unset => no column matches => hardcoded defaults (bundled
in-cluster infra, plaintext).
```

**Before (v2.4.0):**

```
the identity or cloud is unset (opensource / static-key path). Arg: context.
```

**After (v2.4.1):**

```
the identity or cloud is unset (static-key path). Arg: context.
```

### Why it matters

These are **documentation-only changes** that improve clarity for chart maintainers reading the template source code. The removal of "opensource" references simplifies the explanation of default behavior.

### Operational impact

**None.** These changes do not affect:

- Helper function behavior
- Rendered Kubernetes resources
- Configuration values
- Operator workflows

The helpers continue to work identically:

- When `global.cloud` is unset, helpers fall back to hardcoded defaults (bundled in-cluster infrastructure, plaintext connections)
- When `global.cloud` is set to a recognized value (`aws`, `gcp`, `azure`), helpers emit cloud-specific configuration
- The `lerian-common.cloud.objectStorageIdentityAnnotation` helper continues to emit nothing when `global.cloud` or the identity string is unset

> **Note:** If you are consuming this chart as a dependency in other Helm charts, no changes are required to your existing deployments. The chart continues to provide the same helper templates with identical rendered output.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.4.1 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading `lerian-common`, run `helm diff` on the **product charts** that consume it as a dependency. You should see **no differences** in rendered output between v2.4.0 and v2.4.1.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.4.1 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the version in your umbrella or product chart's `Chart.yaml` dependency declaration and run `helm dependency update`:

```yaml
dependencies:
  - name: lerian-common
    version: 2.4.1
    repository: oci://registry-1.docker.io/lerianstudio
```

```bash
helm dependency update
helm upgrade my-chart . -n my-namespace
```
