# Helm Upgrade from v2.2.0 to v2.3.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Fee Mode Configuration](#1-fee-mode-configuration)
- **[Configuration Reference](#configuration-reference)**
  - [New Environment Variables](#new-environment-variables)
  - [Fee Mode Values](#fee-mode-values)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.3.0 introduces support for Midaz native fee handling (available in Midaz >= 4.1) through a new fee mode configuration system. The application image is updated to v3.1.0, which adds automatic detection of the ledger's fee capabilities and allows operators to control whether the plugin uses the legacy plugin-fees service on `/v1` or the new Midaz embedded fees on `/v2`.

This is a **non-breaking** minor release. All new configuration fields have sensible defaults that preserve existing behavior. No operator action is required unless you want to explicitly control the fee mode or adjust the refresh interval.

## Features

### 1. Fee Mode Configuration

**What changed:**  
The application now supports three fee modes: `auto`, `legacy`, and `native`. Two new environment variables control this behavior:

- `MIDAZ_FEE_MODE`: Determines which fee system the plugin uses
- `MIDAZ_FEE_MODE_REFRESH`: Controls how often the plugin checks the ledger's version (when in `auto` mode)

**Application version:**

| Component | v2.2.0 | v2.3.0 |
|-----------|--------|--------|
| Chart version | `2.2.0` | `2.3.0` |
| App version | `3.0.2` | `3.1.0` |
| Image tag | `3.0.2` | `3.1.0` |

**Why it matters:**  
Midaz 4.1+ includes native fee handling on the `/v2` API, eliminating the need for the separate plugin-fees service. The `auto` mode allows the plugin to detect the ledger's capabilities at runtime and switch to native fees automatically when available. Operators can also pin the mode to `legacy` (always use plugin-fees on `/v1`) or `native` (always use Midaz embedded fees on `/v2`).

**Default behavior:**  
The chart defaults to `auto` mode with a 5-minute refresh interval. This means:

- On startup, the plugin calls `GET /version` on the Midaz ledger
- If Midaz version >= 4.1, the plugin uses native fees (`/v2`)
- If Midaz version < 4.1, the plugin uses legacy fees (`/v1` via plugin-fees)
- The plugin rechecks the ledger version every 5 minutes and switches modes if the ledger is upgraded

**Configuration fields:**

**Before (v2.2.0):**
```yaml
bankTransfer:
  configmap:
    # No fee mode configuration
    MIDAZ_BASE_URL: "http://midaz-ledger.midaz.svc.cluster.local:3002"
```

**After (v2.3.0):**
```yaml
bankTransfer:
  configmap:
    MIDAZ_BASE_URL: "http://midaz-ledger.midaz.svc.cluster.local:3002"
    # Fee mode (app v3.1.0+) — defaulted in templates/configmap.yaml to the app's
    # own defaults. "auto" turns native fees on by itself against Midaz >= 4.1;
    # pin "legacy" to keep plugin-fees on /v1. In native mode the ledger's fee
    # packages charge even with BTF_FEE_ENABLED=false.
    MIDAZ_FEE_MODE: "auto"            # auto | legacy | native
    MIDAZ_FEE_MODE_REFRESH: "5m"      # positive Go duration; never empty
```

**Template changes:**

The ConfigMap template now renders two new keys with defaults:

**Before (v2.2.0):**
```yaml
# templates/configmap.yaml
data:
  MIDAZ_TRANSACTION_URL: {{ .Values.bankTransfer.configmap.MIDAZ_TRANSACTION_URL | default .Values.bankTransfer.configmap.MIDAZ_BASE_URL | default "http://midaz-ledger.midaz.svc.cluster.local:3002" | quote }}
  MIDAZ_AUTH_ENABLED: {{ .Values.bankTransfer.configmap.MIDAZ_AUTH_ENABLED | default "false" | quote }}
  MIDAZ_AUTH_ADDRESS: {{ .Values.bankTransfer.configmap.MIDAZ_AUTH_ADDRESS | default "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000" | quote }}
```

**After (v2.3.0):**
```yaml
# templates/configmap.yaml
data:
  MIDAZ_TRANSACTION_URL: {{ .Values.bankTransfer.configmap.MIDAZ_TRANSACTION_URL | default .Values.bankTransfer.configmap.MIDAZ_BASE_URL | default "http://midaz-ledger.midaz.svc.cluster.local:3002" | quote }}
  MIDAZ_AUTH_ENABLED: {{ .Values.bankTransfer.configmap.MIDAZ_AUTH_ENABLED | default "false" | quote }}
  MIDAZ_AUTH_ADDRESS: {{ .Values.bankTransfer.configmap.MIDAZ_AUTH_ADDRESS | default "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000" | quote }}
  # Fee mode (app v3.1.0+): auto | legacy | native, case-sensitive. "auto" asks the
  # ledger GET /version and turns native (Midaz embedded fees on /v2) on by itself
  # against Midaz >= 4.1; "legacy" keeps plugin-fees on /v1. Defaults mirror the app.
  # The refresh default also keeps the key from rendering empty, which the app
  # refuses at boot.
  MIDAZ_FEE_MODE: {{ .Values.bankTransfer.configmap.MIDAZ_FEE_MODE | default "auto" | quote }}
  MIDAZ_FEE_MODE_REFRESH: {{ .Values.bankTransfer.configmap.MIDAZ_FEE_MODE_REFRESH | default "5m" | quote }}
```

**Operational impact:**

- **No action required for most deployments:** The `auto` default preserves backward compatibility with Midaz < 4.1 (uses legacy fees) and automatically enables native fees when the ledger is upgraded to 4.1+
- **Pin to `legacy` if you want to keep using plugin-fees:** Set `MIDAZ_FEE_MODE: "legacy"` to prevent the plugin from switching to native fees, even if Midaz 4.1+ is available
- **Pin to `native` if you know Midaz >= 4.1 is deployed:** Set `MIDAZ_FEE_MODE: "native"` to skip version detection and always use embedded fees
- **Adjust refresh interval if needed:** The default `5m` means the plugin rechecks the ledger version every 5 minutes in `auto` mode. Increase this (e.g., `30m`, `1h`) to reduce API calls, or decrease it (e.g., `1m`) for faster detection of ledger upgrades

> **Important:** In native mode, the ledger's fee packages charge fees even when `BTF_FEE_ENABLED=false`. If you rely on `BTF_FEE_ENABLED` to disable fees entirely, pin the mode to `legacy` or ensure your Midaz fee packages are configured correctly.

**Example: Pin to legacy mode**

If you want to keep using the plugin-fees service on `/v1` (e.g., because you have not yet upgraded Midaz to 4.1 or want to test native fees separately), set:

```yaml
bankTransfer:
  configmap:
    MIDAZ_FEE_MODE: "legacy"
```

**Example: Pin to native mode**

If you know Midaz 4.1+ is deployed and want to skip version detection, set:

```yaml
bankTransfer:
  configmap:
    MIDAZ_FEE_MODE: "native"
```

**Example: Adjust refresh interval**

To check the ledger version every 30 minutes instead of 5 minutes:

```yaml
bankTransfer:
  configmap:
    MIDAZ_FEE_MODE: "auto"
    MIDAZ_FEE_MODE_REFRESH: "30m"
```

> **Note:** The `MIDAZ_FEE_MODE_REFRESH` value must be a valid Go duration string (e.g., `1m`, `5m`, `1h`). The application will refuse to start if this field is empty or invalid.

## Configuration Reference

### New Environment Variables

The following environment variables are new in v2.3.0:

| Variable | Default | Description |
|----------|---------|-------------|
| `MIDAZ_FEE_MODE` | `"auto"` | Fee mode: `auto` (detect ledger version), `legacy` (always use plugin-fees on `/v1`), or `native` (always use Midaz embedded fees on `/v2`). Case-sensitive. |
| `MIDAZ_FEE_MODE_REFRESH` | `"5m"` | How often the plugin rechecks the ledger version in `auto` mode. Must be a positive Go duration (e.g., `1m`, `5m`, `30m`, `1h`). The application refuses to start if this is empty. |

**Values.yaml location:**

```yaml
bankTransfer:
  configmap:
    MIDAZ_FEE_MODE: "auto"
    MIDAZ_FEE_MODE_REFRESH: "5m"
```

**ConfigMap rendering:**

Both fields are rendered in `templates/configmap.yaml` with defaults applied via the `default` template function. Operators can override them in their values file.

### Fee Mode Values

| Mode | Behavior | Use Case |
|------|----------|----------|
| `auto` | Calls `GET /version` on the Midaz ledger at startup and every `MIDAZ_FEE_MODE_REFRESH` interval. Uses native fees if Midaz >= 4.1, otherwise uses legacy fees. | **Recommended default.** Allows seamless migration when Midaz is upgraded to 4.1+. |
| `legacy` | Always uses the plugin-fees service on `/v1`. Never calls `GET /version`. | Pin to this mode if you want to keep using plugin-fees, or if you have not yet upgraded Midaz to 4.1. |
| `native` | Always uses Midaz embedded fees on `/v2`. Never calls `GET /version`. | Pin to this mode if you know Midaz >= 4.1 is deployed and want to skip version detection. |

> **Warning:** The `MIDAZ_FEE_MODE` value is case-sensitive. Use lowercase (`auto`, `legacy`, `native`). Invalid values will cause the application to fail at startup.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.3.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.3.0 -n plugin-br-bank-transfer
```
