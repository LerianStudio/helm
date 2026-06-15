# Helm Upgrade from v8.1.1 to v8.2.0

## Topics

- **[Features](#features)**
  - [1. Application version bump to 3.7.7](#1-application-version-bump-to-377)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version bump to 3.7.7

The midaz application has been updated from version `3.7.6` to `3.7.7`. This is a patch release that includes bug fixes and minor improvements to the ledger service.

#### Version changes

| Component | v8.1.1 | v8.2.0 |
|-----------|--------|--------|
| Chart version | 8.1.1 | 8.2.0 |
| App version | 3.7.6 | 3.7.7 |
| Ledger image tag | 3.7.6 | 3.7.7 |

#### What changed

The ledger service container image tag has been updated to reflect the new application version:

**Before (v8.1.1):**
```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "3.7.6"
```

**After (v8.2.0):**
```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "3.7.7"
```

#### Migration impact

This is a straightforward version bump with no breaking changes, configuration modifications, or operator action required. The upgrade will:

1. Pull the new `3.7.7` image for the ledger service
2. Perform a rolling update of the ledger deployment
3. Maintain all existing configuration and data

> **Note:** For detailed application-level changes in version 3.7.7, refer to the [midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

#### No configuration changes required

This release does not introduce:
- New environment variables
- Modified ConfigMap or Secret keys
- Changes to service ports or endpoints
- Database schema migrations
- Dependency version updates

Your existing `values.yaml` overrides will continue to work without modification.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.2.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.2.0 -n midaz
```
