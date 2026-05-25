# Helm Upgrade from v7.x to v8.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version bump to 3.7.2](#1-application-version-bump-to-372)
  - [2. CRM service image tag update](#2-crm-service-image-tag-update)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor maintenance release that updates the application version and synchronizes service image tags across the Midaz platform. No breaking changes or configuration modifications are required.

## Features

### 1. Application version bump to 3.7.2

The Midaz application has been updated from version `3.7.1` to `3.7.2`. This update includes bug fixes and minor improvements to the core platform.

| Component | v7.0.0 | v8.0.0 |
|-----------|--------|--------|
| appVersion | 3.7.1 | 3.7.2 |
| ledger.image.tag | 3.7.1 | 3.7.2 |

The ledger service image tag has been updated to match the new application version:

```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "3.7.2"
```

> **Note:** For application-level changes included in version 3.7.2, refer to the [Midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

### 2. CRM service image tag update

The CRM service image tag has been updated from `3.7.0` to `3.7.2`, bringing it in sync with the rest of the platform components.

| Component | v7.0.0 | v8.0.0 |
|-----------|--------|--------|
| crm.image.tag | 3.7.0 | 3.7.2 |

```yaml
crm:
  image:
    repository: lerianstudio/midaz-crm
    pullPolicy: Always
    tag: "3.7.2"
```

This ensures all Midaz services are running compatible versions and benefit from the latest stability improvements.

## Configuration Changes

No configuration changes are required for this upgrade. All existing `values.yaml` settings remain compatible with version 8.0.0.

The following table summarizes the image tag changes:

| Service | Setting | v7.0.0 | v8.0.0 |
|---------|---------|--------|--------|
| Ledger | `ledger.image.tag` | 3.7.1 | 3.7.2 |
| CRM | `crm.image.tag` | 3.7.0 | 3.7.2 |

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade process will automatically update the service images to the new versions.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))
2. Ensure you have a recent backup of your data (if using chart-managed databases)
3. Run the upgrade command during a maintenance window
4. Verify all pods are running and healthy after the upgrade

```bash
kubectl get pods -n midaz
```

5. Check service logs for any startup issues

```bash
kubectl logs -n midaz -l app.kubernetes.io/name=midaz-ledger --tail=50
kubectl logs -n midaz -l app.kubernetes.io/name=midaz-crm --tail=50
```

> **Note:** The upgrade will trigger a rolling restart of the ledger and CRM services. Depending on your replica count and readiness probe configuration, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.0.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.0.0 -n midaz
```
