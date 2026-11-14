<!-- {% raw %} -->
# Helm Upgrade from v2.0.4 to v2.1.0

## Topics

- **[Features](#features)**
  - [1. License file value (inactive with app 3.1.0)](#1-license-file-value-inactive-with-app-310)
- **[Configuration Reference](#configuration-reference)**
  - [License file configuration](#license-file-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Keep LICENSE_KEY and leave licenseFile empty](#step-1-keep-license_key-and-leave-licensefile-empty)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Features

Chart 2.1.0 keeps the application at 3.1.0, the same `appVersion` as chart 2.0.4. With the default values the rendered pod templates of every Deployment (`streaming-hub-all`, or `streaming-hub-ingest` and `streaming-hub-delivery` in `split` mode) are identical to 2.0.4, so the upgrade does not restart any pod.

### 1. License file value (inactive with app 3.1.0)

The chart adds `streamingHub.licenseFile.existingSecret`, an optional signed license file mounted from a Kubernetes Secret.

| Setting | v2.0.4 | v2.1.0 |
|---------|--------|--------|
| `streamingHub.licenseFile.existingSecret` | Not available | `""` (default, no change to the pods) |

When the value is set to a Secret name, the chart:

1. Mounts that Secret (key `license`) read-only as the directory `/etc/lerian/license` on every Deployment.
2. Sets `LICENSE_FILE_PATH=/etc/lerian/license/license`.
3. On the `useExistingSecret: true` path only, marks the `LICENSE_KEY` `secretKeyRef` as `optional: true`. On the chart-managed Secret path, `LICENSE_KEY` keeps reaching the pods through `envFrom`.

> **Warning:** Do not set `streamingHub.licenseFile.existingSecret` and do not remove `LICENSE_KEY` with this chart. App 3.1.0 is built with `lib-license-go` v4, which does not read `LICENSE_FILE_PATH`. The app reads only `LICENSE_KEY` and refuses to boot without it (`ErrMissingLicenseKey`). A Hub with the file mounted and no `LICENSE_KEY` does not start.

The license file mode needs an app built with `lib-license-go` v5. The first chart that ships such an app is 2.2.0 (app 3.4.0). See `UPGRADE-2.2.md` for the license behavior from that version on.

---

## Configuration Reference

### License file configuration

```yaml
streamingHub:
  licenseFile:
    existingSecret: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.licenseFile.existingSecret` | `""` | Name of an existing Secret with the signed license file under the key `license`. Leave empty with app 3.1.0. |

The `LICENSE_KEY` contract does not change with app 3.1.0:

- Chart-managed Secret (`useExistingSecret: false`): set `streamingHub.secrets.LICENSE_KEY`.
- External Secret (`useExistingSecret: true`): the Secret named by `streamingHub.existingSecretName` must carry `STREAMING_HUB_POSTGRES_DSN`, `STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY` and `LICENSE_KEY`.

---

## Migration Steps

### Step 1: Keep LICENSE_KEY and leave licenseFile empty

No action is required. Keep your current values:

- Do not set `streamingHub.licenseFile.existingSecret`.
- Keep `LICENSE_KEY` where it is today (chart values or the external Secret).

If your values file already sets `streamingHub.licenseFile.existingSecret`, set it back to `""` before the upgrade.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm --version 2.1.0 -n streaming-hub -f <your-values>.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

With the default `licenseFile` value, expect changes only in the `helm.sh/chart` labels of the objects, not in the Deployment pod templates.

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm --version 2.1.0 -n streaming-hub -f <your-values>.yaml
```
<!-- {% endraw %} -->
