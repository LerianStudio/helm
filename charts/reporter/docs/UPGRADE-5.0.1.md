# Helm Upgrade from v5.0.0 to v5.0.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release with no functional changes. The chart version has been incremented from `5.0.0` to `5.0.1` with no modifications to templates, values, or application version.

| Field | v5.0.0 | v5.0.1 |
|-------|--------|--------|
| Chart version | `5.0.0` | `5.0.1` |
| App version | `4.5.1` | `4.5.1` |

No configuration changes, template updates, or migration steps are required. You can upgrade without modifying your values files.

The chart version is part of the `helm.sh/chart` label in the pod templates, so the upgrade still triggers a rolling restart of the reporter pods.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.0.1 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.0.1 -n reporter
```
