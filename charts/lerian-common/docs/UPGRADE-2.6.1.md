# Helm Upgrade from v2.6.0 to v2.6.1

## Topics ToC

- **[Overview](#overview)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v2.6.1 is a **patch release** that updates inline documentation in the `_cloud.tpl` template file. This release contains **no functional changes** to templates, helpers, or configuration.

**What changed:**

- Inline documentation in `templates/_cloud.tpl` has been clarified for the AWS cloud preset
- Chart version bumped from `2.6.0` to `2.6.1` in `Chart.yaml`
- No changes to template logic, values, or helper functions

Upgrading from v2.6.0 to v2.6.1 will produce **no changes** to rendered Kubernetes resources. No configuration changes, migration steps, or operational actions are required.

## Command to upgrade

Since `lerian-common` is a library chart, you do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `2.6.1` and run `helm dependency update`, then upgrade the parent chart.
