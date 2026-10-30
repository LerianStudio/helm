<!-- {% raw %} -->
# Helm Upgrade from v9.7.2 to v9.8.0

# Topics

- **[Features](#features)**
  - [1. Google Workspace Directory Integration](#1-google-workspace-directory-integration)
  - [2. Enhanced Startup Validation](#2-enhanced-startup-validation)
- **[Configuration Reference](#configuration-reference)**
  - [Google Workspace Directory Configuration](#google-workspace-directory-configuration)
  - [Environment Variables](#environment-variables)
- **[Migration Guide](#migration-guide)**
  - [Step 1: Review Your Current Configuration](#step-1-review-your-current-configuration)
  - [Step 2: Configure Google Workspace Directory (Optional)](#step-2-configure-google-workspace-directory-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Google Workspace Directory Integration

Version 9.8.0 introduces support for Google Workspace directory integration in the identity component, allowing organizations to connect their Google Workspace accounts for user and group synchronization.

**What changed:**

New configuration fields have been added to `identity.configmap` and `identity.secrets` to support Google Workspace directory connections:

| Setting | v9.7.2 | v9.8.0 |
|---------|--------|--------|
| `identity.configmap.GOOGLE_DIRECTORY_ENABLED` | Not available | `""` (optional) |
| `identity.configmap.GOOGLE_DIRECTORY_CLIENT_ID` | Not available | `""` (optional) |
| `identity.configmap.GOOGLE_DIRECTORY_REDIRECT_URL` | Not available | `""` (optional) |
| `identity.secrets.GOOGLE_DIRECTORY_CLIENT_SECRET` | Not available | `""` (optional) |
| `identity.secrets.GOOGLE_DIRECTORY_ENCRYPTION_KEY` | Not available | `""` (optional) |

**Why this matters:**

Organizations using Google Workspace can now integrate their directory with the plugin-access-manager identity service. When enabled, the identity component can:
- Authenticate users via Google OAuth
- Synchronize user and group information from Google Workspace
- Maintain encrypted refresh tokens for ongoing directory access

**Default behavior:**

Google Workspace directory integration is **disabled by default**. All new configuration keys are optional and only render in the ConfigMap/Secret when explicitly set. Existing installations will see no changes in their rendered manifests.

**Configuration structure:**

```yaml
identity:
  configmap:
    # Google Workspace directory (identity 3.12.0+). Each key is omitted from the
    # ConfigMap unless set. With GOOGLE_DIRECTORY_ENABLED "true", identity needs
    # all four GOOGLE_DIRECTORY_* values (these two plus the two in secrets below)
    # and the chart refuses to render without them.
    # GOOGLE_DIRECTORY_ENABLED: ""       # "true" turns on the Google Workspace directory connection
    # GOOGLE_DIRECTORY_CLIENT_ID: ""     # client id of Lerian's Google OAuth client
    # GOOGLE_DIRECTORY_REDIRECT_URL: ""  # OAuth redirect URL registered on that client; https
  
  secrets:
    # -- Client secret of Lerian's Google OAuth client (Google Workspace
    # directory). Empty = key not rendered.
    GOOGLE_DIRECTORY_CLIENT_SECRET: ""
    # -- Key that encrypts each organization's stored Google refresh token; at
    # least 32 bytes. Empty = key not rendered. Changing it makes the stored
    # tokens unreadable and every connected organization must reconnect.
    GOOGLE_DIRECTORY_ENCRYPTION_KEY: ""
```

**Security considerations:**

- `GOOGLE_DIRECTORY_CLIENT_SECRET` is stored in the identity Secret (base64-encoded)
- `GOOGLE_DIRECTORY_ENCRYPTION_KEY` must be at least 32 bytes and is used to encrypt stored refresh tokens
- Changing the encryption key invalidates all stored tokens, requiring organizations to reconnect
- The redirect URL must use HTTPS for production deployments

**Template changes:**

**Before (v9.7.2):**

```yaml
# templates/identity/configmap.yaml
data:
  # FORGOT PASSWORD (public self-service routes; off unless explicitly "true")
  ENABLE_FORGOT_PASSWORD: {{ .Values.identity.configmap.ENABLE_FORGOT_PASSWORD | default "false" | quote }}

  # RUNTIME
  DEPLOYMENT_MODE: {{ .Values.identity.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**After (v9.8.0):**

```yaml
# templates/identity/configmap.yaml
data:
  # FORGOT PASSWORD (public self-service routes; off unless explicitly "true")
  ENABLE_FORGOT_PASSWORD: {{ .Values.identity.configmap.ENABLE_FORGOT_PASSWORD | default "false" | quote }}
  {{- /* GOOGLE WORKSPACE DIRECTORY (identity 3.12.0+; the application keeps it
     off unless GOOGLE_DIRECTORY_ENABLED is "true"). Each key renders only when
     set, so an install that leaves them empty gets the same ConfigMap as
     before. The client secret and the encryption key are not here: they live
     in identity.secrets (templates/identity/secrets.yaml). */}}
  {{- with $cm.GOOGLE_DIRECTORY_ENABLED }}
  GOOGLE_DIRECTORY_ENABLED: {{ . | quote }}
  {{- end }}
  {{- with $cm.GOOGLE_DIRECTORY_CLIENT_ID }}
  GOOGLE_DIRECTORY_CLIENT_ID: {{ . | quote }}
  {{- end }}
  {{- with $cm.GOOGLE_DIRECTORY_REDIRECT_URL }}
  GOOGLE_DIRECTORY_REDIRECT_URL: {{ . | quote }}
  {{- end }}

  # RUNTIME
  DEPLOYMENT_MODE: {{ .Values.identity.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**Before (v9.7.2):**

```yaml
# templates/identity/secrets.yaml
data:
  # -- Default sensitive variables for the identity
  AUTHORIZER_CLIENT_SECRET: {{ required "identity.secrets.AUTHORIZER_CLIENT_SECRET is required" .Values.identity.secrets.AUTHORIZER_CLIENT_SECRET | b64enc | quote }}
  LICENSE_KEY: {{ .Values.identity.secrets.LICENSE_KEY | b64enc | quote }}
  ORGANIZATION_IDS: {{ .Values.identity.secrets.ORGANIZATION_IDS | b64enc | quote }}
```

**After (v9.8.0):**

```yaml
# templates/identity/secrets.yaml
data:
  # -- Default sensitive variables for the identity
  AUTHORIZER_CLIENT_SECRET: {{ required "identity.secrets.AUTHORIZER_CLIENT_SECRET is required" .Values.identity.secrets.AUTHORIZER_CLIENT_SECRET | b64enc | quote }}
  {{- /* Google Workspace directory (identity 3.12.0+). Each key renders only
     when set, so an install that leaves them empty gets the same Secret as
     before. Identity reads them only with GOOGLE_DIRECTORY_ENABLED=true. */}}
  {{- with .Values.identity.secrets.GOOGLE_DIRECTORY_CLIENT_SECRET }}
  GOOGLE_DIRECTORY_CLIENT_SECRET: {{ . | b64enc | quote }}
  {{- end }}
  {{- with .Values.identity.secrets.GOOGLE_DIRECTORY_ENCRYPTION_KEY }}
  GOOGLE_DIRECTORY_ENCRYPTION_KEY: {{ . | b64enc | quote }}
  {{- end }}
  LICENSE_KEY: {{ .Values.identity.secrets.LICENSE_KEY | b64enc | quote }}
  ORGANIZATION_IDS: {{ .Values.identity.secrets.ORGANIZATION_IDS | b64enc | quote }}
```

**Operational impact:**

- Existing installations will see no changes in rendered manifests (all new keys are optional)
- No pod restarts or configuration changes are required unless you explicitly enable the feature
- The identity component will continue to function exactly as before without any configuration changes

### 2. Enhanced Startup Validation

Version 9.8.0 adds comprehensive validation for Google Workspace directory configuration to prevent misconfiguration and deployment failures.

**What changed:**

A new validation template helper `plugin-access-manager.validateGoogleDirectory` has been added to `templates/_startup-validation.tpl` that enforces configuration requirements when Google Workspace directory is enabled.

**Validation rules:**

When `GOOGLE_DIRECTORY_ENABLED` is set to `"true"` (or any truthy value: `"TRUE"`, `"True"`, `"1"`, `"t"`, `"T"`), the chart validates:

1. **All four required configuration values are set:**
   - `identity.configmap.GOOGLE_DIRECTORY_CLIENT_ID`
   - `identity.configmap.GOOGLE_DIRECTORY_REDIRECT_URL`
   - `identity.secrets.GOOGLE_DIRECTORY_CLIENT_SECRET` (or `identity.existingSecretName` if `useExistingSecret: true`)
   - `identity.secrets.GOOGLE_DIRECTORY_ENCRYPTION_KEY` (or `identity.existingSecretName` if `useExistingSecret: true`)

2. **Encryption key length:**
   - `GOOGLE_DIRECTORY_ENCRYPTION_KEY` must be at least 32 bytes (when not using `useExistingSecret`)

3. **No sensitive data in ConfigMap:**
   - `GOOGLE_DIRECTORY_CLIENT_SECRET` and `GOOGLE_DIRECTORY_ENCRYPTION_KEY` must not be set in `identity.configmap` or `identity.extraEnvVars`
   - These values must only be set in `identity.secrets` or an existing Secret

4. **No duplicate configuration:**
   - `GOOGLE_DIRECTORY_ENABLED`, `GOOGLE_DIRECTORY_CLIENT_ID`, and `GOOGLE_DIRECTORY_REDIRECT_URL` must not be set in both `identity.configmap` and `identity.extraEnvVars`

5. **String types in extraEnvVars:**
   - If using `identity.extraEnvVars` for the plain-text keys, values must be quoted strings (because they render in ConfigMap.data)

**Why this matters:**

The identity service (version 3.12.0+) refuses to boot when `GOOGLE_DIRECTORY_ENABLED=true` unless all required configuration is present and valid. The chart now fails at render time with clear error messages instead of allowing a deployment that will crash-loop.

**Example validation errors:**

```
Error: GOOGLE_DIRECTORY_ENABLED=true needs a non-empty identity.configmap.GOOGLE_DIRECTORY_CLIENT_ID, identity.configmap.GOOGLE_DIRECTORY_REDIRECT_URL, identity.secrets.GOOGLE_DIRECTORY_CLIENT_SECRET, identity.secrets.GOOGLE_DIRECTORY_ENCRYPTION_KEY; identity refuses to boot without them
```

```
Error: GOOGLE_DIRECTORY_ENABLED=true needs identity.secrets.GOOGLE_DIRECTORY_ENCRYPTION_KEY of at least 32 bytes; identity refuses to boot with a shorter key
```

```
Error: GOOGLE_DIRECTORY_CLIENT_SECRET is sensitive: use identity.secrets.GOOGLE_DIRECTORY_CLIENT_SECRET or identity.useExistingSecret, not identity.configmap or identity.extraEnvVars
```

**Operational impact:**

- Prevents misconfigured deployments that would crash-loop
- Provides clear, actionable error messages at `helm install` or `helm upgrade` time
- No impact on existing installations (validation only runs when `GOOGLE_DIRECTORY_ENABLED` is truthy)

# Configuration Reference

### Google Workspace Directory Configuration

The Google Workspace directory integration requires both public configuration (ConfigMap) and sensitive credentials (Secret).

**Public configuration (ConfigMap):**

```yaml
identity:
  configmap:
    # Enable Google Workspace directory integration
    GOOGLE_DIRECTORY_ENABLED: "true"
    
    # OAuth client ID from Google Cloud Console
    GOOGLE_DIRECTORY_CLIENT_ID: "123456789-abcdefghijklmnop.apps.googleusercontent.com"
    
    # OAuth redirect URL (must match Google Cloud Console configuration)
    GOOGLE_DIRECTORY_REDIRECT_URL: "https://identity.example.com/api/v1/google/callback"
```

**Sensitive configuration (Secret):**

```yaml
identity:
  secrets:
    # OAuth client secret from Google Cloud Console
    GOOGLE_DIRECTORY_CLIENT_SECRET: "GOCSPX-abcdefghijklmnopqrstuvwxyz"
    
    # Encryption key for stored refresh tokens (minimum 32 bytes)
    GOOGLE_DIRECTORY_ENCRYPTION_KEY: "your-secure-random-32-byte-or-longer-encryption-key-here"
```

**Using an existing Secret:**

```yaml
identity:
  useExistingSecret: true
  existingSecretName: "my-identity-secrets"
  
  configmap:
    GOOGLE_DIRECTORY_ENABLED: "true"
    GOOGLE_DIRECTORY_CLIENT_ID: "123456789-abcdefghijklmnop.apps.googleusercontent.com"
    GOOGLE_DIRECTORY_REDIRECT_URL: "https://identity.example.com/api/v1/google/callback"
```

> **Important:** When using `useExistingSecret: true`, your existing Secret must contain the keys `GOOGLE_DIRECTORY_CLIENT_SECRET` and `GOOGLE_DIRECTORY_ENCRYPTION_KEY` if you enable the Google Workspace directory feature.

### Environment Variables

#### New ConfigMap Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GOOGLE_DIRECTORY_ENABLED` | `""` (not rendered) | Set to `"true"` to enable Google Workspace directory integration |
| `GOOGLE_DIRECTORY_CLIENT_ID` | `""` (not rendered) | OAuth 2.0 client ID from Google Cloud Console |
| `GOOGLE_DIRECTORY_REDIRECT_URL` | `""` (not rendered) | OAuth redirect URL registered in Google Cloud Console (must use HTTPS) |

#### New Secret Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GOOGLE_DIRECTORY_CLIENT_SECRET` | `""` (not rendered) | OAuth 2.0 client secret from Google Cloud Console |
| `GOOGLE_DIRECTORY_ENCRYPTION_KEY` | `""` (not rendered) | Encryption key for stored refresh tokens (minimum 32 bytes) |

> **Note:** All new variables are optional and only render in the ConfigMap/Secret when explicitly set. Setting them to empty strings (`""`) results in the keys being omitted from the rendered manifests.

# Migration Guide

### Step 1: Review Your Current Configuration

Before upgrading, verify that you are not accidentally setting any of the new Google Workspace directory configuration keys.

**Check your current values.yaml:**

```bash
grep -E "GOOGLE_DIRECTORY" values.yaml
```

If this returns no results, you can proceed with the upgrade without any configuration changes.

### Step 2: Configure Google Workspace Directory (Optional)

Google Workspace directory integration is **disabled by default**. Only follow this step if you want to enable the feature.

#### Prerequisites

Before configuring the chart, you must:

1. Create a Google Cloud project
2. Enable the Google Workspace Admin SDK API
3. Create OAuth 2.0 credentials (Web application type)
4. Configure the authorized redirect URI
5. Obtain the client ID and client secret

> **Note:** Detailed instructions for setting up Google Workspace OAuth credentials are available in the Google Cloud Console documentation.

#### Option 1: Store Credentials in Chart-Managed Secret

**Generate a secure encryption key:**

```bash
openssl rand -base64 32
```

**Configure the integration:**

```yaml
identity:
  configmap:
    GOOGLE_DIRECTORY_ENABLED: "true"
    GOOGLE_DIRECTORY_CLIENT_ID: "123456789-abcdefghijklmnop.apps.googleusercontent.com"
    GOOGLE_DIRECTORY_REDIRECT_URL: "https://identity.example.com/api/v1/google/callback"
  
  secrets:
    GOOGLE_DIRECTORY_CLIENT_SECRET: "GOCSPX-abcdefghijklmnopqrstuvwxyz"
    GOOGLE_DIRECTORY_ENCRYPTION_KEY: "your-base64-encoded-32-byte-key-from-openssl-command"
```

#### Option 2: Use Existing Secret

If you manage secrets externally (e.g., via sealed-secrets, external-secrets, or manual creation):

**Create the Secret:**

```bash
kubectl create secret generic my-identity-secrets \
  --from-literal=AUTHORIZER_CLIENT_SECRET="your-authorizer-secret" \
  --from-literal=LICENSE_KEY="your-license-key" \
  --from-literal=ORGANIZATION_IDS="your-org-ids" \
  --from-literal=GOOGLE_DIRECTORY_CLIENT_SECRET="GOCSPX-abcdefghijklmnopqrstuvwxyz" \
  --from-literal=GOOGLE_DIRECTORY_ENCRYPTION_KEY="your-32-byte-encryption-key" \
  -n plugin-access-manager
```

**Configure the chart:**

```yaml
identity:
  useExistingSecret: true
  existingSecretName: "my-identity-secrets"
  
  configmap:
    GOOGLE_DIRECTORY_ENABLED: "true"
    GOOGLE_DIRECTORY_CLIENT_ID: "123456789-abcdefghijklmnop.apps.googleusercontent.com"
    GOOGLE_DIRECTORY_REDIRECT_URL: "https://identity.example.com/api/v1/google/callback"
```

#### Validation Checklist

Before deploying, verify:

- [ ] `GOOGLE_DIRECTORY_ENABLED` is set to `"true"` (as a string)
- [ ] `GOOGLE_DIRECTORY_CLIENT_ID` is set and non-empty
- [ ] `GOOGLE_DIRECTORY_REDIRECT_URL` is set and uses HTTPS
- [ ] `GOOGLE_DIRECTORY_CLIENT_SECRET` is set in `identity.secrets` or your existing Secret
- [ ] `GOOGLE_DIRECTORY_ENCRYPTION_KEY` is set in `identity.secrets` or your existing Secret
- [ ] `GOOGLE_DIRECTORY_ENCRYPTION_KEY` is at least 32 bytes long

> **Warning:** The chart will refuse to render if `GOOGLE_DIRECTORY_ENABLED` is `"true"` and any required configuration is missing or invalid. This is intentional to prevent deployments that would crash-loop.

#### Disabling the Feature

To disable Google Workspace directory integration after enabling it:

```yaml
identity:
  configmap:
    GOOGLE_DIRECTORY_ENABLED: "false"
```

Or remove the key entirely:

```yaml
identity:
  configmap:
    # GOOGLE_DIRECTORY_ENABLED not set = feature disabled
```

> **Note:** Disabling the feature does not delete stored refresh tokens. Organizations that previously connected will need to reconnect if you re-enable the feature with a different encryption key.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.8.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.8.0 -n plugin-access-manager
```
<!-- {% endraw %} -->
