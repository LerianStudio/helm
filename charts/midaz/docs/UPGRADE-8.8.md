# Helm Upgrade from v8.7.0 to v8.8.0

## Topics

- **[Features](#features)**
  - [1. Application version bump to 3.8.1](#1-application-version-bump-to-381)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version bump to 3.8.1

The midaz application has been updated from version `3.8.0` to `3.8.1`. This is a patch release that includes bug fixes and minor improvements to the ledger and CRM services.

#### What changed

| Component | v8.7.0 | v8.8.0 |
|-----------|--------|--------|
| Chart version | 8.7.0 | 8.8.0 |
| App version | 3.8.0 | 3.8.1 |
| Ledger image tag | 3.8.0 | 3.8.1 |
| CRM image tag | 3.8.0 | 3.8.1 |

#### Why it matters

This patch release ensures that both the ledger and CRM services are running the latest stable version with bug fixes and performance improvements. The upgrade is backward compatible and requires no configuration changes.

#### Impact

- **Ledger service**: The container image will be updated to `3.8.1`
- **CRM service**: The container image will be updated to `3.8.1`
- **Downtime**: Minimal — rolling update will be performed automatically
- **Configuration**: No changes required to existing values

> **Note:** For detailed application-level changes, refer to the [midaz changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

## Configuration Reference

No new configuration parameters were introduced in this release. All existing values remain compatible.

The following image tags are automatically updated when upgrading to chart version `8.8.0`:

```yaml
ledger:
  image:
    tag: "3.8.1"

crm:
  image:
    tag: "3.8.1"
```

> **Important:** If you have explicitly pinned image tags in your `values.yaml` overrides, ensure they are updated to `3.8.1` or removed to use the chart defaults.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.8.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.8.0 -n midaz
```
