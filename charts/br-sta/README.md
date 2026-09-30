# br-sta Helm Chart

{% raw %}

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `common.secrets.MASTER_KEYS` always (credential envelope-encryption key material; the manager aborts boot without it). In `production` (the default environment): `POSTGRES_PASSWORD` (external Postgres), `RABBITMQ_DEFAULT_PASS` (or a full `RABBITMQ_URL`) and `LICENSE_KEY`. `STREAMING_SASL_PASSWORD` when a SASL mechanism is set; `IDP_M2M_CLIENT_SECRET` when the access-manager declaration publisher is on; `MULTI_TENANT_SERVICE_API_KEY` when multi-tenancy is on; `RABBITMQ_DEFAULT_PASS` + `RABBITMQ_ERLANG_COOKIE` with the bundled RabbitMQ. The chart fails the render with the exact key to set when one is missing. With `common.useExistingSecret`, the operator Secret must carry them. With the bundled `postgresql` / `valkey` subcharts, their passwords are single-sourced from the subchart Secrets (`secretKeyRef`). No credential is ever placed in a ConfigMap.
- Dependency notes: `lerian-common-helm` (library, env contracts and masks). Bundled `postgresql` (16.3.5), `valkey` (2.4.7), `rabbitmq` (groundhog2k 2.1.11), `seaweedfs` (4.0.393) and `redpanda` (26.2.4, dev only) subcharts, plus an optional mock STA server (dev only), are declared but **disabled by default** (`values-dev.yaml` turns them all on). Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure. External PostgreSQL, Valkey/Redis, RabbitMQ, S3 and Kafka are the production path; Redpanda and the mock STA are refused outside a development-class environment. plugin-access-manager, the tenant manager and BACEN STA itself are external services.
- Production overrides: `global.datastores` (postgres, redis, broker), `global.objectStorage` (sta, staAuditExports), `global.kms`, `global.auth`, `global.streaming`, `global.env`, the Secret keys above (or `common.useExistingSecret`/`existingSecretName`, and `migrations.useExistingSecret`), `common.cors.allowedOrigins`, `common.license.organizationIds`, `common.bacen.environment`, ingress, resources and autoscaling.
- Source/license: Source is in `github.com/LerianStudio/helm`; chart license is Apache-2.0. The br-sta service itself is proprietary (Lerian Studio); its images are private on GHCR.

Deploys **br-sta**, the Lerian BACEN STA (Sistema de Transferência de Arquivos) service: file transfers to and from BACEN, the BACEN operator credentials (envelope-encrypted), and a hash-chained audit trail. It runs as two components from one release train:

| Component | Image | Role |
|-----------|-------|------|
| `manager` | `ghcr.io/lerianstudio/br-sta-manager` | HTTP API (`:4028`): transfers (`POST /v1/transfers`), inbound transfers, credentials, audit read API, connectivity probe |
| `worker` | `ghcr.io/lerianstudio/br-sta-worker` | Background process (probe server `:4029`): the BACEN outbound scheduler (the **only** path that uploads to BACEN), inbound polling, audit publisher/consumer, business-event delivery, partition manager, verifier, export generator, reporter bridge. Exactly one replica, `Recreate` |
| migrations | `ghcr.io/lerianstudio/br-sta-migrations` | Applies the SQL schema (single-tenant) |

The chart tracks application **1.0.0** (`appVersion`), the first stable STA release; the three images follow `appVersion` unless pinned.

> **Version line reset.** The app's pre-releases were numbered `1.2.0-beta.x`; its first stable release restarted at `1.0.0`. `1.0.0` has lower SemVer precedence than every `1.2.0-beta.x`, but it is the later release of the same code lineage: the env contract and the migration sequence `000001`–`000019` are unchanged, so moving from `1.2.0-beta.16` to `1.0.0` is a compatible upgrade (no schema reset, no env change). Tooling that picks "the highest version" would pick the betas: pin `1.0.0` explicitly.

---

## Required external components

| Component | Used for | Chart surface |
|-----------|----------|---------------|
| PostgreSQL | Transfers, credentials, audit trail, outbox | `global.datastores.postgres` + `secrets.POSTGRES_PASSWORD` |
| Valkey / Redis | Rate limiting, idempotency, scheduler leader election | `global.datastores.redis` + `secrets.REDIS_PASSWORD` |
| RabbitMQ | Audit transport (mandatory in production) and the business-event channel | `global.datastores.broker` + `secrets.RABBITMQ_DEFAULT_PASS` (or `RABBITMQ_URL`) |
| S3-compatible object storage | The transfer bucket (both directions) and audit exports | `global.objectStorage.sta` / `staAuditExports` + `secrets.AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (or IRSA) |
| Kafka / Redpanda (optional) | Business facts on `lerian.streaming.br-sta` (+ `.dlq`) | `global.streaming` + `secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` |
| plugin-access-manager | Inbound JWT validation (mandatory outside a development-class env), permission declaration | `global.auth`, `common.identity` |
| Lerian license | Runtime license validation (enforced in production) | `secrets.LICENSE_KEY`, `common.license.organizationIds` |
| BACEN STA (RSFN) | The upstream: `sta-h.bcb.gov.br` (homologation) / `sta.bcb.gov.br` (production) | `common.bacen.environment` |
| Tenant manager (optional) | Multi-tenancy | `global.multiTenant` + `secrets.MULTI_TENANT_SERVICE_API_KEY` |

The BACEN operator credentials and the document-type configs are **not** configured through this chart: they are registered through the API (`/v1/credentials`, the config API) and stored envelope-encrypted under `MASTER_KEYS`.

---

## Install

```console
$ helm install br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version <version> -n br-sta --create-namespace -f my-values.yaml
```

For a step-by-step installation (dev bundle, pairing with br-sisbajud, production), validation and known errors, see the getting-started runbook: [English](docs/00-getting-start.en.md) · [Português](docs/00-getting-start.md).

Start `my-values.yaml` from [`values-template.yaml`](values-template.yaml). It is in the canonical global-first shape.

## Upgrading

```console
$ helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version <new-version> -n br-sta -f my-values.yaml
```

Coming from the pre-release `br-sta-helm` 1.0.0-beta.x charts: the values moved to the productized shape. The app block `br-sta:` becomes `common:` (shared config and secrets) plus `manager:` (the Deployment), the worker keeps `worker:`, and every native env key under `br-sta.configmap` / `br-sta.secrets` goes to `common.configmap` / `common.secrets` (or, better, to the matching `global.*` mask / grouped parameter). The manager Service is now `<release-name-base>-manager` on port `4028`, and `otel-collector-lerian.enabled` is replaced by `global.observability.enabled`.

### Keeping an existing in-cluster address

The manager Service is `<fullname>-manager:4028` by default. To keep an address clients already call (e.g. `br-sta:8080` from the pre-release chart), set only values: the Service name and port change, the container keeps listening on the app's `4028`:

```yaml
manager:
  containerPort: 4028   # SERVER_ADDRESS / containerPort
  service:
    name: br-sta        # Service metadata.name
    port: 8080          # Service port -> targetPort http (4028)
```

The manager Ingress follows the Service name, so an existing Ingress is updated in place (no duplicate host). `manager.deploymentAnnotations` / `worker.deploymentAnnotations` annotate the Deployment objects, e.g. a one-off `argocd.argoproj.io/sync-options: Replace=true,Force=true` when an older release left a same-named Deployment with a different (immutable) selector.

## Uninstalling

```console
$ helm uninstall br-sta -n br-sta
```

---

## Configuration model

Both binaries read the SAME configuration, so the app environment is one shared ConfigMap and one shared Secret (the `common` block, named `<fullname>`), loaded by the manager and the worker via `envFrom`. The worker adds a small ConfigMap of worker-only keys (`<fullname>-worker`, loaded last, so it wins for the worker).

Every application env key is resolved with this precedence (lerian-common):

1. `common.configmap.<KEY>` (or `worker.configmap.<KEY>` for a worker-only key): the native env key, the escape hatch. It wins over everything. Keys the chart does not model are emitted verbatim.
2. `common.<group>.<field>` / `worker.<group>.<field>`: grouped chart parameters (`lerian-common.cfgValue`).
3. `common.datastores` / `common.kms` / `common.objectStorage`: dedicated connection masks for this release.
4. `global.<block>.<field>`: the env-wide contract, set once per environment.
5. `global.cloud`: managed-cloud topology preset (`aws` | `gcp` | `azure`).
6. The chart default (in `templates/_helpers.tpl`).

`common.configmap`, `common.secrets` and `worker.configmap` are empty by default. Pinning a native key there shadows the grouped/global parameter for that key.

`manager.extraVolumes`/`extraVolumeMounts` and the `worker.*` equivalents add pod volumes and container mounts, e.g. a private CA bundle: the app trusts the system certificate pool for the RabbitMQ management API and `amqps` (there is no CA key for them), so a private CA is supplied as a bundle file plus `SSL_CERT_FILE` in `extraEnvVars`. `manager.extraEnvVars` / `worker.extraEnvVars` (lists of `{name, value|valueFrom}`) are rendered as explicit pod `env:` and win over the ConfigMaps and the Secret. The fail-fast gates count an `extraEnvVars` entry only when it reaches every enabled app pod (set on both `manager` and `worker`), since both binaries need the same configuration.

### Global contract

| Block | Fields | Env keys |
|-------|--------|----------|
| `global.env` | `name` | `ENV_NAME`, default of `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` |
| `global.datastores.postgres` | `host`, `port`, `user`, `name`, `ssl`, `replicaHost` | `POSTGRES_HOST/PORT/USER/NAME/SSLMODE`, `POSTGRES_REPLICA_*` |
| `global.datastores.redis` | `host` (`host:port`), `tls`, `caCert` | `REDIS_HOST`, `REDIS_TLS`, `REDIS_CA_CERT` |
| `global.datastores.broker` | `host`, `amqpPort`, `port` (management), `user`, `scheme` | `RABBITMQ_HOST`, `RABBITMQ_PORT_AMQP`, `RABBITMQ_PORT_HOST`, `RABBITMQ_DEFAULT_USER`, `RABBITMQ_SCHEME` |
| `global.objectStorage.sta` | `endpoint`, `region`, `bucket`, `usePathStyle` | `TRANSFER_S3_ENDPOINT`, `TRANSFER_S3_REGION`, `TRANSFER_OBJECT_STORAGE_BUCKET`, `TRANSFER_S3_PATH_STYLE` |
| `global.objectStorage.staAuditExports` | `endpoint`, `region`, `bucket`, `usePathStyle` (default to `sta`, except the bucket) | `AUDIT_EXPORT_GENERATOR_S3_*` |
| `global.kms` | `vendor` (`envvar` \| `aws`), `keyId`, `awsRegion` | `MASTER_KEY_PROVIDER` (`envvar` \| `aws-kms`), `MASTER_KEY_KMS_KEY_ID`, `MASTER_KEY_KMS_REGION` |
| `global.auth` | `enabled`, `host` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` |
| `global.streaming` | `enabled`, `brokers`, `tlsEnabled`, `saslMechanism`, `saslUsername`, `saslAllowPlaintext`, `compression`, `requiredAcks`, `batchLingerMs`, `importantEmitTimeoutMs` | `STREAMING_ENABLED` + `STREAMING_*` transport keys |
| `global.multiTenant` | `enabled`, `url`, `redisHost`, `redisPort`, `redisTls`, `redisCaCert` | `MULTI_TENANT_*` |
| `global.observability` | `enabled`, `otlpEndpoint`, `deploymentEnvironment` | `ENABLE_TELEMETRY`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` |
| `global.cloud` | `aws` \| `gcp` \| `azure` | TLS/ssl/scheme defaults for the masks above |

### Environment classes

| `ENV_NAME` | Effect |
|------------|--------|
| `production` (default) | The app's production gates: `POSTGRES_PASSWORD`, no `sslmode=disable`, mandatory RabbitMQ + outbox, transfer bucket, business channel, `LICENSE_KEY` + `ORGANIZATION_IDS`; Swagger forced off, rate limiting forced on. The chart mirrors them as render failures. |
| `development`, `develop`, `dev`, `local`, `test` | Development class: `PLUGIN_AUTH_ENABLED=false` is accepted (it is the chart default there), no license enforcement without a key, dev-only bundles allowed. |
| anything else (e.g. `staging`) | Not production (no production gates), but inbound auth stays mandatory (`PLUGIN_AUTH_ENABLED` defaults to `true`) and dev-only bundles are refused. |

### Grouped parameters and defaults

Shared (`common.*`):

| Parameter | Env key | Default |
|-----------|---------|---------|
| `app.logLevel` / `defaultTenantId` | `LOG_LEVEL` / `DEFAULT_TENANT_ID` | `info` / `11111111-1111-1111-1111-111111111111` |
| `app.deploymentMode` / `configApiEnabled` | `DEPLOYMENT_MODE` / `CONFIG_API_ENABLED` | unset (app: not saas / `true`) |
| `app.systemplaneEnabled` / `circuitBreakerEnabled` | `SYSTEMPLANE_ENABLED` / `CIRCUIT_BREAKER_ENABLED` | `false` / `false` |
| `app.infraConnectTimeoutSec` / `dbMetricsIntervalSec` / `idempotencyRetryWindowSec` | `INFRA_CONNECT_TIMEOUT_SEC` / `DB_METRICS_INTERVAL_SEC` / `IDEMPOTENCY_RETRY_WINDOW_SEC` | `30` / `15` / `300` |
| `server.address` | `SERVER_ADDRESS` | `0.0.0.0:<manager.containerPort>` (worker: `0.0.0.0:<worker.port>`) |
| `server.bodyLimitBytes` / `tlsTerminatedUpstream` | `HTTP_BODY_LIMIT_BYTES` / `TLS_TERMINATED_UPSTREAM` | `104857600` / `false` |
| `server.tlsCertFile` / `tlsKeyFile` | `SERVER_TLS_CERT_FILE` / `SERVER_TLS_KEY_FILE` | unset (both or neither) |
| `server.trustedProxies` | `SERVER_TRUSTED_PROXIES` | `""` (trust no proxy) |
| `cors.allowedOrigins` / `allowedMethods` / `allowedHeaders` | `CORS_ALLOWED_ORIGINS` / `CORS_ALLOWED_METHODS` / `CORS_ALLOWED_HEADERS` | `""` / `GET,POST,PUT,PATCH,DELETE,OPTIONS` / `Origin,Content-Type,Accept,Authorization,X-Request-ID` |
| `cors.exposeHeaders` / `allowCredentials` | `CORS_EXPOSE_HEADERS` / `CORS_ALLOW_CREDENTIALS` | `""` / `false` |
| `security.allowInsecureTls` | `ALLOW_INSECURE_TLS` | `true` only with a bundled plaintext datastore, else `false` |
| `security.allowCorsWildcard` / `allowInsecureOtel` | `ALLOW_CORS_WILDCARD` / `ALLOW_INSECURE_OTEL` | unset |
| `license.organizationIds` / `isDevelopment` | `ORGANIZATION_IDS` / `IS_DEVELOPMENT` | unset (organizationIds required in production) |
| `postgres.maxOpenConns` / `maxIdleConns` / `connMaxLifetimeMins` / `connMaxIdleTimeMins` / `connectTimeoutSec` | `POSTGRES_MAX_OPEN_CONNS` / `..._MAX_IDLE_CONNS` / `..._CONN_MAX_LIFETIME_MINS` / `..._CONN_MAX_IDLE_TIME_MINS` / `..._CONNECT_TIMEOUT_SEC` | `25` / `5` / `30` / `5` / `10` |
| `redis.db` / `protocol` / `poolSize` / `minIdleConns` | `REDIS_DB` / `REDIS_PROTOCOL` / `REDIS_POOL_SIZE` / `REDIS_MIN_IDLE_CONNS` | `0` / `3` / `10` / `2` |
| `redis.readTimeout` / `writeTimeout` / `dialTimeout` / `poolTimeout` | `REDIS_READ_TIMEOUT` / `REDIS_WRITE_TIMEOUT` / `REDIS_DIAL_TIMEOUT` / `REDIS_POOL_TIMEOUT` | `3` / `3` / `5` / `2` |
| `redis.maxRetries` / `minRetryBackoff` / `maxRetryBackoff` / `masterName` | `REDIS_MAX_RETRIES` / `REDIS_MIN_RETRY_BACKOFF` / `REDIS_MAX_RETRY_BACKOFF` / `REDIS_MASTER_NAME` | `3` / `8` / `1` / unset |
| `rabbitmq.enabled` / `vhost` / `exchange` / `queue` | `RABBITMQ_ENABLED` / `RABBITMQ_VHOST` / `RABBITMQ_EXCHANGE` / `RABBITMQ_QUEUE` | `true` / `/` / `events` / unset |
| `rabbitmq.healthCheckUrl` / `healthCheckAllowedHosts` | `RABBITMQ_HEALTH_CHECK_URL` / `RABBITMQ_HEALTH_CHECK_ALLOWED_HOSTS` | `<http\|https>://<broker host>:<broker port>/api/health/checks/alarms` (https for an `amqps` broker) / the broker host. lib-commons checks the management API on every connect and refuses an empty URL |
| `rabbitmq.requireHealthAllowedHosts` / `allowInsecureHealthCheck` / `allowInsecureTls` | `RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS` / `RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK` / `RABBITMQ_ALLOW_INSECURE_TLS` | `false` / `true` only with the bundled (plain-HTTP) broker, else `false` / `false` |
| `rabbitmq.publisherConfirmTimeoutMs` / `publisherRecoveryInitialMs` / `publisherRecoveryMaxMs` / `publisherMaxRecoveries` | `RABBITMQ_PUBLISHER_*` | `5000` / `1000` / `30000` / `10` |
| `outbox.enabled` / `tableName` / `allowEmptyTenant` | `OUTBOX_ENABLED` / `OUTBOX_TABLE_NAME` / `OUTBOX_ALLOW_EMPTY_TENANT` | `true` / `outbox_events` / `true` |
| `outbox.dispatchIntervalSec` / `batchSize` / `publishMaxAttempts` / `publishBackoffMs` | `OUTBOX_DISPATCH_INTERVAL_SEC` / `OUTBOX_BATCH_SIZE` / `OUTBOX_PUBLISH_MAX_ATTEMPTS` / `OUTBOX_PUBLISH_BACKOFF_MS` | `2` / `50` / `3` / `200` |
| `outbox.retryWindowSec` / `maxDispatchAttempts` / `processingTimeoutSec` / `maxFailedPerBatch` | `OUTBOX_RETRY_WINDOW_SEC` / `OUTBOX_MAX_DISPATCH_ATTEMPTS` / `OUTBOX_PROCESSING_TIMEOUT_SEC` / `OUTBOX_MAX_FAILED_PER_BATCH` | `300` / `10` / `600` / `25` |
| `outbox.includeTenantMetrics` / `priorityEventTypes` | `OUTBOX_INCLUDE_TENANT_METRICS` / `OUTBOX_PRIORITY_EVENT_TYPES` | `false` / unset |
| (global.streaming.enabled) | `STREAMING_ENABLED` | `false` |
| `streaming.cloudeventsSource` / `clientId` | `STREAMING_CLOUDEVENTS_SOURCE` / `STREAMING_CLIENT_ID` | unset (the app pins `br-sta`; any other ce-source is refused) |
| `streaming.cbFailureRatio` / `cbMinRequests` / `cbTimeoutSec` / `closeTimeoutSec` | `STREAMING_CB_FAILURE_RATIO` / `STREAMING_CB_MIN_REQUESTS` / `STREAMING_CB_TIMEOUT_S` / `STREAMING_CLOSE_TIMEOUT_S` | unset (app defaults) |
| (global.auth.enabled) | `PLUGIN_AUTH_ENABLED` | `false` in a development-class env, `true` elsewhere |
| `auth.trustedProxies` | `TRUSTED_PROXIES` (lib-auth client-IP forwarding) | `""` |
| `identity.declarationEnabled` / `host` / `m2mClientId` | `IDP_DECLARATION_ENABLED` / `IDP_HOST` / `IDP_M2M_CLIENT_ID` | `false` / unset / unset |
| `m2m.targetService` / `credentialCacheTtlSec` | `M2M_TARGET_SERVICE` / `M2M_CREDENTIAL_CACHE_TTL_SEC` | unset / `300` |
| `aws.region` | `AWS_REGION` | `us-east-1` |
| `multiTenant.poolMaxConns` / `poolMaxIdleConns` | `MULTI_TENANT_POOL_MAX_CONNS` / `MULTI_TENANT_POOL_MAX_IDLE_CONNS` | `20` / `5` (only with multi-tenancy) |
| `multiTenant.maxTenantPools` / `idleTimeoutSec` / `timeoutSec` / `cacheTtlSec` / `connectionsCheckIntervalSec` | `MULTI_TENANT_MAX_TENANT_POOLS` / `..._IDLE_TIMEOUT_SEC` / `MULTI_TENANT_TIMEOUT` / `..._CACHE_TTL_SEC` / `..._CONNECTIONS_CHECK_INTERVAL_SEC` | `100` / `300` / `30` / `120` / `30` (only with multi-tenancy) |
| `multiTenant.circuitBreakerThreshold` / `circuitBreakerTimeoutSec` / `allowInsecureHttp` | `MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD` / `..._TIMEOUT_SEC` / `MULTI_TENANT_ALLOW_INSECURE_HTTP` | `5` / `30` / `false` (only with multi-tenancy) |
| `observability.serviceName` / `libraryName` | `OTEL_RESOURCE_SERVICE_NAME` / `OTEL_LIBRARY_NAME` | unset (each binary seeds `br-sta-manager` / `br-sta-worker`) |
| `rateLimit.enabled` / `max` / `windowSec` | `RATE_LIMIT_ENABLED` / `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_SEC` | `true` / `100` / `60` |
| `rateLimit.aggressiveMax` / `aggressiveWindowSec` / `relaxedMax` / `relaxedWindowSec` | `AGGRESSIVE_RATE_LIMIT_*` / `RELAXED_RATE_LIMIT_*` | `100` / `60` / `1000` / `60` |
| `rateLimit.auditExportMax` / `auditExportWindowSec` | `AUDIT_EXPORT_RATE_LIMIT_MAX` / `..._WINDOW_SEC` | `10` / `60` |
| `swagger.enabled` / `title` / `version` / `basePath` | `SWAGGER_ENABLED` / `SWAGGER_TITLE` / `SWAGGER_VERSION` / `SWAGGER_BASE_PATH` | `false` / `BR-STA Service API` / image tag / `/` |
| `swagger.leftDelim` / `rightDelim` / `description` / `host` / `schemes` | `SWAGGER_LEFT_DELIM` / `SWAGGER_RIGHT_DELIM` / `SWAGGER_DESCRIPTION` / `SWAGGER_HOST` / `SWAGGER_SCHEMES` | `{{` / `}}` / unset |
| `pagination.maxLimit` / `maxMonthDateRange` | `MAX_PAGINATION_LIMIT` / `MAX_PAGINATION_MONTH_DATE_RANGE` | `100` / `3` |
| `auditApi.defaultPageSize` / `maxPageSize` / `maxExportDateRangeDays` | `AUDIT_API_*` | unset (app: `25` / `100` / `365`) |
| (global.kms.vendor) / `credentials.masterKeyVersion` | `MASTER_KEY_PROVIDER` / `MASTER_KEY_VERSION` | `envvar` / `v1` |
| `bacen.environment` | `BACEN_ENVIRONMENT` | `homologation` |
| `sta.scheme` / `fileHost` / `passwordHost` | `STA_SCHEME` / `STA_FILE_HOST` / `STA_PASSWORD_HOST` | unset (the bundled mock when `mockSta.enabled`); dev/test only |
| `transfer.schedulerEnabled` / `inboundEnabled` | `TRANSFER_SCHEDULER_ENABLED` / `TRANSFER_INBOUND_ENABLED` | `true` / `false` |
| `transfer.maxFileSizeBytes` / `inboundMaxFileSizeBytes` / `inboundExtractMaxExpansionRatio` / `inboundExtractMaxExtractedBytes` | `TRANSFER_MAX_FILE_SIZE_BYTES` / `TRANSFER_INBOUND_MAX_FILE_SIZE_BYTES` / `TRANSFER_INBOUND_EXTRACT_*` | unset (app defaults: 5 GiB / 5 GiB / 100 / 5 GiB) |
| `transfer.chunkSizeBytes` / `maxAttempts` / `ttlHours` / `pollIntervalSeconds` / `workerConcurrency` / `inboundLockClassId` | `TRANSFER_CHUNK_SIZE_BYTES` / `TRANSFER_MAX_ATTEMPTS` / `TRANSFER_TTL_HOURS` / `TRANSFER_POLL_INTERVAL_SECONDS` / `TRANSFER_WORKER_CONCURRENCY` / `TRANSFER_INBOUND_LOCK_CLASS_ID` | unset (app defaults) |
| `businessEvents.enabled` / `exchange` | `BUSINESS_EVENTS_ENABLED` / `BUSINESS_EVENTS_EXCHANGE` | `true` / `sta.business.events` |
| `businessEvents.intervalSec` / `batchSize` / `maxAttempts` / `serviceName` / `lockClassId` / `confirmTimeoutSec` | `BUSINESS_EVENTS_*` | unset (app defaults) |
| `reporterEvents.consumerEnabled` | `REPORTER_EVENTS_CONSUMER_ENABLED` | `false` |
| `reporterEvents.exchange` / `doctypeResolver` | `REPORTER_EVENTS_CONSUMER_EXCHANGE` / `REPORTER_EVENTS_DOCTYPE_RESOLVER` | unset (both required when the consumer is on; `payload` in production) |
| `reporterEvents.queue` / `dlqExchange` / `alternateExchange` / `idleWindowSec` / `dedupTtlSec` / `reconciliationWindowSec` / `redeliveryWindowSec` / `doctypeMap` | `REPORTER_EVENTS_*` | unset (app defaults) |

The `cors` group also renders the keys lib-commons' CORS middleware actually reads: `ACCESS_CONTROL_ALLOW_ORIGIN` always (from `allowedOrigins`), and `ACCESS_CONTROL_ALLOW_METHODS` / `_HEADERS` / `ACCESS_CONTROL_EXPOSE_HEADERS` / `ACCESS_CONTROL_ALLOW_CREDENTIALS` only when the matching field (or native `CORS_*` key) is set — otherwise the middleware keeps its own defaults. An empty origin list means deny-all (the default, fail-closed). Outside production, `*` needs `security.allowCorsWildcard: true` (the chart fails the render otherwise, since the middleware would silently deny everything); in production a wildcard origin is refused outright, opt-in or not. A native `ACCESS_CONTROL_*` key under `common.configmap` wins.

Worker-only (`worker.*`, rendered into the worker ConfigMap):

| Parameter | Env key | Default |
|-----------|---------|---------|
| `scheduler.enabled` | `SCHEDULER_ENABLED` | `true` (BACEN verdict polling + maintenance jobs) |
| `scheduler.filingSweepEnabled` | `SCHEDULER_FILING_SWEEP_ENABLED` | `false` (a deliberate decision: it auto-closes stranded reporter filings) |
| `scheduler.filingSweepAgeMinutes` | `SCHEDULER_FILING_SWEEP_AGE_MINUTES` | unset (app: `120`). A **safety** knob: do not tune it down to make the sweep responsive |
| `scheduler.{serviceName,leaderTtlSeconds,heartbeatSeconds,credentialIntervalHours,staleCleanupIntervalHours,retentionIntervalHours,quarantineRetentionDays,filingSweepIntervalMinutes,filingSweepBatchLimit}` | `SCHEDULER_*` | unset (app defaults) |
| `credentials.recoveryOnBoot` | `CREDENTIALS_RECOVERY_ON_BOOT` | `true` |
| `auditPublisher.enabled` / `auditConsumer.enabled` | `AUDIT_PUBLISHER_ENABLED` / `AUDIT_CONSUMER_ENABLED` | `true` / `true` |
| `auditPartition.enabled` | `AUDIT_PARTITION_MANAGER_ENABLED` | `true` (leave it on: it is the only forward creator of the audit partitions) |
| `auditCleanup.enabled` / `auditVerifier.enabled` | `AUDIT_CLEANUP_ENABLED` / `AUDIT_VERIFIER_ENABLED` | `false` / `true` |
| `auditExportGenerator.enabled` | `AUDIT_EXPORT_GENERATOR_ENABLED` | `true` when an audit-export bucket is set, else `false` |
| every other `audit*` field (interval, batch, exchange, queue, lock class, service name, ...) | `AUDIT_*` | unset (app defaults) |

Keys the chart does not render: the composite DSN forms (`DB_CONNECTION_STRING`, `REDIS_URL`) and `MASTER_ENCRYPTION_KEY` (documented in the app's `.env.example`, not read by the service), `LICENSE_SERVICE_ADDRESS` (reserved, not consumed), `MIGRATIONS_PATH` (the app does not run migrations; the Job sets it). The docker-compose server tuning (`POSTGRES_MAX_CONNECTIONS`, `POSTGRES_SHARED_BUFFERS`) and the inert keys from earlier pre-releases (`REPORTER_EVENTS_CONSUMER_ROUTING_KEY`, `REPORTER_EVENTS_ACOS010_PRODUCER_CATEGORY`, `REPORTER_EVENTS_EXPECTED_TENANT`, `TRUST_STORE_*`) are dropped from the escape hatch with a NOTES warning.

### Secrets

| Key | Required when |
|-----|---------------|
| `MASTER_KEYS` | Always. `envvar`: comma-separated `version:<hex AES key>` (32 bytes: `openssl rand -hex 32`); `aws-kms`: `version:<base64 KMS ciphertext>`. `MASTER_KEY_VERSION` must name one of the versions. Replacing a key makes every stored credential undecryptable: add a new version instead |
| `POSTGRES_PASSWORD` | External Postgres in production, and always for the migrations Job |
| `POSTGRES_REPLICA_PASSWORD` | Optional (replica with its own password) |
| `REDIS_PASSWORD` | The external Redis requires auth |
| `RABBITMQ_DEFAULT_PASS` / `RABBITMQ_URL` | Production (password, or a full DSN that overrides the parts) / the bundled RabbitMQ (password) |
| `RABBITMQ_ERLANG_COOKIE` | The bundled RabbitMQ (stable across upgrades) |
| `LICENSE_KEY` | Production |
| `ORGANIZATION_IDS` | Optional here: an identifier whose home is `common.license.organizationIds` (required in production); accepted in the Secret for tiers that source it from the secret store |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | The object store needs static credentials (not with IRSA / workload identity) |
| `STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` | SASL mechanism set / broker CA not in the system pool |
| `IDP_M2M_CLIENT_SECRET` | `identity.declarationEnabled` |
| `MULTI_TENANT_SERVICE_API_KEY` / `MULTI_TENANT_REDIS_PASSWORD` | Multi-tenancy on / tenant Redis requires auth |

The Deployments list the ConfigMap before the Secret in `envFrom`, so a Secret key always wins over a ConfigMap key of the same name.

### Fail-fast gates

The render fails with the exact value to set (mirroring the app's boot validation) when:

- `MASTER_KEYS` is missing, malformed (not `version:key`, or not hex under `envvar`), or `MASTER_KEY_VERSION` is not one of its versions; `MASTER_KEY_KMS_KEY_ID` is missing under `aws-kms`;
- `PLUGIN_AUTH_ENABLED` is `false` outside a development-class environment (or with `DEPLOYMENT_MODE=saas`), or `true` without `PLUGIN_AUTH_HOST`;
- `POSTGRES_HOST` / `REDIS_HOST` are empty in single-tenant mode; RabbitMQ is enabled without a host or `RABBITMQ_URL`, without a management health-check URL, or with a plain-`http` health-check URL but no `allowInsecureHealthCheck`;
- production lacks `POSTGRES_PASSWORD`, `RABBITMQ_DEFAULT_PASS`, `LICENSE_KEY`, `ORGANIZATION_IDS` or the transfer bucket, uses `sslmode=disable`, disables RabbitMQ, the outbox or the business channel, or allows insecure RabbitMQ TLS / health checks;
- streaming is on without `STREAMING_BROKERS`, a SASL mechanism is set without a username/password or without TLS, or `STREAMING_CLOUDEVENTS_SOURCE` is anything but `br-sta`;
- multi-tenancy is on without the tenant-manager URL, its Redis host, the service API key or inbound auth;
- the declaration publisher or the reporter bridge is on without its host / credentials / exchange / resolver (`static` is refused in production and outside homologation);
- the CORS origin is `*` without `security.allowCorsWildcard` (and, in production, is a wildcard at all), the server TLS cert/key are not set together, or `M2M_TARGET_SERVICE` contains `:`.

A value supplied through `extraEnvVars` satisfies the gate only when it is set, with the same value, on both `manager.extraEnvVars` and `worker.extraEnvVars` (or the worker is disabled). An empty literal for a required key in either pod's `extraEnvVars` fails the render, since it would override the ConfigMap/Secret for that pod. With `common.useExistingSecret`, the gates skip the Secret keys.

---

## Integration with br-sisbajud

br-sisbajud is an STA client: it submits its return files through `POST /v1/transfers`, reads the inbound files br-sta downloads into the transfer bucket, and consumes br-sta's business facts on `lerian.streaming.br-sta`. Wire the two charts with the same values:

| br-sisbajud | br-sta |
|-------------|--------|
| `global.objectStorage.sta.bucket` (→ `STA_INBOUND_BUCKET` / `TRANSFER_OBJECT_STORAGE_BUCKET`) | `global.objectStorage.sta.bucket` (→ `TRANSFER_OBJECT_STORAGE_BUCKET`) — the same bucket |
| `STA_OBJECT_STORAGE_ENDPOINT` (defaults to its S3 endpoint) | `global.objectStorage.sta.endpoint` — the same S3 backend |
| `brSisbajud.sta.transfersBaseUrl` | `http://<fullname>-manager.<namespace>.svc.cluster.local:4028` (printed in NOTES) |
| `brSisbajud.sta.consumerEnabled` + `global.streaming` | `global.streaming.enabled: true` + the same brokers; the topics `lerian.streaming.br-sta` and `.dlq` must exist |
| `brSisbajud.sta.expectedTenantSt` | br-sta's `DEFAULT_TENANT_ID` (`common.app.defaultTenantId`) in single-tenant mode |
| `STA_CLIENT_ID` / `STA_CLIENT_SECRET` (m2m bearer from `global.auth.host`) | the same plugin-access-manager (`global.auth.host`) |

Set these once in an umbrella `global:` block and both charts agree.

---

## Detached migrations

`migrations.enabled` (default `true`, single-tenant only — the runner refuses `MULTI_TENANT_ENABLED=true`) runs `ghcr.io/lerianstudio/br-sta-migrations` (golang-migrate). The Job follows the app's resolved Postgres connection; `migrations.postgres.*` overrides it field by field.

- **External Postgres**: a Helm **pre-install/pre-upgrade** + ArgoCD **PreSync** hook Secret (`hook-weight: -2`) and Job (`-1`), so the app never boots unmigrated under either tool. Helm deletes both after the hook phase succeeds; ArgoCD keeps the Secret until the next hook run (`BeforeHookCreation`). The password comes from that Secret, `migrations.useExistingSecret`, or the app's existing Secret (`common.useExistingSecret`).
- **Bundled Postgres**: the database is created in the same sync, so the Job is a regular resource created with the release; its initContainer waits for Postgres and the password comes from the subchart Secret.

The Job is named after a hash of its spec (`<fullname>-migrations-<hash>`): a new image tag is a new Job, so the immutable `spec.template` never blocks an upgrade under Helm or ArgoCD. The pod is hardened (non-root, read-only rootfs, drop ALL, no service-account token) and carries native-sidecar mesh annotations.

## Bundled infrastructure (development only)

> **Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure.** Production means external, managed infrastructure: PostgreSQL with TLS, Valkey/Redis, RabbitMQ, Kafka/Redpanda with TLS, S3 object storage and the real BACEN/Nuclea STA upstream. The bundled `postgresql`, `valkey`, `rabbitmq`, `seaweedfs` and `redpanda` subcharts and `mockSta` exist for development, POC and quickstart. The render refuses Redpanda and the mock STA in a production-like environment and only warns (NOTES) for the others, but none of them is supported in production.

`values-dev.yaml` is a self-contained dev / evaluation install:

```console
$ helm install br-sta charts/br-sta -f charts/br-sta/values-dev.yaml -n sta-dev --create-namespace
```

It bundles, in the release namespace:

| Bundle | Version | Toggle | Mode |
|--------|---------|--------|------|
| postgresql (Bitnami) | 16.3.5 | `postgresql.enabled` + `external: false` | standalone, creates role/db `br_sta` |
| valkey (Bitnami) | 2.4.7 | `valkey.enabled` + `external: false` | standalone |
| rabbitmq (groundhog2k) | 2.1.11 | `rabbitmq.enabled` | 1 node, plaintext AMQP; credentials read from the app Secret |
| seaweedfs | 4.0.393 | `seaweedfs.enabled` | master/volume/filer + S3, **no S3 auth** |
| redpanda | 26.2.4 | `redpandaBundle.enabled` | 1 broker, no TLS, no SASL, no external listener |
| mock STA server | app tag | `mockSta.enabled` | BACEN STA simulator over HTTP; every upload ends in `defaultTerminalStatus` |

It runs with `ENV_NAME=development`: inbound auth off, no license enforcement, plaintext datastores and broker allowed, streaming on. The reporter bridge, the declaration publisher and multi-tenancy are off.

### Derived connections

With a bundle enabled and no explicit value (`configmap` > dedicated mask > `global.*` still wins):

| Key | Derived from |
|-----|--------------|
| `POSTGRES_HOST` / `REDIS_HOST` | Bitnami Services; passwords via `secretKeyRef` to the subchart Secrets |
| `RABBITMQ_HOST` | `<release>-rabbitmq.<release ns>.svc.cluster.local.` (collapse-aware); the broker reads `RABBITMQ_DEFAULT_USER` / `_PASS` / `RABBITMQ_ERLANG_COOKIE` from the app Secret (`rabbitmq.authentication.existingSecret` must equal it) |
| `TRANSFER_S3_ENDPOINT` (+ audit exports) | `http://<seaweedfs.nameOverride\|seaweedfs>-s3.<release ns>.svc.cluster.local:<s3.port>`, path-style |
| `STREAMING_BROKERS` | `<redpanda.fullnameOverride\|release>.<release ns>.svc.cluster.local.:9093`, injected at the `global.streaming` tier |
| `STA_SCHEME` / `STA_FILE_HOST` / `STA_PASSWORD_HOST` | `http` / `<fullname>-mock-sta.<ns>.svc.cluster.local` (activates the app's mock profile) |

`POSTGRES_SSLMODE` defaults to `disable` and `ALLOW_INSECURE_TLS` to `true` with a bundled datastore.

### Bootstrap Jobs

- **Buckets** (`<fullname>-seaweedfs-buckets-<hash>`): creates `TRANSFER_OBJECT_STORAGE_BUCKET`, `AUDIT_EXPORT_GENERATOR_S3_BUCKET` and `seaweedfsBuckets.extraBuckets` with `weed shell` (list, create the missing ones, verify).
- **Topics** (`<fullname>-redpanda-topics-<hash>`): creates `redpandaTopics.list` (`lerian.streaming.br-sta`, `.dlq`) with `rpk`. The app never creates its topics.
- **Migrations**: see above.

They are **regular Jobs, not hooks**: `/readyz` fails until the transfer bucket exists, so a post-install hook (which `helm install --wait` runs only after the release is Ready) or an ArgoCD PostSync hook would never run. Each is named after a hash of its spec, so a changed spec is a new Job and an unchanged one is not re-run. All are idempotent, non-root with a read-only rootfs (PSS restricted), and carry native-sidecar mesh annotations.

### Production guard

The render **fails** when `redpandaBundle` or `mockSta` is enabled outside a development-class environment: the Redpanda bundle is a single plaintext broker, and with the mock nothing reaches BACEN. The postgresql / valkey / rabbitmq / seaweedfs bundles are allowed in any environment, as in the sibling charts, but NOTES.txt warns.

### Caveats

- **Every credential in `values-dev.yaml` is a public dev-only value** (including an all-zero `MASTER_KEYS`). The explicit Postgres/Valkey passwords keep a GitOps render (no Helm `lookup`) stable.
- **S3 auth is OFF** (`seaweedfs.s3.enableAuth: false`). The AWS SDK still signs requests, so `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` are set to dummy values.
- **Images.** The `bitnami/*` tags that postgresql 16.3.5 / valkey 2.4.7 default to were removed from Docker Hub. The chart pins the same tags from `bitnamilegacy/*` (`postgresql:17.2.0-debian-12-r5`, `valkey:8.0.2-debian-12-r6`) by tag, with `global.security.allowInsecureImages: true`. RabbitMQ runs `rabbitmq:4.1.4` (init `busybox:1.36`); SeaweedFS and the bucket Job run `chrislusf/seaweedfs:3.93`; Redpanda and the topics Job run `docker.redpanda.com/redpandadata/redpanda:v26.2.3`.
- **The app, worker, migrations and mock STA images** (`ghcr.io/lerianstudio/br-sta-*`, `mock-sta-server`) are private: the cluster needs a pull secret for GHCR (`imagePullSecrets`, default `ghcr-credential`).

{% endraw %}
