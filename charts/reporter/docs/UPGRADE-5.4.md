# Helm Upgrade from v5.3.2 to v5.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. License file support for manager and worker](#1-license-file-support-for-manager-and-worker)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Option 1: Continue using LICENSE_KEY (no action required)](#option-1-continue-using-license_key-no-action-required)
  - [Option 2: Migrate to signed license file](#option-2-migrate-to-signed-license-file)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor feature release that adds chart support for signed license files as an alternative to the `LICENSE_KEY` environment variable. The application version remains unchanged at `4.8.0`.

> **Warning:** reporter `4.8.0`, the image this chart deploys by default, cannot use a license file. It is built on `lib-license-go` v4.2.2, does not read `LICENSE_FILE_PATH`, and refuses to boot when `LICENSE_KEY` is empty. Keep `LICENSE_KEY` on chart 5.4.0 unless your manager and worker images are reporter `4.9.0` or later. Chart 5.4.1 is the first chart that deploys reporter `4.9.0` (`lib-license-go` v5.2.0) by default.

| Field | v5.3.2 | v5.4.0 |
|-------|--------|--------|
| Chart version | `5.3.2` | `5.4.0` |
| App version | `4.8.0` | `4.8.0` |

## Features

### 1. License file support for manager and worker

The chart can now give `manager` and `worker` the product license as a signed file instead of the `LICENSE_KEY` environment variable. The application reads that file only from reporter `4.9.0` (`lib-license-go` v5.2.0). reporter `4.8.0`, the default image of this chart, ignores it.

When configured, the chart mounts a Secret containing the license file at `/etc/lerian/license/license` and sets the `LICENSE_FILE_PATH` environment variable to point to it. The chart then stops requiring `LICENSE_KEY` at render time for that component. It does not remove `LICENSE_KEY`: if you keep the key set, the chart still renders it into the component Secret.

| Setting | v5.3.2 | v5.4.0 |
|---------|--------|--------|
| `manager.licenseFile.existingSecret` | not present | `""` (optional) |
| `worker.licenseFile.existingSecret` | not present | `""` (optional) |
| `secrets.LICENSE_KEY` requirement | always required for app >= 4.6.0 | waived if `licenseFile.existingSecret` is set |

**New fields added:**

| Component | Field | Default | Description |
|-----------|-------|---------|-------------|
| `manager` | `licenseFile.existingSecret` | `""` | Name of Secret containing signed license file with key `license` |
| `worker` | `licenseFile.existingSecret` | `""` | Name of Secret containing signed license file with key `license` |

**Rendered environment variable (v5.4.0 with license file):**

```yaml
env:
  - name: LICENSE_FILE_PATH
    value: /etc/lerian/license/license
```

**Rendered volume mount (v5.4.0 with license file):**

```yaml
volumeMounts:
  - name: license-file
    mountPath: /etc/lerian/license
    readOnly: true
```

**Rendered volume (v5.4.0 with license file):**

```yaml
volumes:
  - name: license-file
    secret:
      secretName: my-license-secret
      defaultMode: 0444
      items:
        - key: license
          path: license
```

> **Important:** The chart does not check the image. With reporter `4.8.0`, a license file and an empty `LICENSE_KEY` render without error, and then the manager and the worker refuse to boot. Use the license file only with reporter `4.9.0` or later; otherwise keep `secrets.LICENSE_KEY`.

**Updated license validation logic:**

The chart's `reporter.licenseKeyRequired` check now skips a component that has `licenseFile.existingSecret` set, and its error message names that option. The `secrets.LICENSE_KEY` comment in `values.yaml` says the same.

## Configuration Reference

### License file fields

| Field | Default | Description |
|-------|---------|-------------|
| `manager.licenseFile.existingSecret` | `""` | Name of Secret containing signed license file; Secret must have a `license` key |
| `worker.licenseFile.existingSecret` | `""` | Name of Secret containing signed license file; Secret must have a `license` key |

### Environment variables

When `licenseFile.existingSecret` is set, the following environment variable is added to the component:

| Variable | Value | Description |
|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `/etc/lerian/license/license` | Path to the mounted license file |

## Migration Steps

This upgrade is backward-compatible and requires no mandatory changes. Existing deployments using `secrets.LICENSE_KEY` will continue to work without modification.

### Option 1: Continue using LICENSE_KEY (no action required)

If your deployment already sets `secrets.LICENSE_KEY` (or uses an existing Secret via `manager.useExistingSecret` and `worker.useExistingSecret`), no changes are required. The upgrade will proceed without modification.

**Existing configuration (v5.3.2):**

```yaml
secrets:
  LICENSE_KEY: "your-license-key"
```

This configuration remains valid in v5.4.0.

### Option 2: Migrate to signed license file

Use this option only if you have received a signed license file from Lerian Studio and your manager and worker images are reporter `4.9.0` or later.

> **Warning:** Chart 5.4.0 deploys reporter `4.8.0` by default, which cannot read the license file. Upgrade to chart 5.4.1 or later, which deploys reporter `4.9.0`, or set `manager.image.tag` and `worker.image.tag` to `4.9.0` or later in your values. Otherwise keep `LICENSE_KEY` (Option 1).

#### Step 1: Check the image version

Confirm the reporter version that your values deploy. Without an `image.tag` override, chart 5.4.0 deploys `4.8.0` and chart 5.4.1 deploys `4.9.0`. If you pin `manager.image.tag` or `worker.image.tag`, both must be `4.9.0` or later. If they are not, stop here and keep `LICENSE_KEY`.

#### Step 2: Create a Secret containing the license file

Create a Kubernetes Secret with the signed license file content. The Secret must have a key named `license`:

```bash
kubectl create secret generic reporter-license \
  --from-file=license=/path/to/your/license.lic \
  -n reporter
```

> **Note:** The Secret key must be exactly `license`: the chart expects this key name when mounting the file.

#### Step 3: Configure the chart to use the license file

Update your `values.yaml` or values override file to reference the license Secret for both manager and worker:

```yaml
manager:
  licenseFile:
    existingSecret: "reporter-license"

worker:
  licenseFile:
    existingSecret: "reporter-license"

secrets:
  # LICENSE_KEY can be removed or left empty when using licenseFile
  LICENSE_KEY: ""
```

> **Important:** If you set `licenseFile.existingSecret`, the chart no longer requires `secrets.LICENSE_KEY` for that component. Set it on both `manager` and `worker`: a component without it still needs `LICENSE_KEY`. Empty `LICENSE_KEY` only with reporter `4.9.0` or later.

#### Step 4: Execute the upgrade

Run the upgrade command with your updated values. The command uses chart 5.4.1, the first chart that deploys reporter `4.9.0` by default. Use `--version 5.4.0` only if you pin both image tags to `4.9.0` or later:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm \
  --version 5.4.1 \
  -n reporter \
  -f values-override.yaml
```

#### Step 5: Verify deployment health

Check that all pods are running and healthy:

```bash
kubectl get pods -n reporter
```

Verify that the license file is mounted correctly (do not print the file: it shows the license in your terminal and history):

```bash
kubectl exec -n reporter deployment/reporter-manager -- ls -la /etc/lerian/license/
```

Verify that the `LICENSE_FILE_PATH` environment variable is set:

```bash
kubectl exec -n reporter deployment/reporter-manager -- env | grep LICENSE_FILE_PATH
```

Check the application logs:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n reporter -l scaledjob.keda.sh/name=reporter-worker --tail=50
```

By default the worker runs as a KEDA `ScaledJob` (`worker.keda.scaledJob.enabled: true`), not a Deployment. KEDA labels its Job pods with `scaledjob.keda.sh/name`, not `app.kubernetes.io/name`, and they exist only while there is queued work, so the worker command can print nothing on an idle install.

> **Note:** Adding the license file rolls the manager Deployment. The worker `ScaledJob` uses the new pod spec for the next Jobs it starts. If the license file is invalid or the image is older than reporter `4.9.0`, the manager and the worker fail at boot; roll back by restoring `secrets.LICENSE_KEY` and removing `licenseFile.existingSecret`.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.0 -f values-override.yaml
```

> **Note:** Pass your values with `-f`: without it, `helm upgrade` reuses the stored values, so changes to your values file do not apply. Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.0 -f values-override.yaml
```
