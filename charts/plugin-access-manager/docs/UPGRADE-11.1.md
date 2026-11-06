<!-- {% raw %} -->
# Helm Upgrade from v11.0.1 to v11.1.0

# Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Signed License File Support for Caradhras](#1-signed-license-file-support-for-caradhras)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a minor release that increments the chart version from 11.0.1 to 11.1.0. The application version remains unchanged at `3.17.0`.

**What changed:**

- Added support for mounting a signed license file as an alternative to the `LICENSE_KEY` environment variable for Caradhras
- Updated documentation comments for license configuration options
- Added new template helpers for license file mounting

**What this means for operators:**

This release introduces a new optional configuration method for Caradhras licensing. Operators can now choose between:

1. **Environment variable** (existing): `caradhras.secrets.LICENSE_KEY` or `caradhras.useExistingSecret`
2. **License file** (new): `caradhras.licenseFile.existingSecret`

Both methods remain fully supported. If you are already using `LICENSE_KEY`, no changes are required. The upgrade is backward compatible.

| Component | v11.0.1 | v11.1.0 |
|-----------|---------|---------|
| Chart version | 11.0.1 | 11.1.0 |
| App version | 3.17.0 | 3.17.0 |
| Caradhras image | *(unchanged)* | *(unchanged)* |
| Auth image | *(unchanged)* | *(unchanged)* |
| Identity image | *(unchanged)* | *(unchanged)* |

# Features

### 1. Signed License File Support for Caradhras

**What changed:**

Caradhras can now read its license from a signed file mounted at `/etc/lerian/license/license` instead of requiring the `LICENSE_KEY` environment variable. This feature is controlled by the new `caradhras.licenseFile.existingSecret` value.

The chart mounts the license file on both the Caradhras server container and the `migrate` init container. The migrator is license-gated and, on a fresh install, is the first process to fetch the license file.

**New values.yaml fields:**

```yaml
caradhras:
  # -- Existing Secret with the signed licence file (key `license`), mounted as a directory at
  # /etc/lerian/license on the server and its `migrate` init container; replaces LICENSE_KEY.
  # File mode needs an image on lib-license-go v5.
  licenseFile:
    existingSecret: ""
```

**Before (v11.0.1):**

Caradhras required one of these configurations:

```yaml
caradhras:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

Or:

```yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "caradhras-license"
```

**After (v11.1.0):**

All previous configurations remain valid. You can now also use:

```yaml
caradhras:
  licenseFile:
    existingSecret: "caradhras-license-file"
```

**Template changes:**

The deployment template now includes new helper functions that conditionally mount the license file and set the `LICENSE_FILE_PATH` environment variable:

**Before (v11.0.1):**

```yaml
# templates/caradhras/deployment.yaml
{{- if $licensed }}
- name: LICENSE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "plugin-caradhras.secretName" . }}
      key: LICENSE_KEY
      optional: true
{{- end }}
```

**After (v11.1.0):**

```yaml
# templates/caradhras/deployment.yaml
{{- with (include "plugin-caradhras.licenseEnv" (dict "context" $ "licensed" $licensed) | trim) }}{{ . | nindent 10 }}{{ end }}
```

The helper template `plugin-caradhras.licenseEnv` now generates both the `LICENSE_KEY` environment variable (if configured) and the `LICENSE_FILE_PATH` environment variable (if `licenseFile.existingSecret` is set):

```yaml
# When licenseFile.existingSecret is set, the template adds:
- name: LICENSE_FILE_PATH
  value: /etc/lerian/license/license
```

The license file is mounted as a volume:

```yaml
# templates/caradhras/deployment.yaml
volumes:
  - name: license-file
    secret:
      secretName: "caradhras-license-file"
      items:
        - key: license
          path: license

# In both the server container and migrate init container:
volumeMounts:
  - name: license-file
    mountPath: /etc/lerian/license
    readOnly: true
```

**Why this matters:**

Some operators prefer to manage licenses as files rather than environment variables for:

- **Security:** File-based secrets can be managed with stricter file permissions and access controls
- **Rotation:** Easier to rotate signed license files without redeploying pods (when using projected volumes or CSI drivers)
- **Compliance:** Some environments require cryptographically signed artifacts for audit trails
- **Compatibility:** Future Caradhras versions on lib-license-go v5 will support file mode restrictions

The license file method is particularly useful when integrating with external secret management systems (Vault, AWS Secrets Manager, etc.) that can mount signed files directly.

**Operational impact:**

- **No action required:** If you are using `LICENSE_KEY` or `useExistingSecret`, your configuration continues to work unchanged
- **No pod restarts:** The upgrade does not change the pod template for existing configurations (the license mounting logic is conditional)
- **Validation:** The chart still validates that at least one license method is configured for Caradhras 2.x images

**Updated validation:**

The chart's license validation now accepts three methods:

```yaml
# templates/caradhras/deployment.yaml
{{- if not (or $licensed $licenseFile (and (regexMatch "^v?[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$" $tag) (semverCompare "<2.0.0-0" $tag))) }}
{{- fail "\n\nERROR: Caradhras refuses to boot without its own license key.\n   Set caradhras.secrets.LICENSE_KEY, set caradhras.useExistingSecret=true with caradhras.existingSecretName naming a Secret that holds LICENSE_KEY, or mount a signed licence file with caradhras.licenseFile.existingSecret.\n   The key is issued for the product `caradhras`; the auth and identity key does not license it.\n" }}
{{- end }}
```

**When to use the license file method:**

#### Option 1: Keep existing LICENSE_KEY configuration

If your current setup works and you have no specific requirement for file-based licensing, keep your existing configuration:

```yaml
caradhras:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

No changes are needed during the upgrade.

#### Option 2: Migrate to license file

If you want to use a signed license file, follow these steps:

**Step 1:** Create a Secret containing your signed license file:

```bash
kubectl create secret generic caradhras-license-file \
  --from-file=license=/path/to/your/signed-license-file \
  -n midaz-plugins
```

> **Important:** The Secret must contain a key named `license`. The chart mounts this key at `/etc/lerian/license/license`.

**Step 2:** Update your values.yaml:

```yaml
caradhras:
  # Remove or comment out the LICENSE_KEY
  # secrets:
  #   LICENSE_KEY: ""
  
  # Add the license file configuration
  licenseFile:
    existingSecret: "caradhras-license-file"
```

**Step 3:** Upgrade the chart:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 11.1.0 \
  -n midaz-plugins \
  -f values.yaml
```

> **Note:** You can use both `LICENSE_KEY` and `licenseFile.existingSecret` simultaneously. Caradhras will use whichever method it finds first. However, for clarity, configure only one method.

**Environment variables added:**

| Variable | Set when | Value | Description |
|----------|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `caradhras.licenseFile.existingSecret` is set | `/etc/lerian/license/license` | Path to the mounted signed license file |
| `LICENSE_KEY` | `caradhras.secrets.LICENSE_KEY` or `caradhras.useExistingSecret` is set | *(from Secret)* | License key as environment variable (existing behavior) |

**Volume mounts added:**

When `caradhras.licenseFile.existingSecret` is configured:

| Mount path | Source | Mode |
|------------|--------|------|
| `/etc/lerian/license` | Secret `caradhras.licenseFile.existingSecret`, key `license` | Read-only |

The mount is added to:
- The Caradhras server container
- The `migrate` init container

> **Note:** The license file is mounted as a directory (never as a subPath) to ensure compatibility with Secret rotation mechanisms.

# Configuration Reference

### New values.yaml fields

```yaml
caradhras:
  # -- Existing Secret with the signed licence file (key `license`), mounted as a directory at
  # /etc/lerian/license on the server and its `migrate` init container; replaces LICENSE_KEY.
  # File mode needs an image on lib-license-go v5.
  licenseFile:
    existingSecret: ""
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `caradhras.licenseFile.existingSecret` | string | `""` | Name of an existing Secret containing a signed license file under the key `license`. When set, the chart mounts the file at `/etc/lerian/license/license` and sets `LICENSE_FILE_PATH` environment variable. |

### Updated documentation

The comment for `caradhras.secrets.LICENSE_KEY` has been updated to reflect the new option:

**Before (v11.0.1):**

```yaml
# -- Caradhras license key, injected as env LICENSE_KEY by secretKeyRef.
# Required for Caradhras 2.x (it refuses to boot without it, and the render
# fails without it or useExistingSecret). Issued for product `caradhras`;
# not the auth/identity key.
LICENSE_KEY: ""
```

**After (v11.1.0):**

```yaml
# -- Caradhras license key, injected as env LICENSE_KEY by secretKeyRef.
# Required for Caradhras 2.x (it refuses to boot without it or a licence file, and the
# render fails without it, useExistingSecret or licenseFile.existingSecret). Issued for product `caradhras`;
# not the auth/identity key.
LICENSE_KEY: ""
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.0
```
<!-- {% endraw %} -->
