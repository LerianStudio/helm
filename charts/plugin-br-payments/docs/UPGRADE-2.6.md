<!-- {% raw %} -->
# Helm Upgrade from v2.5.1 to v2.6.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. New sandbox FakeBTG admin key secret](#1-new-sandbox-fakebtg-admin-key-secret)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.5.1` to `2.6.0`. Both releases ship application image `1.4.0`. This minor version adds support for a new optional secret, `SANDBOX_FAKEBTG_ADMIN_KEY`, to the chart-managed Secret template. The new secret enables administrative operations against the FakeBTG sandbox provider when running in non-production environments.

Existing deployments that do not use the FakeBTG sandbox can upgrade without any configuration changes. Deployments that require FakeBTG admin functionality must add the new secret value to their values overlay before or after upgrading.

## Features

### 1. New sandbox FakeBTG admin key secret

The chart now supports an optional `SANDBOX_FAKEBTG_ADMIN_KEY` secret in the `app.secrets` section. This secret is rendered into the chart-managed Secret resource alongside existing secrets like `POSTGRES_PASSWORD`, `PROVIDER_CLIENT_ID`, and others. The application uses this key to authenticate administrative API calls to the FakeBTG sandbox provider, which simulates BTG Pactual payment operations in development and testing environments.

**Before (v2.5.1):**

```yaml
stringData:
  {{- range $key := list "POSTGRES_PASSWORD" "POSTGRES_REPLICA_PASSWORD" "PROVIDER_CLIENT_ID" "PROVIDER_CLIENT_SECRET" "BTG_WEBHOOK_HMAC_SECRET" "INTERNAL_API_KEY" "INTERNAL_API_KEY_PREVIOUS" "CREDENTIAL_ENCRYPTION_KEY" "CREDENTIAL_ENCRYPTION_KEY_PREVIOUS" "LICENSE_KEY" "PLUGIN_AUTH_CLIENT_ID" "PLUGIN_AUTH_CLIENT_SECRET" "MULTI_TENANT_SERVICE_API_KEY" "CONSULT_AUDIT_HMAC_KEY" "IDP_M2M_CLIENT_ID" "IDP_M2M_CLIENT_SECRET" }}
  {{- with (index $sec $key) }}
  {{ $key }}: {{ . | toString | quote }}
  {{- end }}
  {{- end }}
```

**After (v2.6.0):**

```yaml
stringData:
  {{- range $key := list "POSTGRES_PASSWORD" "POSTGRES_REPLICA_PASSWORD" "PROVIDER_CLIENT_ID" "PROVIDER_CLIENT_SECRET" "BTG_WEBHOOK_HMAC_SECRET" "INTERNAL_API_KEY" "INTERNAL_API_KEY_PREVIOUS" "CREDENTIAL_ENCRYPTION_KEY" "CREDENTIAL_ENCRYPTION_KEY_PREVIOUS" "LICENSE_KEY" "PLUGIN_AUTH_CLIENT_ID" "PLUGIN_AUTH_CLIENT_SECRET" "MULTI_TENANT_SERVICE_API_KEY" "CONSULT_AUDIT_HMAC_KEY" "IDP_M2M_CLIENT_ID" "IDP_M2M_CLIENT_SECRET" "SANDBOX_FAKEBTG_ADMIN_KEY" }}
  {{- with (index $sec $key) }}
  {{ $key }}: {{ . | toString | quote }}
  {{- end }}
  {{- end }}
```

**Operational impact:**

The new secret is optional. If `app.secrets.SANDBOX_FAKEBTG_ADMIN_KEY` is not set in your values overlay, the chart will not render it into the Secret resource, and the application will not receive the environment variable. Existing deployments that do not use the FakeBTG sandbox provider can upgrade without any changes.

Deployments that use FakeBTG for testing or development and require admin operations (e.g., resetting sandbox state, managing test accounts) should add the new secret to their values overlay:

```yaml
app:
  secrets:
    SANDBOX_FAKEBTG_ADMIN_KEY: "your-fakebtg-admin-key-here"
```

The application will read this secret as the `SANDBOX_FAKEBTG_ADMIN_KEY` environment variable. Consult your FakeBTG sandbox documentation or provider configuration for the correct admin key value.

> **Important:** The `SANDBOX_FAKEBTG_ADMIN_KEY` is a sensitive credential. Store it securely in your values overlay or use an external secret management solution (e.g., Sealed Secrets, External Secrets Operator) to inject it at deployment time. Do not commit this value to version control in plain text.

> **Note:** The FakeBTG sandbox is intended for non-production environments only. Do not configure `SANDBOX_FAKEBTG_ADMIN_KEY` in production deployments that connect to the real BTG Pactual API.

## Configuration Changes

| Setting | v2.5.1 | v2.6.0 |
|---------|--------|--------|
| `Chart.yaml` `version` | `2.5.1` | `2.6.0` |
| `app.secrets.SANDBOX_FAKEBTG_ADMIN_KEY` | not supported | optional (no default) |

No configuration values were removed. The chart now accepts an optional `SANDBOX_FAKEBTG_ADMIN_KEY` secret in the `app.secrets` map.

### New Secret Variable

| Variable | Default | Description |
|----------|---------|-------------|
| `SANDBOX_FAKEBTG_ADMIN_KEY` | (none) | Admin authentication key for FakeBTG sandbox provider. Required only for administrative operations against the FakeBTG sandbox in non-production environments. |

## Migration Steps

1. **(Optional)** If your deployment uses the FakeBTG sandbox provider and requires admin functionality, add the `SANDBOX_FAKEBTG_ADMIN_KEY` secret to your values overlay:

```yaml
app:
  secrets:
    SANDBOX_FAKEBTG_ADMIN_KEY: "your-fakebtg-admin-key-here"
```

Replace `"your-fakebtg-admin-key-here"` with the actual admin key provided by your FakeBTG sandbox configuration.

2. **(Optional)** If you do not use the FakeBTG sandbox or do not require admin operations, no configuration changes are needed. Proceed directly to the upgrade command.

3. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments
kubectl rollout status -n midaz-plugins deployment/plugin-br-payments --timeout=300s
```

5. **(Optional)** If you added `SANDBOX_FAKEBTG_ADMIN_KEY`, confirm the secret is present in the chart-managed Secret resource:

```bash
kubectl get secret -n midaz-plugins plugin-br-payments -o jsonpath='{.data.SANDBOX_FAKEBTG_ADMIN_KEY}' | base64 -d
```

Expected output: your FakeBTG admin key value (base64-decoded).

6. **(Optional)** Verify the application can authenticate admin operations against the FakeBTG sandbox by checking the application logs for successful admin API calls or by testing a known admin endpoint (consult your FakeBTG sandbox documentation for available admin operations).

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.6.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.6.0
```
<!-- {% endraw %} -->
