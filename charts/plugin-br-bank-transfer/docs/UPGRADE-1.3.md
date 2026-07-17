# Helm Upgrade from v1.2.1 to v1.3.0

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.3.0 is a minor release that updates the application version from 1.1.0 to 1.1.9. This release contains no breaking changes, no configuration changes, and no template modifications. The upgrade only updates the container image tag to deploy the latest application version.

## Application Version Update

**What changed:**  
The default container image tag has been updated to reflect the new application version.

| Setting | v1.2.1 | v1.3.0 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `1.1.0` | `1.1.9` |
| `bankTransfer.image.tag` | `1.1.0` | `1.1.9` |

**Why it matters:**  
The application version bump from 1.1.0 to 1.1.9 includes application-level bug fixes, enhancements, and patches. Refer to the plugin-br-bank-transfer application release notes for details on what changed in the application itself.

**Operational impact:**  
- The bank-transfer deployment will pull and run the `1.1.9` image tag
- No configuration changes are required
- No migration steps are needed

**Migration required:**  
No — the upgrade is transparent. If you have explicitly pinned `bankTransfer.image.tag` in your values, you may continue to use your pinned version or update it to `1.1.9` to adopt the new default.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.3.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.3.0 -n plugin-br-bank-transfer
```
