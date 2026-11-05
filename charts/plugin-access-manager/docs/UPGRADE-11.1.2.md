# Helm Upgrade from v11.1.1 to v11.1.2

# Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a patch release that increments the chart version from 11.1.1 to 11.1.2. No changes were made to:

- Application versions (appVersion remains `3.17.0`)
- Template files
- Configuration values
- Dependencies

**What this means for operators:**

This release contains only chart metadata updates. The upgrade is completely transparent and requires no configuration changes or migration steps. All existing deployments will continue to function identically after the upgrade.

| Component | v11.1.1 | v11.1.2 |
|-----------|---------|---------|
| Chart version | 11.1.1 | 11.1.2 |
| App version | 3.17.0 | 3.17.0 |
| Identity image | *(unchanged)* | *(unchanged)* |
| Auth image | *(unchanged)* | *(unchanged)* |
| Auth Backend image | *(unchanged)* | *(unchanged)* |

**Action required:**

None. This upgrade can be applied without any preparation or configuration changes.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.2
```
