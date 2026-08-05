# Lerian dependency contract — the closed knob vocabulary

This is the STANDARD that makes chart productization uniform across a heterogeneous fleet.

**The problem it solves.** Apps are irreducibly particular — each has its own ~100 tuning keys, so
you can never standardize *app config* into knobs. But you don't need to: **typed knobs are
reserved for DEPENDENCY connections, and the set of dependencies is owned by the PLATFORM, not the
app.** Every Lerian service reaches the same small, closed set of infra dependencies. That set —
below — is the standard. Everything else goes to the one uniform escape hatch (`configmap.<KEY>`),
which needs no per-app design.

**The classification rule is therefore mechanical, not judgment:**

> A key is a typed **knob** IFF it matches a dependency domain in the table below (by `.env`
> prefix / helper). Otherwise it is an **escape-hatch passthrough** (`{{ $cm.KEY | default "X" }}`).

**When an app has a dependency this table doesn't cover** (object storage was the first such gap),
you DO NOT invent a bespoke knob in the chart. You **extend the vocabulary**: add a helper to
`lerian-common` and a row here. The standard evolves in ONE place (the library); charts stay
uniform and a consumer learns the vocabulary once. `coverage.py` enforces the boundary: every
active `.env` var either matches a domain here (knob) or lands in the escape hatch — no third
option, no knob invented outside this list.

Source of truth = `lerian-common` helper templates (run Step 0 of the skill to re-introspect; this
table is a snapshot of **lerian-common 1.4.0** — verify before relying on it).

---

## The closed vocabulary (lerian-common 1.4.0)

| Domain | `.env` prefix | Helper(s) | Env-wide block (`global.*`) | Per-component knob | Secret(s) → `secrets.yaml` |
|---|---|---|---|---|---|
| **PostgreSQL** | `POSTGRES_*` (host/conn) | `datastore.value` (type `postgres`) | `global.datastores.postgres.{host,port,user,ssl,replicaHost}` | `<comp>.datastores.postgres.*` (dedicated) | `POSTGRES_PASSWORD` |
| **Redis / Valkey** | `REDIS_*` (host/conn) | `datastore.value` (type `redis`) | `global.datastores.redis.{host,port,user,ssl}` | `<comp>.datastores.redis.*` | `REDIS_PASSWORD` |
| **MongoDB** | `MONGO_*` (host/conn) | `datastore.value` (type `mongo`) | `global.datastores.mongo.{host,port,user,uri,…}` | `<comp>.datastores.mongo.*` | `MONGO_PASSWORD` |
| **RabbitMQ** | `RABBITMQ_*` (host/conn) | `datastore.value` (type `broker`) | `global.datastores.broker.{host,port,user}` | `<comp>.datastores.broker.*` | `RABBITMQ_DEFAULT_PASS` |
| **Tenant-manager** (multi-tenancy) | `MULTI_TENANT_*` | `multiTenant.env` / `.secret` | `global.multiTenant.{url,redisHost,…}` | `<comp>.configmap.MULTI_TENANT_ENABLED` (the gate/knob, stays inline) + opt-in groups `<comp>.multiTenant.*` | `MULTI_TENANT_SERVICE_API_KEY`, `MULTI_TENANT_REDIS_PASSWORD` |
| **Streaming** (Kafka/RedPanda) | `STREAMING_*` | `streaming.env` / `.secret` | `global.streaming.{brokers,saslUsername,tls,…}` | `STREAMING_ENABLED` (extraEnvVars knob) + per-app identity `STREAMING_CLIENT_ID`/`_CLOUDEVENTS_SOURCE` (inline) | `STREAMING_SASL_PASSWORD`, `STREAMING_TLS_CA_CERT` |
| **Service discovery** (Consul) | `SD_*` | `serviceDiscovery.env` / `.envFlat` | `global.serviceDiscovery.*` | `SD_ENABLED` (extraEnvVars knob); endpoints derived from `<comp>.{name,service.port,ingress}` | `SD_TOKEN` |
| **Auth** (access-manager) | `PLUGIN_AUTH_*` | `auth.env` (via `globalValue`) | `global.auth.{enabled,host}` | `<comp>.configmap.PLUGIN_AUTH_*` override; caller passes `hostKey` (`PLUGIN_AUTH_HOST`\|`_ADDRESS`) | — |
| **Observability** (OTel collector) | `ENABLE_TELEMETRY`, `OTEL_*` | `otel.env` / `.envFlat` / `.podEnv` | `global.observability.{enabled,otlpEndpoint,deploymentEnvironment}` | per-service identity inline (`OTEL_RESOURCE_SERVICE_NAME/VERSION`, `OTEL_LIBRARY_NAME`) | — |
| **Object storage** (S3/SeaweedFS) | `OBJECT_STORAGE_*` | `objectStorage.value` (≥ lerian-common 1.5.0) | `global.objectStorage.<name>.{endpoint,region,bucket,disableSSL,usePathStyle}` | `<comp>.objectStorage.<name>.*` (dedicated) | `*_ACCESS_KEY_ID`, `*_SECRET_ACCESS_KEY` |
| **AWS IAM Roles Anywhere** | `AWS_*` (roles-anywhere) | `rolesAnywhere.{sidecar,volume,imdsEnv,podSecurityContext}` | — | `<comp>.aws.rolesAnywhere.{enabled,…}` | (cert material via volume) |
| **Inter-service** (sibling Lerian services) | `*_URL` / `*_HOST` of another service | `internalHost` / `internalURL` / `firstIngressHost` / `dependency.fullname` | (derived from names / SD) | derived; or a passthrough URL when SD is off | — |

Supporting (not a domain, but dependency-adjacent): `infraSecretRef` (reference an infra Secret).

Everything NOT in this table — rate-limit, outbox, swagger, cors, pagination, probes, timeouts,
retention, pool/client tuning, service-specific business knobs — is **escape-hatch passthrough**.

### Per-module datastores (N instances of one dependency)

A service may reach **several instances of the same dependency**, one per internal module. The
mask absorbs this with a sub-key — the same shape as object-storage's `<name>`:

- **midaz** (modular monolith) keys its native env by MODULE: two Postgres
  (`DB_ONBOARDING_*`, `DB_TRANSACTION_*`) and four Mongo
  (`MONGO_ONBOARDING_*` / `_TRANSACTION_*` / `_CRM_*` / `_FEES_*`).
- Each instance is its own mask block: `datastore.value` per `type` sub-key
  (`<comp>.datastores.postgresOnboarding.host`, `…mongoCrm.host`, …), one `datastore.value` call
  per (module, field). The operator still sees a typed knob per instance; the divergent native key
  (`DB_ONBOARDING_HOST`) is absorbed by the call's `nativeKey` and never leaks.

**Native-key naming is NOT uniform across the fleet — and that is fine, because the mask hides it.**
Services scaffolded from `go-boilerplate-ddd` + lib-commons share a de-facto standard
(`POSTGRES_*` / `REDIS_*` / `RABBITMQ_*` / `MULTI_TENANT_REDIS_*`, ~1:1 with the canonical field),
so the mask is nearly free there. The older core (midaz) uses the per-module `DB_<MODULE>_*` /
`MONGO_<MODULE>_*` scheme above. Either way the OPERATOR-facing knob (`datastores.postgres.host`)
is identical — the `nativeKey` param is where the per-app/per-module difference lives.

---

## Closed gap: object storage (S3 / SeaweedFS) — the worked example

`OBJECT_STORAGE_*` (endpoint / region / bucket / path-style) IS a dependency connection by NATURE
— how the app reaches an S3/SeaweedFS backend — but lerian-common originally had NO helper, so it
fell to the escape hatch. That was the tell that the vocabulary was incomplete, NOT a signal to
hand-roll a per-chart knob. It is the reference example of "extend the library, not the chart":

**Closed in lerian-common 1.5.0** — `lerian-common.objectStorage.value`, a mask modeled on
`datastore.value`:

- Env-wide: `global.objectStorage.<name>.{endpoint,region,bucket,disableSSL,usePathStyle}`
- Per-component dedicated: `<comp>.objectStorage.<name>.*`
- Precedence: native `configmap.<KEY>` › dedicated › shared › default (presence-based, false wins)
- Keyed by `<name>` for apps with multiple buckets (br-ccs: `ccs` / `fetcher` / `sta`)
- Masks only the non-secret fields; credentials (`*_ACCESS_KEY_ID`, `*_SECRET_ACCESS_KEY`) → the
  chart's Secret, fail-fast when the backend is used.

Charts on lerian-common < 1.5.0 keep object storage in the escape hatch (allowlisted) until they
bump the dependency and adopt the mask.

---

## Adding a new dependency domain (how the standard evolves)

1. Confirm it is a **dependency connection** (how the app reaches external infra / another
   service), not app config. If it's tuning/business config, it belongs in the escape hatch — stop.
2. Add the helper + `global.<domain>` contract to **lerian-common** (a doc'd `_<domain>.tpl` with a
   Usage header, backward-compatible/inert-when-unset, secrets via a companion `.secret` helper).
3. Add a row to this table.
4. Wire it in the consuming charts (the mechanical part); `coverage.py` then treats the prefix as a
   covered domain instead of a gap.

Never step 2-in-a-chart: a dependency knob defined in one chart's templates is a bespoke fork, not
the standard. The library is the single home for the vocabulary.
