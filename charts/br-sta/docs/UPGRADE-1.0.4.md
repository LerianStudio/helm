# Helm Upgrade from v1.0.3 to v1.0.4

This is a patch release that removes a deprecated license configuration field from the chart templates and documentation.

## Topics

- **[Configuration Changes](#configuration-changes)**
  - [License Configuration](#license-configuration)

## Configuration Changes

### License Configuration

The `isDevelopment` field has been removed from the `common.license` configuration block. This field was previously used to route the license SDK to a development gateway, but is no longer supported.

#### What Changed

| Setting | v1.0.3 | v1.0.4 |
|---------|--------|--------|
| `common.license.isDevelopment` | Available (optional) | Removed |
| Environment variable `IS_DEVELOPMENT` | Generated if set | No longer generated |

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
- The `IS_DEVELOPMENT` environment variable will no longer be injected into manager and worker pods
- The license SDK will use production endpoints regardless of any previous `isDevelopment` setting

#### Action Required

> **Note:** No immediate action is required. The upgrade will succeed even if `isDevelopment` is still present in your values.

If you currently have `common.license.isDevelopment` configured:

1. Review your `values.yaml` or Helm value overrides:

```bash
helm get values br-sta -n br-sta
```

2. If `isDevelopment: true` is present under `common.license`, remove it from your values file to keep your configuration clean:

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

> **Important:** If your deployment relied on `isDevelopment: true` to connect to a development license gateway, contact Lerian Studio support before upgrading to confirm your license configuration for production use.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://registry-1.docker.io/lerianstudio/br-sta-helm --version 1.0.4 -n br-sta
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://registry-1.docker.io/lerianstudio/br-sta-helm --version 1.0.4 -n br-sta
```
