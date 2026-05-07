# Changelog

## [2.2.0-beta.1] — Unreleased

### Added

- Multi-tenant support: 14 new `MULTI_TENANT_*` env vars wired into the
  configmap (rendered only when `MULTI_TENANT_ENABLED=true`) plus
  `MULTI_TENANT_SERVICE_API_KEY` and `MULTI_TENANT_REDIS_PASSWORD` in the
  secret. Mirrors lib-commons v5 tenant-manager wiring used by the Flowker
  app source.
- `DEPLOYMENT_MODE` (saas/byoc/local) for TLS enforcement at startup.
- Access Manager (plugin auth) configuration: `PLUGIN_AUTH_ENABLED` and
  `PLUGIN_AUTH_ADDRESS`.
- Audit database (PostgreSQL) configuration: `AUDIT_DB_HOST`/`PORT`/`USER`/
  `NAME`/`SSL_MODE`, `AUDIT_MIGRATIONS_PATH`, and `AUDIT_DB_PASSWORD`
  in the secret. `AUDIT_DB_HOST` is required by the application when
  `MULTI_TENANT_ENABLED=false` (audit trail is mandatory for compliance).
- Feature flags: `SKIP_LIB_COMMONS_TELEMETRY`, `FAULT_INJECTION_ENABLED`,
  `SSRF_ALLOW_PRIVATE`.
- `MONGO_TLS_CA_CERT` secret (base64-encoded PEM CA for AWS DocumentDB).
- Fail-fast validation (`required`) for:
  - `MULTI_TENANT_URL` and `MULTI_TENANT_SERVICE_API_KEY` when MT enabled
  - `AUDIT_DB_PASSWORD` when MT disabled

### Changed

- `templates/secrets.yaml` rewritten as conditional `stringData` (was a
  blind range over `.Values.flowker.secrets`). Optional keys are emitted
  only when populated; required keys use `required` for fail-fast errors.
