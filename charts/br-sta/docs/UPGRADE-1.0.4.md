# Helm Upgrade from v1.0.3 to v1.0.4

This is a patch release that stops rendering the `common.license.isDevelopment` field into the ConfigMap and removes it from the chart documentation.

## Topics

- **[Configuration Changes](#configuration-changes)**
  - [License Configuration](#license-configuration)

## Configuration Changes

### License Configuration

The `isDevelopment` field has been removed from the `common.license` configuration block. This field was previously used to route the license SDK to a development gateway. The chart no longer renders it.

#### What Changed

| Setting | v1.0.3 | v1.0.4 |
|---------|--------|--------|
| `common.license.isDevelopment` | Available (optional) | Removed |
| Environment variable `IS_DEVELOPMENT` | Generated if set | No longer generated from `common.license.isDevelopment` |

**Before (v1.0.3):**

```yaml
common:
  license:
    organizationIds: "org-123,org-456"
    isDevelopment: true
```

**After (v1.0.4):**

```yaml
common:
  license:
    organizationIds: "org-123,org-456"
```

#### Impact

- If you have `common.license.isDevelopment` set in your `values.yaml`, it will be silently ignored after the upgrade
- The chart no longer renders `IS_DEVELOPMENT` from `common.license.isDevelopment` into the manager and worker ConfigMap
- The manager and worker pods restart on upgrade even without this key: `checksum/config` hashes the shared ConfigMap, whose chart-version label changes on upgrade. The `checksum/secret` annotation hashes the chart-managed shared Secret only when `common.useExistingSecret` is false; it is omitted when that setting is true because the Secret is operator-managed
- If you set `isDevelopment: "true"` for a key issued by the dev license gateway, the manager and worker now validate that key on the production gateway (`https://license.lerian.io`)

#### Action Required

> **Note:** The upgrade renders even if `isDevelopment` is still present in your values: the chart ignores it.

If you currently have `common.license.isDevelopment` configured:

1. Review your `values.yaml` or Helm value overrides:

```bash
helm get values br-sta -n br-sta
```

2. If `isDevelopment: true` is present under `common.license`, remove it from your values file since the chart ignores it:

```yaml
# Remove this line from your values.yaml
common:
  license:
    isDevelopment: true  # ← Remove this
```

3. The `organizationIds` field remains required and unchanged:

```yaml
common:
  license:
    organizationIds: "your-org-id"
```

> **Important:** If you set `common.license.isDevelopment: "true"` for a key issued by the dev license gateway, the manager and worker now validate that key on the production gateway. Before you upgrade, set a `LICENSE_KEY` that the production gateway accepts.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version 1.0.4 -n br-sta
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version 1.0.4 -n br-sta
```
