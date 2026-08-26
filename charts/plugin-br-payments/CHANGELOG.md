# Changelog

All notable changes to this chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this chart adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BREAKING:** Renamed the OAuth2 credential pair BACK from `BTG_*` to `PROVIDER_*`,
  and only that pair:
  - `app.secrets.BTG_CLIENT_ID` → `app.secrets.PROVIDER_CLIENT_ID`
  - `app.secrets.BTG_CLIENT_SECRET` → `app.secrets.PROVIDER_CLIENT_SECRET`

  The `1.0.0-beta.2` entry below renamed these the other way, and it was right
  about its reason at the time — the binary read `BTG_*`. The binary has now moved
  to `PROVIDER_*` (`internal/bootstrap/config.go`), because `plugin-br-payments` is
  provider-agnostic by design and BTG is its first adapter rather than its only
  one: a client id and a client secret are what any OAuth2 provider issues, unlike
  a BTG host or a BTG webhook mechanism. `BTG_API_BASE_URL`, `BTG_AUTH_URL`,
  `BTG_TOKEN_REFRESH_INTERVAL` and `BTG_WEBHOOK_SECRET` therefore keep their
  prefix and are NOT affected.

  Worth knowing when migrating an overlay: the Vault field names in the deployment
  repositories were `PROVIDER_CLIENT_ID` all along and never followed the
  `1.0.0-beta.2` rename, so this restores agreement rather than introducing a new
  divergence.

### Fixed

- The `PROVIDER_CLIENT_ID` / `PROVIDER_CLIENT_SECRET` requirement is now
  **conditional on tenancy mode** instead of unconditional. In multi-tenant the app
  resolves the pair per tenant from the credential row, nothing reads the global
  values, and it logs a WARN at boot naming each one left set — but
  `validateRequired` demanded them anyway, so a legitimate multi-tenant deployment
  could not render at all (`helm template` refused with
  `app.secrets.BTG_CLIENT_ID is REQUIRED`). The guard now skips when either
  `MULTI_TENANT_ENABLED` or the deprecated `MULTI_TENANCY_ENABLED` is `"true"`:
  the app prefers the former and treats the latter as an alias, while this chart
  still ships the latter, so keying on one alone would refuse a deploy that set the
  other.

## [1.0.0-beta.2] — Unreleased

### Changed

- **BREAKING:** Renamed provider integration value keys from `PROVIDER_*` to `BTG_*`
  to align with the names the `plugin-br-payments` binary actually reads
  (`internal/bootstrap/config.go`). Affected keys:
  - `app.configmap.PROVIDER_API_BASE_URL` → `app.configmap.BTG_API_BASE_URL`
  - `app.configmap.PROVIDER_AUTH_URL` → `app.configmap.BTG_AUTH_URL`
  - `app.configmap.PROVIDER_TOKEN_REFRESH_INTERVAL` → `app.configmap.BTG_TOKEN_REFRESH_INTERVAL`
  - `app.secrets.PROVIDER_CLIENT_ID` → `app.secrets.BTG_CLIENT_ID`
  - `app.secrets.PROVIDER_CLIENT_SECRET` → `app.secrets.BTG_CLIENT_SECRET`
  - `app.secrets.PROVIDER_WEBHOOK_SECRET` → `app.secrets.BTG_WEBHOOK_SECRET`

  Existing deployments must rename these keys in their values overlays in the
  same change set that pins to chart version `1.0.0-beta.2` or later. The
  previous `PROVIDER_*` keys were never consumed by the running binary, so the
  token reconciliation worker remained idle in any environment that relied on
  them.

## [0.1.0] — Unreleased

### Added

- Initial Helm chart for the `plugin-br-payments` service.
- Single Deployment running the `/app` binary with `SERVICE_TYPE=both` —
  HTTP API, reconciliation worker, outbox dispatcher, and webhook delivery
  all run as goroutines in one process.
- PostgreSQL 17 subchart dependency (Bitnami `bitnamisecure/postgresql:latest`,
  Bitnami's free repo after the August 2025 image migration) with replication
  enabled by default.
- Optional `bootstrap-postgres` Job for externally managed PostgreSQL deployments
  (creates database, role, and grants idempotently).
- Canonical Lerian readiness contract (matches `docs/readyz-guide.md` in the plugin):
  - `livenessProbe` -> `/health`
  - `readinessProbe` -> `/readyz`
  - `terminationGracePeriodSeconds: 60`
- Multi-tenancy support: when `MULTI_TENANCY_ENABLED=true`, the chart enforces
  `MULTI_TENANT_MANAGER_URL` and `MULTI_TENANT_SERVICE_API_KEY`.
- Worker secrets validation: when `SERVICE_TYPE` includes the worker
  (`both` or `worker`), the chart enforces `INTERNAL_API_KEY` (>=32 chars)
  and `CREDENTIAL_ENCRYPTION_KEY` (base64 AES-256). When `SERVICE_TYPE=api`,
  it enforces `INTERNAL_WORKER_URL` and `INTERNAL_API_KEY`.
- Validation helpers fail-fast on missing `OUTBOX_ENABLED`, provider, Midaz, and
  PostgreSQL configuration.
- Optional integration with `otel-collector-lerian` for host-level OTLP injection.
- HPA + PDB.
- Ingress template (disabled by default).
- `SERVER_ADDRESS` defaults to `0.0.0.0:8080` so the in-pod bind reaches all
  interfaces. The plugin's `ServerAddress()` rewrites empty-host values to
  `localhost`, which would break kubelet probes if left as `:8080`.

### Verified

Tested in a live K3s cluster with `appVersion 1.0.0-beta.9`:
helm lint passes; helm install succeeds end-to-end; deployment reaches
`2/2 Ready`; `/health`, `/readyz`, and `/version` all return 200 via the
generated Service; the readyz response reports `postgres`, `midaz`, and
`provider` checks all `up`.
