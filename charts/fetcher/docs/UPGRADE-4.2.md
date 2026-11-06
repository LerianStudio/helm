# Helm Upgrade from v4.1.3 to v4.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. License file mode support](#1-license-file-mode-support)
- **[Configuration Reference](#configuration-reference)**
  - [License file configuration](#license-file-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Choose license mode](#step-1-choose-license-mode)
  - [Step 2: Configure license file (if using file mode)](#step-2-configure-license-file-if-using-file-mode)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `4.1.3` to `4.2.0`. This is a minor release that introduces an alternative licensing mechanism: operators can now provide a signed license file via a Kubernetes Secret instead of using the `LICENSE_KEY` environment variable.

The application version (`appVersion: 4.1.0`) is unchanged. No breaking changes are introduced. Existing installations using `secrets.LICENSE_KEY` will continue to work without modification. The new license file mode is optional and requires application images built with `lib-license-go v5` or later.

## Features

### 1. License file mode support

Both `manager` and `worker` components now support mounting a signed license file from a Kubernetes Secret as an alternative to the `LICENSE_KEY` environment variable. This mode is useful for:

- **License rotation without pod restarts**: Kubernetes automatically propagates Secret updates to mounted volumes, allowing license renewal without redeploying pods
- **Separation of concerns**: License files can be managed independently from application configuration
- **Enhanced security**: File-based licenses can be rotated via external secret management systems (e.g., Vault, AWS Secrets Manager)

**Before (v4.1.3):**

License was provided exclusively via the `LICENSE_KEY` environment variable:

```yaml
secrets:
  LICENSE_KEY: "your-base64-encoded-license-key"
```

**After (v4.2.0):**

Operators can choose between two modes:

#### Option 1: Environment variable mode (existing behavior)

```yaml
secrets:
  LICENSE_KEY: "your-base64-encoded-license-key"
```

#### Option 2: File mode (new)

```yaml
manager:
  licenseFile:
    existingSecret: "fetcher-manager-license"

worker:
  licenseFile:
    existingSecret: "fetcher-worker-license"
```

When `licenseFile.existingSecret` is set, the chart:

1. Mounts the Secret as a read-only volume at `/etc/lerian/license`
2. Sets the `LICENSE_FILE_PATH` environment variable to `/etc/lerian/license/license`
3. The application reads the license from the file instead of the `LICENSE_KEY` environment variable

> **Important:** File mode requires application images built with `lib-license-go v5` or later. Verify your `manager.image.tag` and `worker.image.tag` support this feature before enabling it.

> **Note:** The Secret must contain a key named `license` with the signed license file content. The chart expects this exact key name and will mount it at the path specified in `LICENSE_FILE_PATH`.

**Template changes:**

The Deployment templates for both `manager` and `worker` now include conditional volume mounts and environment variables when `licenseFile.existingSecret` is set.

**Before (v4.1.3):**

```yaml
# manager/deployment.yaml (simplified)
spec:
  template:
    spec:
      containers:
        - name: manager
          env:
            # LICENSE_KEY from secrets
```

**After (v4.2.0):**

```yaml
# manager/deployment.yaml (simplified)
spec:
  template:
    spec:
      containers:
        - name: manager
          env:
            # LICENSE_KEY from secrets (if not using file mode)
            # LICENSE_FILE_PATH set to /etc/lerian/license/license (if using file mode)
          volumeMounts:
            - name: license-file
              mountPath: /etc/lerian/license
              readOnly: true
      volumes:
        - name: license-file
          secret:
            secretName: fetcher-manager-license
            defaultMode: 0444
            items:
              - key: license
                path: license
```

The volume is mounted as a directory (not `subPath`) to ensure that Kubernetes propagates Secret updates to the running pod. The `defaultMode: 0444` sets the file as read-only for all users.

## Configuration Reference

### License file configuration

The following fields have been added to both `manager` and `worker` configuration blocks:

| Field | Default | Description |
|-------|---------|-------------|
| `manager.licenseFile.existingSecret` | `""` (empty) | Name of an existing Secret containing the signed license file (key: `license`) |
| `worker.licenseFile.existingSecret` | `""` (empty) | Name of an existing Secret containing the signed license file (key: `license`) |

**Example configuration:**

```yaml
manager:
  licenseFile:
    existingSecret: "fetcher-manager-license"

worker:
  licenseFile:
    existingSecret: "fetcher-worker-license"
```

**Environment variables:**

When `licenseFile.existingSecret` is set, the following environment variable is added to the container:

| Variable | Value | Description |
|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `/etc/lerian/license/license` | Path to the mounted license file |

**Secret structure:**

The referenced Secret must contain a key named `license`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: fetcher-manager-license
  namespace: midaz-plugins
type: Opaque
data:
  license: <base64-encoded-signed-license-file>
```

> **Note:** The chart does not create this Secret. Operators must create it manually or via an external secret management system before enabling file mode.

## Migration Steps

### Step 1: Choose license mode

Determine which licensing mode is appropriate for your deployment:

#### Option 1: Keep existing environment variable mode (no action required)

If you are currently using `secrets.LICENSE_KEY` and do not need license rotation without pod restarts, no changes are required. The upgrade will preserve your existing configuration.

```yaml
secrets:
  LICENSE_KEY: "your-existing-license-key"
```

#### Option 2: Migrate to file mode

If you want to enable license rotation without pod restarts, follow Step 2 to configure file mode.

> **Important:** Verify that your application images support `lib-license-go v5` before migrating to file mode. Check the upstream `fetcher` release notes or contact Lerian Studio support to confirm compatibility.

### Step 2: Configure license file (if using file mode)

If you choose to use file mode, create the required Secrets and update your `values.yaml`:

#### 2.1: Create license file Secrets

Create a Secret for each component (`manager` and `worker`) containing the signed license file:

```bash
# Create manager license Secret
kubectl create secret generic fetcher-manager-license \
  -n midaz-plugins \
  --from-file=license=/path/to/your/signed-license-file.lic

# Create worker license Secret
kubectl create secret generic fetcher-worker-license \
  -n midaz-plugins \
  --from-file=license=/path/to/your/signed-license-file.lic
```

> **Note:** The `--from-file=license=` flag ensures the Secret key is named `license`, which is required by the chart.

#### 2.2: Update values.yaml

Create a `values-override.yaml` file to enable file mode:

```yaml
manager:
  licenseFile:
    existingSecret: "fetcher-manager-license"

worker:
  licenseFile:
    existingSecret: "fetcher-worker-license"

# Optional: Remove LICENSE_KEY if migrating fully to file mode
secrets:
  LICENSE_KEY: ""
```

> **Important:** If both `licenseFile.existingSecret` and `secrets.LICENSE_KEY` are set, the application behavior depends on the `lib-license-go` library version. Consult the upstream documentation to understand precedence rules. It is recommended to set only one mode to avoid ambiguity.

#### 2.3: Verify Secret structure

Confirm the Secrets contain the correct key:

```bash
kubectl get secret -n midaz-plugins fetcher-manager-license -o jsonpath='{.data.license}' | base64 -d | head -c 50
kubectl get secret -n midaz-plugins fetcher-worker-license -o jsonpath='{.data.license}' | base64 -d | head -c 50
```

The output should show the beginning of your signed license file content.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm -n midaz-plugins --version 4.2.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

If you are enabling file mode, include your values override file:

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm -n midaz-plugins --version 4.2.0 -f values-override.yaml
```

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm -n midaz-plugins --version 4.2.0
```

If you are enabling file mode, include your values override file:

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm -n midaz-plugins --version 4.2.0 -f values-override.yaml
```

After the upgrade completes, verify all pods are running:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=fetcher
```

If you enabled file mode, verify the license file is mounted correctly:

```bash
# Check manager pod
kubectl exec -n midaz-plugins -l app.kubernetes.io/component=manager -- ls -la /etc/lerian/license/

# Check worker pod
kubectl exec -n midaz-plugins -l app.kubernetes.io/component=worker -- ls -la /etc/lerian/license/
```

Check manager and worker logs for license validation messages:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/component=manager --tail=50 | grep -i license
kubectl logs -n midaz-plugins -l app.kubernetes.io/component=worker --tail=50 | grep -i license
```
