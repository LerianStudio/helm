# Helm Upgrade from v0.9.0 to v0.9.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
  - [Image Tag Changes](#image-tag-changes)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** that updates the application version from 1.7.0 to 1.8.0. The chart version increments from 0.9.0 to 0.9.1 with no changes to chart templates, configuration structure, or default values beyond the image tags.

| Setting | v0.9.0 | v0.9.1 |
|---------|--------|--------|
| Chart Version | 0.9.0 | 0.9.1 |
| App Version | 1.7.0 | 1.8.0 |
| API Image Tag | 1.7.0 | 1.8.0 |
| Worker Image Tag | 1.7.0 | 1.8.0 |
| Migrations Image Tag | 1.7.0 | 1.8.0 |

## Application Version Update

The upgrade updates the application container images across all three components (API, worker, and migrations) to version 1.8.0. This is a coordinated update that maintains version alignment between the application logic and database schema migrations.

### Image Tag Changes

All component image tags have been updated to `1.8.0`:

| Component | Image Repository | v0.9.0 Tag | v0.9.1 Tag |
|-----------|-----------------|------------|------------|
| API | `ghcr.io/lerianstudio/plugin-br-pix-jd` | `1.7.0` | `1.8.0` |
| Worker | `ghcr.io/lerianstudio/plugin-br-pix-jd-worker` | `1.7.0` | `1.8.0` |
| Migrations | `ghcr.io/lerianstudio/plugin-br-pix-jd-migrations` | `1.7.0` | `1.8.0` |

**Before (v0.9.0):**

```yaml
api:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    tag: "1.7.0"

worker:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.7.0"

migrations:
  image:
    tag: "1.7.0"
```

**After (v0.9.1):**

```yaml
api:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    tag: "1.8.0"

worker:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.8.0"

migrations:
  image:
    tag: "1.8.0"
```

> **Note:** If you have explicitly pinned image tags in your `values.yaml` to `1.7.0`, those overrides will prevent the automatic upgrade to `1.8.0`. Review your values file and remove or update any explicit tag pins.

> **Important:** The migrations image version must match the application version. The chart maintains this alignment by default, but if you override `api.image.tag` without updating `migrations.image.tag`, the migration Job may apply an incompatible schema version.

## Migration Steps

**No configuration changes required.** This upgrade only updates container image tags and can be applied directly to existing installations.

The upgrade process will:

1. Run the migrations Job with the `1.8.0` schema (if `migrations.enabled=true`)
2. Roll out the API Deployment with the `1.8.0` image
3. Roll out the worker Deployment with the `1.8.0` image (if `worker.enabled=true`)

> **Note:** If you are using the bundled PostgreSQL subchart (`postgresql.enabled=true`), the migrations Job runs as a `post-upgrade` hook and will complete after the API begins rolling out. Monitor the Job to ensure schema changes land successfully:
> ```bash
> kubectl -n midaz-plugins logs job/plugin-br-pix-jd-migrations
> ```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.9.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.9.1
```
