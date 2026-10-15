# Helm Upgrade from v0.5.1 to v0.5.2

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. IDP Permission Declaration Support](#1-idp-permission-declaration-support)
  - [2. Application Version Bump](#2-application-version-bump)
- **[Configuration Reference](#configuration-reference)**
  - [IDP Declaration Configuration](#idp-declaration-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review IDP Declaration Requirements](#step-1-review-idp-declaration-requirements)
  - [Step 2: Update Application Version](#step-2-update-application-version)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** that adds support for IDP (Identity Provider) permission declaration, allowing the API to publish its permissions manifest to an Access Manager at boot time. The application version has been updated from 1.1.1 to 1.2.0.

| Setting | v0.5.1 | v0.5.2 |
|---------|--------|--------|
| Chart Version | 0.5.1 | 0.5.2 |
| App Version | 1.1.1 | 1.2.0 |
| Migrations Image Tag | 1.1.1 | 1.2.0 |

## Features

### 1. IDP Permission Declaration Support

The chart now supports automatic permission declaration to an Access Manager at API boot time. When enabled, the API publishes its permissions manifest as a machine-to-machine (M2M) application, allowing centralized permission management in multi-tenant or federated authentication scenarios.

**What changed:**

Three new configuration keys have been added to support IDP declaration:

| Variable | Type | Required When | Purpose |
|----------|------|---------------|---------|
| `IDP_DECLARATION_ENABLED` | ConfigMap | Optional | Enables permission declaration (default: `"false"`) |
| `IDP_HOST` | ConfigMap or Secret | When declaration enabled | Access Manager URL (must be `http(s)://...`) |
| `IDP_M2M_CLIENT_ID` | ConfigMap or Secret | When declaration enabled | M2M application client ID |
| `IDP_M2M_CLIENT_SECRET` | Secret | When declaration enabled | M2M application client secret |

**Why it matters:**

In single-tenant deployments with centralized authentication, the API needs to register its permissions with the Access Manager so that authorization policies can be enforced consistently across the platform. This feature automates that registration at boot time, eliminating manual permission configuration.

**Operational impact:**

- **API-only feature**: The worker does not publish permissions; only the API component uses these settings
- **Requires authentication enabled**: `PLUGIN_AUTH_ENABLED` must be `"true"` (the M2M token is minted by the lib-auth client)
- **Single-tenant only**: Multi-tenant deployments manage permissions through the Tenant Manager
- **Validation at render time**: The chart fails with a descriptive error if declaration is enabled but required values are missing or malformed

**Configuration options:**

The declaration keys can be set in multiple locations, with the following precedence (highest to lowest):

1. `api.extraSecrets` (for sensitive values)
2. `api.secrets` (for sensitive values)
3. `api.extraConfigmap` (for non-sensitive values)
4. `api.configmap` (for non-sensitive values)

> **Note:** `IDP_M2M_CLIENT_SECRET` can only be set via `api.secrets`, `api.extraSecrets`, or `api.extraConfigmap`. The `api.configmap.IDP_M2M_CLIENT_SECRET` field exists for documentation purposes but is never rendered (secrets should not be in ConfigMaps).

**Example configuration (declaration disabled, default):**

```yaml
api:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    # IDP_DECLARATION_ENABLED defaults to "false" when omitted
```

**Example configuration (declaration enabled, all values in secrets):**

```yaml
api:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    IDP_DECLARATION_ENABLED: "true"
  
  secrets:
    IDP_HOST: "https://access-manager.example.com"
    IDP_M2M_CLIENT_ID: "plugin-br-pix-jd-m2m"
    IDP_M2M_CLIENT_SECRET: "secret-value-here"
```

**Example configuration (declaration enabled, mixed ConfigMap and Secret):**

```yaml
api:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "https://access-manager.example.com"
    IDP_M2M_CLIENT_ID: "plugin-br-pix-jd-m2m"
  
  secrets:
    IDP_M2M_CLIENT_SECRET: "secret-value-here"
```

**Validation rules:**

The chart enforces the following validation when `IDP_DECLARATION_ENABLED="true"`:

1. **Required values**: `IDP_HOST`, `IDP_M2M_CLIENT_ID`, and `IDP_M2M_CLIENT_SECRET` must all be set (in any combination of ConfigMap/Secret)
2. **Authentication enabled**: `PLUGIN_AUTH_ENABLED` must be `"true"`
3. **Valid URL**: `IDP_HOST` must be an absolute `http://` or `https://` URL with a hostname and no user credentials
4. **Boolean value**: `IDP_DECLARATION_ENABLED` must be exactly `"true"` or `"false"` (case-sensitive)

**Validation error examples:**

Missing required values:

```
ERROR: IDP_DECLARATION_ENABLED=true requires IDP_HOST, IDP_M2M_CLIENT_ID, IDP_M2M_CLIENT_SECRET.
Set each in api.configmap or api.secrets (or their extra* overrides). The app refuses to
boot without them: it cannot publish its permissions to the Access Manager.
```

Invalid URL format:

```
ERROR: IDP_HOST must be an absolute http(s) URL with a host and no user credentials.
The app refuses any other value at boot.
```

Authentication disabled:

```
ERROR: IDP_DECLARATION_ENABLED=true requires PLUGIN_AUTH_ENABLED=true.
Set each in api.configmap or api.secrets (or their extra* overrides). The app refuses to
boot without them: it cannot publish its permissions to the Access Manager.
```

> **Important:** When using `api.existingSecret.name`, the Secret's content is unknown to the chart, so missing values cannot be detected at render time. The API will fail at boot if required values are absent.

**Template changes:**

The ConfigMap template now includes declaration environment variables when `IDP_DECLARATION_ENABLED` is set:

**Before (v0.5.1):**

```yaml
data:
  PLUGIN_AUTH_ENABLED: {{ $authEnabled | quote }}
  # ... other config keys
```

**After (v0.5.2):**

```yaml
data:
  PLUGIN_AUTH_ENABLED: {{ $authEnabled | quote }}
  {{- with (include "plugin-br-pix-jd.declarationEnv" (dict "root" $ "authEnabled" $authEnabled)) }}
  {{- . | nindent 2 }}
  {{- end }}
  # IDP_DECLARATION_ENABLED: "true"  (if set)
  # IDP_HOST: "https://..."          (if set in ConfigMap)
  # IDP_M2M_CLIENT_ID: "..."         (if set in ConfigMap)
```

The Secret template now includes declaration keys when set via `api.secrets`:

**Before (v0.5.1):**

```yaml
data:
  POSTGRES_PASSWORD: {{ ... }}
  # ... other secret keys
  {{- range $key, $value := (.Values.api.extraSecrets | default dict) }}
  {{ $key }}: {{ $value | b64enc | quote }}
  {{- end }}
```

**After (v0.5.2):**

```yaml
data:
  POSTGRES_PASSWORD: {{ ... }}
  # ... other secret keys
  {{- with (include "plugin-br-pix-jd.declarationSecrets" $) }}
  {{- . | nindent 2 }}
  {{- end }}
  # IDP_HOST: <base64>                (if set in api.secrets)
  # IDP_M2M_CLIENT_ID: <base64>       (if set in api.secrets)
  # IDP_M2M_CLIENT_SECRET: <base64>   (if set in api.secrets)
  {{- range $key, $value := (.Values.api.extraSecrets | default dict) }}
  {{- if not (and (has $key $declarationKeys) (not ($value | default "" | toString | trim))) }}
  {{ $key }}: {{ $value | b64enc | quote }}
  {{- end }}
  {{- end }}
```

> **Note:** The `extraSecrets` loop now skips blank declaration keys to prevent mounting an empty Secret value over a ConfigMap value. Each declaration key appears exactly once across ConfigMap and Secret.

**Vault integration:**

The chart supports Vault path placeholders (e.g., `<path:secret/data/foo#bar>`) for all declaration keys. When a placeholder is detected, URL validation is skipped:

```yaml
api:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "<path:secret/data/idp#host>"
    IDP_M2M_CLIENT_ID: "<path:secret/data/idp#client_id>"
  
  secrets:
    IDP_M2M_CLIENT_SECRET: "<path:secret/data/idp#client_secret>"
```

### 2. Application Version Bump

The chart's `appVersion` has been updated from `1.1.1` to `1.2.0`, and the migrations image tag has been updated to match.

| Component | v0.5.1 | v0.5.2 |
|-----------|--------|--------|
| Chart `appVersion` | 1.1.1 | 1.2.0 |
| API default tag | 1.1.1 | 1.2.0 |
| Worker default tag | 1.1.1 | 1.2.0 |
| Migrations default tag | 1.1.1 | 1.2.0 |

**Configuration changes:**

The migrations image tag pin has been updated in `values.yaml`:

**Before (v0.5.1):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.1.1"
    pullPolicy: IfNotPresent
```

**After (v0.5.2):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.2.0"
    pullPolicy: IfNotPresent
```

> **Important:** The `appVersion` is a **fallback default** for `api.image.tag`, `worker.image.tag`, and `migrations.image.tag`. Production values should **always pin tags explicitly** rather than inheriting from `appVersion`, because the release pipeline builds only the components a commit touched. Tags legitimately diverge across components.

## Configuration Reference

### IDP Declaration Configuration

**New fields (v0.5.2):**

```yaml
api:
  configmap:
    # -- Enable permission declaration to Access Manager at boot (default: "false").
    # Single-tenant only; multi-tenant deployments use the Tenant Manager.
    # Requires PLUGIN_AUTH_ENABLED="true" and all three IDP_* values set.
    IDP_DECLARATION_ENABLED: "false"
    
    # -- Access Manager URL (required when declaration enabled).
    # Must be an absolute http(s) URL with a hostname and no user credentials.
    # Can also be set in api.secrets or api.extraSecrets.
    IDP_HOST: ""
    
    # -- M2M application client ID (required when declaration enabled).
    # Can also be set in api.secrets or api.extraSecrets.
    IDP_M2M_CLIENT_ID: ""
  
  secrets:
    # -- M2M application client secret (required when declaration enabled).
    # Can also be set in api.extraSecrets or api.extraConfigmap (not recommended).
    IDP_M2M_CLIENT_SECRET: ""
```

**Field precedence:**

Each declaration key can be set in multiple locations. The chart reads values in this order (highest to lowest precedence):

1. `api.extraSecrets` (mounted after the Secret, wins for all keys)
2. `api.secrets` (mounted after the ConfigMap, wins over ConfigMap)
3. `api.extraConfigmap` (merged last into ConfigMap, wins over `api.configmap`)
4. `api.configmap` (base configuration)

> **Note:** `IDP_M2M_CLIENT_SECRET` in `api.configmap` is never rendered (secrets should not be in ConfigMaps). Set it via `api.secrets`, `api.extraSecrets`, or `api.extraConfigmap`.

**Validation summary:**

| Condition | Result |
|-----------|--------|
| `IDP_DECLARATION_ENABLED` unset | No validation, feature disabled |
| `IDP_DECLARATION_ENABLED="false"` | No validation, feature disabled |
| `IDP_DECLARATION_ENABLED="true"` | All three IDP_* values required, `PLUGIN_AUTH_ENABLED="true"` required, `IDP_HOST` must be valid URL |
| `IDP_DECLARATION_ENABLED` not `"true"` or `"false"` | Render fails with error |
| `IDP_HOST` contains credentials (e.g., `http://user:pass@...`) | Render fails with error |
| `IDP_HOST` not `http://` or `https://` | Render fails with error |
| Any IDP_* value missing (with own Secret) | Render fails with error |
| Any IDP_* value missing (with `existingSecret`) | No validation, app fails at boot |

## Migration Steps

### Step 1: Review IDP Declaration Requirements

If you are running a **single-tenant** deployment with centralized authentication and want to enable automatic permission declaration, configure the IDP settings:

```yaml
api:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "https://access-manager.example.com"
    IDP_M2M_CLIENT_ID: "plugin-br-pix-jd-m2m"
  
  secrets:
    IDP_M2M_CLIENT_SECRET: "your-m2m-client-secret"
```

If you are running a **multi-tenant** deployment or do not use centralized permission management, no action is required. The feature defaults to disabled.

> **Important:** Enabling declaration requires `PLUGIN_AUTH_ENABLED="true"`. If authentication is disabled, the chart will fail to render with an error message.

### Step 2: Update Application Version

If you explicitly pin image tags in your `values.yaml`, update them to the new version:

**Before (v0.5.1):**

```yaml
api:
  image:
    tag: "1.1.1"

worker:
  image:
    tag: "1.1.1"

migrations:
  image:
    tag: "1.1.1"
```

**After (v0.5.2):**

```yaml
api:
  image:
    tag: "1.2.0"

worker:
  image:
    tag: "1.2.0"

migrations:
  image:
    tag: "1.2.0"
```

If you rely on the `appVersion` fallback (not recommended for production), no action is required. The chart will automatically use `1.2.0` for all components.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.2 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.2 -n plugin-br-pix-jd
```
