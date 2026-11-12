# Helm Upgrade from v0.6.3 to v0.7.0

## Topics

- **[Overview](#overview)**
- **[What Changed](#what-changed)**
  - [1. Optional license file](#1-optional-license-file)
  - [2. LICENSE_KEY is required only without a license file](#2-license_key-is-required-only-without-a-license-file)
- **[Migration Impact](#migration-impact)**
- **[License file: do not use it with image 1.6.1](#license-file-do-not-use-it-with-image-161)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Overview

This minor release adds an optional license file to the `plugin-br-pix-jd` chart. The default image does not change.

| Setting | v0.6.3 | v0.7.0 |
|---------|--------|--------|
| Chart Version | 0.6.3 | 0.7.0 |
| App Version | 1.6.1 | 1.6.1 |
| API / Worker / Migrations Image Tag | 1.6.1 | 1.6.1 |
| New values | none | `api.licenseFile.existingSecret`, `worker.licenseFile.existingSecret` |
| `LICENSE_KEY` | Always required | Required unless the component has `licenseFile.existingSecret` |

> **Important:** The default image `plugin-br-pix-jd:1.6.1` uses lib-license-go v4.2.2. It does not read a license file and does not start without `LICENSE_KEY`. Keep `LICENSE_KEY` set with this chart. See [License file: do not use it with image 1.6.1](#license-file-do-not-use-it-with-image-161).

## What Changed

### 1. Optional license file

Two new values name a pre-existing Secret that holds a signed license file under the key `license`:

```yaml
api:
  licenseFile:
    existingSecret: ""   # default: off
worker:
  licenseFile:
    existingSecret: ""   # default: off; independent of api.licenseFile
```

When a component sets `licenseFile.existingSecret`, the chart changes that component's Deployment:

- It mounts the Secret as a directory (not `subPath`) at `/etc/lerian/license`, with the single item `license`.
- It adds `LICENSE_FILE_PATH=/etc/lerian/license/license` to the container env.

The two values are independent. `worker.licenseFile.existingSecret` does **not** inherit `api.licenseFile.existingSecret`. The worker templates (`worker/secrets.yaml`, `worker/deployment.yaml`) read only `.Values.worker.licenseFile`.

### 2. LICENSE_KEY is required only without a license file

In v0.6.3 the render failed when `LICENSE_KEY` was empty. In v0.7.0 each component skips that check only when it has its own license file:

| Component values | v0.6.3 | v0.7.0 |
|------------------|--------|--------|
| `LICENSE_KEY` set, no license file | Renders | Renders (no change) |
| `LICENSE_KEY` empty, no license file | Render fails | Render fails |
| api: `LICENSE_KEY` empty, `api.licenseFile` set | Render fails | Renders; the api Secret has no `LICENSE_KEY` |
| worker enabled: `LICENSE_KEY` empty, only `api.licenseFile` set | Render fails | **Render fails** (worker Secret) |
| worker enabled: `LICENSE_KEY` empty, `worker.licenseFile` set | Render fails | Renders; the worker Secret has no `LICENSE_KEY` |
| `LICENSE_KEY` set and license file set | Renders | Renders; the Secret keeps `LICENSE_KEY` and the pod also gets `LICENSE_FILE_PATH` |

The worker key still falls back to the api key: `worker.secrets.LICENSE_KEY`, then `api.secrets.LICENSE_KEY`.

A render failure aborts the whole `helm upgrade`, so nothing is applied. The worker error is:

```
ERROR: a license key is required for the worker unless worker.licenseFile.existingSecret is set.
```

Which source the application uses when both are present depends on the image, not on the chart. Image 1.6.1 reads only `LICENSE_KEY`.

## Migration Impact

**No configuration change is required.** The new values default to off, and v0.6.3 values render the same manifests in v0.7.0.

With unchanged values, the render differs from v0.6.3 only in the `helm.sh/chart` label on the chart objects. The pod templates do not carry that label, so this upgrade does not restart the api or worker pods.

If you set a `licenseFile.existingSecret`, the pod template changes (new volume, mount and env). The api pods then restart with a rolling update. The worker pods restart with the `Recreate` strategy: the old worker stops before the new one starts.

## License file: do not use it with image 1.6.1

Do not remove `LICENSE_KEY` with this chart version. The default image (1.6.1) and every stable `plugin-br-pix-jd` release so far use lib-license-go v4, which has no file mode:

- The app does not read `LICENSE_FILE_PATH`.
- The app refuses to boot with an empty `LICENSE_KEY` (`LICENSE_KEY is required`).

If you set `licenseFile.existingSecret` and keep `LICENSE_KEY`, image 1.6.1 ignores the file and keeps using the key. The pods still need the Secret to exist: a missing Secret or a missing `license` key keeps them in `ContainerCreating`.

File mode needs an image on lib-license-go v5. Adopt it only with a later chart whose default image is on v5, and follow that chart's upgrade guide. Do not pin a pre-release image with this chart to get file mode.

To check that a license Secret exists and has the `license` key, count its bytes. Do not decode it: the decoded license would go to the terminal and the shell history.

```bash
kubectl -n midaz-plugins get secret <license-secret> -o jsonpath='{.data.license}' | wc -c
```

A result above `0` means the key exists.

## Preview changes before upgrading

```bash
helm diff upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.7.0 -n midaz-plugins -f my-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

With unchanged values, expect only the `helm.sh/chart` label to change, from `plugin-br-pix-jd-helm-0.6.3` to `plugin-br-pix-jd-helm-0.7.0`.

## Command to upgrade

```bash
helm upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.7.0 -n midaz-plugins -f my-values.yaml
```

Replace `<pix-release>` with your release name.

If you set the payment signing key and certificate with `--set-file`, add the same two `--set-file` flags to these commands. Otherwise the upgrade drops them and payment orders go out unsigned.

## Verify

```bash
kubectl -n midaz-plugins get pods -l app.kubernetes.io/instance=<pix-release>,app.kubernetes.io/component=api
kubectl -n midaz-plugins get pods -l app.kubernetes.io/instance=<pix-release>,app.kubernetes.io/component=worker
```

All pods must stay `Running` and `Ready`. Confirm that the Secrets still carry the license key, without printing it:

```bash
kubectl -n midaz-plugins get secret plugin-br-pix-jd-api -o jsonpath='{.data.LICENSE_KEY}' | wc -c
kubectl -n midaz-plugins get secret plugin-br-pix-jd-worker -o jsonpath='{.data.LICENSE_KEY}' | wc -c
```

Both results must be above `0` (the worker Secret exists only when `worker.enabled=true`). If you use `api.existingSecret.name` or `worker.existingSecret.name`, check that Secret instead.
