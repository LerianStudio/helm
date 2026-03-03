# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-02-25

### Added

- Add missing environment variables required by matcher app v1.0.0+:
  - Rate Limiting: `DISPATCH_RATE_LIMIT_MAX`, `DISPATCH_RATE_LIMIT_EXPIRY_SEC`
  - PostgreSQL: `POSTGRES_QUERY_TIMEOUT_SEC`
  - Redis: `REDIS_MASTER_NAME`, `REDIS_CA_CERT` (optional)
  - Swagger: `SWAGGER_HOST`, `SWAGGER_SCHEMES`
  - Idempotency: `IDEMPOTENCY_SUCCESS_TTL_HOURS`
  - Export Worker: `EXPORT_PRESIGN_EXPIRY_SEC`
  - Webhook: `WEBHOOK_TIMEOUT_SEC`
  - Callback Rate Limiting: `CALLBACK_RATE_LIMIT_PER_MIN`
  - Cleanup Worker: `CLEANUP_WORKER_ENABLED`, `CLEANUP_WORKER_INTERVAL_SEC`, `CLEANUP_WORKER_BATCH_SIZE`, `CLEANUP_WORKER_GRACE_PERIOD_SEC`
  - Scheduler: `SCHEDULER_INTERVAL_SEC`
  - Archival Worker: Full archival configuration (disabled by default)
