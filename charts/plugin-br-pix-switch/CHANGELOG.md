# Plugin-br-pix-switch Changelog

## [1.1.0-beta.2] - Multi-component refactor + bootstrap Jobs + subchart wiring

The chart now deploys all 10 independently-built components of the
plugin-br-pix-switch app, each with its own Deployment, Service, ConfigMap,
Secret, ServiceAccount, HPA, PDB, and optional Ingress.

The prior `1.x-beta.1` chart never produced a working deployment (its
single-binary `pixSwitch` block emitted env vars the app source never reads,
e.g. `DB_HOST`/`DB_PORT`/... while the source reads `DATABASE_URL`). Because
no prior tag was ever functional, this release continues the 1.x line
instead of jumping to 2.0; consumers who tried 1.x cannot have a working
deployment to migrate from.

### Components (10 binaries, 10 Deployments)

- `spi` (port 4101) — PIX SPI service
- `spi-systemplane` (port 4102) — runtime config plane for SPI
- `adapter-btg-mock` (port 4103) — BTG provider mock (disabled by default)
- `dict-hub` (port 4104) — DICT hub
- `dict-hub-vsync` (port 4105) — DICT verification sync worker
- `dict-proxy` (port 4106) — DICT proxy to BCB
- `dict-systemplane` (port 4107) — runtime config plane for DICT
- `cob-hub` (port 4108) — COB hub
- `cob-proxy` (port 4109) — COB proxy to BCB
- `cob-systemplane` (port 4110) — runtime config plane for COB

Ports allocated in the 41xx range to avoid conflicts with the org port
allocation table (4001–4013 is used by Identity, Fees, CRM, Reporter, etc.).

### Bootstrap Jobs

Optional database bootstrap Jobs (gated by
`global.externalPostgresDefinitions.enabled` and
`global.externalMongoDefinitions.enabled`, both `false` by default):

- `bootstrap-postgres-pix-spi` — creates `pix-spi` database + `pixswitch` role
- `bootstrap-postgres-pix-dict` — creates `pix-dict` database + grants
- `bootstrap-postgres-pix-cob` — creates `pix-cob` database + grants
- `bootstrap-mongodb` — creates the `pixswitch` Mongo user with `readWrite`
  on `pix-dict` and `pix-cob` databases

Each Job is idempotent (skips when the role/database/user already exists).

### Subchart dependencies (all disabled by default)

| Subchart | Used by |
|---|---|
| postgresql (Bitnami 16.3) | 7 components (DATABASE_URL) |
| valkey (Bitnami 2.4.7) | spi, dict-hub, dict-hub-vsync (optional cache) |
| mongodb (Bitnami 16.4) | dict-hub only |
| rabbitmq (groundhog2k 2.1.11) | dict-hub-vsync only |

Default credentials (`pixswitch` / `lerian`) feed the URL defaults in each
component's configmap block so a fresh `helm install --set
<subchart>.enabled=true` works out of the box. Production deployments
disable the subcharts and provide URLs via an external Kubernetes Secret
(see values.yaml header for the override pattern).

### Other features

- `wait-for-dependencies` init container parses each component's URL env
  vars (DATABASE_URL / MONGO_URL / VALKEY_URL / RABBITMQ_URI) and waits
  for each TCP endpoint to be reachable. Skips dependencies that aren't
  configured for that component.
- Per-component `command` / `args` overrides so a single multi-binary
  image (when the source repo publishes one) can run different binaries
  per Deployment.
- `OTEL_RESOURCE_SERVICE_VERSION` auto-derived from the deployed image
  tag (component > global > Chart.AppVersion).
- When `TELEMETRY_ENABLED=true`, each pod injects `HOST_IP` via downward
  API and points `OTEL_EXPORTER_OTLP_ENDPOINT` at `$(HOST_IP):4317` for
  node-local OTel collectors. Operators can override the endpoint via
  the component's configmap for external collectors.
- `livenessProbe.path` defaults to `/health` (matches what the pix-switch
  binaries actually serve).

### Migration

No usable 1.0.x / 1.1.0-beta.1 deployment exists today (env-var mismatch).
Operators who tried earlier versions should:

1. Rewrite values to the new shape (per-component blocks: `spi:`, `dictHub:`,
   etc.) using `values-template.yaml` as a starting point.
2. Provision 3 Postgres databases (`pix-spi`, `pix-dict`, `pix-cob`) and a
   `pixswitch` role — or let the bootstrap Jobs do it via
   `global.externalPostgresDefinitions.enabled=true`.
3. Provision MongoDB databases for `dict-hub` (and optionally `cob-hub`).
4. Configure Valkey (optional, for caching) and RabbitMQ (required only for
   `dict-hub-vsync`).
5. Deploy with `installed: true` in helmfile.

Pattern adapted from `helm/charts/plugin-access-manager` and
`helm/charts/midaz` multi-component layouts.

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-switch-v1.0.0)

- **Features**
  - Added Helm chart for plugin-br-pix-switch.

- **Fixes**
  - Addressed CodeRabbit feedback on NOTES, README, configmap, and labeler.
  - Corrected appVersion to 1.0.0-beta.1 and updated the compatibility matrix.
  - Applied container securityContext, fixed tolerations type, and added NOTES defaults.

Contributors: @bedatty, @lerian-studio

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-pix-switch-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-switch-v1.0.0)

- **Features:**
  - Added Helm chart for plugin-br-pix-switch.

- **Fixes:**
  - Addressed CodeRabbit feedback on NOTES, README, configmap, and labeler.
  - Corrected appVersion to 1.0.0-beta.1 and updated the compatibility matrix.
  - Applied container securityContext, fixed tolerations type, and added NOTES defaults.

Contributors: @bedatty, @lerian-studio

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-pix-switch-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-switch-v1.0.0)

- **Features**
  - Added Helm chart for plugin-br-pix-switch.

- **Fixes**
  - Addressed CodeRabbit feedback on NOTES, README, configmap, and labeler.
  - Corrected appVersion to 1.0.0-beta.1 and added it to the compatibility matrix.
  - Applied container securityContext, fixed tolerations type, and added NOTES defaults.

Contributors: @bedatty, @lerian-studio

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-pix-switch-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-switch-v1.0.0)

- **Features:**
  - Added Helm chart for plugin-br-pix-switch.

- **Fixes:**
  - Addressed CodeRabbit feedback on NOTES, README, configmap, and labeler.
  - Corrected appVersion to 1.0.0-beta.1 and updated compatibility matrix.
  - Applied container securityContext, fixed tolerations type, and added NOTES defaults.

Contributors: @bedatty, @lerian-studio

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-pix-switch-v1.0.0)

---

## [1.0.0] - 2026-03-27

### Added

- Initial chart release for plugin-br-pix-switch
- Single Go service deployment (HTTP port 4000, gRPC port 7001)
- PostgreSQL dependency (Bitnami subchart v16.3)
- Valkey dependency (Bitnami subchart v2.4.6)
- HPA, PDB, Ingress support
- OpenTelemetry integration
- Readiness and liveness probes

