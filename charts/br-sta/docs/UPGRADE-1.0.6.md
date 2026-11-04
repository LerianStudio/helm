# Helm Upgrade from v1.0.5 to v1.0.6

This patch release updates the default application version from 1.0.0 to 1.2.0, bringing the latest br-sta application features and fixes to the chart.

## Application Version Update

The `appVersion` field in Chart.yaml has been updated, which changes the default container image tags for the manager, worker, and migrations components.

| Setting | v1.0.5 | v1.0.6 |
|---------|--------|--------|
| `appVersion` | 1.0.0 | 1.2.0 |

### What This Means

The `appVersion` serves as the default image tag for three components:

- Manager deployment
- Worker deployment
- Migrations job

Unless you have explicitly overridden image tags in your `values.yaml`, this upgrade will pull and deploy version 1.2.0 of the br-sta application images.

### Action Required

**If you have NOT overridden image tags:**

The upgrade will automatically use the new 1.2.0 images. No action required.

**If you HAVE overridden image tags:**

Check your `values.yaml` for any of these overrides:

```yaml
manager:
  image:
    tag: "custom-tag"

worker:
  image:
    tag: "custom-tag"

migrations:
  image:
    tag: "custom-tag"
```

If you want to adopt the new 1.2.0 version, remove these overrides or update them to `"1.2.0"`.

> **Important:** The migrations job runs database schema updates. If you maintain custom image tags, ensure your migrations image version is compatible with your manager and worker versions.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.6
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.6
```
