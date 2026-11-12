# Helm Upgrade from v3.2.0 to v3.2.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.2.1 is a patch release that updates the application from version `3.6.0-beta.9` to the stable `3.6.0` release. This upgrade contains no configuration changes, no template modifications, and no breaking changes. The release promotes the application from beta to stable.

## Application Version Update

**What changed:**  
The chart now deploys the stable `3.6.0` application image instead of the beta `3.6.0-beta.9` version.

| Setting | v3.2.0 | v3.2.1 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `3.6.0-beta.9` | `3.6.0` |
| `bankTransfer.image.tag` | `3.6.0-beta.9` | `3.6.0` |

**Why it matters:**  
The `3.6.0` release is the stable version of the application, indicating that it has passed beta testing and is ready for production use. This upgrade ensures you are running the officially released version with any final bug fixes or improvements made during the beta period.

**Migration required:**  
No — the upgrade is automatic when you deploy chart version 3.2.1. The application container will be updated to the new image tag during the rolling update.

> **Note:** If you have explicitly overridden `bankTransfer.image.tag` in your values file to pin to `3.6.0-beta.9`, remove that override to adopt the new stable default, or update it to `3.6.0`.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.2.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.2.1
```
