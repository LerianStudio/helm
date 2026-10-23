# Helm Upgrade from v9.8.1 to v9.8.2

# Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

Version 9.8.2 is a patch release that contains no functional changes, configuration updates, or template modifications. This release only increments the chart version number in `Chart.yaml`.

| Setting | v9.8.1 | v9.8.2 |
|---------|--------|--------|
| Chart version | 9.8.1 | 9.8.2 |
| App version | 3.11.1 | 3.11.1 |

**What changed:**

- The chart version field in `Chart.yaml` was incremented from `9.8.1` to `9.8.2`
- No changes to `values.yaml`, template files, or application configuration
- No changes to the deployed application version (remains `3.11.1`)

**Why this matters:**

This is a metadata-only release. No configuration changes, pod restarts, or operational adjustments are required. The upgrade is safe to apply without reviewing your values file or testing in a staging environment.

**Migration steps:**

No action is required. Simply run the upgrade command to update the chart metadata in your release.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.8.2 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.8.2 -n plugin-access-manager
```
