# Helm Upgrade from v0.5.3 to v0.5.4

## Topics

- **[Overview](#overview)**
- **[What Changed](#what-changed)**
- **[Migration Impact](#migration-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch version bump that updates the application version from 1.2.1 to 1.2.4. The chart version increments from 0.5.3 to 0.5.4 to track the new application release.

| Setting | v0.5.3 | v0.5.4 |
|---------|--------|--------|
| Chart Version | 0.5.3 | 0.5.4 |
| App Version | 1.2.1 | 1.2.4 |
| Migrations Image Tag | 1.2.1 | 1.2.4 |

## What Changed

### 1. Application Version Bump

The `appVersion` field in `Chart.yaml` has been updated from `1.2.1` to `1.2.4`, which updates the default image tag for the API and worker components.

**Before (v0.5.3):**

```yaml
appVersion: "1.2.1"
```

**After (v0.5.4):**

```yaml
appVersion: "1.2.4"
```

**Operational impact:**

- If you have **not** explicitly pinned `api.image.tag` or `worker.image.tag` in your `values.yaml`, the upgrade will automatically pull the new `1.2.4` image
- If you **have** pinned the image tag explicitly, you must update it manually to benefit from the new application version

### 2. Migrations Image Tag Update

The migrations image tag has been updated from `1.2.1` to `1.2.4` to match the application version. This ensures schema migrations are synchronized with the application code.

**Before (v0.5.3):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.2.1"
```

**After (v0.5.4):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.2.4"
```

**Operational impact:**

- The migrations Job will run with the `1.2.4` migrations image during the upgrade
- If you have disabled migrations (`migrations.enabled=false`), this change has no effect
- If you have overridden `migrations.image.tag` in your values, you should update it to `1.2.4` to ensure schema compatibility

> **Note:** The migrations image is independently versioned. A release that does not modify the SQL schema may skip publishing a new migrations image. Always verify the tag exists in the registry before upgrading.

## Migration Impact

**No configuration changes required.** This upgrade can be applied directly to existing installations without modifying your `values.yaml`.

The upgrade will:

1. **Update the API and worker Deployments** to use the `1.2.4` image (unless you have explicitly pinned a different tag)
2. **Run the migrations Job** with the `1.2.4` migrations image (if `migrations.enabled=true`)
3. **Trigger a rolling restart** of API and worker pods to apply the new image

> **Important:** If you are using the bundled PostgreSQL subchart, the migrations Job runs in the `post-upgrade` hook phase. The API pods will roll out **before** the schema changes land. PIX routes may error briefly until the migration Job completes. Monitor the Job with:
> ```bash
> kubectl -n plugin-br-pix-jd logs job/plugin-br-pix-jd-migrations -f
> ```

### Rollback Considerations

If you need to roll back to v0.5.3 after upgrading:

```bash
helm rollback plugin-br-pix-jd -n plugin-br-pix-jd
```

> **Warning:** Helm rollback will revert the Deployment image tags to `1.2.1`, but it **will not** roll back database schema changes. If the `1.2.4` migrations introduced schema changes, you must manually revert them or the `1.2.1` application may fail against the newer schema.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.4 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.4 -n plugin-br-pix-jd
```
