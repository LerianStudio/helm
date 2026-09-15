# streaming-hub Helm chart

Deploys **streaming-hub** — the Lerian service that consumes
[`lib-streaming`](https://github.com/LerianStudio) CloudEvents from
Kafka/Redpanda and fans them out to per-tenant SaaS/BYOC subscribers.

This is a **multi-component** chart built on one image and one binary, selected
at runtime into a role via `STREAMING_HUB_ROLE`. There are **no** database,
broker, or OTEL subcharts — Kafka/Redpanda and PostgreSQL are shared external
infra, and OTEL is env-wired (see [External dependencies](#external-dependencies)).

---

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `secrets.STREAMING_HUB_POSTGRES_DSN` (the DSN carries the DB password); `secrets.STREAMING_HUB_KAFKA_SCRAM_PASSWORD` (when the broker requires SASL/SCRAM; the matching `configmap.STREAMING_HUB_KAFKA_SCRAM_USERNAME` is NOT a credential and lives in the ConfigMap); `secrets.STREAMING_HUB_DEV_KEK` (dev-only KEK material — the pointer `configmap.STREAMING_HUB_KEK_REF` names it); `secrets.STREAMING_HUB_REDIS_PASSWORD` (when the rate-limiter Redis/Valkey requires AUTH — the endpoint itself is not a credential and lives in `configmap.STREAMING_HUB_REDIS_ADDRESS`). Multi-tenant needs no extra secrets — the hub reads the tenant credentials from AWS Secrets Manager with its own IAM identity. All blank by default; the DSN is always emitted (an empty DSN fails the app fast at boot rather than failing the render). Provide sensitive values inline through a protected values source or set `streamingHub.useExistingSecret` + `streamingHub.existingSecretName` (the path GitOps uses, with a Vault-injected Secret).
- Dependency notes: **No bundled subcharts.** Kafka/Redpanda, PostgreSQL and Redis/Valkey are shared external infra — supply `configmap.STREAMING_HUB_KAFKA_BROKERS`, `secrets.STREAMING_HUB_POSTGRES_DSN` and, for control-plane rate limiting, `configmap.STREAMING_HUB_REDIS_ADDRESS` (see [Rate limiting](#rate-limiting)). OTEL is env-wired to a node-local collector (`HOST_IP:4317`, gated on `streamingHub.telemetry.enabled`) — there is no OTEL collector subchart. The optional `bootstrap-postgres` Job provisions the hub's single database when `global.externalPostgresDefinitions.enabled=true`.
- Migrations: the hub applies its schema **out of band** (the app never migrates itself). Enable the migration Job with `streamingHub.migrations.enabled=true` (default off). It is a PreSync hook that runs the stock `migrate/migrate` toolchain (image `ghcr.io/lerianstudio/streaming-hub-migrations`) BEFORE the app rolls out. The hook chain is **`bootstrap-postgres` (sync-wave -10, role+db) → `migration-secret` (-5, the DSN) → `migrations` Job (-1, the schema) → app Deployment (main Sync)**. The Job's only env is `STREAMING_HUB_POSTGRES_DSN` (from the migration-secret, or `migrations.existingSecretName` when `migrations.useExistingSecret=true`). Without it, ingest/dispatcher/partition workers crash on `relation "event_inbox"/"delivery_jobs" does not exist (42P01)`. **When `migrations.useExistingSecret=true`, the named secret must already exist in the namespace before the PreSync phase runs** — do not point it at the chart-managed application Secret (`streamingHub.existingSecretName` / inline `secrets.*`), which is created later in the main Sync phase and is therefore absent when the hook fires; the chart provisions its own PreSync `migration-secret` precisely to close that ordering gap.
- Production overrides: choose `streamingHub.mode` (`all` vs `split`); size per-role `replicaCount` / `autoscaling` / `resources` and the Postgres pool (`poolMaxOpenConns` / `poolMaxIdleConns`) honoring **Σ(replicas × poolMaxOpenConns) ≤ Postgres `max_connections`**; set `image.tag`, `ingress`, and the secrets (inline or `useExistingSecret`).
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

---

## Installing the Chart

```bash
helm install streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version <version> -n streaming-hub --create-namespace
```

With a custom values file:

```bash
helm install streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version <version> -n streaming-hub -f my-values.yaml
```

The chart is mirrored to `oci://ghcr.io/lerianstudio/streaming-hub-helm` as well.

## Uninstalling the Chart

```bash
helm uninstall streaming-hub -n streaming-hub
```

---

## The `mode` switch (read this first)

`streamingHub.mode` decides the topology. It is an **either/or**:

| `mode`  | Renders | `STREAMING_HUB_ROLE` | When |
|---------|---------|----------------------|------|
| `all` (default) | ONE Deployment + Service (+ HPA/PDB) | `all` | Single co-resident deployment. The dev-st target. Byte-equivalent to the historical single binary. |
| `split` | TWO Deployments + Services (ingest + delivery), each with its own HPA/PDB | `ingest` / `delivery` | Ingest and delivery scaled independently as N + M replicas. |

### > **DOUBLE-CONSUME HAZARD — the load-bearing rule**

> **NEVER run a `mode: all` release AND a `mode: split` release against the same
> Kafka/Redpanda cluster.** All three roles (`all`, `ingest`) join the **one**
> ingest consumer group. An `all` pod and an `ingest` pod consuming together
> means **every event is double-consumed and double-delivered.** The `mode`
> switch enforces either/or within a single release — do not defeat it by
> deploying two releases that overlap.

### Worked example — `mode: all` (dev-st)

```yaml
streamingHub:
  mode: all
  all:
    replicaCount: 1
    poolMaxOpenConns: 25   # role=all holds both planes' connections
    poolMaxIdleConns: 12
```

Renders: `streaming-hub-all` Deployment + `streaming-hub-all` Service, plus the
shared `streaming-hub` ConfigMap + Secret + ServiceAccount. One consumer-group
member set — no double-consume possible.

### Worked example — `mode: split` (independent scaling)

```yaml
streamingHub:
  mode: split
  ingest:
    replicaCount: 3
    poolMaxOpenConns: 8    # consume-poll + inbox tx + partition-cron
    poolMaxIdleConns: 4
    autoscaling: { enabled: true, minReplicas: 3, maxReplicas: 4 }
  delivery:
    replicaCount: 2
    poolMaxOpenConns: 16   # 8 dispatch workers + reclaim + dlq + delivery /readyz
    poolMaxIdleConns: 10
    autoscaling: { enabled: true, minReplicas: 2, maxReplicas: 4 }
```

Renders `streaming-hub-ingest` and `streaming-hub-delivery` Deployments +
Services + HPAs, sharing the one ConfigMap + Secret. Each Deployment gets its
own `STREAMING_HUB_ROLE` and pool sizing as **explicit per-Deployment env**
(which wins over the shared `envFrom`).

---

## Connection-budget invariant

streaming-hub owns **ONE** shared PostgreSQL database. Every open connection on
every pod of every role draws from that single `max_connections` budget.

> **Σ over all running pods of `(replicas × poolMaxOpenConns)` + headroom ≤ PostgreSQL `max_connections`.**
> Under HPA, use `maxReplicas` (not `replicaCount`) in the sum.

Worked example (`max_connections = 100`, `mode: split`):

| Role | replicas | poolMaxOpenConns | connections |
|------|----------|------------------|-------------|
| ingest | 3 | 8 | 24 |
| delivery | 4 | 16 | 64 |
| **total** | | | **88** (leaves 12 for admin/migrations) ✅ |

Adding an `all` pod (25) → `88 + 25 = 113 > 100` ❌. The `mode` either/or already
forbids that combination; the budget math is why it also matters operationally.
See `streaming-hub/.env.reference` (`STREAMING_HUB_POSTGRES_MAX_OPEN_CONNS`) for
the per-role rationale (all 25/12, ingest 8/4, delivery 16/10).

---

## Health, drain, and termination

- **Probes** (verified against the hub source / Dockerfile, on the `http` port `8080`):
  - `livenessProbe`: `GET /healthz` — stays `200` throughout drain.
  - `readinessProbe`: `GET /readyz` — flips `NotReady` (503) **first** on SIGTERM so the endpoints controller drains the pod from the Service.
- **No `preStop` hook.** The hub **self-drains on SIGTERM**: the exec-form
  ENTRYPOINT delivers SIGTERM straight to PID 1, and the lib-commons Launcher
  runs the HTTP → consumer → dispatcher teardown.
- **`terminationGracePeriodSeconds` defaults to `80` — the hub's derived SIGTERM
  drain ceiling — and MUST stay at or above it.** At the shipped
  `STREAMING_HUB_SHUTDOWN_TIMEOUT=30s` + `STREAMING_HUB_PRE_STOP_DRAIN_TIMEOUT=5s`
  the ceiling is `30s` (HTTP) + `5s` (consumer final-commit) + `30s` (dispatcher,
  `min(ShutdownTimeout, 55s)`) + `10s` slack = `75s`, plus the `5s` pre-stop wait
  = **`80s`**. If you tune those knobs up, recompute and raise this knob to match,
  or the orchestrator SIGKILLs a still-draining replica (risking a duplicate
  delivery). See `.env.reference`.

---

## Secrets sourcing

Two mutually-exclusive paths:

| `useExistingSecret` | Behavior |
|---------------------|----------|
| `false` (default) | The chart renders `templates/secrets.yaml` from `streamingHub.secrets` (base64-encoded). `STREAMING_HUB_POSTGRES_DSN` is ALWAYS emitted (even empty) so a bare `helm template` succeeds; an empty DSN fails the app fast at boot. Empty optional keys are skipped. |
| `true` | **No** Secret is rendered. Deployments reference `existingSecretName`. This is the **gitops/Vault path** (an external secret is projected into the named Secret) and is the production default. **Key contract:** the named Secret MUST carry `STREAMING_HUB_POSTGRES_DSN` — each Deployment pins that key via an explicit `secretKeyRef`, so a Secret missing it fails container creation (`CreateContainerConfigError`, "couldn't find key") instead of CrashLooping the app. |

Sensitive keys (all in `streamingHub.secrets`, all default `""`):
`STREAMING_HUB_POSTGRES_DSN`, `STREAMING_HUB_KAFKA_CA_CERT`,
`STREAMING_HUB_DEV_KEK` (dev only) — these three are ALWAYS emitted (even empty)
so a bare render succeeds and their non-credential-shaped names are still counted
by the coverage check; plus `STREAMING_HUB_KAFKA_SCRAM_PASSWORD`,
`STREAMING_HUB_REDIS_PASSWORD` (rate-limiter AUTH; may legitimately stay empty)
and `POSTGRES_PASSWORD` (migration-toolchain parity; no in-cluster consumer), all
emit-when-set. Not secrets (live in the ConfigMap): `STREAMING_HUB_KAFKA_SCRAM_USERNAME`
(username, not a credential), `STREAMING_HUB_KEK_REF` (a POINTER — the NAME of
the env var holding the KEK material) and `STREAMING_HUB_REDIS_ADDRESS` /
`STREAMING_HUB_REDIS_TLS` / `STREAMING_HUB_REDIS_CA_CERT` (an endpoint, a flag,
and a public CA cert — the credential travels in its own key).

---

## External dependencies

This chart provisions **none** of the following — they live outside it:

- **Kafka / Redpanda** — the CloudEvents bus the hub consumes. Point
  `STREAMING_HUB_KAFKA_BROKERS` at the cluster; supply SASL/SCRAM creds via the
  Secret when `STREAMING_HUB_KAFKA_SCRAM_MECHANISM` is set.
- **PostgreSQL** — the single hub-owned database (`tenant_id` is a column, not a
  per-tenant DB). Either point `STREAMING_HUB_POSTGRES_DSN` at a pre-provisioned
  managed host, **or** enable `global.externalPostgresDefinitions.enabled` to run
  the bootstrap Job that creates the hub's one DB + role on a shared host.
- **Redis / Valkey** — the store behind the control plane's per-tenant rate
  limiting (`lib-commons` ratelimit, fixed window). Point
  `configmap.STREAMING_HUB_REDIS_ADDRESS` at it (`host:port`) and put its
  password, if it takes one, in `secrets.STREAMING_HUB_REDIS_PASSWORD`. See
  [Rate limiting](#rate-limiting) — **the chart ships no default address, so an
  unconfigured control plane enforces nothing.**
- **OTEL collector** — **not** a subchart (deliberate; declaring it would force
  an OCI pull on `helm lint`/`template`). When `streamingHub.telemetry.enabled=true`
  (a chart-level toggle, not an app env var), the Deployment injects `HOST_IP` via
  the downward API and sets `OTEL_EXPORTER_OTLP_ENDPOINT=$(HOST_IP):4317`
  (node-local DaemonSet collector).

---

## Rate limiting

> **Ships ahead of the app.** No released streaming-hub image reads
> `STREAMING_HUB_REDIS_ADDRESS` yet — on `appVersion 1.7.0` these keys are inert.
> The chart carries them so the connection is configurable the day the app lands.
> Until then, nothing here changes runtime behavior.

The control plane rate-limits its HTTP API through the `lib-commons` three-tier
contract, backed by **Redis/Valkey**, which this chart does not provision. The
whole contract is rendered by `lerian-common.rateLimit.env`, so streaming-hub
exposes the same keys, defaults and productized knobs as every other Lerian
product. The ConfigMap is shared by all roles, so the keys reach every pod.

**The connection** (`streamingHub.datastores.redis`, or `global.datastores.redis`
for the shared tier; `configmap.<KEY>` overrides either):

| Key | Mask field | Default | What it does |
|-----|-----------|---------|--------------|
| `STREAMING_HUB_REDIS_ADDRESS` | `host` | `""` | Full `host:port`. **Required for enforcement.** |
| `STREAMING_HUB_REDIS_TLS` | `tls` | `"true"` | TLS to Redis. |
| `STREAMING_HUB_REDIS_CA_CERT` | `caCert` | `""` | Base64 PEM CA bundle. Empty trusts the container's system roots. |
| `STREAMING_HUB_REDIS_PASSWORD` | — (`secrets`) | `""` | AUTH password. Emit-when-set — leave empty for an instance that takes none. |

**The limits** (`streamingHub.rateLimit.<field>`; `configmap.<KEY>` overrides):

| Key | Field | Default |
|-----|-------|---------|
| `RATE_LIMIT_ENABLED` | `enabled` | `"true"` |
| `ALLOW_RATELIMIT_DISABLED` | `allowDisabled` | `""` |
| `ALLOW_RATELIMIT_FAIL_OPEN` | `allowFailOpen` | `"true"` (chart sets it — see below) |
| `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_SEC` | `max` / `windowSec` | `500` / `60` |
| `AGGRESSIVE_RATE_LIMIT_MAX` / `..._WINDOW_SEC` | `aggressiveMax` / `aggressiveWindowSec` | `100` / `60` |
| `RELAXED_RATE_LIMIT_MAX` / `..._WINDOW_SEC` | `relaxedMax` / `relaxedWindowSec` | `1000` / `60` |
| `RATE_LIMIT_REDIS_TIMEOUT_MS` | `redisTimeoutMs` | `500` |

> **`ALLOW_RATELIMIT_FAIL_OPEN` is a security bypass, and `lib-commons` says so.**
> The library forbids fail-open by default and, when permitted, logs
> `security bypass active` for the life of the process. This chart sets
> `streamingHub.rateLimit.allowFailOpen: "true"` because the hub's intended
> posture is that a Redis **outage** degrades enforcement rather than taking the
> control plane down. Unset it for fail-closed, where an unreachable limiter
> refuses the request.

> **Three reasonable defaults compose into silent allow-all.** An empty
> `STREAMING_HUB_REDIS_ADDRESS` makes `lib-commons` build a pass-through limiter;
> so does `TLS="true"` against a private-CA Redis with no `CA_CERT`, because the
> handshake fails and fail-open then allows everything. Neither fails the render
> nor crashes the pod. If an environment must actually enforce a limit, set the
> address, and set the CA when the chain is private.

This Redis is **not** the multi-tenant registry. The hub's tenancy model reads
tenant credentials from AWS Secrets Manager, so `MULTI_TENANT_REDIS_*` stays
unset — the two connections are independent, and enabling rate limiting does not
turn on a tenant-lifecycle bus.

`STREAMING_HUB_PULL_RATE` / `STREAMING_HUB_PULL_BURST` are **unrelated** and
unchanged: they are the app's own inbound pull gate on `GET /v1/events`, not part
of this contract. Keep tuning them as a pair.

---

## Top-level values

| Key | Default | Description |
|-----|---------|-------------|
| `streamingHub.mode` | `all` | Topology switch: `all` \| `split`. Schema-enforced enum. |
| `streamingHub.image.repository` | `ghcr.io/lerianstudio/streaming-hub` | Image repo. |
| `streamingHub.image.tag` | `""` | Empty falls back to `Chart.appVersion`. |
| `streamingHub.image.pullPolicy` | `IfNotPresent` | |
| `streamingHub.imagePullSecrets` | `[{name: ghcr-credential}]` | Private registry pull secrets. |
| `streamingHub.service.type` | `ClusterIP` | Lerian convention (Ingress fronts external). |
| `streamingHub.service.port` | `8080` | Control-plane HTTP port. |
| `streamingHub.ingress.enabled` | `false` | Control-plane API ingress (opt-in per env). |
| `streamingHub.serviceAccount.create` | `true` | |
| `streamingHub.terminationGracePeriodSeconds` | `80` | Defaults to the ~80s drain ceiling; keep at or above it. |
| `streamingHub.securityContext` | nonroot 65532, drop ALL, RO rootfs, RuntimeDefault | Distroless:nonroot. |
| `streamingHub.useExistingSecret` | `false` | `true` = Vault/gitops path. |
| `streamingHub.existingSecretName` | `""` | Required when `useExistingSecret`. |
| `streamingHub.configmap` | `{}` | Non-sensitive env override hatch (defaults live in `templates/configmap.yaml`). `configmap.<KEY>` overrides an enumerated (allowlisted) key — the schema `propertyNames.enum` rejects a key outside the allowlist; use `extraEnvVars` to inject one that is not enumerated. See `README.params.md`. |
| `streamingHub.datastores` | `{}` | Dedicated datastore masks: `postgres` (host/port/user/name/ssl) and `redis` (host carries `host:port`, tls, caCert). `global.datastores.<type>` is the shared tier. |
| `streamingHub.rateLimit` | `{allowFailOpen: "true"}` | `lib-commons` rate-limit contract (10 keys) via `lerian-common.rateLimit.env`. See [Rate limiting](#rate-limiting). |
| `streamingHub.extraEnvVars` | `{}` | Per-Deployment env hatch (key → value map). Never credentials. |
| `streamingHub.secrets` | (all `""`) | Shared sensitive env. DSN always emitted; other empty values skipped. |
| `streamingHub.secrets.STREAMING_HUB_REDIS_PASSWORD` | `""` | Rate-limiter Redis AUTH password. Emit-when-set; may stay empty. |
| `streamingHub.<role>.replicaCount` | `1` | Per role: `all` / `ingest` / `delivery`. |
| `streamingHub.<role>.poolMaxOpenConns` | all `25` / ingest `8` / delivery `16` | Postgres pool (connection-budget invariant). |
| `streamingHub.<role>.poolMaxIdleConns` | all `12` / ingest `4` / delivery `10` | |
| `streamingHub.<role>.autoscaling.enabled` | `false` | HPA per role (`autoscaling/v2`, CPU+memory). |
| `streamingHub.<role>.pdb.enabled` | `false` | PodDisruptionBudget per role (`policy/v1`). |
| `global.externalPostgresDefinitions.enabled` | `false` | Bootstrap Job for the hub's one DB/role (PreSync, sync-wave -10). |
| `streamingHub.migrations.enabled` | `false` | Out-of-band schema migration Job (PreSync, sync-wave -1). |
| `streamingHub.migrations.image.repository` | `ghcr.io/lerianstudio/streaming-hub-migrations` | Migrations image (`FROM migrate/migrate` + the hub's `migrations/`). |
| `streamingHub.migrations.image.tag` | `""` | Empty falls back to `streamingHub.image.tag`, then `Chart.appVersion`. |
| `streamingHub.migrations.image.digest` | `""` | Pin by digest; wins over tag. |
| `streamingHub.migrations.useExistingSecret` | `false` | `true` = Job reads `STREAMING_HUB_POSTGRES_DSN` from `existingSecretName`. |
| `streamingHub.migrations.existingSecretName` | `""` | Required when `migrations.useExistingSecret`. Must already exist before the PreSync phase — not the main-Sync app Secret. |
| `streamingHub.migrations.backoffLimit` | `3` | Job retry cap. |
| `streamingHub.migrations.activeDeadlineSeconds` | `600` | Job wall-clock cap. |
| `streamingHub.migrations.ttlSecondsAfterFinished` | `600` | Finished-Job GC TTL. |

For the full env contract (defaults, required-in-SaaS markers, the F4 tenant
caution, KEK source vars), see `streaming-hub/.env.reference`.

See [`docs/TOPOLOGY.md`](docs/TOPOLOGY.md) for the role model in depth.
