# Helm Upgrade from v1.0.7 to v1.0.8

This patch release upgrades the application version from 1.3.0 to 1.4.0 and explicitly pins image tags in values.yaml. The chart also removes extraneous blank lines for consistency.

## Table of Contents

- **[Application Version Update](#application-version-update)**
- **[Image Tag Changes](#image-tag-changes)**
  - [Manager Image Tag](#manager-image-tag)
  - [Worker Image Tag](#worker-image-tag)
  - [Migrations Image Tag](#migrations-image-tag)
  - [Mock STA Image Tag](#mock-sta-image-tag)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

The chart's `appVersion` has been updated from `1.3.0` to `1.4.0`, bringing in the latest br-sta application release.

| Setting | v1.0.7 | v1.0.8 |
|---------|--------|--------|
| `appVersion` | `1.3.0` | `1.4.0` |

**What this means:**

The `appVersion` field serves as the default image tag for all br-sta components (manager, worker, migrations, and mock STA). This upgrade pulls in application-level changes from the 1.4.0 release.

> **Note:** If you have explicitly overridden image tags in your values.yaml (e.g., `manager.image.tag`, `worker.image.tag`), those overrides will continue to take precedence. Review your overrides to ensure they are compatible with the new default version.

## Image Tag Changes

In v1.0.8, all component image tags are now explicitly set to `"1.4.0"` in values.yaml. Previously, these fields were empty strings (`""`), which caused the chart to fall back to `Chart.appVersion`.

### Manager Image Tag

| Setting | v1.0.7 | v1.0.8 |
|---------|--------|--------|
| `manager.image.tag` | `""` (defaults to appVersion) | `"1.4.0"` |

**Before (v1.0.7):**

```yaml
manager:
  image:
    repository: ghcr.io/lerianstudio/br-sta-manager
    tag: ""
    pullPolicy: IfNotPresent
```

**After (v1.0.8):**

```yaml
manager:
  image:
    repository: ghcr.io/lerianstudio/br-sta-manager
    tag: "1.4.0"
    pullPolicy: IfNotPresent
```

### Worker Image Tag

| Setting | v1.0.7 | v1.0.8 |
|---------|--------|--------|
| `worker.image.tag` | `""` (defaults to manager.image.tag, then appVersion) | `"1.4.0"` |

**Before (v1.0.7):**

```yaml
worker:
  image:
    repository: ghcr.io/lerianstudio/br-sta-worker
    tag: ""
    pullPolicy: IfNotPresent
```

**After (v1.0.8):**

```yaml
worker:
  image:
    repository: ghcr.io/lerianstudio/br-sta-worker
    tag: "1.4.0"
    pullPolicy: IfNotPresent
```

### Migrations Image Tag

| Setting | v1.0.7 | v1.0.8 |
|---------|--------|--------|
| `migrations.image.tag` | `""` (defaults to appVersion) | `"1.4.0"` |

**Before (v1.0.7):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/br-sta-migrations
    tag: ""
    pullPolicy: IfNotPresent
```

**After (v1.0.8):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/br-sta-migrations
    tag: "1.4.0"
    pullPolicy: IfNotPresent
```

### Mock STA Image Tag

| Setting | v1.0.7 | v1.0.8 |
|---------|--------|--------|
| `mockSta.image.tag` | `""` (defaults to appVersion) | `"1.4.0"` |

**Before (v1.0.7):**

```yaml
mockSta:
  image:
    repository: ghcr.io/lerianstudio/mock-sta-server
    tag: ""
    pullPolicy: IfNotPresent
```

**After (v1.0.8):**

```yaml
mockSta:
  image:
    repository: ghcr.io/lerianstudio/mock-sta-server
    tag: "1.4.0"
    pullPolicy: IfNotPresent
```

**Operational Impact:**

This change makes the default image tags explicit in values.yaml rather than relying on template fallback logic. The functional behavior remains identical: all components will use version 1.4.0 unless you override the tags in your custom values.

> **Important:** If you have pinned image tags to a specific version in your values overrides, those pins will continue to apply. Review your custom values to ensure compatibility with the 1.4.0 application release.

**Example override to stay on 1.3.0:**

```yaml
manager:
  image:
    tag: "1.3.0"
worker:
  image:
    tag: "1.3.0"
migrations:
  image:
    tag: "1.3.0"
```

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.8
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.8
```
