# Helm Upgrade from v0.5.7 to v0.5.8

## Overview

This is a patch release that upgrades the application from version 1.3.0 to 1.5.0. The chart updates all container image tags (API, worker, and migrations) to align with the new application version.

| Setting | v0.5.7 | v0.5.8 |
|---------|--------|--------|
| Chart Version | 0.5.7 | 0.5.8 |
| App Version | 1.3.0 | 1.5.0 |
| API Image Tag | 1.3.0 | 1.5.0 |
| Worker Image Tag | 1.3.0 | 1.5.0 |
| Migrations Image Tag | 1.3.0 | 1.5.0 |

## What Changed

### Image Tag Updates

All three component images have been updated to version 1.5.0:

- **API image**: `ghcr.io/lerianstudio/plugin-br-pix-jd:1.3.0` → `1.5.0`
- **Worker image**: `ghcr.io/lerianstudio/plugin-br-pix-jd-worker:1.3.0` → `1.5.0`
- **Migrations image**: `ghcr.io/lerianstudio/plugin-br-pix-jd-migrations:1.3.0` → `1.5.0`

These changes affect the following values:

```yaml
api:
  image:
    tag: "1.5.0"  # was "1.3.0"

worker:
  image:
    tag: "1.5.0"  # was "1.3.0"

migrations:
  image:
    tag: "1.5.0"  # was "1.3.0"
```

> **Note:** If you have explicitly pinned image tags in your values file, you must update them to `1.5.0` for this upgrade to take effect. Explicit tags in your values override the chart defaults.

## Migration Impact

### Database Migrations

The migrations image has been updated to version 1.5.0. This upgrade will trigger the pre-upgrade migration Job if `migrations.enabled` is `true` (the default).

> **Important:** The migration Job must complete successfully before the API and worker pods roll out. If the Job fails, the upgrade will be blocked. Review migration Job logs if the upgrade hangs.

### Configuration Changes

No new configuration values, environment variables, or secrets are required for this upgrade. All existing configuration remains compatible with version 1.5.0.

## Operator Actions

### 1. Update Image Tags (if pinned)

If your values file explicitly sets image tags, update them to 1.5.0:

```yaml
api:
  image:
    tag: "1.5.0"

worker:
  image:
    tag: "1.5.0"

migrations:
  image:
    tag: "1.5.0"
```

### 2. Verify Migration Job Configuration

Ensure migrations are enabled (default behavior):

```yaml
migrations:
  enabled: true  # Must be true to run database migrations
```

> **Warning:** Setting `migrations.enabled: false` will skip database migrations. Only disable this if you are certain no schema changes are required or if you manage migrations externally.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.8 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.8 -n plugin-br-pix-jd
```
