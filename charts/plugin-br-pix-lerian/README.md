# plugin-br-pix-lerian (Helm chart)

## Chart Contract

- Chart type: `multi-component`
- Required secrets: None for default render; credential-bearing DSNs, URLs, tokens, and passwords belong in component `secrets`, never in component `configmap`.
- Dependency notes: Uses local MongoDB, PostgreSQL, RabbitMQ, and Redis/Valkey dependency charts unless external services are configured.
- Production overrides: Provide SPI/DICT/COB/adapter credentials through component secrets or existing Secrets where supported; keep ConfigMaps limited to non-sensitive hosts, ports, flags, and identifiers.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

BACEN-compliant PIX instant payment platform for the Lerian ecosystem.

The plugin is a Go monorepo that produces 15 independently-deployable binaries.
This chart deploys all of them with one helm release. Each component has its
own Deployment, Service, ConfigMap, Secret, HPA, and PDB; ingress is opt-in
per component.

## Components

| Key in values.yaml | Component | Default port | Notes |
|---|---|---|---|
| `spi` | `spi/api` | 4101 | PIX SPI service |
| `spiSystemplane` | `spi/systemplane/api` | 4102 | Runtime config plane |
| `adapterProviderMock` | `adapter-provider-mock/api` | 4103 | BTG provider mock (disabled by default) |
| `dictHub` | `dict/hub/api` | 4104 | DICT hub (Postgres + Mongo + Valkey) |
| `dictHubVsync` | `dict/hub/vsync` | 4105 | DICT verification sync worker (singleton) |
| `dictProxy` | `dict/proxy/api` | 4106 | DICT proxy to BCB |
| `dictSystemplane` | `dict/systemplane/api` | 4107 | Runtime config plane for DICT |
| `cobHub` | `cob/hub/api` | 4108 | COB hub |
| `cobProxy` | `cob/proxy/api` | 4109 | COB proxy to BCB |
| `cobSystemplane` | `cob/systemplane/api` | 4110 | Runtime config plane for COB |
| `adapterLerian` | `adapter-lerian/api` | 4113 | Lerian provider adapter (API, disabled by default) |
| `adapterLerianConsumer` | `adapter-lerian/consumer` | 4114 | Lerian provider adapter Kafka consumer (disabled by default) |
| `adapterLerianSystemplane` | `adapter-lerian/systemplane/api` | 4115 | Runtime config plane for adapter-lerian (disabled by default) |
| `pixauto` | `pixauto/api` | 4116 | Pix Automático payer side (disabled by default) |
| `pixautoSystemplane` | `pixauto/systemplane/api` | 4117 | Runtime config plane for Pix Automático (disabled by default) |

> Ports 4111 and 4112 are deliberately skipped. 4111 belongs to `br-slc` — its
> chart, two environments and a NetworkPolicy scoped to it — and the pair was
> left free by the component allocated before Pix Automático. Do not fill the
> gap; take the next number above 4117.

## Architecture

The plugin uses a Proxy/Hub deployment model. A "hub" component owns business
logic and local state (its own Postgres database, sometimes Mongo+Valkey),
while a "proxy" component is a stateless pass-through. Both expose identical
APIs. Five Postgres databases are required (`pix-spi`, `pix-dict`, `pix-cob`,
`pix-adapter-lerian`, `pix-pixauto`) and one Mongo database (`pix-dict`) for `dict-hub`
(`pix-cob` is a forward-compat slot the Mongo bootstrap provisions but no component
reads yet).

## Required infrastructure

For a full deployment:
- **PostgreSQL**: 5 databases (`pix-spi`, `pix-dict`, `pix-cob`,
  `pix-adapter-lerian`, `pix-pixauto`) and a role `pixswitch` with full
  ownership of each
- **MongoDB**: 1 database (`pix-dict`) used by `dict-hub`; the bootstrap also
  provisions `pix-cob` as a forward-compat slot, but no component reads it yet
- **Valkey** (Redis-compatible): used by `spi`, `dict-hub`, `dict-hub-vsync`
  for caching and by `pixauto` for its idempotency replay gate (optional there —
  without it the gated routes fall through to their durable backstops)
- **RabbitMQ**: used by `dict-hub-vsync` only

For development, the chart's `postgresql`, `valkey`, `rabbitmq`, and `mongodb`
subcharts can be enabled (set their `enabled: true`). For production, point
the in-cluster components at managed external services and leave the
subcharts disabled (default).

## Enabling/disabling components

Each component's top-level key has an `enabled: true|false` field. Set
`enabled: false` to skip a component entirely (no resources rendered).
Default `enabled` values:

- `spi`, `spiSystemplane`, `dictHub`, `dictHubVsync`, `dictProxy`,
  `dictSystemplane`, `cobHub`, `cobProxy`, `cobSystemplane`: `true`
- `adapterProviderMock`: `false` (it's a mock — only enable in dev/staging)
- `adapterLerian`, `adapterLerianConsumer`, `adapterLerianSystemplane`: `false`
  (Lerian provider adapter — enable per environment)
- `pixauto`, `pixautoSystemplane`: `false` (Pix Automático payer side — enable
  per environment once its `pix-pixauto` database and DSN secret exist)

## Configuration

Each component has its own `configmap` and `secrets` blocks in values.yaml.
The chart accepts every env var the app reads at runtime; see
`templates/<component>/configmap.yaml` for the rendered list per component.

The app reads:
- `DATABASE_URL` (full Postgres DSN, not `DB_HOST/DB_PORT/...`)
- `MONGO_URL`, `MONGO_DB_NAME` (only `dict-hub`)
- `VALKEY_URL` (full Redis URL)
- `RABBITMQ_URI` (only `dict-hub-vsync`)
- `LICENSE_KEY`, `ORGANIZATION_IDS` (every component). `ORGANIZATION_IDS` is
  the live key (`pkg/config` `BaseConfig.LicenseOrganizationIDs`); the
  `LICENSE_ORGANIZATION_IDS` entry some components still carry in values.yaml
  is inert — no code reads that name.
- `DEPLOYMENT_MODE` (saas/byoc/local)
- Sibling URLs (`ADAPTER_BASE_URL`, `DICT_BASE_URL`, `COB_BASE_URL`,
  `MIDAZ_BASE_URL`, `CRM_BASE_URL`)
- Per-component-specific keys (`ISPB`, `ORGANIZATION_ID`, `KEY_CACHE_TTL_SEC`,
  `VSYNC_*`, etc.)

## Image

Each component publishes and pulls its own image
(`ghcr.io/lerianstudio/plugin-br-pix-lerian-<component>-api`), set per
component under `<component>.image.repository`. Worker components omit the
`-api` suffix (e.g. `plugin-br-pix-lerian-dict-hub-vsync` and
`plugin-br-pix-lerian-adapter-lerian-consumer`). There is no shared
`global.image.repository`. When a component's `image.tag` is unset it falls
back to `.Chart.AppVersion`, which keeps the cohort in lockstep by default;
override `<component>.image.tag` to pin a specific build per component (rare).

## Pattern source

This chart follows the multi-component layout used by
`helm/charts/plugin-access-manager` (auth, auth-backend, identity) and
`helm/charts/midaz` (onboarding, transaction, crm, ledger).

## Compatibility

| Chart version | App image tag |
|---|---|
| 1.1.0-beta.2+ | 1.0.0-beta.51+ |
| 1.0.0 – 1.1.0-beta.1 | (chart was incomplete; do not use) |

There is no in-place upgrade path from the `plugin-br-pix-switch` chart — moving to this chart is a fresh install (cutover), not a `helm upgrade`; the switch chart's own history is kept in [../plugin-br-pix-switch/docs/UPGRADE-1.1.md](../plugin-br-pix-switch/docs/UPGRADE-1.1.md).

## Useful commands

```sh
# Render with all components and one disabled
helm template my-release ./plugin-br-pix-lerian --set adapterProviderMock.enabled=true

# Lint
helm lint ./plugin-br-pix-lerian

# Inspect a single component's deployment
helm template my-release ./plugin-br-pix-lerian | yq 'select(.kind=="Deployment" and .metadata.name=="my-release-spi")'

# Get all chart-managed pods
kubectl get pods -l app.kubernetes.io/part-of=plugin-br-pix-lerian -n <ns>
```
