# Helm Upgrade from v1.1.x to v1.2.0

{% raw %}

## Table of Contents

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Application 1.1.0: the Midaz connector moved into the database](#1-application-110-the-midaz-connector-moved-into-the-database)
  - [2. Production-like environment by default](#2-production-like-environment-by-default)
  - [3. Keys app 1.x no longer reads are dropped](#3-keys-app-1x-no-longer-reads-are-dropped)
  - [4. Topics Job provisions the lib-streaming v4 topics](#4-topics-job-provisions-the-lib-streaming-v4-topics)
  - [5. Fail-fast render gates](#5-fail-fast-render-gates)
- **[New Features](#new-features)**
- **[Behavior Changes](#behavior-changes)**
- **[Key Mapping (1.1.x to 1.2)](#key-mapping-11x-to-12)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Chart 1.2 moves br-sisbajud to application **1.1.0** and productizes the chart on the `lerian-common-helm` library (2.1.2):

| Setting | v1.1.x | v1.2.0 |
|---------|--------|--------|
| Application | `1.0.0-beta.109` (default) | `1.1.0` (app, migrations and topics images) |
| Configuration | `brSisbajud.configmap` emitted verbatim | Global-first contract (`global.*`) + grouped params; `configmap` stays as the escape hatch |
| Env coverage | Only what the operator set | Every key of `config/.env.example@v1.1.0` (unchanged from v1.0.2), with defaults |
| Default environment | `ENV_NAME=development` | `ENVIRONMENT_NAME=ENV_NAME=production` |
| Topics Job | Pre-1.1 per-event topics | `lerian.streaming.br-sisbajud` (+ `.dlq`, `.commands`) |
| envFrom order | Secret, then ConfigMap | ConfigMap, then Secret (Secret wins) |

**Backward compatibility.** Every key a 1.1.x install sets under `brSisbajud.configmap`, `brSisbajud.secrets` or `brSisbajud.extraEnvVars` keeps reaching the pod with the same value: the native key wins over every new parameter. The only exceptions are the keys the application no longer reads ([section 3](#3-keys-app-1x-no-longer-reads-are-dropped)). Rendering the dev-st, stg-st and stg-mt values of chart 1.1.0 with 2.0 and comparing the effective pod env (ConfigMap, Secret and `env:`) gives zero changed values. Only the new defaults are added, and `LEDGER_BALANCE_TOPIC` is removed.

## Breaking Changes

### 1. Application 1.1.0: the Midaz connector moved into the database

The Midaz ledger and CRM connector routing (base URL, auth address, CRM URL) and credentials are **per institution** in `institution_config.connector_metadata`, sealed under the credentials KEK. No env var configures them anymore. Before the first order runs, seed one row per institution through the admin API (`POST /v1/institutions`). A row without `baseUrl` fails closed. `MIDAZ_CRM_MODE` (`legacy` | `embedded`) is the only deployment-wide connector setting left. It is inherited by rows without their own `crmMode`.

**1.1.0 on top of 1.0.2.** 1.1.0 has the same env contract as 1.0.2: `config/.env.example` and `internal/bootstrap/config*.go` are byte-identical, with no new migrations and no topic or Dockerfile runtime changes (only the Go toolchain bump to 1.27.1). What changed is the **per-institution connector credential contract**, written through the admin API:
- `crmMode: embedded` now accepts a **ledger-only** credential set (`ledger_client_id` / `ledger_client_secret`, no `crm_*`).
- `legacy` now **requires** the `crm_client_id` / `crm_client_secret` pair.

Check existing `institution_config.connector_metadata.credentials` against the institution's effective CRM mode before upgrading. The access-manager permission manifest also declares `credential_kek` and `sta_dlq` (relevant when `identity.declarationEnabled` is on). Grant those permissions in plugin-access-manager.

Other 1.x application requirements the chart now wires:

- `STA_INBOUND_BUCKET` is **required** at boot (br-sta's transfer bucket for the tier). When the STA consumer or transfers are on, `TRANSFER_OBJECT_STORAGE_BUCKET` must equal it and `STA_OBJECT_STORAGE_ENDPOINT` must equal `SEAWEEDFS_S3_ENDPOINT`. The chart defaults both to those values.
- Runtime license validation: `LICENSE_KEY` and `ORGANIZATION_IDS=global` are required in production.
- In production, `STREAMING_TLS_ENABLED=true` is required when streaming is on, and `POSTGRES_SSLMODE=disable` is refused.

### 2. Production-like environment by default

1.1.x shipped `ENV_NAME=development` in `values.yaml`. 1.2 defaults to `production`, the application's own fail-closed posture. A deployment that relied on the old default now needs a `LICENSE_KEY`, a TLS Postgres (`POSTGRES_SSLMODE` defaults to `require`), a Postgres password and TLS on the broker. To keep a non-production posture, set it explicitly:

```yaml
global:
  env:
    name: "staging"      # local | development | staging | e2e | test
```

A `brSisbajud.configmap.ENV_NAME` or `ENVIRONMENT_NAME` from 1.1.x keeps working and wins.

### 3. Keys app 1.x no longer reads are dropped

The chart no longer emits these keys, even when they are set under `brSisbajud.configmap` / `brSisbajud.secrets` (NOTES.txt lists any that are still set). Remove them from your values:

| Removed key | Replacement |
|-------------|-------------|
| `MIDAZ_BASE_URL`, `MIDAZ_AUTH_ENABLED`, `MIDAZ_AUTH_ADDRESS`, `MIDAZ_CLIENT_ID`, `MIDAZ_CLIENT_SECRET` | `institution_config.connector_metadata` (`baseUrl`, `authAddress`, sealed `credentials`) |
| `CRM_CLIENT_ID`, `CRM_CLIENT_SECRET` | `connector_metadata.credentials` (`crm_client_*`) + `crmBaseUrl` |
| `CONNECTOR_CREDS_USE_SECRET_STORE`, `SECRET_STORE_PROVIDER`, `VAULT_KV_MOUNT` | None: credentials are sealed in the database |
| `STA_INSTITUTION_ID`, `STA_INSTITUTION_CODE` | The `institution_config` table (multi-institution) |
| `LEDGER_BALANCE_TOPIC`, `BALANCE_CONSUMER_DLQ_SUFFIX` | Derived by lib-streaming: `lerian.streaming.br-sisbajud.commands` / `.dlq` |
| `OTEL_RESOURCE_SERVICE_VERSION` | None (not read by 1.x) |

`brSisbajud.extraEnvVars` is still rendered verbatim, so clean these keys out of it as well.

### 4. Topics Job provisions the lib-streaming v4 topics

`topics.list` now defaults to `lerian.streaming.br-sisbajud`, `lerian.streaming.br-sisbajud.dlq` and `lerian.streaming.br-sisbajud.commands`. The app's Builder only creates the first two when its principal holds `CreateTopics`. `.commands` is never created by the app: a missing `.commands` makes the balance trigger fail **silently**. The pre-1.1 per-event topics (`br-sisbajud.ledger.balance.changed`, `br-sisbajud.block_account.created`, `br-sisbajud.kek.rotated`, each with a `.dlq`) are no longer created. Retire them only after every consumer reads the new topic.

The Job now renders only while streaming is enabled. It fails the render when `STREAMING_TLS_ENABLED=true` has no `STREAMING_TLS_CA_CERT`, because the topics image needs the CA as a file. Provide it, or set `topics.enabled=false` and provision the topics out of band.

### 5. Fail-fast render gates

A values mistake now fails the render with the key to set, instead of CrashLooping the pod. The gates cover the STA bucket, datastore hosts, KMS credentials, streaming brokers, license, Postgres password, STA transfers, auth and multi-tenancy (see the README "Fail-fast gates"). Values passed as `brSisbajud.extraEnvVars` count. With `useExistingSecret`, the gates skip the Secret keys.

## New Features

- **Global-first contract (lerian-common).** Set each connection once: `global.datastores.{postgres,redis}`, `global.objectStorage.{sisbajud,sta}`, `global.kms`, `global.streaming`, `global.multiTenant`, `global.auth`, `global.observability`, `global.env`, `global.cloud`. `brSisbajud.datastores/kms/objectStorage` override them for one release.
- **Grouped parameters** for every other key (`brSisbajud.app`, `server`, `cors`, `sta`, `workers.*`, `outbox`, `midaz`, `identity`, `rateLimit`, `swagger`, ...). The README lists every key with its default.
- **Streaming SASL/TLS** through `global.streaming` + `brSisbajud.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT`, validated at render (supported mechanism, username, TLS or explicit plaintext opt-in).
- **Credentials only in the Secret**: `LICENSE_KEY`, `VAULT_TOKEN`, `VAULT_APPROLE_SECRET_ID`, `STA_CLIENT_SECRET`, `IDP_M2M_CLIENT_SECRET`, `SEAWEEDFS_*`, `MULTI_TENANT_SERVICE_API_KEY`, ...
- **Config checksums** on the pod template: a ConfigMap or Secret change rolls the pods.
- **Self-contained dev bundle** (`values-dev.yaml`): PostgreSQL, Valkey, SeaweedFS, OpenBao (dev mode) and Redpanda, with derived endpoints and idempotent bootstrap Jobs (buckets, Transit). OpenBao/Redpanda are refused in a production-like environment; PostgreSQL/Valkey/SeaweedFS only get a NOTES warning there but are unsupported in production. Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure. See the README "Bundled infrastructure".
- **Optional bundled SeaweedFS** (`seaweedfs.enabled`, off by default) for dev and evaluation installs only, never production. The S3 endpoint derives from the subchart Service, and a hook Job creates the configured buckets (the app never creates them). See the README "Bundled infrastructure".

## Behavior Changes

- `envFrom` lists the ConfigMap before the Secret, so a Secret key is never shadowed by a ConfigMap key of the same name.
- The migrations Job follows the app's resolved Postgres connection. With the bundled subchart or `postgresql.auth.existingSecret`, its password comes from that Secret.
- With telemetry on, the pod still ships to `http://$(HOST_IP):4317` (node-local collector), unless an endpoint is set explicitly (`global.observability.otlpEndpoint`, `configmap.OTEL_EXPORTER_OTLP_ENDPOINT` or `extraEnvVars`). 1.1.x forced the node-local endpoint even then.
- `pdb.minAvailable: 0` is honored. 1.1.x coerced it to `1`, which blocked node drains with a single replica.
- `brSisbajud.tolerations` defaults to a list (`[]`).
- `brSisbajud.replicaCount: 0` is honored (1.1.x coerced it to `1`).
- With a bundled Postgres / Redpanda, the migrations / topics Jobs run as Helm post-install/post-upgrade (ArgoCD Sync) hooks instead of PreSync.
- Against external infra, the migrations / topics Jobs and their Secrets are now also Helm `pre-install,pre-upgrade` hooks, so a plain `helm install/upgrade` migrates before the app. ArgoCD behavior is unchanged: the `argocd.argoproj.io/*` annotations win.
- The migrations Job takes its Postgres password from the app's own credential source (existing Secret, `extraEnvVars`, `brSisbajud.secrets`, or the bundled/existing subchart Secret) instead of only `brSisbajud.secrets`. It fails the render if none is set.
- **CORS now works.** The CORS middleware (lib-commons v7.9.0 `withCORS.go`) reads `ACCESS_CONTROL_ALLOW_ORIGIN` / `_METHODS` / `_HEADERS` / `_EXPOSE_HEADERS` / `_CREDENTIALS`, not the app's `CORS_*`. 1.1.x only set `CORS_*`, so the middleware fell back to `*` and denied every origin. The chart now renders both families from one resolution. An existing `brSisbajud.configmap.CORS_ALLOWED_ORIGINS` flows into `ACCESS_CONTROL_ALLOW_ORIGIN`, and so does a `brSisbajud.extraEnvVars` `CORS_*` entry, which is mirrored as an explicit `ACCESS_CONTROL_*` pod env. A native `ACCESS_CONTROL_*` (configmap or extraEnvVars) wins.
- The bundled `postgresql` / `valkey` subcharts pull `bitnamilegacy/*` images: the `bitnami/*` tags they default to no longer exist on Docker Hub. The tags are the same, so existing data stays readable. The bundled Postgres now creates the `br_sisbajud` role and database, and the bundled Valkey runs standalone.
- `SERVER_ADDRESS` defaults to `0.0.0.0:<service.port>`, and `VERSION` / `SWAGGER_VERSION` default to the image tag.

## Key Mapping (1.1.x to 1.2)

The 1.1.x native keys keep working. Move to the right-hand column to use the productized API. Once you set the new parameter, delete the native key: a native key shadows it.

| 1.1.x (`brSisbajud.configmap` / `extraEnvVars`) | 1.2 |
|---|---|
| `ENV_NAME` / `ENVIRONMENT_NAME` | `global.env.name` |
| `POSTGRES_HOST` / `PORT` / `USER` / `NAME` / `SSLMODE` | `global.datastores.postgres.{host,port,user,name,ssl}` |
| `POSTGRES_REPLICA_HOST` | `global.datastores.postgres.replicaHost` |
| `REDIS_HOST` / `REDIS_TLS` / `REDIS_CA_CERT` | `global.datastores.redis.{host,tls,caCert}` |
| `KMS_PROVIDER` | `global.kms.vendor` (`hashicorp-vault` \| `aws`) |
| `VAULT_ADDR` / `VAULT_AUTH_METHOD` / `VAULT_APPROLE_ROLE_ID` / `VAULT_TRANSIT_MOUNT_PATH` | `global.kms.{vaultAddr,vaultAuthMethod,vaultRoleId,vaultMount}` |
| `VAULT_APPROLE_SECRET_ID` (extraEnvVars) | `brSisbajud.secrets.VAULT_APPROLE_SECRET_ID` |
| `AWS_REGION` (KMS) | `global.kms.awsRegion` |
| `SEAWEEDFS_S3_ENDPOINT` / `SEAWEEDFS_REGION` / `SEAWEEDFS_BUCKET` | `global.objectStorage.sisbajud.{endpoint,region,bucket}` |
| `STA_INBOUND_BUCKET` (+ `TRANSFER_OBJECT_STORAGE_BUCKET`) | `global.objectStorage.sta.bucket` |
| `STA_OBJECT_STORAGE_ENDPOINT` | `global.objectStorage.sta.endpoint` (defaults to the sisbajud endpoint) |
| `STREAMING_ENABLED` / `STREAMING_BROKERS` | `global.streaming.{enabled,brokers}` |
| `STREAMING_TLS_ENABLED` / `STREAMING_SASL_MECHANISM` / `STREAMING_SASL_USERNAME` / `STREAMING_SASL_ALLOW_PLAINTEXT` | `global.streaming.{tlsEnabled,saslMechanism,saslUsername,saslAllowPlaintext}` |
| `STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` (extraEnvVars) | `brSisbajud.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` |
| `MULTI_TENANT_ENABLED` / `URL` / `REDIS_HOST` / `REDIS_PORT` / `REDIS_TLS` | `global.multiTenant.{enabled,url,redisHost,redisPort,redisTls}` |
| `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_HOST` | `global.auth.{enabled,host}` |
| `TRUSTED_PROXIES` | `brSisbajud.auth.trustedProxies` |
| `IDP_DECLARATION_ENABLED` / `IDP_HOST` / `IDP_M2M_CLIENT_ID` | `brSisbajud.identity.{declarationEnabled,host,m2mClientId}` |
| `IDP_M2M_CLIENT_SECRET` (extraEnvVars) | `brSisbajud.secrets.IDP_M2M_CLIENT_SECRET` |
| `ENABLE_TELEMETRY` / `OTEL_EXPORTER_OTLP_ENDPOINT` / `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `global.observability.{enabled,otlpEndpoint,deploymentEnvironment}` |
| `OTEL_RESOURCE_SERVICE_NAME` / `OTEL_LIBRARY_NAME` | `brSisbajud.observability.{serviceName,libraryName}` |
| `LOG_LEVEL`, `DEPLOYMENT_MODE`, `DEFAULT_TENANT_ID`, `VERSION` | `brSisbajud.app.{logLevel,deploymentMode,defaultTenantId,version}` |
| `SERVER_ADDRESS`, `HTTP_BODY_LIMIT_BYTES`, `TLS_TERMINATED_UPSTREAM` | `brSisbajud.server.{address,bodyLimitBytes,tlsTerminatedUpstream}` |
| `CORS_ALLOWED_ORIGINS` / `METHODS` / `HEADERS` | `brSisbajud.cors.{allowedOrigins,allowedMethods,allowedHeaders}` (also rendered as `ACCESS_CONTROL_*`) |
| `ALLOW_INSECURE_TLS` | `brSisbajud.security.allowInsecureTls` |
| `ORGANIZATION_IDS`, `IS_DEVELOPMENT` | `brSisbajud.license.{organizationIds,isDevelopment}` |
| `STA_CONSUMER_ENABLED`, `STA_TRANSFERS_ENABLED`, `STA_TRANSFERS_BASE_URL`, `STA_EXPECTED_TENANT_ST`, `STA_BACEN_SYSTEM_CODE`, `STA_SOURCE_PRODUCT`, `STA_CLIENT_ID` | `brSisbajud.sta.{consumerEnabled,transfersEnabled,transfersBaseUrl,expectedTenantSt,bacenSystemCode,sourceProduct,clientId}` |
| `STA_CLIENT_SECRET` (extraEnvVars) | `brSisbajud.secrets.STA_CLIENT_SECRET` |
| `EXECUTION_ENABLED` | `brSisbajud.workers.execution.enabled` |
| `RETURN_FILE_GENERATION_*`, `RETURN_FILE_ENVIRONMENT` | `brSisbajud.workers.returnFile.{enabled,scanInterval,limit,environment}` |
| `INFORMATION_RETURN_FILE_GENERATION_*` | `brSisbajud.workers.informationReturnFile.*` |
| `INFORMATION_REQUEST_*` / `MONITORING_EXPIRY_*` | `brSisbajud.workers.informationRequest.*` / `monitoringExpiry.*` |
| `RECONCILIATION_*` | `brSisbajud.workers.reconciliation.*` |
| `SLA_ALERT_*` / `PERMANENT_BLOCK_EXPIRY_*` | `brSisbajud.workers.slaAlert.*` / `permanentBlockExpiry.*` |
| `KEK_REWRAP_BACKFILL_*` / `REHASH_BACKFILL_*` | `brSisbajud.workers.kekRewrapBackfill.*` / `rehashBackfill.*` |
| `OUTBOX_*` | `brSisbajud.outbox.*` |
| `MIDAZ_BALANCE_TOPIC`, `MIDAZ_CRM_MODE` | `brSisbajud.midaz.{balanceTopic,crmMode}` |
| `RATE_LIMIT_*` | `brSisbajud.rateLimit.*` |
| `SWAGGER_*` | `brSisbajud.swagger.*` |
| `MAX_PAGINATION_*`, `DB_METRICS_INTERVAL_SEC`, `IDEMPOTENCY_RETRY_WINDOW_SEC`, `INFRA_CONNECT_TIMEOUT_SEC` | `brSisbajud.pagination.*`, `brSisbajud.app.*` |

## Migration Steps

### Step 1: Prepare application 1.1.0

1. Seed `institution_config` for every institution (admin API), including `connector_metadata.baseUrl`, `authAddress` and the sealed `credentials` when the ledger requires auth.
2. Confirm br-sta's transfer bucket for the tier and set `global.objectStorage.sta.bucket`.
3. Provision `lerian.streaming.br-sisbajud.commands` (the topics Job does it by default), with the same partition count as the app topic.
4. Drain `outbox_events` on the old build before switching topic generations (lib-streaming v3+ rollout in the application repository).

### Step 2: Render with your current values, unchanged

Keep your 1.1.x values. Pin the environment explicitly if you relied on the old default (`global.env.name`), remove the keys from [section 3](#3-keys-app-1x-no-longer-reads-are-dropped), and diff the render (next section). The expected difference is the new default keys plus the removed ones.

### Step 3: Move to the global-first shape (optional, recommended)

Move connection keys to `global.*` and the rest to the grouped parameters (see the [Key Mapping](#key-mapping-11x-to-12)). Move credentials from `extraEnvVars` to `brSisbajud.secrets`. [`values-template.yaml`](../values-template.yaml) is the canonical starter. Re-render and confirm the effective env did not change.

## Preview changes before upgrading

```bash
helm template br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version 1.1.0 -f my-values.yaml > before.yaml
helm template br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version 1.2.0 -f my-values.yaml > after.yaml
diff before.yaml after.yaml
```

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version 1.2.0 -n br-sisbajud -f my-values.yaml
```

{% endraw %}
