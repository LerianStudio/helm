# Helm Upgrade from v3.0.1 to v3.0.2

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.0.2 is a patch release that updates the application version from 3.2.0 to 3.3.0. This release contains no configuration changes, no template modifications, and no breaking changes. The upgrade only updates the container image tag to match the new application version.

## Application Version Update

**What changed:**  
The chart now deploys application version 3.3.0 (previously 3.2.0). The default container image tag has been updated accordingly.

| Setting | v3.0.1 | v3.0.2 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `3.2.0` | `3.3.0` |
| `bankTransfer.image.tag` | `3.2.0` | `3.3.0` |

**Why it matters:**  
The new application version may include bug fixes, performance improvements, or minor feature enhancements. Refer to the application's release notes for details on what changed in version 3.3.0.

**Operational impact:**  
- The deployment will perform a rolling update to the new container image
- No configuration changes are required
- No database migrations or schema changes are expected (patch version bump)

**Migration required:**  
No — the upgrade is automatic when you run `helm upgrade`.

> **Note:** If you have explicitly overridden `bankTransfer.image.tag` in your values, you may want to update it to `3.3.0` or remove the override to use the chart default.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.2 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.2 -n plugin-br-bank-transfer
```
