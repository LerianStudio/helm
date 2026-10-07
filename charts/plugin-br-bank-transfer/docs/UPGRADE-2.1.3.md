# Helm Upgrade from v2.1.2 to v2.1.3

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.1.3 is a patch release that updates the application version from 3.0.1 to 3.0.2. This release contains no configuration changes, no template modifications, and no breaking changes. The upgrade only updates the container image tag to match the new application version.

## Application Version Update

**What changed:**  
The default container image tag has been updated to align with the new application version.

| Setting | v2.1.2 | v2.1.3 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `3.0.1` | `3.0.2` |
| `bankTransfer.image.tag` | `3.0.1` | `3.0.2` |

**Why it matters:**  
The application container will be updated to version 3.0.2, which may include bug fixes, performance improvements, or new features at the application level. Refer to the application's release notes for details on what changed in the application itself.

**Operational impact:**  
- The bank-transfer deployment will perform a rolling update to the new image version
- If you have explicitly set `bankTransfer.image.tag` in your values, that override will continue to be respected
- No configuration changes are required unless you want to pin to a specific version

**Migration required:**  
No — the upgrade is automatic. If you have overridden `bankTransfer.image.tag` in your values and want to use the new default, remove the override:

```yaml
# Remove this override to use the chart's new default (3.0.2)
bankTransfer:
  image:
    tag: "3.0.1"  # Delete this line to use 3.0.2
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.3 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.3 -n plugin-br-bank-transfer
```
