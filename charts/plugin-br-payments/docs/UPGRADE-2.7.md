<!-- {% raw %} -->
# Helm Upgrade from v2.6.0 to v2.7.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Collections module (Gestão de Cobrança)](#1-collections-module-gestão-de-cobrança)
  - [2. Webhook public URL insecure HTTP flag](#2-webhook-public-url-insecure-http-flag)
- **[Configuration Reference](#configuration-reference)**
  - [Collections database configuration](#collections-database-configuration)
  - [Collections worker intervals](#collections-worker-intervals)
  - [Collections authentication](#collections-authentication)
  - [Webhook configuration](#webhook-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.6.0` to `2.7.0`. The application version advances from `1.4.0` to `1.5.0`. This minor release introduces the Collections module (Gestão de Cobrança), a new subsystem with its own PostgreSQL database for managing payment collections, subscriptions, beneficiaries, and title lifecycle. The module is **disabled by default** and requires explicit configuration to activate.

The upgrade also adds a new webhook configuration flag to allow insecure HTTP URLs in non-production environments.

All new configuration keys are **optional**. Existing deployments will continue to work without values changes; the Collections module will remain inactive unless you provide the required database credentials and enable the module.

## Features

### 1. Collections module (Gestão de Cobrança)

The Collections module is a new subsystem for managing payment collections (cobrança). It operates on a separate PostgreSQL database and includes workers for:

- Command dispatch and processing
- Subscription lifecycle checks
- Notice application
- Beneficiary polling
- Agreement branch sweeps
- Inventory reconciliation
- Enablement item processing
- Title fact dispatch and outcome polling

The module ships **disabled by default**. To activate it, you must:

1. Provide a PostgreSQL database for Collections (separate from the main plugin database)
2. Set `MULTI_TENANT_COLLECTIONS_POSTGRES_MODULE` to `"true"` in `app.configmap`, **or**
3. Set `COLLECTIONS_POSTGRES_HOST` in `app.configmap`

If neither of these keys is set, the application will not load the Collections module and none of the Collections environment variables will be read.

**New ConfigMap keys (all optional):**

```yaml
app:
  configmap:
    # Enable the Collections module (required to activate)
    MULTI_TENANT_COLLECTIONS_POSTGRES_MODULE: "true"
    
    # Collections database connection
    COLLECTIONS_POSTGRES_HOST: "collections-db.example.com"
    COLLECTIONS_POSTGRES_PORT: "5432"
    COLLECTIONS_POSTGRES_USER: "collections_user"
    COLLECTIONS_POSTGRES_DB: "collections"
    COLLECTIONS_POSTGRES_SSLMODE: "require"
    COLLECTIONS_POSTGRES_MAX_OPEN_CONNS: "25"
    COLLECTIONS_POSTGRES_MAX_IDLE_CONNS: "5"
    
    # Collections worker intervals (seconds)
    COLLECTIONS_COMMAND_RESEND_INTERVAL_SEC: "30"
    COLLECTIONS_COMMAND_PROCESSING_TIMEOUT_SEC: "300"
    COLLECTIONS_COMMAND_DISPATCH_CONCURRENCY: "10"
    COLLECTIONS_SUBSCRIPTION_CHECK_INTERVAL_SEC: "60"
    COLLECTIONS_NOTICE_APPLY_INTERVAL_SEC: "120"
    COLLECTIONS_BENEFICIARY_POLL_INTERVAL_SEC: "300"
    COLLECTIONS_AGREEMENT_BRANCH_SWEEP_INTERVAL_SEC: "600"
    COLLECTIONS_INVENTORY_INTERVAL_SEC: "900"
    COLLECTIONS_ENABLEMENT_ITEM_INTERVAL_SEC: "180"
    COLLECTIONS_TITLE_FACT_DISPATCH_INTERVAL_SEC: "60"
    COLLECTIONS_TITLE_OUTCOME_POLL_INTERVAL_SEC: "120"
    
    # Disable the module entirely (overrides all other settings)
    COLLECTIONS_DISABLED: "false"
```

**New Secret keys (all optional):**

```yaml
app:
  secrets:
    # Collections database password
    COLLECTIONS_POSTGRES_PASSWORD: "your-collections-db-password"
    
    # Collections PCR (Payment Collection Registry) OAuth2 credentials
    COLLECTIONS_PCR_CLIENT_ID: "your-pcr-client-id"
    COLLECTIONS_PCR_CLIENT_SECRET: "your-pcr-client-secret"
    
    # Collections cursor HMAC key for pagination security
    COLLECTIONS_CURSOR_HMAC_KEY: "your-cursor-hmac-key"
```

> **Important:** The Collections module requires a **separate PostgreSQL database**. Do not reuse the main plugin database (`POSTGRES_HOST`) for Collections. The module expects its own schema and migration history.

> **Note:** All Collections configuration keys are rendered conditionally using `{{- if hasKey $cm "KEY_NAME" }}`. If you do not set a key in your values overlay, it will not appear in the ConfigMap or Secret, and the application will use its internal defaults (defined in `internal/bootstrap/config.go`).

**Template changes:**

The `templates/configmap.yaml` file now includes a new section for Collections configuration:

**After (v2.7.0):**

```yaml
  # ====================================================================
  # COLLECTIONS (Gestão de Cobrança, its own database)
  # ====================================================================
  {{- /* The module ships off: with neither MULTI_TENANT_COLLECTIONS_POSTGRES_MODULE
     nor COLLECTIONS_POSTGRES_HOST set, the app reads none of these. No chart
     defaults: each key renders only when set, so the app defaults and bounds
     apply. The password, PCR client credentials and cursor HMAC key live in the
     Secret. */}}
  {{- if hasKey $cm "COLLECTIONS_POSTGRES_HOST" }}
  COLLECTIONS_POSTGRES_HOST: {{ index $cm "COLLECTIONS_POSTGRES_HOST" | quote }}
  {{- end }}
  {{- if hasKey $cm "COLLECTIONS_POSTGRES_PORT" }}
  COLLECTIONS_POSTGRES_PORT: {{ index $cm "COLLECTIONS_POSTGRES_PORT" | quote }}
  {{- end }}
  # ... (additional 13 Collections keys)
```

The `templates/secrets.yaml` file now includes four new secret keys in the `stringData` range:

**Before (v2.6.0):**

```yaml
  {{- range $key := list "POSTGRES_PASSWORD" "POSTGRES_REPLICA_PASSWORD" "PROVIDER_CLIENT_ID" "PROVIDER_CLIENT_SECRET" "BTG_WEBHOOK_HMAC_SECRET" "INTERNAL_API_KEY" "INTERNAL_API_KEY_PREVIOUS" "CREDENTIAL_ENCRYPTION_KEY" "CREDENTIAL_ENCRYPTION_KEY_PREVIOUS" "LICENSE_KEY" "PLUGIN_AUTH_CLIENT_ID" "PLUGIN_AUTH_CLIENT_SECRET" "MULTI_TENANT_SERVICE_API_KEY" "CONSULT_AUDIT_HMAC_KEY" "IDP_M2M_CLIENT_ID" "IDP_M2M_CLIENT_SECRET" "SANDBOX_FAKEBTG_ADMIN_KEY" }}
```

**After (v2.7.0):**

```yaml
  {{- range $key := list "POSTGRES_PASSWORD" "POSTGRES_REPLICA_PASSWORD" "PROVIDER_CLIENT_ID" "PROVIDER_CLIENT_SECRET" "BTG_WEBHOOK_HMAC_SECRET" "INTERNAL_API_KEY" "INTERNAL_API_KEY_PREVIOUS" "CREDENTIAL_ENCRYPTION_KEY" "CREDENTIAL_ENCRYPTION_KEY_PREVIOUS" "LICENSE_KEY" "PLUGIN_AUTH_CLIENT_ID" "PLUGIN_AUTH_CLIENT_SECRET" "MULTI_TENANT_SERVICE_API_KEY" "CONSULT_AUDIT_HMAC_KEY" "IDP_M2M_CLIENT_ID" "IDP_M2M_CLIENT_SECRET" "SANDBOX_FAKEBTG_ADMIN_KEY" "COLLECTIONS_POSTGRES_PASSWORD" "COLLECTIONS_PCR_CLIENT_ID" "COLLECTIONS_PCR_CLIENT_SECRET" "COLLECTIONS_CURSOR_HMAC_KEY" }}
```

**Operational impact:**

- If you do not set any Collections configuration keys, the upgrade will have no effect on your deployment. The Collections module will remain inactive.
- If you set `MULTI_TENANT_COLLECTIONS_POSTGRES_MODULE: "true"` or `COLLECTIONS_POSTGRES_HOST`, the application will attempt to connect to the Collections database at startup. If the database is unreachable or credentials are invalid, the application will fail to start.
- The Collections workers run as background goroutines within the main application process. They do not require additional pods or services.

### 2. Webhook public URL insecure HTTP flag

A new optional configuration flag `WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP` was added to allow webhook URLs with the `http://` scheme in non-production environments. By default, the application requires `https://` for all webhook URLs.

**New ConfigMap key:**

```yaml
app:
  configmap:
    # Allow insecure HTTP webhook URLs (default: false, requires https://)
    WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP: "true"
```

> **Warning:** Setting `WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP: "true"` disables TLS validation for webhook URLs. Use this flag **only in development or testing environments**. Production deployments should always use HTTPS webhooks.

**Template changes:**

The `templates/configmap.yaml` file now includes the new flag in the webhook configuration section:

**After (v2.7.0):**

```yaml
  {{- if hasKey $cm "WEBHOOK_PUBLIC_BASE_URL" }}
  WEBHOOK_PUBLIC_BASE_URL: {{ index $cm "WEBHOOK_PUBLIC_BASE_URL" | quote }}
  {{- end }}
  {{- if hasKey $cm "WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP" }}
  WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP: {{ index $cm "WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP" | quote }}
  {{- end }}
  {{- if hasKey $cm "WEBHOOK_SKIP_URL_VALIDATION" }}
  WEBHOOK_SKIP_URL_VALIDATION: {{ index $cm "WEBHOOK_SKIP_URL_VALIDATION" | quote }}
  {{- end }}
```

**Operational impact:**

If you do not set this flag, the application will continue to enforce HTTPS for all webhook URLs. Existing deployments are unaffected.

## Configuration Reference

### Collections database configuration

| Flag | Default | Description |
|------|---------|-------------|
| `MULTI_TENANT_COLLECTIONS_POSTGRES_MODULE` | not set | Enable the Collections module in multi-tenant mode. Set to `"true"` to activate. |
| `COLLECTIONS_POSTGRES_HOST` | not set | Collections database hostname. Setting this value also activates the module. |
| `COLLECTIONS_POSTGRES_PORT` | `"5432"` (app default) | Collections database port. |
| `COLLECTIONS_POSTGRES_USER` | not set | Collections database username. |
| `COLLECTIONS_POSTGRES_DB` | not set | Collections database name. |
| `COLLECTIONS_POSTGRES_SSLMODE` | `"require"` (app default) | PostgreSQL SSL mode (`disable`, `require`, `verify-ca`, `verify-full`). |
| `COLLECTIONS_POSTGRES_MAX_OPEN_CONNS` | `25` (app default) | Maximum number of open database connections. |
| `COLLECTIONS_POSTGRES_MAX_IDLE_CONNS` | `5` (app default) | Maximum number of idle database connections. |

### Collections worker intervals

All intervals are in seconds. The application uses internal defaults if these keys are not set.

| Flag | Default | Description |
|------|---------|-------------|
| `COLLECTIONS_COMMAND_RESEND_INTERVAL_SEC` | `30` (app default) | Interval for resending pending commands. |
| `COLLECTIONS_COMMAND_PROCESSING_TIMEOUT_SEC` | `300` (app default) | Timeout for command processing. |
| `COLLECTIONS_COMMAND_DISPATCH_CONCURRENCY` | `10` (app default) | Number of concurrent command dispatch workers. |
| `COLLECTIONS_SUBSCRIPTION_CHECK_INTERVAL_SEC` | `60` (app default) | Interval for checking subscription status. |
| `COLLECTIONS_NOTICE_APPLY_INTERVAL_SEC` | `120` (app default) | Interval for applying payment notices. |
| `COLLECTIONS_BENEFICIARY_POLL_INTERVAL_SEC` | `300` (app default) | Interval for polling beneficiary updates. |
| `COLLECTIONS_AGREEMENT_BRANCH_SWEEP_INTERVAL_SEC` | `600` (app default) | Interval for sweeping agreement branches. |
| `COLLECTIONS_INVENTORY_INTERVAL_SEC` | `900` (app default) | Interval for inventory reconciliation. |
| `COLLECTIONS_ENABLEMENT_ITEM_INTERVAL_SEC` | `180` (app default) | Interval for processing enablement items. |
| `COLLECTIONS_TITLE_FACT_DISPATCH_INTERVAL_SEC` | `60` (app default) | Interval for dispatching title facts. |
| `COLLECTIONS_TITLE_OUTCOME_POLL_INTERVAL_SEC` | `120` (app default) | Interval for polling title outcomes. |
| `COLLECTIONS_DISABLED` | `"false"` (app default) | Disable the Collections module entirely. Set to `"true"` to override all other settings. |

### Collections authentication

| Flag | Default | Description |
|------|---------|-------------|
| `COLLECTIONS_POSTGRES_PASSWORD` | not set | Collections database password (stored in Secret). |
| `COLLECTIONS_PCR_CLIENT_ID` | not set | OAuth2 client ID for Payment Collection Registry integration (stored in Secret). |
| `COLLECTIONS_PCR_CLIENT_SECRET` | not set | OAuth2 client secret for Payment Collection Registry integration (stored in Secret). |
| `COLLECTIONS_CURSOR_HMAC_KEY` | not set | HMAC key for securing pagination cursors (stored in Secret). |

### Webhook configuration

| Flag | Default | Description |
|------|---------|-------------|
| `WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP` | `"false"` (app default) | Allow `http://` webhook URLs. Set to `"true"` only in non-production environments. |

## Migration Steps

1. **(Optional)** If you want to enable the Collections module, provision a new PostgreSQL database for Collections. Do not reuse the main plugin database.

2. **(Optional)** If enabling Collections, add the required configuration to your values overlay:

```yaml
app:
  configmap:
    MULTI_TENANT_COLLECTIONS_POSTGRES_MODULE: "true"
    COLLECTIONS_POSTGRES_HOST: "collections-db.example.com"
    COLLECTIONS_POSTGRES_PORT: "5432"
    COLLECTIONS_POSTGRES_USER: "collections_user"
    COLLECTIONS_POSTGRES_DB: "collections"
    COLLECTIONS_POSTGRES_SSLMODE: "require"
  secrets:
    COLLECTIONS_POSTGRES_PASSWORD: "your-collections-db-password"
    COLLECTIONS_PCR_CLIENT_ID: "your-pcr-client-id"
    COLLECTIONS_PCR_CLIENT_SECRET: "your-pcr-client-secret"
    COLLECTIONS_CURSOR_HMAC_KEY: "your-cursor-hmac-key"
```

3. **(Optional)** If you need to allow insecure HTTP webhook URLs in a non-production environment, add the flag to your values overlay:

```yaml
app:
  configmap:
    WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP: "true"
```

4. Preview the rendered diff with the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

5. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

6. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n midaz-plugins
```

7. **(If Collections is enabled)** Check the application logs to confirm the Collections module initialized successfully and the database connection is healthy:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments --tail=100 | grep -i collections
```

8. **(If Collections is enabled)** Verify the Collections workers are running by checking for log entries related to command dispatch, subscription checks, and other Collections background tasks.

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

> **Important:** If you enable the Collections module and the database connection fails, the application will fail to start. Verify your database credentials and network connectivity before upgrading.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.7.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.7.0
```
<!-- {% endraw %} -->
