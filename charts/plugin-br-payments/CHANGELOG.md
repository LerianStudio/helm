# Plugin-br-payments Changelog

## [2.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.2)

Fixes:
- Keep control-plane guard on API pods and trim comments to ensure proper functionality. (@fredcamaral)
- Align starter overlay, schema, and pod labels for consistency. (@fredcamaral)

Improvements:
- Fix the `1.1.2` secret commands in the documentation for better clarity. (@fredcamaral)
- Correct the `1.1.2` upgrade guide to reflect accurate instructions. (@fredcamaral)
- Add verified upgrade guides for versions `1.1.3` to `2.2.1` to assist users in transitioning between versions. (@fredcamaral)
- Correct chart documentation against templates and app code to ensure accuracy. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.1...plugin-br-payments-v2.2.2)

---

## [2.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.2)

Fixes:
- Keep control-plane guard on API pods and trim comments to maintain code clarity. (@fredcamaral)
- Align starter overlay, schema, and pod labels for consistent deployment configurations. (@fredcamaral)

Improvements:
- Correct the `plugin-br-payments` `1.1.2` upgrade guide to ensure accurate upgrade instructions. (@fredcamaral)
- Fix secret commands in the `plugin-br-payments` `1.1.2` documentation for improved clarity. (@fredcamaral)
- Add verified upgrade guides for versions from `1.1.3` to `2.2.1` to assist users in transitioning between versions. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.1...plugin-br-payments-v2.2.2)

---

## [2.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.2)

Fixes:
- Keep control-plane guard on API pods and trim comments to improve clarity and maintainability. (@fredcamaral)
- Align starter overlay, schema, and pod labels to ensure consistency across the deployment. (@fredcamaral)

Improvements:
- Fix the `plugin-br-payments` `1.1.2` secret commands to ensure accurate documentation. (@fredcamaral)
- Correct the `plugin-br-payments` `1.1.2` upgrade guide for better guidance during updates. (@fredcamaral)
- Add verified upgrade guides for versions `1.1.3` to `2.2.1` to assist users in transitioning between versions smoothly. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.1...plugin-br-payments-v2.2.2)

---

## [2.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.2)

Fixes:

- Keep control-plane guard on API pods and trim comments. (@fredcamaral)
- Align starter overlay, schema, and pod labels for consistency. (@fredcamaral)

Improvements:

- Fix secret commands for `plugin-br-payments` `1.1.2`. (@fredcamaral)
- Correct the upgrade guide for `plugin-br-payments` `1.1.2`. (@fredcamaral)
- Add verified upgrade guides for versions `1.1.3` to `2.2.1`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.1...plugin-br-payments-v2.2.2)

---

## [2.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.2)

Fixes:
- Keep control-plane guard on API pods and trim comments for improved clarity. (@fredcamaral)
- Align starter overlay, schema, and pod labels for consistency. (@fredcamaral)

Improvements:
- Fix secret commands for `plugin-br-payments` `1.1.2` to ensure accuracy. (@fredcamaral)
- Correct the upgrade guide for `plugin-br-payments` `1.1.2` to provide clear instructions. (@fredcamaral)
- Add verified upgrade guides for versions from `1.1.3` to `2.2.1` to assist users in transitioning smoothly. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.1...plugin-br-payments-v2.2.2)

---

## [2.2.2](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.2)

Fixes:

- Keep control-plane guard on API pods and trim comments for better clarity. (@fredcamaral)
- Align starter overlay, schema, and pod labels to ensure consistency. (@fredcamaral)

Improvements:

- Fix secret commands in the `plugin-br-payments` `1.1.2` documentation to ensure accuracy. (@fredcamaral)
- Correct the `plugin-br-payments` `1.1.2` upgrade guide for improved clarity. (@fredcamaral)
- Add verified upgrade guides for versions `1.1.3` to `2.2.1` to assist users in the upgrade process. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.1...plugin-br-payments-v2.2.2)

---

## [2.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.1)

Fixes:
- Updated charts to use stable payments `1.2.0`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.0...plugin-br-payments-v2.2.1)

---

## [2.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.1)

Fixes:
- Updated charts to use stable payments version `1.2.0`. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.0...plugin-br-payments-v2.2.1)

---

## [2.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.1)

Fixes:

- Use stable payments `1.2.0` in charts. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.0...plugin-br-payments-v2.2.1)

---

## [2.2.1](https://github.com/LerianStudio/helm/releases/tag/plugin-br-payments-v2.2.1)

Fixes:

- Use stable payments `1.2.0` in charts. (@fredcamaral)

[Compare changes](https://github.com/LerianStudio/helm/compare/plugin-br-payments-v2.2.0...plugin-br-payments-v2.2.1)

---

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

