# Helm Upgrade from v8.x to v9.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version bump to 3.8.3](#1-application-version-bump-to-383)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor maintenance release that bumps the midaz application version from `3.8.2` to `3.8.3`. There are no breaking changes, configuration changes, or operator actions required beyond the standard upgrade command.

## Features

### 1. Application version bump to 3.8.3

The midaz ledger application has been updated to version `3.8.3`.

| Component | v8.9.0 | v9.0.0 |
|-----------|--------|--------|
| Chart version | 8.9.0 | 9.0.0 |
| App version | 3.8.2 | 3.8.3 |
| Ledger image tag | 3.8.2 | 3.8.3 |

**What changed:**

The `appVersion` field in `Chart.yaml` and the default `ledger.image.tag` in `values.yaml` have been updated to `3.8.3`.

**Why it matters:**

This release includes bug fixes, performance improvements, or minor enhancements in the midaz application. For detailed application-level changes, refer to the [midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

**Impact:**

- No configuration changes required
- No breaking API or behavior changes
- Existing values and secrets remain compatible
- Rolling update will deploy the new application version

> **Note:** If you have pinned the ledger image tag explicitly in your `values.yaml`, you may keep your existing version or update to `3.8.3` at your discretion.

## Migration Steps

No migration steps are required for this upgrade. The chart maintains full backward compatibility with v8.x configurations.

**Recommended pre-upgrade checklist:**

1. Review the [midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md) for application-level changes in version 3.8.3
2. Preview the upgrade using the helm-diff plugin (see below)
3. Ensure your Helm values are backed up
4. Proceed with the upgrade command

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.0.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.0.0 -n midaz
```
