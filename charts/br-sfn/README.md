# br-sfn

Helm chart for **br-sfn** — the Lerian Brazilian SFN rails monorepo: SPB/STR
(TED), SPI (Pix — four runtime binaries), SILOC (card settlement), SCR (credit
information), desk (cockpit operator-state + four-eyes), slc-edge (Cabine SLC
authenticated passthrough) and the cockpit operations SPA.

## Modularity contract

**Every component ships `enabled: false`.** br-sfn is a monorepo of independent
rails and no environment runs all of them — enable exactly what the deployment
operates:

```yaml
spb:
  enabled: true
spi:
  enabled: true
cockpit:
  enabled: true
```

A default render produces only the shared ServiceAccount.

| Component | Values key | Image | Port | Migrations |
|-----------|-----------|-------|------|------------|
| SPB/STR rail | `spb` | `ghcr.io/lerianstudio/br-spb` | 3000 | baked (`/app/migrations`) |
| SPI/Pix api | `spi.api` | `ghcr.io/lerianstudio/br-spi` | 9800 | family Job (dedicated image) |
| SPI/Pix dict | `spi.dict` | `ghcr.io/lerianstudio/br-spi-dict` | 9801 | — |
| SPI/Pix brcode | `spi.brcode` | `ghcr.io/lerianstudio/br-spi-brcode` | 9802 | — |
| SPI/Pix core | `spi.core` | `ghcr.io/lerianstudio/br-spi-core` | 9803 | — |
| SILOC rail | `siloc` | `ghcr.io/lerianstudio/br-siloc` | 9820 | dedicated (`br-siloc-migrations`) |
| SCR rail | `scr` | `ghcr.io/lerianstudio/br-scr` | 3003 | baked (`/migrations`, table `schema_migrations_scr`) |
| desk | `desk` | `ghcr.io/lerianstudio/br-desk` | 3002 | baked (`/migrations`) |
| slc-edge | `slcEdge` | `ghcr.io/lerianstudio/br-slc-edge` | 3005 | none (stateless) |
| cockpit SPA | `cockpit` | `ghcr.io/lerianstudio/br-sfn-cockpit` | 8080 | none (static bundle) |

The four SPI components share `spi.configmap` / `spi.secrets` (merged under
each component's own block; component keys win) because they ride one Postgres,
one Redis and one RedPanda.

## Migrations

PreSync ArgoCD hook Jobs (`hook-weight: -1`), one per rail that owns a schema,
in two flavors:

- **baked** (spb, scr, desk): an initContainer copies the migrations tree out
  of the app image; `migrate/migrate` applies it. Postgres passwords must be
  URL-safe (no `@ : / ? # %`).
- **dedicated** (spi, siloc): the rail's own migrator image runs with the
  `POSTGRES_*` env contract. The SPI migrator owns module ordering
  (global → events → spi → dict → brcode → core) and the per-module bookkeeping
  tables its `/readyz` schema probes read — never replace it with a plain
  golang-migrate run.

Connection settings resolve from `<component>.migrations.postgres.*`, falling
back to the component's `configmap` keys (`POSTGRES_HOST`, `POSTGRES_PORT`,
`POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_SSLMODE`). Host, user and database
are required — the render fails loud when missing.

## Configuration model

`<component>.configmap` and `<component>.secrets` are emitted **verbatim** into
the component's ConfigMap/Secret (no fixed allowlist), so new env vars never
need a chart change. On GitOps tiers the secrets map carries ArgoCD Vault
Plugin `<path:...>` refs. `useExistingSecret: true` + `existingSecretName`
switches the component to an operator-provided Secret.

## Infra contract

Postgres, Valkey/Redis, RabbitMQ, RedPanda and IBM MQ are **external**,
pre-provisioned services — this chart ships no infra subcharts and no
dependencies. RedPanda topics for spb/spi are an environment concern (the
compose `redpanda-topics` one-shot is dev-only).

## Cockpit caveat

The SPA bakes `VITE_*` URLs at **image build time**. The published baseline
image carries honest-degrade defaults; an environment that needs real URLs
pins an environment-specific image build.

## Chart Contract

- Chart type: `multi-component`
- Required secrets: None for default render (all components disabled). Per
  enabled rail: `POSTGRES_PASSWORD` in `<component>.secrets` (or an
  `existingSecretName` Secret) for spb/spi/siloc/scr/desk; slc-edge and
  cockpit need none.
- Dependency notes: no subcharts — Postgres/Valkey/RabbitMQ/RedPanda/IBM MQ
  are external services by contract.
- Production overrides: `<component>.enabled`, `<component>.image.tag`
  (components version independently — `svc/vX.Y.Z` tags), `configmap`/`secrets`
  maps per rail, `resources`, `ingress`; `useExistingSecret`/
  `existingSecretName` for operator-owned credentials.
- Source/license: https://github.com/LerianStudio/br-sfn (proprietary).
