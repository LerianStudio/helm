# Helm Upgrade from v10.0.0 to v10.0.1

# Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a patch release that increments the chart version from 10.0.0 to 10.0.1. No changes were made to:

- Application versions (appVersion remains `3.11.1`)
- Template files
- Configuration values
- Dependencies

**What this means for operators:**

This release contains only chart metadata updates. The upgrade is completely transparent and requires no configuration changes or migration steps. All existing deployments will continue to function identically after the upgrade.

| Component | v10.0.0 | v10.0.1 |
|-----------|---------|---------|
| Chart version | 10.0.0 | 10.0.1 |
| App version | 3.11.1 | 3.11.1 |
| Identity image | *(unchanged)* | *(unchanged)* |
| Auth image | *(unchanged)* | *(unchanged)* |
| Auth Backend image | *(unchanged)* | *(unchanged)* |

**Action required:**

None. This upgrade can be applied without any preparation or configuration changes.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.1 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.1 -n plugin-access-manager
```
