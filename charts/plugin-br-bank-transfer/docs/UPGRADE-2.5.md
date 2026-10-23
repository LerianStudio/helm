<!-- {% raw %} -->
# Helm Upgrade from v2.4.1 to v2.5.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. System Facts Producer Integration](#1-system-facts-producer-integration)
- **[Configuration Reference](#configuration-reference)**
  - [New ConfigMap Environment Variables](#new-configmap-environment-variables)
  - [New Secret Fields](#new-secret-fields)
  - [Template Render Gates](#template-render-gates)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review System Facts Requirements](#step-1-review-system-facts-requirements)
  - [Step 2: Configure System Facts (Optional)](#step-2-configure-system-facts-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.5.0 introduces optional System Facts producer integration. This is a **non-breaking** feature addition that is **disabled by default**. The application can now register its own contract with a System Facts service at boot and emit structured facts to an outbox for delivery. Operators who do not need System Facts integration can upgrade without any configuration changes.

The feature includes new environment variables in the ConfigMap and Secret templates, along with render-time validation gates that enforce correct configuration when the producer is enabled.

## Features

### 1. System Facts Producer Integration

**What changed:**  
The chart now supports an optional System Facts producer that allows the application to:
- Register its own contract with a System Facts service at boot (no Job, no hook)
- Emit structured facts to an outbox for delivery
- Operate in both single-tenant (delivers + registers) and multi-tenant (registers the contract, tenants deliver with their own M2M credentials) modes

The producer is **disabled by default** and requires explicit opt-in via `bankTransfer.configmap.SYSTEM_FACTS_ENABLED=true`.

**Why it matters:**  
System Facts integration enables the application to publish domain events and operational metrics to a centralized facts service for observability, auditing, and analytics. The feature is designed to fail fast: the application refuses to boot if the producer is enabled but misconfigured (missing URL, missing client credentials in multi-tenant mode, etc.).

**Configuration flow:**

| Setting | Location | Required When | Description |
|---------|----------|---------------|-------------|
| `SYSTEM_FACTS_ENABLED` | `bankTransfer.configmap` | Always (defaults to `"false"`) | Master switch; when `"true"`, the app builds an emitter and registry client |
| `SYSTEM_FACTS_URL` | `bankTransfer.configmap` | `SYSTEM_FACTS_ENABLED=true` | Target URL for the System Facts service (the app refuses to boot without it) |
| `SYSTEM_FACTS_CLIENT_ID` | `bankTransfer.secrets` | `SYSTEM_FACTS_ENABLED=true` AND `MULTI_TENANT_ENABLED=true` | OAuth2 client ID for contract registration (single-tenant: delivers + registers; multi-tenant: service credential for registration only) |
| `SYSTEM_FACTS_CLIENT_SECRET` | `bankTransfer.secrets` | `SYSTEM_FACTS_ENABLED=true` AND `MULTI_TENANT_ENABLED=true` | OAuth2 client secret (must be set with `CLIENT_ID` — partial pairs are refused) |
| `SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE` | `bankTransfer.configmap` | Optional | When `"true"`, the app requires all credentials to be rotated before enforcing source service validation (defaults to `"false"`) |
| `SYSTEM_FACTS_INSECURE_HTTP` | `bankTransfer.configmap` | Optional | Allows plaintext HTTP URLs off loopback (refused in production; defaults to `"false"`) |

**Template changes:**

**Before (v2.4.1):**
```yaml
# templates/configmap.yaml
data:
  ORGANIZATION_ID: {{ .Values.bankTransfer.configmap.ORGANIZATION_ID | default "" | quote }}
  # (no System Facts keys)
```

**After (v2.5.0):**
```yaml
# templates/configmap.yaml
data:
  ORGANIZATION_ID: {{ .Values.bankTransfer.configmap.ORGANIZATION_ID | default "" | quote }}

  # =====================================================================
  # SYSTEM FACTS PRODUCER — OFF by default.
  # =====================================================================
  {{- $sfEnabled := eq (lower (toString (index $cm "SYSTEM_FACTS_ENABLED" | default "false"))) "true" }}
  SYSTEM_FACTS_ENABLED: {{ $sfEnabled | toString | quote }}
  {{- if $sfEnabled }}
  SYSTEM_FACTS_URL: {{ required "bankTransfer.configmap.SYSTEM_FACTS_URL is required when SYSTEM_FACTS_ENABLED=true" (index $cm "SYSTEM_FACTS_URL" | default "") | quote }}
  SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE: {{ index $cm "SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE" | default "false" | quote }}
  {{- if hasKey $cm "SYSTEM_FACTS_INSECURE_HTTP" }}
  SYSTEM_FACTS_INSECURE_HTTP: {{ index $cm "SYSTEM_FACTS_INSECURE_HTTP" | toString | quote }}
  {{- end }}
  {{- end }}
```

**Before (v2.4.1):**
```yaml
# templates/secrets.yaml
stringData:
  WEBHOOK_BROKER_EVENT_SIGNING_SECRET: {{ .Values.bankTransfer.secrets.WEBHOOK_BROKER_EVENT_SIGNING_SECRET | quote }}
  # (no System Facts keys)
```

**After (v2.5.0):**
```yaml
# templates/secrets.yaml
stringData:
  WEBHOOK_BROKER_EVENT_SIGNING_SECRET: {{ .Values.bankTransfer.secrets.WEBHOOK_BROKER_EVENT_SIGNING_SECRET | quote }}

  {{- $sfEnabled := eq (lower (toString (index $configmap "SYSTEM_FACTS_ENABLED" | default "false"))) "true" }}
  {{- $sfID := .Values.bankTransfer.secrets.SYSTEM_FACTS_CLIENT_ID | default "" }}
  {{- $sfSecret := .Values.bankTransfer.secrets.SYSTEM_FACTS_CLIENT_SECRET | default "" }}
  {{- if and $sfEnabled (or $sfID $sfSecret) (not (and $sfID $sfSecret)) }}
  {{- fail "\n\nERROR: bankTransfer.secrets.SYSTEM_FACTS_CLIENT_ID and SYSTEM_FACTS_CLIENT_SECRET go together: set both or neither.\n" }}
  {{- end }}
  {{- if and $sfEnabled $multiTenantEnabled (not (and $sfID $sfSecret)) }}
  {{- fail "\n\nERROR: bankTransfer.secrets.SYSTEM_FACTS_CLIENT_ID and SYSTEM_FACTS_CLIENT_SECRET are required when SYSTEM_FACTS_ENABLED=true and MULTI_TENANT_ENABLED=true.\n" }}
  {{- end }}
  {{- if $sfEnabled }}
  {{- with $sfID }}
  SYSTEM_FACTS_CLIENT_ID: {{ . | quote }}
  {{- end }}
  {{- with $sfSecret }}
  SYSTEM_FACTS_CLIENT_SECRET: {{ . | quote }}
  {{- end }}
  {{- end }}
```

**Operational impact:**
- **When `SYSTEM_FACTS_ENABLED=false` (default):** Only the `SYSTEM_FACTS_ENABLED: "false"` key is emitted in the ConfigMap. No other System Facts keys appear, and the application does not build an emitter or registry client.
- **When `SYSTEM_FACTS_ENABLED=true`:** The chart enforces that `SYSTEM_FACTS_URL` is set (render fails otherwise). In multi-tenant mode, the chart also enforces that both `SYSTEM_FACTS_CLIENT_ID` and `SYSTEM_FACTS_CLIENT_SECRET` are set (the app refuses to boot without them).
- **Render-time validation:** The chart includes gates that prevent misconfiguration:
  - System Facts keys (`SYSTEM_FACTS_ENABLED`, `SYSTEM_FACTS_URL`, `SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE`, `SYSTEM_FACTS_INSECURE_HTTP`, `SYSTEM_FACTS_CLIENT_ID`, `SYSTEM_FACTS_CLIENT_SECRET`) **must not** be set via `bankTransfer.extraEnvVars` — the chart fails rendering if they are, ensuring the validation gates apply
  - A partial client pair (only `CLIENT_ID` or only `CLIENT_SECRET`) is refused at render time
  - In multi-tenant mode, a missing client pair is refused at render time
- **Contract registration:** The application registers its own contract at boot (no separate Job or Helm hook). The forwarder holds until the contract is ACTIVE; facts wait in the outbox meanwhile.
- **Dev-only token:** `SYSTEM_FACTS_TOKEN` (a dev-only static bearer token) is **not** modeled by the chart and can still be set via `bankTransfer.extraEnvVars` or an existing Secret if needed for local development.

**Migration required:**  
No — the feature is disabled by default. Existing deployments continue to work without any configuration changes. See [Step 2: Configure System Facts (Optional)](#step-2-configure-system-facts-optional) if you want to enable the producer.

## Configuration Reference

### New ConfigMap Environment Variables

The following environment variables are now rendered in `templates/configmap.yaml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `SYSTEM_FACTS_ENABLED` | `"false"` | Master switch for the System Facts producer. When `"true"`, the app builds an emitter, registry client, and runs fact SQL. When `"false"` or unset, the producer is disabled. |
| `SYSTEM_FACTS_URL` | `""` (required when enabled) | Target URL for the System Facts service. The app refuses to boot if the producer is enabled but this is empty. |
| `SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE` | `"false"` | When `"true"`, the app enforces source service validation (only after all credentials are rotated). Defaults to `"false"`. |
| `SYSTEM_FACTS_INSECURE_HTTP` | `"false"` | Allows plaintext HTTP URLs off loopback (for local development). Refused in production. Only rendered if explicitly set. |

**Example (producer disabled, default behavior):**
```yaml
bankTransfer:
  configmap:
    # SYSTEM_FACTS_ENABLED: "false"  # Commented out — defaults to "false"
```

**Example (producer enabled, single-tenant):**
```yaml
bankTransfer:
  configmap:
    SYSTEM_FACTS_ENABLED: "true"
    SYSTEM_FACTS_URL: "https://system-facts.example.com"
    SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE: "false"
```

**Example (producer enabled, multi-tenant):**
```yaml
bankTransfer:
  configmap:
    SYSTEM_FACTS_ENABLED: "true"
    SYSTEM_FACTS_URL: "https://system-facts.example.com"
    MULTI_TENANT_ENABLED: "true"
  secrets:
    SYSTEM_FACTS_CLIENT_ID: "service-client-id"
    SYSTEM_FACTS_CLIENT_SECRET: "service-client-secret"
```

### New Secret Fields

The following fields are now rendered in `templates/secrets.yaml` when `SYSTEM_FACTS_ENABLED=true`:

| Field | Required When | Description |
|-------|---------------|-------------|
| `SYSTEM_FACTS_CLIENT_ID` | `SYSTEM_FACTS_ENABLED=true` AND `MULTI_TENANT_ENABLED=true` | OAuth2 client ID for contract registration. In single-tenant mode, this is optional (the app can deliver + register with the same credential). In multi-tenant mode, this is the service credential that registers the contract at boot. |
| `SYSTEM_FACTS_CLIENT_SECRET` | `SYSTEM_FACTS_ENABLED=true` AND `MULTI_TENANT_ENABLED=true` | OAuth2 client secret. Must be set together with `CLIENT_ID` — partial pairs are refused. |

**Example (single-tenant with client credentials):**
```yaml
bankTransfer:
  configmap:
    SYSTEM_FACTS_ENABLED: "true"
    SYSTEM_FACTS_URL: "https://system-facts.example.com"
  secrets:
    SYSTEM_FACTS_CLIENT_ID: "single-tenant-client-id"
    SYSTEM_FACTS_CLIENT_SECRET: "single-tenant-client-secret"
```

**Example (multi-tenant — credentials required):**
```yaml
bankTransfer:
  configmap:
    SYSTEM_FACTS_ENABLED: "true"
    SYSTEM_FACTS_URL: "https://system-facts.example.com"
    MULTI_TENANT_ENABLED: "true"
  secrets:
    SYSTEM_FACTS_CLIENT_ID: "service-client-id"
    SYSTEM_FACTS_CLIENT_SECRET: "service-client-secret"
```

> **Important:** The client pair must be set together — setting only `CLIENT_ID` or only `CLIENT_SECRET` will cause the chart to fail rendering with an error message.

### Template Render Gates

The chart includes validation logic that enforces correct System Facts configuration at render time:

1. **System Facts keys must not be set via `extraEnvVars`:**  
   The keys `SYSTEM_FACTS_ENABLED`, `SYSTEM_FACTS_URL`, `SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE`, `SYSTEM_FACTS_INSECURE_HTTP`, `SYSTEM_FACTS_CLIENT_ID`, and `SYSTEM_FACTS_CLIENT_SECRET` must be set under `bankTransfer.configmap` or `bankTransfer.secrets`. If any of these keys appear in `bankTransfer.extraEnvVars`, the chart fails rendering with an error message.

2. **Partial client pairs are refused:**  
   If `SYSTEM_FACTS_ENABLED=true` and either `SYSTEM_FACTS_CLIENT_ID` or `SYSTEM_FACTS_CLIENT_SECRET` is set (but not both), the chart fails rendering with an error message.

3. **Multi-tenant mode requires client credentials:**  
   If `SYSTEM_FACTS_ENABLED=true` and `MULTI_TENANT_ENABLED=true`, both `SYSTEM_FACTS_CLIENT_ID` and `SYSTEM_FACTS_CLIENT_SECRET` must be set. If they are missing, the chart fails rendering with an error message.

4. **URL is required when enabled:**  
   If `SYSTEM_FACTS_ENABLED=true`, `SYSTEM_FACTS_URL` must be set. If it is empty, the chart fails rendering with an error message.

**Example error (partial client pair):**
```
ERROR: bankTransfer.secrets.SYSTEM_FACTS_CLIENT_ID and SYSTEM_FACTS_CLIENT_SECRET go together: set both or neither.
A partial pair counts as no pair in the app, so the producer would refuse to boot.
```

**Example error (multi-tenant missing credentials):**
```
ERROR: bankTransfer.secrets.SYSTEM_FACTS_CLIENT_ID and SYSTEM_FACTS_CLIENT_SECRET are required when SYSTEM_FACTS_ENABLED=true and MULTI_TENANT_ENABLED=true.
They are the service credential that registers the contract at boot; the app refuses to boot without them.
```

**Example error (System Facts key in extraEnvVars):**
```
ERROR: bankTransfer.extraEnvVars.SYSTEM_FACTS_ENABLED is not allowed: set it under bankTransfer.configmap (or bankTransfer.secrets for the client pair) so the System Facts render gates apply.
```

## Migration Steps

### Step 1: Review System Facts Requirements

The System Facts producer is **disabled by default**. If you do not need System Facts integration, you can upgrade to v2.5.0 without any configuration changes.

If you want to enable the producer, review the following requirements:

- **System Facts service URL:** You must have a System Facts service deployed and accessible from the plugin-br-bank-transfer pods.
- **OAuth2 client credentials:** In multi-tenant mode, you must provision a service-level OAuth2 client (client ID + secret) for contract registration. In single-tenant mode, client credentials are optional (the app can deliver + register with the same credential).
- **Plugin auth address:** The client credentials are exchanged for a bearer token at `PLUGIN_AUTH_ADDRESS` (this must already be configured for the application to boot).

### Step 2: Configure System Facts (Optional)

If you want to enable the System Facts producer, follow the steps below based on your deployment mode.

#### Option 1: Single-Tenant Mode

In single-tenant mode, the application delivers facts and registers its own contract. Client credentials are optional (the app can use the same credential for both operations).

**Example (with client credentials):**
```yaml
bankTransfer:
  configmap:
    SYSTEM_FACTS_ENABLED: "true"
    SYSTEM_FACTS_URL: "https://system-facts.example.com"
  secrets:
    SYSTEM_FACTS_CLIENT_ID: "single-tenant-client-id"
    SYSTEM_FACTS_CLIENT_SECRET: "single-tenant-client-secret"
```

**Example (without client credentials, using tenant M2M credential):**
```yaml
bankTransfer:
  configmap:
    SYSTEM_FACTS_ENABLED: "true"
    SYSTEM_FACTS_URL: "https://system-facts.example.com"
  # No SYSTEM_FACTS_CLIENT_ID or SYSTEM_FACTS_CLIENT_SECRET — the app uses the tenant M2M credential
```

#### Option 2: Multi-Tenant Mode

In multi-tenant mode, the application registers the contract at boot using a service-level credential. Each tenant delivers facts using its own M2M credential. The service credential is **required** — the chart will fail rendering if it is missing.

**Example:**
```yaml
bankTransfer:
  configmap:
    SYSTEM_FACTS_ENABLED: "true"
    SYSTEM_FACTS_URL: "https://system-facts.example.com"
    MULTI_TENANT_ENABLED: "true"
  secrets:
    SYSTEM_FACTS_CLIENT_ID: "service-client-id"
    SYSTEM_FACTS_CLIENT_SECRET: "service-client-secret"
```

> **Warning:** In multi-tenant mode, both `SYSTEM_FACTS_CLIENT_ID` and `SYSTEM_FACTS_CLIENT_SECRET` must be set. A missing or partial client pair will cause the chart to fail rendering.

#### Option 3: Local Development (Insecure HTTP)

For local development, you can allow plaintext HTTP URLs off loopback by setting `SYSTEM_FACTS_INSECURE_HTTP=true`. This is refused in production.

**Example:**
```yaml
bankTransfer:
  configmap:
    SYSTEM_FACTS_ENABLED: "true"
    SYSTEM_FACTS_URL: "http://localhost:8080"
    SYSTEM_FACTS_INSECURE_HTTP: "true"
```

> **Note:** `SYSTEM_FACTS_INSECURE_HTTP` is only rendered if explicitly set. It defaults to `"false"` and is refused by the application in production environments.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.5.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.5.0 -n plugin-br-bank-transfer
```
<!-- {% endraw %} -->
