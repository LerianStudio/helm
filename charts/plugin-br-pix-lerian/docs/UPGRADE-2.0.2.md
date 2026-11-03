# Helm Upgrade from v2.0.1 to v2.0.2

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch-level chart release. The chart version changes from `2.0.1` to `2.0.2`. The application version (`appVersion: "1.1.0"`), the values and the templates do not change.

| Setting | v2.0.1 | v2.0.2 |
|---------|--------|--------|
| `Chart.yaml version` | `2.0.1` | `2.0.2` |
| `Chart.yaml appVersion` | `"1.1.0"` | `"1.1.0"` |

**Why it matters:**

This release contains no configuration changes. The only other change is the chart license: the chart README now declares Elastic License 2.0 instead of Apache-2.0.

**How to handle it:**

No action is required beyond running the upgrade command. Your existing `values.yaml` will continue to work without modification. The `helm.sh/chart` label on every resource changes to the new chart version, so every enabled Deployment restarts its pods.

```bash
helm upgrade plugin-br-pix-lerian oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.2 -n plugin-br-pix-lerian
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-lerian oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.2 -n plugin-br-pix-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-lerian oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.2 -n plugin-br-pix-lerian
```
