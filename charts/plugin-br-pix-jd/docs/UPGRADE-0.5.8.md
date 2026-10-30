# Helm Upgrade from v0.5.7 to v0.5.8

## Overview

This is a patch release that moves the application from version 1.3.0 to 1.5.0. The chart changes `appVersion` and the default image tags of the API, the worker, and the migrations Job. No template, value key, or secret changes: rendering v0.5.7 and v0.5.8 with the same values differs only in image tags, the `app.kubernetes.io/version` and `helm.sh/chart` labels, and the `checksum/config` and `checksum/secret` pod annotations.

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

The worker only runs if `worker.enabled` is `true`, which is not the default. An empty tag falls back to `appVersion`, but in this chart the three tags are set explicitly in `values.yaml`.

> **Note:** If your values file sets any of these tags, your value wins over the chart default and that image stays at the old version. Update the pinned tags to `1.5.0` to get the new application. The chart does not check that the three tags match, so move `api.image.tag`, `worker.image.tag`, and `migrations.image.tag` together.

## Migration Impact

### Database Migrations

The migrations image has been updated to version 1.5.0. The chart renders the migrations Job when `migrations.enabled` is `true` (the default). The chart does not describe what changed in the 1.5.0 schema.

With the default external PostgreSQL, the Job is a `pre-install`/`pre-upgrade` Helm hook (ArgoCD PreSync) and runs before the app rolls out. A failed Job fails the upgrade. The Job allows 3 retries (`backoffLimit`) and 600 seconds (`activeDeadlineSeconds`) by default. Review the Job logs if the upgrade hangs.

With the bundled PostgreSQL (`postgresql.enabled: true`), the Job is a `post-install`/`post-upgrade` hook (ArgoCD PostSync) and runs after the API rolls out, so the API pods run the new image against the old schema until the Job finishes.

With `MULTI_TENANT_ENABLED: "true"` in `api.configmap`, the chart does not render the Job at all, because the Tenant Manager migrates the tenant databases.

### Configuration Changes

The chart adds no values, environment variables, or secrets in this release, and the rendered ConfigMaps and Secrets keep the same keys. Whether application 1.5.0 itself needs new configuration is not stated in the chart; check the application release notes.

The API Deployment rolls (`RollingUpdate`, `maxUnavailable: 0`) because the image tag changes. If the worker is enabled, its `Recreate` Deployment is replaced.

## Operator Actions

### 1. Update Image Tags (if pinned)

If your values file explicitly sets image tags, update them to 1.5.0 (the worker tag only matters if `worker.enabled` is `true`):

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

> **Warning:** Setting `migrations.enabled: false` skips database migrations. Only disable this if you apply the schema changes yourself.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.8 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.8 -n plugin-br-pix-jd
```
