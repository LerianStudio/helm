<!-- {% raw %} -->
# Helm Upgrade from v3.0.4 to v3.0.5

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application Version Update](#1-application-version-update)
  - [2. License Gateway Configuration Simplified](#2-license-gateway-configuration-simplified)
  - [3. MongoDB Password Template Added](#3-mongodb-password-template-added)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Remove IS_DEVELOPMENT Configuration (If Present)](#step-1-remove-is_development-configuration-if-present)
  - [Step 2: Verify License Configuration](#step-2-verify-license-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.0.5 is a patch release that updates the application version from 3.4.0 to 3.5.0 and simplifies license gateway configuration. The `IS_DEVELOPMENT` environment variable has been removed — all products now validate against the production license gateway only. Development environments that relied on `IS_DEVELOPMENT="true"` to select the development license gateway must migrate to production license keys.

## Changes

### 1. Application Version Update

**What changed:**  
The default container image tag has been updated to align with the new application version.

| Setting | v3.0.4 | v3.0.5 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `3.4.0` | `3.5.0` |
| `bankTransfer.image.tag` | `3.4.0` | `3.5.0` |

**Why it matters:**  
The application container will be updated to version 3.5.0, which includes the license gateway simplification. Application 3.5.0 validates `LICENSE_KEY` as a global licence and no longer reads `ORGANIZATION_IDS`.

**Operational impact:**  
- The bank-transfer deployment will perform a rolling update to the new image version
- If you have explicitly set `bankTransfer.image.tag` in your values, that override will continue to be respected

**Migration required:**  
If you have overridden `bankTransfer.image.tag` in your values and want to use the new default, remove the override:

```yaml
# Remove this override to use the chart's new default (3.5.0)
bankTransfer:
  image:
    tag: "3.4.0"  # Delete this line to use 3.5.0
```

### 2. License Gateway Configuration Simplified

**What changed:**  
The `IS_DEVELOPMENT` environment variable has been removed from both the values file and the ConfigMap template. Application version 3.5.0 and later validate licenses exclusively against the production license gateway.

**Before (v3.0.4):**

**values.yaml:**
```yaml
bankTransfer:
  configmap:
    # =================================================================
    # License gateway — newer app images refuse to boot without LICENSE_KEY
    # (bankTransfer.secrets) and ORGANIZATION_IDS (below), in every
    # environment. lib-license-go picks the gateway itself: IS_DEVELOPMENT
    # "true" (exactly) selects the development gateway, which a development
    # licence key needs. Rendered only when set.
    # =================================================================
    # IS_DEVELOPMENT: "true"
```

**templates/configmap.yaml:**
```yaml
# =====================================================================
# LICENSE GATEWAY — rendered in both modes. Newer app images refuse to
# boot without LICENSE_KEY (Secret) and ORGANIZATION_IDS, in every environment.
# IS_DEVELOPMENT is read by lib-license-go: exactly "true" selects the
# development licence gateway, which a development licence key needs.
# =====================================================================
{{- if and .Values.bankTransfer.configmap.ORGANIZATION_IDS (not (.Values.bankTransfer.secrets.ORGANIZATION_IDS | default "")) }}
ORGANIZATION_IDS: {{ .Values.bankTransfer.configmap.ORGANIZATION_IDS | quote }}
{{- end }}
{{- if .Values.bankTransfer.configmap.IS_DEVELOPMENT }}
IS_DEVELOPMENT: {{ .Values.bankTransfer.configmap.IS_DEVELOPMENT | quote }}
{{- end }}
```

**After (v3.0.5):**

**values.yaml:**
```yaml
bankTransfer:
  configmap:
    # =================================================================
    # License gateway — newer app images refuse to boot without LICENSE_KEY
    # (bankTransfer.secrets) and ORGANIZATION_IDS (below), in every
    # environment. Products validate only on the production licence gateway.
    # =================================================================
```

**templates/configmap.yaml:**
```yaml
# =====================================================================
# LICENSE GATEWAY — rendered in both modes. Newer app images refuse to
# boot without LICENSE_KEY (Secret) and ORGANIZATION_IDS, in every environment.
# =====================================================================
{{- if and .Values.bankTransfer.configmap.ORGANIZATION_IDS (not (.Values.bankTransfer.secrets.ORGANIZATION_IDS | default "")) }}
ORGANIZATION_IDS: {{ .Values.bankTransfer.configmap.ORGANIZATION_IDS | quote }}
{{- end }}
```

**Why it matters:**  
The application's license validation library (`lib-license-go`) no longer supports selecting between development and production license gateways. All deployments — including development, staging, and production environments — must use production license keys that validate against the production gateway.

**Operational impact:**  
- **Development/staging environments:** If you previously set `IS_DEVELOPMENT: "true"` to use development license keys, those keys will no longer work after upgrading to application version 3.5.0. You must obtain production license keys for all environments
- If `IS_DEVELOPMENT` is present in your values file, it will be ignored (the template no longer renders it), but the application will fail to start if you are using a development license key
- Application 3.5.0 always validates `LICENSE_KEY` as a global licence. If `bankTransfer.configmap.ORGANIZATION_IDS` or `bankTransfer.secrets.ORGANIZATION_IDS` holds organization IDs today, your key works only with those organizations: get a global key from Lerian and put it in `bankTransfer.secrets.LICENSE_KEY` before you upgrade, or the application does not start

**Breaking change for development environments:**  
If your development or staging environment currently sets `IS_DEVELOPMENT: "true"` and uses a development license key, the application will fail to start after upgrading to v3.0.5 because the development license key will not validate against the production gateway.

> **Warning:** Development environments using `IS_DEVELOPMENT: "true"` with development license keys must migrate to production license keys before upgrading. Contact your license provider to obtain production keys for non-production environments.

### 3. MongoDB Password Template Added

**What changed:**  
A new template helper file `_mongodb-passwords.tpl` has been added to support MongoDB password management. This is an internal template helper and does not require operator configuration.

**Template added:**

**templates/_mongodb-passwords.tpl:**
```yaml
{{- define "mongodb.customPasswords" -}}
{{- $passwords := list -}}
{{- if .Values.auth.password -}}
{{- $passwords = append $passwords .Values.auth.password -}}
{{- end -}}
{{- range .Values.auth.passwords -}}
{{- $passwords = append $passwords . -}}
{{- end -}}
{{- $configured := join "," $passwords -}}
{{- if or $configured .Values.auth.existingSecret .Values.passwordUpdateJob.enabled -}}
{{- $configured -}}
{{- else -}}
{{- include "common.secrets.lookup" (dict "secret" (include "mongodb.secretName" .) "key" "mongodb-passwords" "context" .) | b64dec -}}
{{- end -}}
{{- end -}}
```

**Why it matters:**  
The file replaces the bundled MongoDB subchart's `mongodb.customPasswords` helper. When no MongoDB password is set in values (`mongodb.auth.password` and `mongodb.auth.passwords` empty, the default) and `mongodb.auth.existingSecret` is unset, an upgrade keeps the password already stored in the MongoDB Secret (key `mongodb-passwords`) instead of generating a new one.

**Operational impact:**  
- This is an **internal template helper** — no operator action is required
- If you use the bundled MongoDB subchart (`mongodb.enabled=true`), if you do not set a password, the stored password is now kept across upgrades
- If you use an external MongoDB instance, this template is not used

**Migration required:**  
No — this is an internal template addition with no configuration changes.

## Migration Steps

### Step 1: Remove IS_DEVELOPMENT Configuration (If Present)

If your values file contains `IS_DEVELOPMENT: "true"`, you must remove it and migrate to a production license key.

#### Option 1: Production Environment (No Action Required)

If you are running a production environment, never set `IS_DEVELOPMENT`, and your `LICENSE_KEY` is a global key (not one issued for organization IDs), no action is required.

#### Option 2: Development/Staging Environment (Migration Required)

If your development or staging environment currently uses `IS_DEVELOPMENT: "true"` with a development license key, follow these steps:

**Step 2a: Obtain a production license key**

Contact your license provider to obtain a production license key for your development/staging environment. Production license keys validate against the production gateway and work in all environments.

**Step 2b: Update your values file**

Remove the `IS_DEVELOPMENT` configuration and update `LICENSE_KEY` with your new production key:

**Before:**
```yaml
bankTransfer:
  configmap:
    IS_DEVELOPMENT: "true"
    ORGANIZATION_IDS: "org-123,org-456"
  
  secrets:
    LICENSE_KEY: "dev-license-key-abc123"  # Development key
```

**After:**
```yaml
bankTransfer:
  secrets:
    LICENSE_KEY: "prod-license-key-xyz789"  # Production key
```

> **Important:** Do not upgrade to v3.0.5 until you have obtained and configured a production license key. The application will fail to start if you attempt to use a development license key with application version 3.5.0.

### Step 2: Verify License Configuration

Before upgrading, verify that your license configuration is correct:

**Required configuration:**

```yaml
bankTransfer:
  secrets:
    LICENSE_KEY: "your-production-license-key"  # Production key
```

> **Note:** `LICENSE_KEY` (in `bankTransfer.secrets`) is required for the application to start. If it is missing, the application refuses to boot.

**Verify your configuration:**

1. Ensure `LICENSE_KEY` is set in `bankTransfer.secrets` (or in an external secret if using `bankTransfer.useExistingSecret=true`)
2. Ensure `IS_DEVELOPMENT` is **not** present in your values file
3. Confirm your `LICENSE_KEY` is a global production key (not a development key, and not a key issued for organization IDs)

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.5 -n midaz-plugins
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.5 -n midaz-plugins
```
<!-- {% endraw %} -->
