<!-- {% raw %} -->
# Helm Upgrade from v11.1.2 to v11.2.0

# Topics

- **[Features](#features)**
  - [1. License File Support for Auth and Identity](#1-license-file-support-for-auth-and-identity)
- **[Configuration Reference](#configuration-reference)**
  - [Auth Service License File](#auth-service-license-file)
  - [Identity Service License File](#identity-service-license-file)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. License File Support for Auth and Identity

This release introduces an alternative licensing mechanism for both the auth and identity services. Instead of providing the license as an environment variable (`LICENSE_KEY`), you can now mount a signed license file from an existing Kubernetes Secret.

**What changed:**

New configuration fields have been added to both services:

```yaml
auth:
  licenseFile:
    existingSecret: ""

identity:
  licenseFile:
    existingSecret: ""
```

**Why this matters:**

File-based licensing provides several operational advantages:

- **Separation of concerns**: License files can be managed independently from application configuration
- **Rotation flexibility**: Update licenses by replacing the Secret without modifying Helm values
- **Security**: Some organizations prefer file-based credentials over environment variables for audit and compliance reasons
- **Future compatibility**: File mode requires an image built with `lib-license-go v5`, preparing for upcoming licensing infrastructure changes

**How it works:**

When `auth.licenseFile.existingSecret` or `identity.licenseFile.existingSecret` is set:

1. The chart mounts the specified Secret as a directory at `/etc/lerian/license`
2. The Secret must contain a key named `license` with the signed license file content
3. The environment variable `LICENSE_FILE_PATH` is automatically set to `/etc/lerian/license/license`
4. The `LICENSE_KEY` environment variable becomes **optional** (not required) when using file-based licensing

**Default behavior:**

Both `existingSecret` fields default to empty strings (`""`), which means:

- The chart continues to use the existing `LICENSE_KEY` environment variable approach
- `LICENSE_KEY` remains **required** in `auth.secrets.LICENSE_KEY` and `identity.secrets.LICENSE_KEY`
- No file mounting occurs
- **This is a fully backward-compatible, opt-in feature**

**Before (v11.1.2):**

```yaml
# auth/secrets.yaml
data:
  LICENSE_KEY: {{ required "auth.secrets.LICENSE_KEY is required: auth refuses to boot without a license. Set it, or use auth.useExistingSecret with a Secret that carries LICENSE_KEY." .Values.auth.secrets.LICENSE_KEY | b64enc | quote }}
```

```yaml
# auth/deployment.yaml - no license file volume or mount
spec:
  template:
    spec:
      containers:
        - name: auth
          env:
            {{- toYaml $h.env | nindent 12 }}
```

**After (v11.2.0):**

```yaml
# auth/secrets.yaml - LICENSE_KEY now optional when using file-based licensing
data:
  {{- if include "plugin-access-manager.licenseFileSecret" .Values.auth }}
  {{- with .Values.auth.secrets.LICENSE_KEY }}
  LICENSE_KEY: {{ . | b64enc | quote }}
  {{- end }}
  {{- else }}
  LICENSE_KEY: {{ required "auth.secrets.LICENSE_KEY is required: auth refuses to boot without a license. Set it, or use auth.useExistingSecret with a Secret that carries LICENSE_KEY." .Values.auth.secrets.LICENSE_KEY | b64enc | quote }}
  {{- end }}
```

```yaml
# auth/deployment.yaml - new license file volume and mount when configured
spec:
  template:
    spec:
      containers:
        - name: auth
          env:
            {{- toYaml $h.env | nindent 12 }}
            {{- with (include "plugin-access-manager.licenseFileEnv" .Values.auth | trim) }}{{ . | nindent 12 }}{{ end }}
          {{- with (include "plugin-access-manager.licenseFileMount" .Values.auth | trim) }}
          volumeMounts:
            {{- . | nindent 12 }}
          {{- end }}
      {{- with (include "plugin-access-manager.licenseFileVolume" .Values.auth | trim) }}
      volumes:
        {{- . | nindent 8 }}
      {{- end }}
```

The same pattern applies to the identity service (`identity/secrets.yaml` and `identity/deployment.yaml`).

**Template helpers added:**

Four new template helpers were added to `_helpers.tpl` to support license file mounting:

- `plugin-access-manager.licenseFileSecret`: Returns the Secret name if configured
- `plugin-access-manager.licenseFileEnv`: Injects `LICENSE_FILE_PATH` environment variable
- `plugin-access-manager.licenseFileMount`: Defines the volume mount at `/etc/lerian/license`
- `plugin-access-manager.licenseFileVolume`: Defines the Secret volume with the `license` key

> **Important:** File-based licensing requires an application image built with `lib-license-go v5` or later. Verify your image version supports file-based licensing before enabling this feature. The chart does not validate image compatibility.

# Configuration Reference

### Auth Service License File

Configure file-based licensing for the auth service in your `values.yaml`:

```yaml
auth:
  licenseFile:
    existingSecret: "auth-license-file"
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `auth.licenseFile.existingSecret` | `""` | Name of an existing Kubernetes Secret containing the signed license file. The Secret must have a key named `license`. When set, `LICENSE_KEY` becomes optional. |

**Example: Creating the license Secret**

```bash
kubectl create secret generic auth-license-file \
  --from-file=license=/path/to/your/license.lic \
  -n midaz-plugins
```

**Example: Using file-based licensing**

```yaml
auth:
  licenseFile:
    existingSecret: "auth-license-file"
  secrets:
    # LICENSE_KEY is now optional when licenseFile.existingSecret is set
    # LICENSE_KEY: ""  # can be omitted or left empty
    ORGANIZATION_IDS: "org-123"
    MFA_SECRET: "mfa-secret-value"
```

**Example: Keeping environment variable licensing**

```yaml
auth:
  licenseFile:
    existingSecret: ""  # default, can be omitted
  secrets:
    LICENSE_KEY: "your-base64-encoded-license-key"
    ORGANIZATION_IDS: "org-123"
```

### Identity Service License File

Configure file-based licensing for the identity service in your `values.yaml`:

```yaml
identity:
  licenseFile:
    existingSecret: "identity-license-file"
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `identity.licenseFile.existingSecret` | `""` | Name of an existing Kubernetes Secret containing the signed license file. The Secret must have a key named `license`. When set, `LICENSE_KEY` becomes optional. |

**Example: Creating the license Secret**

```bash
kubectl create secret generic identity-license-file \
  --from-file=license=/path/to/your/license.lic \
  -n midaz-plugins
```

**Example: Using file-based licensing**

```yaml
identity:
  licenseFile:
    existingSecret: "identity-license-file"
  secrets:
    # LICENSE_KEY is now optional when licenseFile.existingSecret is set
    # LICENSE_KEY: ""  # can be omitted or left empty
    ORGANIZATION_IDS: "org-123"
```

**Example: Keeping environment variable licensing**

```yaml
identity:
  licenseFile:
    existingSecret: ""  # default, can be omitted
  secrets:
    LICENSE_KEY: "your-base64-encoded-license-key"
    ORGANIZATION_IDS: "org-123"
```

> **Note:** The auth and identity services can use different licensing methods independently. For example, auth can use file-based licensing while identity continues using `LICENSE_KEY`, or vice versa.

> **Warning:** When using `licenseFile.existingSecret`, ensure the Secret exists in the same namespace as the Helm release **before** upgrading. The chart does not create this Secret — you must provision it separately.

# Migration Steps

This is an **optional, opt-in feature**. No action is required to upgrade from v11.1.2 to v11.2.0 if you want to continue using environment variable-based licensing.

**Step 1: Determine your licensing approach**

Choose one of the following options for each service (auth and identity):

#### Option 1: Keep existing environment variable licensing (no action required)

If you are satisfied with the current `LICENSE_KEY` environment variable approach, no changes are needed. Your existing configuration will continue to work exactly as before.

```yaml
# Your existing values.yaml - no changes needed
auth:
  secrets:
    LICENSE_KEY: "your-existing-license-key"

identity:
  secrets:
    LICENSE_KEY: "your-existing-license-key"
```

#### Option 2: Migrate to file-based licensing

If you want to adopt file-based licensing, follow these steps for each service:

**Step 2a: Verify image compatibility**

Confirm that your auth and identity images are built with `lib-license-go v5` or later. Check your current image versions:

```bash
helm get values plugin-access-manager -n midaz-plugins | grep -A 3 "image:"
```

Consult your image documentation or release notes to verify `lib-license-go` version compatibility.

**Step 2b: Prepare the license file Secret**

Create a Kubernetes Secret containing your signed license file. The Secret must have a key named `license`:

```bash
# For auth service
kubectl create secret generic auth-license-file \
  --from-file=license=/path/to/auth-license.lic \
  -n midaz-plugins

# For identity service
kubectl create secret generic identity-license-file \
  --from-file=license=/path/to/identity-license.lic \
  -n midaz-plugins
```

**Step 2c: Update your values.yaml**

Add the `licenseFile.existingSecret` configuration and optionally remove or empty the `LICENSE_KEY` field:

```yaml
auth:
  licenseFile:
    existingSecret: "auth-license-file"
  secrets:
    # LICENSE_KEY can now be omitted or left empty
    ORGANIZATION_IDS: "org-123"
    MFA_SECRET: "mfa-secret-value"

identity:
  licenseFile:
    existingSecret: "identity-license-file"
  secrets:
    # LICENSE_KEY can now be omitted or left empty
    ORGANIZATION_IDS: "org-123"
```

**Step 2d: Validate your configuration locally**

Test your configuration with a dry-run before upgrading:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 11.2.0 \
  -n midaz-plugins \
  --dry-run \
  --debug
```

Verify that:

- The `LICENSE_FILE_PATH` environment variable is set to `/etc/lerian/license/license`
- The volume mount appears at `/etc/lerian/license`
- The Secret volume references your `existingSecret` name

**Step 2e: Proceed with the upgrade**

Once validation passes, proceed with the upgrade using the command in the [Command to upgrade](#command-to-upgrade) section.

> **Important:** If you use `auth.useExistingSecret` or `identity.useExistingSecret` to provide secrets from an external Secret (instead of the chart-managed Secret), ensure your external Secret includes `LICENSE_KEY` **or** configure `licenseFile.existingSecret`. The chart cannot validate the contents of external Secrets.

> **Note:** You can migrate one service at a time. For example, migrate auth to file-based licensing while keeping identity on `LICENSE_KEY`, then migrate identity later in a subsequent upgrade.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.0
```
<!-- {% endraw %} -->
