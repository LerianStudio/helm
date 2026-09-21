# Helm Upgrade from v9.2.0 to v9.2.1

## Topics

- **[Application Version Update](#application-version-update)**
  - [1. Midaz application bump to 4.0.3](#1-midaz-application-bump-to-403)
  - [2. Image tag updates](#2-image-tag-updates)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

### 1. Midaz application bump to 4.0.3

This patch release updates the Midaz application from version `4.0.2` to `4.0.3`. This is a minor patch update that includes bug fixes and stability improvements.

| Component | v9.2.0 | v9.2.1 |
|-----------|--------|--------|
| appVersion | 4.0.2 | 4.0.3 |

For detailed application-level changes, refer to the [Midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

### 2. Image tag updates

The following container image tags have been updated to align with the new application version:

| Component | v9.2.0 | v9.2.1 |
|-----------|--------|--------|
| ledger.image.tag | 4.0.2 | 4.0.3 |
| tracer.image.tag | 4.0.2 | 4.0.3 |

**Before (v9.2.0):**

```yaml
ledger:
  image:
    tag: "4.0.2"

tracer:
  image:
    tag: "4.0.3"
```

**After (v9.2.1):**

```yaml
ledger:
  image:
    tag: "4.0.3"

tracer:
  image:
    tag: "4.0.3"
```

> **Note:** If you have overridden these image tags in your `values.yaml`, ensure they are updated to `4.0.3` or removed to use the chart defaults.

#### Operational Impact

This is a straightforward patch upgrade with no breaking changes, configuration modifications, or migration steps required. The upgrade will:

- Pull new container images for the `ledger` and `tracer` components
- Perform a rolling update of the affected deployments
- Maintain backward compatibility with existing configurations

No operator action is required beyond running the upgrade command. Existing data, secrets, and configurations remain unchanged.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.1 -n midaz
```
