# Helm Upgrade from v4.4.0 to v4.4.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that increments the chart version from `4.4.0` to `4.4.1`. No changes have been made to the application version, configuration values, templates, or any other chart components. This release contains only the chart version bump itself.

| Field | v4.4.0 | v4.4.1 |
|-------|--------|--------|
| Chart version | `4.4.0` | `4.4.1` |
| App version | `4.5.0` | `4.5.0` |

**What this means for operators:**

- No configuration changes are required
- No pod restarts will be triggered
- No application behavior changes
- The upgrade is a metadata-only update

This type of release typically indicates internal chart repository or CI/CD pipeline changes that do not affect deployed resources.

> **Note:** Running `helm upgrade` with this version will update the chart metadata in your release history but will not modify any Kubernetes resources.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.4.1 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.4.1 -n reporter
```
