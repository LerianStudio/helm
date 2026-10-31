# Helm Upgrade from v10.1.3 to v10.1.4

# Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

Version 10.1.4 is a patch release that contains no functional changes, template modifications, or configuration updates. This release only increments the chart version number in `Chart.yaml` from `10.1.3` to `10.1.4`.

**What changed:**

| File | Change |
|------|--------|
| `Chart.yaml` | `version: 10.1.3` → `version: 10.1.4` |

**Why this matters:**

This is a version bump release with no operational impact. The application version (`appVersion: "3.14.0"`), all templates, default values, and configuration remain identical to v10.1.3.

**What operators need to do:**

No configuration changes, migration steps, or operational actions are required. The upgrade is a direct replacement with zero functional diff.

> **Note:** Running `helm diff` against this release will show no changes to the rendered Kubernetes manifests. The only difference is the chart metadata version.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.4 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.4 -n plugin-access-manager
```
