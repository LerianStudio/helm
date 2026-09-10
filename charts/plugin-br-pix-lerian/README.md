# plugin-br-pix-lerian (Helm chart)

## Chart Contract

- Chart type: `multi-component`
- Required secrets: None for the default render, which is **not** a working installation. A working installation requires per-component Postgres DSNs, `LICENSE_KEY` outside `local` mode, and `SYSTEMPLANE_SECRET_MASTER_KEY` on the Systemplane components in the modes listed under [Required before installation](#required-before-installation). Credential-bearing DSNs, URLs, tokens, and passwords belong in a component's `secrets` block or an existing Secret — never in `configmap`.
- Dependency notes: PostgreSQL, Valkey, and RabbitMQ ship as local subcharts that are **disabled by default**. Production points the components at externally managed services.
- Production overrides: Per-component `secrets` (or `useExistingSecret` + `existingSecretName`), `global.externalPostgresDefinitions`, `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_URL`, and the ingress blocks. An existing Secret **replaces** the chart-rendered Secret for that component; it is not merged.
- Source/license: Source is in [github.com/LerianStudio/helm](https://github.com/LerianStudio/helm); license is Apache-2.0.

## Overview

BACEN-compliant Pix platform for the Lerian ecosystem.

This chart manages 14 independently deployable Pix Lerian workloads. Each one gets its own Deployment, Service, ConfigMap, Secret, ServiceAccount, and — where configured — HPA and PodDisruptionBudget. Ingress is opt-in and disabled by default on all three ingress surfaces.

Read [Supported topologies and current limitations](#supported-topologies-and-current-limitations) before choosing which workloads to enable. Two of them are not usable outside a local environment in this release, and two more serve no business routes.

## Compatibility

| Chart version | App image tag |
|---|---|
| 2.1.0-beta.2 | 1.0.0-beta.318 |

The row above covers this chart only. There is no in-place upgrade path from the retired `plugin-br-pix-switch` chart — moving to this chart is a fresh install (cutover), not a `helm upgrade`. A cutover does not migrate or copy data; see [Upgrade and rollback](#upgrade-and-rollback).

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

Each domain (DICT, COB) has a hub tier and a proxy tier. **They do not have equivalent APIs.**

| | DICT Hub | DICT Proxy | COB Hub | COB Proxy |
|---|---|---|---|---|
| Business routes | 53 | **0** | 12 | **0** |
| Internal callback routes | yes | **0** | yes | **0** |
| Admin routes | yes | **0** | none | **0** |
| `health`, `readyz`, OpenAPI | yes | yes | yes | yes |

In this release `dictProxy` and `cobProxy` are scaffolding. They serve `health`, `readyz`, and an OpenAPI document that declares no operations, and they contain no request-forwarding logic. **Choosing the proxy tier does not deliver functional parity, and it does not fall back to the hub.**

If you route client traffic at a proxy:

- Every business request returns 404. There is no forwarding and no fallback.
- `health` and `readyz` still return 200, so monitoring stays green while the rail is dead.
- Setting a routing mode to `proxy` on a **caller** redirects that caller at the proxy tier and breaks the corresponding flows: on `spi`, `DICT_ROUTING_MODE=proxy` breaks key-initiated flows and `COB_ROUTING_MODE=proxy` breaks QR-code initiation; on `cobHub`, `DICT_ROUTING_MODE=proxy` breaks the DICT lookups that gate charge creation.
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

Three more settings have no default and cannot get one, because they identify *your* sandbox access. You receive them together with that access:

| Setting | Where | Notes |
|---|---|---|
| `PROVIDER_CLIENT_ID` | `secrets` | **Required** — the component does not start without it |
| `PROVIDER_CLIENT_SECRET` | `secrets` | **Required** — the component does not start without it |
| `ADAPTER_ISPB` | `configmap` | The ISPB the mock presents as the provider |

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
5. `LICENSE_KEY` and `ORGANIZATION_IDS` set on every enabled workload if `DEPLOYMENT_MODE` is not `local`.
6. `SYSTEMPLANE_SECRET_MASTER_KEY` set on the Systemplane workloads that require it in your mode.
7. `RABBITMQ_URI` set if `dictHubVsync` is enabled.
8. `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_URL` decided; `systemplaneIngress.enabled` left `false`.
9. Chart version pinned.

### Minimum single-tenant path

```yaml
# minimal.yaml — hub topology, external Postgres, no ingress.
global:
  imagePullSecrets:
    - name: <kubernetes-secret-name>

spi:
  configmap:
    DEPLOYMENT_MODE: "byoc"
    ORGANIZATION_ID: "<organization-id>"
    ISPB: "<8-digit-ispb>"
    ORGANIZATION_IDS: "global"
    DICT_BASE_URL: "http://<release-name>-dict-hub:4104"
    COB_BASE_URL: "http://<release-name>-cob-hub:4108"
  secrets:
    DATABASE_URL: "postgres://<user>:<password>@<postgres-host>:5432/pix-spi?sslmode=require"
    LICENSE_KEY: "<license-key>"

spiSystemplane:
  configmap:
    ORGANIZATION_IDS: "global"
  secrets:
    DATABASE_URL: "postgres://<user>:<password>@<postgres-host>:5432/pix-spi?sslmode=require"
    LICENSE_KEY: "<license-key>"

dictHub:
  configmap:
    DEPLOYMENT_MODE: "byoc"
    ORGANIZATION_ID: "<organization-id>"
    ISPB: "<8-digit-ispb>"
    ORGANIZATION_IDS: "global"
  secrets:
    DATABASE_URL: "postgres://<user>:<password>@<postgres-host>:5432/pix-dict?sslmode=require"
    LICENSE_KEY: "<license-key>"

dictSystemplane:
  configmap:
    ORGANIZATION_IDS: "global"
  secrets:
    DATABASE_URL: "postgres://<user>:<password>@<postgres-host>:5432/pix-dict?sslmode=require"
    LICENSE_KEY: "<license-key>"

cobHub:
  configmap:
    DEPLOYMENT_MODE: "byoc"
    ORGANIZATION_ID: "<organization-id>"
    ORGANIZATION_IDS: "global"
  secrets:
    DATABASE_URL: "postgres://<user>:<password>@<postgres-host>:5432/pix-cob?sslmode=require"
    LICENSE_KEY: "<license-key>"

cobSystemplane:
  configmap:
    ORGANIZATION_IDS: "global"
  secrets:
    DATABASE_URL: "postgres://<user>:<password>@<postgres-host>:5432/pix-cob?sslmode=require"
    LICENSE_KEY: "<license-key>"

# Not usable outside a local environment in this release.
adapterLerian: { enabled: false }
adapterLerianSystemplane: { enabled: false }
adapterProviderMock: { enabled: false }

postgresql: { enabled: false }
valkey: { enabled: false }
rabbitmq: { enabled: false }
```

This is a starting point for a reachable, licensed deployment with the schemas applied. It has authentication **off** — see [Authentication and network boundaries](#authentication-and-network-boundaries) before exposing anything.

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
| `cobHub` | `pix-cob` — **Required** (single-tenant) | `pix-cob` | Optional — **key not shipped** | — | Optional, off | apps |
| `cobProxy` | `pix-cob` — **Required** | `pix-cob` | — | — | — | apps |
| `cobSystemplane` | — | `pix-cob` — **Required** | — | — | — | systemplane |
| `adapterLerian` | none | `pix-adapter-lerian` — **Required** | Required when enabled | — | — | providers |
| `adapterLerianSystemplane` | — | `pix-adapter-lerian` — **Required** | — | — | — | systemplane |
| `pixauto` | `pix-pixauto` — **Required** (single-tenant) | `pix-pixauto` — **Required** | Optional, degrades | — | Optional, off | apps |
| `pixautoSystemplane` | — | `pix-pixauto` — **Required** | — | — | — | systemplane |

Notes on the entries above:

- **`cobHub` and Valkey.** `cobHub` reads `VALKEY_URL`, but **the chart does not ship the key** in `cobHub.secrets`. To enable the cache, add `VALKEY_URL` through that component's `secrets` block. Without it, `cobHub` runs with the cache off and no route fails; a retried request may re-execute.
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

Set these before `helm install`. "Required" means the workload **fails to start** without it.

| Setting | Where | Required when |
|---|---|---|
| `DEPLOYMENT_MODE` | `configmap` | Accepts `local`, `byoc`, `saas`, lower-case and untrimmed. **Required to be set explicitly** on `spi`, `dictHub`, `dictProxy`, `cobHub`, `cobProxy`, `pixauto` when `MULTI_TENANT_ENABLED=true`. Chart default is `byoc`. |
| `LICENSE_KEY` | `secrets` | **Required** whenever `DEPLOYMENT_MODE` is anything other than `local`. Empty is tolerated only in `local`. The chart ships the key on all 14 workloads. |
| `ORGANIZATION_IDS` | `configmap` | **Required together with `LICENSE_KEY`** — the license client refuses to initialise without it. Use `global` for a single-license deployment. The chart ships the key only on `adapterLerian` and `pixauto`; add it to every other workload where you set `LICENSE_KEY`. |
| `ORGANIZATION_ID` | `configmap` | Single-tenant business identity. Applies to `spi`, `dictHub`, `dictHubVsync`, `cobHub`. **Must be empty** when `MULTI_TENANT_ENABLED=true` on `cobHub` and `pixauto` — a value there refuses the boot. Not read by `dictProxy` or `pixauto`; the chart ships it there for parity only. Not interchangeable with `ORGANIZATION_IDS`. |
| `ISPB` | `configmap` | Single-tenant identity on `spi`, `dictHub`, `dictHubVsync`. Required to reach ready — see [Health and readiness reference](#health-and-readiness-reference). |
| `DATABASE_URL` | `secrets` | **Required** on `spi`, `dictHub`, `dictProxy`, `cobProxy` in every mode. **Required in single-tenant only** on `cobHub`, `dictHubVsync`, `pixauto`. Not used by `adapterLerian`, `adapterProviderMock`. |
| `SYSTEMPLANE_POSTGRES_DSN` | `secrets` | On the five Systemplane workloads, **one of** this or `DATABASE_URL` is required, and this one **wins** when both are set. **Required** on `adapterLerian` and `pixauto`. On other workloads it is optional and falls back to `DATABASE_URL`. |
| `SYSTEMPLANE_SECRET_MASTER_KEY` | `secrets` | **Required, and must be non-empty**, on `spiSystemplane`, `dictSystemplane`, `cobSystemplane`, `pixautoSystemplane` whenever `ENV_NAME` is not `local` or `development`; and on `adapterLerianSystemplane` whenever `DEPLOYMENT_MODE` is not `local`. Note the two gates differ. See [the note below](#about-systemplane_secret_master_key). |
| `MULTI_TENANT_ENABLED` | `configmap` | Defaults to `false`. See [Multi-tenant configuration](#multi-tenant-configuration). |
| `MULTI_TENANT_URL`, `MULTI_TENANT_API_KEY` | `configmap` / `secrets` | **Required when `MULTI_TENANT_ENABLED=true`** on the five Systemplane workloads, `cobHub`, `dictHubVsync`, `pixauto`, `adapterLerian`. `dictSystemplane` and `cobSystemplane` do **not** ship these keys — add them through the open maps. |
| `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_URL` | `configmap` | Defaults to `false` / an in-cluster placeholder. When enabled, `PLUGIN_AUTH_URL` **must be non-empty** or the workload refuses to start. **Required to be `true`** on `pixauto` whenever `ENV_NAME` is not `local` or `development`. |
| `AUTH_JWT_VERIFY_CERT`, `AUTH_JWT_ISSUER` | `secrets` | **Required on `pixauto`** when `PLUGIN_AUTH_ENABLED=true` and `ENV_NAME` is not `local` or `development`. **The chart does not ship these keys** — add them through `pixauto.secrets`. Without them the workload refuses to start. |
| `RABBITMQ_URI` | `secrets` | **Required when `dictHubVsync` is enabled.** The render fails without it. |
| `PROVIDER_CLIENT_ID`, `PROVIDER_CLIENT_SECRET` | `secrets` | **Required when `adapterProviderMock` is enabled** — it does not start without both. Issued with your sandbox access; see [`adapterProviderMock`](#adapterprovidermock--development-only). |
| `VALKEY_URL` | `secrets` | **Required** on `dictHubVsync`. Optional elsewhere; not shipped for `cobHub`. |
| `ADAPTER_BASE_URL` | `configmap` | Optional at boot — it is not validated at startup. A missing value surfaces as rejected requests at runtime, not as a failed rollout. Include the provider's route prefix. |

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

- **The existing Secret replaces the chart-rendered Secret entirely. There is no merge.** When `useExistingSecret: true`, the chart does not render `<release-name>-spi` at all and the pod's `envFrom` points only at your Secret. Anything you left in `spi.secrets` is silently not applied.
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

The Jobs are **regular resources**, not hooks. On install they run alongside the rest of the release and before the migration hooks; on upgrade the migration hooks run first, by which point the databases already exist.

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

Hook ordering:

| Resource | Hook | Weight | Delete policy |
|---|---|---|---|
| `<release-name>-<component>-migrations` Secret | `pre-install,pre-upgrade` | `-10` | `before-hook-creation` |
| `<release-name>-<component>-migrations` Job | `pre-upgrade,post-install` | `-5` | `before-hook-creation,hook-succeeded` |

The Secret carries only `DATABASE_URL`, one weight earlier than the Job so it is guaranteed to exist when the Job runs. It is **not** rendered when `useExistingSecret: true` — the Job reads your Secret directly, which is why that Secret must exist before install.

`helm upgrade --wait` waits for hook Jobs to succeed before proceeding, so a failing migration blocks the release. Raise `--timeout` for large schema changes.

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

### Multi-tenant needs an administrative step before readiness

**Helm and environment values are not sufficient to bring a multi-tenant deployment to ready.** The store seeding described in [Systemplane configuration lifecycle](#systemplane-configuration-lifecycle) does not run in multi-tenant mode, but `spi`, `cobHub`, `cobProxy`, and `dictProxy` still gate readiness on their global configuration slots. Those slots stay at their defaults, so those four workloads report **503 under `required_keys`** until an operator writes the values through the Systemplane administrative API. `dictHub` and `dictHubVsync` do not gate this way.

Plan for that write as an explicit provisioning step. See [Troubleshooting](#troubleshooting) for the symptom.

### The request path fails closed

Per-tenant configuration is resolved from the store on every request, keyed by the calling tenant. **There is no global fallback.** A request whose tenant configuration is missing or incomplete is rejected with **HTTP 403 and code `TENANT_CONFIG_NOT_FOUND`**, and a request arriving without a resolvable tenant is refused before any read. The log line names the cause and the missing keys, never the values.

Provision each tenant's configuration before sending it traffic. `spi` needs its identity trio, four credential pairs, and the ledger identifier; `dictHub` needs the identity trio plus its CRM address and credential pair; `cobHub` needs the identity trio.

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
| Per-request | Read on every request | Per-tenant identity and credentials, the Pix Automático QR domain allowlist, the adapter's routing table |

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

## Authentication and network boundaries

`PLUGIN_AUTH_ENABLED=true`, plus a resolvable `PLUGIN_AUTH_URL`, is what mounts per-route authorization on the **business and internal machine-to-machine routes** of `spi`, `dictHub`, `cobHub`, `pixauto`, and `adapterLerian`.

**It does not protect everything.** These surfaces are not covered by that flag and need network-level controls from your platform:

| Surface | Covered by `PLUGIN_AUTH_ENABLED`? |
|---|---|
| Business routes on `spi`, `dictHub`, `cobHub`, `pixauto`, `adapterLerian` | Yes |
| Internal machine-to-machine routes on those workloads | Yes |
| `health` and `readyz` on every workload | **No** |
| OpenAPI and docs routes | **No** |
| The five `*Systemplane` administrative APIs | **No** |
| `adapterProviderMock` | **No** |

Consequences to design around:

- **The Systemplane administrative surface is not protected by application authentication.** Keep `systemplaneIngress.enabled: false`, which is the default, and restrict access with NetworkPolicies or equivalent platform controls. Treat it as operator-only. Do not publish it to a shared or public ingress.
- **`PLUGIN_AUTH_ENABLED=false` is not an acceptable posture for a publicly exposed production deployment.** With auth off, authorization is not merely bypassed — the middleware is not in the route chain at all, for reads and mutations alike, and nothing downstream compensates. The default is `false`, so an operator who configures nothing gets an unauthenticated surface.
- **Only Pix Automático has a render-time guard.** If `appsIngress` publishes a `pixauto` route while the effective `PLUGIN_AUTH_ENABLED` for that workload is not true, the chart **fails the render**. For every other workload, enabling ingress without authentication renders successfully and is the operator's responsibility.
- **That guard has a blind spot.** With `pixauto.useExistingSecret: true` the chart cannot read your Secret, so it cannot determine the value and stays silent. In that configuration your Secret **must** carry `PLUGIN_AUTH_ENABLED` set to a true value whenever a `pixauto` route is published. Setting the key in `pixauto.extraEnvVars` instead keeps the guard effective, because explicit env entries outrank every `envFrom` source.
- **`appsIngress` refuses to publish the Pix Automático internal callback group.** A route that would expose `/pixauto/internal/v1/*` fails the render. Use `/pixauto/v1` for the client-facing surface, which is what `values.yaml` ships.
- If `PLUGIN_AUTH_URL` points somewhere unreachable while auth is enabled, requests are **denied**, not allowed. The symptom is a permissions failure rather than a boot failure; the URL's format is not validated.
- OpenAPI and docs routes are mounted unless `ENV_NAME` is exactly `production` — an **exact string match**, so `prod`, `Production`, `staging`, or a trailing space all leave them mounted. Set `SWAGGER_ENABLED` explicitly if you need them off.
- `pixauto` additionally accepts `IDP_*` settings for permission declaration. Leave `IDP_DECLARATION_ENABLED` at `"false"` until an M2M application is registered for this service in your Access Manager.

## Ingress and service URLs

Three independent ingress surfaces, all `enabled: false` by default:

| Block | Publishes | Default posture |
|---|---|---|
| `appsIngress` | Client-facing application routes | Disabled |
| `systemplaneIngress` | Systemplane administrative routes | Disabled — **keep it disabled** |
| `providersIngress` | Provider-facing adapters | Disabled |

Each route names a component by its `values.yaml` key, which is the single source of the enabled flag, the Service name, and the backend port. Routes whose component is disabled are skipped. If you also set `serviceName`, it must name the same component, otherwise the render fails.

### In-cluster URLs

Use the full Service DNS name with the scheme, the port, and the route prefix. With the default naming, Services are `<release-name>-<component>`:

```yaml
spi:
  configmap:
    DICT_BASE_URL: "http://<release-name>-dict-hub:4104"
    COB_BASE_URL: "http://<release-name>-cob-hub:4108"
    ADAPTER_BASE_URL: "http://<release-name>-adapter-lerian:4113/lerian"
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
kubectl logs -n <namespace> job/<release-name>-spi-migrations

# Readiness from inside the cluster
kubectl port-forward -n <namespace> svc/<release-name>-spi 4101:4101
curl --fail -sS http://localhost:4101/spi/readyz
```

Check that the Jobs you expected actually rendered. A migration Job that is absent is the common cause of a workload that starts but never becomes ready:

```bash
kubectl get jobs -n <namespace> -o name | grep migrations
```

## Health and readiness reference

Every workload serves liveness and readiness over HTTP on its Service port. Paths carry the workload's route prefix, **except `dictHubVsync`, which serves both at the root.**

| Workload | Service port | Liveness | Readiness |
|---|---|---|---|
| `spi` | 4101 | `/spi/health` | `/spi/readyz` |
| `spiSystemplane` | 4102 | `/spi/health` | `/spi/readyz` |
| `adapterProviderMock` | 4103 | `/provider-mock/health` | `/provider-mock/readyz` |
| `dictHub` | 4104 | `/dict-hub/health` | `/dict-hub/readyz` |
| `dictHubVsync` | 4105 | `/health` | `/readyz` |
| `dictProxy` | 4106 | `/dict-proxy/health` | `/dict-proxy/readyz` |
| `dictSystemplane` | 4107 | `/dict/health` | `/dict/readyz` |
| `cobHub` | 4108 | `/cob-hub/health` | `/cob-hub/readyz` |
| `cobProxy` | 4109 | `/cob-proxy/health` | `/cob-proxy/readyz` |
| `cobSystemplane` | 4110 | `/cob/health` | `/cob/readyz` |
| `adapterLerian` | 4113 | `/lerian/health` | `/lerian/readyz` |
| `adapterLerianSystemplane` | 4115 | `/lerian/health` | `/lerian/readyz` |
| `pixauto` | 4116 | `/pixauto/health` | `/pixauto/readyz` |
| `pixautoSystemplane` | 4117 | `/pixauto/health` | `/pixauto/readyz` |

Note that a Systemplane workload's prefix is its **domain** prefix, not its own name: `dictSystemplane` answers under `/dict`, while `dictHub` answers under `/dict-hub`. Both `spi` and `spiSystemplane` answer under `/spi`, on different ports.

Reading the responses:

- **200 on `health`** means the process is up. It does **not** mean the workload can serve traffic.
- **200 on `readyz`** means the process is up and its checked dependencies are satisfied.
- **503 on `readyz`** means a dependency check failed. Postgres is checked on every workload. Valkey is checked on `dictHub` and `dictHubVsync` only. RabbitMQ is checked on `dictHubVsync` in single-tenant only. Streaming never blocks readiness.
- Readiness also gates on required configuration keys being present in the store. This is the usual reason a correctly configured pod stays 503 — the values were never seeded, or were never written for the tenant.
- `health` and `readyz` are unauthenticated on every workload. See [Authentication and network boundaries](#authentication-and-network-boundaries).

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
kubectl port-forward -n <namespace> svc/<release-name>-spi 4101:4101
curl -sS http://localhost:4101/spi/readyz
```

**Causes** — a dependency check failing, or required configuration keys absent from the store.

**Fix** — if the response points at required keys, set the domain's identity and dependency values on the **Systemplane** workload, which is what seeds them. In multi-tenant see the next entry. If it points at Postgres, check the DSN and network reachability.

### Multi-tenant: several workloads stay 503 after a clean install

**Symptom** — `spi`, `cobHub`, `cobProxy`, and `dictProxy` report 503 under required keys, while `dictHub` is ready.

**Cause** — store seeding does not run in multi-tenant mode, but those four workloads still gate readiness on their global configuration slots, which stay at their defaults.

**Fix** — write those values through the domain's Systemplane administrative API as an explicit provisioning step. Helm values alone will not clear this. Restart the workload afterwards if the key is boot-captured.

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
kubectl logs -n <namespace> job/<release-name>-<component>-migrations
kubectl get events -n <namespace> --sort-by=.lastTimestamp | tail -30
```

**Causes and fixes:**

- **The Job is absent.** The DSN is empty and `useExistingSecret` is false, so the chart skipped it — the schema was never applied. Set `secrets.DATABASE_URL`.
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

**Cause** — only Pix Automático has a render-time guard. Every other workload renders successfully in that state.

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

> **A chart rollback does not revert database schema or data.** Helm restores manifests. Migrations that already ran stay applied, and rows written under the newer schema stay written. If the target revision's application cannot read the current schema, rolling back the chart will not make it work — restore from backup instead.

Inspect hook Jobs before rolling back. A rollback triggers the `pre-upgrade` hooks of the target revision, so a migration Job runs again with the older image.

Keep `SYSTEMPLANE_SECRET_MASTER_KEY` unchanged across upgrades and rollbacks — it is checked at every boot, so a revision that does not carry it will not start.

## Uninstall and residual resources

```bash
helm uninstall <release-name> --namespace <namespace>
```

What uninstall does **not** remove:

- **Databases, schemas, and data.** Nothing in the chart drops them. Uninstalling and reinstalling reuses the existing databases.
- **`<release-name>-<component>-migrations` Secrets.** These are hook resources, and Helm does not track hook resources as release resources. They are also left behind if you clear `DATABASE_URL` or disable migrations on a release that already created them. Each carries the same DSN the application Secret held.
- **Secrets you created yourself** — existing Secrets and image pull secrets are yours to manage.
- **PersistentVolumeClaims from the local subcharts**, if you enabled them.

Find residual resources before deleting anything:

```bash
kubectl get all,secret,pvc,job -n <namespace> \
  -l app.kubernetes.io/part-of=plugin-br-pix-lerian

kubectl get secret -n <namespace> -o name | grep migrations
```

Delete the migration Secrets individually once you have confirmed what they are:

```bash
kubectl delete secret -n <namespace> <release-name>-<component>-migrations
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

When you enable the PostgreSQL subchart and want the chart to create the five databases, set `global.externalPostgresDefinitions.enabled: true` and point `connection.host` at the subchart's Service.

`adapterProviderMock` and the `adapterLerian` pair are also development-only in this release; see [Supported topologies and current limitations](#supported-topologies-and-current-limitations).

## Useful commands

```bash
# Render one workload's Deployment
helm template <release-name> charts/plugin-br-pix-lerian \
  | yq 'select(.kind=="Deployment" and .metadata.name=="<release-name>-spi")'

# Which workloads a values file actually enables
helm template <release-name> charts/plugin-br-pix-lerian --values values.yaml \
  | yq -r 'select(.kind=="Deployment") | .metadata.name'

# All chart-managed pods
kubectl get pods -n <namespace> -l app.kubernetes.io/part-of=plugin-br-pix-lerian

# Follow one workload's logs
kubectl logs -n <namespace> -l app.kubernetes.io/component=spi -f
```
