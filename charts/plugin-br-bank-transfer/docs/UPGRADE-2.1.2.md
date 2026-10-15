# Helm Upgrade from v2.1.1 to v2.1.2

This is a patch release that updates the application image from version 3.0.0 to 3.0.1. The upgrade includes no configuration changes, template modifications, or breaking changes.

## Topics

- **[Overview](#overview)**
- **[Application Image Update](#application-image-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.1.2 is a straightforward patch release that bumps the bank-transfer application image from `3.0.0` to `3.0.1`. No Helm chart configuration changes, template modifications, or operator actions are required. The upgrade is backward-compatible and can be applied without modifying existing values files.

## Application Image Update

**What changed:**  
The default application image tag has been updated from `3.0.0` to `3.0.1`.

| Setting | v2.1.1 | v2.1.2 |
|---------|--------|--------|
| `bankTransfer.image.tag` | `"3.0.0"` | `"3.0.1"` |
| Chart `appVersion` | `"3.0.0"` | `"3.0.1"` |

**Why it matters:**  
This patch version of the application image likely includes bug fixes, security patches, or minor improvements. The image update is transparent to operators — no configuration changes are required.

**Migration required:**  
No — the image tag is updated automatically when you upgrade the chart. If you explicitly override `bankTransfer.image.tag` in your values file, you may want to update it to `"3.0.1"` or remove the override to use the chart default.

**Example override (optional):**

If you want to explicitly pin the image version in your values file:

```yaml
bankTransfer:
  image:
    tag: "3.0.1"
```

> **Note:** If you do not override `bankTransfer.image.tag`, the chart will automatically use the new default (`3.0.1`) after upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.2 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.2 -n plugin-br-bank-transfer
```
