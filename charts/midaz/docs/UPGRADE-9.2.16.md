# Helm Upgrade from v9.2.16 to v9.2.16

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release with no changes to the chart configuration, templates, or application version. The chart version remains at `9.2.16` with no modifications to `Chart.yaml`, `values.yaml`, or any template files.

**What this means for operators:**

- No configuration changes are required
- No breaking changes
- No new features or additions
- No migration steps needed
- The upgrade is a no-op from a functional perspective

This release may have been created for administrative purposes (e.g., registry republishing, metadata updates, or CI/CD pipeline testing) but contains no operational changes.

> **Note:** While this upgrade requires no action, we still recommend following the preview and upgrade steps below to ensure your deployment remains in sync with the chart registry.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.16 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.16 -n midaz
```
