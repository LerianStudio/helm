# Helm Upgrade from v2.0.1 to v2.0.2

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch-level version bump** with no functional changes. The chart version has been incremented from `2.0.1` to `2.0.2`, but the application version (`appVersion: "1.1.0"`), values schema, and template logic remain unchanged.

| Setting | v2.0.1 | v2.0.2 |
|---------|--------|--------|
| `Chart.yaml version` | `2.0.1` | `2.0.2` |
| `Chart.yaml appVersion` | `"1.1.0"` | `"1.1.0"` |

**Why it matters:**

This release contains no configuration changes, no new features, and no fixes that affect deployed resources. The version bump is administrative only (e.g., to align with release tooling or repository conventions).

**How to handle it:**

No action is required beyond running the upgrade command. Your existing `values.yaml` will continue to work without modification. The upgrade will not modify any Deployments, Services, ConfigMaps, Secrets, or other Kubernetes resources.

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.2 -n plugin-br-pix-lerian
```

> **Note:** If you run `helm diff` before upgrading, you should see no resource changes. The only difference will be in the chart metadata (labels, annotations) that reference the chart version.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.2 -n plugin-br-pix-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.2 -n plugin-br-pix-lerian
```
