<!-- {% raw %} -->
# Helm Upgrade from v2.7.0 to v2.8.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Courier Account Claims Sweep](#1-courier-account-claims-sweep)
- **[Configuration Reference](#configuration-reference)**
  - [New Environment Variables](#new-environment-variables)
  - [New Validation Rules](#new-validation-rules)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Courier Integration Requirements](#step-1-review-courier-integration-requirements)
  - [Step 2: Configure COURIER_ACCOUNT_CLAIMS_ENABLED (Optional)](#step-2-configure-courier_account_claims_enabled-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.8.0 introduces a new optional feature for Courier integration: the account claims sweep. This release updates the application from v3.1.0 to v3.2.0 and adds a new configuration flag (`COURIER_ACCOUNT_CLAIMS_ENABLED`) that controls whether the bank-transfer engine claims its CRM accounts on the Courier service. The feature is **disabled by default** and requires additional configuration when enabled in single-tenant mode.

This is a **non-breaking** release. Existing deployments will continue to work without configuration changes. Operators who wish to enable the new account claims feature must follow the migration steps below.

## Features

### 1. Courier Account Claims Sweep

**What changed:**  
The application now supports an optional sweep process that claims the bank-transfer engine's CRM accounts on the Courier service. This feature is controlled by a new environment variable `COURIER_ACCOUNT_CLAIMS_ENABLED` (added in app v3.2.0).

**Version changes:**

| Component | v2.7.0 | v2.8.0 |
|-----------|--------|--------|
| Chart version | `2.7.0` | `2.8.0` |
| App version | `3.1.0` | `3.2.0` |
| Image tag | `3.1.0` | `3.2.0` |

**Default behavior:**  
The feature is **disabled by default** (`COURIER_ACCOUNT_CLAIMS_ENABLED: "false"`). When disabled, the application behaves exactly as in v2.7.0 — no account claims sweep runs, and no additional Courier configuration is required.

**When enabled (`COURIER_ACCOUNT_CLAIMS_ENABLED: "true"`):**

The application performs a sweep that claims CRM accounts on the Courier. The configuration requirements differ by deployment mode:

**Single-tenant mode:**  
The chart enforces the following required fields at Helm install/upgrade time (the application will refuse to boot without them):

- `bankTransfer.configmap.COURIER_BASE_URL` — the Courier service base URL
- `bankTransfer.configmap.ORGANIZATION_ID` — the organization identifier
- `bankTransfer.secrets.COURIER_CLIENT_ID` — OAuth2 client ID for Courier authentication
- `bankTransfer.secrets.COURIER_CLIENT_SECRET` — OAuth2 client secret for Courier authentication
- `bankTransfer.configmap.CRM_BASE_URL` — the CRM service base URL (already required for CRM integration)
- `bankTransfer.configmap.PLUGIN_AUTH_ADDRESS` — the plugin authentication service address (already required)

**Multi-tenant mode:**  
The Courier base URL and credentials are read from each tenant's JD bundle. Only `CRM_BASE_URL` and `PLUGIN_AUTH_ADDRESS` are required (these are already mandatory for multi-tenant CRM integration).

**Template changes:**

The chart adds new validation logic to `templates/configmap.yaml` that checks for required fields when `COURIER_ACCOUNT_CLAIMS_ENABLED=true` in single-tenant mode:

**Before (v2.7.0):**
```yaml
# templates/configmap.yaml (excerpt)
{{- if .Values.bankTransfer.configmap.COURIER_BASE_URL }}
COURIER_BASE_URL: {{ .Values.bankTransfer.configmap.COURIER_BASE_URL | quote }}
{{- end }}
```

**After (v2.8.0):**
```yaml
# templates/configmap.yaml (excerpt)
{{- if .Values.bankTransfer.configmap.COURIER_BASE_URL }}
COURIER_BASE_URL: {{ .Values.bankTransfer.configmap.COURIER_BASE_URL | quote }}
{{- end }}

# COURIER_ACCOUNT_CLAIMS_ENABLED (app v3.2.0+): the sweep that claims this
# engine's CRM accounts on the Courier, in both modes. Defaults to the app's
# own "false". When "true" the app refuses to boot without CRM_BASE_URL and
# PLUGIN_AUTH_ADDRESS, plus, single-tenant only, COURIER_BASE_URL, the
# COURIER_CLIENT_ID/COURIER_CLIENT_SECRET pair and ORGANIZATION_ID
# (multi-tenant reads the Courier per tenant). Left to an existing
# bankTransfer.extraEnvVars entry when one is set.
{{- $courierExtra := .Values.bankTransfer.extraEnvVars | default dict }}
{{- $claims := toString (index $cm "COURIER_ACCOUNT_CLAIMS_ENABLED" | default "false") }}
{{- if not (hasKey $courierExtra "COURIER_ACCOUNT_CLAIMS_ENABLED") }}
COURIER_ACCOUNT_CLAIMS_ENABLED: {{ $claims | quote }}
{{- end }}
{{- if and (eq (lower $claims) "true") (not $multiTenantEnabled) }}
{{- if not (or .Values.bankTransfer.configmap.COURIER_BASE_URL (index $courierExtra "COURIER_BASE_URL")) }}
{{- fail "\n\nERROR: bankTransfer.configmap.COURIER_BASE_URL is required when COURIER_ACCOUNT_CLAIMS_ENABLED=true in single-tenant mode (the app refuses to boot without it).\n" }}
{{- end }}
{{- if not (or .Values.bankTransfer.configmap.ORGANIZATION_ID (index $courierExtra "ORGANIZATION_ID")) }}
{{- fail "\n\nERROR: bankTransfer.configmap.ORGANIZATION_ID is required when COURIER_ACCOUNT_CLAIMS_ENABLED=true in single-tenant mode (the app refuses to boot without it).\n" }}
{{- end }}
{{- end }}
```

**Operational impact:**

- **Default behavior (disabled):** No impact. The chart renders `COURIER_ACCOUNT_CLAIMS_ENABLED: "false"` in the ConfigMap, and the application does not run the account claims sweep.
- **When enabled in single-tenant mode:** The chart validates that `COURIER_BASE_URL` and `ORGANIZATION_ID` are set at Helm install/upgrade time. If either is missing, the upgrade will fail with a clear error message. The application will also refuse to boot if `COURIER_CLIENT_ID`, `COURIER_CLIENT_SECRET`, `CRM_BASE_URL`, or `PLUGIN_AUTH_ADDRESS` are missing.
- **When enabled in multi-tenant mode:** The chart does not enforce `COURIER_BASE_URL` or `ORGANIZATION_ID` (these are read from tenant bundles), but the application still requires `CRM_BASE_URL` and `PLUGIN_AUTH_ADDRESS`.

**Why it matters:**  
This feature enables automatic account provisioning workflows for deployments that use the Courier service. Operators who do not use Courier can ignore this feature entirely. Operators who wish to enable it must ensure all required configuration is in place before setting `COURIER_ACCOUNT_CLAIMS_ENABLED: "true"`.

## Configuration Reference

### New Environment Variables

The following environment variable has been added to the application ConfigMap:

| Variable | Default | Description |
|----------|---------|-------------|
| `COURIER_ACCOUNT_CLAIMS_ENABLED` | `"false"` | Enables the sweep that claims this engine's CRM accounts on the Courier. When `"true"`, the application requires `CRM_BASE_URL` and `PLUGIN_AUTH_ADDRESS` in all modes, plus `COURIER_BASE_URL`, `COURIER_CLIENT_ID`, `COURIER_CLIENT_SECRET`, and `ORGANIZATION_ID` in single-tenant mode. Multi-tenant mode reads Courier configuration from tenant JD bundles. |

**values.yaml documentation (excerpt):**

```yaml
bankTransfer:
  configmap:
    # COURIER_ACCOUNT_CLAIMS_ENABLED (app v3.2.0+) turns on the sweep that
    # claims this engine's CRM accounts on the Courier. Rendered with the app
    # default "false". When "true", single-tenant also needs COURIER_BASE_URL,
    # the COURIER_CLIENT_ID/COURIER_CLIENT_SECRET pair and ORGANIZATION_ID;
    # multi-tenant reads the Courier from each tenant's JD bundle.
    # COURIER_ACCOUNT_CLAIMS_ENABLED: "false"
```

### New Validation Rules

The chart now enforces the following validation rules when `COURIER_ACCOUNT_CLAIMS_ENABLED=true` in single-tenant mode:

| Field | Required When | Validation Error |
|-------|---------------|------------------|
| `bankTransfer.configmap.COURIER_BASE_URL` | `COURIER_ACCOUNT_CLAIMS_ENABLED=true` and single-tenant mode | `ERROR: bankTransfer.configmap.COURIER_BASE_URL is required when COURIER_ACCOUNT_CLAIMS_ENABLED=true in single-tenant mode (the app refuses to boot without it).` |
| `bankTransfer.configmap.ORGANIZATION_ID` | `COURIER_ACCOUNT_CLAIMS_ENABLED=true` and single-tenant mode | `ERROR: bankTransfer.configmap.ORGANIZATION_ID is required when COURIER_ACCOUNT_CLAIMS_ENABLED=true in single-tenant mode (the app refuses to boot without it).` |

> **Note:** The chart validates `COURIER_BASE_URL` and `ORGANIZATION_ID` at Helm upgrade time. The application validates `COURIER_CLIENT_ID`, `COURIER_CLIENT_SECRET`, `CRM_BASE_URL`, and `PLUGIN_AUTH_ADDRESS` at boot time.

## Migration Steps

### Step 1: Review Courier Integration Requirements

Determine whether you need to enable the new account claims feature:

- **If you do not use the Courier service:** No action required. The feature is disabled by default, and your deployment will continue to work as in v2.7.0.
- **If you use the Courier service and want to enable account claims:** Proceed to Step 2.

### Step 2: Configure COURIER_ACCOUNT_CLAIMS_ENABLED (Optional)

If you wish to enable the account claims sweep, follow the instructions for your deployment mode:

#### Option 1: Enable in Single-Tenant Mode

Add the following configuration to your `values-override.yaml`:

```yaml
bankTransfer:
  configmap:
    # Enable the account claims sweep
    COURIER_ACCOUNT_CLAIMS_ENABLED: "true"
    
    # Required: Courier service base URL
    COURIER_BASE_URL: "https://courier.example.com"
    
    # Required: Organization identifier
    ORGANIZATION_ID: "your-org-id"
    
    # Required: CRM service base URL (if not already set)
    CRM_BASE_URL: "https://crm.example.com"
    
    # Required: Plugin authentication service address (if not already set)
    PLUGIN_AUTH_ADDRESS: "https://plugin-auth.example.com"
  
  secrets:
    # Required: Courier OAuth2 credentials
    COURIER_CLIENT_ID: "your-courier-client-id"
    COURIER_CLIENT_SECRET: "your-courier-client-secret"
```

> **Important:** All fields listed above are **required** when `COURIER_ACCOUNT_CLAIMS_ENABLED=true` in single-tenant mode. The Helm upgrade will fail if `COURIER_BASE_URL` or `ORGANIZATION_ID` are missing. The application will refuse to boot if `COURIER_CLIENT_ID`, `COURIER_CLIENT_SECRET`, `CRM_BASE_URL`, or `PLUGIN_AUTH_ADDRESS` are missing.

#### Option 2: Enable in Multi-Tenant Mode

Add the following configuration to your `values-override.yaml`:

```yaml
bankTransfer:
  configmap:
    # Enable the account claims sweep
    COURIER_ACCOUNT_CLAIMS_ENABLED: "true"
    
    # Required: CRM service base URL (if not already set)
    CRM_BASE_URL: "https://crm.example.com"
    
    # Required: Plugin authentication service address (if not already set)
    PLUGIN_AUTH_ADDRESS: "https://plugin-auth.example.com"
```

> **Note:** In multi-tenant mode, `COURIER_BASE_URL`, `COURIER_CLIENT_ID`, `COURIER_CLIENT_SECRET`, and `ORGANIZATION_ID` are read from each tenant's JD bundle. You do not need to set them in the chart values.

#### Option 3: Keep the Feature Disabled (Default)

No configuration changes are required. The chart will render `COURIER_ACCOUNT_CLAIMS_ENABLED: "false"` in the ConfigMap, and the application will not run the account claims sweep.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.8.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.8.0 -n plugin-br-bank-transfer
```
<!-- {% endraw %} -->
