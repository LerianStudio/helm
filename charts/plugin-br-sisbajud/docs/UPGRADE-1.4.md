<!-- {% raw %} -->
# Helm Upgrade from v1.3.1 to v1.4.0

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.3.1** to **1.4.0**. This is a minor release that introduces support for signed license files as an alternative to the `LICENSE_KEY` environment variable.

## Table of Contents

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Signed License File Support](#1-signed-license-file-support)
- **[Configuration Reference](#configuration-reference)**
  - [License File Configuration](#license-file-configuration)
  - [New Environment Variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
  - [Option 1: Continue Using LICENSE_KEY](#option-1-continue-using-license_key)
  - [Option 2: Migrate to Signed License File](#option-2-migrate-to-signed-license-file)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.4.0 introduces an alternative licensing mechanism using signed license files. This release maintains full backward compatibility with the existing `LICENSE_KEY` environment variable approach.

**What changed:**

| Component | Change |
|-----------|--------|
| `values.yaml` | Added `sisbajud.licenseFile.existingSecret` configuration |
| `templates/_env.tpl` | Added `LICENSE_FILE_PATH` environment variable when license file is configured |
| `templates/_helpers.tpl` | Added helper templates for license file mounting and validation |
| `templates/_migrations.tpl` | Added license file support for migration jobs |
| `templates/_validate.tpl` | Updated validation to accept either `LICENSE_KEY` or `licenseFile.existingSecret` |
| `templates/deployment.yaml` | Added license file volume mount to main container |
| `templates/migrations/job.yaml` | Added license file volume to migration job |
| `templates/migrations/license-secret.yaml` | New: PreSync hook Secret for migration job license key |

**Migration impact:**

- **No action required** if you continue using `LICENSE_KEY`
- **Optional migration** to signed license files for enhanced security
- All existing `values.yaml` configurations remain valid

> **Important:** This feature requires the application image to be built with `lib-license-go` v5 or later. Verify your image version supports license files before migrating.

## Features

### 1. Signed License File Support

The chart now supports mounting a signed license file as an alternative to the `LICENSE_KEY` environment variable. This approach offers enhanced security by:

- Storing the license as a file instead of an environment variable
- Supporting automatic rotation when the Secret is updated (no pod restart required)
- Enabling centralized license management via external secret operators

**How it works:**

1. You create a Kubernetes Secret containing the signed license file under the key `license`
2. The chart mounts this Secret as a directory at `/etc/lerian/license`
3. The application reads the license from `/etc/lerian/license/license` via the `LICENSE_FILE_PATH` environment variable

**Key characteristics:**

- **Mutually exclusive with LICENSE_KEY**: You must provide either `LICENSE_KEY` or `licenseFile.existingSecret`, not both
- **Directory mount (not subPath)**: The Secret is mounted as a directory to enable automatic rotation without pod restarts
- **Read-only mount**: The license file is mounted with `readOnly: true`
- **Migration job support**: The license file is automatically mounted to migration jobs and init containers

**Validation behavior:**

The chart validation now accepts either licensing method:

**Before (v1.3.1):**

```yaml
# Validation required LICENSE_KEY in every environment
{{- if not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" "LICENSE_KEY")) -}}
{{- include $f (dict "msg" "LICENSE_KEY is required in every environment (the app has no unlicensed mode)." "set" "sisbajud.secrets.LICENSE_KEY (or sisbajud.useExistingSecret)") -}}
{{- end -}}
```

**After (v1.4.0):**

```yaml
# Validation accepts either LICENSE_KEY or licenseFile.existingSecret
{{- if not (or (include "plugin-br-sisbajud.provided" (dict "context" $ "key" "LICENSE_KEY")) (include "plugin-br-sisbajud.licenseSecret" $)) -}}
{{- include $f (dict "msg" "LICENSE_KEY is required in every environment (the app has no unlicensed mode)." "set" "sisbajud.secrets.LICENSE_KEY (or sisbajud.useExistingSecret), or sisbajud.licenseFile.existingSecret") -}}
{{- end -}}
```

## Configuration Reference

### License File Configuration

**New values.yaml field:**

| Setting | v1.3.1 | v1.4.0 |
|---------|--------|--------|
| `sisbajud.licenseFile.existingSecret` | Not available | `""` (empty string, optional) |

**Configuration example:**

```yaml
sisbajud:
  # Option 1: Traditional LICENSE_KEY (existing behavior)
  secrets:
    LICENSE_KEY: "your-license-key-here"
  
  # Option 2: Signed license file (new in v1.4.0)
  licenseFile:
    existingSecret: "sisbajud-license-file"
```

**Creating the license file Secret:**

```bash
kubectl create secret generic sisbajud-license-file \
  --from-file=license=/path/to/your/license.lic \
  -n sisbajud
```

> **Note:** The Secret must contain a key named `license` with the signed license file content. The chart will mount this file at `/etc/lerian/license/license`.

### New Environment Variables

The following environment variable is added when `sisbajud.licenseFile.existingSecret` is configured:

| Variable | Source | Description |
|----------|--------|-------------|
| `LICENSE_FILE_PATH` | `sisbajud.licenseFile.existingSecret` | Path to the mounted license file (`/etc/lerian/license/license`) |

**Environment variable behavior:**

```yaml
# When licenseFile.existingSecret is set
LICENSE_FILE_PATH: "/etc/lerian/license/license"

# When licenseFile.existingSecret is NOT set (traditional mode)
LICENSE_KEY: "value-from-secrets-or-extraEnvVars"
```

> **Important:** The application will use `LICENSE_FILE_PATH` if set, otherwise it will fall back to `LICENSE_KEY`. Do not set both in the same deployment.

### Volume Mount Configuration

**Deployment volume mount (added automatically when license file is configured):**

```yaml
volumeMounts:
  - name: license-file
    mountPath: /etc/lerian/license
    readOnly: true

volumes:
  - name: license-file
    secret:
      secretName: sisbajud-license-file
      items:
        - key: license
          path: license
```

**Migration job volume mount (added automatically when license file is configured):**

```yaml
# templates/migrations/job.yaml
volumes:
  - name: license-file
    secret:
      secretName: sisbajud-license-file
      items:
        - key: license
          path: license
```

### Migration Job License Handling

The chart introduces a new PreSync hook Secret (`templates/migrations/license-secret.yaml`) to handle license keys for migration jobs that run before the main application Secret exists.

**When the hook Secret is created:**

- `sisbajud.enabled: true`
- `LICENSE_KEY` is provided via `sisbajud.secrets.LICENSE_KEY` or `sisbajud.extraEnvVars.LICENSE_KEY`
- `sisbajud.useExistingSecret: false` (chart manages the Secret)
- Migrations are enabled and not using bundled PostgreSQL

**Hook Secret annotations:**

```yaml
annotations:
  helm.sh/hook: pre-install,pre-upgrade
  helm.sh/hook-weight: "-10"
  helm.sh/hook-delete-policy: before-hook-creation
  argocd.argoproj.io/hook: PreSync
  argocd.argoproj.io/sync-wave: "-10"
  argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

> **Note:** This hook Secret is only created when using `LICENSE_KEY`. When using `licenseFile.existingSecret`, the migration job mounts the same license file Secret directly.

## Migration Steps

### Option 1: Continue Using LICENSE_KEY

No action is required. Your existing configuration will continue to work without changes.

**Existing configuration (remains valid):**

```yaml
sisbajud:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

**Or with external Secret:**

```yaml
sisbajud:
  useExistingSecret: true
  existingSecretName: "sisbajud-secrets"
```

### Option 2: Migrate to Signed License File

Follow these steps to migrate from `LICENSE_KEY` to a signed license file:

#### Step 1: Obtain the signed license file

Contact Lerian Studio support to obtain a signed license file (`.lic` format) for your organization.

#### Step 2: Create the license file Secret

```bash
kubectl create secret generic sisbajud-license-file \
  --from-file=license=/path/to/your/license.lic \
  -n sisbajud
```

#### Step 3: Update your values.yaml

**Before (v1.3.1):**

```yaml
sisbajud:
  secrets:
    LICENSE_KEY: "your-license-key-here"
    POSTGRES_PASSWORD: "postgres-password"
    REDIS_PASSWORD: "redis-password"
    MENSAGERIA_CLIENT_ID: "client-id"
    MENSAGERIA_CLIENT_SECRET: "client-secret"
    EXECUTOR_HUB_WEBHOOK_SECRET: "webhook-secret"
```

**After (v1.4.0):**

```yaml
sisbajud:
  # Remove LICENSE_KEY from secrets
  secrets:
    POSTGRES_PASSWORD: "postgres-password"
    REDIS_PASSWORD: "redis-password"
    MENSAGERIA_CLIENT_ID: "client-id"
    MENSAGERIA_CLIENT_SECRET: "client-secret"
    EXECUTOR_HUB_WEBHOOK_SECRET: "webhook-secret"
  
  # Add license file configuration
  licenseFile:
    existingSecret: "sisbajud-license-file"
```

#### Step 4: Verify image compatibility

Ensure your application image is built with `lib-license-go` v5 or later:

```bash
kubectl get deployment plugin-br-sisbajud -n sisbajud -o jsonpath='{.spec.template.spec.containers[0].image}'
```

> **Warning:** If your image does not support license files, the application will fail to start with an error about missing `LICENSE_KEY`. Upgrade your application image before migrating to license files.

#### Step 5: Apply the upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  -n sisbajud \
  --version 1.4.0 \
  -f values.yaml
```

#### Step 6: Verify the license file is mounted

```bash
kubectl exec -n sisbajud deployment/plugin-br-sisbajud -- ls -la /etc/lerian/license/
```

Expected output:

```
total 0
drwxrwxrwt 3 root  root   100 Jan 15 10:00 .
drwxr-xr-x 3 root  root    60 Jan 15 10:00 ..
drwxr-xr-x 2 root  root    80 Jan 15 10:00 ..2024_01_15_10_00_00.123456789
lrwxrwxrwx 1 root  root    32 Jan 15 10:00 ..data -> ..2024_01_15_10_00_00.123456789
lrwxrwxrwx 1 root  root    14 Jan 15 10:00 license -> ..data/license
```

#### Step 7: Verify the application started successfully

```bash
kubectl logs -n sisbajud deployment/plugin-br-sisbajud --tail=50
```

Look for log entries indicating successful license validation.

### Rollback Procedure

If you encounter issues with the license file approach, you can roll back to `LICENSE_KEY`:

#### Step 1: Restore LICENSE_KEY in values.yaml

```yaml
sisbajud:
  secrets:
    LICENSE_KEY: "your-license-key-here"
  
  # Remove or comment out license file configuration
  # licenseFile:
  #   existingSecret: "sisbajud-license-file"
```

#### Step 2: Apply the configuration

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  -n sisbajud \
  --version 1.4.0 \
  -f values.yaml
```

> **Note:** You can keep the license file Secret in the cluster even when using `LICENSE_KEY`. The chart will ignore it if `licenseFile.existingSecret` is not set.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.4.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.4.0
```
<!-- {% endraw %} -->
