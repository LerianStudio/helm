# Helm Upgrade from v2.4.1 to v2.4.2

## Topics ToC

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v2.4.2 is a **patch release** with no functional changes, template modifications, or configuration updates. This release only increments the chart version number in `Chart.yaml`.

**What changed:**

- Chart version bumped from `2.4.1` to `2.4.2` in `Chart.yaml`
- No changes to templates, values, or helper functions

**Who should upgrade:**

- Chart maintainers who need to align with the latest patch version for dependency management
- Operators who want to stay current with the latest release (optional)

**Backward compatibility:**

This release is **fully backward-compatible**. All templates, helpers, and configuration remain byte-identical to v2.4.1. Upgrading from v2.4.1 to v2.4.2 will produce **no changes** to rendered Kubernetes resources.

**Operational impact:**

> **Note:** Since this release contains no functional changes, upgrading is **optional**. Existing deployments on v2.4.1 will continue to function identically. No configuration changes, migration steps, or operational actions are required.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.4.2 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v2.4.2, run `helm diff` on the **product charts** that consume it after updating the dependency version. Since this release contains no functional changes, the diff will show no changes to rendered resources.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.4.2 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `2.4.2` and run `helm dependency update`, then upgrade the parent chart.
