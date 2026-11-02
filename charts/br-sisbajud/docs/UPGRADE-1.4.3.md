# Helm Upgrade from v1.4.2 to v1.4.3

## Topics

- **[Fixes](#fixes)**
  - [License configuration cleanup](#license-configuration-cleanup)

## Fixes

### License configuration cleanup

The chart has removed the deprecated `isDevelopment` flag from the license configuration block. This flag was previously used to route the license SDK to a development gateway, but is no longer supported by the application.

| Setting | v1.4.2 | v1.4.3 |
|---------|--------|--------|
| `brSisbajud.license.isDevelopment` | Supported (optional) | Removed |
| License gateway routing | Configurable via `isDevelopment` | Always uses production gateway |

**Before (v1.4.2):**

```yaml
brSisbajud:
  license:
    organizationIds: "global"
    isDevelopment: "true"  # Routes to dev gateway
  secrets:
    LICENSE_KEY: "<dev-gateway-license-key>"
```

**After (v1.4.3):**

```yaml
brSisbajud:
  license:
    organizationIds: "global"
    # isDevelopment removed
  secrets:
    LICENSE_KEY: "<production-license-key>"
```

#### What changed

1. **Configuration field removed**: The `brSisbajud.license.isDevelopment` field has been removed from `values.yaml` and is no longer emitted as the `IS_DEVELOPMENT` environment variable in the application ConfigMap.

2. **Template helper updated**: The `br-sisbajud.removedKeys` helper now includes `IS_DEVELOPMENT` in the list of removed environment variables, ensuring the chart will not emit it even if operators include it in their values.

3. **Documentation updated**: All references to `isDevelopment` have been removed from:
   - `values.yaml` comments
   - `NOTES.txt` warning messages
   - `_helpers.tpl` validation messages

#### Operational impact

**For production environments:**

No action required. Production environments should already be using production license keys without the `isDevelopment` flag.

**For development/staging environments:**

If you were using `brSisbajud.license.isDevelopment: "true"` with a development gateway license key, you have two options:

**Option 1: Use the dev bypass (recommended for non-production)**

Remove the `isDevelopment` field and leave `LICENSE_KEY` empty. The application automatically bypasses license validation in `local`, `development`, `staging`, `e2e`, and `test` environments:

```yaml
brSisbajud:
  configmap:
    ENV_NAME: "development"  # or staging, e2e, test, local
  license:
    organizationIds: "global"
  secrets:
    LICENSE_KEY: ""  # Empty triggers dev bypass
```

> **Note:** The dev bypass only works when `ENV_NAME` is set to one of: `local`, `development`, `staging`, `e2e`, or `test`. Any other environment name requires a valid production license key.

**Option 2: Use a production license key**

Obtain a production license key and configure it in your values:

```yaml
brSisbajud:
  configmap:
    ENV_NAME: "development"
  license:
    organizationIds: "global"
  secrets:
    LICENSE_KEY: "<production-license-key>"
```

> **Warning:** Development gateway license keys are no longer supported. If your existing `LICENSE_KEY` was issued by the development gateway, the application will fail to start after upgrading. Either clear the key to use the dev bypass, or obtain a production key.

#### Migration steps

1. **Check your current configuration**

   Review your `values.yaml` or Helm release values:

   ```bash
   helm get values br-sisbajud -n br-sisbajud
   ```

   Look for `brSisbajud.license.isDevelopment` or `IS_DEVELOPMENT` in the output.

2. **Remove the deprecated field**

   If present, remove `isDevelopment` from your values file:

   ```yaml
   brSisbajud:
     license:
       organizationIds: "global"
       # Remove this line:
       # isDevelopment: "true"
   ```

3. **Update LICENSE_KEY if needed**

   - **For non-production environments** (`ENV_NAME` is `local`, `development`, `staging`, `e2e`, or `test`): Set `LICENSE_KEY` to an empty string or remove it entirely to use the dev bypass.
   - **For production-like environments**: Ensure you have a valid production license key.

4. **Verify the upgrade**

   After upgrading, check that the application starts successfully:

   ```bash
   kubectl -n br-sisbajud logs -l app.kubernetes.io/name=br-sisbajud --tail=50
   ```

   Look for license validation messages. If you see errors about an invalid license key, verify your `ENV_NAME` and `LICENSE_KEY` configuration.

#### Removed environment variable

| Variable | v1.4.2 | v1.4.3 | Description |
|----------|--------|--------|-------------|
| `IS_DEVELOPMENT` | Emitted from `brSisbajud.license.isDevelopment` | Not emitted | Previously routed license SDK to dev gateway; no longer supported |

> **Important:** The `IS_DEVELOPMENT` environment variable is now included in the chart's `removedKeys` list. Even if you manually add it to `brSisbajud.configmap` or `brSisbajud.extraEnvVars`, the chart will not emit it to the application pods.

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.4.3 -n br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.4.3 -n br-sisbajud
```
