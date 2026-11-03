# Helm Upgrade from v0.6.1 to v0.6.2

## Topics

- **[Overview](#overview)**
- **[What Changed](#what-changed)**
  - [1. Application Version Bump](#1-application-version-bump)
  - [2. Image Tag Updates](#2-image-tag-updates)
  - [3. Migrations Comment Clarification](#3-migrations-comment-clarification)
- **[Migration Impact](#migration-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the `plugin-br-pix-jd` chart from version 0.6.1 to 0.6.2. The release bumps the application version from 1.6.0 to 1.6.1 and updates all component image tags accordingly.

| Setting | v0.6.1 | v0.6.2 |
|---------|--------|--------|
| Chart Version | 0.6.1 | 0.6.2 |
| App Version | 1.6.0 | 1.6.1 |
| API Image Tag | 1.6.0 | 1.6.1 |
| Worker Image Tag | 1.6.0 | 1.6.1 |
| Migrations Image Tag | 1.6.0 | 1.6.1 |

## What Changed

### 1. Application Version Bump

The chart's `appVersion` field has been updated from `1.6.0` to `1.6.1`, reflecting a patch release of the plugin-br-pix-jd application.

**Chart.yaml change:**

```yaml
# Before (v0.6.1)
appVersion: "1.6.0"

# After (v0.6.2)
appVersion: "1.6.1"
```

This version bump indicates bug fixes or minor improvements in the application binary.

### 2. Image Tag Updates

All component image tags have been synchronized to version `1.6.1`:

| Component | Image Repository | v0.6.1 Tag | v0.6.2 Tag |
|-----------|-----------------|------------|------------|
| API | `ghcr.io/lerianstudio/plugin-br-pix-jd` | `1.6.0` | `1.6.1` |
| Worker | `ghcr.io/lerianstudio/plugin-br-pix-jd-worker` | `1.6.0` | `1.6.1` |
| Migrations | `ghcr.io/lerianstudio/plugin-br-pix-jd-migrations` | `1.6.0` | `1.6.1` |

**values.yaml changes:**

```yaml
# API component
api:
  image:
    tag: "1.6.1"  # was "1.6.0"

# Worker component
worker:
  image:
    tag: "1.6.1"  # was "1.6.0"

# Migrations job
migrations:
  image:
    tag: "1.6.1"  # was "1.6.0"
```

> **Note:** If you have explicitly pinned image tags in your `values.yaml` overrides, those pins will take precedence over the chart defaults. Review your custom values to ensure they reference the correct version.

### 3. Migrations Comment Clarification

The inline documentation for the migrations image tag has been simplified to remove version-specific migration details.

**Before (v0.6.1):**

```yaml
migrations:
  image:
    # -- Pinned explicitly: api, worker and migrations are all published at 1.3.0.
    # Migrations are independently versioned; a release that does not touch the SQL
    # skips this image, so re-check the pin on every appVersion bump. 1.3.0 adds
    # 000045-000055, and the 1.3.0 binary needs them (000054 above all: without it
    # no Pix is created or settled), so this Job must run them before the app rolls.
    tag: "1.6.0"
```

**After (v0.6.2):**

```yaml
migrations:
  image:
    # -- Pinned explicitly: api, worker and migrations are all published at 1.6.1.
    # Migrations are independently versioned; a release that does not touch the SQL
    # skips this image, so re-check the pin on every appVersion bump. The app needs
    # every migration this image carries, so this Job must run them before the app rolls.
    tag: "1.6.1"
```

This is a documentation-only change with no functional impact. The comment now provides a general reminder to verify the migrations image tag on every appVersion bump, without referencing specific migration file numbers.

## Migration Impact

**No configuration changes required.** This upgrade can be applied directly to existing v0.6.1 installations.

The upgrade will:

1. **Trigger a rolling update** of the API deployment with the new `1.6.1` image
2. **Trigger a rolling update** of the worker deployment (if enabled) with the new `1.6.1` image
3. **Run the migrations Job** (if `migrations.enabled=true` and `MULTI_TENANT_ENABLED` is not `true`) with the `1.6.1` migrations image

> **Important:** The migrations Job will run during the upgrade hook phase. If using bundled PostgreSQL, the Job runs in the `post-upgrade` phase (after the API starts rolling). If using external PostgreSQL, it runs in the `pre-upgrade` phase (before the API rolls). Monitor the Job to ensure schema changes complete successfully:
> ```bash
> kubectl -n midaz-plugins logs job/plugin-br-pix-jd-migrations
> ```

> **Note:** Since this is a patch version bump (1.6.0 → 1.6.1), breaking schema changes are not expected.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.6.2 -n midaz-plugins
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.6.2 -n midaz-plugins
```
