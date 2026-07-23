# br-slc Helm chart

Internal Helm chart for the **br-slc monolith** (Sistema de Liquidação
Centralizada — SLC). BYOC single-tenant deployment: **ClusterIP-only**
Service, **no Ingress**. Postgres/Redis/RabbitMQ are external, client-managed
dependencies in BYOC — this chart does not deploy them.

## Chart Contract

- Chart type: `single-service` — one Deployment (the monolith) with mandatory
  same-pod `slc-signer` + `aslc-xsd-validator` sidecars and a conditional
  `mqbridge` sidecar, plus a detached migrations Job.
- Required secrets: **None for a default render.** For a real install provide
  the app Secret keys (`POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `WEBHOOK_API_KEY`,
  `WEBHOOK_HMAC_SECRET`, and — only when the corresponding integration is
  enabled — `RABBITMQ_DEFAULT_PASS`, `AWS_SECRET_ACCESS_KEY`,
  `AWS_SESSION_TOKEN`) via `secrets.data` (`secrets.create=true`) or an
  operator-managed `secrets.existingSecretName`. The signing-key material
  (`SIGNER_SOFTKEY_PFX_PASSPHRASE`, `SIGNER_VAULT_TOKEN`, `SIGNER_PKCS11_PIN`,
  awskms creds) lives ONLY in the signer Secret (`signer.secrets.*`, ADR-9
  custody) and is never readable by the app container. The migration Job reads
  `POSTGRES_PASSWORD` from a dedicated PreSync Secret (or
  `migrations.existingSecretName`). No credential is ever placed in a ConfigMap.
- Dependency notes: No bundled subcharts. Postgres, Redis and (optional)
  RabbitMQ are EXTERNAL and pre-provisioned in BYOC — the chart only takes
  connection config (`configmap.data.POSTGRES_HOST` / `REDIS_HOST` / RabbitMQ
  host). Streaming (Kafka/Redpanda) is external and referenced only when
  `STREAMING_ENABLED=true`. The `mqbridge` sidecar links the external IBM
  MQ/RSFN broker (amd64-only) and is off by default.
- Production overrides: Set `image.tag` (defaults to `Chart.appVersion`);
  `configmap.data.POSTGRES_HOST` / `REDIS_HOST`; `configmap.data.PLUGIN_AUTH_HOST`
  (auth is on by default and **fails closed at boot** until this is set);
  `configmap.data.CORS_ALLOWED_ORIGINS` (empty deny-all by default); the app +
  signer Secrets; and, for the IF Domicílio role, `mqbridge.enabled=true` with
  `RSFN_CONSUMER_TRANSPORT=mq` (forces `replicaCount=1` + an amd64 node pin).
  `secrets.useExistingSecret`-style `create`/`existingSecretName` are supported
  for the app, signer, mqbridge and migration Secrets.
- Source/license: Source is in `github.com/LerianStudio/helm`; chart license is
  Apache-2.0. The `br-slc` service source is `github.com/LerianStudio/br-slc`.

## Topology (ADR-12: same-pod sidecars)

This chart ships **one Deployment**. Its pod runs **three mandatory
containers**, plus a **fourth conditional container** (`mqbridge`) that is
rendered only when `mqbridge.enabled=true`:

| Container | Port | Role | Reached via | Rendered |
|---|---|---|---|---|
| `br-slc` | 4111 | the monolith | — | always |
| `slc-signer` | 9101 | ICP-Brasil signing / crypto+credential boundary (ADR-9) | `SIGNER_URL=http://localhost:9101` | always |
| `aslc-xsd-validator` | 9091 | XSD validation (fail-closed for outbound ASLC) | `XSD_VALIDATOR_URL=http://localhost:9091` | always |
| `mqbridge` | 9121 | inbound IBM MQ/RSFN consumer (cards channel) | `MQ_BRIDGE_URL=http://localhost:9121` | only when `mqbridge.enabled=true` |

The signer and validator are **mandatory same-pod containers** (ADR-12,
"sidecar no mesmo pod, localhost") — no enable toggle. The app talks to them
over **localhost**, not cluster DNS. **Shared fate**: the pod only reaches
`Ready` when every container that defines a readiness probe passes it, which
removes the "app Ready but validator absent" window. The `mqbridge` container
deliberately has **no** readiness probe (see below), so it does not
independently gate pod readiness. Each container keeps its own hardened
`securityContext` and its own `/tmp` `emptyDir`.

**Custody (ADR-9):** the signing-key material (softkey PFX + passphrase, HSM
PIN, Vault token) is mounted/injected **only** on the `slc-signer` container
(its own `signer.secrets` Secret + `signer.softkeySecret` volume) — never on
the app, validator, or mqbridge container.

### Conditional `mqbridge` container (Decisão 21)

The inbound **`mqbridge`** (IBM MQ/RSFN consumer of the cards channel) is a
**same-pod CONDITIONAL** container — `mqbridge.enabled: false` by default. A
BYOC client flips it on when the role is **IF Domicílio** with
`RSFN_CONSUMER_TRANSPORT=mq`; a credenciadora-only tenant never carries it.
It was previously a separate, gated Deployment (its own `br-slc-mq-bridge`
chart) — Decisão 21 moved it into this pod so the app reaches it over
**localhost:9121** (resolving the drain/ack affinity risk by construction:
same pod, same localhost).

When (and only when) `mqbridge.enabled=true`:

- The pod gains the `mqbridge` container (writable `/var/mqm` rootfs +
  read-only keystore mount when `mqbridge.keystoreSecret.enabled`), plus its
  own `<fullname>-mqbridge` ConfigMap and (when
  `mqbridge.secrets.create=true`) `<fullname>-mqbridge-secrets` Secret.
- The **whole pod gets an amd64 node pin**
  (`nodeSelector: kubernetes.io/arch: amd64`) — the IBM MQ Redistributable
  Client (libmqm/GSKit) it links is published for Linux x86_64 only. The pin
  is absent when the bridge is disabled.
- The mqbridge keystore (GSKit `.kdb/.sth/.rdb`) is mounted **only** on this
  container, never on the app/signer/validator.
- **`replicaCount` is hard-capped to 1.** The bridge holds per-process state
  (`/v1/drain` mints a `deliveryRef→conn`; `/v1/ack` must land in the SAME
  process), and its mTLS identity is per-process (`MQSCO.KeyRepository` from
  env `MQSSLKEYR`), so 1 process = 1 RSFN participant. As a same-pod container
  the monolith `replicaCount` governs the consumer count — the render **fails**
  with a guard message if `mqbridge.enabled` and `replicaCount != 1`.

> **Enabling `mqbridge` couples app scale to the consumer.** If a client needs
> app HA (multiple replicas) **and** MQ inbound simultaneously, that signals
> the separate-Deployment / **Fase 7** multi-tenant consumer-manager path
> (Decisão 21) — escalate as a DOUBT, do not force multi-replica with the
> bridge enabled.

## Optional `mock-nuclea` Deployment (ADR-23) — DEV/HML/BYOC-TEST ONLY

`mock-nuclea` is the Núclea clearing-house **simulator**. It ships in this chart
as a **separate, optional Deployment** (its own pod + `ClusterIP` Service,
`mockNuclea.enabled: false` by default) — **not** a same-pod sidecar (team
decision 2026-07-23): keeping it a distinct pod keeps the app pod small and its
scaling independent, and toggling the fixture never touches the app pod. It lets
a client validate the **real BYOC deploy flow** (including the signed credit
round-trip) before they have Núclea access; when they do, it is a simple repoint
(disable the mock, point the URLs at Núclea).

> **NEVER enabled in production/BYOC-prod.** The Deployment renders a hard `fail`
> guard when `mockNuclea.enabled=true` under `ENV_NAME=production` or
> `DEPLOYMENT_MODE=saas` (ADR-23; mirrors the app's own
> `validateDispatchDevRecipientConfig`). Since the chart's base `ENV_NAME`
> defaults to `production`, enabling the fixture **requires** an overlay that
> also sets a non-prod `ENV_NAME` (e.g. `sandbox`/`staging`).
>
> **Guard premise (know this before relying on it):** it keys off the chart's
> **declared** `configmap.data.ENV_NAME` / `configmap.data.DEPLOYMENT_MODE` — the
> same values the chart feeds the app — and matches the **exact** strings
> `production` / `saas`, mirroring the app's `isProductionOrSaaS()`. Two
> consequences: (1) it does not inspect an `ENV_NAME` sourced outside the chart
> (e.g. an external Secret); because the base default is `production` this stays
> fail-safe, but keep `configmap.data.*` authoritative. (2) `DEPLOYMENT_MODE`
> defaults to `byoc`, so a **BYOC-prod** deploy is caught only by the
> `ENV_NAME=production` half — a real production tier (BYOC included) **must**
> carry `ENV_NAME=production` for both this guard and the app's own guard to
> engage. Never run a prod tier under a non-`production` `ENV_NAME`.

When `mockNuclea.enabled=true`:

- A separate `br-slc-mock-nuclea` Deployment + `ClusterIP` Service is rendered.
  Point the app at it in the overlay: `NUCLEA_REST_BASE_URL` /
  `RSFN_CONSUMER_BASE_URL=http://br-slc-mock-nuclea:9190` (cluster DNS).
- **SPB key material is provisioned EXTERNALLY** (the point of this fixture — it
  exercises the real flow where the client sets the public/private material). All
  four files must come from ONE self-consistent set (mint one with the mock
  image's `-gen`), distributed to the three consumers:
  | Consumer | Needs | Provisioned via |
  |---|---|---|
  | `mock-nuclea` (this pod) | `recipient.key` (unwrap C14) + `emitter.crt` (verify C15) | `mockNuclea.spbKeysSecret` (Secret mounted read-only) |
  | `slc-signer` (app pod) | `signer.pfx` (sign C15) | `signer.softkeySecret` (existing) |
  | `br-slc` app (app pod) | `recipient.crt` (encrypt C14) | `extraVolumes`/`extraVolumeMounts` + `DISPATCH_DEV_RECIPIENT_CERT_PATH` (overlay) |
- `mockNuclea.spbKeysSecret.enabled: false` leaves the mock a bare
  connectivity/health fixture (no keys, no signed round-trip).

### Provisioning the SPB key set (signed round-trip runbook)

> ⚠️ The four files **must all come from a SINGLE `-gen` run**. `-gen` mints fresh
> RSA keys on every invocation, and each file is independently valid, so mixing
> files from different runs **boots green and only fails at dispatch time** with
> an opaque `verify C15 signature failed` / symmetric-key-unwrap error in the
> **mock's** logs. Mint once, build all three Secrets from that one output dir,
> and rotate them together.

**1. Mint the set once.** The image is distroless (no shell, non-root uid 65532),
so run `-gen` as a one-shot container writing to a host dir the uid can write:

```bash
mkdir -p spb-keys
# The container runs as uid 65532 and writes the four files into the bind mount,
# so the host dir must be writable by that uid (throwaway dev keys → world-writable
# is fine). Without this, `-gen` fails with permission-denied on /spb-keys.
chmod 777 spb-keys
docker run --rm -u 65532:65532 -v "$PWD/spb-keys:/spb-keys" \
  -e SIGNER_SOFTKEY_PFX_PASSPHRASE="$PFX_PASS" \
  ghcr.io/lerianstudio/br-slc-mock-nuclea:<tag> -gen -out /spb-keys
# → spb-keys/{recipient.key, recipient.crt, emitter.crt, signer.pfx}
```

**2. Build the three Secrets from that ONE dir** (exact key names the chart expects):

```bash
# All three Secrets MUST live in the same namespace as the br-slc release — the
# chart renders the pods into `global.namespace` (namespaceOverride, else the
# install namespace), so a Secret in any other namespace simply won't mount.
NS=<your br-slc release namespace>   # = namespaceOverride if set, else the -n/--namespace you pass to `helm install`
kubectl create secret generic br-slc-mock-spb-keys --namespace "$NS" \
  --from-file=recipient.key=spb-keys/recipient.key \
  --from-file=emitter.crt=spb-keys/emitter.crt      # → mockNuclea.spbKeysSecret
kubectl create secret generic br-slc-signer-softkey --namespace "$NS" \
  --from-file=signer.pfx=spb-keys/signer.pfx        # → signer.softkeySecret
kubectl create secret generic br-slc-dev-recipient --namespace "$NS" \
  --from-file=recipient.crt=spb-keys/recipient.crt  # → app, via extraVolumes
```

**3. Wire the overlay** (all under a non-prod `ENV_NAME`, or the guard blocks the render):

```yaml
mockNuclea:
  enabled: true
  spbKeysSecret: { enabled: true, secretName: br-slc-mock-spb-keys }
signer:
  softkeySecret: { enabled: true, secretName: br-slc-signer-softkey }
  secrets:
    data:
      # ⚠️ MUST equal the $PFX_PASS used at `-gen` time. Leaving it empty does NOT
      # fall back to "test-passphrase" (that default is only inside `-gen`); an
      # empty value here fails the PKCS#12 decode and the signer never gets Ready.
      SIGNER_SOFTKEY_PFX_PASSPHRASE: "<same as $PFX_PASS>"
extraVolumes:
  - name: dev-recipient
    secret: { secretName: br-slc-dev-recipient }
extraVolumeMounts:
  - name: dev-recipient
    mountPath: /dev-recipient
    readOnly: true
configmap:
  data:
    # Path MUST equal the mount above + the file name. The app needs a CERTIFICATE
    # PEM here (not a bare public key). It fails closed at boot if unreadable.
    DISPATCH_DEV_RECIPIENT_CERT_PATH: /dev-recipient/recipient.crt
```

Disable everything (or just `spbKeysSecret`) to fall back to a bare
connectivity/health mock with no signed round-trip.

## Install

```bash
helm lint charts/br-slc
helm template my-release charts/br-slc

# Real install — you MUST override at least:
#   - configmap.data.POSTGRES_HOST / REDIS_HOST (external, client-managed)
#   - configmap.data.PLUGIN_AUTH_HOST (required: PLUGIN_AUTH_ENABLED=true by default)
#   - configmap.data.CORS_ALLOWED_ORIGINS (empty/deny-all by default)
#   - secrets.* (see "Secrets" below)
helm install my-release charts/br-slc -f my-values.yaml
```

No `values-<env>.yaml` files live in this chart — per-environment overrides
(dev/hml relaxations, SaaS-only knobs) belong in the beleriand gitops overlays
(Task 6.0.6), not here.

## Secrets

Secrets are split by custody boundary (ADR-9) into **two** Secrets so the
signing-key material is never readable by the app container.

### App container Secret (`secrets.*`)

Seven env vars, injected via `secretKeyRef` into both the app container and the
migration Job:

| Env var | Purpose |
|---|---|
| `POSTGRES_PASSWORD` | primary Postgres password |
| `REDIS_PASSWORD` | Redis/Valkey password |
| `WEBHOOK_API_KEY` | client webhook API-key header (BYOC `direct` provider) |
| `WEBHOOK_HMAC_SECRET` | client webhook HMAC signing secret |
| `RABBITMQ_DEFAULT_PASS` | RabbitMQ password (inert while `RABBITMQ_ENABLED=false`, this base's default; only meaningful if an overlay enables RabbitMQ for real) |
| `AWS_SECRET_ACCESS_KEY` | AWS static credential for the app's M2M provider (prefer IRSA instead — keep empty) |
| `AWS_SESSION_TOKEN` | AWS static credential (prefer IRSA instead — keep empty) |

### Signer container Secret (`signer.secrets.*`, ADR-9 custody)

Five key/credential-material env vars injected **only** into the `slc-signer`
container (never the app):

| Env var | Purpose |
|---|---|
| `SIGNER_SOFTKEY_PFX_PASSPHRASE` | decrypts the softkey PFX (dev/softkey custody; production should use awskms/pkcs11/vault) |
| `AWS_SECRET_ACCESS_KEY` | awskms adapter static credential (prefer IRSA — keep empty) |
| `AWS_SESSION_TOKEN` | awskms adapter static credential (prefer IRSA — keep empty) |
| `SIGNER_VAULT_TOKEN` | Vault transit auth token (only when `SIGNER_VAULT_ADDR` is set) |
| `SIGNER_PKCS11_PIN` | HSM/SoftHSM2 token PIN (only when a pkcs11 token is configured) |

The softkey PFX **file** itself is mounted read-only onto the signer container
from an externally managed Secret via `signer.softkeySecret.*` (never baked
into the image or `values.yaml`).

Each Secret has the same two modes (`secrets.create` / `signer.secrets.create`):

- **`create: false` (default, recommended for BYOC).** The client manages the
  Secret out-of-band (their own manifest, External Secrets Operator, Vault
  injector, etc.) and sets `existingSecretName` to its name. That Secret
  **must** expose the same keys listed above.
- **`create: true`.** This chart creates the Secret from `*.data` — populate
  those values via `--set-string`/`-f` at install time (a values override file
  kept out of version control), never by committing real values to this
  chart's `values.yaml`.

`AWS_ACCESS_KEY_ID` stays in the ConfigMap (the non-secret half of a static
credential pair, analogous to a `*_USER` var) and is deliberately **not**
secret-managed: it must stay empty in production/BYOC. Use IRSA (EKS) or an
equivalent workload identity via `serviceAccount.annotations` instead — the
AWS SDK's default credential chain picks that up with no env vars at all.

## Env var coverage

All active vars from `config/.env.example` are covered. `config/.env.example`
is the shared compose-stack env file, so it also carries the signer/validator
vars — under this chart's same-pod consolidation those live in the
`signer.configmap.data` / `signer.secrets.data` / `xsdValidator.configmap.data`
subsections (see `values.yaml`), NOT in the app's ConfigMap/Secret. The app
container's own surface is the app `configmap.data` (non-secret) plus the
7-key app Secret (Task 6.0.2 reconciliation moved `RABBITMQ_DEFAULT_PASS`,
`AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` from the ConfigMap into the
Secret; the ADR-12 consolidation moved `SIGNER_SOFTKEY_PFX_PASSPHRASE` out of
the app Secret into `signer.secrets.data` per the ADR-9 custody boundary — see
"Flagged deviations" below). Two additional vars are surfaced beyond
`.env.example`'s app surface because this chart's hardened defaults require
them (see the header comment above `configmap.data` in `values.yaml` for the
full rationale):

| Var | Why it's here even though not "active" in `.env.example` |
|---|---|
| `DEPLOYMENT_MODE` | Read by `config_validation.go`/`systemplane.go`/TLS enforcement; `.env.example` has no active line for it. Defaults to `byoc`. |
| `PLUGIN_AUTH_HOST` | `.env.example` only has it commented out (auth defaults off there). This chart's base flips `PLUGIN_AUTH_ENABLED=true`, and `config_validation.go`'s `validateAuthConfig` **fails boot** if `PLUGIN_AUTH_HOST` is empty when auth is enabled. **This chart intentionally fails closed at boot until you set the real Access Manager URL** — that is deliberate hardening, not a bug, but you must set it before first deploy. |

Every one of the 156 was checked mechanically against
`config/.env.example` (grep for uncommented `KEY=` lines) and cross-referenced
against the `env:"..."` struct tags in `internal/bootstrap/config.go`. See the
`ring:helm` execution report for the full 156-row source table.

### Flagged deviations from `.env.example`'s dev defaults

This base intentionally hardens a handful of values beyond mirroring
`.env.example` (which is tuned for local/dev, not BYOC production):

- `ENV_NAME=production` (was `development`) — activates
  `config_validation.go`'s production hardening gate.
- `ALLOW_INSECURE_TLS` / `ALLOW_CORS_WILDCARD` / `ALLOW_RATELIMIT_FAIL_OPEN` =
  `false` (all were `true` in `.env.example`, which is dev/CI-only — production
  boot is rejected if `ALLOW_CORS_WILDCARD` or `ALLOW_RATELIMIT_FAIL_OPEN` is
  true anyway).
- `POSTGRES_SSLMODE=require` (was `disable`) — production boot is **rejected**
  if this is `disable` (`config_validation.go`). Tighten to `verify-full` once
  the client's Postgres cert chain is known.
- `PLUGIN_AUTH_ENABLED=true` (was `false`) — real auth in BYOC; see
  `PLUGIN_AUTH_HOST` note above.
- `ENABLE_TELEMETRY=true` (was `false`) — production observability on by
  default; `OTEL_EXPORTER_OTLP_ENDPOINT` assumes an in-cluster
  `otel-collector-lerian` release — reconcile the real name per environment.
- `RABBITMQ_DEFAULT_PASS` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` live
  in `secrets.data`, not the ConfigMap (Task 6.0.2 reconciliation — see
  "Secrets" above). `RABBITMQ_DEFAULT_PASS` is inert while
  `RABBITMQ_ENABLED=false` (this base's default); the two AWS vars are
  expected to stay empty in production regardless (prefer IRSA).
- `SIGNER_URL` / `XSD_VALIDATOR_URL` / `MQ_BRIDGE_URL` all point at
  **localhost** (`http://localhost:9101`, `http://localhost:9091`,
  `http://localhost:9121`) because the signer, validator, and (when enabled)
  the `mqbridge` are same-pod containers (ADR-12 + Decisão 21) — not cluster
  DNS. `MQ_BRIDGE_URL` is inert until `RSFN_CONSUMER_TRANSPORT=mq` **and**
  `mqbridge.enabled=true` (see "Conditional `mqbridge` container" above).

## Migration Job

Migrations are applied by a detached **ArgoCD `PreSync` hook** — a dedicated
Job plus a small companion Secret, both under `templates/migrations/` — that
runs **before** the main sync wave rolls the Deployment, so the monolith never
boots against an unmigrated database.

- `templates/migrations/secrets.yaml` — a PreSync Secret
  (`argocd.argoproj.io/hook-weight: "-2"`) carrying **only** `POSTGRES_PASSWORD`
  (from `migrations.postgres.password`, falling back to
  `secrets.data.POSTGRES_PASSWORD`). Its `hook-delete-policy` is
  `BeforeHookCreation` **only** (not `HookSucceeded`) so it survives the whole
  PreSync phase for the Job to read, and is replaced on the next sync. It is
  minted only when `migrations.useExistingSecret=false`.
- `templates/migrations/job.yaml` — a PreSync Job
  (`argocd.argoproj.io/hook-weight: "-1"`, so it runs after the Secret) that
  runs the dedicated `ghcr.io/lerianstudio/br-slc-migrations` image
  (`migrations.image.tag` defaults to `Chart.appVersion`). That image's
  entrypoint owns the golang-migrate loop over the `migrations/*.up.sql`
  **baked into the image** at build time by the br-slc release pipeline — the
  chart's Job only supplies the DB connection and runs the image; it does not
  carry the SQL or build the loop. Its `hook-delete-policy` is
  `BeforeHookCreation,HookSucceeded`.

The Job reads the DB connection from plain env vars
(`POSTGRES_HOST`/`POSTGRES_PORT`/`POSTGRES_USER`/`POSTGRES_NAME`/`POSTGRES_SSLMODE`,
each defaulting to the app's `configmap.data.POSTGRES_*`) plus
`POSTGRES_PASSWORD` via `secretKeyRef`. When `migrations.useExistingSecret=true`
the password comes from the operator-managed `migrations.existingSecretName`
instead of the chart-minted PreSync Secret (the render **fails fast** if
`existingSecretName` is left empty in that mode).

A lightweight `busybox` initContainer (`migrations.waitForPostgres`, on by
default) polls `POSTGRES_HOST:POSTGRES_PORT` with `nc -z` before the migrations
container starts, so a fresh install racing a not-yet-ready Postgres doesn't
hard-fail the Job.

Set `migrations.enabled: false` to skip the hook entirely (e.g. if migrations
are applied by a separate operational process).

### Recovering from a dirty migration

If a migration fails partway through, golang-migrate marks
`schema_migrations.dirty = true` in the database. Every subsequent sync re-runs
this PreSync Job, which keeps refusing to apply the next migration on top of a
dirty version — so the release never converges on its own.

Manual recovery:

1. **Find the failing version.** Inspect the failed PreSync Job/pod logs
   (`kubectl logs job/<release>-br-slc-migrations`). golang-migrate's error
   output names the dirty version, e.g. `Dirty database version 7. Fix and
   force version.`
2. **Force the version.** Run a one-off `migrate force <version>` against the
   same database, pointed at the same Postgres endpoint/credentials the Job
   uses (any golang-migrate-capable CLI works — the `schema_migrations` table
   is standard). Set `<version>` to the value identified in step 1 (use the
   version *before* the failed one if the failed migration's DDL did not
   actually apply — confirm against the target schema before forcing).
3. **Re-sync.** With `dirty` cleared, the PreSync Job runs normally and applies
   the remaining migrations.

This is a manual, deliberately out-of-band recovery path — the hook does not
attempt automatic dirty-state recovery, since forcing the wrong version can
silently skip or reapply DDL.

## Probes

| Container | Probe | Path | Port | Notes |
|---|---|---|---|---|
| `br-slc` | liveness | `/health` | 4111 | process viability only, no dependency checks |
| `br-slc` | readiness | `/readyz` | 4111 | dependency-aware; has a `draining` state during graceful shutdown — more lenient `failureThreshold` than liveness |
| `slc-signer` | liveness + readiness | `/health` | 9101 | same path for both (no separate readyz) |
| `aslc-xsd-validator` | liveness + readiness | `/health` | 9091 | same path for both |
| `mqbridge` | liveness only | `/health` | 9121 | only when `mqbridge.enabled`; process viability. **No readinessProbe on purpose** (Decisão 21) |

The app's `/health` and `/readyz` are auth/telemetry-exempt (see
`internal/bootstrap/routes.go`, `fiber_server.go`); `/metrics` is also exempt
but not probed here. Readiness relies on **per-container probes + shared
fate**: the pod is only `Ready` when all readiness-probed containers pass, so a
crash-looping signer/validator de-registers the pod endpoint on its own. The
app's `/readyz` deliberately does **not** add signer/validator dependency
checks — the fail-closed guard is enforced per-request in the builders, and
double-coupling readyz would only cause flapping. **mqbridge deliberately has
NO readinessProbe**: nothing routes to `:9121` via a Service, and its `/readyz`
reflects the live IBM MQ pool, so wiring it as readiness would pull the WHOLE
pod out of the monolith's `:4111` Service on any MQ blip — under the
`replicaCount=1` hard-cap that is a total API outage, not a consumer
degradation. MQ health reaches the monolith via the client-side breaker.

## Security posture

Every container (app, `slc-signer`, `aslc-xsd-validator`, migrate) carries the
same hardened `securityContext`: `runAsNonRoot: true`, `runAsUser/Group:
65532`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`
(each with its own `emptyDir` at `/tmp`), all capabilities dropped,
`seccompProfile: RuntimeDefault`. The signer/validator postures are set
per-container via `signer.securityContext` / `xsdValidator.securityContext`.
The conditional `mqbridge` container (`mqbridge.securityContext`) shares this
posture with **one deliberate exception**: `readOnlyRootFilesystem: false`,
because the IBM MQ C client (libmqm) needs a writable `/var/mqm` (mounted as
an explicit `emptyDir`); it stays non-root, no privilege escalation, all
capabilities dropped, `RuntimeDefault` seccomp. Service is `ClusterIP` only.

## Installation

The chart is published as an OCI artifact to GitHub Container Registry:

```bash
helm install my-release oci://ghcr.io/lerianstudio/br-slc-helm --version <chart-version>
```

## Ingress (opt-in, disabled by default)

The chart is `ClusterIP`-only by default (BYOC reaches the app over cluster DNS
or a manually managed edge). An optional Ingress is available for environments
that want one — enable it and set the class + host(s):

```yaml
ingress:
  enabled: true
  className: nginx
  annotations: {}
  hosts:
    - host: br-slc.dev-st.lerian.net
      paths:
        - path: /
          pathType: Prefix
  tls: []
```

With `ingress.enabled=false` (the default) no Ingress object is rendered.

### Port-forward (no Ingress)

```bash
kubectl port-forward svc/my-release-br-slc 4111:4111
curl localhost:4111/health
curl localhost:4111/readyz
```

## Not included in this chart

- **HPA / PodDisruptionBudget** — not in this chart's scope (Task 6.0.1
  deliverable list); add if/when autoscaling or multi-replica HA is needed.
- **Postgres/Redis/RabbitMQ subcharts** — BYOC brings its own; this chart only
  takes connection config.
- **SaaS multi-tenant MQ consumer manager** — the shared-keystore /
  cert-label-per-connection consumer manager for the SaaS model is **Fase 7**
  (a separate singleton Deployment), out of scope here (Decisão 21). This
  chart's `mqbridge` is the BYOC single-tenant same-pod consumer only.
