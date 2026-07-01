# Changelog

All notable changes to this project will be documented in this file.

## [3.2.0-beta.1]

### Added

- Promote UI, MCP, and detached migrations into the chart as first-class,
  optional multi-component parts (chart-type `multi-component`). All default to
  `enabled: false`:
  - `ui.*` — Vite SPA (nginx-unprivileged). UI ingress implements the same-origin
    proxy (`/v1` and `/system` → matcher API Service; `/` → UI Service).
  - `mcp.*` — Streamable-HTTP MCP relay (stateless, no credentials); independent
    version line from the app tag.
  - `migrations.*` — ArgoCD PreSync Secret + Job (up-only, single-tenant) applied
    before the app Deployment; TCP-wait initContainer; `useExistingSecret`-aware.
- `matcher.secrets.APP_ENC_KEY` (engine credential master key; required in
  production) and `matcher.secrets.ACTOR_PII_ENCRYPTION_KEY` (optional). Both are
  emitted only when set, keeping the default render byte-identical.
- `matcher.configmap.GOMEMLIMIT` opt-in knob (Go 1.26 soft memory limit).

### Changed

- App templates moved into `templates/matcher/` component subdirectory. Rendered
  Kubernetes objects are unchanged for existing API consumers, modulo the chart
  version string, `# Source:` provenance, and the auth-key changes below.
- ConfigMap now emits `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_ADDRESS` (the app's
  canonical v4 names) instead of `AUTH_ENABLED` / `AUTH_SERVICE_ADDRESS`. The
  template still reads the legacy `matcher.configmap.AUTH_ENABLED` /
  `AUTH_SERVICE_ADDRESS` as a fallback, so an upgrade never silently disables auth.

### Removed

- `matcher.secrets.AUTH_JWT_SECRET` — no-op in app v4 (validation delegated to
  plugin-auth); no longer emitted into the Secret. Setting it is now ignored
  (harmless). See `docs/UPGRADE-3.2.md`.

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
