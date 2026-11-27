# Helm Upgrade from v3.4.0 to v3.4.1

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application Version Update](#1-application-version-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.4.1 is a patch release that updates the application version from 3.8.0 to 3.9.0. No configuration changes are required, and no migration steps are necessary. The upgrade performs a rolling update of the bank-transfer deployment to the new application version.

## Changes

### 1. Application Version Update

**What changed:**  
The default container image tag has been updated to align with the new application version.

| Setting | v3.4.0 | v3.4.1 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `3.8.0` | `3.9.0` |
| `bankTransfer.image.tag` | `3.8.0` | `3.9.0` |

**Why it matters:**  
The application container will be updated to version 3.9.0. This is a standard application update that includes bug fixes and improvements.

**Operational impact:**  
- The bank-transfer deployment will perform a rolling update to the new image version
- If you have explicitly set `bankTransfer.image.tag` in your values, that override will continue to be respected

**Migration required:**  
No migration is required. If you have overridden `bankTransfer.image.tag` in your values and want to use the new default, remove the override:

```yaml
# Remove this override to use the chart's new default (3.9.0)
bankTransfer:
  image:
    tag: "3.8.0"  # Delete this line to use 3.9.0
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.4.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.4.1
```
