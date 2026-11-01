# Helm Upgrade from v1.1.3 to v2.0.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Template-owned ConfigMap and Secret with lerian-common masks](#1-template-owned-configmap-and-secret-with-lerian-common-masks)
  - [2. Renamed and removed configuration keys](#2-renamed-and-removed-configuration-keys)
  - [3. Multi-tenant mode requirements](#3-multi-tenant-mode-requirements)
  - [4. New required secrets](#4-new-required-secrets)
  - [5. Control-plane migrations Job](#5-control-plane-migrations-job)
  - [6. PostgreSQL exclusivity validation](#6-postgresql-exclusivity-validation)
- **[Features](#features)**
  - [1. lerian-common-helm dependency](#1-lerian-common-helm-dependency)
  - [2. AWS IAM Roles Anywhere support](#2-aws-iam-roles-anywhere-support)
  - [3. Enhanced validation and fail-fast checks](#3-enhanced-validation-and-fail-fast-checks)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Single-tenant with bundled PostgreSQL](#single-tenant-with-bundled-postgresql)
  - [Single-tenant with external PostgreSQL](#single-tenant-with-external-postgresql)
  - [Multi-tenant with external PostgreSQL](#multi-tenant-with-external-postgresql)
- **[Configuration Reference](#configuration-reference)**
  - [Global masks](#global-masks)
  - [Chart-level datastore overrides](#chart-level-datastore-overrides)
  - [Control-plane migrations Job](#control-plane-migrations-job-1)
  - [AWS IAM Roles Anywhere](#aws-iam-roles-anywhere)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `1.1.3` to `2.0.0`. The application version advances from `1.0.0-beta.9` to `1.0.2`. The chart bump to `2.0.0` is a major release that introduces breaking changes to the configuration model: the ConfigMap and Secret are now template-owned (every key is rendered by the chart with a default or only when set), connection endpoints resolve through `global:` masks from the new `lerian-common-helm` dependency, several keys were renamed or removed, multi-tenant mode has new requirements, and new secrets are required for all deployments.

Existing deployments must update their values overlays to remove retired keys, rename changed keys, set new required secrets, and optionally migrate connection endpoints to the `global:` block. The previous `app.configmap` and `app.secrets` blocks accepted arbitrary keys; v2.0.0 refuses any key the chart does not render (enforced by `values.schema.json`).

## Breaking Changes

### 1. Template-owned ConfigMap and Secret with lerian-common masks

The ConfigMap (`templates/configmap.yaml`) and Secret (`templates/secrets.yaml`) are now template-owned: each renders a fixed set of keys, with every key either having a chart default or rendering only when set in `app.configmap.<KEY>` or `app.secrets.<KEY>`. The chart refuses any key it does not render (enforced by `values.schema.json`). Connection endpoints (PostgreSQL, plugin-access-manager, OpenTelemetry, tenant-manager) resolve through `global:` masks from the new `lerian-common-helm` dependency, with per-key overrides in `app.configmap` always winning.

**Before (v1.1.3):**

The ConfigMap and Secret accepted arbitrary keys. Operators set every environment variable explicitly in `app.configmap` and `app.secrets`, including connection endpoints:

```yaml
app:
  configmap:
    POSTGRES_HOST: "plugin-br-payments-postgresql-primary"
    POSTGRES_PORT: "5432"
    POSTGRES_USER: "plugin_br_payments"
    POSTGRES_DB: "plugin_br_payments"
    POSTGRES_SSLMODE: "require"
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"
    MULTI_TENANCY_ENABLED: "false"
    MULTI_TENANT_MANAGER_URL: ""
    # ... 80+ other keys
  secrets:
    POSTGRES_PASSWORD: ""
    BTG_CLIENT_ID: ""
    BTG_CLIENT_SECRET: ""
    # ... other secrets
```

**After (v2.0.0):**

The ConfigMap and Secret render only the keys the chart defines. Connection endpoints are set once in `global:` blocks (or `datastores:` for this chart only), and `app.configmap.<KEY>` overrides one key at a time. A null value means "unset" and falls through to the chart default. The chart refuses any key not in its template:

```yaml
global:
  env:
    name: "production"
  datastores:
    postgres:
      host: "postgresql.internal"
      port: "5432"
      user: "plugin_br_payments"
      name: "plugin_br_payments"
      ssl: "require"
  auth:
    enabled: "true"
    host: "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000"
  observability:
    enabled: "true"
    otlpEndpoint: "https://otel-collector.example.com:4317"
    deploymentEnvironment: "production"
  multiTenant:
    enabled: "true"
    url: "http://tenant-manager.tenant-manager.svc.cluster.local:4003"

app:
  configmap:
    BTG_API_BASE_URL: "https://api.btgpactual.com"
    BTG_AUTH_URL: "https://id.btgpactual.com/oauth2/token"
    MIDAZ_LEDGER_URL: "https://midaz-ledger.example.com/v1"
    ORGANIZATION_IDS: "global"
    # Only set keys that differ from chart defaults or have no default
  secrets:
    LICENSE_KEY: "your-license-key"
    PROVIDER_CLIENT_ID: "your-provider-client-id"
    PROVIDER_CLIENT_SECRET: "your-provider-client-secret"
    INTERNAL_API_KEY: "your-internal-api-key"
    CREDENTIAL_ENCRYPTION_KEY: "your-credential-encryption-key"
    BTG_WEBHOOK_HMAC_SECRET: "your-btg-webhook-hmac-secret"
    CONSULT_AUDIT_HMAC_KEY: "your-consult-audit-hmac-key"
```

**Operational impact:**

- Operators must remove all keys from `app.configmap` and `app.secrets` that are not explicitly required or that differ from chart defaults
- Connection endpoints should be migrated to `global:` blocks (or `datastores:` for chart-specific overrides) to share configuration across charts
- Any key left in `app.configmap` or `app.secrets` that the chart does not render will cause the upgrade to fail with a schema validation error
- A null value in an overlay (e.g., `POSTGRES_HOST: null`) is treated as "unset" and falls through to the chart default, not as an empty string

> **Important:** The chart now refuses to render if `app.configmap` or `app.secrets` contains a key the chart does not define. Review the full key list in the chart's README.md ("Configuration keys") and remove any keys not in that list from your values overlay.

### 2. Renamed and removed configuration keys

Several configuration keys were renamed or removed. The chart fails at upgrade time if any retired key is set.

| Previous (v1.1.3) | Current (v2.0.0) | Notes |
|-------------------|------------------|-------|
| `MULTI_TENANCY_ENABLED` | `MULTI_TENANT_ENABLED` | Renamed for consistency |
| `MULTI_TENANT_MANAGER_URL` | `MULTI_TENANT_URL` | Shortened |
| `MULTI_TENANT_POSTGRES_MODULE` | removed | No longer used |
| `MULTI_TENANT_ALLOW_INSECURE_HTTP` | removed | No longer used |
| `MULTI_TENANT_CLIENT_TIMEOUT_SEC` | removed | No longer used |
| `MULTI_TENANT_CACHE_TTL_MINUTES` | removed | No longer used |
| `MULTI_TENANT_CB_THRESHOLD` | removed | No longer used |
| `MULTI_TENANT_CB_TIMEOUT_SEC` | removed | No longer used |
| `MULTI_TENANT_MAX_TENANT_POOLS` | removed | No longer used |
| `BTG_CLIENT_ID` | `PROVIDER_CLIENT_ID` | Renamed to reflect role, not vendor |
| `BTG_CLIENT_SECRET` | `PROVIDER_CLIENT_SECRET` | Renamed to reflect role, not vendor |
| `BTG_WEBHOOK_SECRET` | `BTG_WEBHOOK_HMAC_SECRET` | Renamed to clarify HMAC usage |
| `MIDAZ_ONBOARDING_URL` | `MIDAZ_LEDGER_URL` | Consolidated into one URL |
| `MIDAZ_TRANSACTION_URL` | `MIDAZ_LEDGER_URL` | Consolidated into one URL |
| `OUTBOX_ENABLED` | removed | Always enabled; no longer configurable |
| `OUTBOX_TABLE_NAME` | removed | Fixed at `outbox_events` |
| `OUTBOX_DISPATCH_INTERVAL_SEC` | removed | No longer configurable |
| `OUTBOX_BATCH_SIZE` | removed | No longer configurable |
| `OUTBOX_PUBLISH_MAX_ATTEMPTS` | removed | No longer configurable |
| `OUTBOX_PUBLISH_BACKOFF_MS` | removed | No longer configurable |
| `OUTBOX_RETRY_WINDOW_SEC` | removed | No longer configurable |
| `OUTBOX_MAX_DISPATCH_ATTEMPTS` | removed | No longer configurable |
| `OUTBOX_PROCESSING_TIMEOUT_SEC` | removed | No longer configurable |
| `OUTBOX_MAX_FAILED_PER_BATCH` | removed | No longer configurable |
| `OUTBOX_INCLUDE_TENANT_METRICS` | removed | No longer configurable |
| `OUTBOX_ALLOW_EMPTY_TENANT` | removed | No longer configurable |

**Migration:**

Replace retired keys in your values overlay:

```yaml
# Before (v1.1.3)
app:
  configmap:
    MULTI_TENANCY_ENABLED: "true"
    MULTI_TENANT_MANAGER_URL: "http://tenant-manager.tenant-manager.svc.cluster.local:4003"
    MIDAZ_ONBOARDING_URL: "https://midaz-ledger.example.com/v1/onboarding"
    MIDAZ_TRANSACTION_URL: "https://midaz-ledger.example.com/v1/transactions"
    OUTBOX_ENABLED: "true"
  secrets:
    BTG_CLIENT_ID: "your-client-id"
    BTG_CLIENT_SECRET: "your-client-secret"
    BTG_WEBHOOK_SECRET: "your-webhook-secret"

# After (v2.0.0)
global:
  multiTenant:
    enabled: "true"
    url: "http://tenant-manager.tenant-manager.svc.cluster.local:4003"

app:
  configmap:
    MIDAZ_LEDGER_URL: "https://midaz-ledger.example.com/v1"
  secrets:
    PROVIDER_CLIENT_ID: "your-client-id"
    PROVIDER_CLIENT_SECRET: "your-client-secret"
    BTG_WEBHOOK_HMAC_SECRET: "your-webhook-secret"
```

> **Warning:** The chart fails at upgrade time with an explicit error if any retired key is set. Remove all keys listed in the "Previous (v1.1.3)" column from your values overlay before upgrading.

### 3. Multi-tenant mode requirements

Multi-tenant mode (`MULTI_TENANT_ENABLED=true`) now requires:

- An external PostgreSQL instance (`postgresql.enabled: false`)
- The control-plane migrations Job enabled (`app.controlplaneMigrations.enabled: true`)
- `MULTI_TENANT_CREDENTIAL_SOURCE` set to `"vault"` (no fallback credential source)
- `AWS_REGION` set (read directly by the AWS SDK for the Secrets Manager client)
- `WEBHOOK_PUBLIC_BASE_URL` set (where the API is served)
- `MULTI_TENANT_SERVICE_API_KEY` set in `app.secrets`
- `PROVIDER_CLIENT_ID` and `PROVIDER_CLIENT_SECRET` must NOT be set (resolved per tenant from the credential row; the app logs a WARN at boot for each one left set)

**Before (v1.1.3):**

Multi-tenant mode could run with the bundled PostgreSQL subchart and did not require the control-plane migrations Job or AWS region:

```yaml
app:
  configmap:
    MULTI_TENANCY_ENABLED: "true"
    MULTI_TENANT_MANAGER_URL: "http://tenant-manager.tenant-manager.svc.cluster.local:4003"
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "your-api-key"
    BTG_CLIENT_ID: "your-client-id"
    BTG_CLIENT_SECRET: "your-client-secret"

postgresql:
  enabled: true
```

**After (v2.0.0):**

Multi-tenant mode requires an external PostgreSQL instance, the control-plane migrations Job, AWS region, webhook public base URL, and no provider OAuth2 credentials (resolved per tenant):

```yaml
global:
  multiTenant:
    enabled: "true"
    url: "http://tenant-manager.tenant-manager.svc.cluster.local:4003"
  datastores:
    postgres:
      host: "postgresql.internal"
      port: "5432"
      user: "plugin_br_payments"
      name: "plugin_br_payments"
      ssl: "require"

app:
  configmap:
    MULTI_TENANT_CREDENTIAL_SOURCE: "vault"
    AWS_REGION: "us-east-2"
    WEBHOOK_PUBLIC_BASE_URL: "https://plugin-br-payments.example.com"
  secrets:
    POSTGRES_PASSWORD: "your-postgres-password"
    MULTI_TENANT_SERVICE_API_KEY: "your-api-key"
    # Do NOT set PROVIDER_CLIENT_ID or PROVIDER_CLIENT_SECRET in multi-tenant mode
  controlplaneMigrations:
    enabled: true

postgresql:
  enabled: false
```

**Operational impact:**

- Deployments that previously ran multi-tenant mode with the bundled PostgreSQL subchart must migrate to an external PostgreSQL instance before upgrading to v2.0.0
- The control-plane migrations Job creates the `tenant_credentials` and `tenant_metadata` tables required by the multi-tenant API; the app refuses to boot without them
- The provider OAuth2 credentials (`PROVIDER_CLIENT_ID` and `PROVIDER_CLIENT_SECRET`) are resolved per tenant from the credential row in multi-tenant mode; setting them in `app.secrets` will cause the app to log a WARN at boot and ignore them

> **Important:** Multi-tenant mode in v2.0.0 cannot run with the bundled PostgreSQL subchart. Provision an external PostgreSQL instance and set `postgresql.enabled: false` before upgrading.

### 4. New required secrets

v2.0.0 introduces new required secrets for all deployments:

| Secret | Required When | Notes |
|--------|---------------|-------|
| `LICENSE_KEY` | Always | Required in every environment |
| `ORGANIZATION_IDS` | Always | "global" or the organization UUIDs the license covers (set in `app.configmap`, not `app.secrets`) |
| `CONSULT_AUDIT_HMAC_KEY` | `SERVICE_TYPE` serves the API ("both"/"api") | >= 32 chars, no leading/trailing whitespace; HMAC key for bill consult audit line fingerprint |
| `BTG_WEBHOOK_HMAC_SECRET` | API is served and in production | >= 32 chars; renamed from `BTG_WEBHOOK_SECRET` |
| `CREDENTIAL_ENCRYPTION_KEY` | `SERVICE_TYPE` runs the worker ("both"/"worker"), multi-tenant serves the API, or `ENV_NAME` is production | Base64-encoded AES-256 key (32 random bytes) |
| `INTERNAL_API_KEY` | `SERVICE_TYPE` runs the worker ("both"/"worker") | >= 32 chars |
| `POSTGRES_PASSWORD` | External PostgreSQL without `postgresql.auth.existingSecret` | Not required with bundled subchart or when `postgresql.auth.existingSecret` is set |
| `PROVIDER_CLIENT_ID` | Single-tenant mode | Not required in multi-tenant mode (resolved per tenant) |
| `PROVIDER_CLIENT_SECRET` | Single-tenant mode | Not required in multi-tenant mode (resolved per tenant) |
| `PLUGIN_AUTH_CLIENT_ID` | Single-tenant mode while `MIDAZ_AUTH_ENABLED=true` (the default) | Midaz client credentials |
| `PLUGIN_AUTH_CLIENT_SECRET` | Single-tenant mode while `MIDAZ_AUTH_ENABLED=true` (the default) | Midaz client credentials |
| `MULTI_TENANT_SERVICE_API_KEY` | Multi-tenant mode | Required when `MULTI_TENANT_ENABLED=true` |

**Before (v1.1.3):**

Only `POSTGRES_PASSWORD`, `BTG_CLIENT_ID`, `BTG_CLIENT_SECRET`, `BTG_WEBHOOK_SECRET`, `INTERNAL_API_KEY`, and `CREDENTIAL_ENCRYPTION_KEY` were required (and `LICENSE_KEY` was recommended):

```yaml
app:
  secrets:
    POSTGRES_PASSWORD: "your-postgres-password"
    BTG_CLIENT_ID: "your-client-id"
    BTG_CLIENT_SECRET: "your-client-secret"
    BTG_WEBHOOK_SECRET: "your-webhook-secret"
    INTERNAL_API_KEY: "your-internal-api-key"
    CREDENTIAL_ENCRYPTION_KEY: "your-credential-encryption-key"
    LICENSE_KEY: "your-license-key"
```

**After (v2.0.0):**

`LICENSE_KEY`, `ORGANIZATION_IDS`, `CONSULT_AUDIT_HMAC_KEY`, `BTG_WEBHOOK_HMAC_SECRET`, and (in single-tenant mode) `PLUGIN_AUTH_CLIENT_ID` and `PLUGIN_AUTH_CLIENT_SECRET` are now required:

```yaml
app:
  configmap:
    ORGANIZATION_IDS: "global"
  secrets:
    LICENSE_KEY: "your-license-key"
    POSTGRES_PASSWORD: "your-postgres-password"
    PROVIDER_CLIENT_ID: "your-provider-client-id"
    PROVIDER_CLIENT_SECRET: "your-provider-client-secret"
    INTERNAL_API_KEY: "your-internal-api-key"
    CREDENTIAL_ENCRYPTION_KEY: "your-credential-encryption-key"
    BTG_WEBHOOK_HMAC_SECRET: "your-btg-webhook-hmac-secret"
    CONSULT_AUDIT_HMAC_KEY: "your-consult-audit-hmac-key"
    PLUGIN_AUTH_CLIENT_ID: "your-plugin-auth-client-id"
    PLUGIN_AUTH_CLIENT_SECRET: "your-plugin-auth-client-secret"
```

**Generate secrets:**

```bash
# INTERNAL_API_KEY (>= 32 chars)
openssl rand -hex 32

# CREDENTIAL_ENCRYPTION_KEY (base64-encoded AES-256 key, 32 random bytes)
openssl rand -base64 32

# BTG_WEBHOOK_HMAC_SECRET (>= 32 chars)
openssl rand -hex 32

# CONSULT_AUDIT_HMAC_KEY (>= 32 chars)
openssl rand -hex 32
```

> **Warning:** The chart fails at upgrade time if any required secret is missing. Generate and set all required secrets in your values overlay before upgrading.

> **Note:** In production (`ENV_NAME=production`, the default), the chart refuses the published example placeholders for `CONSULT_AUDIT_HMAC_KEY`. Source it from your platform secret manager.

### 5. Control-plane migrations Job

Multi-tenant mode now requires a control-plane migrations Job (`app.controlplaneMigrations.enabled: true`) that runs as a Helm PreSync hook before the Deployment starts. The Job runs `/controlplane-migrate` from the app image (present since v1.0.0) and creates the `tenant_credentials` and `tenant_metadata` tables required by the multi-tenant API. The app refuses to boot without these tables.

**Before (v1.1.3):**

No control-plane migrations Job existed. Multi-tenant mode expected the tables to be pre-provisioned.

**After (v2.0.0):**

The control-plane migrations Job is required for multi-tenant mode and renders only with `MULTI_TENANT_ENABLED=true` and an external PostgreSQL instance (`postgresql.enabled: false`):

```yaml
app:
  controlplaneMigrations:
    enabled: true
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 250m
        memory: 256Mi
```

**Operational impact:**

- The Job runs once per upgrade as a PreSync hook, before the Deployment starts
- The Job reads the same `POSTGRES_HOST` and `POSTGRES_PORT` the Deployment uses, so the app and the Job can never target different databases
- The Job's resource requests and limits are deliberately smaller than `app.resources` (it runs once, briefly, not steady-state API/worker traffic)
- If the Job fails, the upgrade fails and the Deployment does not start

> **Important:** The control-plane migrations Job is required for multi-tenant mode. Set `app.controlplaneMigrations.enabled: true` in your values overlay before upgrading.

### 6. PostgreSQL exclusivity validation

The chart now fails at upgrade time if `postgresql.enabled` is `true` at the same time as `postgresql.external` or `global.externalPostgresDefinitions.enabled`. Previously, the chart would silently render both the bundled PostgreSQL subchart and the external PostgreSQL bootstrap Job, causing a race condition.

**Before (v1.1.3):**

The chart accepted `postgresql.enabled: true` and `postgresql.external: true` simultaneously, rendering both the bundled subchart and the external bootstrap Job:

```yaml
postgresql:
  enabled: true
  external: true
```

**After (v2.0.0):**

The chart fails at upgrade time with an explicit error if `postgresql.enabled` is `true` while `postgresql.external` or `global.externalPostgresDefinitions.enabled` is also `true`:

```
ERROR: postgresql.enabled cannot be true at the same time as postgresql.external
   or global.externalPostgresDefinitions.enabled.
   Chart.yaml's postgresql dependency is gated on the literal postgresql.enabled
   value alone (condition: postgresql.enabled), so leaving it at its default
   true still renders the bundled PostgreSQL subchart even when
   postgresql.external and/or global.externalPostgresDefinitions.enabled is
   also set to true. Set postgresql.enabled: false to use an external Postgres
   (postgresql.external / global.externalPostgresDefinitions), or leave both
   postgresql.external and global.externalPostgresDefinitions.enabled false to
   use the bundled one.
```

**Migration:**

If you use an external PostgreSQL instance, set `postgresql.enabled: false` explicitly:

```yaml
postgresql:
  enabled: false
  external: true
```

> **Important:** The chart now enforces exclusivity between the bundled PostgreSQL subchart and external PostgreSQL signals. Set `postgresql.enabled: false` explicitly when using an external instance.

## Features

### 1. lerian-common-helm dependency

The chart now depends on `lerian-common-helm` v2.1.2, which provides the `global:` masks for connection endpoints (datastores, auth, observability, multiTenant) and the `lerian-common.datastore.value` and `lerian-common.globalValue` helpers. Connection endpoints resolve through these masks, with per-key overrides in `app.configmap` always winning.

**Configuration:**

```yaml
global:
  env:
    name: "production"
  datastores:
    postgres:
      host: "postgresql.internal"
      port: "5432"
      user: "plugin_br_payments"
      name: "plugin_br_payments"
      ssl: "require"
      replicaHost: "postgresql-replica.internal"
  auth:
    enabled: "true"
    host: "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000"
  observability:
    enabled: "true"
    otlpEndpoint: "https://otel-collector.example.com:4317"
    deploymentEnvironment: "production"
  multiTenant:
    enabled: "true"
    url: "http://tenant-manager.tenant-manager.svc.cluster.local:4003"
  cloud: "aws"
```

**Operational impact:**

- Connection endpoints can be set once in `global:` and shared across all charts that depend on `lerian-common-helm`
- Per-key overrides in `app.configmap` always win over the `global:` masks
- The `global.cloud` preset ("aws", "gcp", "azure") sets TLS/SSL defaults for the masks (e.g., `ssl: "require"` for AWS RDS)

> **Note:** The `global:` masks are optional. If not set, the chart falls back to its historical defaults (e.g., `POSTGRES_HOST` defaults to the bundled subchart's Service).

### 2. AWS IAM Roles Anywhere support

The chart now supports AWS IAM Roles Anywhere for non-AWS clusters (e.g., Proxmox) that need to call AWS Secrets Manager for per-tenant integrations bundles (`MULTI_TENANT_CREDENTIAL_SOURCE=vault`). An `aws-signing-helper` sidecar exchanges an X.509 client certificate (provisioned by cert-manager) for temporary AWS credentials served on a local metadata endpoint the app reads.

**Configuration:**

```yaml
aws:
  rolesAnywhere:
    enabled: true
    trustAnchorArn: "arn:aws:rolesanywhere:us-east-2:123456789012:trust-anchor/abcd1234-5678-90ab-cdef-1234567890ab"
    profileArn: "arn:aws:rolesanywhere:us-east-2:123456789012:profile/plugin-br-payments"
    roleArn: "arn:aws:iam::123456789012:role/plugin-br-payments-secrets-reader"
    region: "us-east-2"
    sessionDuration: 3600
    certificateSecretName: "plugin-br-payments-iam-tls"
    sidecar:
      image:
        repository: public.ecr.aws/rolesanywhere/credential-helper
        tag: "1.8.5-amd64-2026.08.24.20.52"
        pullPolicy: IfNotPresent
      port: 9911
      resources:
        limits:
          cpu: 100m
          memory: 128Mi
        requests:
          cpu: 10m
          memory: 64Mi
```

**Operational impact:**

- The sidecar runs alongside the app container in the same pod
- The sidecar serves temporary AWS credentials on `http://localhost:9911` (the app reads `AWS_CONTAINER_CREDENTIALS_FULL_URI` to find it)
- The X.509 client certificate must be provisioned by cert-manager and stored in the Secret named by `certificateSecretName`
- The sidecar image is pinned to an immutable version-platform-timestamp tag (`1.8.5-amd64-2026.08.24.20.52`), not the rolling `latest-amd64`, to avoid supply-chain risk

> **Note:** AWS IAM Roles Anywhere is only required for non-AWS clusters that need to call AWS Secrets Manager. If your cluster has native AWS credential mechanisms (IRSA, static keys), leave `aws.rolesAnywhere.enabled: false`.

### 3. Enhanced validation and fail-fast checks

The chart now includes enhanced validation and fail-fast checks for required configuration keys and secrets. The chart fails at upgrade time with an explicit error if:

- Any retired key is set (see [Renamed and removed configuration keys](#2-renamed-and-removed-configuration-keys))
- Any required secret is missing (see [New required secrets](#4-new-required-secrets))
- Multi-tenant mode is enabled without an external PostgreSQL instance or the control-plane migrations Job
- `postgresql.enabled` is `true` at the same time as `postgresql.external` or `global.externalPostgresDefinitions.enabled`
- `app.useExistingSecret` is `true` but `app.existingSecretName` is not set
- In production (`ENV_NAME=production`), `CONSULT_AUDIT_HMAC_KEY` is set to a published example placeholder

**Operational impact:**

- The chart fails fast at upgrade time with an explicit error message naming the missing or invalid key
- Operators no longer need to wait for the app to fail at runtime to discover missing configuration

> **Note:** The chart's validation checks run at Helm template render time, before any resources are applied to the cluster.

## Deployment Scenarios

### Single-tenant with bundled PostgreSQL

This is the simplest deployment: the chart renders the bundled PostgreSQL subchart, and the app runs in single-tenant mode with provider OAuth2 credentials set in `app.secrets`.

**Configuration:**

```yaml
global:
  env:
    name: "production"

app:
  configmap:
    BTG_API_BASE_URL: "https://api.btgpactual.com"
    BTG_AUTH_URL: "https://id.btgpactual.com/oauth2/token"
    MIDAZ_LEDGER_URL: "https://midaz-ledger.example.com/v1"
    ORGANIZATION_IDS: "global"
  secrets:
    LICENSE_KEY: "your-license-key"
    PROVIDER_CLIENT_ID: "your-provider-client-id"
    PROVIDER_CLIENT_SECRET: "your-provider-client-secret"
    INTERNAL_API_KEY: "your-internal-api-key"
    CREDENTIAL_ENCRYPTION_KEY: "your-credential-encryption-key"
    BTG_WEBHOOK_HMAC_SECRET: "your-btg-webhook-hmac-secret"
    CONSULT_AUDIT_HMAC_KEY: "your-consult-audit-hmac-key"
    PLUGIN_AUTH_CLIENT_ID: "your-plugin-auth-client-id"
    PLUGIN_AUTH_CLIENT_SECRET: "your-plugin-auth-client-secret"

postgresql:
  enabled: true
  auth:
    username: "plugin_br_payments"
    database: "plugin_br_payments"
    password: "your-postgres-password"
```

**Operational impact:**

- The bundled PostgreSQL subchart renders a StatefulSet, Service, and PVC
- The app reads `POSTGRES_PASSWORD` from the subchart's Secret (single-sourced)
- No control-plane migrations Job is required (single-tenant mode does not need the `tenant_credentials` table)

### Single-tenant with external PostgreSQL

This deployment uses an external PostgreSQL instance instead of the bundled subchart. The app still runs in single-tenant mode with provider OAuth2 credentials set in `app.secrets`.

**Configuration:**

```yaml
global:
  env:
    name: "production"
  datastores:
    postgres:
      host: "postgresql.internal"
      port: "5432"
      user: "plugin_br_payments"
      name: "plugin_br_payments"
      ssl: "require"

app:
  configmap:
