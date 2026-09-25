# Helm Upgrade from v2.0.0 to v2.0.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Values Formatting Changes](#values-formatting-changes)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.0.1 is a patch release that updates the application image from v2.0.0 to v2.1.1 and applies minor formatting cleanup to `values.yaml`. There are no breaking changes, no new configuration fields, and no template modifications. The upgrade is straightforward and requires no operator action beyond running the upgrade command.

## Application Version Update

**What changed:**  
The chart now deploys application version 2.1.1 (previously 2.0.0).

| Setting | v2.0.0 | v2.0.1 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `2.0.0` | `2.1.1` |
| `bankTransfer.image.tag` | `2.0.0` | `2.1.1` |

**Why it matters:**  
The application image has been updated to v2.1.1, which may include bug fixes, security patches, or minor feature enhancements. Refer to the application's release notes for details on what changed in the application itself.

**Operational impact:**  
- The deployment will pull the new image tag (`2.1.1`) on upgrade
- Existing pods will be replaced with new pods running the updated image
- No configuration changes are required

**Migration required:**  
No — the image tag update is automatic.

## Values Formatting Changes

**What changed:**  
The `values.yaml` file has been reformatted to remove extraneous blank lines and trailing whitespace. The following changes are purely cosmetic:

- Removed blank lines after `CORS_ALLOWED_HEADERS` (line 353)
- Removed blank lines after `ORGANIZATION_IDS` (line 488)
- Removed blank lines after `# STREAMING_CLOSE_TIMEOUT_S: ""` (line 514)
- Moved streaming and multi-tenant Redis credential comments outside the `secrets:` block (lines 559-565) to improve readability
- Removed trailing blank line at end of file (line 749)

**Why it matters:**  
These changes improve the readability and maintainability of the values file but have no functional impact. The rendered templates are identical.

**Operational impact:**  
None — formatting changes do not affect the deployed resources.

**Migration required:**  
No — existing values overrides continue to work without modification.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.0.1 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.0.1 -n plugin-br-bank-transfer
```
