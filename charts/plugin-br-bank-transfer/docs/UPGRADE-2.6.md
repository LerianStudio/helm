<!-- {% raw %} -->
# Helm Upgrade from v2.5.0 to v2.6.0

## Topics

- **[Overview](#overview)**
- **[New Features](#new-features)**
  - [1. Access Manager Permission Declaration Support](#1-access-manager-permission-declaration-support)
- **[Configuration Reference](#configuration-reference)**
  - [New Secret Fields](#new-secret-fields)
  - [New Environment Variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Determine If You Need Access Manager Integration](#step-1-determine-if-you-need-access-manager-integration)
  - [Step 2: Configure Access Manager Credentials (Optional)](#step-2-configure-access-manager-credentials-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.6.0 introduces optional support for Access Manager permission declaration via a new machine-to-machine (M2M) client credential pair. This is a non-breaking minor release that adds new configuration fields to `bankTransfer.secrets` without modifying existing behavior. The feature is opt-in and controlled by runtime flags (`IDP_DECLARATION_ENABLED` and `IDP_HOST`) that operators set via ConfigMap or `extraEnvVars`.

No action is required unless you plan to enable Access Manager permission declaration for this plugin.

## New Features

### 1. Access Manager Permission Declaration Support

**What changed:**  
The chart now supports an optional Access Manager (Identity Provider) integration for declaring resource permissions at application startup. Two new secret fields have been added to store the M2M client credentials required for this integration.

**New secret fields:**

| Field | Location | Purpose |
|-------|----------|---------|
| `IDP_M2M_CLIENT_ID` | `bankTransfer.secrets` | Client ID for Access Manager permission declaration |
| `IDP_M2M_CLIENT_SECRET` | `bankTransfer.secrets` | Client secret for Access Manager permission declaration |

**values.yaml (v2.6.0):**
```yaml
bankTransfer:
  secrets:
    # Access Manager permission declaration (RI) client pair, used only when
    # IDP_DECLARATION_ENABLED="true" (set it and IDP_HOST in configmap or extraEnvVars)
    # IDP_M2M_CLIENT_ID: ""
    # IDP_M2M_CLIENT_SECRET: ""
```

**Template changes:**

**Before (v2.5.0):**
```yaml
# templates/secrets.yaml (end of stringData block)
  {{- if .Values.bankTransfer.secrets.COURIER_CLIENT_SECRET }}
  COURIER_CLIENT_SECRET: {{ .Values.bankTransfer.secrets.COURIER_CLIENT_SECRET | quote }}
  {{- end }}

{{- end }}
{{- end }}
```

**After (v2.6.0):**
```yaml
# templates/secrets.yaml (end of stringData block)
  {{- if .Values.bankTransfer.secrets.COURIER_CLIENT_SECRET }}
  COURIER_CLIENT_SECRET: {{ .Values.bankTransfer.secrets.COURIER_CLIENT_SECRET | quote }}
  {{- end }}

  {{- /* Access Manager permission declaration (RI), read by lib-auth's declaration.WireFromEnv
     only when IDP_DECLARATION_ENABLED="true" (set with IDP_HOST through configmap or
     extraEnvVars). With the flag on, the app refuses to boot without this pair. */}}
  {{- if .Values.bankTransfer.secrets.IDP_M2M_CLIENT_ID }}
  IDP_M2M_CLIENT_ID: {{ .Values.bankTransfer.secrets.IDP_M2M_CLIENT_ID | quote }}
  {{- end }}
  {{- if .Values.bankTransfer.secrets.IDP_M2M_CLIENT_SECRET }}
  IDP_M2M_CLIENT_SECRET: {{ .Values.bankTransfer.secrets.IDP_M2M_CLIENT_SECRET | quote }}
  {{- end }}

{{- end }}
{{- end }}
```

**Why it matters:**  
Access Manager permission declaration allows the plugin to register its resource permissions (RI) with a centralized identity provider at startup. This enables fine-grained authorization policies managed through the Access Manager system. The feature is opt-in and requires explicit configuration of both the M2M credentials and runtime flags.

**Operational impact:**  
- **When `IDP_DECLARATION_ENABLED` is not set or set to `"false"`:** The new credentials are ignored, and the application behaves exactly as in v2.5.0
- **When `IDP_DECLARATION_ENABLED="true"`:** The application requires both `IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` to be set, along with `IDP_HOST`. If these are missing, the application will refuse to start
- The credentials are read from the application Secret and injected into the deployment via the existing `envFrom: secretRef` mechanism

**Migration required:**  
No — the feature is opt-in. See [Migration Steps](#migration-steps) if you want to enable Access Manager integration.

## Configuration Reference

### New Secret Fields

The following fields have been added to `bankTransfer.secrets`:

| Field | Default | Required | Description |
|-------|---------|----------|-------------|
| `IDP_M2M_CLIENT_ID` | `""` (empty) | Only when `IDP_DECLARATION_ENABLED="true"` | Machine-to-machine client ID for Access Manager permission declaration |
| `IDP_M2M_CLIENT_SECRET` | `""` (empty) | Only when `IDP_DECLARATION_ENABLED="true"` | Machine-to-machine client secret for Access Manager permission declaration |

### New Environment Variables

The following environment variables are now supported by the application (set via `bankTransfer.configmap` or `bankTransfer.extraEnvVars`):

| Variable | Default | Description |
|----------|---------|-------------|
| `IDP_DECLARATION_ENABLED` | `"false"` (implicit) | Enables Access Manager permission declaration at startup. When `"true"`, requires `IDP_HOST`, `IDP_M2M_CLIENT_ID`, and `IDP_M2M_CLIENT_SECRET` |
| `IDP_HOST` | `""` (empty) | Access Manager (Identity Provider) host URL. Required when `IDP_DECLARATION_ENABLED="true"` |

> **Note:** These variables are **not** set by default in the chart. Operators must add them explicitly via `bankTransfer.configmap` or `bankTransfer.extraEnvVars` to enable the feature.

## Migration Steps

### Step 1: Determine If You Need Access Manager Integration

Access Manager permission declaration is an **optional** feature. You only need to configure it if:

- Your organization uses a centralized Access Manager (Identity Provider) for authorization policies
- You want the plugin to register its resource permissions (RI) at startup
- You have been instructed by your platform team to enable `IDP_DECLARATION_ENABLED`

If you do not use Access Manager or are unsure, **skip to [Command to upgrade](#command-to-upgrade)** — no configuration changes are required.

### Step 2: Configure Access Manager Credentials (Optional)

If you need to enable Access Manager integration, follow these steps:

#### Option 1: Use Helm values (recommended for non-production)

Create or update your `values-override.yaml` file with the Access Manager configuration:

```yaml
bankTransfer:
  configmap:
    # Enable Access Manager permission declaration
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "https://access-manager.example.com"

  secrets:
    # M2M client credentials for Access Manager
    IDP_M2M_CLIENT_ID: "<your-client-id>"
    IDP_M2M_CLIENT_SECRET: "<your-client-secret>"
```

> **Important:** Replace `<your-client-id>` and `<your-client-secret>` with the actual credentials provided by your Access Manager administrator. Replace `https://access-manager.example.com` with your Access Manager host URL.

#### Option 2: Use existing Kubernetes Secrets (recommended for production)

Create a Secret containing the M2M credentials:

```bash
kubectl create secret generic my-app-secret \
  --from-literal=IDP_M2M_CLIENT_ID='<your-client-id>' \
  --from-literal=IDP_M2M_CLIENT_SECRET='<your-client-secret>' \
  --dry-run=client -o yaml | kubectl apply -f - -n plugin-br-bank-transfer
```

Reference the Secret and set the runtime flags in your `values-override.yaml`:

```yaml
bankTransfer:
  useExistingSecret: true
  existingSecretName: "my-app-secret"

  configmap:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "https://access-manager.example.com"
```

> **Warning:** If you set `IDP_DECLARATION_ENABLED="true"` without providing valid `IDP_M2M_CLIENT_ID`, `IDP_M2M_CLIENT_SECRET`, and `IDP_HOST`, the application will fail to start. Ensure all three values are configured before enabling the feature.

#### Option 3: Use extraEnvVars for runtime flags

If you prefer to keep runtime flags separate from the ConfigMap, use `extraEnvVars`:

```yaml
bankTransfer:
  secrets:
    IDP_M2M_CLIENT_ID: "<your-client-id>"
    IDP_M2M_CLIENT_SECRET: "<your-client-secret>"

  extraEnvVars:
    - name: IDP_DECLARATION_ENABLED
      value: "true"
    - name: IDP_HOST
      value: "https://access-manager.example.com"
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.6.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.6.0 -n plugin-br-bank-transfer
```

> **Note:** If you are enabling Access Manager integration, add `-f values-override.yaml` to the command above, where `values-override.yaml` contains the configuration from [Step 2](#step-2-configure-access-manager-credentials-optional).
<!-- {% endraw %} -->
