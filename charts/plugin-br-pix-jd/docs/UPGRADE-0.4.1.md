# Helm Upgrade from v0.4.0 to v0.4.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. JD_BANK_ID Renamed to JD_ISPB](#1-jd_bank_id-renamed-to-jd_ispb)
  - [2. Multi-Tenant ISPB Validation Logic](#2-multi-tenant-ispb-validation-logic)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Update Configuration Variable Name](#step-1-update-configuration-variable-name)
  - [Step 2: Verify Multi-Tenant Configuration](#step-2-verify-multi-tenant-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** that renames a critical configuration variable and refines validation logic for multi-tenant deployments. The chart version increments from 0.4.0 to 0.4.1 with no changes to the application version.

| Setting | v0.4.0 | v0.4.1 |
|---------|--------|--------|
| Chart Version | 0.4.0 | 0.4.1 |
| App Version | (unchanged) | (unchanged) |

## Fixes

### 1. JD_BANK_ID Renamed to JD_ISPB

The environment variable `JD_BANK_ID` has been renamed to `JD_ISPB` to align with the application's internal naming conventions and clarify that this value represents the plugin's own ISPB (Identificador do Sistema de Pagamentos Brasileiro).

**Variable name change:**

| Variable | v0.4.0 | v0.4.1 |
|---------|--------|--------|
| ISPB identifier | `JD_BANK_ID` | `JD_ISPB` |

**Before (v0.4.0):**

```yaml
JD_BANK_ID: {{ $bankId | quote }}
```

**After (v0.4.1):**

```yaml
JD_ISPB: {{ $ispb | quote }}
```

**Operational impact:**

The application reads this variable to identify the plugin's own ISPB. The worker gates **every MED poller** on this value being exactly 8 characters. If the length does not match, the worker skips all MED pollers with a single WARN log entry — including `med_settlement_reconcile`, which commits or cancels reserved money.

> **Important:** This is a **breaking change** for existing deployments that explicitly set `JD_BANK_ID` in their values. The old variable name is no longer recognized by the chart. You must update your configuration to use `JD_ISPB` before upgrading.

### 2. Multi-Tenant ISPB Validation Logic

The chart now distinguishes between **single-tenant** and **multi-tenant** worker modes when validating the ISPB configuration:

- **Single-tenant mode** (default): `JD_ISPB` is required and must be exactly 8 characters
- **Multi-tenant mode** (`MULTI_TENANT_ENABLED=true`): `JD_ISPB` is optional because the worker resolves the ISPB from each tenant binding

**Validation behavior:**

| Mode | Worker Enabled | JD_ISPB Missing | JD_ISPB Wrong Length | Result |
|------|----------------|-----------------|---------------------|--------|
| Single-tenant | Yes | ❌ Render fails | ❌ Render fails | Must be exactly 8 chars |
| Single-tenant | No | ⚠️ Warning only | ❌ Render fails | Length always validated |
| Multi-tenant | Yes | ✅ Allowed | ❌ Render fails | Resolved per tenant |
| Multi-tenant | No | ✅ Allowed | ❌ Render fails | Length always validated |

**Before (v0.4.0):**

```yaml
{{- $bankId := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_BANK_ID" "default" "") -}}
{{- if and $bankId (ne (len $bankId) 8) -}}
{{- fail (printf "\n\nERROR: JD_BANK_ID must be exactly 8 characters (an ISPB); got %d.\n..." (len $bankId)) -}}
{{- end }}
```

The old logic rejected only **malformed** values (wrong length when present), but allowed a missing value even in single-tenant mode.

**After (v0.4.1):**

```yaml
{{- $ispb := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_ISPB" "default" "") -}}
{{- $multiTenant := eq (include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MULTI_TENANT_ENABLED" "default" "false")) "true" -}}
{{- if or (and $ispb (ne (len $ispb) 8)) (and $root.Values.worker.enabled (not $multiTenant) (not $ispb)) -}}
{{- fail (printf "\n\nERROR: JD_ISPB must be exactly 8 characters when the worker runs in single-tenant mode; got %d.\n..." (len $ispb)) -}}
{{- end }}
```

The new logic:
1. Always rejects malformed values (wrong length when present)
2. Rejects a **missing** value when the worker is enabled in single-tenant mode
3. Allows a missing value in multi-tenant mode (resolved per tenant)

**Operational impact:**

If you are running the worker in single-tenant mode without setting `JD_ISPB`, the chart will now **fail at render time** with a clear error message. This prevents silent degradation of the money path.

> **Warning:** Deployments with `worker.enabled=true` and no `JD_ISPB` configured will fail to render after this upgrade. You must set a valid 8-character ISPB before upgrading.

## Migration Steps

### Step 1: Update Configuration Variable Name

If your existing `values.yaml` explicitly sets `JD_BANK_ID`, rename it to `JD_ISPB`:

**Before (v0.4.0):**

```yaml
api:
  configmap:
    JD_BANK_ID: "12345678"
```

**After (v0.4.1):**

```yaml
api:
  configmap:
    JD_ISPB: "12345678"
```

If you are using the worker component, apply the same change to `worker.configmap`:

```yaml
worker:
  configmap:
    JD_ISPB: "12345678"
```

> **Note:** If you did not explicitly set `JD_BANK_ID` in your values (relying on a default or external configuration), no action is required for this step.

### Step 2: Verify Multi-Tenant Configuration

If you are running the worker in **single-tenant mode** (the default), ensure `JD_ISPB` is set and exactly 8 characters:

```yaml
worker:
  enabled: true

api:
  configmap:
    JD_ISPB: "12345678"
    MULTI_TENANT_ENABLED: "false"  # or omit (defaults to false)
```

If you are running in **multi-tenant mode**, the ISPB is resolved per tenant and `JD_ISPB` is optional:

```yaml
worker:
  enabled: true

api:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    TENANT_MANAGER_URL: "https://tenant-manager.example.com"
    # JD_ISPB is optional in this mode
```

> **Important:** If `worker.enabled=true`, `MULTI_TENANT_ENABLED=false` (or unset), and `JD_ISPB` is missing or not exactly 8 characters, the chart will fail to render with an error message explaining the requirement.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.1 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.1 -n plugin-br-pix-jd
```
