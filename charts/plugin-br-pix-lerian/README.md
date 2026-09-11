# plugin-br-pix-lerian (Helm chart)

## Chart Contract

- Chart type: `multi-component`
- Required secrets: None for the default render, which is **not** a working installation. A working installation requires per-component Postgres DSNs, `LICENSE_KEY` outside `local` mode, and `SYSTEMPLANE_SECRET_MASTER_KEY` on the Systemplane components in the modes listed under [Required before installation](#required-before-installation). Credential-bearing DSNs, URLs, tokens, and passwords belong in a component's `secrets` block or an existing Secret — never in `configmap`.
- Dependency notes: PostgreSQL, Valkey, and RabbitMQ ship as local subcharts that are **disabled by default**. Production points the components at externally managed services.
- Production overrides: Per-component `secrets` (or `useExistingSecret` + `existingSecretName`), `global.externalPostgresDefinitions`, `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_URL`, and the ingress blocks. An existing Secret **replaces** the chart-rendered Secret for that component; it is not merged.
- Source/license: Source is in [github.com/LerianStudio/helm](https://github.com/LerianStudio/helm); chart license is Apache-2.0.

## Overview

BACEN-compliant Pix platform for the Lerian ecosystem.

This chart manages 14 independently deployable Pix Lerian workloads. Each gets its own Deployment, Service, ConfigMap, Secret, ServiceAccount, and — where configured — HPA and PodDisruptionBudget. Ingress is opt-in, disabled by default on all three surfaces.

**The default render is not a working installation.** `helm template` with no values succeeds, but validates structure only. With defaults: 6 of the 14 workloads are disabled; no Postgres DSN is set, so **no migration Job is rendered** and the schemas are never applied; PostgreSQL, Valkey, RabbitMQ, the external-Postgres bootstrap, and all three ingresses are off; and `LICENSE_KEY` is empty while `DEPLOYMENT_MODE` defaults to `byoc`, which the applications refuse.

## Compatibility

| Chart version | App image tag |
|---|---|
| 1.0.0 | 1.0.0-beta.337 |

The row above covers this chart only. There is no in-place upgrade path from any earlier chart — moving to this chart is a fresh install (cutover), not a `helm upgrade`, and a cutover does not migrate or copy data. See [Upgrade and rollback](#upgrade-and-rollback).

Every workload's image tag defaults to the chart's `appVersion`, keeping the cohort in lockstep. Pinning `<component>.image.tag` takes that workload off the cohort and out of the compatibility row above.

## Production quickstart

One supported path for this release: **single-tenant, hub-only, external dependencies, ingresses off.**

| Decision | This release |
|---|---|
| Tenancy | Single-tenant (`MULTI_TENANT_ENABLED: "false"`, the default) |
| DICT / COB tier | Hub. `dictProxy` and `cobProxy` **disabled** |
| Development-only pairs | `adapterProviderMock`, `adapterLerian`, `adapterLerianSystemplane` **disabled** |
| Pix Automático | Optional. Enable `pixauto` + `pixautoSystemplane` only if needed |
| PostgreSQL, Valkey, RabbitMQ | Externally managed. Local subcharts stay off |
| Ingress | All three surfaces off until authentication, DNS, and TLS are in place |
| Release layout | One release per namespace |

Why: only the hub tier carries business flows in this release, and the adapter and mock pairs are development only. See [Recommended topology and limitations](#recommended-topology-and-limitations).

**1. Prerequisites.** Namespace, GHCR pull secret, reachable PostgreSQL, license key, and an Access Manager. Full list: [Prerequisites](#prerequisites).

**2. Build `values.yaml`.** Copy `values-template.yaml` from this directory and fill its placeholders — it already ships the topology above, so you edit values, not toggles. What it encodes:

```yaml
# Enabled: spi, dictHub, cobHub, each with its *Systemplane workload,
#          plus dictHubVsync for DICT reconciliation (needs Valkey + RabbitMQ).
# Disabled: dictProxy, cobProxy, adapterProviderMock,
#           adapterLerian + adapterLerianSystemplane,
#           postgresql, valkey, rabbitmq subcharts,
#           pixauto + pixautoSystemplane — enable the pair for Pix Automático.
spi:       { enabled: true }
dictProxy: { enabled: false }
```

**3. Fill the indispensable values.** Every item below is mandatory for this topology. [Required before installation](#required-before-installation) is the canonical table.

| Value | Where | On which workloads |
|---|---|---|
| `DATABASE_URL` | `secrets` | `spi`, `dictHub`, `dictHubVsync`, `cobHub` — **no DSN means no migration Job, so no schema** |
| `SYSTEMPLANE_POSTGRES_DSN` | `secrets` | the enabled `*Systemplane` workloads |
| `LICENSE_KEY` | `secrets` | every enabled workload (`DEPLOYMENT_MODE` is not `local`) |
| `ORGANIZATION_IDS` | `configmap` | with `LICENSE_KEY`, on the eight license-client workloads |
| `ORGANIZATION_ID`, `ISPB` | `configmap` | the domain application **and** its `*Systemplane` workload |
| `SYSTEMPLANE_SECRET_MASTER_KEY` | `secrets` | `spiSystemplane`, `dictSystemplane`, `cobSystemplane`, `pixautoSystemplane` |
| `RABBITMQ_URI`, `VALKEY_URL` | `secrets` | `dictHubVsync` — both hard requirements |
| `ADAPTER_BASE_URL` and the `*_BASE_URL` family | `configmap` | the domain application **and** its `*Systemplane` workload |

Supply every secret from a Secret your own secret manager populates, created **before** `helm install` because migration hooks run first. See [Production secret management](#production-secret-management).

**4. Install.**

```bash
helm registry login ghcr.io --username <registry-username>

kubectl create namespace <namespace>

kubectl create secret docker-registry <pull-secret-name> \
  --namespace <namespace> \
  --docker-server=ghcr.io \
  --docker-username=<registry-username> \
  --docker-password='<token>'

helm upgrade --install <release-name> \
  oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm \
  --version <chart-version> \
  --namespace <namespace> \
  --values values.yaml \
  --wait --timeout 10m
```

Name that pull secret in `global.imagePullSecrets`; every workload inherits it when its own `imagePullSecrets` list is empty. `helm registry login` prompts for the token on stdin — **do not pass a token on the command line**, it lands in shell history and in the process list. **Always pin `--version`**; an unpinned install resolves to whatever is newest, making the deployed version unreproducible.

**One release per namespace.** Workload names (`plugin-br-pix-lerian-<component>`) do not carry the release name, so two releases cannot share a namespace. Two releases in two namespaces are fine, and that is how you run more than one installation.

<a id="verify"></a>
**5. Verify.**

```bash
# Workloads, then the bootstrap and migration Jobs
kubectl get pods -n <namespace> -l app.kubernetes.io/instance=<release-name>
kubectl get jobs -n <namespace> -l app.kubernetes.io/instance=<release-name>

# A migration Job that is ABSENT is the common cause of a pod that never becomes ready
kubectl get jobs -n <namespace> -o name | grep migrations

# First place a failed install explains itself
kubectl get events -n <namespace> --sort-by=.lastTimestamp | tail -30
kubectl logs -n <namespace> job/plugin-br-pix-lerian-<component>-migrations
kubectl logs -n <namespace> <pod> --previous | head -30

# Readiness from inside the cluster
kubectl port-forward -n <namespace> svc/plugin-br-pix-lerian-spi 4101:4101
curl --fail -sS http://localhost:4101/spi/readyz
```

`readyz` must return 200 on every enabled workload. A 200 on `health` with 503 on `readyz` is a configuration problem, not a crash — read the body, then [Health and readiness reference](#health-and-readiness-reference).

## Prerequisites

The single list; later sections link here instead of restating it.

| Requirement | When |
|---|---|
| **Kubernetes 1.23+** and **Helm 3.10+** | Always |
| **GHCR access** — a credential that can pull the chart and the 14 `ghcr.io/lerianstudio/plugin-br-pix-lerian-*` images | Always |
| **A namespace**, created before install, plus an image pull secret in it named in `global.imagePullSecrets` | Always |
| **PostgreSQL** reachable from the cluster, with the databases and role from [Database bootstrap and migrations](#database-bootstrap-and-migrations) | Always |
| **Permission to create Jobs** — bootstrap and migrations both run as Jobs | Always |
| **A license key**, and `ORGANIZATION_IDS` alongside it | Any `DEPLOYMENT_MODE` other than `local` |
| **Valkey (Redis-compatible)** | **Required** by `dictHubVsync`; optional caches on `spi`, `dictHub`, `cobHub`, `pixauto` |
| **RabbitMQ** | **Required** by `dictHubVsync` in single-tenant — the render fails without the URI |
| **An Access Manager** reachable at `PLUGIN_AUTH_URL` | `PLUGIN_AUTH_ENABLED=true`, which you should set for any exposed deployment |
| **Existing Secrets created before `helm install`** | Whenever a workload uses `useExistingSecret` — migration hooks read them first |
| **DNS, TLS certificates, and an ingress controller** | Only if you enable an ingress. The chart defaults to `className: nginx` |
| **Storage classes / PVCs** | Only with the local subcharts, which are [development only](#development-only-local-dependencies) |

`values-template.yaml` carries the shape — which key belongs to which workload, and which keys belong in `secrets` rather than `configmap`. [Required before installation](#required-before-installation) is the authoritative list of what each value means and when it is required. Fill the `*Systemplane` blocks too: setting identity and dependency addresses only on the application workload is not enough ([Single-tenant configuration](#single-tenant-configuration)).

## Recommended topology and limitations

The detail behind the shape in the [quickstart](#production-quickstart).

| Group | Workloads | Notes |
|---|---|---|
| SPI | `spi` + `spiSystemplane` | Always |
| DICT | `dictHub` + `dictSystemplane`, `dictHubVsync` optional | Hub tier only |
| COB | `cobHub` + `cobSystemplane` | Hub tier only |
| Pix Automático | `pixauto` + `pixautoSystemplane` | Optional |
| Shared dependencies | PostgreSQL, Valkey, RabbitMQ | External to this chart |

Critical contracts, each stated once here:

- **Only the hub tier carries business flows in this release.** Proxies serve no business route in either domain.
- **A proxy can be healthy and still answer 404 for business.** Its probes return 200 while the rail is dead.
- **`adapterLerian`, `adapterLerianSystemplane`, `adapterProviderMock` are `Development only`** here.
- **Disabling a hub can remove the only migration Job for that domain's schema.** See [Effect of disabling a workload](#effect-of-disabling-a-workload).
- **Keep `systemplaneIngress.enabled: false`.** The administrative API reads and writes runtime configuration — operator-only.
- **One release per namespace.**

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

Ports 4111, 4112, and 4114 are intentionally unused. A Systemplane workload's prefix is its **domain** prefix, not its name: `dictSystemplane` answers under `/dict`, `dictHub` under `/dict-hub`.

Each workload pulls its own image, `ghcr.io/lerianstudio/plugin-br-pix-lerian-<component>-api`, set under `<component>.image.repository`. Workers omit the `-api` suffix — `dictHubVsync` pulls `plugin-br-pix-lerian-dict-hub-vsync`. There is no shared `global.image`; a `global.image.tag` is accepted by the schema and then ignored.

The application also ships an adapter consumer entrypoint that this chart does not model. If your integration needs it, deploy it outside this chart.

### Hub and proxy are not interchangeable

Each domain picks a tier. A **hub** owns the domain's business logic and its local state — its own database, and Valkey on some components. A **proxy** fronts a provider that already owns that state, so it keeps no local business state. Which tier fits follows the provider's capability. **The domains are independent:** setting DICT to proxy does not affect COB, so DICT-on-proxy with COB-on-hub is valid in the model.

In this release the proxy tier is structural only. `dictProxy` and `cobProxy` serve `health`, `readyz`, and an OpenAPI document that declares no operations, with no request-forwarding logic. **The proxy tier delivers no functional parity and does not fall back to the hub.**

| If you | Then |
|---|---|
| Route client traffic at a proxy | Every business request returns 404. No forwarding, no fallback |
| Watch its probes | `health` and `readyz` still return 200, so monitoring stays green while the rail is dead |
| Set a routing mode to `proxy` on a **caller** | Every operation that caller performs against that domain stops working. `spi` carries a mode for DICT and one for COB; `cobHub` carries one for DICT |
| Mismatch routing mode and `*_BASE_URL` | Not caught at boot — the mode only selects which service name a caller resolves, and is not cross-checked. Keep both on the same tier |
| Enable a proxy at all | It still needs a Postgres DSN for its configuration store; it is not a stateless drop-in |

Routing mode accepts `hub` and `proxy`, defaulting to `hub`. **Leave it at `hub` in this release.** Enable the proxy workloads only if your provider topology requires the tier to exist; do not send business traffic to it.

### Development-only components

`adapterLerian` / `adapterLerianSystemplane` — **Development only.** `adapterLerian` **fails to boot when `DEPLOYMENT_MODE` is anything other than `local`.** The default is `byoc` and the workload ships disabled, so nothing breaks out of the box; enabling it in `byoc` or `saas` crash-loops the pod. The `pix-adapter-lerian` database is still created by the bootstrap Job, because the database list is fixed.

`adapterProviderMock` — **Development only**, shipped `enabled: false`. A provider test double for development and homologation: it stands in for a real provider so the rest of the platform can be exercised end to end without one. Its default target is the Lerian sandbox mock server:

```yaml
adapterProviderMock:
  configmap:
    PROVIDER_BASE_URL: "https://mock-pix-lerian-server.sandbox.lerian.net"
```

Because the component ships disabled, that default reaches no installation that does not enable it explicitly. Override it only to target your own mock server. These settings cannot get a default, because they identify *your* sandbox access, which you receive together with them:

| Setting | Where | Notes |
|---|---|---|
| `PROVIDER_CLIENT_ID` | `secrets` | **Required** — the component does not start without it |
| `PROVIDER_CLIENT_SECRET` | `secrets` | **Required** — the component does not start without it |
| `SPI_BASE_URL` | `configmap` | **Required** — validated at boot. The chart ships an in-cluster default |
| `ADAPTER_ISPB` | `configmap` | Optional. The ISPB the mock presents as the provider; the application falls back to a placeholder ISPB when it is empty, so set it to exercise your own |

No credential ships in this chart; supply these like any other secret ([Production secret management](#production-secret-management)). Two cautions: its routes have **no authorization**, regardless of `PLUGIN_AUTH_ENABLED`, so keep `enabled: false` wherever callers you do not control can reach the pod, and never publish it on a shared ingress; and leave `MOCK_TEST_ENDPOINTS_ENABLED` off outside a controlled environment, since it mounts routes that simulate provider callbacks.

### Effect of disabling a workload

A migration Job renders **only for an enabled component**, and only five components carry a `migrations` block at all — see [Migration Jobs](#migration-jobs).

> Disabling the hub of a domain removes the only Job that applies that domain's schema. Running COB as `cobProxy` + `cobSystemplane` with `cobHub` disabled renders **no** Job for `pix-cob`, so that schema is never applied even though both remaining workloads use the database.

If you disable a hub, apply that domain's schema by other means before the remaining workloads start.

## Dependencies per workload

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

| Entry | Behaviour |
|---|---|
| `cobHub` + Valkey | Optional. Without `VALKEY_URL` the cache is off and no route fails; a retried request may re-execute |
| `dictHubVsync` + Valkey/RabbitMQ | Both hard requirements. The chart **fails the render** without `RABBITMQ_URI`. In multi-tenant the shared connection is not opened and `RABBITMQ_URI` is not consulted — queues live in per-tenant vhosts |
| `dictHub` + RabbitMQ | Publish-only and **off unless you set it**; the chart does not ship the key. It only accelerates reconciliation dispatch. An unavailable broker warns and continues on the backstop |
| `adapterLerian` + Valkey | Required once its DLQ admin surface is active, gated by Kafka broker configuration. Moot — the workload is `Development only` |
| Streaming | `spi`, `dictHub`, `cobHub`, `pixauto` can emit CloudEvents, **off by default**; only `pixauto` ships the `STREAMING_*` keys. Leave `STREAMING_CLOUDEVENTS_SOURCE` empty — a non-empty value that does not match the application's own source refuses the boot **whether or not streaming is enabled**. Streaming enabled without brokers also refuses the boot |
| `MULTI_TENANT_REDIS_*` on `dictHubVsync` | A **separate** Redis from `VALKEY_URL`, where the Tenant Manager publishes tenant lifecycle events. Pointing both at one instance makes tenant changes invisible to the worker. Optional — discovery then falls back to the periodic sweep. The CA certificate, when used, is base64-encoded PEM |

## Required before installation

Set these before `helm install`. **"Required" does not mean the same thing on every row** — a missing value can fail the render, the container, the boot, readiness, or only the first request that needs it. The `Failure stage` column says which:

| Stage | What you see |
|---|---|
| Render | `helm template`/`install` fails; nothing is applied |
| Container creation | Pod stuck in `CreateContainerConfigError` |
| Application boot | `CrashLoopBackOff`; the log names the variable |
| Readiness | Pod runs, `readyz` 503 |
| First request | Pod ready; the request needing the value is rejected |
| Security posture | Everything works and is unprotected |
| Optional degradation | Feature off or slower; no failure |

| Setting | Where | Failure stage | Required when |
|---|---|---|---|
| `DEPLOYMENT_MODE` | `configmap` | Application boot | Accepts `local`, `byoc`, `saas`, lower-case and untrimmed. **Required to be set explicitly** on `spi`, `dictHub`, `dictProxy`, `cobHub`, `cobProxy`, `pixauto` when `MULTI_TENANT_ENABLED=true`. Chart default is `byoc`. |
| `LICENSE_KEY` | `secrets` | Application boot | **Required** whenever `DEPLOYMENT_MODE` is anything other than `local`. Empty is tolerated only in `local`. The chart ships the key on all 14 workloads. |
| `ORGANIZATION_IDS` | `configmap` | Application boot | **Required together with `LICENSE_KEY`** — the license client refuses to initialise without it and the workload exits at boot. Use `global`, or a comma-separated list to scope it. Eight workloads build a license client and need it: `spi`, `dictHub`, `dictProxy`, `dictHubVsync`, `cobHub`, `cobProxy`, `pixauto`, `adapterLerian`. The five Systemplane workloads and `adapterProviderMock` do not, even though they carry `LICENSE_KEY`. `values-template.yaml` sets it on all eight; `values.yaml` only on `adapterLerian` and `pixauto` — add the other six if you start from defaults. |
| `ORGANIZATION_ID` | `configmap` | Application boot | Single-tenant business identity, read by `spi`, `dictHub`, `dictHubVsync`, `dictProxy`, `cobHub`, `pixauto`. The workload reads its domain's `organization_id` from the Systemplane store first and falls back to this value when the store holds nothing — so on `pixauto`, with neither set, every request answers `403 TENANT_CONFIG_NOT_FOUND`. **Must be empty** when `MULTI_TENANT_ENABLED=true` on `cobHub` and `pixauto`; a value there refuses the boot. Not interchangeable with `ORGANIZATION_IDS`. |
| `ISPB` | `configmap` | Readiness | Single-tenant identity on `spi`, `dictHub`, `dictHubVsync`. Required to reach ready — see [Health and readiness reference](#health-and-readiness-reference). |
| `DATABASE_URL` | `secrets` | Application boot | **Required** on `spi`, `dictHub`, `dictProxy`, `cobProxy` in every mode. **Required in single-tenant only** on `cobHub`, `dictHubVsync`, `pixauto`. Not used by `adapterLerian`, `adapterProviderMock`. |
| `SYSTEMPLANE_POSTGRES_DSN` | `secrets` | Application boot | On the five Systemplane workloads, **one of** this or `DATABASE_URL` is required, and this one **wins** when both are set. **Required** on `adapterLerian` and `pixauto`. On other workloads it is optional and falls back to `DATABASE_URL`. |
| `SYSTEMPLANE_SECRET_MASTER_KEY` | `secrets` | Application boot | **Required, and must be non-empty**, on `spiSystemplane`, `dictSystemplane`, `cobSystemplane`, `pixautoSystemplane` whenever `ENV_NAME` is not `local` or `development`; and on `adapterLerianSystemplane` whenever `DEPLOYMENT_MODE` is not `local`. Note the two gates differ. See [the note below](#about-systemplane_secret_master_key). |
| `MULTI_TENANT_ENABLED` | `configmap` | Application boot | Defaults to `false`. See [Multi-tenant configuration](#multi-tenant-configuration). |
| `MULTI_TENANT_URL`, `MULTI_TENANT_API_KEY` | `configmap` / `secrets` | Application boot | **Required when `MULTI_TENANT_ENABLED=true`** on the five Systemplane workloads, `cobHub`, `dictHubVsync`, `pixauto`, `adapterLerian`. `dictSystemplane` and `cobSystemplane` do **not** ship these keys — add them through the open maps. |
| `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_URL` | `configmap` | Application boot / Security posture | Defaults to `false` / an in-cluster placeholder. When enabled, `PLUGIN_AUTH_URL` **must be non-empty** or the workload refuses to start. **Required to be `true`** on `pixauto` whenever `ENV_NAME` is not `local` or `development`. |
| `RABBITMQ_URI` | `secrets` | Render | **Required when `dictHubVsync` is enabled.** The render fails without it. |
| `PROVIDER_CLIENT_ID`, `PROVIDER_CLIENT_SECRET` | `secrets` | Application boot | **Required when `adapterProviderMock` is enabled** — it does not start without both. Issued with your sandbox access; see [Development-only components](#development-only-components). |
| `VALKEY_URL` | `secrets` | Application boot / Optional degradation | **Required** on `dictHubVsync`, which does not start without it. Optional on `spi`, `dictHub`, `cobHub`, `pixauto`, where its absence degrades the cache rather than failing the workload. |
| `ADAPTER_BASE_URL` | `configmap` | First request | Not validated at startup, so a missing value surfaces as rejected requests at runtime rather than a failed rollout. Include the provider's route prefix. |

Setting a key a workload does not read has no effect. `configmap`, `secrets`, and `extraEnvVars` are open maps: the chart passes any key straight to the container, but **that is not proof the binary reads or validates it**. Unknown keys are ignored silently. Use only keys documented for that workload and this version.

### About `SYSTEMPLANE_SECRET_MASTER_KEY`

- **No format and no length is validated by this release.** Do not infer a required encoding or size.
- Supply it from an existing Secret; see [Production secret management](#production-secret-management).
- It is checked at every boot, so keep the same value across upgrades — otherwise a rollout needs the new value supplied everywhere first.
- The two gates are different: four Systemplane workloads key off `ENV_NAME`, `adapterLerianSystemplane` off `DEPLOYMENT_MODE`. With the chart defaults (`ENV_NAME: development`, `DEPLOYMENT_MODE: byoc`), `adapterLerianSystemplane` already requires the key while the other four do not.

## Production secret management

In production every secret comes from a Secret your own secret manager populates, per workload:

```yaml
spi:
  useExistingSecret: true
  existingSecretName: <kubernetes-secret-name>
```

Rules that matter:

- **The existing Secret replaces the chart-rendered Secret entirely. There is no merge.** With `useExistingSecret: true` the chart does not render `plugin-br-pix-lerian-spi` at all and the pod's `envFrom` points only at your Secret; anything left in `spi.secrets` is silently not applied.
- **Your Secret must therefore carry the complete set of secret keys for that workload** — every key it needs from the table above, not just the ones you wanted to override.
- `useExistingSecret` must be an **unquoted boolean**. A quoted `"false"` is truthy in Helm templates; the chart rejects it rather than silently selecting an existing Secret. Prefer `--set` over `--set-string`. `existingSecretName` is required when it is true.
- **Never put a secret in `configmap` or `extraEnvVars`.** ConfigMap data is not protected, and `extraEnvVars` renders the value inline into the Deployment, where `kubectl describe` shows it.
- Inline `secrets` are for development, testing, or a deliberate exception. An inline value ends up in Git, in your GitOps renders, and in Helm release history.
- The existing Secret must exist **before** `helm install`, because the migration hooks run first.

Prefer reading values from files, which keeps them out of shell history and out of the process list:

```bash
kubectl create secret generic <kubernetes-secret-name> \
  --namespace <namespace> \
  --from-file=DATABASE_URL=./database-url.txt \
  --from-file=LICENSE_KEY=./license-key.txt
```

## Database bootstrap and migrations

A full single-tenant deployment uses five databases owned by a single role: `pix-spi`, `pix-dict`, `pix-cob`, `pix-adapter-lerian`, `pix-pixauto`. **This is the complete topology, not a per-workload requirement** — which workload needs which is in [Dependencies per workload](#dependencies-per-workload).

### Optional bootstrap Jobs

With `global.externalPostgresDefinitions.enabled: true` the chart renders one Job per database, creating role, database, and grants idempotently. The admin credentials need privilege to create roles and databases. The Jobs run again on every upgrade; a re-run against provisioned databases is a no-op that re-asserts the role password and the grants.

Each credential can come from an existing Secret or inline, independently of the other:

| Credential | Existing Secret | Inline |
|---|---|---|
| Postgres admin login | `postgresAdminLogin.useExistingSecret.name`, on a Secret carrying `DB_USER_ADMIN` and `DB_ADMIN_PASSWORD` | `postgresAdminLogin.username` + `.password` |
| Application role password | `pixLerianCredentials.useExistingSecret.name`, on a Secret carrying `DB_PASSWORD_PIX_LERIAN` | `pixLerianCredentials.password` |

The schema requires `connection.host` and, for each credential, either a password or an existing Secret name. Enabling the bootstrap without them fails the render, and an inline half left empty **fails at render time** rather than producing a Secret the Jobs would then authenticate with.

Inline values never reach a Job manifest: the chart collects them into a single Secret read through `secretKeyRef`, so no password appears in the Job spec or in `kubectl describe job`. That Secret carries only the inline halves, and is not rendered at all when both halves name an existing Secret.

What the Jobs guarantee:

- The role password is set client-side with `password_encryption = 'scram-sha-256'` pinned in the same session, so only the derived verifier reaches the server. No superuser needed.
- **The bootstrap image must ship psql 15 or newer** — the Job keeps credentials out of process arguments using a meta-command added in psql 15. The chart pins `postgres:17`.
- Inputs are validated before the cluster is touched, so a bad credential cannot half-bootstrap the databases. Empty `DB_USER_ADMIN`, `DB_ADMIN_PASSWORD`, or `DB_PASSWORD_PIX_LERIAN` are refused, and so is an application password containing LF or CR — the password is transported as newline-delimited input. Every other character works.
- Sessions taking an advisory lock set `lock_timeout = '60s'` first, so a Job contending with a sibling fails with a clear error instead of blocking until the release times out.

The role name defaults to `pixswitch`, preserved for compatibility. Set `global.externalPostgresDefinitions.pixLerianCredentials.username` on a **new** deployment to change it. Renaming the role on an existing deployment is a database operation, not a values change — a new name here creates a second role with no privileges over the existing objects.

#### Migrating values from the retired key

`global.externalPostgresDefinitions.pixswitchCredentials` was renamed to `pixLerianCredentials` with **no alias**. `values.schema.json` rejects the retired key outright, so a stale override fails loudly instead of quietly ceasing to apply:

```text
Error: values don't meet the specifications of the schema(s) in the following chart(s):
plugin-br-pix-lerian-helm:
- at '/global/externalPostgresDefinitions': 'allOf' failed
  - at '/global/externalPostgresDefinitions/pixswitchCredentials': false schema
```

Two edits move a values file across:

| Before | After |
|---|---|
| `global.externalPostgresDefinitions.pixswitchCredentials` | `global.externalPostgresDefinitions.pixLerianCredentials` |
| `DB_PASSWORD_PIXSWITCH`, on the Secret named by `useExistingSecret.name` | `DB_PASSWORD_PIX_LERIAN`, on the same Secret |

Nothing else changes: `username`, `password` and `useExistingSecret` keep their names and meaning. This is the only key in the retired chart's `values.yaml` that this chart refuses; a values file that never set `global.externalPostgresDefinitions` renders here unchanged.

### Migration Jobs

`spi`, `dictHub`, `cobHub`, `adapterLerian`, and `pixauto` each carry a `migrations` block. A migration Job renders only when **all** of these hold:

1. the component is enabled,
2. `<component>.migrations.enabled` is not `false` (it defaults to true), and
3. `<component>.useExistingSecret` is true **or** `<component>.secrets.DATABASE_URL` is non-empty.

Condition 3 is why the default render produces no Jobs: an empty DSN would fail the hook before any pod starts, so the chart skips it. **A workload whose Job never renders never gets its schema applied.**

Every database resource sits in the same `pre-install,pre-upgrade` phase, ordered by weight. Helm applies a phase's hooks in weight order and waits for each to finish, so install and upgrade share one ordering:

| Weight | Resource | Delete policy |
|---|---|---|
| `-30` | `plugin-br-pix-lerian-bootstrap-postgres` Secret — bootstrap credentials | `before-hook-creation` |
| `-20` | `plugin-br-pix-lerian-bootstrap-postgres-<database>` Jobs — role, databases, grants | `before-hook-creation,hook-succeeded` |
| `-10` | `plugin-br-pix-lerian-<component>-migrations` Secret | `before-hook-creation` |
| `-5` | `plugin-br-pix-lerian-<component>-migrations` Job — must succeed | `before-hook-creation,hook-succeeded` |
| `0` | Workloads — Deployments, Services, ConfigMaps, application Secrets | — |

The `-30` and `-20` rows render only with the bootstrap enabled. The migration Secret carries only `DATABASE_URL` and is **not** rendered when `useExistingSecret: true` — the Job reads your Secret directly, which is why it must exist before the install begins.

What that ordering gives you:

- **Migrations complete before any workload is created or updated.** A failing migration aborts the release at weight `-5`: a first install creates no Deployment, an upgrade leaves the pods at the previous revision.
- **The bootstrap Jobs run ahead of the migrations** that depend on the databases they create, so provisioning and migrating in one fresh install is supported.
- **The readiness gate comes after the schema is in place.** Still raise `--timeout` for large schema changes, since `--wait` waits for hook Jobs too.

**The database must already be reachable when the migration Job runs.** That holds for an external or managed server, and for the databases the bootstrap Jobs create. It does **not** hold for the bundled `postgresql` subchart: its StatefulSet is a normal resource at weight `0`, so it cannot start before a hook at weight `-5`. Pointing a DSN at the bundled subchart and installing with migrations enabled fails at the migration hook, with the connection error in the Job log. That subchart is [development-only](#development-only-local-dependencies); when you use it, install once with `<component>.migrations.enabled: false`, then enable migrations in a second step once Postgres is running.

The chart also carries Argo CD annotations (`argocd.argoproj.io/hook`, `sync-wave`) alongside the Helm ones, with the same waves as the weights above. All four resources are `PreSync`.

## Single-tenant configuration

Single-tenant is the default (`MULTI_TENANT_ENABLED: "false"`).

Set the same values on both the domain application **and** its Systemplane workload:

- Identity: `ORGANIZATION_ID`, `ISPB`
- Dependency addresses: `ADAPTER_BASE_URL`, and the `*_BASE_URL` / `*_CLIENT_ID` / `*_CLIENT_SECRET` families

The Systemplane workload seeds these into the configuration store and the applications read them back. Readiness is gated on the store, so a workload can run with correct environment values and still report itself not ready if the domain's Systemplane workload was never given them.

## Multi-tenant configuration

With `MULTI_TENANT_ENABLED: "true"`, four requirements change — the per-workload lists are in [Required before installation](#required-before-installation):

- `MULTI_TENANT_URL` and `MULTI_TENANT_API_KEY` become **required**. `dictSystemplane` and `cobSystemplane` do not ship these keys — add them through the open maps.
- `DEPLOYMENT_MODE` must be **explicitly set**; an implicit mode is refused.
- `ORGANIZATION_ID` **must be empty** on `cobHub` and `pixauto`. A value there refuses the boot, because a deployment-wide organization could only act as a cross-tenant fallback.
- `DATABASE_URL` stops being required on the workloads that resolve per-tenant pools instead.

The boot-time configuration snapshot is skipped entirely; environment and Helm values are the boot source of truth.

### Tenant configuration is provisioned per tenant

Store seeding from the environment does **not** run in multi-tenant mode. A tenant's configuration is written per tenant and read per request, so provisioning a tenant is a step of its own — not something Helm values do for you. Readiness still consults the store, so a workload can run with correct environment values and still report itself not ready while the store has nothing to read. The `readyz` body names each check and, under `required_keys`, the exact keys it is waiting for.

### The request path fails closed

Per-tenant configuration is resolved from the store on every request, keyed by the calling tenant. **There is no global fallback.** A request whose tenant configuration is missing or incomplete is rejected with **HTTP 403 and code `TENANT_CONFIG_NOT_FOUND`**, and a request arriving without a resolvable tenant is refused before any read. The log line names the cause and the missing keys, never the values — which is the reliable way to enumerate what that workload requires in your version.

Provision each tenant's configuration before sending it traffic. Two different sets are at play and they fail at different moments, which is the usual source of a tenant that onboards cleanly and then rejects every request:

- **Readiness** consults the deployment-wide slots. On `cobHub`: `organization_id`, `ispb`, `provider`, `dict_base_url`.
- **Tenant resolution** consults the calling tenant's own configuration on every request. On `cobHub` that set additionally requires `dict_client_id` and `dict_client_secret` — five keys in total. An absent credential fails the request closed with 403 rather than falling back.

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

The boot snapshot is skipped, leaving the environment value in place, when: the deployment is multi-tenant; no store is reachable (no DSN, or a connection failure — logged as a warning, and the workload continues); the stored value is empty or absent; or it has the wrong type. `adapterLerian` has **no boot snapshot at all** — it reads the store per request.

Which keys need a restart:

| Class | Behaviour | Examples |
|---|---|---|
| Boot-captured | Read once at boot. **A change through the administrative API needs a pod restart.** | Deployment identity (`organization_id`, `ispb`), provider and dependency base URLs, routing modes, the request timeout, telemetry settings, the auth toggle and URL, Postgres pool sizing |
| Hot-reloaded in place | Applied without a restart | Log level, the reconciliation worker's enable/concurrency knobs, and the readiness key gates — satisfying a gate turns `readyz` green on its own |
| Per-request | Read on every request | Per-tenant identity and credentials, the adapter's routing table |

Because most identity and address keys are boot-captured, **changing them through the administrative API is not enough** — restart the workload.

### 3. Per-tenant runtime

In multi-tenant mode, Helm and the environment provide only what a pod needs to initialise. Per-request configuration comes from the store, scoped to the calling organization, and fails closed — see [Multi-tenant configuration](#multi-tenant-configuration).

## Configuration precedence inside a pod

Within one workload, highest precedence first:

1. `<component>.extraEnvVars` — explicit env entries, which beat every `envFrom` source
2. the imported Secret — `<component>.secrets`, or your existing Secret
3. `<component>.configmap`

Set a key in only one of them unless you mean to override. The chart **fails the render** if the same key appears in both `extraEnvVars` and `secrets` with opposing values — two deliberate overrides disagreeing is a mistake, not a preference.

Two things this precedence does **not** mean:

- An open map means the chart forwards the key. It does **not** mean the binary reads or validates it. Unknown keys are ignored silently.
- When `useExistingSecret: true`, the inline `secrets` map is not rendered at all, so it is not a source — see [Production secret management](#production-secret-management).

The chart reserves the pod annotation carrying the ConfigMap/Secret checksum, which is what rolls the pods when configuration changes. Overriding it would stop configuration updates from restarting pods, so the chart refuses it.

## Authentication

`PLUGIN_AUTH_ENABLED=true` with a resolvable `PLUGIN_AUTH_URL` mounts per-route authorization on the business and machine-to-machine routes of the workloads that carry it. It does not cover probes, OpenAPI routes, the `*Systemplane` administrative APIs, or the provider mock — those need network-level controls from your platform.

- **The default is `false`.** Configure nothing and you get an unauthenticated surface. Set it explicitly before exposing any route.
- **Keep `systemplaneIngress.enabled: false`,** the default. Restrict the administrative API with NetworkPolicies or equivalent.
- **`ENV_NAME` is matched exactly.** OpenAPI and docs routes stay mounted unless it is the literal string `production`; `prod`, `Production`, or a trailing space all leave them served. Set `SWAGGER_ENABLED` explicitly to turn them off.
- **An unreachable `PLUGIN_AUTH_URL` denies requests rather than allowing them.** The URL format is not validated, so the symptom is a permissions failure at request time, not a boot failure.

## Ingress and service URLs

Three independent ingress surfaces, all `enabled: false` by default:

| Block | Publishes | Default posture |
|---|---|---|
| `appsIngress` | Client-facing application routes | Disabled |
| `systemplaneIngress` | Systemplane administrative routes | Disabled — **keep it disabled** |
| `providersIngress` | Provider-facing adapters | Disabled |

Each route names a component by its `values.yaml` key, which is the single source of the enabled flag, the Service name, and the backend port. Routes whose component is disabled are skipped. If you also set `serviceName`, it must name the same component, or the render fails.

The chart fails the render for one workload published without authentication and renders successfully for every other — **do not read a successful render as proof that the published surface is protected.** The check is also blind when `<component>.useExistingSecret: true`, since the chart cannot read your Secret. In that configuration the external Secret **must** carry `PLUGIN_AUTH_ENABLED` set to a true value; setting the key in `<component>.extraEnvVars` instead keeps the check effective.

### In-cluster URLs

Use the full Service DNS name with the scheme, the port, and the route prefix.

**Resource names do not carry the release name.** Every workload's Deployment, Service, ConfigMap, and Secret is named `plugin-br-pix-lerian-<component>` whatever release name you install under; only `nameOverride` changes that prefix. The bundled subcharts are the opposite — their Services *are* release-prefixed (`<release-name>-postgresql`, `<release-name>-valkey-primary`).

```yaml
spi:
  configmap:
    DICT_BASE_URL: "http://plugin-br-pix-lerian-dict-hub:4104"
    COB_BASE_URL: "http://plugin-br-pix-lerian-cob-hub:4108"
    ADAPTER_BASE_URL: "http://plugin-br-pix-lerian-adapter-lerian:4113/lerian"
```

The adapter and provider addresses need their route prefix — `/lerian`, `/provider-mock`. The hubs' `*_BASE_URL` values carry no path.

### Publishing the apps ingress

Only after authentication, DNS, and TLS are in place:

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

A proxy workload your topology requires is configuration only — it gains no business routes. Give it a DSN and a license key, keep callers' routing modes at `hub`, and do not point client traffic at it. See [Hub and proxy are not interchangeable](#hub-and-proxy-are-not-interchangeable).

## Health and readiness reference

Every workload serves liveness and readiness over HTTP on its Service port. Paths carry the workload's route prefix, **except `dictHubVsync`, which serves both at the root.** The `readyz` response is the authoritative list for the active version, tenant mode, and configuration.

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
| `pixauto` | 4116 | `/pixauto/health` | `/pixauto/readyz` | `required_keys`; Postgres in single-tenant | `auth.url` when auth is on; streaming when enabled |
| `pixautoSystemplane` | 4117 | `/pixauto/health` | `/pixauto/readyz` | Postgres | — |

Reading the responses:

- **200 on `health`** means the process is up. It does **not** mean the workload can serve traffic.
- **200 on `readyz`** means the process is up and its checked dependencies are satisfied.
- **503 on `readyz`** means a check failed. The two right-hand columns say which checks a workload runs; a conditional probe exists only when that dependency or feature is configured. The proxies gate on configuration keys only, and `adapterProviderMock` probes its provider rather than a database, so "Postgres is checked everywhere" is not true. **Read the `readyz` body** — it names each check and its status.
- Failure modes by check: `required_keys` — the configuration store has nothing for a key the workload needs, which is the usual reason a correctly configured pod stays 503; Postgres, Valkey, RabbitMQ — the dependency is unreachable; adapter, Midaz, CRM, provider, `auth.url` — an HTTP dependency did not answer; notification outbox relay or streaming — the event path is not healthy.
- **Tenant mode changes the set, not just the values.** A check on a deployment-wide connection pool is registered only where that pool exists — single-tenant, not multi-tenant. So `spi`, `dictHub`, `cobHub`, `dictHubVsync`, and `pixauto` carry a Postgres check in single-tenant and none in multi-tenant, and `dictHubVsync` also drops its RabbitMQ and adapter checks there while gaining `tenant_consumers`. The relay check runs the other way round: multi-tenant only, and only with streaming enabled. **Ready in multi-tenant is therefore a narrower claim,** and a tenant whose own configuration is missing still fails at the request, not at `readyz`.
- `health` and `readyz` are unauthenticated on every workload. See [Authentication](#authentication).

## Troubleshooting

Every entry below uses the commands in [step 5 of the quickstart](#verify); only the diagnosis differs.

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff` / `ErrImagePull` | No pull secret in the namespace, it is not named in `global.imagePullSecrets`, or the pinned tag does not exist | Create the pull secret in the same namespace and reference it. Each workload has its own image repository — confirm the tag exists for that component |
| `CreateContainerConfigError`, or a workload failing on a variable you believe you set | Your Secret does not exist yet or lacks the key. **An existing Secret replaces the chart's Secret entirely; there is no merge**, so anything left in `<component>.secrets` is not applied | Put that workload's complete set of secret keys into your Secret and create it **before** `helm install`. Inspect it with `kubectl get secret -n <namespace> <name> -o jsonpath='{.data}'` |
| Business requests return 404 through the ingress | A wrong path prefix, or traffic reaching a proxy, which serves no business routes in this release | Check the [health and readiness table](#health-and-readiness-reference) for the prefix — a Systemplane workload's is its **domain** prefix — and confirm the route's backend is the hub |
| Requests return 403 `TENANT_CONFIG_NOT_FOUND` | The calling tenant has no configuration, is missing required keys, or the request carried no resolvable tenant. **There is no global fallback**; the path fails closed by design | Provision that tenant's configuration before sending traffic. The log line names the cause and the missing keys |
| An ingress is published while `PLUGIN_AUTH_ENABLED` is false, and the render succeeded anyway | The render check covers one workload only, and is blind when `useExistingSecret: true` | Set `PLUGIN_AUTH_ENABLED: "true"` and a resolvable `PLUGIN_AUTH_URL` on every published workload, keep `systemplaneIngress.enabled: false`, and restrict the admin surface at the network layer. See [Ingress and service URLs](#ingress-and-service-urls) |

### Workload refuses to start, log names a variable

**Symptom** — `CrashLoopBackOff`, and the log's first lines name a variable.

| Message names | Fix |
|---|---|
| `LICENSE_KEY` | Set it on that workload. |
| the license client failing to initialise | Set `ORGANIZATION_IDS` — `global` for a single-license deployment. |
| `DATABASE_URL` / a Postgres DSN | Set `DATABASE_URL` or `SYSTEMPLANE_POSTGRES_DSN` per the [requirements table](#required-before-installation). |
| `SYSTEMPLANE_SECRET_MASTER_KEY` | Set a non-empty value on that Systemplane workload. |
| `MULTI_TENANT_URL` / `MULTI_TENANT_API_KEY` | Required when `MULTI_TENANT_ENABLED=true`. `dictSystemplane` and `cobSystemplane` need the keys added through their open maps. |
| `DEPLOYMENT_MODE` must be explicitly set | Set it on that workload; multi-tenant does not accept an implicit mode. |
| `ORGANIZATION_ID` must be empty | Remove it from `cobHub` / `pixauto` in multi-tenant mode. |
| `PLUGIN_AUTH_ENABLED` must be true | On `pixauto` outside `local`/`development`, enable auth or set `ENV_NAME` accordingly. |

Also check the mode value itself: it is matched **case-sensitively and untrimmed**, so `SAAS` or a trailing space is not the mode you meant.

### `health` is 200 but `readyz` is 503

**Causes** — a dependency check failing, or required configuration keys absent from the store.

**Fix** — if the response points at required keys, set the domain's identity and dependency values on the **Systemplane** workload, which seeds them; in multi-tenant those keys arrive by provisioning instead, so provision them and restart the workload if the key is boot-captured ([Systemplane configuration lifecycle](#systemplane-configuration-lifecycle)). If it points at Postgres, check the DSN and network reachability.

### Changing a value in `values.yaml` had no effect

**Cause** — one of three things:

1. The key is stored in the Systemplane store and an administrator already changed it. **The seed only replaces a value still at its registered default**, so a non-default value is preserved and your environment change is ignored.
2. The key is boot-captured. It was read once at boot, so it needs a pod restart.
3. The key is set in a higher-precedence source — see [Configuration precedence inside a pod](#configuration-precedence-inside-a-pod).

**Fix** — for (1) change it through the administrative API; for (2) restart the workload after the change; for (3) remove the duplicate.

### A migration or bootstrap Job failed

- **The Job is absent.** The DSN is empty and `useExistingSecret` is false, so the chart skipped it — the schema was never applied. Set `secrets.DATABASE_URL`.
- **The Job cannot connect.** The server in the DSN was not reachable when the hook ran: a database never provisioned, or a DSN aimed at the bundled `postgresql` subchart. See [Migration Jobs](#migration-jobs).
- **Authentication failure on a bootstrap Job.** Check the admin credentials. Empty inline values fail at render, so a runtime failure points at wrong values or missing privileges.
- **`invalid command \getenv`.** The bootstrap image is older than psql 15. The chart pins `postgres:17`; a pull-through mirror or an override may be serving something older.
- **A lock timeout.** A sibling Job held the advisory lock for more than 60 seconds. Re-run the upgrade once the contending Job has finished.
- **A hook blocking the release.** `--wait` waits for hook Jobs; raise `--timeout` for large schema changes.

### Valkey was unavailable at boot and the workload is silently degraded

**Symptom** — `dictHub` reports ready and serves traffic, but cache-dependent behaviour never works and one route consistently fails, with a cache warning in the logs from startup only.

**Cause** — `dictHub` connects its cache at startup and registers the readiness check only when that succeeded. A Valkey that was down **at boot** leaves the pod without a client for its whole lifetime, and readiness stays green. `spi`, `cobHub`, and `pixauto` connect on first use, so they recover on their own.

**Fix** — restart `dictHub` once Valkey is reachable. Bring Valkey up before the workload.

### Valkey or RabbitMQ unavailable

`dictHubVsync` requires both and will not start without them — [Dependencies per workload](#dependencies-per-workload) says which dependency is hard and which degrades. Where Valkey is optional (`spi`, `dictHub`, `cobHub`, `pixauto`) caches turn off and gated mutations fall back to durable backstops, but **a few routes fail closed with 503 rather than proceed without the cache.**

## Upgrade and rollback

Before upgrading:

1. **Pin both versions.** Record the deployed chart version and the target — `helm list` and `helm history <release-name> -n <namespace>`.
2. **Read `CHANGELOG.md`** in this directory and the [compatibility table](#compatibility).
3. **Back up the databases** whenever the target includes schema changes. This is the only reliable way back.
4. **Review what the upgrade will do**, from a render or with `helm diff`. Optional.

Then run the same command as [step 4 of the quickstart](#production-quickstart) with the new `--version`. Migration hooks run **before** the new pods roll out, so a failing migration blocks the release rather than leaving a partial rollout.

### Rollback

```bash
helm history <release-name> -n <namespace>
kubectl get jobs -n <namespace>            # inspect hooks before rolling back
helm rollback <release-name> <revision> -n <namespace> --wait
```

What a rollback does:

- It **restores the manifests of the revision you select**. Nothing more.
- It does **not re-run the migration Job.** This chart declares no `pre-rollback` or `post-rollback` hook, so no migration hook fires on a rollback. Do not read the `pre-upgrade` weights above as rollback behaviour. The chart deliberately has no rollback hook: one would run the target revision's migrations forward again, which is not what reverting a schema means.
- It does **not revert database schema or data.** Migrations that already ran stay applied, and rows written under the newer schema stay written.

The consequence decides whether a rollback is usable at all: **the image you roll back to has to be compatible with the schema that is already applied.** Where it is, the rollback is a clean way back. Where it is not, restoring the manifests will not make the older binary work — recovering needs a restore from the backup you took before upgrading, or a hand-applied down migration.

Inspect hook Jobs before rolling back, so you know which migration last ran; a failed migration Job is kept rather than cleaned up, precisely so its log is still there. Keep `SYSTEMPLANE_SECRET_MASTER_KEY` unchanged across upgrades and rollbacks — it is checked at every boot, so a revision that does not carry it will not start.

## Uninstall and residual resources

```bash
helm uninstall <release-name> --namespace <namespace>
```

What uninstall does **not** remove:

- **Databases, schemas, and data.** Nothing in the chart drops them; reinstalling reuses the existing databases.
- **`plugin-br-pix-lerian-<component>-migrations` Secrets.** Helm does not track hook resources as release resources. They are also left behind if you clear `DATABASE_URL` or disable migrations on a release that already created them. Each carries the same DSN the application Secret held.
- **Secrets you created yourself** — existing Secrets and image pull secrets are yours to manage.
- **PersistentVolumeClaims from the local subcharts**, if you enabled them.

Find residual resources before deleting anything:

```bash
# Workloads this chart owns — they carry the chart's part-of label
kubectl get all,secret,configmap -n <namespace> \
  -l app.kubernetes.io/part-of=plugin-br-pix-lerian

# Everything tied to the release, subcharts included — their resources
# do NOT carry the label above
kubectl get all,pvc,secret -n <namespace> \
  -l app.kubernetes.io/instance=<release-name>

# Subchart PersistentVolumeClaims, which outlive uninstall
kubectl get pvc -n <namespace>

# Migration Secrets, which Helm leaves behind
kubectl get secret -n <namespace> -o name | grep migrations

# Your own Secrets are not labelled by the chart at all. Identify them from
# your values: existingSecretName, and global.imagePullSecrets.
```

Delete the migration Secrets individually once you have confirmed what they are:

```bash
kubectl delete secret -n <namespace> plugin-br-pix-lerian-<component>-migrations
```

Do not delete the namespace or run a broad label-based delete without inspecting the list first — it may hold resources from other releases, and your own Secrets live there too.

## Development-only local dependencies

For development, the chart can run PostgreSQL, Valkey, and RabbitMQ in-cluster:

```yaml
postgresql: { enabled: true }
valkey: { enabled: true }
rabbitmq: { enabled: true }
```

**Development only.** These are not configured for production durability, backup, or availability. In production leave them disabled — the default — and point the workloads at managed services.

To have the chart create the five databases in the PostgreSQL subchart, set `global.externalPostgresDefinitions.enabled: true` and point `connection.host` at the subchart's Service. That Service **is** release-prefixed: `<release-name>-postgresql`, not `plugin-br-pix-lerian-postgresql`, which does not exist. Valkey follows the same rule (`<release-name>-valkey-primary`).

`adapterProviderMock` and the `adapterLerian` pair are also development-only in this release; see [Development-only components](#development-only-components).

## Useful commands

```bash
# Review a render before it reaches a cluster
helm dependency build charts/plugin-br-pix-lerian
helm lint charts/plugin-br-pix-lerian
helm template <release-name> charts/plugin-br-pix-lerian \
  --namespace <namespace> --values values.yaml

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
