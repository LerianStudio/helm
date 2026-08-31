# Changelog

All notable changes to this chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this chart adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0-beta.4] - 2026-08-31

### Added

- `templates/controlplane-migrations.yaml`: a `PreSync` Helm hook Job
  (`helm.sh/hook: pre-install,pre-upgrade` + `argocd.argoproj.io/hook: PreSync`,
  `helm.sh/hook-weight: "-1"`) that applies the app's control-plane migrations
  (ADR-013, `plugin-br-payments` repo) via the `/controlplane-migrate` binary
  before the app rolls out. `plugin-br-payments` is always-external Postgres
  (`templates/bootstrap-postgres.yaml`), so — unlike
  `plugin-br-bank-transfer` — there is no bundled-Postgres `PostSync` branch:
  always `PreSync`.

  Gated directly on `app.configmap.MULTI_TENANT_ENABLED` (the canonical key
  from the `1.2.0-beta.3` rename above) — no new values-key of its own, same
  inline-configmap-read pattern every chart in this repo already uses for
  that flag. The Job renders only when multi-tenancy is on: single-tenant
  already applies every migration automatically at boot, so running this Job
  too would be redundant, not incorrect, and stays gated out.

  Reuses `.Values.app.image` (same image as `templates/deployment.yaml`,
  entrypoint overridden to `/controlplane-migrate`) and the exact same
  ConfigMap/Secret Postgres connection references as the Deployment — no new
  connection definition.

## [1.2.0-beta.3] - 2026-08-31

### Changed

- Renamed the 6 deprecated multi-tenant configmap/secret keys to the canonical
  names the app itself accepts (`internal/bootstrap/config_multitenant.go`):
  - `app.configmap.MULTI_TENANCY_ENABLED` → `app.configmap.MULTI_TENANT_ENABLED`
  - `app.configmap.MULTI_TENANT_MANAGER_URL` → `app.configmap.MULTI_TENANT_URL`
  - `app.configmap.MULTI_TENANT_CLIENT_TIMEOUT_SEC` → `app.configmap.MULTI_TENANT_TIMEOUT`
  - `app.configmap.MULTI_TENANT_CACHE_TTL_MINUTES` → `app.configmap.MULTI_TENANT_CACHE_TTL_SEC`
    (**unit conversion**, not just a rename: the default changes from `"60"` minutes
    to `"3600"` seconds)
  - `app.configmap.MULTI_TENANT_CB_THRESHOLD` → `app.configmap.MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD`
  - `app.configmap.MULTI_TENANT_CB_TIMEOUT_SEC` → `app.configmap.MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC`

  Updated `values.yaml`, `values-template.yaml`, the required-value validation
  (`_helpers.tpl`), `NOTES.txt`, and `README.md`. `MULTI_TENANT_SERVICE_NAME`,
  `MULTI_TENANT_POSTGRES_MODULE`, `MULTI_TENANT_ALLOW_INSECURE_HTTP`,
  `MULTI_TENANT_MAX_TENANT_POOLS`, and `MULTI_TENANT_SERVICE_API_KEY` were
  already canonical and are untouched.

### Deprecated

- The 6 old key names above are deprecated. Unlike the `MIDAZ_LEDGER_URL` rename,
  the chart does **not** carry a fallback for them: `_helpers.tpl`'s
  "required when enabled" gate now reads only the canonical
  `MULTI_TENANT_ENABLED`/`MULTI_TENANT_URL`/`MULTI_TENANT_SERVICE_API_KEY`.
  A values overlay that still sets the old names (e.g. `stg-mt` today) renders
  fine and the app itself still accepts the old names with a startup `WARN`
  fallback — but the chart's own required-value gate becomes a **blind spot**
  for that overlay: since it never sets the canonical `MULTI_TENANT_ENABLED`,
  the gate's `if` never fires and a missing `MULTI_TENANT_URL`/
  `MULTI_TENANT_SERVICE_API_KEY` under the old names goes unvalidated by the
  chart. This is an accepted, documented consequence, not a bug — closing it
  is tracked as the follow-up rename of the `stg-mt` gitops values themselves
  (Task 2.2.2 of the MT-01 control-plane plan, `plugin-br-payments` repo),
  currently `Blocked` pending a release/rc that includes MT-01.

## [1.2.0-beta.1] - 2026-08-15

### Changed

- Renamed the Midaz Ledger configmap key to a single `app.configmap.MIDAZ_LEDGER_URL`,
  matching the app refactor that reads one Ledger plane URL instead of the former
  `MIDAZ_ONBOARDING_URL` + `MIDAZ_TRANSACTION_URL` pair. Updated the required-value
  validation (`_helpers.tpl`), `NOTES.txt`, `values.yaml`, `values-template.yaml`,
  and `README.md`.

### Deprecated

- `app.configmap.MIDAZ_ONBOARDING_URL` and `app.configmap.MIDAZ_TRANSACTION_URL`
  are deprecated. They are still accepted as a fallback (validation passes when
  both are set) for environments that have not yet migrated to `MIDAZ_LEDGER_URL`.
  Remove once all overlays use the single key.

## [1.0.0-beta.2]

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

## [0.1.0]

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
