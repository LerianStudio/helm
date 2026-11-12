<!-- {% raw %} -->
# Helm Upgrade from v3.2.1 to v3.2.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Indentation Correction in values.yaml](#1-indentation-correction-in-valuesyaml)
  - [2. New Validation for Misplaced Credentials](#2-new-validation-for-misplaced-credentials)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Verify Your Credentials Placement](#step-1-verify-your-credentials-placement)
  - [Step 2: Review Indentation Changes (No Action Required)](#step-2-review-indentation-changes-no-action-required)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.2.2 is a **patch release** that fixes documentation indentation in `values.yaml` and adds a new validation rule to prevent configuration errors. The chart now detects when credentials or environment variables are accidentally placed directly under `bankTransfer` instead of under `bankTransfer.secrets` or `bankTransfer.configmap`, and fails the upgrade with a clear error message.

This release does **not** change the application version, container image, or any runtime behavior. The only template change is a new validation block in `templates/configmap.yaml` that catches common configuration mistakes before they cause silent failures.

**Version changes:**

| Component | v3.2.1 | v3.2.2 |
|-----------|--------|--------|
| Chart version | `3.2.1` | `3.2.2` |
| App version | `3.6.0` | `3.6.0` |
| Image tag | `3.6.0` | `3.6.0` |

**Breaking changes:** None. Existing deployments will continue to work without configuration changes, unless your `values.yaml` contains credentials placed directly under `bankTransfer` (which would not have worked correctly in v3.2.1 either).

## Fixes

### 1. Indentation Correction in values.yaml

**What changed:**  
The documentation comments for optional credentials in `values.yaml` were incorrectly indented at the same level as `bankTransfer.secrets`, making them appear as top-level `bankTransfer` keys. This has been corrected to show that all credentials belong under the `secrets` block.

**Before (v3.2.1):**

```yaml
bankTransfer:
  secrets:
    # Midaz M2M Credentials (optional)
    # MIDAZ_CLIENT_ID: ""
    # MIDAZ_CLIENT_SECRET: ""
  # Streaming credentials (optional — only required when a SASL mechanism
  # is configured via global.streaming.saslMechanism)
  # STREAMING_SASL_PASSWORD: ""
  # STREAMING_TLS_CA_CERT: ""

  # Multi-tenant (only when MULTI_TENANT_ENABLED=true). Redis CA: only when
  # MULTI_TENANT_REDIS_TLS=true and the cluster's CA isn't in the system trust pool.
  # MULTI_TENANT_SERVICE_API_KEY: ""  # REQUIRED when MULTI_TENANT_ENABLED=true
  # MULTI_TENANT_REDIS_PASSWORD: ""
  # MULTI_TENANT_REDIS_CA_CERT: ""

  # RabbitMQ credentials (when RABBITMQ_ENABLED=true; RABBITMQ_URL is required,
  # amqps:// outside development/test/local)
  # RABBITMQ_URL: ""
  # RABBITMQ_EVENT_SIGNING_SECRET: ""

  # Webhook secrets (when WEBHOOK_ENABLED=true)
  # WEBHOOK_SIGNING_SECRET: ""
  # WEBHOOK_BROKER_EVENT_SIGNING_SECRET: ""

  # Courier outbound M2M credentials (courier integration, added in app 2.2.0)
  # COURIER_CLIENT_ID: ""
  # COURIER_CLIENT_SECRET: ""

  # Access Manager permission declaration (RI) client pair, used only when
  # IDP_DECLARATION_ENABLED="true" (configmap.IDP_DECLARATION_ENABLED / IDP_HOST, or
  # global.idp.{declarationEnabled,host}). With useExistingSecret=true the chart renders
  # neither key: the existing Secret must carry both.
  # IDP_M2M_CLIENT_ID: ""
  # IDP_M2M_CLIENT_SECRET: ""
```

**After (v3.2.2):**

```yaml
bankTransfer:
  secrets:
    # Midaz M2M Credentials (optional)
    # MIDAZ_CLIENT_ID: ""
    # MIDAZ_CLIENT_SECRET: ""
    # Streaming credentials (optional — only required when a SASL mechanism
    # is configured via global.streaming.saslMechanism)
    # STREAMING_SASL_PASSWORD: ""
    # STREAMING_TLS_CA_CERT: ""

    # Multi-tenant (only when MULTI_TENANT_ENABLED=true). Redis CA: only when
    # MULTI_TENANT_REDIS_TLS=true and the cluster's CA isn't in the system trust pool.
    # MULTI_TENANT_SERVICE_API_KEY: ""  # REQUIRED when MULTI_TENANT_ENABLED=true
    # MULTI_TENANT_REDIS_PASSWORD: ""
    # MULTI_TENANT_REDIS_CA_CERT: ""

    # RabbitMQ credentials (when RABBITMQ_ENABLED=true; RABBITMQ_URL is required,
    # amqps:// outside development/test/local)
    # RABBITMQ_URL: ""
    # RABBITMQ_EVENT_SIGNING_SECRET: ""

    # Webhook secrets (when WEBHOOK_ENABLED=true)
    # WEBHOOK_SIGNING_SECRET: ""
    # WEBHOOK_BROKER_EVENT_SIGNING_SECRET: ""

    # Courier outbound M2M credentials (courier integration, added in app 2.2.0)
    # COURIER_CLIENT_ID: ""
    # COURIER_CLIENT_SECRET: ""

    # Access Manager permission declaration (RI) client pair, used only when
    # IDP_DECLARATION_ENABLED="true" (configmap.IDP_DECLARATION_ENABLED / IDP_HOST, or
    # global.idp.{declarationEnabled,host}). With useExistingSecret=true the chart renders
    # neither key: the existing Secret must carry both.
    # IDP_M2M_CLIENT_ID: ""
    # IDP_M2M_CLIENT_SECRET: ""
```

**Why it matters:**  
The incorrect indentation in v3.2.1 could mislead operators into placing credentials directly under `bankTransfer` when uncommenting example values. This would cause the credentials to be silently ignored by the chart templates, leading to application boot failures or missing configuration. The corrected indentation makes it clear that all credentials must be nested under `bankTransfer.secrets`.

**Operational impact:**  
This is a **documentation-only change**. If your existing `values.yaml` already places credentials under `bankTransfer.secrets` (the correct location), no action is required. If you have credentials placed directly under `bankTransfer`, the new validation in Fix #2 will catch this error during upgrade.

### 2. New Validation for Misplaced Credentials

**What changed:**  
The chart now validates that no UPPER_CASE keys (e.g., `STREAMING_SASL_PASSWORD`, `RABBITMQ_URL`, `IDP_M2M_CLIENT_ID`) are placed directly under `bankTransfer`. These keys are only read when placed under `bankTransfer.secrets` or `bankTransfer.configmap`. Placing them at the wrong indentation level would cause them to be silently ignored.

**Template changes:**

**Before (v3.2.1):**

```yaml
# templates/configmap.yaml (excerpt)
{{- $mtRaw := include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false") -}}
{{- $multiTenantEnabled := eq (lower (toString $mtRaw)) "true" }}
kind: ConfigMap
apiVersion: v1
metadata:
```

**After (v3.2.2):**

```yaml
# templates/configmap.yaml (excerpt)
{{- $mtRaw := include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false") -}}
{{- $multiTenantEnabled := eq (lower (toString $mtRaw)) "true" }}
{{- /* No template reads an UPPER_CASE key placed directly under bankTransfer.
   It is almost always a values.yaml example uncommented one indent level too
   shallow, which would otherwise vanish from the Secret/ConfigMap silently. */ -}}
{{- range $key, $_ := .Values.bankTransfer }}
{{- if regexMatch "^[A-Z][A-Z0-9_]*$" $key }}
{{- fail (printf "bankTransfer.%s is not read by this chart: put credentials under bankTransfer.secrets and settings under bankTransfer.configmap (check the key's indentation)" $key) }}
{{- end }}
{{- end }}
kind: ConfigMap
apiVersion: v1
metadata:
```

**Validation behavior:**

The chart now iterates over all keys directly under `bankTransfer` and checks if any match the pattern `^[A-Z][A-Z0-9_]*$` (uppercase letters, digits, and underscores). If a match is found, the Helm upgrade fails immediately with an error message:

```
Error: UPGRADE FAILED: template: plugin-br-bank-transfer/templates/configmap.yaml:19:4: executing "plugin-br-bank-transfer/templates/configmap.yaml" at <fail (printf "bankTransfer.%s is not read by this chart: put credentials under bankTransfer.secrets and settings under bankTransfer.configmap (check the key's indentation)" $key)>: error calling fail: bankTransfer.STREAMING_SASL_PASSWORD is not read by this chart: put credentials under bankTransfer.secrets and settings under bankTransfer.configmap (check the key's indentation)
```

**Why it matters:**  
In v3.2.1 and earlier, if an operator accidentally placed a credential like `STREAMING_SASL_PASSWORD` directly under `bankTransfer` (instead of under `bankTransfer.secrets`), the chart would silently ignore it. The application would then fail to boot or behave incorrectly due to missing configuration, with no clear indication of the root cause. This validation catches the mistake at Helm upgrade time, before the application is deployed.

**Operational impact:**

- **If your `values.yaml` is correctly structured:** No impact. The upgrade will proceed normally.
- **If your `values.yaml` has misplaced credentials:** The upgrade will fail with a clear error message indicating which key is misplaced and where it should be moved. You must correct the indentation before the upgrade can succeed.

**Common mistake example:**

```yaml
# INCORRECT (will fail validation in v3.2.2)
bankTransfer:
  secrets:
    MIDAZ_CLIENT_ID: "client-id"
  STREAMING_SASL_PASSWORD: "password"  # ❌ Wrong indentation level
```

```yaml
# CORRECT
bankTransfer:
  secrets:
    MIDAZ_CLIENT_ID: "client-id"
    STREAMING_SASL_PASSWORD: "password"  # ✅ Correct indentation
```

> **Important:** This validation only checks for keys placed directly under `bankTransfer`. It does not validate the structure of `bankTransfer.secrets` or `bankTransfer.configmap` — those are handled by the existing template logic.

## Migration Steps

### Step 1: Verify Your Credentials Placement

Before upgrading, review your `values.yaml` or `values-override.yaml` to ensure all credentials and environment variables are correctly nested under `bankTransfer.secrets` or `bankTransfer.configmap`.

**Check for misplaced keys:**

Look for any UPPER_CASE keys (e.g., `STREAMING_SASL_PASSWORD`, `RABBITMQ_URL`, `COURIER_CLIENT_ID`, `IDP_M2M_CLIENT_SECRET`) that are placed directly under `bankTransfer` instead of under `bankTransfer.secrets` or `bankTransfer.configmap`.

**Example of incorrect placement:**

```yaml
bankTransfer:
  secrets:
    MIDAZ_CLIENT_ID: "client-id"
  # ❌ These are at the wrong indentation level
  STREAMING_SASL_PASSWORD: "password"
  RABBITMQ_URL: "amqps://rabbitmq.example.com"
  COURIER_CLIENT_ID: "courier-client"
```

**Corrected placement:**

```yaml
bankTransfer:
  secrets:
    MIDAZ_CLIENT_ID: "client-id"
    # ✅ All credentials under bankTransfer.secrets
    STREAMING_SASL_PASSWORD: "password"
    RABBITMQ_URL: "amqps://rabbitmq.example.com"
    COURIER_CLIENT_ID: "courier-client"
```

**For configuration settings (non-secret values):**

```yaml
bankTransfer:
  configmap:
    # ✅ All non-secret settings under bankTransfer.configmap
    COURIER_BASE_URL: "https://courier.example.com"
    ORGANIZATION_ID: "org-123"
    CRM_BASE_URL: "https://crm.example.com"
```

> **Note:** If you are using `bankTransfer.useExistingSecret: true`, this validation does not apply to your external Secret resource. The validation only checks keys in the Helm values.

**Action required:**

If you find any misplaced keys, move them to the correct location (`bankTransfer.secrets` for credentials, `bankTransfer.configmap` for non-secret settings) before proceeding with the upgrade.

### Step 2: Review Indentation Changes (No Action Required)

The indentation correction in `values.yaml` is a documentation-only change. If you have been following the chart's examples correctly (placing credentials under `bankTransfer.secrets`), your existing configuration is already correct.

**No action required** unless you were planning to uncomment example values from the chart's default `values.yaml`. In that case, note that the examples now show the correct indentation.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.2.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.2.2
```
<!-- {% endraw %} -->
