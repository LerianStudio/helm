# Helm Upgrade from v1.4.0 to v1.5.0

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.5.0 is a patch release that updates the application version from 1.2.0 to 1.2.1. This release contains no configuration changes, no template modifications, and no breaking changes. The upgrade only increments the chart version and updates the default container image tag to match the new application version.

## Application Version Update

**What changed:**  
The default container image tag has been updated to align with the new application version.

| Setting | v1.4.0 | v1.5.0 |
|---------|--------|--------|
| Chart version | `1.4.0` | `1.5.0` |
| App version | `1.2.0` | `1.2.1` |
| `bankTransfer.image.tag` | `"1.2.0"` | `"1.2.1"` |

**Why it matters:**  
The application version 1.2.1 includes bug fixes and improvements from the upstream plugin-br-bank-transfer application. The chart automatically uses this new version unless you have explicitly overridden `bankTransfer.image.tag` in your values.

**Operational impact:**  
- If you rely on the default `bankTransfer.image.tag` value, the upgrade will deploy the new `1.2.1` image
- If you have explicitly set `bankTransfer.image.tag` in your values file, your override will continue to take precedence and no image change will occur
- The new image is a patch release and should be backward-compatible with existing deployments

**Migration required:**  
No — the change is automatic and backward-compatible. If you have pinned a specific image tag in your values, review whether you want to adopt the new `1.2.1` version.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.5.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.5.0 -n plugin-br-bank-transfer
```
