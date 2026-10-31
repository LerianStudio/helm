# Helm Upgrade from v5.2.0 to v5.2.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that increments the chart version from `5.2.0` to `5.2.1`. The application version remains `1.12.0` and no configuration values, templates, or resources have changed.

**What changed:**

| Setting | v5.2.0 | v5.2.1 |
|---------|--------|--------|
| Chart version | `5.2.0` | `5.2.1` |
| App version | `1.12.0` | `1.12.0` |

**Why it matters:**

This release contains no functional changes to the deployed resources. The chart version bump is purely administrative and does not modify any Kubernetes manifests, probe configurations, environment variables, or service behavior.

**Operational impact:**

Upgrading to `5.2.1` will **not trigger any pod restarts or configuration changes**. Helm will detect that the rendered templates are identical to the currently deployed resources and will not perform any updates to running workloads.

**No action required** beyond running the upgrade command. Your existing values files and custom configurations remain fully compatible.

> **Note:** If you run `helm diff` before upgrading, you should see no differences in the rendered manifests. The only change is the chart metadata version.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.1 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.1 -n plugin-br-pix-indirect-btg
```
