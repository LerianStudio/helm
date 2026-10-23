# Helm Upgrade from v9.8.0 to v9.8.1

## Topics

- **[Application Version Update](#application-version-update)**
  - [1. Midaz application bump to 4.3.0](#1-midaz-application-bump-to-430)
  - [2. Image tag updates](#2-image-tag-updates)
  - [3. New migration image tags](#3-new-migration-image-tags)

## Application Version Update

### 1. Midaz application bump to 4.3.0

The Midaz application version has been updated from `4.2.2` to `4.3.0`. This is a minor version bump that includes new features and improvements.

| Component | v9.8.0 | v9.8.1 |
|-----------|--------|--------|
| appVersion | 4.2.2 | 4.3.0 |

For detailed application-level changes, refer to the [Midaz changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

### 2. Image tag updates

The following service images have been updated to version `4.3.0`:

| Service | v9.8.0 | v9.8.1 |
|---------|--------|--------|
| ledger.image.tag | 4.2.2 | 4.3.0 |
| tracer.image.tag | 4.2.2 | 4.3.0 |

**Before (v9.8.0):**

```yaml
ledger:
  image:
    tag: "4.2.2"

tracer:
  image:
    tag: "4.2.2"
```

**After (v9.8.1):**

```yaml
ledger:
  image:
    tag: "4.3.0"

tracer:
  image:
    tag: "4.3.0"
```

> **Note:** These image tags are automatically updated when upgrading the chart. No manual intervention is required unless you have explicitly overridden these values in your deployment.

### 3. New migration image tags

Two new top-level configuration blocks have been added to explicitly control migration runner image tags:

```yaml
midaz-ledger-migrations:
  image:
    tag: 4.3.0

midaz-tracer-migrations:
  image:
    tag: 4.3.0
```

These values provide explicit control over the migration job images, ensuring they match the application version. Previously, migration image tags were controlled through the service-level configuration only.

> **Important:** If you have customized migration job configurations in your values, ensure these new blocks are aligned with your deployment strategy.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.8.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.8.1 -n midaz
```
