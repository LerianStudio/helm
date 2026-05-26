# Changelog

All notable changes to this project will be documented in this file.

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
