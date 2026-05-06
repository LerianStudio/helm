# Changelog

All notable changes to this chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this chart adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
