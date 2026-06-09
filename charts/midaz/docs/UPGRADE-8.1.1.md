# Helm Upgrade from v8.1.0 to v8.1.1

## Topics

- **[Fixes](#fixes)**
  - [1. Application version bump to 3.7.6](#1-application-version-bump-to-376)
  - [2. Ledger service image tag update](#2-ledger-service-image-tag-update)
  - [3. CRM service image tag update](#3-crm-service-image-tag-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Application version bump to 3.7.6

The chart's `appVersion` has been updated from `3.7.3` to `3.7.6`. This is a patch release that includes bug fixes and minor improvements to the Midaz application components.

| Setting | v8.1.0 | v8.1.1 |
|---------|--------|--------|
| `appVersion` | 3.7.3 | 3.7.6 |

> **Note:** Review the [Midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md) for detailed information about application-level changes between versions 3.7.3 and 3.7.6.

### 2. Ledger service image tag update

The ledger service container image has been updated to align with the new application version.

| Setting | v8.1.0 | v8.1.1 |
|---------|--------|--------|
| `ledger.image.tag` | 3.7.2 | 3.7.6 |

**Before (v8.1.0):**
```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "3.7.2"
```

**After (v8.1.1):**
```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "3.7.6"
```

This update ensures the ledger service runs the latest patch version with bug fixes and improvements. No configuration changes are required from operators.

### 3. CRM service image tag update

The CRM service container image has been updated to align with the new application version.

| Setting | v8.1.0 | v8.1.1 |
|---------|--------|--------|
| `crm.image.tag` | 3.7.3 | 3.7.6 |

**Before (v8.1.0):**
```yaml
crm:
  image:
    repository: lerianstudio/midaz-crm
    pullPolicy: Always
    tag: "3.7.3"
```

**After (v8.1.1):**
```yaml
crm:
  image:
    repository: lerianstudio/midaz-crm
    pullPolicy: Always
    tag: "3.7.6"
```

This update ensures the CRM service runs the latest patch version with bug fixes and improvements. No configuration changes are required from operators.

> **Important:** This is a patch release with no breaking changes. The upgrade should be seamless with no downtime expected for properly configured deployments with multiple replicas and appropriate readiness/liveness probes.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.1.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.1.1 -n midaz
```
