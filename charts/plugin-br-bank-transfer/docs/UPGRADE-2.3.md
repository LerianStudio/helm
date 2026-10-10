# Helm Upgrade from v2.2.0 to v2.3.0

## Topics

- **[Overview](#overview)**
- **[Before you upgrade](#before-you-upgrade)**
- **[Features](#features)**
  - [1. Fee Mode Configuration](#1-fee-mode-configuration)
- **[Configuration Reference](#configuration-reference)**
  - [New Environment Variables](#new-environment-variables)
  - [Fee Mode Values](#fee-mode-values)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.3.0 introduces support for Midaz native fee handling (available in Midaz >= 4.1) through a new fee mode configuration system. The application image is updated to v3.1.0, which adds automatic detection of the ledger's fee capabilities and allows operators to control whether the plugin uses the legacy plugin-fees service on `/v1` or the new Midaz embedded fees on `/v2`.

**Operator action is required** for any client whose fee packages still live in plugin-fees. Read [Before you upgrade](#before-you-upgrade) first.

## Before you upgrade

> **Warning:** Under the default `MIDAZ_FEE_MODE=auto`, Bank Transfer switches to Midaz native fees as soon as the ledger reports version 4.1.0 or later, and stops calling plugin-fees. A client whose fee packages still live in plugin-fees has no Midaz fee package to apply, so its transfers are charged **zero fees, with no error**.

For each client whose fee packages live in plugin-fees:

1. Set `bankTransfer.configmap.MIDAZ_FEE_MODE: "legacy"` **before upgrading Midaz to 4.1+**, and **before upgrading this chart if Midaz is already 4.1+**.
2. Before the rollout, check the rendered value: `helm template` (or `helm diff upgrade`, below) with your values must show `MIDAZ_FEE_MODE: "legacy"`.
3. After the rollout, confirm the pin took effect: the log line `midaz: fee mode resolved` carries `feeMode=legacy` and `source=config`. A single-tenant pod logs it at boot; a multi-tenant pod logs it per tenant, on that tenant's first transfer.
4. Move the fee packages to Midaz with the [fees migration guide](https://docs.lerian.studio/en/products/midaz/fees/fees-migration-guide), then set `auto` or `native`.

If Midaz is already 4.1+, pin `legacy` for this chart upgrade even when the fee packages already live in Midaz, and set `auto` only once every pod runs app 3.1.0: during the rolling update, a pod still on app 3.0.x can settle on `/v1`, where no fee is charged, a transfer that a 3.1.0 pod started in native mode.

Native mode needs two Midaz grants on Bank Transfer's credentials that legacy never used: `midaz` / `packages` / `get` and `midaz` / `estimates` / `post` (in multi-tenant, on each tenant's credentials). Without them, a native transfer initiation answers 503 `BTF-2000`.

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

- **`auto` is safe only once the client's fee packages live in Midaz:** it uses legacy fees against Midaz < 4.1 and switches to native fees by itself when the ledger is upgraded to 4.1+
- **Pin to `legacy` while the client's fee packages live in plugin-fees:** Set `MIDAZ_FEE_MODE: "legacy"` to prevent the plugin from switching to native fees, even if Midaz 4.1+ is available (see [Before you upgrade](#before-you-upgrade))
- **Pin to `native` if you know Midaz >= 4.1 is deployed:** Set `MIDAZ_FEE_MODE: "native"` to skip version detection and always use embedded fees
- **Adjust refresh interval if needed:** The default `5m` means the plugin rechecks the ledger version every 5 minutes in `auto` mode. Increase this (e.g., `30m`, `1h`) to reduce API calls, or decrease it (e.g., `1m`) for faster detection of ledger upgrades

> **Important:** `BTF_FEE_ENABLED` governs legacy mode only: it turns the plugin-fees call on or off. In native mode it has no effect, and a fee is turned on and off by its Midaz fee package.

**Example: Pin to legacy mode**

Required while the client's fee packages live in plugin-fees on `/v1`:

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
| `auto` | Calls `GET /version` on the Midaz ledger at startup and every `MIDAZ_FEE_MODE_REFRESH` interval. Uses native fees if Midaz >= 4.1, otherwise uses legacy fees. | Default. Safe once the client's fee packages live in Midaz; with packages still in plugin-fees, Midaz 4.1+ charges zero fees. |
| `legacy` | Always uses the plugin-fees service on `/v1`. Never calls `GET /version`. | Required while the client's fee packages live in plugin-fees. |
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
