# br-sisbajud Helm Chart

{% raw %}

## Chart Contract

- Chart type: `single-service`
- Required secrets: `brSisbajud.secrets.LICENSE_KEY` and (external Postgres) `POSTGRES_PASSWORD` in a production-like environment (the default); `VAULT_APPROLE_SECRET_ID` with Vault AppRole (or `VAULT_TOKEN` with token auth in `production`); `STREAMING_SASL_PASSWORD` when a SASL mechanism is set; `STA_CLIENT_SECRET` when the STA transfers client is on; `IDP_M2M_CLIENT_SECRET` when the access-manager declaration publisher is on; `MULTI_TENANT_SERVICE_API_KEY` when multi-tenancy is on. The chart fails the render with the exact key to set when one is missing. With `brSisbajud.useExistingSecret`, the operator Secret must carry them. With the bundled `postgresql`/`valkey` subcharts, their passwords are single-sourced from the subchart Secrets (`secretKeyRef`). No credential is ever placed in a ConfigMap.
- Dependency notes: `lerian-common-helm` (library, env contracts and masks). Bundled `postgresql` (16.3.5), `valkey` (2.4.7), `seaweedfs` (4.0.393), `openbao` (0.30.0, dev mode) and `redpanda` (26.2.4) subcharts are declared but **disabled by default** (`values-dev.yaml` turns them all on). External PostgreSQL, Valkey/Redis, S3, Vault/AWS KMS and Kafka are the production path, and OpenBao/Redpanda are refused in a production-like environment. Kafka/Redpanda, Vault (or AWS KMS), S3-compatible object storage, plugin-access-manager, br-sta and the Midaz ledger are external services.
- Production overrides: `global.datastores` (postgres, redis), `global.objectStorage` (sisbajud, sta), `global.kms`, `global.streaming`, `global.auth`, `global.env`, the Secret keys above (or `brSisbajud.useExistingSecret`/`existingSecretName`, and `migrations.useExistingSecret`), `brSisbajud.cors.allowedOrigins`, ingress, resources and autoscaling.
- Source/license: Source is in `github.com/LerianStudio/helm`; chart license is Apache-2.0. The `br-sisbajud` service source is `github.com/LerianStudio/br-sisbajud`.

Deploys **br-sisbajud**, the Lerian SISBAJUD plugin (judicial asset blocking and unblocking with BACEN SISBAJUD). The service is a single Go binary that runs the HTTP API and the background workers in one process. The chart tracks application **1.0.2** (`appVersion`); the app, migrations and topics images follow `appVersion` unless pinned.

---

## Required external components

| Component | Used for | Chart surface |
|-----------|----------|---------------|
| PostgreSQL | Orders, institutions, audit, outbox | `global.datastores.postgres` + `secrets.POSTGRES_PASSWORD` |
| Valkey / Redis | Rate limiting, idempotency, processing locks | `global.datastores.redis` + `secrets.REDIS_PASSWORD` |
| Kafka / Redpanda | lib-streaming producer/consumers, Midaz balance translator, br-sta facts | `global.streaming` + `secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` |
| HashiCorp Vault Transit **or** AWS KMS | Envelope encryption of court-ordered seizure data | `global.kms` + `secrets.VAULT_APPROLE_SECRET_ID` (or `VAULT_TOKEN`) |
| Lerian license | Runtime license validation (fail-closed in production) | `secrets.LICENSE_KEY`, `brSisbajud.license.organizationIds` (`global`) |
| Midaz ledger stream | Balance-change trigger (`lerian.streaming.ledger`, created by Midaz) | `brSisbajud.midaz.balanceTopic` |
| plugin-access-manager | Inbound JWT validation, STA m2m token minting, permission declaration | `global.auth`, `brSisbajud.identity` |
| br-sta | Remittance intake (business facts) and return-file submission | `brSisbajud.sta`, `global.objectStorage.sta` |
| S3-compatible object storage | Encrypted seizure artifacts and the br-sta transfer bucket | `global.objectStorage` + `secrets.SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` |

The Midaz ledger and CRM connectors are **not** configured through this chart: since app 1.0.x each institution carries its own routing and sealed credentials in `institution_config.connector_metadata`. Seed one institution per tenant through the admin API (`POST /v1/institutions`) before orders can execute.

---

## Install

```console
$ helm install br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version <version> -n br-sisbajud --create-namespace -f my-values.yaml
```

Start `my-values.yaml` from [`values-template.yaml`](values-template.yaml). It is in the canonical global-first shape.

## Upgrading

```console
$ helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version <new-version> -n br-sisbajud -f my-values.yaml
```

Coming from chart 1.1.x (app `1.0.0-beta.x` / `rc.x`), read [UPGRADE-2.0.md](docs/UPGRADE-2.0.md) first.

## Uninstalling

```console
$ helm uninstall br-sisbajud -n br-sisbajud
```

---

## Configuration model

Every application env key is resolved with this precedence (lerian-common):

1. `brSisbajud.configmap.<KEY>`: the native env key, the escape hatch. It wins over everything. Keys the chart does not model are emitted verbatim.
2. `brSisbajud.<group>.<field>`: grouped chart parameters (`lerian-common.cfgValue`).
3. `brSisbajud.datastores` / `brSisbajud.kms` / `brSisbajud.objectStorage`: dedicated connection masks for this release.
4. `global.<block>.<field>`: the env-wide contract, set once per environment.
5. `global.cloud`: managed-cloud topology preset (`aws` | `gcp` | `azure`).
6. The chart default (in `templates/_helpers.tpl`).

`brSisbajud.configmap` and `brSisbajud.secrets` are empty by default. Pinning a native key there shadows the grouped/global parameter for that key.

`brSisbajud.extraEnvVars` (a list of `{name, value|valueFrom}`) is rendered as explicit pod `env:` and wins over the ConfigMap and the Secret. The fail-fast gates and the topics Job also read it.

### Global contract

| Block | Fields | Env keys |
|-------|--------|----------|
| `global.env` | `name` | `ENVIRONMENT_NAME`, `ENV_NAME`, default of `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` |
| `global.datastores.postgres` | `host`, `port`, `user`, `name`, `ssl`, `replicaHost` | `POSTGRES_HOST/PORT/USER/NAME/SSLMODE`, `POSTGRES_REPLICA_*` |
| `global.datastores.redis` | `host` (`host:port`), `tls`, `caCert` | `REDIS_HOST`, `REDIS_TLS`, `REDIS_CA_CERT` |
| `global.objectStorage.sisbajud` | `endpoint`, `region`, `bucket` | `SEAWEEDFS_S3_ENDPOINT`, `SEAWEEDFS_REGION`, `SEAWEEDFS_BUCKET` |
| `global.objectStorage.sta` | `bucket`, `endpoint` | `STA_INBOUND_BUCKET` (+ `TRANSFER_OBJECT_STORAGE_BUCKET`), `STA_OBJECT_STORAGE_ENDPOINT` |
| `global.kms` | `vendor` (`hashicorp-vault` \| `aws`), `vaultAddr`, `vaultAuthMethod`, `vaultRoleId`, `vaultMount`, `awsRegion` | `KMS_PROVIDER`, `VAULT_ADDR`, `VAULT_AUTH_METHOD`, `VAULT_APPROLE_ROLE_ID`, `VAULT_TRANSIT_MOUNT_PATH`, `AWS_REGION` |
| `global.streaming` | `enabled`, `brokers`, `tlsEnabled`, `saslMechanism`, `saslUsername`, `saslAllowPlaintext`, `compression`, `requiredAcks`, `batchLingerMs`, `importantEmitTimeoutMs` | `STREAMING_*` transport keys |
| `global.multiTenant` | `enabled`, `url`, `redisHost`, `redisPort`, `redisTls` | `MULTI_TENANT_*` |
| `global.auth` | `enabled`, `host` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` |
| `global.observability` | `enabled`, `otlpEndpoint`, `deploymentEnvironment` | `ENABLE_TELEMETRY`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` |
| `global.cloud` | `aws` \| `gcp` \| `azure` | TLS/ssl defaults for the masks above |

Parity rules the app enforces are single-sourced: `TRANSFER_OBJECT_STORAGE_BUCKET` defaults to `STA_INBOUND_BUCKET`, and `STA_OBJECT_STORAGE_ENDPOINT` defaults to `SEAWEEDFS_S3_ENDPOINT`.

### Grouped parameters and defaults

| Parameter | Env key | Default |
|-----------|---------|---------|
| `app.logLevel` | `LOG_LEVEL` | `info` |
| `app.version` | `VERSION` | image tag |
| `app.deploymentMode` | `DEPLOYMENT_MODE` | unset (app: `local`; only `saas` enforces TLS) |
| `app.defaultTenantId` | `DEFAULT_TENANT_ID` | `11111111-1111-1111-1111-111111111111` |
| `app.systemplaneEnabled` | `SYSTEMPLANE_ENABLED` | `false` |
| `app.infraConnectTimeoutSec` | `INFRA_CONNECT_TIMEOUT_SEC` | `30` |
| `app.dbMetricsIntervalSec` | `DB_METRICS_INTERVAL_SEC` | `15` |
| `app.idempotencyRetryWindowSec` | `IDEMPOTENCY_RETRY_WINDOW_SEC` | `300` |
| `app.circuitBreakerEnabled` | `CIRCUIT_BREAKER_ENABLED` | `false` |
| `server.address` | `SERVER_ADDRESS` | `0.0.0.0:<service.port>` |
| `server.bodyLimitBytes` | `HTTP_BODY_LIMIT_BYTES` | `104857600` |
| `server.tlsTerminatedUpstream` | `TLS_TERMINATED_UPSTREAM` | `false` |
| `server.tlsCertFile` / `tlsKeyFile` | `SERVER_TLS_CERT_FILE` / `SERVER_TLS_KEY_FILE` | unset (both or neither) |
| `cors.allowedOrigins` | `CORS_ALLOWED_ORIGINS` | `""` (set in production) |
| `cors.allowedMethods` | `CORS_ALLOWED_METHODS` | `GET,POST,PUT,PATCH,DELETE,OPTIONS` |
| `cors.allowedHeaders` | `CORS_ALLOWED_HEADERS` | `Origin,Content-Type,Accept,Authorization,X-Request-ID` |
| `cors.exposeHeaders` / `allowCredentials` | `CORS_EXPOSE_HEADERS` / `CORS_ALLOW_CREDENTIALS` | `""` / `false` |
| `security.allowInsecureTls` | `ALLOW_INSECURE_TLS` | `true` only with a bundled subchart, else `false` |
| `security.allowCorsWildcard` / `allowInsecureOtel` / `allowWebhookPrivateNetwork` | `ALLOW_CORS_WILDCARD` / `ALLOW_INSECURE_OTEL` / `ALLOW_WEBHOOK_PRIVATE_NETWORK` | unset |
| `license.organizationIds` | `ORGANIZATION_IDS` | `global` (the only accepted value) |
| `license.isDevelopment` | `IS_DEVELOPMENT` | unset (license SDK dev gateway when `true`) |
| `postgres.maxOpenConns` / `maxIdleConns` | `POSTGRES_MAX_OPEN_CONNS` / `POSTGRES_MAX_IDLE_CONNS` | `25` / `5` |
| `postgres.connMaxLifetimeMins` / `connMaxIdleTimeMins` / `connectTimeoutSec` | `POSTGRES_CONN_MAX_LIFETIME_MINS` / `POSTGRES_CONN_MAX_IDLE_TIME_MINS` / `POSTGRES_CONNECT_TIMEOUT_SEC` | `30` / `5` / `10` |
| `redis.db` / `protocol` / `poolSize` / `minIdleConns` | `REDIS_DB` / `REDIS_PROTOCOL` / `REDIS_POOL_SIZE` / `REDIS_MIN_IDLE_CONNS` | `0` / `3` / `10` / `2` |
| `redis.readTimeout` / `writeTimeout` / `dialTimeout` / `poolTimeout` | `REDIS_READ_TIMEOUT` / `REDIS_WRITE_TIMEOUT` / `REDIS_DIAL_TIMEOUT` / `REDIS_POOL_TIMEOUT` | `3` / `3` / `5` / `2` |
| `redis.maxRetries` / `minRetryBackoff` / `maxRetryBackoff` / `masterName` | `REDIS_MAX_RETRIES` / `REDIS_MIN_RETRY_BACKOFF` / `REDIS_MAX_RETRY_BACKOFF` / `REDIS_MASTER_NAME` | `3` / `8` / `1` / unset |
| `vault.timeoutSec` | `VAULT_TIMEOUT_SEC` | `15` |
| `vault.tokenRenewEnabled` / `tokenRenewMinIntervalSec` | `VAULT_TOKEN_RENEW_ENABLED` / `VAULT_TOKEN_RENEW_MIN_INTERVAL_SEC` | `true` / `60` |
| `vault.awsEndpointUrl` | `AWS_ENDPOINT_URL` | unset (LocalStack only) |
| `crypto.dekCacheTtl` / `dekCacheMaxEntries` / `hmacCoexistenceWindow` | `SISBAJUD_DEK_CACHE_TTL` / `SISBAJUD_DEK_CACHE_MAX_ENTRIES` / `SISBAJUD_HMAC_COEXISTENCE_WINDOW` | `5m` / `50000` / `720h` |
| `layout.responseLayout` / `remittanceLayouts` | `SISBAJUD_RESPONSE_LAYOUT` / `SISBAJUD_REMITTANCE_LAYOUTS` | `auto` / `v111,v2026` |
| `sta.fileLockTtl` | `STA_FILE_LOCK_TTL` | `5` (minutes) |
| `sta.consumerEnabled` / `consumerGroup` / `consumerRetryBudget` | `STA_CONSUMER_ENABLED` / `STA_CONSUMER_GROUP` / `STA_CONSUMER_RETRY_BUDGET` | `false` / `sisbajud-sta-consumer` / `3` |
| `sta.sourceProduct` / `bacenSystemCode` | `STA_SOURCE_PRODUCT` / `STA_BACEN_SYSTEM_CODE` | `br-sisbajud` / `JUD` |
| `sta.expectedTenantSt` | `STA_EXPECTED_TENANT_ST` | `""` (always emitted: the app checks presence) |
| `sta.maxInboundSizeBytes` | `STA_MAX_INBOUND_SIZE_BYTES` | `52428800` |
| `sta.transfersEnabled` / `transfersBaseUrl` / `clientId` | `STA_TRANSFERS_ENABLED` / `STA_TRANSFERS_BASE_URL` / `STA_CLIENT_ID` | `false` / `""` / `""` |
| `sta.documentTypeAjud302` / `documentTypeAjud309` | `STA_DOCUMENT_TYPE_AJUD302` / `STA_DOCUMENT_TYPE_AJUD309` | `AJUD302` / `AJUD309` |
| `workers.permanentBlockExpiry.{enabled,scanInterval,batchSize}` | `PERMANENT_BLOCK_EXPIRY_*` | `false` / `86400` / `500` |
| `workers.kekRewrapBackfill.{enabled,scanInterval,batchSize}` | `KEK_REWRAP_BACKFILL_*` | `false` / `300` / `100` |
| `workers.rehashBackfill.{enabled,scanInterval,batchSize,dropPreviousKeyEnabled}` | `REHASH_BACKFILL_*` | `false` / `300` / `100` / `false` |
| `workers.reconciliation.{enabled,scanInterval,batchSize}` | `RECONCILIATION_ENABLED` / `_SCAN_INTERVAL` / `_BATCH_SIZE` | `false` / `3600` / `500` |
| `workers.reconciliation.{intensifiedEnabled,intensifiedScanInterval,nearDeadlinePercent}` | `RECONCILIATION_INTENSIFIED_*` / `RECONCILIATION_NEAR_DEADLINE_PERCENT` | `false` / `300` / `75` |
| `workers.slaAlert.{enabled,scanInterval}` | `SLA_ALERT_*` | `false` / `60` |
| `workers.returnFile.{enabled,scanInterval,limit,environment}` | `RETURN_FILE_GENERATION_*`, `RETURN_FILE_ENVIRONMENT` | `false` / `3600` / `500` / `HOMOLOGATION` |
| `workers.informationReturnFile.{enabled,scanInterval,limit}` | `INFORMATION_RETURN_FILE_GENERATION_*` | `false` / `3600` / `500` |
| `workers.informationRequest.{enabled,scanInterval,batchSize,lockTtl}` | `INFORMATION_REQUEST_*` | unset (opt-in, app defaults) |
| `workers.monitoringExpiry.{enabled,scanInterval,batchSize}` | `MONITORING_EXPIRY_*` | unset (opt-in, app defaults) |
| `workers.execution.{enabled,orchestratorLockTtl,orchestratorRenewInterval}` | `EXECUTION_ENABLED`, `ORCHESTRATOR_LOCK_TTL`, `ORCHESTRATOR_RENEW_INTERVAL` | `false` / `30` / `10` |
| `workers.execution.{unblockScanInterval,unblockBatchSize}` | `UNBLOCK_EXECUTION_SCAN_INTERVAL` / `UNBLOCK_EXECUTION_BATCH_SIZE` | `60` / `500` |
| `workers.processingLockReaper.{enabled,intervalSec}` | `PROCESSING_LOCK_REAPER_*` | `true` / `300` |
| `outbox.enabled` / `tableName` | `OUTBOX_ENABLED` / `OUTBOX_TABLE_NAME` | `true` / `outbox_events` |
| `outbox.dispatchIntervalSec` / `batchSize` / `publishMaxAttempts` / `publishBackoffMs` | `OUTBOX_DISPATCH_INTERVAL_SEC` / `OUTBOX_BATCH_SIZE` / `OUTBOX_PUBLISH_MAX_ATTEMPTS` / `OUTBOX_PUBLISH_BACKOFF_MS` | `2` / `50` / `3` / `200` |
| `outbox.retryWindowSec` / `maxDispatchAttempts` / `processingTimeoutSec` / `maxFailedPerBatch` | `OUTBOX_RETRY_WINDOW_SEC` / `OUTBOX_MAX_DISPATCH_ATTEMPTS` / `OUTBOX_PROCESSING_TIMEOUT_SEC` / `OUTBOX_MAX_FAILED_PER_BATCH` | `300` / `10` / `600` / `25` |
| `outbox.includeTenantMetrics` / `allowEmptyTenant` / `priorityEventTypes` | `OUTBOX_INCLUDE_TENANT_METRICS` / `OUTBOX_ALLOW_EMPTY_TENANT` / `OUTBOX_PRIORITY_EVENT_TYPES` | `false` / `true` / unset |
| `streaming.cloudeventsSource` | `STREAMING_CLOUDEVENTS_SOURCE` | `br-sisbajud` (the app refuses any other value) |
| `streaming.clientId` / `healthCheckTimeout` | `STREAMING_CLIENT_ID` / `STREAMING_HEALTH_CHECK_TIMEOUT` | unset / `2s` |
| (global.streaming.enabled) | `STREAMING_ENABLED` | `true` (needs `OUTBOX_ENABLED=true`) |
| `balanceConsumer.{group,dedupTtl,retryBudget}` | `BALANCE_CONSUMER_GROUP` / `BALANCE_DEDUP_TTL` / `BALANCE_CONSUMER_RETRY_BUDGET` | unset (app: `sisbajud-balance-consumer` / `24h` / `3`) |
| `midaz.balanceTopic` / `balanceConsumerGroup` / `balanceDefaultAccountType` | `MIDAZ_BALANCE_TOPIC` / `MIDAZ_BALANCE_CONSUMER_GROUP` / `MIDAZ_BALANCE_DEFAULT_ACCOUNT_TYPE` | `lerian.streaming.ledger` / `sisbajud-midaz-balance-translator` / `deposit` |
| `midaz.crmMode` / `manifestCheckInterval` | `MIDAZ_CRM_MODE` / `MIDAZ_MANIFEST_CHECK_INTERVAL` | `legacy` / `15m` |
| `auth.trustedProxies` / `productName` | `TRUSTED_PROXIES` / `AUTH_PRODUCT_NAME` | `""` / unset |
| `identity.declarationEnabled` / `host` / `m2mClientId` | `IDP_DECLARATION_ENABLED` / `IDP_HOST` / `IDP_M2M_CLIENT_ID` | `false` / `""` / `""` |
| `m2m.targetService` / `credentialCacheTtlSec` | `M2M_TARGET_SERVICE` / `M2M_CREDENTIAL_CACHE_TTL_SEC` | unset / `300` |
| `observability.serviceName` / `libraryName` | `OTEL_RESOURCE_SERVICE_NAME` / `OTEL_LIBRARY_NAME` | `br-sisbajud` / `github.com/LerianStudio/br-sisbajud` |
| `rateLimit.{enabled,max,windowSec}` | `RATE_LIMIT_ENABLED` / `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_SEC` | `true` / `500` / `60` |
| `rateLimit.{aggressiveMax,aggressiveWindowSec,relaxedMax,relaxedWindowSec}` | `AGGRESSIVE_RATE_LIMIT_*` / `RELAXED_RATE_LIMIT_*` | `100` / `60` / `1000` / `60` |
| `rateLimit.{allowFailOpen,allowDisabled,redisTimeoutMs}` | `ALLOW_RATELIMIT_FAIL_OPEN` / `ALLOW_RATELIMIT_DISABLED` / `RATE_LIMIT_REDIS_TIMEOUT_MS` | `""` / `""` / `500` |
| `swagger.enabled` / `title` / `version` / `basePath` | `SWAGGER_ENABLED` / `SWAGGER_TITLE` / `SWAGGER_VERSION` / `SWAGGER_BASE_PATH` | `false` / `br-sisbajud` / image tag / `/` |
| `swagger.leftDelim` / `rightDelim` | `SWAGGER_LEFT_DELIM` / `SWAGGER_RIGHT_DELIM` | `{{` / `}}` |
| `swagger.description` / `host` / `schemes` | `SWAGGER_DESCRIPTION` / `SWAGGER_HOST` / `SWAGGER_SCHEMES` | unset |
| `pagination.maxLimit` / `maxMonthDateRange` | `MAX_PAGINATION_LIMIT` / `MAX_PAGINATION_MONTH_DATE_RANGE` | `100` / `3` |
| `admin.maxFileContentBytes` / `maxAuditVerifyWindow` | `ADMIN_MAX_FILE_CONTENT_BYTES` / `ADMIN_MAX_AUDIT_VERIFY_WINDOW` | `104857600` / unset |

Chart-derived keys: `ENVIRONMENT_NAME`/`ENV_NAME` default to `production`; `POSTGRES_SSLMODE` defaults to `require` (`disable` with the bundled subchart); `VAULT_AUTH_METHOD` defaults to `token` and `VAULT_TRANSIT_MOUNT_PATH` to `transit`; `KMS_PROVIDER` defaults to `vault`; `MULTI_TENANT_ENABLED` and `PLUGIN_AUTH_ENABLED` default to `false`. `OTEL_EXPORTER_OTLP_ENDPOINT` is overridden on the pod by `http://$(HOST_IP):4317` (node-local collector) when telemetry is on and no endpoint is set.

Keys that only matter for local development (`VAULT_PORT`, `VAULT_DEV_*`, `VAULT_APPROLE_ROLE_NAME`, `LOCALSTACK_DEBUG`, `APP_ENV`) and the deprecated lib-auth aliases (`DECLARATION_ENABLED`, `PLUGIN_IDENTITY_HOST`, `M2M_CLIENT_ID`, `M2M_CLIENT_SECRET`) are not rendered. Set them under `brSisbajud.configmap` / `brSisbajud.secrets` if you need them. The advanced lib-streaming knobs (`STREAMING_BATCH_MAX_BYTES`, `STREAMING_RECORD_RETRIES`, `STREAMING_CB_*`, ...) work the same way.

### Secrets

| Key | Required when |
|-----|---------------|
| `POSTGRES_PASSWORD` | External Postgres in a production-like environment (single-tenant) |
| `POSTGRES_REPLICA_PASSWORD` | Optional (replica with its own password) |
| `REDIS_PASSWORD` | The external Redis requires auth |
| `LICENSE_KEY` | Production-like environment |
| `VAULT_APPROLE_SECRET_ID` | `global.kms.vaultAuthMethod: approle` |
| `VAULT_TOKEN` | `vaultAuthMethod: token` and `ENVIRONMENT_NAME=production` |
| `STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` | SASL mechanism set / broker CA not in the system pool (the topics Job needs the CA when TLS is on) |
| `SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` | The object store requires static credentials |
| `STA_CLIENT_SECRET` | `sta.transfersEnabled` |
| `IDP_M2M_CLIENT_SECRET` | `identity.declarationEnabled` |
| `MULTI_TENANT_SERVICE_API_KEY` / `MULTI_TENANT_REDIS_PASSWORD` | Multi-tenancy on / tenant Redis requires auth |

The Deployment lists the ConfigMap before the Secret in `envFrom`, so a Secret key always wins over a ConfigMap key of the same name.

### Fail-fast gates

The render fails with the exact value to set (mirroring `internal/bootstrap/config_validation.go`) when:

- `STA_INBOUND_BUCKET` is empty (always: the app has no default by policy);
- `POSTGRES_HOST` / `REDIS_HOST` are empty in single-tenant mode;
- `KMS_PROVIDER` is not `vault`/`aws`, or its credentials are missing (`VAULT_ADDR`, AppRole role/secret id, `VAULT_TOKEN` in `production`, `AWS_REGION` for AWS KMS);
- streaming is on without `STREAMING_BROKERS`, or a SASL mechanism is set without a username/password or without TLS;
- a production-like environment lacks `LICENSE_KEY` or the external Postgres password;
- the STA transfers client, inbound auth or the declaration publisher is on without its host/client credentials;
- multi-tenancy is on without the tenant-manager URL, its Redis host or the service API key;
- `ORGANIZATION_IDS` is anything but `global`.

A value supplied through `brSisbajud.extraEnvVars` satisfies the gate. With `useExistingSecret`, the gates skip the Secret keys.

---

## Detached migrations

`migrations.enabled` (default `true`) ships an ArgoCD **PreSync** Secret (`hook-weight: -2`) and Job (`hook-weight: -1`) that run `ghcr.io/lerianstudio/br-sisbajud-migrations` (golang-migrate). The Job follows the app's resolved Postgres connection. `migrations.postgres.*` overrides it field by field. With the bundled subchart (or `postgresql.auth.existingSecret`), the password comes from that Secret. `migrations.useExistingSecret` / `existingSecretName` are supported. The Job pod is hardened (non-root, read-only rootfs, drop ALL, no service-account token) and waits for Postgres with a `busybox` initContainer.

## Topic provisioning

While streaming is enabled, `topics.enabled` (default `true`) ships a PreSync Job running `ghcr.io/lerianstudio/br-sisbajud-topics` (`rpk`, list-then-create, idempotent). It creates `topics.list` with the app's resolved broker, TLS and SASL settings. The SASL password and CA come from a dedicated PreSync Secret, the existing Secret, or `extraEnvVars`. The default list is the lib-streaming v4 set: `lerian.streaming.br-sisbajud`, `.dlq` and `.commands`. The Builder only creates the first two when its principal holds `CreateTopics`, and it never creates `.commands`. `lerian.streaming.ledger` belongs to Midaz: never list it. `topics.partitions`, `topics.replicationFactor` (must not exceed the broker count) and `topics.retentionMs` tune creation.

## Bundled infrastructure (development only)

`values-dev.yaml` is a self-contained dev / evaluation install:

```console
$ helm install br-sisbajud charts/br-sisbajud -f charts/br-sisbajud/values-dev.yaml -n sisb-dev --create-namespace
```

It bundles, in the release namespace:

| Subchart | Version | Toggle | Mode |
|----------|---------|--------|------|
| postgresql (Bitnami) | 16.3.5 | `postgresql.enabled` + `external: false` | standalone, creates role/db `br_sisbajud` |
| valkey (Bitnami) | 2.4.7 | `valkey.enabled` + `external: false` | standalone |
| seaweedfs | 4.0.393 | `seaweedfs.enabled` | master/volume/filer + S3, **no S3 auth** |
| openbao | 0.30.0 | `openbao.enabled` | **dev mode** (in-memory, auto-unsealed, root token) |
| redpanda | 26.2.4 | `redpandaBundle.enabled` | 1 broker, no TLS, no SASL, no external listener |

It runs with `ENVIRONMENT_NAME=development`, which relaxes the app's production gates: empty `LICENSE_KEY` = license dev bypass, plaintext Postgres and broker allowed. Inbound auth, the access-manager declaration publisher, the br-sta consumer/transfers client and multi-tenancy are off. plugin-access-manager, br-sta and the Midaz ledger are not bundled, so institutions are still seeded via the admin API.

### Derived connections

With a subchart enabled and no explicit value (`configmap` > dedicated mask > `global.*` still wins):

| Key | Derived from |
|-----|--------------|
| `POSTGRES_HOST` / `REDIS_HOST` | Bitnami Services; passwords via `secretKeyRef` to the subchart Secrets |
| `SEAWEEDFS_S3_ENDPOINT` (+ `STA_OBJECT_STORAGE_ENDPOINT`) | `http://<seaweedfs.nameOverride\|seaweedfs>-s3.<release ns>.svc.cluster.local:<s3.port>` |
| `VAULT_ADDR` | `http://<release>-openbao.<release ns>.svc.cluster.local:8200` (collapse-aware); `KMS_PROVIDER=vault`, `VAULT_AUTH_METHOD=token` |
| `VAULT_TOKEN` (Secret) | `openbao.server.dev.devRootToken` (required when the bundle is on) |
| `STREAMING_BROKERS` | `<redpanda.fullnameOverride\|release>.<release ns>.svc.cluster.local.:9093`, injected at the `global.streaming` tier |

`POSTGRES_SSLMODE` defaults to `disable` and `ALLOW_INSECURE_TLS` to `true` with a bundled datastore.

### Bootstrap Jobs

- **Buckets** (`<release>-seaweedfs-buckets`, Helm post-install/post-upgrade, ArgoCD PostSync). The app never creates buckets. This Job creates `SEAWEEDFS_BUCKET`, `STA_INBOUND_BUCKET`, `TRANSFER_OBJECT_STORAGE_BUCKET` and `seaweedfsBuckets.extraBuckets` with `weed shell` (list, create the missing ones, verify).
- **Transit** (`<release>-openbao-transit`, same hooks). It mounts the Transit engine at `VAULT_TRANSIT_MOUNT_PATH` if it is absent. No key is pre-created: the app creates its KEKs (`sisbajud-kek-<institution>`, `sisbajud-kek-connector-<institution>`) itself at boot and per institution. The Job authenticates with the dev token from the app Secret.
- **Migrations / topics**. With their dependency bundled, these Jobs run as Helm post-install/post-upgrade / ArgoCD **Sync** hooks: a PreSync hook would wait forever for infra created in the same sync. They wait for Postgres / the broker in an initContainer. Against external infra they stay ArgoCD PreSync hooks.

- **App boot ordering.** With a dependency bundled, the app pod itself runs idempotent initContainers before the app starts: `migrate up` (the migrations container, lock-protected), wait-for-broker, the topics entrypoint (list-then-create), and a wait for the Transit mount. The app never boots on a missing schema, missing topics or an unmounted Transit (verified on minikube: 0 restarts, `/readyz` healthy on first start). Against external infra these initContainers are not rendered.

All the bootstrap Jobs are idempotent, non-root with a read-only rootfs (PSS restricted), carry native-sidecar mesh annotations, and are replaced on each run (`before-hook-creation`). The finished Job stays until `ttlSecondsAfterFinished`.

### Production guard

The render **fails** when `openbao` or `redpandaBundle` is enabled in a production-like environment (anything but `local|development|staging|e2e|test`):

- OpenBao dev mode keeps its keys in memory: a pod restart loses every Transit key, and the data encrypted under them becomes **unrecoverable**.
- The Redpanda bundle is a single plaintext broker.

The postgresql / valkey / seaweedfs bundles are allowed in any environment, as in the sibling charts, but NOTES.txt warns when they run production-like. Kafka/Redpanda and the KMS are external in production: set `global.streaming` and `global.kms`.

### Caveats

- **S3 auth is OFF** (`seaweedfs.s3.enableAuth: false`). To enable it, set `seaweedfs.s3.enableAuth: true` + `seaweedfs.s3.existingConfigSecret`, and put the keys in `brSisbajud.secrets.SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` (Secret only).
- **OpenBao restarts lose its keys.** The next `helm upgrade` / sync re-mounts Transit, but previously encrypted rows are unreadable: reset the database too.
- **The dev root token is visible in the OpenBao pod env** (subchart dev mode). It is a public dev value (`dev-root-token`).
- **Images.** The `bitnami/*` tags that postgresql 16.3.5 / valkey 2.4.7 default to were removed from Docker Hub. The chart pins the same tags from `bitnamilegacy/*` (`postgresql:17.2.0-debian-12-r5`, `valkey:8.0.2-debian-12-r6`) by tag, with `global.security.allowInsecureImages: true`. SeaweedFS and the bucket Job run `chrislusf/seaweedfs:3.93`. OpenBao and the Transit Job run `quay.io/openbao/openbao:2.7.0`. Redpanda runs its chart default (`docker.redpanda.com/redpandadata/redpanda:v26.2.3`).
- **The app, migrations and topics images** (`ghcr.io/lerianstudio/br-sisbajud*`) are private: the cluster needs a pull secret for GHCR. Top-level `imagePullSecrets` (default `ghcr-credential`) covers the app, migrations, topics and bucket pods; `brSisbajud/migrations/topics.imagePullSecrets` override it per workload.
- **The bundled Valkey restarts once on the first `helm upgrade`** after install (upstream Bitnami: its `checksum/secret` is only stable once the generated password is reused via `lookup`). The password does not change.

{% endraw %}
