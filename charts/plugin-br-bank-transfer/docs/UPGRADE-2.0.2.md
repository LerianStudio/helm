# Helm Upgrade from v2.0.1 to v2.0.2

This is a patch release that updates the application container image from version 2.1.1 to 2.1.2. No configuration changes, template modifications, or breaking changes are included.

## Overview

Version 2.0.2 bumps the `appVersion` from `2.1.1` to `2.1.2` and updates the default container image tag accordingly. This release contains application-level fixes or improvements packaged in the new container image. No Helm chart configuration, templates, or subchart dependencies have changed.

## Application Version Update

**What changed:**  
The default container image tag for the bank-transfer deployment has been updated to `2.1.2`.

| Setting | v2.0.1 | v2.0.2 |
|---------|--------|--------|
| `Chart.yaml` `appVersion` | `2.1.1` | `2.1.2` |
| `values.yaml` `bankTransfer.image.tag` | `2.1.1` | `2.1.2` |

**Why it matters:**  
The new image version (`2.1.2`) includes application-level bug fixes, security patches, or minor improvements. The chart automatically uses this version unless you have explicitly overridden `bankTransfer.image.tag` in your values.

**Operational impact:**  
- If you use the default `bankTransfer.image.tag` (or leave it unset), the upgrade will deploy the new `2.1.2` image
- If you have pinned a specific image tag via values override, your override will continue to take precedence
- The deployment will perform a rolling update to replace pods with the new image version

**Migration required:**  
No — the image update is automatic and backward-compatible. Review the application's release notes for `2.1.2` to understand what fixes or features are included.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.0.2 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.0.2 -n plugin-br-bank-transfer
```
