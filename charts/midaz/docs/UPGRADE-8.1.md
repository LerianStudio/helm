# Helm Upgrade from v8.0.0 to v8.1.0

## Topics

- **[Features](#features)**
  - [1. Application version bump to 3.7.3](#1-application-version-bump-to-373)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version bump to 3.7.3

The midaz application has been updated from version `3.7.2` to `3.7.3`. This is a patch release that includes bug fixes and minor improvements.

#### Version changes

| Component | v8.0.0 | v8.1.0 |
|-----------|--------|--------|
| Chart version | 8.0.0 | 8.1.0 |
| App version | 3.7.2 | 3.7.3 |
| CRM image tag | 3.7.2 | 3.7.3 |

#### What changed

The CRM service image tag has been updated to align with the new application version:

**Before (v8.0.0):**
```yaml
crm:
  image:
    tag: "3.7.2"
```

**After (v8.1.0):**
```yaml
crm:
  image:
    tag: "3.7.3"
```

> **Note:** This is a minor patch update. No configuration changes or migration steps are required. The upgrade will pull the new image version and restart the CRM pods automatically.

#### Application changelog

For detailed information about application-level changes in version 3.7.3, refer to the [midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.1.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.1.0 -n midaz
```
