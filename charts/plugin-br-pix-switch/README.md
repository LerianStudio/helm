# plugin-br-pix-switch (Helm chart)

BACEN-compliant PIX instant payment platform for the Lerian ecosystem.

The plugin is a Go monorepo that produces 10 independently-deployable binaries.
This chart deploys all of them with one helm release. Each component has its
own Deployment, Service, ConfigMap, Secret, HPA, and PDB; ingress is opt-in
per component.

## Components

| Key in values.yaml | Component | Default port | Notes |
|---|---|---|---|
| `spi` | `spi/api` | 4101 | PIX SPI service |
| `spiSystemplane` | `spi/systemplane/api` | 4102 | Runtime config plane |
| `adapterBtgMock` | `adapter-btg-mock/api` | 4103 | BTG provider mock (disabled by default) |
| `dictHub` | `dict/hub/api` | 4104 | DICT hub (Postgres + Mongo + Valkey) |
| `dictHubVsync` | `dict/hub/vsync` | 4105 | DICT verification sync worker (singleton) |
| `dictProxy` | `dict/proxy/api` | 4106 | DICT proxy to BCB |
| `dictSystemplane` | `dict/systemplane/api` | 4107 | Runtime config plane for DICT |
| `cobHub` | `cob/hub/api` | 4108 | COB hub |
| `cobProxy` | `cob/proxy/api` | 4109 | COB proxy to BCB |
| `cobSystemplane` | `cob/systemplane/api` | 4110 | Runtime config plane for COB |

## Architecture

The plugin uses a Proxy/Hub deployment model. A "hub" component owns business
logic and local state (its own Postgres database, sometimes Mongo+Valkey),
while a "proxy" component is a stateless pass-through. Both expose identical
APIs. Three Postgres databases are required (`pix-spi`, `pix-dict`, `pix-cob`)
and two Mongo databases for `dict-hub` and `cob-hub`.

## Required infrastructure

For a full deployment:
- **PostgreSQL**: 3 databases (`pix-spi`, `pix-dict`, `pix-cob`) and a role
  `pixswitch` with full ownership of each
- **MongoDB**: 2 databases (`pix-dict`, `pix-cob`)
- **Valkey** (Redis-compatible): used by `spi`, `dict-hub`, `dict-hub-vsync`,
  `dict-proxy` for caching
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
- `adapterBtgMock`: `false` (it's a mock — only enable in dev/staging)

## Configuration

Each component has its own `configmap` and `secrets` blocks in values.yaml.
The chart accepts every env var the app reads at runtime; see
`templates/<component>/configmap.yaml` for the rendered list per component.

The app reads:
- `DATABASE_URL` (full Postgres DSN, not `DB_HOST/DB_PORT/...`)
- `MONGO_URL`, `MONGO_DB_NAME` (only `dict-hub` and `cob-hub`)
- `VALKEY_URL` (full Redis URL)
- `RABBITMQ_URI` (only `dict-hub-vsync`)
- `LICENSE_KEY`, `LICENSE_ORGANIZATION_IDS` (every component)
- `DEPLOYMENT_MODE` (saas/byoc/local)
- Sibling URLs (`ADAPTER_BASE_URL`, `DICT_BASE_URL`, `COB_BASE_URL`,
  `MIDAZ_BASE_URL`, `CRM_BASE_URL`)
- Per-component-specific keys (`ISPB`, `ORGANIZATION_ID`, `KEY_CACHE_TTL_SEC`,
  `VSYNC_*`, etc.)

## Image

All 10 components share the same image, parameterized at build time with
`APP_NAME` + `COMPONENT_NAME` build args. The chart sets `image.repository`
once at the global level (`global.image.repository`) and individual
components inherit it. Each component can override `image.tag` if you need
to pin a specific tag per component (rare).

## Pattern source

This chart follows the multi-component layout used by
`helm/charts/plugin-access-manager` (auth, auth-backend, identity) and
`helm/charts/midaz` (onboarding, transaction, crm, ledger).

## Compatibility

| Chart version | App image tag |
|---|---|
| 1.1.0-beta.2+ | 1.0.0-beta.51+ |
| 1.0.0 – 1.1.0-beta.1 | (chart was incomplete; do not use) |

## Useful commands

```sh
# Render with all components and one disabled
helm template my-release ./plugin-br-pix-switch --set adapterBtgMock.enabled=true

# Lint
helm lint ./plugin-br-pix-switch

# Inspect a single component's deployment
helm template my-release ./plugin-br-pix-switch | yq 'select(.kind=="Deployment" and .metadata.name=="my-release-spi")'

# Get all chart-managed pods
kubectl get pods -l app.kubernetes.io/part-of=plugin-br-pix-switch -n <ns>
```
