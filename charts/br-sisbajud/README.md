# br-sisbajud Helm Chart

{% raw %}

## Chart Contract

- Chart type: `single-service`
- Required secrets: `brSisbajud.secrets.LICENSE_KEY` in a production-like environment (the default; `local|development|staging|e2e|test` have the app's dev bypass); (external Postgres) `POSTGRES_PASSWORD` in a production-like environment; `VAULT_APPROLE_SECRET_ID` with Vault AppRole (or `VAULT_TOKEN` with token auth in `production`); `STREAMING_SASL_PASSWORD` when a SASL mechanism is set (streaming is mandatory); `STA_CLIENT_SECRET` when the STA transfers client is on; `STA_STREAM_SASL_PASSWORD` (+ `STA_STREAM_TLS_CA_CERT` with TLS) when the br-sta consumer is on; `IDP_M2M_CLIENT_SECRET` when the access-manager declaration publisher is on; `MULTI_TENANT_SERVICE_API_KEY` when multi-tenancy is on. Operator-provided Secrets mounted as files: the execution API server certificate/key (`brSisbajud.execution.tls.existingSecret`, always) and client CA (`execution.clientCa`, with mTLS), and the Access Manager JWT verification PEM (`brSisbajud.auth.jwtVerifyCertSecret`, unless inline). The chart fails the render with the exact key to set when one is missing. With `brSisbajud.useExistingSecret`, the operator Secret must carry them. With the bundled `postgresql`/`valkey` subcharts, their passwords are single-sourced from the subchart Secrets (`secretKeyRef`). No credential is ever placed in a ConfigMap.
- Dependency notes: `lerian-common-helm` (library, env contracts and masks). Bundled `postgresql` (16.3.5), `valkey` (2.4.7), `seaweedfs` (4.0.393), `openbao` (0.30.0, dev mode) and `redpanda` (26.2.4) subcharts are declared but **disabled by default** (`values-dev.yaml` turns them all on). Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure. External PostgreSQL, Valkey/Redis, S3, Vault/AWS KMS and Kafka are the production path, and OpenBao/Redpanda are refused outside a development-class environment (staging is refused). Kafka/Redpanda, Vault (or AWS KMS), S3-compatible object storage, plugin-access-manager, br-sta and the Midaz ledger are external services.
- Production overrides: `global.datastores` (postgres, redis), `global.objectStorage` (sisbajud, sta), `global.kms`, `global.streaming`, `global.auth`, `global.env`, `brSisbajud.auth.jwtIssuer` + `jwtVerifyCert*`, `brSisbajud.execution.tls.existingSecret`, the Secret keys above (or `brSisbajud.useExistingSecret`/`existingSecretName`, and `migrations.useExistingSecret`), `brSisbajud.cors.allowedOrigins`, ingress, resources and autoscaling.
- Source/license: Source is in `github.com/LerianStudio/helm`; chart license is Elastic License 2.0. The service source is `github.com/LerianStudio/br-sfn` (`services/sisbajud`, released as `sisbajud-v*`).

Deploys **br-sisbajud**, the Lerian **Sisbajud Mensageria**: the regulatory side of SISBAJUD judicial asset blocking (STA remittance intake, return files, BACEN) plus the **execution API** that the executor, plugin-br-sisbajud, calls to pull orders and post results. It was split out of the former br-sisbajud monolith: ledger execution now lives in plugin-br-sisbajud. The service is a single Go binary that runs the main HTTP API (`:4031`), the execution API on its own in-pod TLS listener (`:4032`) and the background workers in one process. The chart tracks application **1.0.0** (`appVersion`, br-sfn `sisbajud-v1.0.0`); the app and migrations images follow `appVersion` unless pinned.

---

## Required external components

| Component | Used for | Chart surface |
|-----------|----------|---------------|
| PostgreSQL | Orders, institutions, audit, outbox | `global.datastores.postgres` + `secrets.POSTGRES_PASSWORD` |
| Valkey / Redis | Rate limiting, idempotency, processing locks | `global.datastores.redis` + `secrets.REDIS_PASSWORD` |
| Kafka / Redpanda | lib-streaming producer (`lerian.streaming.br-sisbajud`: order release notices for plugin-br-sisbajud, probes). Mandatory | `global.streaming` + `secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` |
| br-sta's Kafka cluster | br-sta business facts consumer (`lerian.streaming.br-sta`), SASL + TLS | `brSisbajud.sta.stream` + `secrets.STA_STREAM_SASL_PASSWORD` / `STA_STREAM_TLS_CA_CERT` |
| HashiCorp Vault Transit **or** AWS KMS | Envelope encryption of court-ordered seizure data | `global.kms` + `secrets.VAULT_APPROLE_SECRET_ID` (or `VAULT_TOKEN`) |
| Lerian license | Runtime license validation (fail-closed in a production-like environment) | `secrets.LICENSE_KEY`, `brSisbajud.license.organizationIds` (`global`) |
| plugin-access-manager | Inbound JWT validation (plus local signature verification with its public key), STA m2m token minting, permission declaration | `global.auth`, `brSisbajud.auth.jwtIssuer` / `jwtVerifyCert*`, `brSisbajud.identity` |
| plugin-br-sisbajud | The executor: calls the execution API (TLS, optional mTLS, M2M bearer) | `brSisbajud.execution` |
| br-sta | Remittance intake (business facts) and return-file submission | `brSisbajud.sta`, `global.objectStorage.sta` |
| S3-compatible object storage | Encrypted seizure artifacts and the br-sta transfer bucket | `global.objectStorage` + `secrets.SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` |

The Midaz ledger is not called by the Mensageria: plugin-br-sisbajud executes orders on it. Seed institutions (and grant the executor access) through the admin API (`POST /v1/institutions`) before orders can be executed.

---

## Install

```console
$ helm install br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version <version> -n br-sisbajud --create-namespace -f my-values.yaml
```

For a step-by-step installation (dev bundle, pairing with br-sta, production), validation and known errors, see the getting-started runbook: [English](docs/00-getting-start.en.md) · [Português](docs/00-getting-start.md).

Start `my-values.yaml` from [`values-template.yaml`](values-template.yaml). It is in the canonical global-first shape.

## Upgrading

```console
$ helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version <new-version> -n br-sisbajud -f my-values.yaml
```

Coming from chart 1.1.x (app `1.0.0-beta.x` / `rc.x`), read [UPGRADE-1.2.md](docs/UPGRADE-1.2.md) first.

### From the monolith (chart 1.2.x, app 1.2.x) to the Mensageria

The chart now deploys a **different application** (br-sfn `services/sisbajud`). It is not an in-place upgrade of a running monolith: plan it as a new deployment (fresh database or a migration plan owned by the app team) and install plugin-br-sisbajud next to it. Values changes:

- **New, required:** `brSisbajud.execution.tls.existingSecret` (the execution API's server certificate; `execution.tls.generate: true` in development only), `brSisbajud.auth.jwtIssuer` + `jwtVerifyCert` / `jwtVerifyCertSecret` (lib-auth local bearer verification, required in both auth switch positions), `global.auth.enabled: true` outside `development|develop|dev|local|test`.
- **Streaming is mandatory** (`global.streaming.enabled: false` is refused) and the **topics Job is off by default**: lib-streaming creates `lerian.streaming.br-sisbajud` and `.dlq` itself.
- **Ports:** the main API moved to `4031` (`service.port`), the execution API is `4032`.
- **br-sta consumer:** dials br-sta's own cluster via `sta.stream` (SASL mandatory); it no longer needs the transfers client, nor reads `global.streaming`. `sta.consumerGroup` is gone (fixed in code).
- **License:** required in a production-like environment only.
- **Removed** (executor side, now in plugin-br-sisbajud): `workers.execution`, `workers.reconciliation`, `workers.permanentBlockExpiry`, `workers.rehashBackfill`, `workers.informationRequest`, `workers.monitoringExpiry`, `balanceConsumer`, `midaz`, `app.version`. Their env keys are dropped even from `brSisbajud.configmap`, and NOTES lists any still set.

## Uninstalling

```console
$ helm uninstall br-sisbajud -n br-sisbajud
```

---

## Configuration model

Every application env key is resolved with this precedence (lerian-common):

1. `brSisbajud.configmap.<KEY>`: the native env key, the escape hatch. It wins over everything. Keys the chart does not model are emitted verbatim, into the ConfigMap: never put a credential (token, password, key) here; use `brSisbajud.secrets` or `brSisbajud.secretRefs`.
2. `brSisbajud.<group>.<field>`: grouped chart parameters (`lerian-common.cfgValue`).
3. `brSisbajud.datastores` / `brSisbajud.kms` / `brSisbajud.objectStorage`: dedicated connection masks for this release.
4. `global.<block>.<field>`: the env-wide contract, set once per environment.
5. `global.cloud`: managed-cloud topology preset (`aws` | `gcp` | `azure`).
6. The chart default (in `templates/_helpers.tpl`).

`brSisbajud.configmap` and `brSisbajud.secrets` are empty by default. Pinning a native key there shadows the grouped/global parameter for that key.

`brSisbajud.secretRefs` (`{ENV_KEY: {name, key[, optional]}}`) references a key of a Secret the chart does not manage (e.g. synced by External Secrets) as an explicit `secretKeyRef` pod env entry. Credentials never need raw `extraEnvVars`, and the fail-fast gates and the migrations/topics Jobs honor them. `brSisbajud.extraEnvVars` (a list of `{name, value|valueFrom}`) is still rendered as explicit pod `env:`, after `secretRefs` and winning on a name clash, and wins over the ConfigMap and the Secret. The fail-fast gates and the topics Job also read it for credentials and streaming TLS, but the KMS gates (key mode, ARN, timeouts, minimum image tag) read only the ConfigMap: an `extraEnvVars` entry such as `KMS_PROVIDER=aws` or `KMS_AWS_*` bypasses them at render, and only the app's boot validation refuses an invalid combination.

### Global contract

| Block | Fields | Env keys |
|-------|--------|----------|
| `global.env` | `name` | `ENVIRONMENT_NAME`, `ENV_NAME`, default of `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` |
| `global.datastores.postgres` | `host`, `port`, `user`, `name`, `ssl`, `replicaHost` | `POSTGRES_HOST/PORT/USER/NAME/SSLMODE`, `POSTGRES_REPLICA_*` |
| `global.datastores.redis` | `host` (`host:port`), `tls`, `caCert` | `REDIS_HOST`, `REDIS_TLS`, `REDIS_CA_CERT` |
| `global.objectStorage.sisbajud` | `endpoint`, `region`, `bucket` | `SEAWEEDFS_S3_ENDPOINT`, `SEAWEEDFS_REGION`, `SEAWEEDFS_BUCKET` |
| `global.objectStorage.sta` | `bucket`, `endpoint` | `STA_INBOUND_BUCKET` (+ `TRANSFER_OBJECT_STORAGE_BUCKET`), `STA_OBJECT_STORAGE_ENDPOINT` |
| `global.kms` | `vendor` (`hashicorp-vault` \| `aws`), `vaultAddr`, `vaultAuthMethod`, `vaultRoleId`, `vaultMount`, `awsRegion`, `awsKeyMode`, `awsKeyArn` | `KMS_PROVIDER`, `VAULT_ADDR`, `VAULT_AUTH_METHOD`, `VAULT_APPROLE_ROLE_ID`, `VAULT_TRANSIT_MOUNT_PATH`, `AWS_REGION`, `KMS_AWS_KEY_MODE`, `KMS_AWS_KEY_ARN` |
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
| `app.deploymentMode` | `DEPLOYMENT_MODE` | `byoc` (`saas` \| `byoc` \| `local`; only `saas` enforces TLS) |
| `app.defaultTenantId` | `DEFAULT_TENANT_ID` | `11111111-1111-1111-1111-111111111111` |
| `app.systemplaneEnabled` | `SYSTEMPLANE_ENABLED` | `false` |
| `app.infraConnectTimeoutSec` | `INFRA_CONNECT_TIMEOUT_SEC` | `30` |
| `app.dbMetricsIntervalSec` | `DB_METRICS_INTERVAL_SEC` | `15` |
| `app.idempotencyRetryWindowSec` | `IDEMPOTENCY_RETRY_WINDOW_SEC` | `300` |
| `app.circuitBreakerEnabled` | `CIRCUIT_BREAKER_ENABLED` | `false` |
| `server.address` | `SERVER_ADDRESS` | `0.0.0.0:<service.port>` |
| `server.bodyLimitBytes` | `HTTP_BODY_LIMIT_BYTES` | `104857600` |
| `server.tlsTerminatedUpstream` | `TLS_TERMINATED_UPSTREAM` | `false` |
| `server.tlsCertFile` / `tlsKeyFile` | `SERVER_TLS_CERT_FILE` / `SERVER_TLS_KEY_FILE` | unset (both or neither; main listener only) |
| `execution.port` | `SISBAJUD_EXECUTION_ADDRESS` (`:<port>`) + container/Service port `execution` | `4032` |
| `execution.mtlsEnabled` | `SISBAJUD_EXECUTION_MTLS_ENABLED` | `false` |
| `execution.tls.{existingSecret,certKey,keyKey,mountPath}` | `SISBAJUD_EXECUTION_TLS_CERT_FILE` / `_KEY_FILE` = `<mountPath>/tls.crt` / `tls.key` | `""` (required) / `tls.crt` / `tls.key` / `/etc/sisbajud/execution-tls` |
| `execution.clientCa.{existingSecret,key,mountPath}` | `SISBAJUD_EXECUTION_CLIENT_CA_FILE` = `<mountPath>/ca.crt` (mTLS only) | `tls.existingSecret` / `ca.crt` / `/etc/sisbajud/execution-client-ca` |
| `executionSweep.responseDeadlineMargin` / `drainedHeadAlarmAfter` | `RESPONSE_DEADLINE_MARGIN` / `EXECUTION_DRAINED_HEAD_ALARM_AFTER` | `2h` / `30m` (the app has no default; positive Go durations) |
| `executionSweep.sweepIntervalSec` / `deadlineMarginSec` / `canaryIntervalSec` | `EXECUTION_SWEEP_INTERVAL_SEC` / `EXECUTION_DEADLINE_MARGIN_SEC` / `EXECUTION_CANARY_INTERVAL_SEC` | `60` / unset (= `returnFile.scanInterval`, must be < 21600) / `300` |
| `cors.allowedOrigins` | `ACCESS_CONTROL_ALLOW_ORIGIN` + `CORS_ALLOWED_ORIGINS` | `""` (set in production: with no origin the CORS middleware denies all) |
| `cors.allowedMethods` | `ACCESS_CONTROL_ALLOW_METHODS` + `CORS_ALLOWED_METHODS` | `GET,POST,PUT,PATCH,DELETE,OPTIONS` |
| `cors.allowedHeaders` | `ACCESS_CONTROL_ALLOW_HEADERS` + `CORS_ALLOWED_HEADERS` | `Origin,Content-Type,Accept,Authorization,X-Request-ID` |
| `cors.exposeHeaders` / `allowCredentials` | `ACCESS_CONTROL_EXPOSE_HEADERS` / `ACCESS_CONTROL_ALLOW_CREDENTIALS` (+ `CORS_*`) | `""` / `false` |
| `security.allowInsecureTls` | `ALLOW_INSECURE_TLS` | `true` only with a bundled subchart, else `false` |
| `security.allowCorsWildcard` / `allowInsecureOtel` / `allowWebhookPrivateNetwork` | `ALLOW_CORS_WILDCARD` / `ALLOW_INSECURE_OTEL` / `ALLOW_WEBHOOK_PRIVATE_NETWORK` | unset |
| `license.organizationIds` | `ORGANIZATION_IDS` | `global` (the only accepted value) |
| `postgres.maxOpenConns` / `maxIdleConns` | `POSTGRES_MAX_OPEN_CONNS` / `POSTGRES_MAX_IDLE_CONNS` | `25` / `5` |
| `postgres.connMaxLifetimeMins` / `connMaxIdleTimeMins` / `connectTimeoutSec` | `POSTGRES_CONN_MAX_LIFETIME_MINS` / `POSTGRES_CONN_MAX_IDLE_TIME_MINS` / `POSTGRES_CONNECT_TIMEOUT_SEC` | `30` / `5` / `10` |
| `redis.db` / `protocol` / `poolSize` / `minIdleConns` | `REDIS_DB` / `REDIS_PROTOCOL` / `REDIS_POOL_SIZE` / `REDIS_MIN_IDLE_CONNS` | `0` / `3` / `10` / `2` |
| `redis.readTimeout` / `writeTimeout` / `dialTimeout` / `poolTimeout` | `REDIS_READ_TIMEOUT` / `REDIS_WRITE_TIMEOUT` / `REDIS_DIAL_TIMEOUT` / `REDIS_POOL_TIMEOUT` | `3` / `3` / `5` / `2` |
| `redis.maxRetries` / `minRetryBackoff` / `maxRetryBackoff` / `masterName` | `REDIS_MAX_RETRIES` / `REDIS_MIN_RETRY_BACKOFF` / `REDIS_MAX_RETRY_BACKOFF` / `REDIS_MASTER_NAME` | `3` / `8` / `1` / unset |
| `vault.timeoutSec` | `VAULT_TIMEOUT_SEC` | `15` |
| `vault.tokenRenewEnabled` / `tokenRenewMinIntervalSec` | `VAULT_TOKEN_RENEW_ENABLED` / `VAULT_TOKEN_RENEW_MIN_INTERVAL_SEC` | `true` / `60` |
| `vault.awsEndpointUrl` | `AWS_ENDPOINT_URL` | unset (LocalStack only) |
| `vault.awsKmsTimeoutSec` | `KMS_AWS_TIMEOUT_SEC` | unset (`1`..`600`); emitted only with `KMS_PROVIDER=aws` |
| `vault.awsKmsRotationCheckIntervalSec` | `KMS_AWS_ROTATION_CHECK_INTERVAL_SEC` | unset (`1`..`86400`, validated in `provided` mode); emitted only with `KMS_PROVIDER=aws` |
| `kms.awsKeyMode` | `KMS_AWS_KEY_MODE` (only when `KMS_PROVIDER=aws`) | unset (`managed` \| `provided`; required with `aws`) |
| `kms.awsKeyArn` | `KMS_AWS_KEY_ARN` (only when `KMS_PROVIDER=aws`) | unset (required with `provided`, must be empty with `managed`) |
| `kms.allowUnverifiableImageTag` | none (render-time acknowledgement) | unset (`true` confirms an `image.tag` the chart cannot verify (any tag outside the canonical form `vX.Y.Z[-(alpha|beta|rc).N]`) is `>= 1.1.0-beta.13`) |
| `crypto.dekCacheTtl` / `dekCacheMaxEntries` / `hmacCoexistenceWindow` | `SISBAJUD_DEK_CACHE_TTL` / `SISBAJUD_DEK_CACHE_MAX_ENTRIES` / `SISBAJUD_HMAC_COEXISTENCE_WINDOW` | `5m` / `50000` / `720h` |
| `layout.responseLayout` / `remittanceLayouts` | `SISBAJUD_RESPONSE_LAYOUT` / `SISBAJUD_REMITTANCE_LAYOUTS` | `auto` / `v111,v2026` |
| `sta.fileLockTtl` | `STA_FILE_LOCK_TTL` | `5` (minutes) |
| `sta.consumerEnabled` / `consumerRetryBudget` | `STA_CONSUMER_ENABLED` / `STA_CONSUMER_RETRY_BUDGET` | `false` / `3` |
| `sta.stream.{brokers,saslMechanism,saslUsername,saslAllowPlaintext,tlsEnabled}` | `STA_STREAM_BROKERS` / `_SASL_MECHANISM` / `_SASL_USERNAME` / `_SASL_ALLOW_PLAINTEXT` / `_TLS_ENABLED` | unset (required with the consumer: brokers, SASL triple, TLS + CA or plaintext opt-in outside production) |
| `sta.sourceProduct` / `bacenSystemCode` | `STA_SOURCE_PRODUCT` / `STA_BACEN_SYSTEM_CODE` | `br-sisbajud` / `JUD` |
| `sta.expectedTenantSt` | `STA_EXPECTED_TENANT_ST` | `""` (always emitted: the app checks presence) |
| `sta.maxInboundSizeBytes` | `STA_MAX_INBOUND_SIZE_BYTES` | `52428800` |
| `sta.transfersEnabled` / `transfersBaseUrl` / `clientId` | `STA_TRANSFERS_ENABLED` / `STA_TRANSFERS_BASE_URL` / `STA_CLIENT_ID` | `false` / `""` / `""` |
| `sta.documentTypeAjud302` / `documentTypeAjud309` | `STA_DOCUMENT_TYPE_AJUD302` / `STA_DOCUMENT_TYPE_AJUD309` | `AJUD302` / `AJUD309` |
| `workers.kekRewrapBackfill.{enabled,scanInterval,batchSize}` | `KEK_REWRAP_BACKFILL_*` | `false` / `300` / `100` |
| `workers.slaAlert.{enabled,scanInterval}` | `SLA_ALERT_*` | `false` / `60` |
| `workers.returnFile.{enabled,scanInterval,limit,environment}` | `RETURN_FILE_GENERATION_*`, `RETURN_FILE_ENVIRONMENT` | `false` / `3600` / `500` / `HOMOLOGATION` |
| `workers.informationReturnFile.{enabled,scanInterval,limit}` | `INFORMATION_RETURN_FILE_GENERATION_*` | `false` / `3600` / `500` |
| `workers.processingLockReaper.{enabled,intervalSec}` | `PROCESSING_LOCK_REAPER_*` | `true` / `300` |
| `outbox.enabled` / `tableName` | `OUTBOX_ENABLED` / `OUTBOX_TABLE_NAME` | `true` / `outbox_events` |
| `outbox.dispatchIntervalSec` / `batchSize` / `publishMaxAttempts` / `publishBackoffMs` | `OUTBOX_DISPATCH_INTERVAL_SEC` / `OUTBOX_BATCH_SIZE` / `OUTBOX_PUBLISH_MAX_ATTEMPTS` / `OUTBOX_PUBLISH_BACKOFF_MS` | `2` / `50` / `3` / `200` |
| `outbox.retryWindowSec` / `maxDispatchAttempts` / `processingTimeoutSec` / `maxFailedPerBatch` | `OUTBOX_RETRY_WINDOW_SEC` / `OUTBOX_MAX_DISPATCH_ATTEMPTS` / `OUTBOX_PROCESSING_TIMEOUT_SEC` / `OUTBOX_MAX_FAILED_PER_BATCH` | `300` / `864` (72h at the 300s retry window, the app default) / `600` / `25` |
| `outbox.includeTenantMetrics` / `allowEmptyTenant` / `priorityEventTypes` | `OUTBOX_INCLUDE_TENANT_METRICS` / `OUTBOX_ALLOW_EMPTY_TENANT` / `OUTBOX_PRIORITY_EVENT_TYPES` | `false` / `true` / unset |
| `streaming.cloudeventsSource` | `STREAMING_CLOUDEVENTS_SOURCE` | `br-sisbajud` (the app refuses any other value) |
| `streaming.clientId` / `healthCheckTimeout` | `STREAMING_CLIENT_ID` / `STREAMING_HEALTH_CHECK_TIMEOUT` | unset / `2s` |
| `streaming.topicAutoProvision` | `STREAMING_TOPIC_AUTO_PROVISION` | `true` (lib-streaming creates `lerian.streaming.br-sisbajud` + `.dlq` at boot; `false` when IaC provisions them) |
| `streaming.topicPartitions` / `topicReplicationFactor` | `STREAMING_TOPIC_PARTITIONS` / `STREAMING_TOPIC_REPLICATION_FACTOR` | unset (broker default) |
| `streaming.closeTimeoutS` | `STREAMING_CLOSE_TIMEOUT_S` | `20` (must stay below the pod `terminationGracePeriodSeconds`: Kubernetes default 30s, not overridden by this chart) |
| (global.streaming.enabled) | `STREAMING_ENABLED` | `true` (mandatory: the app refuses `false`; needs brokers and `OUTBOX_ENABLED=true`) |
| `auth.trustedProxies` / `productName` | `TRUSTED_PROXIES` / `AUTH_PRODUCT_NAME` | `""` / unset |
| `auth.jwtIssuer` | `AUTH_JWT_ISSUER` | unset (required unless auth on + `DEPLOYMENT_MODE=local` + `ENV_NAME=local`) |
| `auth.jwtVerifyCert` | `AUTH_JWT_VERIFY_CERT` (inline public PEM, ConfigMap) | unset |
| `auth.jwtVerifyCertSecret.{name,key}` / `jwtVerifyCertPath` | `AUTH_JWT_VERIFY_CERT_PATH` (`/etc/sisbajud/auth/jwt-verify.pem` when the Secret is mounted) | unset (one cert source is required, same exemption as the issuer) |
| `identity.declarationEnabled` / `host` / `m2mClientId` | `IDP_DECLARATION_ENABLED` / `IDP_HOST` / `IDP_M2M_CLIENT_ID` | `false` / `""` / `""` |
| `m2m.targetService` / `credentialCacheTtlSec` | `M2M_TARGET_SERVICE` / `M2M_CREDENTIAL_CACHE_TTL_SEC` | unset / `300` |
| `observability.serviceName` / `libraryName` | `OTEL_RESOURCE_SERVICE_NAME` / `OTEL_LIBRARY_NAME` | `br-sisbajud` / `github.com/LerianStudio/br-sfn/services/sisbajud` |
| `rateLimit.{enabled,max,windowSec}` | `RATE_LIMIT_ENABLED` / `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_SEC` | `true` / `500` / `60` |
| `rateLimit.{aggressiveMax,aggressiveWindowSec,relaxedMax,relaxedWindowSec}` | `AGGRESSIVE_RATE_LIMIT_*` / `RELAXED_RATE_LIMIT_*` | `100` / `60` / `1000` / `60` |
| `rateLimit.{allowFailOpen,allowDisabled,redisTimeoutMs}` | `ALLOW_RATELIMIT_FAIL_OPEN` / `ALLOW_RATELIMIT_DISABLED` / `RATE_LIMIT_REDIS_TIMEOUT_MS` | `""` / `""` / `500` |
| `swagger.enabled` / `title` / `version` / `basePath` | `SWAGGER_ENABLED` / `SWAGGER_TITLE` / `SWAGGER_VERSION` / `SWAGGER_BASE_PATH` | `false` / `br-sisbajud` / image tag / `/` |
| `swagger.leftDelim` / `rightDelim` | `SWAGGER_LEFT_DELIM` / `SWAGGER_RIGHT_DELIM` | `{{` / `}}` |
| `swagger.description` / `host` / `schemes` | `SWAGGER_DESCRIPTION` / `SWAGGER_HOST` / `SWAGGER_SCHEMES` | unset |
| `pagination.maxLimit` / `maxMonthDateRange` | `MAX_PAGINATION_LIMIT` / `MAX_PAGINATION_MONTH_DATE_RANGE` | `100` / `3` |
| `admin.maxFileContentBytes` / `maxAuditVerifyWindow` | `ADMIN_MAX_FILE_CONTENT_BYTES` / `ADMIN_MAX_AUDIT_VERIFY_WINDOW` | `104857600` / unset |
| `runtime.godebug` / `gotraceback` | `GODEBUG` / `GOTRACEBACK` | unset |

Chart-derived keys: `ENVIRONMENT_NAME`/`ENV_NAME` default to `production`; `POSTGRES_SSLMODE` defaults to `require` (`disable` with the bundled subchart); `VAULT_AUTH_METHOD` defaults to `token` and `VAULT_TRANSIT_MOUNT_PATH` to `transit`; `KMS_PROVIDER` defaults to `vault`; `MULTI_TENANT_ENABLED` and `PLUGIN_AUTH_ENABLED` default to `false`. `OTEL_EXPORTER_OTLP_ENDPOINT` is overridden on the pod by `http://$(HOST_IP):4317` (node-local collector) when telemetry is on and no endpoint is set.

Keys that only matter for local development (`VAULT_PORT`, `VAULT_DEV_*`, `VAULT_APPROLE_ROLE_NAME`, `LOCALSTACK_DEBUG`, `APP_ENV`) and the deprecated lib-auth aliases (`DECLARATION_ENABLED`, `PLUGIN_IDENTITY_HOST`, `M2M_CLIENT_ID`, `M2M_CLIENT_SECRET`) are not rendered. Set them under `brSisbajud.configmap` / `brSisbajud.secrets` if you need them. The advanced lib-streaming knobs (`STREAMING_BATCH_MAX_BYTES`, `STREAMING_RECORD_RETRIES`, `STREAMING_CB_*`, ...) work the same way.

**AWS KMS key mode.** With `KMS_PROVIDER=aws` the key mode is now required: set `brSisbajud.kms.awsKeyMode` (or `global.kms.awsKeyMode`); `provided` also needs `awsKeyArn`, `managed` rejects it. Key mode and ARN follow `brSisbajud.configmap` > `brSisbajud.kms` > `global.kms`. The timeout and rotation interval are set under `brSisbajud.vault` (`awsKmsTimeoutSec`, `awsKmsRotationCheckIntervalSec`); `KMS_AWS_*` keys in the free-form `brSisbajud.configmap` still win as the native override. Mode and ARN are trimmed both for validation and in the ConfigMap; `KMS_AWS_TIMEOUT_SEC` (in every aws mode) and `KMS_AWS_ROTATION_CHECK_INTERVAL_SEC` (only in `provided` mode) are validated after trimming but rendered as set (the app trims them at boot). `"+30"` is refused at render although the app accepts it (deliberately stricter).

- Minimum image: `sisbajud-v1.1.0-beta.13` (chart value `brSisbajud.image.tag >= 1.1.0-beta.13`). Older images (such as `1.0.0`) ignore the key mode and create their own KMS key, so the chart fails the render on them.
- Only a tag in the canonical form `^v?X.Y.Z(-(alpha|beta|rc).N)?$` is verifiable (e.g. `1.1.0-beta.13`, `v1.2.0`, `1.2.0-rc.2`); it is compared with the minimum. Every other tag fails closed unless `brSisbajud.kms.allowUnverifiableImageTag: true`: non-SemVer (`latest`, mirror tags), other suffixes such as arch tags (`1.1.0-beta.13-amd64`, `1.2.0-beta1`) and build metadata (`1.2.0+build.5`), even when the version part is above the minimum. With the flag set such a tag passes without any version check, even one whose label is below the minimum (e.g. `1.1.0-beta.12-amd64`): the chart does not read the label of a non-canonical tag, so the acknowledgement is the operator's word that the image has key modes. This flag is per chart only: setting it under `global.kms` has no effect.
- A tag containing `@` (`tag@digest` or digest-only) also requires `brSisbajud.kms.allowUnverifiableImageTag: true`, even when the tag part is canonical: the kubelet pulls by digest, so the label cannot be verified against the minimum. With the flag set no version check is made. A canonical tag below the minimum fails even with the flag.
- This is the first gate in this repo that treats `@` as a signal: other charts' minimum-version gates strip the digest or fail open on it. The deviation is deliberate (DR-04).
- Residual: a mutable SemVer tag re-pushed in a mirror is still only a label; the chart cannot detect it.
- A digest-only tag (`image.tag: "@sha256:…"`) is not supported by this chart's image template: it renders `repo:@sha256:…`, which the kubelet rejects.
- AWS credentials come via IRSA (`serviceAccount` annotations) or `secretRefs`; this chart has no `rolesAnywhere` block.

### Secrets

| Key | Required when |
|-----|---------------|
| `POSTGRES_PASSWORD` | External Postgres in a production-like environment (single-tenant) |
| `POSTGRES_REPLICA_PASSWORD` | Optional (replica with its own password) |
| `REDIS_PASSWORD` | The external Redis requires auth |
| `LICENSE_KEY` | Production-like environment (empty = dev bypass in `local|development|staging|e2e|test`) |
| `VAULT_APPROLE_SECRET_ID` | `global.kms.vaultAuthMethod: approle` |
| `VAULT_TOKEN` | `vaultAuthMethod: token` and `ENVIRONMENT_NAME=production` |
| `STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` | SASL mechanism set / a private broker CA (empty = system trust pool; the topics Job requires it with TLS) |
| `SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` | The object store requires static credentials |
| `STA_CLIENT_SECRET` | `sta.transfersEnabled` |
| `STA_STREAM_SASL_PASSWORD` / `STA_STREAM_TLS_CA_CERT` | `sta.consumerEnabled` / `sta.stream.tlsEnabled` (base64 PEM) |
| `IDP_M2M_CLIENT_SECRET` | `identity.declarationEnabled` |
| `MULTI_TENANT_SERVICE_API_KEY` / `MULTI_TENANT_REDIS_PASSWORD` | Multi-tenancy on / tenant Redis requires auth |

The Deployment lists the ConfigMap before the Secret in `envFrom`, so a Secret key always wins over a ConfigMap key of the same name.

### Fail-fast gates

The render fails with the exact value to set (mirroring `internal/bootstrap/config_validation.go`) when:

- `STA_INBOUND_BUCKET` is empty (always: the app has no default by policy);
- `POSTGRES_HOST` / `REDIS_HOST` are empty in single-tenant mode;
- `KMS_PROVIDER` is not `vault`/`aws`, or its credentials are missing (`VAULT_ADDR`, AppRole role/secret id, `VAULT_TOKEN` in `production`, `AWS_REGION` for AWS KMS);
- streaming is off or the outbox is off (the Mensageria refuses both), or on without `STREAMING_BROKERS`, without TLS in a production-like environment, or with `streaming.closeTimeoutS` not below 30; or a SASL mechanism is set without a username/password or without TLS;
- `PLUGIN_AUTH_ENABLED` is `false` outside a development-class `ENV_NAME` (`development|develop|dev|local|test`) or with `DEPLOYMENT_MODE=saas`;
- no JWT verification source (`AUTH_JWT_VERIFY_CERT` / `_PATH`) or no `AUTH_JWT_ISSUER`, unless auth is on with `DEPLOYMENT_MODE=local` and `ENV_NAME=local`;
- the execution listener has no server certificate Secret (or, with mTLS, no client CA), or `execution.tls.generate` is used outside a development-class environment;
- `RESPONSE_DEADLINE_MARGIN` / `EXECUTION_DRAINED_HEAD_ALARM_AFTER` are not positive Go durations;
- the br-sta consumer is on without `sta.stream` brokers, the SASL triple, TLS + CA (or the plaintext opt-in, refused in production) or a non-empty `sta.expectedTenantSt`; the consumer or the transfers client is on with multi-tenancy;
- `LICENSE_KEY` is missing in a production-like environment, or a production-like environment lacks the external Postgres password;
- the STA transfers client, inbound auth or the declaration publisher is on without its host/client credentials;
- multi-tenancy is on without the tenant-manager URL, its Redis host or the service API key;
- `ORGANIZATION_IDS` is empty in a production-like environment, or anything but `global`.

A value supplied through `brSisbajud.extraEnvVars` satisfies the gate. With `useExistingSecret`, the gates skip the Secret keys.

---

## Detached migrations

`migrations.enabled` (default `true`) ships a Job that runs `ghcr.io/lerianstudio/br-sisbajud-migrations` (golang-migrate). Against external Postgres it is a Helm `pre-install,pre-upgrade` hook and an ArgoCD **PreSync** hook (weight `-1`), so both `helm install/upgrade` and ArgoCD migrate before the app rolls. The Job follows the app's resolved Postgres connection; `migrations.postgres.*` overrides it field by field.

The password comes from the **same source the app effectively uses**. Explicit migration overrides come first, then the app's own precedence (pod `env:` wins over the subchart reference, which wins over `envFrom`):
1. `migrations.useExistingSecret`;
2. `migrations.postgres.password`;
3. a `brSisbajud.extraEnvVars` `POSTGRES_PASSWORD` entry (reused verbatim);
4. the bundled subchart or `postgresql.auth.existingSecret`;
5. `brSisbajud.useExistingSecret`;
6. `brSisbajud.secrets.POSTGRES_PASSWORD`.

Sources 2 and 6 are copied into a dedicated hook Secret (weight `-2`), because the app Secret does not exist yet in pre-install/PreSync. With plain Helm, that Secret is deleted once the hook phase succeeds (`hook-succeeded`), so no copy of the password is left behind, including after uninstall. With ArgoCD it is replaced on each sync. With none set, the render fails. With the bundled `postgresql`, `migrations.postgres.password` is refused at render: the app's `migrations` initContainer would have to read it from that hook Secret, which only exists while the post-install hooks run. The bundled subchart Secret (or `migrations.useExistingSecret`) is used instead. The Job pod is hardened (non-root, read-only rootfs, drop ALL, no service-account token) and waits for Postgres with a `busybox` initContainer.

## Execution API (plugin-br-sisbajud)

The Mensageria serves `/v1/sisbajud/execution/*` only on its own listener, `SISBAJUD_EXECUTION_ADDRESS` (`:4032`), exposed on the chart Service as port `execution`. TLS is terminated **in the pod** in every `DEPLOYMENT_MODE`: there is no plain-HTTP or upstream-TLS mode for it, a bearer token (the plugin's M2M token from plugin-access-manager) is always required, and the app refuses to boot without the server certificate and key.

- `execution.tls.existingSecret`: a Secret with the server certificate and key (e.g. a cert-manager `Certificate`), mounted read-only (0440, `fsGroup` 65532) at `/etc/sisbajud/execution-tls`. Its SANs must contain the name the plugin dials, normally `<fullname>.<namespace>.svc.cluster.local`. Rotation needs a rollout restart.
- `execution.mtlsEnabled: true` makes the listener require a client certificate signed by `execution.clientCa` (default: `ca.crt` of the TLS Secret, which cert-manager fills). The plugin then needs `MENSAGERIA_MTLS_ENABLED=true` and a client pair (with `clientAuth` EKU) chained to that CA; with `false` (default), the plugin only needs to trust the server CA.
- `execution.tls.generate: true` (development-class environments only) creates a CA + server certificate for the Service DNS names in `<fullname>-execution-tls` (keys `tls.crt`, `tls.key`, `ca.crt`), reused via `lookup`. Under ArgoCD (no `lookup`) it regenerates on each sync.
- Plugin side: `MENSAGERIA_BASE_URL=https://<fullname>.<namespace>.svc.cluster.local:4032`, the server CA as its Mensageria CA file, and `RESPONSE_DEADLINE_MARGIN` equal to `executionSweep.responseDeadlineMargin`.

## Topic provisioning

The Mensageria produces one topic, `lerian.streaming.br-sisbajud`, plus `.dlq`. lib-streaming v4.1 creates both at boot when `STREAMING_TOPIC_AUTO_PROVISION` is `true` (default, `streaming.topicAutoProvision`) and its principal holds `CreateTopics` on them (without it, it only logs a WARN); `streaming.topicPartitions` / `topicReplicationFactor` tune that creation. So `topics.enabled` defaults to **`false`**. Enable it only for a broker whose app principal lacks `CreateTopics`: it ships a Helm pre-install/pre-upgrade + ArgoCD PreSync Job (`rpk`, list-then-create, idempotent) with the app's resolved broker, TLS and SASL settings (SASL password and CA from a dedicated hook Secret, the existing Secret, or `extraEnvVars`). br-sfn publishes no Mensageria topics image, so the Job runs the product-agnostic `ghcr.io/lerianstudio/br-sisbajud-topics:1.2.0` (pinned, not `appVersion`). `lerian.streaming.br-sta` belongs to br-sta: never list it. `topics.partitions`, `topics.replicationFactor` (must not exceed the broker count) and `topics.retentionMs` tune creation.

## Bundled infrastructure (development only)

> **Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure.** Production means PostgreSQL with TLS, Valkey/Redis, Kafka/Redpanda with TLS, Vault/OpenBao in non-dev mode (or AWS KMS) and S3 object storage. The bundled `postgresql`, `valkey`, `seaweedfs`, `openbao` and `redpanda` subcharts exist for development, POC and quickstart installs. The render refuses the OpenBao and Redpanda bundles outside a development-class environment (`local`, `development`, `develop`, `dev`, `test`, `e2e`; staging is refused). The PostgreSQL, Valkey and SeaweedFS bundles only get a NOTES warning in a production-like environment, but they are unsupported in production all the same.

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

It runs with `ENVIRONMENT_NAME=development`, which relaxes the app's production gates: plaintext Postgres and broker, `PLUGIN_AUTH_ENABLED=false` and an empty `LICENSE_KEY` (the dev bypass) are allowed. It generates a dev execution TLS certificate (`execution.tls.generate`) and ships a **throwaway** JWT verification public key (its private half was discarded), so the app boots but no bearer verifies until you set your Access Manager's public key and issuer (`brSisbajud.auth`). Inbound auth, the access-manager declaration publisher, the br-sta consumer/transfers client and multi-tenancy are off. plugin-access-manager, br-sta and the Midaz ledger are not bundled, so institutions are still seeded via the admin API.

### With a br-sta dev bundle

[`values-dev-with-br-sta.yaml`](values-dev-with-br-sta.yaml), layered on `values-dev.yaml`, wires br-sisbajud to a br-sta dev bundle (release `br-sta`) in the same namespace: it reuses br-sta's SeaweedFS and Redpanda (the STA transfer bucket and endpoint then match, `sta_bucket_parity` is up) and points the transfers client at `http://br-sta-manager:4028`. The br-sta business-fact consumer stays off: the Mensageria requires SASL on br-sta's cluster (`sta.stream`), which the br-sta dev Redpanda does not offer. Install br-sta with `--set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]'` so its bucket Job also creates br-sisbajud's own bucket. There is no plugin-access-manager in either bundle, so the transfers client cannot mint its m2m bearer; transfer submission needs a real `global.auth.host`.

### Derived connections

With a subchart enabled and no explicit value (`configmap` > dedicated mask > `global.*` still wins):

| Key | Derived from |
|-----|--------------|
| `POSTGRES_HOST` / `REDIS_HOST` | Bitnami Services; passwords via `secretKeyRef` to the subchart Secrets |
| `SEAWEEDFS_S3_ENDPOINT` (+ `STA_OBJECT_STORAGE_ENDPOINT`) | `http://<seaweedfs.nameOverride\|seaweedfs>-s3.<release ns>.svc.cluster.local:<s3.port>` |
| `VAULT_ADDR` | `http://<release>-openbao.<release ns>.svc.cluster.local:8200` (collapse-aware); `KMS_PROVIDER=vault`, `VAULT_AUTH_METHOD=token` |
| `VAULT_TOKEN` | `secretKeyRef` to the chart-generated dev-token Secret (`br-sisbajud-openbao-dev-token`, key `token`) |
| `STREAMING_BROKERS` | `<redpanda.fullnameOverride\|release>.<release ns>.svc.cluster.local.:9093`, injected at the `global.streaming` tier |

`POSTGRES_SSLMODE` defaults to `disable` and `ALLOW_INSECURE_TLS` to `true` with a bundled datastore.

### Bootstrap Jobs

- **Buckets** (`<release>-seaweedfs-buckets`, Helm post-install/post-upgrade, ArgoCD PostSync). The app never creates buckets. This Job creates `SEAWEEDFS_BUCKET`, `STA_INBOUND_BUCKET`, `TRANSFER_OBJECT_STORAGE_BUCKET` and `seaweedfsBuckets.extraBuckets` with `weed shell` (list, create the missing ones, verify).
- **Transit** (`<release>-openbao-transit`, same hooks). It mounts the Transit engine at `VAULT_TRANSIT_MOUNT_PATH` if it is absent. No key is pre-created: the app creates its KEKs (`sisbajud-kek-<institution>`, `sisbajud-kek-connector-<institution>`) itself at boot and per institution. The Job authenticates with the dev token from the app Secret.
- **Migrations / topics** (topics only when `topics.enabled`). With their dependency bundled, these Jobs run as Helm post-install/post-upgrade / ArgoCD **Sync** hooks: a PreSync hook would wait forever for infra created in the same sync. They wait for Postgres / the broker in an initContainer. Against external infra they are Helm pre-install/pre-upgrade + ArgoCD PreSync hooks.

- **App boot ordering.** With a dependency bundled, the app pod itself runs idempotent initContainers before the app starts: `migrate up` (the migrations container, lock-protected), wait-for-broker, the topics entrypoint (list-then-create), and the Transit mount itself (idempotent `bao secrets enable`, so `helm install --wait` cannot deadlock on the post-install Transit Job). The app never boots on a missing schema, missing topics or an unmounted Transit (verified on minikube: 0 restarts, `/readyz` healthy on first start). Against external infra these initContainers are not rendered.

All the bootstrap Jobs are idempotent, non-root with a read-only rootfs (PSS restricted), carry native-sidecar mesh annotations, and are replaced on each run (`before-hook-creation`). The finished Job stays until `ttlSecondsAfterFinished`.

### Production guard

The render **fails** when `openbao` or `redpandaBundle` is enabled outside a development-class environment, that is anything but `local|development|develop|dev|test|e2e` (case-insensitive). **Staging is refused too**: the app relaxes its own gates in `staging` (plaintext Postgres and broker), but a staging tier holds data someone expects to keep, and OpenBao dev mode loses every Transit key on a restart:

- OpenBao dev mode keeps its keys in memory: a pod restart loses every Transit key, and the data encrypted under them becomes **unrecoverable**.
- The Redpanda bundle is a single plaintext broker.

The guard only decides whether the dev-only bundles render. The app's own relaxations are separate: only `local|development|staging|e2e|test` relax its gates (`dev` and `develop` pass the guard, but the app treats them as production, so they still need TLS). Those five also skip the license (an empty `LICENSE_KEY` is the dev bypass); `PLUGIN_AUTH_ENABLED=false` follows a different list (`development|develop|dev|local|test`). A dev install uses `development`, as `values-dev.yaml` does.

The postgresql / valkey / seaweedfs bundles render in any environment, as in the sibling charts, and NOTES.txt warns when they run production-like. That is a warning, not support: they are unsupported in production. Kafka/Redpanda and the KMS are external in production: set `global.streaming` and `global.kms`.

### Caveats

- **S3 auth is OFF** (`seaweedfs.s3.enableAuth: false`). To enable it, set `seaweedfs.s3.enableAuth: true` + `seaweedfs.s3.existingConfigSecret`, and put the keys in `brSisbajud.secrets.SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` (Secret only).
- **OpenBao restarts lose its keys.** The next `helm upgrade` / sync re-mounts Transit, but previously encrypted rows are unreadable: reset the database too.
- **The OpenBao dev root token is generated per install.** It is a random 40-character value in the Secret named in `openbao.server.extraSecretEnvironmentVars` (default `br-sisbajud-openbao-dev-token`), reused on upgrade via `lookup`. OpenBao reads it as `BAO_DEV_ROOT_TOKEN_ID`, which wins over the subchart's plaintext `VAULT_DEV_ROOT_TOKEN_ID` default, so that default is not a working token. The app, the Transit Job and the `transit` initContainer read the same Secret, under the same `secretKey`. Under GitOps, where `lookup` sees nothing, set `openbaoDevToken.token` (an AVP placeholder) or the token rotates on every render. The Secret name is fixed: one bundled OpenBao per namespace.
- **Images.** The `bitnami/*` tags that postgresql 16.3.5 / valkey 2.4.7 default to were removed from Docker Hub. The chart pins the same tags from `bitnamilegacy/*` (`postgresql:17.2.0-debian-12-r5`, `valkey:8.0.2-debian-12-r6`) by tag, with `global.security.allowInsecureImages: true`. SeaweedFS and the bucket Job run `chrislusf/seaweedfs:3.93`. OpenBao and the Transit Job run `quay.io/openbao/openbao:2.7.0`. Redpanda runs its chart default (`docker.redpanda.com/redpandadata/redpanda:v26.2.3`).
- **The app, migrations and topics images** (`ghcr.io/lerianstudio/br-sisbajud`, `br-sisbajud-migrations`, `br-sisbajud-topics`) are public on GHCR: no pull secret is needed. To pull them from a private mirror/registry, set top-level `imagePullSecrets` (default `[]`), which covers the app, migrations, topics and bucket pods; `brSisbajud/migrations/topics.imagePullSecrets` override it per workload.
- **The bundled Valkey regenerates an empty password on every render** (upstream Bitnami), which rotates it and restarts Valkey and the app on each `helm upgrade`. `values-dev.yaml` pins public dev passwords for PostgreSQL and Valkey; set them explicitly in any other dev values file. After changing them, delete the PVCs (the Postgres volume keeps the first password).

{% endraw %}
