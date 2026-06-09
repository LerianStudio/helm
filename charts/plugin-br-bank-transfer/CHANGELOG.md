# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0-beta.8]

### Fixed
- `templates/deployment.yaml`: the `wait-for-dependencies` init container
  is now gated behind `MULTI_TENANT_ENABLED != "true"`. In 2.0.0-beta.7
  we stopped rendering `POSTGRES_HOST` / `POSTGRES_PORT` / `REDIS_HOST`
  tuning in MT mode, but the init container still referenced
  `$POSTGRES_HOST:$POSTGRES_PORT` and `$REDIS_HOST` for its `nc -z`
  probes. With those envs unset the probe loop ran forever printing
  `nc: bad port ''` and pods never started.

  In MT mode the bootstrap does not connect to any static Postgres /
  Redis at boot — per-tenant connections are resolved via tenant-manager
  at request time — so the dependency wait gate has nothing legitimate
  to wait for. The init container is now omitted entirely in MT mode.
- `templates/migrations.yaml`: the migrations Job is now gated by
  `MULTI_TENANT_ENABLED != "true"` as well. Per-tenant schema migrations
  in MT mode are owned by tenant-manager, not by a static pre-upgrade
  hook bound to a single Postgres host.

## [2.0.0-beta.7]

### Changed
- ConfigMap and Secret templates now gate single-tenant-only infrastructure
  keys behind `MULTI_TENANT_ENABLED != "true"`. In multi-tenant mode the
  rendered ConfigMap only contains the envs the bootstrap actually consumes
  in that mode (app identity, server address, multi-tenant infrastructure,
  app-level Redis connection envs, outbound adapter URLs + auth toggles,
  inbound auth, telemetry toggle/endpoint, feature flags, AWS region for
  the secrets-manager client). Gated single-tenant-only in MT-mode render:
  - All `POSTGRES_*` / `MIGRATIONS_PATH` (per-tenant Postgres resolves via
    tenant-manager; migrations init container only runs in single-tenant)
  - All `MONGO_*` (per-tenant Mongo resolves via tenant-manager)
  - All `RABBITMQ_*` (not used in MT mode)
  - Redis pool / timeout / `REDIS_PROTOCOL` tuning (systemplane-managed)
  - `DEPLOYMENT_MODE`, `HTTP_BODY_LIMIT_BYTES`, `TLS_TERMINATED_UPSTREAM`,
    `SERVER_*` TLS / proxy
  - `OTEL_LIBRARY_NAME`, `OTEL_RESOURCE_SERVICE_NAME`,
    `OTEL_RESOURCE_SERVICE_VERSION`, `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`
  - JD live config (`JD_BASE_URL`, `JD_ORIGIN_ISPB`, `JD_SOAP_PATH`,
    `JD_SIGNING_MODE`, `JD_LEGACY_CODE`, `JD_PRIVATE_KEY_KEYINFO`) — these
    are per-tenant via `TenantIntegrationResolver` in MT mode
  - `LICENSE_SERVICE_ADDRESS`
  - `ORGANIZATION_ID`
- Single-tenant mode is unchanged: same defaults, same required guards
  (`POSTGRES_PASSWORD`, `MONGO_PASSWORD`, `JD_BASE_URL`, `JD_ORIGIN_ISPB`
  when sandbox mode is off).

### Removed (dead envs not consumed by the app)
Audited against `plugin-br-bank-transfer` source (`internal/bootstrap/config`,
`.env.example`, and the `lib-license-go` / `lib-commons` integrations) and
dropped from the chart entirely:

- `VERSION` — populated at build time via Docker `--build-arg VERSION` +
  Go `ldflags -X ...bootstrap.Version=...`. Not read from env at runtime.
- `TENANT_IDS` — explicitly removed from the app in the D7 license rewrite
  (`internal/bootstrap/config/validate_production.go`).
- `PLUGIN_AUTH_CLIENT_ID`, `PLUGIN_AUTH_CLIENT_SECRET` — explicitly removed
  in D7; the inbound `PLUGIN_AUTH_ENABLED` + `PLUGIN_AUTH_ADDRESS` are the
  only inbound-auth wiring the app needs.
- `DEFAULT_ORGANIZATION_ID`, `DEFAULT_TENANT_ID`, `DEFAULT_TENANT_SLUG` —
  no `env:` tag anywhere in source and no reference in `.env.example`.
- `IS_DEVELOPMENT` — no `env:` tag or `.env.example` reference. The
  per-environment behaviour is selected via `ENV_NAME` / `DEPLOYMENT_MODE`.
- `INFRA_CONNECT_TIMEOUT_SEC` — no source reference. Per-dependency
  connect timeouts use the explicit `POSTGRES_CONNECT_TIMEOUT_SEC` /
  `MONGO_*_TIMEOUT_MS` / `REDIS_DIAL_TIMEOUT_MS` envs instead.
- `MULTI_TENANT_INTEGRATION_SECRET_NAME_TEMPLATE` — no source reference;
  the per-tenant integration secret name template is hard-coded in the
  `TenantIntegrationResolver`.
- `MULTI_TENANT_REDIS_CA_CERT` — no source reference and no `.env.example`
  entry; MT-mode Redis uses TLS via the system trust store.
- `SYSTEMPLANE_POSTGRES_DSN`, `SYSTEMPLANE_SECRET_MASTER_KEY` — no source
  reference. lib-commons `systemplane` reads DSN/key bundles via its own
  envs (`SYSTEMPLANE_*` v5 surface), not these.
- `JD_CERTIFICATE_PEM` — orphan / typo. The app reads `JD_CERT_PEM`.

### Fixed
- Multi-tenant installs no longer fail at template time with
  `bankTransfer.configmap.JD_BASE_URL is required when JD_SANDBOX_MODE is
  not true`. The required guard now also requires `MULTI_TENANT_ENABLED`
  to be off before triggering.

## [1.6.0-beta.1]

### Changed
- Chart now only ships **infrastructure configuration**: database / Valkey
  / RabbitMQ / MongoDB connection info, multi-tenant toggle + endpoints,
  outbound adapter URLs + auth toggles, OpenTelemetry plumbing, and
  inbound auth wiring. All operational tuning (timeouts, retries, circuit
  breakers, cache TTLs, rate limit, idempotency window, reconciliation,
  webhook retries, JD polling cadence, usage limits, operating hours,
  CORS, routing UUIDs) is dropped from the chart and is now managed at
  runtime via the systemplane admin API or covered by lib-commons
  compiled defaults.

### Removed env vars (now systemplane-managed or default-covered)
- `LOG_LEVEL`, `CORS_ALLOWED_*`, `AUTH_CACHE_TTL_SEC`, `DB_METRICS_INTERVAL_SEC`
- `RATE_LIMIT_*`, `IDEMPOTENCY_RETRY_WINDOW_SEC`, `IDEMPOTENCY_REQUIRE_REDIS`,
  `DUPLICATE_GUARD_TTL_SEC`
- `MIDAZ_TIMEOUT_MS`, `MIDAZ_MAX_RETRIES`, `MIDAZ_OTEL_ENABLED`, `MIDAZ_DEBUG`,
  `MIDAZ_BREAKER_FAILURES`, `MIDAZ_BREAKER_TIMEOUT_SECONDS`
- `CRM_TIMEOUT_MS`, `CRM_MAX_RETRIES`, `CRM_CACHE_TTL_MS`, `CRM_*_LOOKUP_PATH_TEMPLATE`
- `FEES_TIMEOUT_MS`, `FEES_MAX_RETRIES`, `FEES_FAIL_CLOSED_DEFAULT`,
  `FEES_MAX_FEE_AMOUNT_CENTS`, `FEES_REFUND_ON_DEVOLUCAO`
- `JD_TIMEOUT_MS`, `JD_MAX_RETRIES`, `JD_SIGNATURE_REQUIRED`,
  `JD_VALIDATE_EXTERNAL_SIGNATURE`, `JD_POLLING_ENABLED`, `JD_POLL_*`
- `RABBITMQ_MAX_RETRIES`, `RABBITMQ_PUBLISH_TIMEOUT_MS`,
  `RABBITMQ_RETRY_BACKOFF_MS`, `RABBITMQ_ROUTING_KEY_PREFIX`
- `RECONCILIATION_PENDING_ALERT_THRESHOLD`, `BTF_RECONCILIATION_*`
- `WEBHOOK_QUEUE_NAME`, `WEBHOOK_DLQ_NAME`, `WEBHOOK_CONSUMER_TAG`,
  `WEBHOOK_PREFETCH_COUNT`, `WEBHOOK_TIMEOUT_MS`, `WEBHOOK_MAX_RETRIES`,
  `WEBHOOK_RETRY_BACKOFF_MS`, `WEBHOOK_ALLOW_UNSIGNED_BROKER_EVENTS`,
  `WEBHOOK_UNSIGNED_BROKER_EVENTS_GRACE_SEC`, `WEBHOOK_ENDPOINT_URL`
- `USAGE_LIMITS_ENABLED`, `USAGE_LIMIT_DAILY_CENTS`, `USAGE_LIMIT_MONTHLY_CENTS`
- `TRANSFER_OPERATING_OPEN`, `TRANSFER_OPERATING_CLOSE`, `TRANSFER_OPERATING_TIMEZONE`
- `BTF_FEE_ENABLED`, `BTF_MIDAZ_CB_ENABLED`
- `SYSTEMPLANE_BACKEND`, `SYSTEMPLANE_POSTGRES_SCHEMA` (chart internals,
  app reads these via lib-commons configuration loader)
- `ALLOW_INSECURE_OTEL` (unused by app)
- `MULTI_TENANT_MAX_TENANT_POOLS`, `MULTI_TENANT_IDLE_TIMEOUT_SEC`,
  `MULTI_TENANT_TIMEOUT`, `MULTI_TENANT_CACHE_TTL_SEC`,
  `MULTI_TENANT_CIRCUIT_BREAKER_*`, `MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC`,
  `MULTI_TENANT_REDIS_PORT` (chart default 6379)

### Kept
- All Postgres / Valkey / MongoDB / RabbitMQ connection configuration
- Multi-tenant toggle + infra endpoints
  (`MULTI_TENANT_ENABLED`, `MULTI_TENANT_URL`, `MULTI_TENANT_REDIS_HOST`,
   `MULTI_TENANT_REDIS_TLS`, `MULTI_TENANT_INTEGRATION_SECRET_NAME_TEMPLATE`,
   `AWS_REGION`)
- Server / TLS wiring (`SERVER_*`, `TLS_TERMINATED_UPSTREAM`,
  `HTTP_BODY_LIMIT_BYTES`, `ALLOW_PRIVATE_UPSTREAMS`)
- Outbound adapter URLs + auth toggles (Midaz / CRM / Fees / JD)
- Inbound auth wiring (`PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_ADDRESS`)
- OpenTelemetry plumbing
- All secrets (in `templates/secrets.yaml`)

### Migration
Consumers whose `values.yaml` set any of the removed keys should:
1. Remove the entries from `values.yaml` (chart now ignores them).
2. Pre-populate the equivalent systemplane key in Postgres before this
   chart version rolls out, OR accept the lib-commons compiled default
   (sane production values for retries, timeouts, etc.).
3. Use the runtime admin API to tweak any value at any time without
   restarting the pod.

## [1.0.0] - 2024-03-24

### Changed
- Renamed chart from `plugin-br-bank-transfer-jd` to `plugin-br-bank-transfer`
- Fixed auth env var names to match source code:
  - `AUTH_ENABLED` → `PLUGIN_AUTH_ENABLED`
  - `AUTH_SERVICE_ADDRESS` → `PLUGIN_AUTH_ADDRESS`
  - `ORGANIZATION_IDS` → `TENANT_IDS`
- Updated image repository to `ghcr.io/lerianstudio/plugin-br-bank-transfer`
- Updated MongoDB database default to `plugin_br_bank_transfer`
- Updated OTEL service name to `plugin-br-bank-transfer`

### Added
- `PLUGIN_AUTH_CLIENT_ID` - Auth client identifier
- `PLUGIN_AUTH_CLIENT_SECRET` - Auth client secret (in secrets)
- `CRM_AUTH_ENABLED`, `CRM_CLIENT_ID`, `CRM_CLIENT_SECRET` - CRM outbound M2M auth
- `FEES_AUTH_ENABLED`, `FEES_CLIENT_ID`, `FEES_CLIENT_SECRET` - Fees outbound M2M auth
- `SYSTEMPLANE_BACKEND`, `SYSTEMPLANE_POSTGRES_SCHEMA` - Systemplane config
- `SYSTEMPLANE_SECRET_MASTER_KEY`, `SYSTEMPLANE_POSTGRES_DSN` - Systemplane secrets
