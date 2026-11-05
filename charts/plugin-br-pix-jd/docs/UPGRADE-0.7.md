<!-- {% raw %} -->
# Helm Upgrade from v0.6.3 to v0.7.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. License File Support](#1-license-file-support)
  - [2. Relaxed License Key Requirement](#2-relaxed-license-key-requirement)
- **[Configuration Reference](#configuration-reference)**
  - [API License File Configuration](#api-license-file-configuration)
  - [Worker License File Configuration](#worker-license-file-configuration)
- **[Migration Steps](#migration-steps)**
  - [Option 1: Continue Using LICENSE_KEY (No Action Required)](#option-1-continue-using-license_key-no-action-required)
  - [Option 2: Migrate to License File](#option-2-migrate-to-license-file)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **minor version bump** introducing support for file-based license validation as an alternative to the existing `LICENSE_KEY` environment variable. The chart now allows operators to mount a signed license file from an external Secret, which will be preferred over the environment variable when both are present.

| Setting | v0.6.3 | v0.7.0 |
|---------|--------|--------|
| Chart Version | 0.6.3 | 0.7.0 |
| App Version | 1.6.1 | 1.6.1 (unchanged) |
| License validation methods | `LICENSE_KEY` only | `LICENSE_KEY` or license file |
| License key requirement | Always required | Required unless `licenseFile.existingSecret` is set |

## Features

### 1. License File Support

The chart now supports mounting a signed license file from an external Secret as an alternative to the `LICENSE_KEY` environment variable. This enables license validation via cryptographically signed files instead of plain-text keys.

**How it works:**

- The operator creates a Secret containing a signed license file under the key `license`
- The chart mounts this Secret as a volume at `/etc/lerian/license/` in both API and worker pods
- The application reads the license from `/etc/lerian/license/license` via the `LICENSE_FILE_PATH` environment variable
- If both `LICENSE_KEY` and a license file are present, the file takes precedence

**Key characteristics:**

| Aspect | Behavior |
|--------|----------|
| Mount path | `/etc/lerian/license/` (directory, not subPath) |
| Secret key | `license` (must match exactly) |
| Environment variable | `LICENSE_FILE_PATH=/etc/lerian/license/license` |
| Compatibility | Requires application image built with lib-license-go v5+ for file mode support |
| Precedence | License file overrides `LICENSE_KEY` when both are set |

**Template changes:**

The chart adds conditional volume mounts and environment variables to both API and worker Deployments when `licenseFile.existingSecret` is set.

**Before (v0.6.3):**

```yaml
# No license file support
env:
  - name: LICENSE_KEY
    valueFrom:
      secretKeyRef:
        name: plugin-br-pix-jd-api
        key: LICENSE_KEY
```

**After (v0.7.0):**

```yaml
env:
  - name: LICENSE_KEY
    valueFrom:
      secretKeyRef:
        name: plugin-br-pix-jd-api
        key: LICENSE_KEY
  # Added when api.licenseFile.existingSecret is set:
  - name: LICENSE_FILE_PATH
    value: /etc/lerian/license/license

volumeMounts:
  # Added when api.licenseFile.existingSecret is set:
  - name: license-file
    mountPath: /etc/lerian/license
    readOnly: true

volumes:
  # Added when api.licenseFile.existingSecret is set:
  - name: license-file
    secret:
      secretName: plugin-pix-license-file
      items:
        - key: license
          path: license
```

> **Important:** The license file feature requires an application image built with **lib-license-go v5 or later**. Older images will ignore the `LICENSE_FILE_PATH` variable and fall back to `LICENSE_KEY`. Check your image version before migrating.

> **Note:** The license file is mounted as a **directory**, not a subPath. This ensures atomic updates when the Secret is rotated — Kubernetes replaces the entire mount point, avoiding stale file handles.

### 2. Relaxed License Key Requirement

The `LICENSE_KEY` secret field is no longer unconditionally required. The chart now allows operators to omit it when using a license file instead.

**Validation logic changes:**

| Scenario | v0.6.3 | v0.7.0 |
|----------|--------|--------|
| `LICENSE_KEY` set, no license file | Valid | Valid |
| `LICENSE_KEY` empty, no license file | **Render fails** | **Render fails** |
| `LICENSE_KEY` empty, license file set | **Render fails** | Valid |
| Both `LICENSE_KEY` and license file set | Valid | Valid (file takes precedence) |

**Before (v0.6.3):**

```yaml
# api/secrets.yaml
data:
  LICENSE_KEY: {{ required "\n\nERROR: api.secrets.LICENSE_KEY is required.\nThe api and the worker validate the license at boot in every mode and do not start\nwithout it.\n" ((.Values.api.secrets | default dict).LICENSE_KEY | default "") | b64enc | quote }}
```

**After (v0.7.0):**

```yaml
# api/secrets.yaml
{{- $licenseFile := include "plugin-br-pix-jd.licenseFileSecret" .Values.api }}
{{- $licenseKey := (.Values.api.secrets | default dict).LICENSE_KEY | default "" }}
data:
  {{- if or $licenseKey (not $licenseFile) }}
  LICENSE_KEY: {{ required "\n\nERROR: api.secrets.LICENSE_KEY is required unless api.licenseFile.existingSecret is set.\nThe api validates the license at boot and does not start without one.\n" $licenseKey | b64enc | quote }}
  {{- end }}
```

The same logic applies to the worker Secret (`worker/secrets.yaml`), with the worker's license file falling back to the API's `LICENSE_KEY` if neither `worker.secrets.LICENSE_KEY` nor `worker.licenseFile.existingSecret` is set.

> **Warning:** If you set `api.licenseFile.existingSecret` but the referenced Secret does not exist or lacks the `license` key, pods will fail to start with a mount error. Always verify the Secret exists before upgrading:
> ```bash
> kubectl -n midaz-plugins get secret plugin-pix-license-file -o jsonpath='{.data.license}' | base64 -d | head -c 50
> ```

## Configuration Reference

### API License File Configuration

```yaml
api:
  # Existing license key configuration (unchanged)
  secrets:
    LICENSE_KEY: ""  # Now optional if licenseFile.existingSecret is set
  
  # New: license file configuration
  licenseFile:
    # -- Secret holding a signed licence file under the key `license`, mounted at
    # /etc/lerian/license; replaces LICENSE_KEY. File mode needs an image on lib-license-go v5.
    existingSecret: ""
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `api.licenseFile.existingSecret` | string | `""` | Name of a pre-existing Secret containing a signed license file under the key `license` |

**Example Secret structure:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: plugin-pix-license-file
  namespace: midaz-plugins
type: Opaque
data:
  license: <base64-encoded-signed-license-file>
```

### Worker License File Configuration

```yaml
worker:
  # Existing license key configuration (unchanged)
  secrets:
    LICENSE_KEY: ""  # Falls back to api.secrets.LICENSE_KEY; optional if licenseFile.existingSecret is set
  
  # New: license file configuration
  licenseFile:
    # -- Same as api.licenseFile.existingSecret, for the worker.
    existingSecret: ""
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `worker.licenseFile.existingSecret` | string | `""` | Name of a pre-existing Secret containing a signed license file for the worker; if empty, falls back to `api.licenseFile.existingSecret` |

> **Note:** The worker's license file configuration is independent of the API's. You can use the same Secret for both components or provision separate Secrets if your license model requires per-component files.

## Migration Steps

### Option 1: Continue Using LICENSE_KEY (No Action Required)

If you are satisfied with the existing `LICENSE_KEY` environment variable approach, **no changes are required**. The chart remains fully backward-compatible with v0.6.3 configurations.

Your existing values will continue to work:

```yaml
api:
  secrets:
    LICENSE_KEY: "your-existing-license-key"

worker:
  enabled: true
  secrets:
    LICENSE_KEY: ""  # Falls back to api.secrets.LICENSE_KEY
```

Simply upgrade the chart version:

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.7.0
```

### Option 2: Migrate to License File

If you want to adopt file-based license validation, follow these steps:

#### Step 1: Verify Application Image Compatibility

Ensure your application image is built with **lib-license-go v5 or later**. Check the image metadata or release notes for your `appVersion`.

> **Warning:** Images built with lib-license-go v4 or earlier will ignore `LICENSE_FILE_PATH` and fall back to `LICENSE_KEY`. If you remove `LICENSE_KEY` without upgrading the image, pods will fail to start.

#### Step 2: Create the License File Secret

Obtain your signed license file from Lerian Studio and create a Secret containing it:

```bash
kubectl -n midaz-plugins create secret generic plugin-pix-license-file \
  --from-file=license=/path/to/your/signed-license-file.lic
```

Verify the Secret was created correctly:

```bash
kubectl -n midaz-plugins get secret plugin-pix-license-file -o jsonpath='{.data.license}' | base64 -d | head -c 100
```

#### Step 3: Update values.yaml

Add the `licenseFile.existingSecret` field to your API and worker configurations:

```yaml
api:
  secrets:
    LICENSE_KEY: ""  # Can be removed or left empty
  
  licenseFile:
    existingSecret: plugin-pix-license-file

worker:
  enabled: true
  secrets:
    LICENSE_KEY: ""  # Can be removed or left empty
  
  licenseFile:
    existingSecret: plugin-pix-license-file
```

> **Note:** If you set `api.licenseFile.existingSecret`, you can safely remove `api.secrets.LICENSE_KEY` from your values file. The chart will not render the `LICENSE_KEY` field in the Secret when a license file is configured.

#### Step 4: Upgrade the Chart

Apply the updated configuration:

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm \
  -n midaz-plugins \
  --version 0.7.0 \
  -f values.yaml
```

#### Step 5: Verify License File Mount

Check that the license file is mounted correctly in a running pod:

```bash
kubectl -n midaz-plugins exec -it deployment/plugin-br-pix-jd-api -- ls -la /etc/lerian/license/
```

Expected output:

```
total 0
drwxrwxrwt 3 root root  100 Jan 15 10:30 .
drwxr-xr-x 1 root root 4096 Jan 15 10:30 ..
drwxr-xr-x 2 root root   60 Jan 15 10:30 ..2024_01_15_10_30_00.123456789
lrwxrwxrwx 1 root root   31 Jan 15 10:30 ..data -> ..2024_01_15_10_30_00.123456789
lrwxrwxrwx 1 root root   14 Jan 15 10:30 license -> ..data/license
```

Verify the application is reading the file:

```bash
kubectl -n midaz-plugins logs deployment/plugin-br-pix-jd-api | grep -i license
```

Expected log output:

```
INFO  license validation: reading from file path=/etc/lerian/license/license
INFO  license validation: signature verified issuer=Lerian Studio
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.7.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.7.0
```
<!-- {% endraw %} -->
