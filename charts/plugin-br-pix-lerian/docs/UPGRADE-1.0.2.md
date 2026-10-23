<!-- {% raw %} -->
# Helm Upgrade from v1.0.1 to v1.0.2

## Topics

- **[Features](#features)**
  - [1. Pix Automático Enabled by Default](#1-pix-automático-enabled-by-default)
  - [2. New M2M Client Secrets for Regulatory Dispatch and CRM](#2-new-m2m-client-secrets-for-regulatory-dispatch-and-crm)
  - [3. Database Read Replica Support](#3-database-read-replica-support)
  - [4. Regulatory Dispatch Configuration](#4-regulatory-dispatch-configuration)
  - [5. CRM Integration Configuration](#5-crm-integration-configuration)
  - [6. Insecure TLS Flag for Development](#6-insecure-tls-flag-for-development)
  - [7. OTEL_RESOURCE_SERVICE_VERSION Removed](#7-otel_resource_service_version-removed)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Pix Automático Enabled by Default

**What changed:**

The `pixauto` and `pixautoSystemplane` components now default to `enabled: true`. Previously, these components shipped disabled (`enabled: false`) and required explicit opt-in per environment.

| Setting | v1.0.1 | v1.0.2 |
|---------|--------|--------|
| `pixauto.enabled` | `false` | `true` |
| `pixautoSystemplane.enabled` | `false` | `true` |

**Why it matters:**

An existing installation that relied on the v1.0.1 default (`enabled: false`) **will gain the `pixauto` and `pixauto-systemplane` Deployments, Services, ConfigMaps, Secrets, ServiceAccounts, HPAs, PodDisruptionBudgets, and migration Job on `helm upgrade`**. The pixauto API will attempt to start and will **fail to boot** if the required infrastructure does not exist:

- The `pix-pixauto` PostgreSQL database
- The `DATABASE_URL` / `SYSTEMPLANE_POSTGRES_DSN` secret values
- The `SYSTEMPLANE_SECRET_MASTER_KEY` secret value

**How to handle it:**

#### Option 1: Opt out (keep existing behavior)

If your environment is not ready for Pix Automático, explicitly disable both components before upgrading:

```yaml
pixauto:
  enabled: false

pixautoSystemplane:
  enabled: false
```

This preserves the v1.0.1 behavior and prevents the pixauto workloads from being deployed.

#### Option 2: Opt in (accept the new default)

If your environment is ready for Pix Automático, ensure the following infrastructure exists **before upgrading**:

1. **Create the `pix-pixauto` database** (via the bootstrap Job or external tooling):

```yaml
externalPostgresDefinitions:
  enabled: true
  databases:
    - pix-spi
    - pix-dict
    - pix-cob
    - pix-adapter-lerian
    - pix-pixauto  # Ensure this database is created
```

2. **Provide the `DATABASE_URL` secret** for pixauto:

```yaml
pixauto:
  secrets:
    DATABASE_URL: "postgres://pixswitch:password@postgres.example.com:5432/pix-pixauto?sslmode=require"
    DB_PASSWORD: "password"
```

3. **Provide the `SYSTEMPLANE_POSTGRES_DSN` secret** for pixautoSystemplane:

```yaml
pixautoSystemplane:
  secrets:
    SYSTEMPLANE_POSTGRES_DSN: "postgres://pixswitch:password@postgres.example.com:5432/pix-pixauto?sslmode=require"
```

4. **Provide the `SYSTEMPLANE_SECRET_MASTER_KEY` secret** for pixautoSystemplane:

```yaml
pixautoSystemplane:
  secrets:
    SYSTEMPLANE_SECRET_MASTER_KEY: "your-master-key"
```

> **Warning:** Never commit real passwords or master keys to `values.yaml`. Use `useExistingSecret` and create the Secret externally, or use `--set-file` to inject credentials at upgrade time.

**After (v1.0.2) values.yaml:**

```yaml
pixauto:
  # Enabled by default: Pix Automático ships on in the cohort. An environment
  # upgrading into this default gets the pixauto workloads, so its `pix-pixauto`
  # database, the `DATABASE_URL` / `SYSTEMPLANE_POSTGRES_DSN` secret and the
  # systemplane master key must exist BEFORE the upgrade. Set `enabled: false`
  # to opt a lane out.
  enabled: true
  name: "pixauto"
  description: "Pix Automático payer API"
  # ...

pixautoSystemplane:
  # Enabled by default alongside pixauto: it is the sole writer of the pixauto
  # systemplane store the API reads. Requires SYSTEMPLANE_SECRET_MASTER_KEY and
  # the pix-pixauto DSN before upgrade. Set `enabled: false` to opt a lane out.
  enabled: true
  name: "pixauto-systemplane"
  description: "Runtime config plane for Pix Automático"
  # ...
```

### 2. New M2M Client Secrets for Regulatory Dispatch and CRM

**What changed:**

The `pixauto` component now includes three new secret keys in `pixauto.secrets`:

- `ADAPTER_CLIENT_SECRET` — M2M client secret for the counterparty adapter (regulatory dispatch)
- `CRM_CLIENT_SECRET` — M2M client secret for the CRM (person/account enrichment)
- `DATABASE_READ_REPLICA` — Optional DSN for the read-replica pool

| Setting | v1.0.1 | v1.0.2 |
|---------|--------|--------|
| `pixauto.secrets.ADAPTER_CLIENT_SECRET` | (not present) | `""` |
| `pixauto.secrets.CRM_CLIENT_SECRET` | (not present) | `""` |
| `pixauto.secrets.DATABASE_READ_REPLICA` | (not present) | `""` |

**Why it matters:**

The v1.1.0 application version introduces M2M authentication for the adapter and CRM integrations. **`ADAPTER_CLIENT_SECRET` is REQUIRED** (along with `ADAPTER_CLIENT_ID` in the ConfigMap) once `REGULATORY_DISPATCH_ENABLED=true` in a non-local `ENV_NAME`, or the app refuses to boot.

**How to handle it:**

#### If regulatory dispatch is disabled (default)

No action is required. The `REGULATORY_DISPATCH_ENABLED` flag defaults to `false`, so the adapter client credentials are not validated.

#### If regulatory dispatch is enabled

Provide both `ADAPTER_CLIENT_ID` (in ConfigMap) and `ADAPTER_CLIENT_SECRET` (in Secret) before upgrading:

```yaml
pixauto:
  configmap:
    REGULATORY_DISPATCH_ENABLED: "true"
    ADAPTER_BASE_URL: "http://adapter-lerian:4000"
    ADAPTER_CLIENT_ID: "pixauto-client"
  secrets:
    ADAPTER_CLIENT_SECRET: "your-adapter-client-secret"
```

> **Important:** In a non-local/development `ENV_NAME`, both `ADAPTER_CLIENT_ID` and `ADAPTER_CLIENT_SECRET` must be set together when `REGULATORY_DISPATCH_ENABLED=true`, or the app refuses to boot. Both empty is allowed only in a dev `ENV_NAME` (no-credential mock).

#### If CRM integration is enabled

Provide both `CRM_CLIENT_ID` (in ConfigMap) and `CRM_CLIENT_SECRET` (in Secret):

```yaml
pixauto:
  configmap:
    CRM_BASE_URL: "http://crm:8080"
    CRM_CLIENT_ID: "pixauto-crm-client"
  secrets:
    CRM_CLIENT_SECRET: "your-crm-client-secret"
```

**After (v1.0.2) values.yaml:**

```yaml
pixauto:
  secrets:
    ADAPTER_CLIENT_SECRET: ""
    CRM_CLIENT_SECRET: ""
    DATABASE_READ_REPLICA: ""
    DATABASE_URL: ""
    IDP_M2M_CLIENT_SECRET: ""
    LICENSE_KEY: ""
    # ... other secrets
```

### 3. Database Read Replica Support

**What changed:**

The `pixauto` component now supports an optional read-replica pool via the `DATABASE_READ_REPLICA` secret key.

| Setting | v1.0.1 | v1.0.2 |
|---------|--------|--------|
| `pixauto.secrets.DATABASE_READ_REPLICA` | (not present) | `""` |

**Why it matters:**

If your PostgreSQL deployment includes a read replica, you can now configure pixauto to use it for read-heavy queries, reducing load on the primary database.

**How to handle it:**

#### If you do not have a read replica

No action is required. Leave `DATABASE_READ_REPLICA` empty (the default), and pixauto will use a single connection pool to the primary database.

#### If you have a read replica

Provide the read-replica DSN in the `DATABASE_READ_REPLICA` secret:

```yaml
pixauto:
  secrets:
    DATABASE_URL: "postgres://pixswitch:password@postgres-primary.example.com:5432/pix-pixauto?sslmode=require"
    DATABASE_READ_REPLICA: "postgres://pixswitch:password@postgres-replica.example.com:5432/pix-pixauto?sslmode=require"
```

> **Note:** `DATABASE_READ_REPLICA` is an optional composed DSN for the read-replica pool (app-runtime). If blank, pixauto keeps a single pool to the primary.

### 4. Regulatory Dispatch Configuration

**What changed:**

The `pixauto` ConfigMap now includes configuration keys for the regulatory-intent drain to the counterparty adapter (v1.1.0 feature):

- `REGULATORY_DISPATCH_ENABLED` — Feature flag (default: `false`)
- `ADAPTER_BASE_URL` — Counterparty adapter edge URL
- `ADAPTER_CLIENT_ID` — M2M client ID for the adapter

**Why it matters:**

The regulatory dispatch feature allows pixauto to forward regulatory-intent events to the counterparty adapter. When enabled in a non-local/development `ENV_NAME`, the adapter client credentials (`ADAPTER_CLIENT_ID` and `ADAPTER_CLIENT_SECRET`) are **required**, or the app refuses to boot.

**How to handle it:**

#### If you do not need regulatory dispatch

No action is required. The feature defaults to `REGULATORY_DISPATCH_ENABLED=false`, and the adapter client credentials are not validated.

#### If you need regulatory dispatch

Set the feature flag and provide the adapter client credentials:

```yaml
pixauto:
  configmap:
    REGULATORY_DISPATCH_ENABLED: "true"
    ADAPTER_BASE_URL: "http://adapter-lerian:4000"
    ADAPTER_CLIENT_ID: "pixauto-client"
  secrets:
    ADAPTER_CLIENT_SECRET: "your-adapter-client-secret"
```

> **Warning:** Once `REGULATORY_DISPATCH_ENABLED=true` in a non-local `ENV_NAME`, both `ADAPTER_CLIENT_ID` and `ADAPTER_CLIENT_SECRET` must be set together, or the app refuses to boot. Both empty is allowed only in a dev `ENV_NAME` (no-credential mock).

**After (v1.0.2) configmap.yaml:**

```yaml
# -- Regulatory-intent drain to the counterparty adapter (v1.1.0). OFF by
# default; flip REGULATORY_DISPATCH_ENABLED=true to turn it on. Once on in a
# non-local/development ENV_NAME, ADAPTER_CLIENT_ID and ADAPTER_CLIENT_SECRET
# MUST be set together or the app refuses to boot; both empty is allowed only
# in a dev ENV_NAME (no-credential mock). ADAPTER_BASE_URL is the counterparty
# edge; ADAPTER_CLIENT_SECRET lives under secrets.
REGULATORY_DISPATCH_ENABLED: {{ $cm.REGULATORY_DISPATCH_ENABLED | default "false" | quote }}
ADAPTER_BASE_URL: {{ $cm.ADAPTER_BASE_URL | default "" | quote }}
ADAPTER_CLIENT_ID: {{ $cm.ADAPTER_CLIENT_ID | default "" | quote }}
```

| Flag | Default | Description |
|------|---------|-------------|
| `pixauto.configmap.REGULATORY_DISPATCH_ENABLED` | `"false"` | Enable regulatory dispatch to the counterparty adapter |
| `pixauto.configmap.ADAPTER_BASE_URL` | `""` | Counterparty adapter edge URL (e.g., `http://adapter-lerian:4000`) |
| `pixauto.configmap.ADAPTER_CLIENT_ID` | `""` | M2M client ID for the adapter (required when dispatch is enabled in non-dev ENV_NAME) |
| `pixauto.secrets.ADAPTER_CLIENT_SECRET` | `""` | M2M client secret for the adapter (required when dispatch is enabled in non-dev ENV_NAME) |

### 5. CRM Integration Configuration

**What changed:**

The `pixauto` ConfigMap now includes configuration keys for the CRM (person/account enrichment) integration:

- `CRM_BASE_URL` — CRM service URL
- `CRM_CLIENT_ID` — M2M client ID for the CRM

**Why it matters:**

The CRM integration allows pixauto to enrich person and account data. Unlike the SPI, pixauto reads no `CRM_ORGANIZATION_ID`.

**How to handle it:**

#### If you do not need CRM integration

No action is required. Leave `CRM_BASE_URL` and `CRM_CLIENT_ID` empty (the default).

#### If you need CRM integration

Provide the CRM service URL and client credentials:

```yaml
pixauto:
  configmap:
    CRM_BASE_URL: "http://crm:8080"
    CRM_CLIENT_ID: "pixauto-crm-client"
  secrets:
    CRM_CLIENT_SECRET: "your-crm-client-secret"
```

**After (v1.0.2) configmap.yaml:**

```yaml
# -- CRM (person/account enrichment). Unlike the SPI, pixauto reads no
# CRM_ORGANIZATION_ID. CRM_CLIENT_SECRET lives under secrets.
CRM_BASE_URL: {{ $cm.CRM_BASE_URL | default "" | quote }}
CRM_CLIENT_ID: {{ $cm.CRM_CLIENT_ID | default "" | quote }}
```

| Flag | Default | Description |
|------|---------|-------------|
| `pixauto.configmap.CRM_BASE_URL` | `""` | CRM service URL (e.g., `http://crm:8080`) |
| `pixauto.configmap.CRM_CLIENT_ID` | `""` | M2M client ID for the CRM |
| `pixauto.secrets.CRM_CLIENT_SECRET` | `""` | M2M client secret for the CRM |

### 6. Insecure TLS Flag for Development

**What changed:**

The `pixauto` ConfigMap now includes the `ALLOW_INSECURE_TLS` flag, which permits plaintext/insecure TLS to in-cluster dependencies (dev/CI only).

| Setting | v1.0.1 | v1.0.2 |
|---------|--------|--------|
| `pixauto.configmap.ALLOW_INSECURE_TLS` | (not present) | `"false"` |

**Why it matters:**

In development and CI environments, you may need to connect to in-cluster dependencies (PostgreSQL, Redis, RabbitMQ) without TLS or with self-signed certificates. This flag allows pixauto to skip TLS verification.

**How to handle it:**

#### In production

No action is required. The flag defaults to `false`, and TLS verification is enforced.

#### In development/CI

Set the flag to `true` to allow insecure TLS:

```yaml
pixauto:
  configmap:
    ALLOW_INSECURE_TLS: "true"
```

> **Warning:** Keep `ALLOW_INSECURE_TLS=false` in production. This flag is for dev/CI only.

**After (v1.0.2) configmap.yaml:**

```yaml
# -- Permit plaintext/insecure TLS to in-cluster dependencies (dev/CI only).
# Keep false in production.
ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "false" | quote }}
```

| Flag | Default | Description |
|------|---------|-------------|
| `pixauto.configmap.ALLOW_INSECURE_TLS` | `"false"` | Permit plaintext/insecure TLS to in-cluster dependencies (dev/CI only) |

### 7. OTEL_RESOURCE_SERVICE_VERSION Removed

**What changed:**

The `OTEL_RESOURCE_SERVICE_VERSION` environment variable is no longer emitted in the `pixauto` ConfigMap. Previously, this variable was derived from `image.tag` or `Chart.AppVersion` and emitted to the ConfigMap.

**Why it matters:**

As of v1.1.0, pixauto no longer reads `OTEL_RESOURCE_SERVICE_VERSION` from the environment. Build identity is linked in via `-X` ldflags and reported on the OTel resource from there. The variable is now suppressed to prevent a stray `configmap.OTEL_RESOURCE_SERVICE_VERSION` from surfacing.

**How to handle it:**

No action is required. The variable is no longer used by the application, and the chart no longer emits it.

**Before (v1.0.1) configmap.yaml:**

```yaml
{{- /* OTEL_RESOURCE_SERVICE_VERSION: from image tag (image.tag then
   Chart.AppVersion); override via pixauto.configmap.OTEL_RESOURCE_SERVICE_VERSION. */}}
{{- /* OTEL_RESOURCE_SERVICE_VERSION: always emitted (like OTEL_RESOURCE_SERVICE_NAME/
   OTEL_LIBRARY_NAME) so the value lives in the ConfigMap and does NOT require a
   redundant extraEnvVars entry. configmap.<KEY> wins; else derive from image.tag
   then Chart.AppVersion. */}}
{{- $compTag := default $.Chart.AppVersion $values.image.tag }}
OTEL_RESOURCE_SERVICE_VERSION: {{ $cm.OTEL_RESOURCE_SERVICE_VERSION | default $compTag | quote }}
```

**After (v1.0.2) configmap.yaml:**

```yaml
{{- /* OTEL_RESOURCE_SERVICE_VERSION is deliberately NOT emitted: pixauto reads
   no such env as of v1.1.0 (build identity is linked in via -X ldflags and
   reported on the OTel resource from there). It stays in the suppression list
   below so a stray configmap.OTEL_RESOURCE_SERVICE_VERSION cannot surface. */}}
```

> **Note:** If you previously set `pixauto.configmap.OTEL_RESOURCE_SERVICE_VERSION` in your values, it will now be ignored. Remove it from your values file.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 1.0.2 -n plugin-br-pix-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 1.0.2 -n plugin-br-pix-lerian
```
<!-- {% endraw %} -->
