## [3.1.1]

### Fixed

- Restore 3.1 chart content dropped by the 3.1.0 stable release (scheduler
  worker Deployment, valkey subchart, XSD-validator + IRSA sidecars,
  schema/docs, helpers, values.schema); WORKOS_TM_CLIENT_SECRET support
  retained. The 3.1 work below was published only on the
  `flowker-v3.1.0-beta.1` tag and never merged to `main`; the stable 3.1.0
  release was cut from `main` without it, regressing the chart. This restores
  the full beta.1 superset.

## [3.1.0] — Unreleased

### Added

- **Scheduler worker Deployment** (`worker.enabled`, default on): a second
  Deployment running the `/worker` binary from the same flowker image (queue
  consume server + background jobs), single replica with a `Recreate` strategy
  and no HPA. Reuses the api ConfigMap + Secret with a worker-only ConfigMap
  layered last. Dedicated worker helpers, ServiceAccount, and ConfigMap.
- **Full runtime env surface** in the ConfigMap/Secret: Schema Registry S3,
  secrets backend, token cache, internal provider URLs, scheduler
  (`SCHEDULER_*`), CORS/body caps, and the XSD knobs. WorkOS Tenant Manager
  token mint (`flowker.workosTmEnabled`) is all-or-none gated with fail-fast
  `required` guards.
- **In-pod XSD validator sidecar** (`flowker.xsdValidator.enabled`, default on):
  injected into the api and worker pods (port 8081, hardened securityContext).
  `XSD_VALIDATOR_URL` auto-wires to loopback; the cleartext acknowledgement is
  scoped to the in-pod hop only (an off-pod URL override defaults back to secure).
- **valkey subchart** (`valkey.enabled`, default off) backing the scheduler
  queue. `SCHEDULER_REDIS_HOST` auto-derives to the subchart Service when
  enabled; an explicit override or an external Redis is honored.
- **AWS authentication**: IRSA via the api/worker ServiceAccount annotations,
  and an optional IAM Roles Anywhere signing sidecar (`aws.rolesAnywhere.enabled`,
  default off) for non-EKS clusters, serving credentials over a loopback IMDS
  endpoint with the client cert mounted read-only.

### Changed

- Chart type annotation `single-service` → `multi-component`.
- Default `flowker.image.tag` bumped to `1.2.0-beta.82` (the first image that
  bundles the `/worker` binary and has a published `flowker-xsd-validator`
  sidecar image). `appVersion` updated to match.
- Shared init/env helpers (`flowker.waitForMongoInit`, `flowker.otelHostEnv`)
  extracted and reused across the api and worker Deployments.

### Migration notes

- The worker and XSD sidecar default on and require an app image
  >= `1.2.0-beta.82`. Pin `flowker.image.tag` accordingly, or set
  `worker.enabled=false` / `flowker.xsdValidator.enabled=false` to opt out.
- To run the scheduler, either set `valkey.enabled=true` or point
  `flowker.configmap.SCHEDULER_REDIS_HOST` at an external Redis; otherwise the
  scheduler stays a nil-safe no-op.

## [2.1.0-beta.5] — Unreleased

### Changed

- **Move `MONGO_URI` from ConfigMap to Secret.** The connection URI
  embeds the application password and must not be persisted in plaintext
  in a ConfigMap.
- **`MONGO_URI` is now REQUIRED** — set `flowker.secrets.MONGO_URI` to a
  full `mongodb://` URI. Auto-construction was removed because the
  application reads `MONGO_URI` directly and the individual fields used
  for construction were not consumed by the app.

### Removed

- ConfigMap no longer emits the following Mongo env vars (the application
  source does not read them):
  - `MONGO_HOST`, `MONGO_PORT`, `MONGO_APP_USER`
  - `MONGO_MIN_POOL_SIZE`, `MONGO_MAX_IDLE_TIME_MS`
  - `MONGO_CONNECT_TIMEOUT_MS`, `MONGO_SOCKET_TIMEOUT_MS`
- Secret no longer emits `MONGO_APP_PASSWORD` standalone — the password
  is provided as part of `MONGO_URI`.

### Kept in ConfigMap

- `MONGO_DB_NAME` (read via `env:"MONGO_DB_NAME"`)
- `MONGO_MAX_POOL_SIZE` (read via `getEnvAsIntOrDefault`)

### Kept in Secret

- `MONGO_URI` (REQUIRED, read via `env:"MONGO_URI"`)
- `MONGO_TLS_CA_CERT` (read via `env:"MONGO_TLS_CA_CERT"`)

### Migration notes

Installs that previously set `flowker.configmap.MONGO_URI` or
`flowker.secrets.MONGO_APP_PASSWORD` MUST move to
`flowker.secrets.MONGO_URI` with the full URI. The chart will fail to
render if `MONGO_URI` is not set.

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
