# Helm Upgrade from v10.0.4 to v10.0.5

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that increments only the chart version from `10.0.4` to `10.0.5`. No changes were made to:

- Application version (remains `4.4.0`)
- Default values in `values.yaml`
- Template files
- Schema definitions
- Documentation

### Operational impact

- Pods will roll once. The chart version is part of the `helm.sh/chart` label in the pod templates, so this chart version bump triggers a rolling restart of the Midaz pods.
- The ledger migrations Job runs as a `pre-upgrade` hook on every upgrade, including this one.
- No configuration changes are required.
- Rendered Kubernetes resources remain identical except for the `helm.sh/chart` label value.

### Action required

No action required. This upgrade can be applied directly without modifying your existing values files.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.5 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.5 -n midaz
```
