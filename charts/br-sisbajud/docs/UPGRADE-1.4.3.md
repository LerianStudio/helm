# Helm Upgrade from v1.4.2 to v1.4.3

## Topics

- **[Fixes](#fixes)**
  - [License configuration cleanup](#license-configuration-cleanup)

## Fixes

### License configuration cleanup

The chart has removed the `isDevelopment` flag from the license configuration block. This flag was previously used to route the license SDK to a development gateway.

| Setting | v1.4.2 | v1.4.3 |
|---------|--------|--------|
| `brSisbajud.license.isDevelopment` | Supported (optional) | Removed |

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

2. **Template helper updated**: The `br-sisbajud.removedKeys` helper now includes `IS_DEVELOPMENT` in the list of removed environment variables, ensuring the chart will not emit it even if operators set it in `brSisbajud.configmap` or `brSisbajud.secrets`.

3. **Documentation updated**: All references to `isDevelopment` have been removed from:
   - `values.yaml` comments
   - `NOTES.txt` warning messages
   - `_helpers.tpl` validation messages

#### Operational impact

The br-sisbajud pod restarts on upgrade even if `isDevelopment` was never set: its `checksum/config` annotation hashes the ConfigMap, which carries the chart version label. `checksum/secret` hashes the chart-managed Secret and is not rendered with `brSisbajud.useExistingSecret: true`; `checksum/config` alone restarts the pod in that case.

**For production environments:**

No action required. Production environments should already be using production license keys without the `isDevelopment` flag.

**For development/staging environments:**

If you were using `brSisbajud.license.isDevelopment: "true"` with a development gateway license key, the chart no longer sets `IS_DEVELOPMENT`. Configure a key the production license gateway accepts:

```yaml
brSisbajud:
  configmap:
    ENV_NAME: "development"
  license:
    organizationIds: "global"
  secrets:
    LICENSE_KEY: "<production-license-key>"
```

> **Warning:** If your existing `LICENSE_KEY` was issued by the development gateway, the production gateway refuses it and the application will fail to start after upgrading. Obtain a production key.

#### Migration steps

1. **Find every source of `IS_DEVELOPMENT` and `LICENSE_KEY`**

   Read the values stored in the release:

   ```bash
   helm get values br-sisbajud -n br-sisbajud
   ```

   Look for `brSisbajud.license.isDevelopment`, `brSisbajud.secrets.LICENSE_KEY`, `brSisbajud.configmap.LICENSE_KEY`, `brSisbajud.secretRefs`, `brSisbajud.extraEnvVars`, and `brSisbajud.useExistingSecret` with `brSisbajud.existingSecretName`.

   `brSisbajud.configmap.LICENSE_KEY` is not in the chart's `removedKeys`: the ConfigMap escape hatch emits it verbatim, so the license key sits in clear text in the ConfigMap.

   `helm get values` does not show the content of a Secret the chart does not generate. With `useExistingSecret: true`, the chart does not render its own Secret: the pod loads the operator Secret with `envFrom`, unfiltered. List its keys (values stay hidden):

   ```bash
   kubectl -n br-sisbajud describe secret <existingSecretName>
   ```

   Do the same for every Secret that `brSisbajud.secretRefs` points to.

2. **Remove `IS_DEVELOPMENT` from every source that still sets it**

   The chart drops `IS_DEVELOPMENT` only from the ConfigMap and the Secret it generates (`brSisbajud.configmap`, `brSisbajud.secrets`). The license SDK of app 1.1.0 still reads the variable, so remove it where the chart does not filter it:

   - `brSisbajud.extraEnvVars`: delete the `IS_DEVELOPMENT` entry.
   - `brSisbajud.secretRefs.IS_DEVELOPMENT`: delete the entry.
   - The operator Secret of `useExistingSecret`: delete the `IS_DEVELOPMENT` key in the tool that owns the Secret (External Secrets, Vault, GitOps), or directly:

     ```bash
     kubectl -n br-sisbajud patch secret <existingSecretName> --type=json \
       -p '[{"op":"remove","path":"/data/IS_DEVELOPMENT"}]'
     ```

   Removing `brSisbajud.license.isDevelopment` is cleanup only: chart 1.4.3 ignores the key, and the schema still accepts it, so it does not fail the render.

   ```yaml
   brSisbajud:
     license:
       organizationIds: "global"
       # Optional cleanup, the chart ignores this line:
       # isDevelopment: "true"
   ```

3. **Update LICENSE_KEY at its effective source**

   The pod needs a key the production license gateway accepts, in every environment. App 1.1.0 refuses to boot with an empty `LICENSE_KEY` whatever `ENVIRONMENT_NAME` says (`validateLicenseConfig`: `LICENSE_KEY is required`). The render checks the key only in a production-like environment: in `local`, `development`, `staging`, `e2e` and `test` an empty key renders and the pod does not start. The `values.yaml`, `values-dev.yaml` and `_helpers.tpl` comments of chart 1.4.3 that call an empty key a dev bypass describe app 1.0.0, not app 1.1.0.

   Change the key where the pod really reads it:

   - `brSisbajud.extraEnvVars` or `brSisbajud.secretRefs.LICENSE_KEY`, when present: these render as explicit `env` and win over `envFrom`.
   - Otherwise the operator Secret, when `useExistingSecret: true`.
   - Otherwise `brSisbajud.secrets.LICENSE_KEY`.
   - Otherwise `brSisbajud.configmap.LICENSE_KEY`: `envFrom` loads the ConfigMap before the Secret, so this value counts only when no Secret or explicit `env` carries the key.

   Do not keep the key in `brSisbajud.configmap`. Move it to `brSisbajud.secrets.LICENSE_KEY`, `brSisbajud.secretRefs.LICENSE_KEY` or the operator Secret, and delete `brSisbajud.configmap.LICENSE_KEY`. The render gate of a production-like environment does not count the ConfigMap copy as a key.

   Change an external Secret before the upgrade. The chart does not hash a Secret it does not generate, so a later change to it does not restart the pod.

4. **Verify the upgrade**

   After upgrading, check that the application starts successfully:

   ```bash
   kubectl -n br-sisbajud logs -l app.kubernetes.io/name=br-sisbajud --tail=50
   ```

   Look for license validation messages. If you see errors about an invalid license key, verify your `LICENSE_KEY`.

#### Removed environment variable

| Variable | v1.4.2 | v1.4.3 | Description |
|----------|--------|--------|-------------|
| `IS_DEVELOPMENT` | Emitted from `brSisbajud.license.isDevelopment` | Not emitted | Previously routed license SDK to dev gateway |

> **Important:** The `IS_DEVELOPMENT` environment variable is now included in the chart's `removedKeys` list. Even if you manually add it to `brSisbajud.configmap` or `brSisbajud.secrets`, the chart will not emit it to the application pods. It still reaches the pod through `brSisbajud.extraEnvVars`, `brSisbajud.secretRefs.IS_DEVELOPMENT`, or the operator Secret of `useExistingSecret` (loaded by `envFrom`).

## Preview changes before upgrading

Pass the full values file of the release, with the edits from steps 2 and 3. Without `-f` or `--set`, Helm reuses the values stored in the release and ignores your edits.

```bash
helm diff upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version 1.4.3 -n br-sisbajud -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version 1.4.3 -n br-sisbajud -f values.yaml
```
