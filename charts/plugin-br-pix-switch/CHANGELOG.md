# Plugin-br-pix-switch Changelog

## [2.0.0-beta.1] - Multi-component refactor (BREAKING)

The chart now deploys all 10 independently-built components of the
plugin-br-pix-switch app, each with its own Deployment, Service, ConfigMap,
Secret, ServiceAccount, HPA, PDB, and optional Ingress.

### Components

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

### Breaking changes

- **values.yaml shape rewritten**. The single `pixSwitch` block is gone,
  replaced by per-component blocks (`spi`, `dictHub`, etc.). Existing values
  files for chart 1.x will not work with 2.x.
- **Env-var schema corrected**. App reads `DATABASE_URL` (full DSN), not
  `DB_HOST/DB_PORT/...`. Mongo uses `MONGO_URL`/`MONGO_DB_NAME`. Valkey uses
  `VALKEY_URL`. Old chart's `DB_*`/`VALKEY_HOST`/etc. envs were never read by
  the app.
- **Port allocation moved to 4101–4110** (per org port allocation table; the
  4001–4013 range used in docker-compose conflicts with other Lerian services).
- **`LICENSE_ORGANIZATION_IDS`** key (the app reads this name) replaces
  `ORGANIZATION_IDS`.
- **Per-component IDs**: every K8s resource is named `<release>-<component>`,
  so resource counts grow from 7 to ~50 (9 components × 5–7 resources).
- Chart was bumped to a major version (`2.0.0-beta.1`) to signal the breaking
  change.

### Migration

If you were using chart 1.x (which never deployed a working app due to the
env-var mismatch), there is no in-place migration. Rewrite your values
following `values.yaml`'s new shape, provision Postgres (3 DBs: pix-spi,
pix-dict, pix-cob), Mongo (2 DBs: pix-dict, pix-cob), Valkey, and (for
dict-hub-vsync) RabbitMQ, then deploy 2.0.0-beta.1.

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

