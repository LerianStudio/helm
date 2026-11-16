# Helm Upgrade from v1.0.3 to v1.0.4

This is a patch release that stops rendering the `common.license.isDevelopment` field into the ConfigMap and removes it from the chart documentation.

## Topics

- **[Configuration Changes](#configuration-changes)**
  - [License Configuration](#license-configuration)

## Configuration Changes

### License Configuration

The `isDevelopment` field has been removed from the `common.license` configuration block. This field was previously used to route the license SDK to a development gateway. The chart no longer renders it.

> **Historical scope:** This guide covers chart 1.0.3 to 1.0.4 with the default app 1.0.0 images (license SDK v4.1.0), not later application releases. Chart 1.0.4 removes only the modeled `common.license.isDevelopment` mapping; it does not disable the SDK's `IS_DEVELOPMENT` switch. An exact pod environment value of `IS_DEVELOPMENT=true` still selects the development gateway. The variable can also enter through `common.configmap`, `common.secrets`, an operator-managed shared Secret, `common.secretRefs.IS_DEVELOPMENT`, or the component's `extraEnvVars`.

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
- If `common.license.isDevelopment` was your only source of `IS_DEVELOPMENT=true`, removing its mapping makes app 1.0.0 use the production gateway (`https://license.lerian.io`). Other environment injection paths can still select the development gateway; inspect both manager and worker configurations before upgrading.

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

> **Important:** For app 1.0.0, removing `common.license.isDevelopment` switches to the production gateway only if no other source supplies `IS_DEVELOPMENT=true`. Before a production upgrade, remove that development override from all environment sources for both components and configure a `LICENSE_KEY` accepted by the production gateway. Inspect configuration privately; do not print or decode Secret values into shared logs.

## Preview changes before upgrading

Prepare `values-migrated.yaml` as the complete intended configuration: preserve unrelated settings and existing Secret references, remove the retired key, and check every environment injection path described above. Keep any values backups private because they may contain credentials. Both commands below reset stored values and apply this complete file; a partial example is not sufficient.

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version 1.0.4 -n br-sta --reset-values -f values-migrated.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version 1.0.4 -n br-sta --reset-values -f values-migrated.yaml
```
