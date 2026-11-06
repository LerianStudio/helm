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

This is a minor feature release that adds support for signed license files as an alternative to the `LICENSE_KEY` environment variable. The application version remains unchanged at `4.8.0`.

| Field | v5.3.2 | v5.4.0 |
|-------|--------|--------|
| Chart version | `5.3.2` | `5.4.0` |
| App version | `4.8.0` | `4.8.0` |

## Features

### 1. License file support for manager and worker

Both `manager` and `worker` components now support loading the product license from a signed file instead of the `LICENSE_KEY` environment variable. This feature requires an application image built with `lib-license-go` v5 or later.

When configured, the chart mounts a Secret containing the license file at `/etc/lerian/license/license` and sets the `LICENSE_FILE_PATH` environment variable to point to it. This is mutually exclusive with `LICENSE_KEY` — if a license file is configured, the `LICENSE_KEY` requirement is waived.

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

> **Important:** The license file feature requires an application image built with `lib-license-go` v5 or later. If your image does not support `LICENSE_FILE_PATH`, continue using `secrets.LICENSE_KEY`.

**Updated license validation logic:**

The chart's `reporter.licenseKeyRequired` helper now exempts components that have `licenseFile.existingSecret` set. The validation error message has been updated to mention the license file option:

**Before (v5.3.2):**

```
ERROR: secrets.LICENSE_KEY is REQUIRED for reporter app >= 4.6.0 (manager.image.tag is "4.8.0").
   The manager AND the worker refuse to boot without a license.
   Set secrets.LICENSE_KEY,
   or set manager.useExistingSecret=true and manager.existingSecretName to a Secret that carries them.
   See charts/reporter/docs/UPGRADE-5.1.md.
```

**After (v5.4.0):**

```
ERROR: secrets.LICENSE_KEY is REQUIRED for reporter app >= 4.6.0 (manager.image.tag is "4.8.0").
   The manager AND the worker refuse to boot without a license.
   Set secrets.LICENSE_KEY, or manager.licenseFile.existingSecret (needs an image on lib-license-go v5),
   or set manager.useExistingSecret=true and manager.existingSecretName to a Secret that carries them.
   See charts/reporter/docs/UPGRADE-5.1.md.
```

**Updated values.yaml comment:**

The `secrets.LICENSE_KEY` comment now clarifies that the key is not needed when using `licenseFile`:

**Before (v5.3.2):**

```yaml
secrets:
  # -- Product license. REQUIRED for app >= 4.6.0: the manager AND the worker refuse to boot
  # without it, and the chart refuses to render it for those tags (reporter.licenseKeyRequired).
  # LICENSE_KEY: ""
```

**After (v5.4.0):**

```yaml
secrets:
  # -- Product license. REQUIRED for app >= 4.6.0: the manager AND the worker refuse to boot
  # without it, and the chart refuses to render it for those tags (reporter.licenseKeyRequired),
  # unless <component>.licenseFile.existingSecret is set.
  # LICENSE_KEY: ""
```

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

If you have received a signed license file from Lerian Studio and your application images support `lib-license-go` v5, you can migrate to file-based licensing.

#### Step 1: Create a Secret containing the license file

Create a Kubernetes Secret with the signed license file content. The Secret must have a key named `license`:

```bash
kubectl create secret generic reporter-license \
  --from-file=license=/path/to/your/license.lic \
  -n reporter
```

> **Note:** The Secret key must be exactly `license` — the chart expects this key name when mounting the file.

#### Step 2: Configure the chart to use the license file

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

> **Important:** If you set `licenseFile.existingSecret`, you can remove or leave empty `secrets.LICENSE_KEY`. The chart will not require `LICENSE_KEY` when a license file is configured.

#### Step 3: Verify image compatibility

Confirm that your manager and worker images support `LICENSE_FILE_PATH`. This feature requires `lib-license-go` v5 or later. If your images do not support this variable, the pods will fail to start.

Check the application logs after upgrade:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-worker --tail=50
```

If the application does not recognize `LICENSE_FILE_PATH`, roll back to using `secrets.LICENSE_KEY`.

#### Step 4: Execute the upgrade

Run the upgrade command with your updated values:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm \
  --version 5.4.0 \
  -n reporter \
  -f values-override.yaml
```

#### Step 5: Verify deployment health

Check that all pods are running and healthy:

```bash
kubectl get pods -n reporter
```

Verify that the license file is mounted correctly:

```bash
kubectl exec -n reporter -it deployment/reporter-manager -- ls -la /etc/lerian/license/
kubectl exec -n reporter -it deployment/reporter-manager -- cat /etc/lerian/license/license
```

Verify that the `LICENSE_FILE_PATH` environment variable is set:

```bash
kubectl exec -n reporter -it deployment/reporter-manager -- env | grep LICENSE_FILE_PATH
```

> **Note:** The upgrade triggers a rolling restart of both manager and worker deployments. If the license file is invalid or the image does not support `LICENSE_FILE_PATH`, pods will fail to start.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.4.0
```
