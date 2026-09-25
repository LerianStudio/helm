# Helm Upgrade from v1.3.0 to v1.4.0

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.4.0 is a minor release that updates the application version from 1.1.9 to 1.2.0. This release contains no configuration changes, no template modifications, and no breaking changes. The upgrade only increments the chart version and the underlying application image tag.

## Application Version Update

**What changed:**  
The default container image tag for the bank-transfer application has been updated to version 1.2.0.

| Setting | v1.3.0 | v1.4.0 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `1.1.9` | `1.2.0` |
| `bankTransfer.image.tag` | `1.1.9` | `1.2.0` |

**Why it matters:**  
This update pulls in the latest application features, bug fixes, and improvements from the bank-transfer application version 1.2.0. The image tag change ensures that new deployments and upgrades use the updated application version.

**Operational impact:**  
- The deployment will pull the new image tag (`1.2.0`) during the upgrade
- Existing pods will be replaced with new pods running the updated application version
- No configuration changes are required — the image tag is the only modified value

**Migration required:**  
No — the upgrade is automatic. If you have explicitly overridden `bankTransfer.image.tag` in your values, you may want to update it to `1.2.0` or remove the override to use the chart default.

**Example values override (optional):**

If you need to pin to a specific version or revert to the previous version, you can override the image tag:

```yaml
bankTransfer:
  image:
    tag: "1.2.0"  # Explicitly set to new version (or "1.1.9" to stay on previous)
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.4.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.4.0 -n plugin-br-bank-transfer
```
