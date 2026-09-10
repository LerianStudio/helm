# plugin-br-pix-lerian (Helm chart)

## Chart Contract

- Chart type: `multi-component`
- Required secrets: None for the default render, which is **not** a working installation. A working installation requires per-component Postgres DSNs, `LICENSE_KEY` outside `local` mode, and `SYSTEMPLANE_SECRET_MASTER_KEY` on the Systemplane components in the modes listed under [Required before installation](#required-before-installation). Credential-bearing DSNs, URLs, tokens, and passwords belong in a component's `secrets` block or an existing Secret — never in `configmap`.
- Dependency notes: PostgreSQL, Valkey, and RabbitMQ ship as local subcharts that are **disabled by default**. Production points the components at externally managed services.
- Production overrides: Per-component `secrets` (or `useExistingSecret` + `existingSecretName`), `global.externalPostgresDefinitions`, `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_URL`, and the ingress blocks. An existing Secret **replaces** the chart-rendered Secret for that component; it is not merged.
- Source/license: Source is in [github.com/LerianStudio/helm](https://github.com/LerianStudio/helm); chart license is Apache-2.0.

## Overview

BACEN-compliant Pix platform for the Lerian ecosystem.

This chart manages 14 independently deployable Pix Lerian workloads. Each one gets its own Deployment, Service, ConfigMap, Secret, ServiceAccount, and — where configured — HPA and PodDisruptionBudget. Ingress is opt-in and disabled by default on all three ingress surfaces.

The DICT and COB domains each deploy as a hub tier or a proxy tier, chosen per domain. Read [Supported topologies and current limitations](#supported-topologies-and-current-limitations) before choosing which workloads to enable: in this release only the hub tier carries business flows, and some workloads are development only.

## Compatibility

| Chart version | App image tag |
|---|---|
| 2.1.0-beta.2 | 1.0.0-beta.318 |

The row above covers this chart only. There is no in-place upgrade path from any earlier chart — moving to this chart is a fresh install (cutover), not a `helm upgrade`. A cutover does not migrate or copy data; see [Upgrade and rollback](#upgrade-and-rollback).

Every workload's image tag defaults to the chart's `appVersion`, which keeps the cohort in lockstep. You can pin `<component>.image.tag` per workload, but doing so takes that workload off the cohort and is not covered by the compatibility row above.

## What this chart installs

**The default render is not a working installation.** `helm template` with no values succeeds, but it validates structure only. With defaults:

- 6 of the 14 workloads are disabled.
- No Postgres DSN is set, so **no migration Job is rendered** and the schemas are never applied.
- PostgreSQL, Valkey, RabbitMQ, the external-Postgres bootstrap, and all three ingresses are off.
- `LICENSE_KEY` is empty while `DEPLOYMENT_MODE` defaults to `byoc`, which the applications refuse.

`values-template.yaml` is a starting point, not a ready-to-apply file.

### Workloads

| Key in `values.yaml` | Responsibility | Enabled by default | Service port | Route prefix |
|---|---|---|---|---|
| `spi` | Pix SPI — payment initiation and settlement flows | Yes | 4101 | `/spi` |
| `spiSystemplane` | Runtime configuration plane for SPI | Yes | 4102 | `/spi` |
| `adapterProviderMock` | Provider test double | No | 4103 | `/provider-mock` |
| `dictHub` | DICT key directory — business flows | Yes | 4104 | `/dict-hub` |
| `dictHubVsync` | DICT reconciliation worker (singleton) | No | 4105 | none |
| `dictProxy` | DICT proxy tier | Yes | 4106 | `/dict-proxy` |
| `dictSystemplane` | Runtime configuration plane for DICT | Yes | 4107 | `/dict` |
| `cobHub` | COB / BR Code charge operations | Yes | 4108 | `/cob-hub` |
| `cobProxy` | COB proxy tier | Yes | 4109 | `/cob-proxy` |
| `cobSystemplane` | Runtime configuration plane for COB | Yes | 4110 | `/cob` |
| `adapterLerian` | Lerian provider adapter | No | 4113 | `/lerian` |
| `adapterLerianSystemplane` | Runtime configuration plane for the adapter | No | 4115 | `/lerian` |
| `pixauto` | Pix Automático — payer side | No | 4116 | `/pixauto` |
| `pixautoSystemplane` | Runtime configuration plane for Pix Automático | No | 4117 | `/pixauto` |

Ports 4111, 4112, and 4114 are intentionally unused.

Each workload pulls its own image, `ghcr.io/lerianstudio/plugin-br-pix-lerian-<component>-api`, set under `<component>.image.repository`. Worker workloads omit the `-api` suffix — `dictHubVsync` pulls `plugin-br-pix-lerian-dict-hub-vsync`. There is no shared `global.image`; a `global.image.tag` is accepted by the schema and then ignored.

The application also ships an adapter consumer entrypoint that this chart does not model. If your integration needs it, it has to be deployed outside this chart.

## Supported topologies and current limitations

### Hub and proxy are not interchangeable

The DICT and COB domains each deploy in one of two tiers, and the choice is made per domain.

A **hub** owns the domain's business logic and its local state — its own database, and Valkey on some components. It carries the domain's operations itself.

A **proxy** is the tier for a provider that already owns that state on its side, so it keeps no local business state of its own.

Which tier a domain uses follows the provider's capability: a provider that owns the state is fronted by the proxy, one that does not is fronted by the hub. **The domains are independent.** Each rail carries its own mode, and setting DICT to proxy does not affect COB, so the model allows a deployment to combine DICT on proxy with COB on hub.

**In this release, only the hub tier carries business flows.** The proxy tier serves no business route in either domain, so the hub is the tier that serves traffic today — including inside a mixed combination, where the domain placed on proxy would answer no business request at all.

`dictProxy` and `cobProxy` serve `health`, `readyz`, and an OpenAPI document that declares no operations, and they contain no request-forwarding logic. **Choosing the proxy tier does not deliver functional parity, and it does not fall back to the hub.**

If you route client traffic at a proxy:

- Every business request returns 404. There is no forwarding and no fallback.
- `health` and `readyz` still return 200, so monitoring stays green while the rail is dead.
- Setting a routing mode to `proxy` on a **caller** points that caller at the proxy tier, so every operation that caller performs against the affected domain stops working. `spi` carries a mode for DICT and one for COB; `cobHub` carries one for DICT.
- Routing mode selects only which service name a caller resolves. It is **not** cross-checked against the matching `*_BASE_URL`, so a mismatch between the two is not caught at boot. Keep them pointing at the same tier.
- A proxy still needs a Postgres DSN for its configuration store. It is not a stateless drop-in.

Routing mode accepts `hub` and `proxy` and defaults to `hub`. **Leave it at `hub` in this release.** Enable the proxy workloads only if your provider topology requires the tier to exist; do not send business traffic to it.

### `adapterLerian` and `adapterLerianSystemplane` — Development only in this release

`adapterLerian` **fails to boot when `DEPLOYMENT_MODE` is anything other than `local`.** The chart default is `byoc` and it ships the workload disabled, so nothing breaks out of the box, but the consequence is:

- Do not enable `adapterLerian` in a `byoc` or `saas` deployment. The pod will crash-loop.
- Treat the `adapterLerian` / `adapterLerianSystemplane` pair as **Development only** in this release.
- The `pix-adapter-lerian` database is still created by the bootstrap Job (see [Database bootstrap and migrations](#database-bootstrap-and-migrations)), because the database list is fixed.

### `adapterProviderMock` — Development only

A provider test double for development and homologation, shipped `enabled: false`. It stands in for a real provider so the rest of the platform can be exercised end to end without one.

It talks to the Lerian sandbox mock server, which is the chart's default for that setting:

```yaml
adapterProviderMock:
  configmap:
    PROVIDER_BASE_URL: "https://mock-pix-lerian-server.sandbox.lerian.net"
```

Because the component ships disabled, that default reaches no installation that does not enable it explicitly. Override it only to target your own mock server.

Two more settings are required and cannot get a default, because they identify *your* sandbox access; a third is optional. You receive them together with that access:

| Setting | Where | Notes |
|---|---|---|
| `PROVIDER_CLIENT_ID` | `secrets` | **Required** — the component does not start without it |
| `PROVIDER_CLIENT_SECRET` | `secrets` | **Required** — the component does not start without it |
| `SPI_BASE_URL` | `configmap` | **Required** — validated at boot. The chart ships an in-cluster default |
| `ADAPTER_ISPB` | `configmap` | Optional. The ISPB the mock presents as the provider; the application falls back to a placeholder ISPB when it is empty, so set it to exercise your own |

No credential ships in this chart. Supply these the same way as any other secret — see [Production secret management](#production-secret-management).

Two cautions:

- Its routes have **no authorization**, regardless of `PLUGIN_AUTH_ENABLED`. Keep `enabled: false` anywhere the pod can be reached by callers you do not control, and never publish it on a shared ingress.
- Leave `MOCK_TEST_ENDPOINTS_ENABLED` off outside a controlled environment; it mounts routes that simulate provider callbacks.

### Supported production topology

Hub-only, with the two `Development only` pairs disabled:

- `spi`, `spiSystemplane`
- `dictHub`, `dictSystemplane`, and `dictHubVsync` if you need DICT reconciliation
- `cobHub`, `cobSystemplane`
- `pixauto`, `pixautoSystemplane` if you need Pix Automático
- `dictProxy` / `cobProxy` only if your topology requires the tier to be present

## Prerequisites

- **Kubernetes 1.23+** and **Helm 3.10+**, matching the convention of the charts in this repository.
- **Registry access.** A GHCR credential that can pull `ghcr.io/lerianstudio/plugin-br-pix-lerian-*` images, and OCI access to pull the chart.
- **A namespace**, created before install.
- **PostgreSQL.** Reachable from the cluster, with the databases and role from [Database bootstrap and migrations](#database-bootstrap-and-migrations). Which workload needs which DSN is in the [dependency matrix](#dependencies-per-workload).
- **Valkey (Redis-compatible)** if you enable `dictHubVsync` (**required**) or want the optional caches on `spi`, `dictHub`, `cobHub`, `pixauto`.
- **RabbitMQ** if you enable `dictHubVsync` in a single-tenant deployment (**required** — the render fails without the URI).
- **An Access Manager** reachable at `PLUGIN_AUTH_URL` if you set `PLUGIN_AUTH_ENABLED=true`, which you should for any exposed deployment.
- **A license key** for any `DEPLOYMENT_MODE` other than `local`.
- **DNS, TLS certificates, and an ingress controller** if you enable any ingress. The chart defaults to `className: nginx`.
- **Permissions to create Jobs** in the namespace. Bootstrap and migrations both run as Jobs.
- **Existing Secrets created before `helm install`.** Migration Jobs are pre-install/pre-upgrade hooks, so any Secret they read must already exist.
- **Storage classes / PVCs** only if you enable the local subcharts, which is for development.

### Pre-installation checklist

1. Namespace created.
2. Image pull secret created in that namespace and named in `global.imagePullSecrets`.
3. Postgres reachable; databases and role exist, or `global.externalPostgresDefinitions` is configured to create them.
4. `secrets.DATABASE_URL` and/or `secrets.SYSTEMPLANE_POSTGRES_DSN` set for every workload you enable — **otherwise no migration Job is rendered for it.**
5. `LICENSE_KEY` set on every enabled workload if `DEPLOYMENT_MODE` is not `local`, and `ORGANIZATION_IDS` set alongside it on the eight workloads that build a license client — see [`ORGANIZATION_IDS`](#required-before-installation) for the list.
6. `SYSTEMPLANE_SECRET_MASTER_KEY` set on the Systemplane workloads that require it in your mode.
7. `RABBITMQ_URI` set if `dictHubVsync` is enabled.
8. `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_URL` decided; `systemplaneIngress.enabled` left `false`.
9. Chart version pinned.

### Building your values file

Start from `values-template.yaml` in this directory and fill in its placeholders. The template
carries the shape — which key belongs to which workload, and which ones belong in `secrets`
rather than `configmap`. This README carries what each value means and when it is required; the
authoritative list is [Required before installation](#required-before-installation).

Before the first install, make sure the template's placeholders are filled for every workload you
enable: the Postgres DSNs, `LICENSE_KEY` and `ORGANIZATION_IDS` outside `local` mode,
`SYSTEMPLANE_SECRET_MASTER_KEY` where it applies, and the identity and dependency addresses on the
`*Systemplane` blocks.

Those `*Systemplane` blocks matter more than they look. Each one seeds its domain's configuration
store, and the application workloads read those values back and gate their readiness on them —
so setting identity and dependency addresses only on the application workload is not enough.
`ADAPTER_BASE_URL` has no default and must point at whatever provider adapter your environment
runs, including that adapter's route prefix.

## Component and dependency matrix

### Dependencies per workload

| Workload | Business DB | Systemplane store | Valkey | RabbitMQ | Streaming | Ingress surface |
|---|---|---|---|---|---|---|
| `spi` | `pix-spi` — **Required** | `pix-spi` | Optional, degrades | — | Optional, off | apps |
| `spiSystemplane` | — | `pix-spi` — **Required** | — | — | — | systemplane |
| `adapterProviderMock` | — | — | — | — | — | providers |
| `dictHub` | `pix-dict` — **Required** | `pix-dict` | Optional, degrades | Optional, off by default | Optional, off | apps |
| `dictHubVsync` | `pix-dict` — **Required** (single-tenant) | `pix-dict` | **Required** | **Required** (single-tenant) | — | none |
| `dictProxy` | `pix-dict` — **Required** | `pix-dict` | — | — | — | apps |
| `dictSystemplane` | — | `pix-dict` — **Required** | — | — | — | systemplane |
| `cobHub` | `pix-cob` — **Required** (single-tenant) | `pix-cob` | Optional, degrades | — | Optional, off | apps |
| `cobProxy` | `pix-cob` — **Required** | `pix-cob` | — | — | — | apps |
| `cobSystemplane` | — | `pix-cob` — **Required** | — | — | — | systemplane |
| `adapterLerian` | none | `pix-adapter-lerian` — **Required** | Required when enabled | — | — | providers |
| `adapterLerianSystemplane` | — | `pix-adapter-lerian` — **Required** | — | — | — | systemplane |
| `pixauto` | `pix-pixauto` — **Required** (single-tenant) | `pix-pixauto` — **Required** | Optional, degrades | — | Optional, off | apps |
| `pixautoSystemplane` | — | `pix-pixauto` — **Required** | — | — | — | systemplane |

Notes on the entries above:

- **`cobHub` and Valkey.** The cache is optional. Without `VALKEY_URL`, `cobHub` runs with the cache off and no route fails; a retried request may re-execute.
- **`dictHubVsync` and Valkey/RabbitMQ.** Both are hard requirements. The chart **fails the render** if `dictHubVsync` is enabled without `RABBITMQ_URI`. In a multi-tenant deployment the shared RabbitMQ connection is not opened and `RABBITMQ_URI` is not consulted; queues live in per-tenant vhosts instead.
- **`dictHub` and RabbitMQ.** Publish-only and **off unless you set it**. Enabling it only accelerates reconciliation job dispatch; if the broker is unavailable the workload logs a warning and continues on its backstop. The chart does not ship the key.
- **`adapterLerian` and Valkey.** Required once its DLQ admin surface is active, which is gated by the presence of Kafka broker configuration. Moot in practice, since the workload is `Development only` in this release.
- **Streaming.** `spi`, `dictHub`, `cobHub`, and `pixauto` can emit CloudEvents. It is **off by default**; only `pixauto` ships the `STREAMING_*` keys. Leave `STREAMING_CLOUDEVENTS_SOURCE` empty — a non-empty value that does not match the application's own source refuses the boot **whether or not streaming is enabled**. Enabling streaming without brokers also refuses the boot.
- **`MULTI_TENANT_REDIS_*`** on `dictHubVsync` is a **separate** Redis instance from `VALKEY_URL` — it is where the Tenant Manager publishes tenant lifecycle events. Pointing both at the same instance makes tenant changes invisible to the worker. It is optional: without it, tenant discovery falls back to the periodic sweep. The CA certificate, when used, is base64-encoded PEM.

### Effect of disabling a workload

Only `spi`, `dictHub`, `cobHub`, `adapterLerian`, and `pixauto` carry a `migrations` block, and a migration Job renders **only for an enabled component**. This has a consequence worth planning around:

> Disabling the hub of a domain removes the only Job that applies that domain's schema. For example, running COB as `cobProxy` + `cobSystemplane` with `cobHub` disabled renders **no** Job for `pix-cob`, so that schema is never applied even though both remaining workloads use the database.

If you disable a hub, apply that domain's schema by other means before the remaining workloads start.

## Required before installation

Set these before `helm install`. **"Required" does not mean the same thing on every row** — a missing value can fail the render, the container, the boot, readiness, or only the first request that needs it. The `Failure stage` column says which:

| Stage | What you see |
|---|---|
| Render | `helm template`/`install` fails; nothing is applied |
| Container creation | Pod stuck in `CreateContainerConfigError` |
| Application boot | `CrashLoopBackOff`; the log names the variable |
| Readiness | Pod runs, `readyz` 503 |
| First request | Pod ready; the request that needs the value is rejected |
| Security posture | Everything works and is unprotected |
| Optional degradation | Feature off or slower; no failure |

| Setting | Where | Failure stage | Required when |
|---|---|---|---|
| `DEPLOYMENT_MODE` | `configmap` | Application boot | Accepts `local`, `byoc`, `saas`, lower-case and untrimmed. **Required to be set explicitly** on `spi`, `dictHub`, `dictProxy`, `cobHub`, `cobProxy`, `pixauto` when `MULTI_TENANT_ENABLED=true`. Chart default is `byoc`. |
| `LICENSE_KEY` | `secrets` | Application boot | **Required** whenever `DEPLOYMENT_MODE` is anything other than `local`. Empty is tolerated only in `local`. The chart ships the key on all 14 workloads. |
| `ORGANIZATION_IDS` | `configmap` | Application boot | **Required together with `LICENSE_KEY`** — the license client refuses to initialise without it and the workload exits at boot. Use `global` for a single-license deployment, or a comma-separated list to scope it. Eight workloads build a license client and need the key: `spi`, `dictHub`, `dictProxy`, `dictHubVsync`, `cobHub`, `cobProxy`, `pixauto`, and `adapterLerian`. The five Systemplane workloads and `adapterProviderMock` do not, so the key is not needed there even though they carry `LICENSE_KEY`. `values-template.yaml` sets it on all eight; `values.yaml` ships it only on `adapterLerian` and `pixauto`, so add it to the other six if you build your values file from the defaults. |
| `ORGANIZATION_ID` | `configmap` | Application boot | Single-tenant business identity. Applies to `spi`, `dictHub`, `dictHubVsync`, `cobHub`. **Must be empty** when `MULTI_TENANT_ENABLED=true` on `cobHub` and `pixauto` — a value there refuses the boot. Not read by `dictProxy` or `pixauto`; the chart ships it there for parity only. Not interchangeable with `ORGANIZATION_IDS`. |
| `ISPB` | `configmap` | Readiness | Single-tenant identity on `spi`, `dictHub`, `dictHubVsync`. Required to reach ready — see [Health and readiness reference](#health-and-readiness-reference). |
| `DATABASE_URL` | `secrets` | Application boot | **Required** on `spi`, `dictHub`, `dictProxy`, `cobProxy` in every mode. **Required in single-tenant only** on `cobHub`, `dictHubVsync`, `pixauto`. Not used by `adapterLerian`, `adapterProviderMock`. |
| `SYSTEMPLANE_POSTGRES_DSN` | `secrets` | Application boot | On the five Systemplane workloads, **one of** this or `DATABASE_URL` is required, and this one **wins** when both are set. **Required** on `adapterLerian` and `pixauto`. On other workloads it is optional and falls back to `DATABASE_URL`. |
| `SYSTEMPLANE_SECRET_MASTER_KEY` | `secrets` | Application boot | **Required, and must be non-empty**, on `spiSystemplane`, `dictSystemplane`, `cobSystemplane`, `pixautoSystemplane` whenever `ENV_NAME` is not `local` or `development`; and on `adapterLerianSystemplane` whenever `DEPLOYMENT_MODE` is not `local`. Note the two gates differ. See [the note below](#about-systemplane_secret_master_key). |
| `MULTI_TENANT_ENABLED` | `configmap` | Application boot | Defaults to `false`. See [Multi-tenant configuration](#multi-tenant-configuration). |
| `MULTI_TENANT_URL`, `MULTI_TENANT_API_KEY` | `configmap` / `secrets` | Application boot | **Required when `MULTI_TENANT_ENABLED=true`** on the five Systemplane workloads, `cobHub`, `dictHubVsync`, `pixauto`, `adapterLerian`. `dictSystemplane` and `cobSystemplane` do **not** ship these keys — add them through the open maps. |
| `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_URL` | `configmap` | Application boot / Security posture | Defaults to `false` / an in-cluster placeholder. When enabled, `PLUGIN_AUTH_URL` **must be non-empty** or the workload refuses to start. **Required to be `true`** on `pixauto` whenever `ENV_NAME` is not `local` or `development`. |
| `AUTH_JWT_VERIFY_CERT`, `AUTH_JWT_ISSUER` | `secrets` | Application boot | **Required on `pixauto`** when `PLUGIN_AUTH_ENABLED=true` and `ENV_NAME` is not `local` or `development`. **The chart does not ship these keys** — add them through `pixauto.secrets`. Without them the workload refuses to start. |
| `RABBITMQ_URI` | `secrets` | Render | **Required when `dictHubVsync` is enabled.** The render fails without it. |
| `PROVIDER_CLIENT_ID`, `PROVIDER_CLIENT_SECRET` | `secrets` | Application boot | **Required when `adapterProviderMock` is enabled** — it does not start without both. Issued with your sandbox access; see [`adapterProviderMock`](#adapterprovidermock--development-only). |
| `VALKEY_URL` | `secrets` | Application boot / Optional degradation | **Required** on `dictHubVsync`, which does not start without it. Optional on `spi`, `dictHub`, `cobHub` and `pixauto`, where its absence degrades the cache rather than failing the workload. |
| `ADAPTER_BASE_URL` | `configmap` | First request | Optional at boot — it is not validated at startup. A missing value surfaces as rejected requests at runtime, not as a failed rollout. Include the provider's route prefix. |

Setting a key that a workload does not read has no effect. The `configmap`, `secrets`, and `extraEnvVars` blocks are open maps: the chart passes any key you add straight to the container, but **that is not proof the binary reads or validates it**. An unknown key is ignored silently. Use only keys documented for that workload and this version.

### About `SYSTEMPLANE_SECRET_MASTER_KEY`

- It is **required to be present and non-empty** on the workloads and in the modes listed above. The workload refuses to start without it.
- **No format and no length is validated by this release.** Do not infer a required encoding or size.
- Supply it from an existing Secret; see [Production secret management](#production-secret-management).
- Because it is checked at every boot, keep the same value across upgrades — otherwise a rollout needs the new value supplied everywhere first.
- The two gates are different: four Systemplane workloads key off `ENV_NAME`, and `adapterLerianSystemplane` keys off `DEPLOYMENT_MODE`. With the chart defaults (`ENV_NAME: development`, `DEPLOYMENT_MODE: byoc`), `adapterLerianSystemplane` already requires the key while the other four do not.

## Production secret management

In production, every secret comes from a Secret your own secret manager populates. The chart supports that per workload:

```yaml
spi:
  useExistingSecret: true
  existingSecretName: <kubernetes-secret-name>
```

Rules that matter:

- **The existing Secret replaces the chart-rendered Secret entirely. There is no merge.** When `useExistingSecret: true`, the chart does not render `plugin-br-pix-lerian-spi` at all and the pod's `envFrom` points only at your Secret. Anything you left in `spi.secrets` is silently not applied.
- **Your Secret must therefore carry the complete set of secret keys for that workload** — every key that workload needs from the table above, not just the ones you wanted to override.
- `useExistingSecret` must be an **unquoted boolean**. A quoted `"false"` is truthy in Helm templates; the chart rejects it rather than silently selecting an existing Secret. Prefer `--set` over `--set-string` for this key.
- `existingSecretName` is required when `useExistingSecret` is true.
- **Never put a secret in `configmap` or `extraEnvVars`.** ConfigMap data is not protected, and `extraEnvVars` renders the value inline into the Deployment, where `kubectl describe` shows it.
- Inline `secrets` are for development, testing, or a deliberate exception. An inline value ends up in Git, in your GitOps renders, and in Helm release history.
- The existing Secret must exist **before** `helm install`, because the migration hooks run first.

Creating a Secret without leaving the value in shell history — note the leading space, and that this depends on your shell's `HISTCONTROL`/`histignorespace` setting:

```bash
 kubectl create secret generic <kubernetes-secret-name> \
   --namespace <namespace> \
   --from-literal=DATABASE_URL='postgres://<user>:<password>@<postgres-host>:5432/pix-spi?sslmode=require' \
   --from-literal=LICENSE_KEY='<license-key>'
```

Prefer reading from files, which keeps values out of the process list entirely:

```bash
kubectl create secret generic <kubernetes-secret-name> \
  --namespace <namespace> \
  --from-file=DATABASE_URL=./database-url.txt \
  --from-file=LICENSE_KEY=./license-key.txt
```

## Database bootstrap and migrations

### The five databases

A full single-tenant deployment uses five databases: `pix-spi`, `pix-dict`, `pix-cob`, `pix-adapter-lerian`, and `pix-pixauto`, owned by a single role. **This is the complete topology, not a per-workload requirement** — which workload needs which is in the [dependency matrix](#dependencies-per-workload).

### Optional bootstrap Jobs

With `global.externalPostgresDefinitions.enabled: true` the chart renders one Job per database, creating role, database, and grants idempotently. The admin credentials need privilege to create roles and databases on the target server.

The Jobs are `pre-install,pre-upgrade` hooks at weight `-20`, and the Secret carrying their credentials is a hook at `-30`. That places both ahead of the migration pair at `-10` and `-5`, so on a fresh install the role and the databases exist before the first migration runs against them. They run again on every upgrade; the Jobs are idempotent, so a re-run against already-provisioned databases is a no-op that re-asserts the role password and the grants.

Each credential can come from an existing Secret or inline, independently of the other:

| Credential | Existing Secret | Inline |
|---|---|---|
| Postgres admin login | `postgresAdminLogin.useExistingSecret.name`, on a Secret carrying `DB_USER_ADMIN` and `DB_ADMIN_PASSWORD` | `postgresAdminLogin.username` + `.password` |
| Application role password | `pixLerianCredentials.useExistingSecret.name`, on a Secret carrying `DB_PASSWORD_PIX_LERIAN` | `pixLerianCredentials.password` |

The schema requires `connection.host` and, for each of the two credentials, either a password or an existing Secret name. Enabling the bootstrap without them fails the render.

Inline values never reach a Job manifest. The chart collects them into a single Secret and the Jobs read every credential through `secretKeyRef`, so both paths reach the container identically and no password appears in the Job spec or in `kubectl describe job`. That Secret carries only the inline halves, and when both halves name an existing Secret it is not rendered at all.

An inline half left empty **fails at render time** rather than producing a Secret the Jobs would then authenticate with.

`pixswitchCredentials` was renamed to `pixLerianCredentials` and there is **no alias**. `values.schema.json` rejects the retired key outright, so a stale override fails loudly instead of quietly ceasing to apply. Rename the key in your values.

Guarantees the Jobs provide:

- The role password is set client-side with `password_encryption = 'scram-sha-256'` pinned in the same session, so only the derived verifier reaches the server and the cleartext password never does. This works without superuser.
- **The bootstrap image must ship psql 15 or newer.** The Job keeps credentials out of process arguments using a meta-command added in psql 15. The chart pins `postgres:17`.
- Inputs are validated before the cluster is touched, so a bad credential cannot half-bootstrap the databases: empty `DB_USER_ADMIN`, `DB_ADMIN_PASSWORD`, or `DB_PASSWORD_PIX_LERIAN` are refused, and an application password containing LF or CR is refused because the password is transported as newline-delimited input. Every other character works, including spaces, quotes, backslashes, and `$ @ /`.
- Every session taking an advisory lock sets `lock_timeout = '60s'` first, so a Job contending with a sibling fails with a clear error instead of blocking until the release times out.

The role name defaults to `pixswitch`. Set `global.externalPostgresDefinitions.pixLerianCredentials.username` on a new deployment to change it. Renaming the role on an existing deployment is a database operation, not a values change — pointing the chart at a new name would create a second role with no privileges over the existing objects.

### Migration Jobs

`spi`, `dictHub`, `cobHub`, `adapterLerian`, and `pixauto` each carry a `migrations` block. A migration Job renders only when **all** of these hold:

1. the component is enabled,
2. `<component>.migrations.enabled` is not `false` (it defaults to true), and
3. `<component>.useExistingSecret` is true **or** `<component>.secrets.DATABASE_URL` is non-empty.

Condition 3 is why the default render produces no Jobs: an empty DSN would make the hook fail the release before any pod starts, so the chart skips it instead. **A workload whose Job never renders never gets its schema applied.**

Hook annotations. Every database resource in the chart sits in the same `pre-install,pre-upgrade` phase, ordered by weight:

| Resource | Hook | Weight | Delete policy |
|---|---|---|---|
| `plugin-br-pix-lerian-bootstrap-postgres` Secret | `pre-install,pre-upgrade` | `-30` | `before-hook-creation` |
| `plugin-br-pix-lerian-bootstrap-postgres-<database>` Job | `pre-install,pre-upgrade` | `-20` | `before-hook-creation,hook-succeeded` |
| `plugin-br-pix-lerian-<component>-migrations` Secret | `pre-install,pre-upgrade` | `-10` | `before-hook-creation` |
| `plugin-br-pix-lerian-<component>-migrations` Job | `pre-install,pre-upgrade` | `-5` | `before-hook-creation,hook-succeeded` |

The migration Secret carries only `DATABASE_URL`. It is **not** rendered when `useExistingSecret: true` — the Job reads your Secret directly, which is why that Secret must exist before the install begins.

**Install and upgrade share one ordering.** Helm applies the hooks of a phase in weight order and waits for each one to finish before starting the next, so both lifecycles run:

1. weight `-30`: the bootstrap credential Secret is applied (only with the bootstrap enabled).
2. weight `-20`: the bootstrap Jobs create the role, databases, and grants (only with the bootstrap enabled).
3. weight `-10`: each component's migration Secret is applied.
4. weight `-5`: each component's migration Job runs and must succeed.
5. weight `0`: the normal resources — Deployments, Services, ConfigMaps, and the application Secrets — are applied, and on an upgrade the new pods roll out.

What that gives you:

- **Migrations complete before any workload is created or updated.** A failing migration aborts the release at step 4, so on a first install no Deployment is created at all, and on an upgrade the running pods are left untouched at the previous revision.
- **The bootstrap Jobs are sequenced ahead of the migrations** that depend on the databases they create, which makes provisioning and migrating in a single fresh install a supported flow.
- **`--wait` no longer sits between a workload and its schema.** The migration now runs before the workloads exist, so the readiness gate comes after the schema is in place instead of in front of the step that applies it. A workload that cannot report ready until its tables exist is therefore no longer waiting on something that has yet to run. Still raise `--timeout` for large schema changes, since `--wait` waits for hook Jobs too.

**The database must already be reachable when the migration Job runs.** That holds for an external or managed server, and for the databases the chart's own bootstrap Jobs create. It does **not** hold for the bundled `postgresql` subchart: its StatefulSet is a normal resource at weight `0`, so it cannot be started before a hook at weight `-5`. Pointing a DSN at the bundled subchart and installing with migrations enabled therefore fails at the migration hook, with the connection error in the Job log. That subchart is [development-only](#development-only-local-dependencies); when you do use it, install once with `<component>.migrations.enabled: false`, then enable migrations in a second step once Postgres is running.

The chart also carries Argo CD annotations (`argocd.argoproj.io/hook`, `sync-wave`) alongside the Helm ones, with the same waves as the weights above. All four resources are `PreSync`. Argo CD's phase model is its own and is not a restatement of Helm's; the waves express the same relative order within `PreSync`.

## Single-tenant configuration

Single-tenant is the default (`MULTI_TENANT_ENABLED: "false"`).

Set the deployment identity on both the domain application **and** its Systemplane workload:

- Identity: `ORGANIZATION_ID`, `ISPB`
- Dependency addresses: `ADAPTER_BASE_URL`, and the `*_BASE_URL` / `*_CLIENT_ID` / `*_CLIENT_SECRET` families

The Systemplane workload is what seeds these into the configuration store; the application workloads read them back. Readiness is gated on the store, so a workload can be running with correct environment values and still report itself not ready if the domain's Systemplane workload was never given them. Set the same values on both.

## Multi-tenant configuration

With `MULTI_TENANT_ENABLED: "true"`:

- `MULTI_TENANT_URL` and `MULTI_TENANT_API_KEY` become **required** on the five Systemplane workloads, `cobHub`, `dictHubVsync`, and `pixauto`. `dictSystemplane` and `cobSystemplane` do not ship these keys — add them through the open maps.
- `DEPLOYMENT_MODE` must be **explicitly set** on `spi`, `dictHub`, `dictProxy`, `cobHub`, `cobProxy`, and `pixauto`.
- `ORGANIZATION_ID` **must be empty** on `cobHub` and `pixauto`. A value there refuses the boot, because a deployment-wide organization could only act as a cross-tenant fallback.
- `DATABASE_URL` stops being required on `cobHub`, `dictHubVsync`, and `pixauto`, which resolve per-tenant pools instead. It stays required on `spi`, `dictHub`, `dictProxy`, and `cobProxy`.
- The boot-time configuration snapshot is skipped entirely; environment and Helm values are the boot source of truth.

### Tenant configuration is provisioned per tenant

Store seeding from the environment does **not** run in multi-tenant mode. A tenant's configuration is written per tenant and read per request, so provisioning a tenant is a step of its own — it is not something Helm values do for you. Identity in particular is per tenant: `ORGANIZATION_ID` must be **empty** on `cobHub` and `pixauto`, and a value there refuses the boot.

Readiness on the application workloads still consults the configuration store, so a workload can be running with correct environment values and still report itself not ready while the store has nothing for it to read. Read the `readyz` body: it names each check and, under `required_keys`, the exact keys it is waiting for.

### The request path fails closed

Per-tenant configuration is resolved from the store on every request, keyed by the calling tenant. **There is no global fallback.** A request whose tenant configuration is missing or incomplete is rejected with **HTTP 403 and code `TENANT_CONFIG_NOT_FOUND`**, and a request arriving without a resolvable tenant is refused before any read. The log line names the cause and the missing keys, never the values.

Provision each tenant's configuration before sending it traffic. When a tenant is missing something, the rejection names the missing keys, which is the reliable way to enumerate what that workload requires in your version.

Two different sets are at play, and they fail at different moments — this is the usual source of a tenant that onboards cleanly and then rejects every request:

- **Readiness** consults the deployment-wide slots. On `cobHub` those are `organization_id`, `ispb`, `provider` and `dict_base_url`.
- **Tenant resolution** consults the calling tenant's own configuration on every request. On `cobHub` that set additionally requires `dict_client_id` and `dict_client_secret` — five keys in total. They are deliberately per-tenant rather than deployment-wide, and an absent credential fails the request closed with 403 rather than falling back.

So a `cobHub` that reports ready can still reject traffic for a tenant whose DICT credentials were never provisioned.

## Systemplane configuration lifecycle

Configuration reaches a workload at three levels.

### 1. Direct bootstrap environment

Read from the pod's environment through `configmap`, `secrets`, and `extraEnvVars`. Changing one of these is a values change plus an upgrade, and a rollout if the value was captured at boot.

### 2. Systemplane seed and runtime store

**The store overrides the value loaded from the environment at boot. The environment variables are first-boot seeds. A restart re-reads the store.** Nothing rewrites the container's environment.

Seeding rules:

- Seeding runs **only in the five Systemplane workloads, and only in single-tenant mode.**
- **Only keys with an explicit seed mapping are seeded.** Keys that exist in the store's catalogue but have no mapping stay at their registered default until an administrator sets them.
- **An empty environment value is skipped.**
- **The seed only replaces a value still at its registered default.** A value an administrator has already changed is preserved — re-deploying with a different environment value will **not** overwrite it.
- A value the key's validator rejects is dropped silently.

The boot-time snapshot is skipped, leaving the environment value in place, when: the deployment is multi-tenant; no configuration store is reachable (no DSN, or a connection failure — logged as a warning, and the workload continues); the stored value is empty or the key is absent; or the stored value has the wrong type. `adapterLerian` has **no boot snapshot at all** — it reads the store per request.

Which keys need a restart:

| Class | Behaviour | Examples |
|---|---|---|
| Boot-captured | Read once at boot. **A change through the administrative API needs a pod restart.** | Deployment identity (`organization_id`, `ispb`), provider and dependency base URLs, routing modes, the request timeout, telemetry settings, the auth toggle and URL, Postgres pool sizing |
| Hot-reloaded in place | Applied without a restart | Log level, the reconciliation worker's enable/concurrency knobs, and the readiness key gates — satisfying a gate turns `readyz` green on its own |
| Per-request | Read on every request | Per-tenant identity and credentials, the adapter's routing table |

Because most identity and address keys are boot-captured, **changing them through the administrative API is not enough** — restart the workload.

### 3. Per-tenant runtime

In multi-tenant mode, Helm and the environment provide what a pod needs to initialise. Per-request configuration comes from the store, scoped to the calling organization, and fails closed. See [Multi-tenant configuration](#multi-tenant-configuration).

## Configuration precedence inside a pod

Within one workload, highest precedence first:

1. `<component>.extraEnvVars` — explicit env entries, which beat every `envFrom` source
2. the imported Secret — `<component>.secrets`, or your existing Secret
3. `<component>.configmap`

Set a key in only one of them unless you mean to override. The chart **fails the render** if the same key appears in both `extraEnvVars` and `secrets` with opposing values, because two deliberate overrides disagreeing is a mistake rather than a preference.

Two things this precedence does **not** mean:

- An open map means the chart forwards the key. It does **not** mean the binary reads or validates it. Unknown keys are ignored silently.
- When `useExistingSecret: true`, the inline `secrets` map is not rendered at all, so it is not a source — see [Production secret management](#production-secret-management).

The chart reserves the pod annotation carrying the ConfigMap/Secret checksum, which is what rolls the pods when configuration changes. Overriding it stops configuration updates from restarting pods, so the chart refuses it.

## Authentication

`PLUGIN_AUTH_ENABLED=true` with a resolvable `PLUGIN_AUTH_URL` mounts per-route authorization on the business and machine-to-machine routes of the workloads that carry it. It does not cover probes, OpenAPI routes, the `*Systemplane` administrative APIs, or the provider mock — those need network-level controls from your platform.

- **The default is `false`.** An operator who configures nothing gets an unauthenticated surface. Set it explicitly before exposing any route.
- **Keep `systemplaneIngress.enabled: false`,** which is the default. The administrative API reads and writes runtime configuration; treat it as operator-only and restrict it with NetworkPolicies or equivalent.
- **`ENV_NAME` is matched exactly.** OpenAPI and docs routes stay mounted unless it is the literal string `production`; `prod`, `Production`, or a trailing space all leave them served. Set `SWAGGER_ENABLED` explicitly to turn them off.
- **An unreachable `PLUGIN_AUTH_URL` denies requests rather than allowing them.** The URL format is not validated, so the symptom is a permissions failure at request time, not a boot failure.

## Ingress and service URLs

Three independent ingress surfaces, all `enabled: false` by default:

| Block | Publishes | Default posture |
|---|---|---|
| `appsIngress` | Client-facing application routes | Disabled |
| `systemplaneIngress` | Systemplane administrative routes | Disabled — **keep it disabled** |
| `providersIngress` | Provider-facing adapters | Disabled |

Each route names a component by its `values.yaml` key, which is the single source of the enabled flag, the Service name, and the backend port. Routes whose component is disabled are skipped. If you also set `serviceName`, it must name the same component, otherwise the render fails.

### In-cluster URLs

Use the full Service DNS name with the scheme, the port, and the route prefix.

**Resource names do not carry the release name.** Every workload's Deployment, Service, ConfigMap, and Secret is named `plugin-br-pix-lerian-<component>` regardless of the release name you install under; only `nameOverride` changes that prefix. The bundled subcharts behave the opposite way — their Services *are* release-prefixed (`<release-name>-postgresql`, `<release-name>-valkey-primary`).

```yaml
spi:
  configmap:
    DICT_BASE_URL: "http://plugin-br-pix-lerian-dict-hub:4104"
    COB_BASE_URL: "http://plugin-br-pix-lerian-cob-hub:4108"
    ADAPTER_BASE_URL: "http://plugin-br-pix-lerian-adapter-lerian:4113/lerian"
```

The route prefix matters. The adapter and provider addresses need theirs — `/lerian`, `/provider-mock`. The `*_BASE_URL` values for the hubs do not carry a path.

### Example topologies

**Hub topology** — the supported production shape:

```yaml
dictProxy: { enabled: false }
cobProxy: { enabled: false }
# leave the routing modes at their default `hub`
```

**Disabling a domain's optional workloads** — remember the schema consequence in [Effect of disabling a workload](#effect-of-disabling-a-workload):

```yaml
dictHubVsync: { enabled: false }
pixauto: { enabled: false }
pixautoSystemplane: { enabled: false }
```

**Proxy tier present** — configuration only. This does not give the proxy business routes; see [Hub and proxy are not interchangeable](#hub-and-proxy-are-not-interchangeable):

```yaml
dictProxy:
  enabled: true
  secrets:
    DATABASE_URL: "postgres://<user>:<password>@<postgres-host>:5432/pix-dict?sslmode=require"
    LICENSE_KEY: "<license-key>"
# Do not point client traffic here, and leave callers' routing modes at `hub`.
```

**Apps ingress with authentication:**

```yaml
appsIngress:
  enabled: true
  className: "nginx"
  hosts:
    - <apps-hostname>
  tls:
    - secretName: <kubernetes-secret-name>
      hosts:
        - <apps-hostname>

spi:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_URL: "<access-manager-url>"
```

## Install from OCI

```bash
helm registry login ghcr.io --username <registry-username>

kubectl create namespace <namespace>

helm upgrade --install <release-name> \
  oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm \
  --version <chart-version> \
  --namespace <namespace> \
  --values values.yaml \
  --wait --timeout 10m
```

`helm registry login` prompts for the token on stdin. **Do not pass a token on the command line** — it lands in your shell history and in the process list.

Get `<chart-version>` from the chart release, or from `Chart.yaml` in this directory. **Always pin it explicitly.** An unpinned install resolves to whatever is newest, which makes the deployed version unreproducible.

### Image pull secret

The images are private. Create a pull secret in the namespace and name it in `global.imagePullSecrets`, which every workload inherits when its own `imagePullSecrets` list is empty:

```bash
 kubectl create secret docker-registry <kubernetes-secret-name> \
   --namespace <namespace> \
   --docker-server=ghcr.io \
   --docker-username=<registry-username> \
   --docker-password='<token>'
```

```yaml
global:
  imagePullSecrets:
    - name: <kubernetes-secret-name>
```

### Installing from a source checkout

Useful for reviewing a render before it reaches a cluster:

```bash
helm dependency build charts/plugin-br-pix-lerian
helm lint charts/plugin-br-pix-lerian
helm template <release-name> charts/plugin-br-pix-lerian \
  --namespace <namespace> --values values.yaml
```

## Post-install verification

```bash
# Every workload in the release
kubectl get pods -n <namespace> -l app.kubernetes.io/instance=<release-name>

# Bootstrap and migration Jobs
kubectl get jobs -n <namespace> -l app.kubernetes.io/instance=<release-name>

# Recent events, newest last — the first place a failed install explains itself
kubectl get events -n <namespace> --sort-by=.lastTimestamp | tail -30

# Logs from a migration Job that did not succeed
kubectl logs -n <namespace> job/plugin-br-pix-lerian-spi-migrations

# Readiness from inside the cluster
kubectl port-forward -n <namespace> svc/plugin-br-pix-lerian-spi 4101:4101
curl --fail -sS http://localhost:4101/spi/readyz
```

Check that the Jobs you expected actually rendered. A migration Job that is absent is the common cause of a workload that starts but never becomes ready:

```bash
kubectl get jobs -n <namespace> -o name | grep migrations
```

## Health and readiness reference

Every workload serves liveness and readiness over HTTP on its Service port. Paths carry the workload's route prefix, **except `dictHubVsync`, which serves both at the root.**

Common checks are summarized below. The `readyz` response is the authoritative list for the active version, tenant mode, and configuration.

| Workload | Service port | Liveness | Readiness | Always probed | Probed when configured |
|---|---|---|---|---|---|
| `spi` | 4101 | `/spi/health` | `/spi/readyz` | `required_keys`; Postgres in single-tenant | adapter and Midaz, each when its base URL is set; notification outbox relay in multi-tenant with streaming on; streaming when enabled |
| `spiSystemplane` | 4102 | `/spi/health` | `/spi/readyz` | Postgres | — |
| `adapterProviderMock` | 4103 | `/provider-mock/health` | `/provider-mock/readyz` | — | its configured provider over HTTP |
| `dictHub` | 4104 | `/dict-hub/health` | `/dict-hub/readyz` | `required_keys`; Postgres in single-tenant | CRM and adapter, each when its base URL is set; Valkey when the cache connected at boot; notification outbox relay in multi-tenant with streaming on; streaming when enabled |
| `dictHubVsync` | 4105 | `/health` | `/readyz` | `required_keys`, Valkey; Postgres and RabbitMQ in single-tenant; `scheduler` and `chunk_consumer` during startup | CRM when its base URL is set; adapter in single-tenant when its base URL is set; `tenant_consumers` in multi-tenant |
| `dictProxy` | 4106 | `/dict-proxy/health` | `/dict-proxy/readyz` | `required_keys` | — |
| `dictSystemplane` | 4107 | `/dict/health` | `/dict/readyz` | Postgres | — |
| `cobHub` | 4108 | `/cob-hub/health` | `/cob-hub/readyz` | `required_keys`; Postgres in single-tenant | notification outbox relay in multi-tenant with streaming on; streaming when enabled |
| `cobProxy` | 4109 | `/cob-proxy/health` | `/cob-proxy/readyz` | `required_keys` | — |
| `cobSystemplane` | 4110 | `/cob/health` | `/cob/readyz` | Postgres | — |
| `adapterLerian` | 4113 | `/lerian/health` | `/lerian/readyz` | Postgres | — |
| `adapterLerianSystemplane` | 4115 | `/lerian/health` | `/lerian/readyz` | Postgres | — |
| `pixauto` | 4116 | `/pixauto/health` | `/pixauto/readyz` | Postgres, `required_keys` | `auth.url` when auth is on; streaming when enabled |
| `pixautoSystemplane` | 4117 | `/pixauto/health` | `/pixauto/readyz` | Postgres | — |

Note that a Systemplane workload's prefix is its **domain** prefix, not its own name: `dictSystemplane` answers under `/dict`, while `dictHub` answers under `/dict-hub`. Both `spi` and `spiSystemplane` answer under `/spi`, on different ports.

Reading the responses:

- **200 on `health`** means the process is up. It does **not** mean the workload can serve traffic.
- **200 on `readyz`** means the process is up and its checked dependencies are satisfied.
- **503 on `readyz`** means a check failed. The two right-hand columns above say which checks a workload runs; a conditional probe exists only when that dependency or feature is configured. Note that the proxy workloads gate on configuration keys only, and `adapterProviderMock` probes its provider rather than a database, so "Postgres is checked everywhere" is not true. **Read the `readyz` body** — it names each check and its status, and is authoritative for your version and configuration.
- Failure modes differ by check: `required_keys` means the configuration store has nothing for a key the workload needs; a Postgres, Valkey, or RabbitMQ check means the dependency is unreachable; an adapter, Midaz, CRM, provider, or `auth.url` check means an HTTP dependency did not answer; a notification outbox relay or streaming check means the event path is not healthy.
- **Tenant mode changes the set, it does not just change the values.** A check that depends on a deployment-wide connection pool is registered only when that pool exists, which in single-tenant it does and in multi-tenant it does not — per-tenant pools are resolved per request instead. That is why `spi`, `dictHub`, `cobHub`, and `dictHubVsync` carry a Postgres check in single-tenant and none in multi-tenant, and why `dictHubVsync` additionally drops its RabbitMQ and adapter checks there while gaining `tenant_consumers`. The relay check runs the other way round: it exists only in multi-tenant, and only with streaming enabled. A workload reporting ready in multi-tenant is therefore making a narrower claim than the same workload in single-tenant, and a tenant whose own configuration is missing still fails at the request, not at `readyz`.
- Readiness also gates on required configuration keys being present in the store. This is the usual reason a correctly configured pod stays 503 — the values were never seeded, or were never written for the tenant.
- `health` and `readyz` are unauthenticated on every workload. See [Authentication](#authentication).

## Troubleshooting

### Image will not pull

**Symptom** — `ImagePullBackOff` or `ErrImagePull`.

```bash
kubectl describe pod -n <namespace> <pod> | tail -20
```

**Cause** — no pull secret in the namespace, the secret is not named in `global.imagePullSecrets`, or the pinned tag does not exist.

**Fix** — create the pull secret in the same namespace and reference it. Confirm the tag exists for that component; remember each workload has its own image repository.

### Workload refuses to start, log names a variable

**Symptom** — `CrashLoopBackOff`, and the log's first lines name a variable.

```bash
kubectl logs -n <namespace> <pod> --previous | head -30
```

**Causes and fixes:**

| Message names | Fix |
|---|---|
| `LICENSE_KEY` | Set it, or use `DEPLOYMENT_MODE: "local"`. Required in every other mode. |
| the license client failing to initialise | Set `ORGANIZATION_IDS` on that workload — `global` for a single-license deployment. |
| `DATABASE_URL` / a Postgres DSN | Set `DATABASE_URL` or `SYSTEMPLANE_POSTGRES_DSN` per the [requirements table](#required-before-installation). |
| `SYSTEMPLANE_SECRET_MASTER_KEY` | Set a non-empty value on that Systemplane workload. |
| `MULTI_TENANT_URL` / `MULTI_TENANT_API_KEY` | Required when `MULTI_TENANT_ENABLED=true`. `dictSystemplane` and `cobSystemplane` need the keys added through their open maps. |
| `DEPLOYMENT_MODE` must be explicitly set | Set it on that workload. Multi-tenant does not accept an implicit mode. |
| `ORGANIZATION_ID` must be empty | Remove it from `cobHub` / `pixauto` in multi-tenant mode. |
| `PLUGIN_AUTH_ENABLED` must be true | On `pixauto` outside `local`/`development`, enable auth or set `ENV_NAME` accordingly. |
| `AUTH_JWT_VERIFY_CERT` / `AUTH_JWT_ISSUER` | Add both to `pixauto.secrets`. The chart does not ship them. |

Also check the mode value itself: it is matched **case-sensitively and untrimmed**, so `SAAS` or a trailing space is not the mode you meant.

### Existing Secret is missing a key

**Symptom** — `CreateContainerConfigError`, or a workload failing on a variable you believe you set.

**Cause** — the Secret does not exist yet, or it does not carry the key. **An existing Secret replaces the chart's Secret entirely; there is no merge**, so anything left in `<component>.secrets` is not applied.

```bash
kubectl get secret -n <namespace> <kubernetes-secret-name> -o jsonpath='{.data}' | tr ',' '\n'
```

**Fix** — put the complete set of that workload's secret keys into your Secret, and create it **before** `helm install`, because the migration hooks run first.

### `health` is 200 but `readyz` is 503

```bash
kubectl port-forward -n <namespace> svc/plugin-br-pix-lerian-spi 4101:4101
curl -sS http://localhost:4101/spi/readyz
```

**Causes** — a dependency check failing, or required configuration keys absent from the store.

**Fix** — if the response points at required keys, set the domain's identity and dependency values on the **Systemplane** workload, which is what seeds them. In multi-tenant see the next entry. If it points at Postgres, check the DSN and network reachability.

### Multi-tenant: a workload reports 503 under `required_keys`

**Symptom** — a workload is running but `readyz` returns 503 and names keys under `required_keys`.

**Cause** — the configuration store holds nothing for the keys that workload gates on. Environment seeding does not run in multi-tenant mode, so those values arrive by provisioning rather than from Helm values.

```bash
kubectl port-forward -n <namespace> svc/plugin-br-pix-lerian-spi 4101:4101
curl -sS http://localhost:4101/spi/readyz
```

**Fix** — provision the named keys for that domain, then restart the workload if the key is boot-captured (see [Systemplane configuration lifecycle](#systemplane-configuration-lifecycle)). The `readyz` body is authoritative about which keys are outstanding.

### Multi-tenant: requests return 403 `TENANT_CONFIG_NOT_FOUND`

**Cause** — the calling tenant has no configuration, is missing required keys, or the request carried no resolvable tenant. **There is no global fallback**; the path fails closed by design.

**Fix** — provision that tenant's configuration before sending traffic. The log line names the cause and the missing keys.

### Changing a value in `values.yaml` had no effect

**Cause** — one of three things:

1. The key is stored in the Systemplane store and an administrator already changed it. **The seed only replaces a value still at its registered default**, so a non-default value is preserved and your environment change is ignored.
2. The key is boot-captured. It was read once at boot, so it needs a pod restart.
3. The key is set in a higher-precedence source. `extraEnvVars` beats the Secret, which beats the ConfigMap.

**Fix** — for (1) change it through the administrative API; for (2) restart the workload after the change; for (3) remove the duplicate.

### A migration or bootstrap Job failed

```bash
kubectl get jobs -n <namespace>
kubectl logs -n <namespace> job/plugin-br-pix-lerian-<component>-migrations
kubectl get events -n <namespace> --sort-by=.lastTimestamp | tail -30
```

**Causes and fixes:**

- **The Job is absent.** The DSN is empty and `useExistingSecret` is false, so the chart skipped it — the schema was never applied. Set `secrets.DATABASE_URL`.
- **The migration Job cannot connect.** Migrations run as a `pre-install`/`pre-upgrade` hook, ahead of every normal resource, so the server in the DSN has to be reachable already. On a first install this points at either a database that was never provisioned, or a DSN aimed at the bundled `postgresql` subchart — which is a normal resource and is not running yet at that point. See [Migration Jobs](#migration-jobs) for the two-step flow that covers the subchart case.
- **Authentication failure on a bootstrap Job.** Check the admin credentials. Empty inline values fail at render, so a runtime failure points at wrong values or missing privileges.
- **`invalid command \getenv`.** The bootstrap image is older than psql 15. The chart pins `postgres:17`; a pull-through mirror or an override may be serving something older.
- **A lock timeout.** A sibling Job held the advisory lock for more than 60 seconds. Re-run the upgrade once the contending Job has finished.
- **A hook blocking the release.** `--wait` waits for hook Jobs; raise `--timeout` for large schema changes.

### Requests return 404 through the ingress

**Cause** — a wrong path prefix. Each workload answers only under its own prefix, and a Systemplane workload's prefix is its **domain** prefix, not its name. Alternatively, traffic is reaching a proxy workload, which serves no business routes.

**Fix** — check the [health and readiness table](#health-and-readiness-reference) for the correct prefix, and confirm the route's backend is the hub.

### Valkey was unavailable at boot and the workload is silently degraded

**Symptom** — `dictHub` reports ready and serves traffic, but cache-dependent behaviour never works and one route consistently fails, while the logs show a warning about the cache from startup only.

**Cause** — `dictHub` establishes its cache connection at startup and only registers the readiness check when that succeeded. A Valkey that was down **at boot** leaves the pod without a client for its whole lifetime, and readiness stays green. `spi`, `cobHub`, and `pixauto` connect on first use, so they recover on their own.

**Fix** — restart `dictHub` once Valkey is reachable. When ordering matters, bring Valkey up before the workload.

### Valkey or RabbitMQ unavailable

- **`dictHubVsync`** requires both. It will not start without them; the render itself fails without `RABBITMQ_URI`.
- **`spi`, `dictHub`, `cobHub`, `pixauto`** degrade rather than fail: caches turn off and gated mutations fall back to their durable backstops. A small number of routes fail closed with 503 rather than proceed without the cache.
- **`dictHub`'s RabbitMQ** is publish-only and off unless configured; if the broker is unavailable it warns and continues on its backstop.

### Ingress is exposed without authentication

**Symptom** — an ingress is published while `PLUGIN_AUTH_ENABLED` is false.

**Cause** — the chart fails the render for one workload published without authentication, and renders successfully for every other. Do not read a successful render as proof that the published surface is protected.

That check also has a blind spot: with `<component>.useExistingSecret: true` the chart cannot read your Secret, so it cannot determine the effective value and stays silent. In that configuration the external Secret **must** carry `PLUGIN_AUTH_ENABLED` set to a true value. Setting the key in `<component>.extraEnvVars` instead keeps the check effective, because explicit env entries outrank every `envFrom` source.

**Fix** — set `PLUGIN_AUTH_ENABLED: "true"` and a resolvable `PLUGIN_AUTH_URL` on every published workload, keep `systemplaneIngress.enabled: false`, and restrict the administrative surface at the network layer.

## Upgrade and rollback

Before upgrading:

1. **Pin both versions.** Record the currently deployed chart version and the target. `helm list -n <namespace>` and `helm history <release-name> -n <namespace>`.
2. **Read `CHANGELOG.md`** in this directory and the [compatibility table](#compatibility).
3. **Back up the databases** whenever the target includes schema changes. This is the only reliable way back.
4. **Review what the upgrade will do**, either from a render or with `helm diff` if that plugin is installed. It is not required.

```bash
helm upgrade <release-name> \
  oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm \
  --version <chart-version> \
  --namespace <namespace> \
  --values values.yaml \
  --wait --timeout 10m
```

Migration hooks run **before** the new pods roll out, so a failing migration blocks the release rather than leaving a partial rollout.

### Rollback

```bash
helm history <release-name> -n <namespace>
kubectl get jobs -n <namespace>            # inspect hooks before rolling back
helm rollback <release-name> <revision> -n <namespace> --wait
```

What a rollback does:

- It **restores the manifests of the revision you select**. Nothing more.
- It does **not re-run the migration Job.** Helm has its own `pre-rollback` and `post-rollback` hooks, and this chart declares neither, so no migration hook fires on a rollback. Do not read the `pre-upgrade` weights above as rollback behaviour.
- It does **not revert database schema or data.** Migrations that already ran stay applied, and rows written under the newer schema stay written.

The consequence is the one that decides whether a rollback is usable at all: **the image you roll back to has to be compatible with the schema that is already applied.** Where it is, the rollback is a clean way back. Where it is not, restoring the manifests will not make the older binary work, and recovering needs a database procedure of its own — a restore from the backup you took before upgrading, or a hand-applied down migration — planned with the schema change in front of you. That is why the pre-upgrade checklist above asks for a backup whenever the target carries schema changes.

Adding a rollback hook is not a fix for this and the chart deliberately does not have one: it would run the target revision's migrations forward again, which is not what reverting a schema means.

Inspect hook Jobs before rolling back, so you know which migration last ran. A failed migration Job is kept rather than cleaned up, precisely so its log is still there.

Keep `SYSTEMPLANE_SECRET_MASTER_KEY` unchanged across upgrades and rollbacks — it is checked at every boot, so a revision that does not carry it will not start.

## Uninstall and residual resources

```bash
helm uninstall <release-name> --namespace <namespace>
```

What uninstall does **not** remove:

- **Databases, schemas, and data.** Nothing in the chart drops them. Uninstalling and reinstalling reuses the existing databases.
- **`plugin-br-pix-lerian-<component>-migrations` Secrets.** These are hook resources, and Helm does not track hook resources as release resources. They are also left behind if you clear `DATABASE_URL` or disable migrations on a release that already created them. Each carries the same DSN the application Secret held.
- **Secrets you created yourself** — existing Secrets and image pull secrets are yours to manage.
- **PersistentVolumeClaims from the local subcharts**, if you enabled them.

Find residual resources before deleting anything:

```bash
# 1. Workloads this chart owns. They carry the chart's part-of label.
kubectl get all,secret,configmap -n <namespace> \
  -l app.kubernetes.io/part-of=plugin-br-pix-lerian

# 2. Everything tied to the release, which includes the subcharts. Their
#    resources do NOT carry the label above.
kubectl get all,pvc,secret -n <namespace> \
  -l app.kubernetes.io/instance=<release-name>

# 3. Subchart PersistentVolumeClaims specifically — these outlive uninstall.
kubectl get pvc -n <namespace>

# 4. Migration Secrets, which Helm leaves behind.
kubectl get secret -n <namespace> -o name | grep migrations

# 5. Secrets you created yourself are not labelled by the chart at all.
#    Identify them from your own values: existingSecretName and the image
#    pull secret named in global.imagePullSecrets.
```

Delete the migration Secrets individually once you have confirmed what they are:

```bash
kubectl delete secret -n <namespace> plugin-br-pix-lerian-<component>-migrations
```

Do not delete the namespace or run a broad label-based delete without inspecting the list first — the namespace may hold resources from other releases, and your own Secrets live there too.

## Development-only local dependencies

For development, the chart can run PostgreSQL, Valkey, and RabbitMQ in-cluster:

```yaml
postgresql: { enabled: true }
valkey: { enabled: true }
rabbitmq: { enabled: true }
```

**Development only.** These are not configured for production durability, backup, or availability. In production leave them disabled — which is the default — and point the workloads at managed services.

When you enable the PostgreSQL subchart and want the chart to create the five databases, set `global.externalPostgresDefinitions.enabled: true` and point `connection.host` at the subchart's Service. That Service **is** release-prefixed, so for a release named `<release-name>` it is `<release-name>-postgresql` — not `plugin-br-pix-lerian-postgresql`, which does not exist. The Valkey subchart follows the same rule (`<release-name>-valkey-primary`).

`adapterProviderMock` and the `adapterLerian` pair are also development-only in this release; see [Supported topologies and current limitations](#supported-topologies-and-current-limitations).

## Useful commands

```bash
# Render one workload's Deployment
helm template <release-name> charts/plugin-br-pix-lerian \
  | yq 'select(.kind=="Deployment" and .metadata.name=="plugin-br-pix-lerian-spi")'

# Which workloads a values file actually enables
helm template <release-name> charts/plugin-br-pix-lerian --values values.yaml \
  | yq -r 'select(.kind=="Deployment") | .metadata.name'

# All chart-managed pods
kubectl get pods -n <namespace> -l app.kubernetes.io/part-of=plugin-br-pix-lerian

# Follow one workload's logs
kubectl logs -n <namespace> -l app.kubernetes.io/component=spi -f
```
