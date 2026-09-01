# Changelog

All notable changes to this chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this chart adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Consolidated entry for the whole MT-01 phase-2 control-plane branch's helm
changes (rename + PreSync migrations Job + hardening). This chart's actual
published version is assigned by `semantic-release` at merge time
(`.github/workflows/release.yml`); no chart release ever carried the
intermediate bugs fixed during this branch's own development, so only the
final shipped state is documented below.

### Added

- **New values keys:** `app.controlplaneMigrations.enabled` (default
  `false`) and `app.controlplaneMigrations.resources` (default requests
  `50m`/`64Mi`, limits `250m`/`256Mi`) — see the `templates/controlplane-migrations.yaml`
  entry below for what they control.

- `templates/controlplane-migrations.yaml`: a `PreSync` Helm hook Job that
  applies the app's control-plane migrations (ADR-013, `plugin-br-payments`
  repo) via the `/controlplane-migrate` binary before the app rolls out.

  Renders only when **all four** are true:
  - `app.configmap.MULTI_TENANT_ENABLED=true` — single-tenant already applies
    every migration automatically at boot, so running this Job too would be
    redundant, not incorrect.
  - `global.externalPostgresDefinitions.enabled=true` **and** the chart's
    `postgresql.enabled` helper resolves to `false` — i.e. Postgres is
    genuinely external, not just flagged as such.
    `externalPostgresDefinitions.enabled` alone is independent of
    `postgresql.enabled`/`postgresql.external`, and the chart's own default
    is a **bundled** Postgres (`postgresql.enabled: true`,
    `postgresql.external: false`); this Job assumes an external Postgres
    host with no in-cluster ordering guarantee relative to a bundled
    `postgresql` subchart's Sync-phase StatefulSet, so both conditions are
    required to keep it gated out of the bundled-Postgres path entirely.
    `templates/bootstrap-postgres.yaml` shares the identical two-condition
    gate.
  - `app.controlplaneMigrations.enabled=true` — **new values key, default
    `false`.** `app.image` resolves to the currently released
    `plugin-br-payments` image today, which does not yet contain the
    `/controlplane-migrate` binary (only an unmerged branch has it). **Do
    not** flip this on until a `plugin-br-payments` release containing the
    binary is deployed.

  Postgres connection env vars are inlined rather than `envFrom` the app
  ConfigMap, which is a plain Sync-phase resource that does not exist yet
  when this `PreSync` hook runs on a first install. `POSTGRES_HOST`/
  `POSTGRES_PORT` read from `app.configmap.POSTGRES_HOST`/`POSTGRES_PORT` —
  the same source `templates/deployment.yaml`'s app container resolves via
  its `envFrom` of `templates/configmap.yaml`, and the SAME source
  `templates/bootstrap-postgres.yaml` now reads its own `DB_HOST`/`DB_PORT`
  from too — so the migration Job, the bootstrap Job, and the app Deployment
  all agree by construction on which Postgres this release talks to.
  `global.externalPostgresDefinitions.connection.host`/`.port` is no longer
  read by any template (retained in `values.yaml` only for backward
  compatibility) — its non-empty chart defaults used to name the bundled
  subchart's own Service and, before this Job and `bootstrap-postgres.yaml`
  shared one source, an operator who correctly set
  `app.configmap.POSTGRES_HOST` without also mirroring `connection.host`
  left the bootstrap Job provisioning a role/database on the wrong host
  while the app and this migration Job connected to the right one;
  `USER`/`DB`/`SSLMODE`/`CONNECT_TIMEOUT_SEC` come from `.Values.app.configmap`
  with the same defaults the app itself uses, plus the existing
  `POSTGRES_PASSWORD` secretRef. Mirrors
  `plugin-br-bank-transfer/templates/migrations.yaml`'s and `charts/br-slc`'s
  inline-env pattern for the same reason.

- `plugin-br-payments.validatePostgresExclusivity` (`_helpers.tpl`): a
  render-time `fail()` that blocks the contradictory combination of a
  literal `postgresql.enabled: true` (the value `Chart.yaml`'s
  `condition: postgresql.enabled` actually gates the bundled subchart on)
  together with either `postgresql.external: true` or
  `global.externalPostgresDefinitions.enabled: true`. Included
  unconditionally at the top of both `templates/controlplane-migrations.yaml`
  and `templates/bootstrap-postgres.yaml`, independently of each file's own
  render gate, so a caller who signals "external" through either flag while
  leaving `postgresql.enabled` at its default `true` gets a fast, explicit
  `fail()` instead of a release that renders the bundled `StatefulSet`
  alongside a Job provisioning a genuinely external host.

  `activeDeadlineSeconds: 300` keeps the Job within Helm's default 300s
  release timeout (`helm upgrade --timeout`); deployments that need a longer
  migration budget must pass a matching `--timeout` explicitly.

  `templates/bootstrap-postgres.yaml` now carries its own `PreSync` hook at
  weight `-10` (mirroring `charts/streaming-hub`'s own bootstrap Job), so it
  is guaranteed to provision the role/database before this Job (`-1`) runs.

  The Job's pod template omits the `app.kubernetes.io/name`/`instance`
  labels that `pdb.yaml`'s `minAvailable: 1` and `service.yaml`'s selector
  match on, so the app's `PodDisruptionBudget` and `Service` cannot select
  this transient pod — mirroring `plugin-br-bank-transfer`'s
  component-scoped selector labels. It gets its own smaller resource
  defaults via the **new values key** `app.controlplaneMigrations.resources`
  (~50m/64Mi requests, 250m/256Mi limits) instead of reusing
  `app.resources`, and an `argocd.argoproj.io/sync-wave` annotation matching
  its hook weight.

  **Known gap:** `.github/scripts/validate-helm-charts`'s render gate
  renders exactly one fixture per chart, and this chart's fixture
  (`.github/configs/helm-render-values/plugin-br-payments.yaml`) exercises
  the chart's default bundled-Postgres deployment mode — so CI's render
  gate does not yet cover the external-Postgres + control-plane migrations
  Job path described above. Closing this (a second fixture, or an
  equivalent render-gate change) is tracked as a follow-up.

### Changed

- Renamed the 6 deprecated multi-tenant configmap/secret keys to the
  canonical names the app itself accepts
  (`internal/bootstrap/config_multitenant.go`):
  - `app.configmap.MULTI_TENANCY_ENABLED` → `app.configmap.MULTI_TENANT_ENABLED`
  - `app.configmap.MULTI_TENANT_MANAGER_URL` → `app.configmap.MULTI_TENANT_URL`
  - `app.configmap.MULTI_TENANT_CLIENT_TIMEOUT_SEC` → `app.configmap.MULTI_TENANT_TIMEOUT`
  - `app.configmap.MULTI_TENANT_CACHE_TTL_MINUTES` → `app.configmap.MULTI_TENANT_CACHE_TTL_SEC`
    (**unit conversion**, not just a rename: the canonical default moves
    from `"60"` minutes to `"3600"` seconds)
  - `app.configmap.MULTI_TENANT_CB_THRESHOLD` → `app.configmap.MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD`
  - `app.configmap.MULTI_TENANT_CB_TIMEOUT_SEC` → `app.configmap.MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC`

  Shipped end state: all 6 renamed keys' explicit literal defaults (e.g.
  `MULTI_TENANT_ENABLED: "false"`, `MULTI_TENANT_CACHE_TTL_SEC: "3600"`) are
  **removed from `values.yaml`** — they exist only as commented-out
  reference values there now, and render into the ConfigMap only when an
  overlay sets them explicitly. This matters because
  `templates/configmap.yaml` `range`s generically over the merged
  `app.configmap` map: a non-blank literal default shipped in this chart's
  own `values.yaml` would render into every ConfigMap, including one built
  from an overlay that still sets only the *old*, pre-rename key names
  (exactly `stg-mt`'s situation, pending Task 2.2.2 in the
  `plugin-br-payments` repo) — the app's `reconcileDeprecatedMultiTenantEnv`
  only falls back to a deprecated key when the canonical one is unset/blank,
  so a chart-shipped `MULTI_TENANT_ENABLED: "false"` would silently outrank
  and disable an overlay's deprecated `MULTI_TENANCY_ENABLED: "true"`.
  `_helpers.tpl` and `templates/controlplane-migrations.yaml`'s gates
  already default an absent `MULTI_TENANT_ENABLED` to `"false"`, so
  chart-only-install behavior is unchanged.

  Updated `values.yaml`, `values-template.yaml`, the required-value
  validation (`_helpers.tpl`), `NOTES.txt`, and `README.md`.
  `MULTI_TENANT_SERVICE_NAME`, `MULTI_TENANT_POSTGRES_MODULE`,
  `MULTI_TENANT_ALLOW_INSECURE_HTTP`, `MULTI_TENANT_MAX_TENANT_POOLS`, and
  `MULTI_TENANT_SERVICE_API_KEY` were already canonical and are untouched.

### Deprecated

- The 6 old multi-tenant key names above are deprecated. Unlike the
  `MIDAZ_LEDGER_URL` rename, the chart does **not** carry a fallback for
  them: `_helpers.tpl`'s "required when enabled" gate now reads only the
  canonical `MULTI_TENANT_ENABLED`/`MULTI_TENANT_URL`/
  `MULTI_TENANT_SERVICE_API_KEY`. A values overlay that still sets the old
  names (e.g. `stg-mt` today) renders fine and the app itself still accepts
  the old names with a startup `WARN` fallback — but the chart's own
  required-value gate becomes a **blind spot** for that overlay: since it
  never sets the canonical `MULTI_TENANT_ENABLED`, the gate's `if` never
  fires and a missing `MULTI_TENANT_URL`/`MULTI_TENANT_SERVICE_API_KEY`
  under the old names goes unvalidated by the chart. This is an accepted,
  documented consequence, not a bug — closing it is tracked as the
  follow-up rename of the `stg-mt` gitops values themselves (Task 2.2.2 of
  the MT-01 control-plane plan, `plugin-br-payments` repo), currently
  `Blocked` pending a release/rc that includes MT-01.

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
