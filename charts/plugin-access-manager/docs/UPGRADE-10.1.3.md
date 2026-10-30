# Helm Upgrade from v10.1.2 to v10.1.3

# Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a patch release that updates only the chart version metadata. No functional changes, template modifications, or configuration updates are included in this release.

**What changed:**

The chart version has been incremented from 10.1.2 to 10.1.3 in the Chart.yaml metadata file. The application version remains unchanged at 3.14.0.

| Setting | v10.1.2 | v10.1.3 |
|---------|---------|---------|
| Chart version | 10.1.2 | 10.1.3 |
| Application version | 3.14.0 | 3.14.0 |

**What this means for operators:**

- No configuration changes are required
- No template or resource definitions have been modified
- No new features, fixes, or behavioral changes are included
- The upgrade is purely administrative and should have zero impact on running workloads
- All existing values.yaml configurations will continue to work without modification

> **Note:** This release does not modify any Kubernetes resources, container images, or application behavior. The upgrade will not trigger pod restarts or service disruptions unless other configuration changes are applied simultaneously.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.3 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.3 -n plugin-access-manager
```
