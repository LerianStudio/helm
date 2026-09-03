# br-sfn

Helm chart for **br-sfn** — the Lerian Brazilian SFN rails monorepo: SPB/STR
(TED), SPI (Pix — four runtime binaries), SILOC (card settlement), SCR (credit
information), desk (cockpit operator-state + four-eyes), correios (BC Correio
regulatory mailbox), slc-edge (Cabine SLC authenticated passthrough) and the
cockpit operations SPA.

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
| correios rail | `correios` | `ghcr.io/lerianstudio/plugin-bc-correios` | 8080 | baked (`/migrations`, db key `POSTGRES_NAME`) |
| slc-edge | `slcEdge` | `ghcr.io/lerianstudio/br-slc-edge` | 3005 | none (stateless) |
| cockpit SPA | `cockpit` | `ghcr.io/lerianstudio/br-sfn-cockpit` | 8080 | none (static bundle) |

The four SPI components share `spi.configmap` / `spi.secrets` (merged under
each component's own block; component keys win) because they ride one Postgres,
one Redis and one RedPanda.

## Migrations

PreSync ArgoCD hook Jobs (`hook-weight: -1`), one per rail that owns a schema,
in two flavors:

- **baked** (spb, scr, desk, correios): an initContainer copies the migrations
  tree out of the app image; `migrate/migrate` applies it. Postgres passwords
  must be URL-safe (no `@ : / ? # %`).
- **dedicated** (spi, siloc): the rail's own migrator image runs with the
  `POSTGRES_*` env contract. The SPI migrator owns module ordering
  (global → events → spi → dict → brcode → core) and the per-module bookkeeping
  tables its `/readyz` schema probes read — never replace it with a plain
  golang-migrate run.

Connection settings resolve from `<component>.migrations.postgres.*`, falling
back to the component's `configmap` keys (`POSTGRES_HOST`, `POSTGRES_PORT`,
`POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_SSLMODE`). correios is the one
exception: its service reads the database name from `POSTGRES_NAME`, so its
migration Job falls back to `correios.configmap.POSTGRES_NAME` instead of
`POSTGRES_DB`. Host, user and database are required — the render fails loud
when missing.

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

### SPB event topics: unlimited retention is a provisioning requirement

The SPB rail publishes its money facts on one application topic,
`lerian.streaming.br-spb`, with a dead-letter twin `lerian.streaming.br-spb.dlq`.
The service never expires anything on its side (its durable outbox is never
pruned), and it assumes the broker does not either — a consumer that comes back
after days must find every event it missed. Provision **both** topics with:

```text
retention.ms=-1  retention.bytes=-1  cleanup.policy=delete
```

`cleanup.policy=delete` is deliberate: `retention.ms=-1` under `compact` means
something else, and compaction would drop history by key.

The consumer group's committed **offsets** expire on a separate, cluster-level
timer that topic retention never touches (default 7 days on both brokers). A
group that stays down past it loses its *position*, not the data — and what
happens next is decided by the **consumer's** offset-reset policy, which this
chart does not control: a franz-go consumer (the default of Lerian's
lib-streaming, `ConsumeResetOffset` at the start of the log) silently re-reads
everything — event ids are deterministic, so a consumer that deduplicates by
id survives it, but it is hours of redelivery nobody chose; a consumer with the
Java client default `auto.offset.reset=latest` silently jumps to the head and
**never sees the events it missed**. Neither outcome is chosen by anyone, so
disable that timer too:

- RedPanda: `rpk cluster config set group_offset_retention_sec null`
  (`null` is RedPanda's documented "off").
- Apache Kafka: `offsets.retention.minutes` accepts no "off" value
  (`int`, `[1,...]`) — set it to its maximum, `2147483647` (~4085 years).

Nothing in this chart provisions or verifies either setting today; both are the
operator's duty. Source of the requirement and the mechanics:
`docs/streaming/lib-streaming-v3-rollout.md` and
`services/spb/docs/PROJECT_RULES.md` (§ Retenção) in the br-sfn repository.

## Cockpit caveat

The SPA bakes `VITE_*` URLs at **image build time**. The published baseline
image carries honest-degrade defaults; an environment that needs real URLs
pins an environment-specific image build.

## Chart Contract

- Chart type: `multi-component`
- Required secrets: None for default render (all components disabled). Per
  enabled rail: `POSTGRES_PASSWORD` in `<component>.secrets` (or an
  `existingSecretName` Secret) for spb/spi/siloc/scr/desk/correios; slc-edge
  and cockpit need none.
- Dependency notes: no subcharts — Postgres/Valkey/RabbitMQ/RedPanda/IBM MQ
  are external services by contract.
- Production overrides: `<component>.enabled`, `<component>.image.tag`
  (components version independently — `svc/vX.Y.Z` tags), `configmap`/`secrets`
  maps per rail, `resources`, `ingress`; `useExistingSecret`/
  `existingSecretName` for operator-owned credentials.
- Source/license: https://github.com/LerianStudio/br-sfn (proprietary).
