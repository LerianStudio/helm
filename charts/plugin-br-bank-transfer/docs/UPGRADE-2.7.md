<!-- {% raw %} -->
# Helm Upgrade from v2.6.0 to v2.7.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Access Manager Permission Declaration (RI) Support](#1-access-manager-permission-declaration-ri-support)
  - [2. lerian-common-helm Dependency Update](#2-lerian-common-helm-dependency-update)
- **[Configuration Reference](#configuration-reference)**
  - [New Global Configuration Block](#new-global-configuration-block)
  - [New ConfigMap Fields](#new-configmap-fields)
  - [New Secret Fields](#new-secret-fields)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Access Manager Integration Requirements](#step-1-review-access-manager-integration-requirements)
  - [Step 2: Configure IDP Settings (Optional)](#step-2-configure-idp-settings-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.7.0 introduces support for Access Manager permission declaration (RI) through a new global configuration block and updates the `lerian-common-helm` dependency from 2.3.0 to 2.4.0. This release adds new optional configuration fields for integrating with the Access Manager Identity component but does not require immediate action from operators. All new features are opt-in and disabled by default.

The chart now supports declaring permissions to Access Manager's Identity component (IDP) through new environment variables and secret fields, rendered by the updated `lerian-common-helm` library. Operators who do not use Access Manager can upgrade without configuration changes.

## Features

### 1. Access Manager Permission Declaration (RI) Support

**What changed:**  
The chart now supports integration with Access Manager's Identity component (IDP) for permission declaration. This feature is controlled by new configuration fields in `global.idp`, `bankTransfer.configmap`, and `bankTransfer.secrets`.

**Why it matters:**  
Applications that need to declare permissions to Access Manager can now configure the IDP client through standardized chart values. The feature is opt-in: when `IDP_DECLARATION_ENABLED` is set to `"true"`, the application will attempt to connect to the IDP service using the provided host and M2M client credentials. Without this configuration, the application behaves exactly as in v2.6.0.

**New configuration blocks:**

#### Global IDP Configuration

A new `global.idp` block allows environment-wide IDP configuration:

```yaml
global:
  idp:
    # declarationEnabled: true  # Enables IDP declaration for all components
    host: "http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001"
```

| Field | Default | Description |
|-------|---------|-------------|
| `declarationEnabled` | (unset) | When `true`, enables IDP permission declaration for all components in the release |
| `host` | (unset) | IDP service URL; required when declaration is enabled |

#### Component-Level IDP Configuration

Component-specific overrides are available in `bankTransfer.configmap` and `bankTransfer.secrets`:

```yaml
bankTransfer:
  configmap:
    IDP_DECLARATION_ENABLED: "false"  # Component-level gate (overrides global.idp.declarationEnabled)
    IDP_HOST: ""  # Component-level host (overrides global.idp.host)
  
  secrets:
    IDP_M2M_CLIENT_ID: ""  # M2M client ID for IDP authentication
    IDP_M2M_CLIENT_SECRET: ""  # M2M client secret for IDP authentication
```

| Field | Location | Default | Description |
|-------|----------|---------|-------------|
| `IDP_DECLARATION_ENABLED` | ConfigMap | `"false"` | Enables IDP permission declaration for this component |
| `IDP_HOST` | ConfigMap | `""` | IDP service URL (rendered only when set) |
| `IDP_M2M_CLIENT_ID` | Secret | `""` | Machine-to-machine client ID for IDP authentication |
| `IDP_M2M_CLIENT_SECRET` | Secret | `""` | Machine-to-machine client secret for IDP authentication |

**Resolution order:**  
Component-level settings (`bankTransfer.configmap.*`, `bankTransfer.extraEnvVars`) take precedence over global settings (`global.idp.*`).

**Template changes:**

**Before (v2.6.0):**
```yaml
# templates/configmap.yaml (no IDP configuration)
data:
  PLUGIN_AUTH_ENABLED: "true"
  PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth..."
  
  {{- range $key, $value := .Values.bankTransfer.extraEnvVars }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

**After (v2.7.0):**
```yaml
# templates/configmap.yaml (IDP configuration added)
data:
  PLUGIN_AUTH_ENABLED: "true"
  PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth..."
  
  # =====================================================================
  # ACCESS MANAGER PERMISSION DECLARATION (RI) — lerian-common.idp.env.
  # IDP_DECLARATION_ENABLED (always, default "false") and IDP_HOST (only when
  # set), resolved as bankTransfer.configmap > bankTransfer.extraEnvVars
  # (legacy) > global.idp.{declarationEnabled,host}. The client pair lives in
  # the Secret (templates/secrets.yaml). With the flag on, the app refuses to
  # boot without the host and the pair.
  # =====================================================================
  {{- include "lerian-common.idp.env" (dict "context" $ "configmap" $cm "extraEnvVars" .Values.bankTransfer.extraEnvVars) | nindent 2 }}
  
  # =====================================================================
  # EXTRA OVERRIDES (escape hatch for env vars not modeled above)
  # =====================================================================
  {{- /* IDP_DECLARATION_ENABLED / IDP_HOST in extraEnvVars already fed
     lerian-common.idp.env above; emitting them again would duplicate the key. */ -}}
  {{- $idpEnvKeys := include "lerian-common.idp.keys" (dict "kind" "env") | fromJsonArray }}
  {{- range $key, $value := .Values.bankTransfer.extraEnvVars }}
  {{- if not (has $key $idpEnvKeys) }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
```

**Before (v2.6.0):**
```yaml
# templates/secrets.yaml (IDP credentials rendered conditionally)
stringData:
  {{- if .Values.bankTransfer.secrets.IDP_M2M_CLIENT_ID }}
  IDP_M2M_CLIENT_ID: {{ .Values.bankTransfer.secrets.IDP_M2M_CLIENT_ID | quote }}
  {{- end }}
  {{- if .Values.bankTransfer.secrets.IDP_M2M_CLIENT_SECRET }}
  IDP_M2M_CLIENT_SECRET: {{ .Values.bankTransfer.secrets.IDP_M2M_CLIENT_SECRET | quote }}
  {{- end }}
```

**After (v2.7.0):**
```yaml
# templates/secrets.yaml (IDP credentials rendered via lerian-common helper)
stringData:
  {{- /* Access Manager permission declaration (RI) client pair — lerian-common.idp.secret,
     each key only when set. Read by lib-auth's declaration.WireFromEnv only when
     IDP_DECLARATION_ENABLED="true" (ConfigMap, lerian-common.idp.env). With the flag on,
     the app refuses to boot without this pair. */}}
  {{- with (include "lerian-common.idp.secret" (dict "secrets" .Values.bankTransfer.secrets "mode" "stringData" "useExistingSecret" .Values.bankTransfer.useExistingSecret)) }}
  {{- . | nindent 2 }}
  {{- end }}
```

**Operational impact:**
- When `IDP_DECLARATION_ENABLED="false"` (default): No IDP-related environment variables are rendered; application behavior is unchanged from v2.6.0
- When `IDP_DECLARATION_ENABLED="true"`: The application requires `IDP_HOST`, `IDP_M2M_CLIENT_ID`, and `IDP_M2M_CLIENT_SECRET` to be set; the application will refuse to boot if any are missing
- The `extraEnvVars` escape hatch now filters out `IDP_DECLARATION_ENABLED` and `IDP_HOST` to prevent duplicate keys in the ConfigMap (these are now rendered by `lerian-common.idp.env`)
- When `bankTransfer.useExistingSecret=true`, the chart does not render `IDP_M2M_CLIENT_ID` or `IDP_M2M_CLIENT_SECRET` — the existing Secret must contain both keys

**Migration required:**  
No — the feature is disabled by default. See [Step 2: Configure IDP Settings](#step-2-configure-idp-settings-optional) if you want to enable Access Manager integration.

### 2. lerian-common-helm Dependency Update

**What changed:**  
The `lerian-common-helm` dependency has been updated from version 2.3.0 to 2.4.0.

| Dependency | v2.6.0 | v2.7.0 | Change Type |
|------------|--------|--------|-------------|
| `lerian-common-helm` | `2.3.0` | `2.4.0` | Minor |

**Why it matters:**  
The updated library chart introduces new template helpers for IDP configuration (`lerian-common.idp.env`, `lerian-common.idp.secret`, `lerian-common.idp.keys`) that enable the Access Manager permission declaration feature. The update is backward-compatible and does not affect existing functionality.

**Migration required:**  
No — the dependency update is transparent to operators.

## Configuration Reference

### New Global Configuration Block

```yaml
global:
  # -- Env-wide Access Manager permission declaration (RI). Consumed by
  # lerian-common.idp.env (block "idp"). Fields: declarationEnabled, host.
  # (bankTransfer.configmap.IDP_DECLARATION_ENABLED / IDP_HOST override.)
  # declarationEnabled turns the gate on for every component of the release;
  # prefer the component configmap for the gate and use global for the host.
  # Example: idp: { host: "http://plugin-access-manager-identity.<ns>.svc.cluster.local:4001" }
  idp: {}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `global.idp` | object | `{}` | Environment-wide IDP configuration block |
| `global.idp.declarationEnabled` | bool | (unset) | Enables IDP permission declaration for all components |
| `global.idp.host` | string | (unset) | IDP service URL (e.g., `http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001`) |

### New ConfigMap Fields

```yaml
bankTransfer:
  configmap:
    # =================================================================
    # Access Manager permission declaration (RI) — rendered by
    # lerian-common.idp.env. IDP_DECLARATION_ENABLED defaults to "false";
    # IDP_HOST is rendered only when set. Client pair: bankTransfer.secrets.
    # IDP_DECLARATION_ENABLED: "false"
    # IDP_HOST: ""
    # =================================================================
```

| Field | Default | Description |
|-------|---------|-------------|
| `IDP_DECLARATION_ENABLED` | `"false"` | Enables IDP permission declaration for the bank-transfer component |
| `IDP_HOST` | `""` | IDP service URL (rendered only when set; overrides `global.idp.host`) |

### New Secret Fields

```yaml
bankTransfer:
  secrets:
    # Access Manager permission declaration (RI) client pair, used only when
    # IDP_DECLARATION_ENABLED="true" (configmap.IDP_DECLARATION_ENABLED / IDP_HOST, or
    # global.idp.{declarationEnabled,host}). With useExistingSecret=true the chart renders
    # neither key: the existing Secret must carry both.
    # IDP_M2M_CLIENT_ID: ""
    # IDP_M2M_CLIENT_SECRET: ""
```

| Field | Default | Description |
|-------|---------|-------------|
| `IDP_M2M_CLIENT_ID` | `""` | Machine-to-machine client ID for IDP authentication (rendered only when set) |
| `IDP_M2M_CLIENT_SECRET` | `""` | Machine-to-machine client secret for IDP authentication (rendered only when set) |

> **Important:** When `bankTransfer.useExistingSecret=true`, the chart does not render `IDP_M2M_CLIENT_ID` or `IDP_M2M_CLIENT_SECRET`. The existing Secret must contain both keys if IDP declaration is enabled.

## Migration Steps

### Step 1: Review Access Manager Integration Requirements

The new IDP permission declaration feature is **disabled by default**. No action is required unless you want to integrate with Access Manager's Identity component.

**Current behavior (default):**
- `IDP_DECLARATION_ENABLED` defaults to `"false"`
- No IDP-related environment variables are rendered in the ConfigMap or Secret
- Application behavior is identical to v2.6.0

**To enable IDP integration:**
- Set `IDP_DECLARATION_ENABLED="true"` (via `global.idp.declarationEnabled` or `bankTransfer.configmap.IDP_DECLARATION_ENABLED`)
- Provide `IDP_HOST` (via `global.idp.host` or `bankTransfer.configmap.IDP_HOST`)
- Provide `IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` (via `bankTransfer.secrets.*`)

> **Warning:** When `IDP_DECLARATION_ENABLED="true"`, the application will refuse to boot if `IDP_HOST`, `IDP_M2M_CLIENT_ID`, or `IDP_M2M_CLIENT_SECRET` are missing.

### Step 2: Configure IDP Settings (Optional)

If you want to enable Access Manager permission declaration, choose one of the following configuration approaches:

#### Option 1: Global Configuration (Recommended for Multi-Component Environments)

Use `global.idp` to configure IDP settings for all components in the release:

```yaml
global:
  idp:
    declarationEnabled: true
    host: "http://plugin-access-manager-identity.midaz-plugins.svc.cluster.local:4001"

bankTransfer:
  secrets:
    IDP_M2M_CLIENT_ID: "<your-client-id>"
    IDP_M2M_CLIENT_SECRET: "<your-client-secret>"
```

#### Option 2: Component-Level Configuration

Use `bankTransfer.configmap` and `bankTransfer.secrets` for component-specific settings:

```yaml
bankTransfer:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://plugin-access-manager-identity.midaz-plugins.svc.cluster.local:4001"
  
  secrets:
    IDP_M2M_CLIENT_ID: "<your-client-id>"
    IDP_M2M_CLIENT_SECRET: "<your-client-secret>"
```

#### Option 3: Use Existing Secret (Recommended for Production)

Create a Kubernetes Secret with the IDP client credentials and reference it:

```bash
kubectl create secret generic my-app-secret \
  --from-literal=IDP_M2M_CLIENT_ID='<your-client-id>' \
  --from-literal=IDP_M2M_CLIENT_SECRET='<your-client-secret>' \
  -n plugin-br-bank-transfer
```

Reference the Secret in your values:

```yaml
global:
  idp:
    declarationEnabled: true
    host: "http://plugin-access-manager-identity.midaz-plugins.svc.cluster.local:4001"

bankTransfer:
  useExistingSecret: true
  existingSecretName: "my-app-secret"
```

> **Note:** When using `useExistingSecret=true`, ensure the existing Secret contains both `IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` keys if IDP declaration is enabled.

#### Option 4: Legacy extraEnvVars (Not Recommended)

For backward compatibility, you can still use `extraEnvVars` to set IDP configuration:

```yaml
bankTransfer:
  extraEnvVars:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://plugin-access-manager-identity.midaz-plugins.svc.cluster.local:4001"
  
  secrets:
    IDP_M2M_CLIENT_ID: "<your-client-id>"
    IDP_M2M_CLIENT_SECRET: "<your-client-secret>"
```

> **Note:** `IDP_DECLARATION_ENABLED` and `IDP_HOST` set via `extraEnvVars` are automatically filtered to prevent duplicate keys in the ConfigMap. Prefer `bankTransfer.configmap` or `global.idp` for clarity.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.7.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.7.0 -n plugin-br-bank-transfer
```
<!-- {% endraw %} -->
