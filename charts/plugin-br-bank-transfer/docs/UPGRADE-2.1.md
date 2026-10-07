# Helm Upgrade from v2.0.2 to v2.1.0

## Topics

- **[Overview](#overview)**
- **[New Features](#new-features)**
  - [1. Courier Outbound Integration](#1-courier-outbound-integration)
  - [2. TRUSTED_PROXIES Configuration](#2-trusted_proxies-configuration)
  - [3. Application Version Update](#3-application-version-update)
- **[Configuration Reference](#configuration-reference)**
  - [New ConfigMap Fields](#new-configmap-fields)
  - [New Secret Fields](#new-secret-fields)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Courier Integration Requirements](#step-1-review-courier-integration-requirements)
  - [Step 2: Configure TRUSTED_PROXIES (Optional)](#step-2-configure-trusted_proxies-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.1.0 introduces optional support for the Courier outbound integration (added in application version 2.2.0), a new `TRUSTED_PROXIES` configuration field to complement the existing `SERVER_TRUSTED_PROXIES` setting, and updates the application image from 2.1.2 to 2.2.0. This is a **non-breaking** minor release — all new features are optional and require explicit configuration to activate.

Operators who do not use the Courier integration or need additional proxy configuration can upgrade without any changes to their existing values files.

## New Features

### 1. Courier Outbound Integration

**What changed:**  
The chart now supports configuration for the Courier outbound integration, an optional notification/delivery service added in application version 2.2.0. The integration requires a base URL (set in the ConfigMap) and M2M credentials (set in the Secret).

**Configuration fields:**

| Field | Location | Required | Description |
|-------|----------|----------|-------------|
| `COURIER_BASE_URL` | `bankTransfer.configmap` | No | Base URL for the Courier service |
| `COURIER_CLIENT_ID` | `bankTransfer.secrets` | No | M2M client ID for Courier authentication |
| `COURIER_CLIENT_SECRET` | `bankTransfer.secrets` | No | M2M client secret for Courier authentication |

**Template changes:**

**ConfigMap (templates/configmap.yaml):**

**After (v2.1.0):**
```yaml
# Courier (outbound notification/delivery integration, added in app 2.2.0).
# Optional — rendered only when configured; the M2M CLIENT_ID/CLIENT_SECRET
# live in the Secret (see templates/secrets.yaml), like CRM/FEES.
{{- if .Values.bankTransfer.configmap.COURIER_BASE_URL }}
COURIER_BASE_URL: {{ .Values.bankTransfer.configmap.COURIER_BASE_URL | quote }}
{{- end }}
```

**Secret (templates/secrets.yaml):**

**After (v2.1.0):**
```yaml
# Courier Outbound M2M Credentials (optional - courier integration, added in app 2.2.0)
{{- if .Values.bankTransfer.secrets.COURIER_CLIENT_ID }}
COURIER_CLIENT_ID: {{ .Values.bankTransfer.secrets.COURIER_CLIENT_ID | quote }}
{{- end }}
{{- if .Values.bankTransfer.secrets.COURIER_CLIENT_SECRET }}
COURIER_CLIENT_SECRET: {{ .Values.bankTransfer.secrets.COURIER_CLIENT_SECRET | quote }}
{{- end }}
```

**Why it matters:**  
The Courier integration enables the application to send outbound notifications or delivery events to external systems. The credentials follow the same pattern as existing integrations (CRM, FEES) — the base URL is public configuration (ConfigMap), while authentication credentials are sensitive (Secret).

**Operational impact:**  
- The integration is **opt-in** — if you do not set `COURIER_BASE_URL`, no Courier-related environment variables are rendered
- If you set `COURIER_BASE_URL` but omit the credentials, the application will attempt to connect to Courier without authentication (behavior depends on the Courier service configuration)
- The application deployment reads these values from the ConfigMap and Secret via `envFrom` (no template changes to the Deployment resource)

**When to use:**  
Enable this integration if your deployment requires outbound notification delivery via the Courier service. Consult your application team or Courier service documentation for the correct base URL and credential provisioning process.

### 2. TRUSTED_PROXIES Configuration

**What changed:**  
A new optional `TRUSTED_PROXIES` configuration field has been added to complement the existing `SERVER_TRUSTED_PROXIES` setting.

**Before (v2.0.2):**
```yaml
bankTransfer:
  configmap:
    SERVER_TRUSTED_PROXIES: ""  # Only this field existed
```

**After (v2.1.0):**
```yaml
bankTransfer:
  configmap:
    SERVER_TRUSTED_PROXIES: ""
    TRUSTED_PROXIES: ""  # New optional field
```

**Template changes:**

**ConfigMap (templates/configmap.yaml):**

**After (v2.1.0):**
```yaml
{{- if .Values.bankTransfer.configmap.SERVER_TRUSTED_PROXIES }}
SERVER_TRUSTED_PROXIES: {{ .Values.bankTransfer.configmap.SERVER_TRUSTED_PROXIES | quote }}
{{- end }}
{{- if .Values.bankTransfer.configmap.TRUSTED_PROXIES }}
TRUSTED_PROXIES: {{ .Values.bankTransfer.configmap.TRUSTED_PROXIES | quote }}
{{- end }}
```

**Why it matters:**  
The `TRUSTED_PROXIES` field provides an additional mechanism for configuring proxy trust relationships in the application. The exact behavior depends on the application's internal proxy handling logic (consult application documentation for details on how `TRUSTED_PROXIES` differs from `SERVER_TRUSTED_PROXIES`).

**Operational impact:**  
- The field is **optional** — if not set, it is not rendered in the ConfigMap
- Existing `SERVER_TRUSTED_PROXIES` configuration is unaffected
- Both fields can be set independently

**When to use:**  
Set this field if your application team or deployment architecture requires a separate proxy trust configuration distinct from `SERVER_TRUSTED_PROXIES`. Most deployments will not need to set this field.

### 3. Application Version Update

**What changed:**  
The application image tag and appVersion have been updated to reflect the new application release.

| Setting | v2.0.2 | v2.1.0 |
|---------|--------|--------|
| Chart version | `2.0.2` | `2.1.0` |
| App version (`appVersion`) | `2.1.2` | `2.2.0` |
| Default image tag (`bankTransfer.image.tag`) | `2.1.2` | `2.2.0` |

**Why it matters:**  
Application version 2.2.0 includes the Courier integration support and any other features, bug fixes, or security patches released by the application team. Refer to the application's release notes for a complete list of changes in version 2.2.0.

**Operational impact:**  
- The Deployment will pull the new image tag (`2.2.0`) on upgrade
- Existing pods will be replaced with new pods running the updated application version (standard rolling update behavior)
- If you override `bankTransfer.image.tag` in your values, you must update it manually to `2.2.0` (or your preferred tag) to receive the application updates

## Configuration Reference

### New ConfigMap Fields

The following fields have been added to `bankTransfer.configmap`:

| Field | Default | Description |
|-------|---------|-------------|
| `COURIER_BASE_URL` | `""` (not rendered) | Base URL for the Courier outbound integration service (optional) |
| `TRUSTED_PROXIES` | `""` (not rendered) | Additional proxy trust configuration, complements `SERVER_TRUSTED_PROXIES` (optional) |

**Example configuration:**

```yaml
bankTransfer:
  configmap:
    # Enable Courier integration
    COURIER_BASE_URL: "https://courier.example.com"
    
    # Configure additional proxy trust (optional)
    TRUSTED_PROXIES: "10.0.0.0/8,172.16.0.0/12"
```

### New Secret Fields

The following fields have been added to `bankTransfer.secrets`:

| Field | Default | Description |
|-------|---------|-------------|
| `COURIER_CLIENT_ID` | `""` (not rendered) | M2M client ID for Courier authentication (optional) |
| `COURIER_CLIENT_SECRET` | `""` (not rendered) | M2M client secret for Courier authentication (optional) |

**Example configuration:**

```yaml
bankTransfer:
  secrets:
    COURIER_CLIENT_ID: "courier-client-abc123"
    COURIER_CLIENT_SECRET: "courier-secret-xyz789"
```

> **Important:** Like other M2M credentials (CRM, FEES), Courier credentials should be managed via a secure secret management system in production. Consider using `bankTransfer.useExistingSecret=true` and referencing an externally managed Secret instead of embedding credentials in your values file.

## Migration Steps

### Step 1: Review Courier Integration Requirements

If your deployment requires the Courier outbound integration, configure the base URL and credentials in your values file.

#### Option 1: Enable Courier Integration

Add the following to your `values-override.yaml`:

```yaml
bankTransfer:
  configmap:
    COURIER_BASE_URL: "https://courier.example.com"
  
  secrets:
    COURIER_CLIENT_ID: "your-courier-client-id"
    COURIER_CLIENT_SECRET: "your-courier-client-secret"
```

> **Note:** Replace `https://courier.example.com` with your actual Courier service URL, and provision the client ID/secret according to your Courier service's authentication requirements.

#### Option 2: Skip Courier Integration

If you do not use Courier, no action is required — the integration is opt-in and will not be configured unless you explicitly set `COURIER_BASE_URL`.

### Step 2: Configure TRUSTED_PROXIES (Optional)

If your deployment requires the new `TRUSTED_PROXIES` configuration (consult your application team or network architecture documentation), add it to your values file.

**Example:**

```yaml
bankTransfer:
  configmap:
    TRUSTED_PROXIES: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

> **Note:** Most deployments will not need to set this field. Only configure it if explicitly required by your application team or infrastructure setup.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.0 -n plugin-br-bank-transfer
```
