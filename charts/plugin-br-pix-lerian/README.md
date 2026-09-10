# plugin-br-pix-lerian (Helm chart)

## Chart Contract

- Chart type: `multi-component`
- Required secrets: None for default render; credential-bearing DSNs, URLs, tokens, and passwords belong in component `secrets`, never in component `configmap`.
- Dependency notes: Uses local PostgreSQL, RabbitMQ, and Redis/Valkey dependency charts unless external services are configured.
- Production overrides: Provide SPI/DICT/COB/adapter credentials through component secrets or existing Secrets where supported; keep ConfigMaps limited to non-sensitive hosts, ports, flags, and identifiers.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

BACEN-compliant PIX instant payment platform for the Lerian ecosystem.

The plugin is a Go monorepo that produces 14 independently-deployable binaries.
This chart deploys all of them with one helm release. Each component has its
own Deployment, Service, ConfigMap, Secret, HPA, and PDB; ingress is opt-in
per component.

## Components

| Key in values.yaml | Component | Default port | Notes |
|---|---|---|---|
| `spi` | `spi/api` | 4101 | PIX SPI service |
| `spiSystemplane` | `spi/systemplane/api` | 4102 | Runtime config plane |
| `adapterProviderMock` | `adapter-provider-mock/api` | 4103 | BTG provider mock (disabled by default) |
| `dictHub` | `dict/hub/api` | 4104 | DICT hub (Postgres + Valkey) |
| `dictHubVsync` | `dict/hub/vsync` | 4105 | DICT verification sync worker (singleton) |
| `dictProxy` | `dict/proxy/api` | 4106 | DICT proxy to BCB |
| `dictSystemplane` | `dict/systemplane/api` | 4107 | Runtime config plane for DICT |
| `cobHub` | `cob/hub/api` | 4108 | COB hub |
| `cobProxy` | `cob/proxy/api` | 4109 | COB proxy to BCB |
| `cobSystemplane` | `cob/systemplane/api` | 4110 | Runtime config plane for COB |
| `adapterLerian` | `adapter-lerian/api` | 4113 | Lerian provider adapter (API, disabled by default) |
| `adapterLerianSystemplane` | `adapter-lerian/systemplane/api` | 4115 | Runtime config plane for adapter-lerian (disabled by default) |
| `pixauto` | `pixauto/api` | 4116 | Pix Automático payer side (disabled by default) |
| `pixautoSystemplane` | `pixauto/systemplane/api` | 4117 | Runtime config plane for Pix Automático (disabled by default) |

> Ports 4111 and 4112 are deliberately skipped. 4111 belongs to `br-slc` — its
> chart, two environments and a NetworkPolicy scoped to it — and the pair was
> left free by the component allocated before Pix Automático. Do not fill the
> gap; take the next number above 4117.

## Architecture

The plugin uses a Proxy/Hub deployment model. A "hub" component owns business
logic and local state (its own Postgres database, sometimes Valkey),
while a "proxy" component is a stateless pass-through. Both expose identical
APIs. Five Postgres databases are required (`pix-spi`, `pix-dict`, `pix-cob`,
`pix-adapter-lerian`, `pix-pixauto`); in a domain deployed as a proxy, that
domain's database backs only the runtime-configuration (systemplane) store
rather than business state.

The choice is made per domain and follows the provider's capability: a provider
that owns the state is fronted by the proxy, one that does not is fronted by the
hub. The rails are independent — deploying DICT as a proxy does not affect COB,
and vice versa. Callers pick the tier they resolve through the application's
`*_ROUTING_MODE` setting, which defaults to `hub`; the matching `*_BASE_URL`
must point at the same tier, because nothing cross-checks the two.

The `dict-proxy` and `cob-proxy` components are Phase 2 in the application:
today they serve `health`, `readyz` and their OpenAPI endpoints, with the
business operations still to land, so a proxy enabled now becomes Ready without
yet taking traffic.

## Required infrastructure

For a full deployment:
- **PostgreSQL**: 5 databases (`pix-spi`, `pix-dict`, `pix-cob`,
  `pix-adapter-lerian`, `pix-pixauto`) and a role `pixswitch` with full
  ownership of each (see [Bootstrap credentials](#bootstrap-credentials) for how
  the Jobs are credentialed and why the role keeps that name)
- **Valkey** (Redis-compatible): used by `spi`, `dict-hub`, `dict-hub-vsync`
  for caching and by `pixauto` for its idempotency replay gate (optional there —
  without it the gated routes fall through to their durable backstops)
- **RabbitMQ**: used by `dict-hub-vsync` only

For development, the chart's `postgresql`, `valkey`, and `rabbitmq`
subcharts can be enabled (set their `enabled: true`). For production, point
the in-cluster components at managed external services and leave the
subcharts disabled (default).

## Bootstrap credentials

When `global.externalPostgresDefinitions.enabled` is true the chart renders one
bootstrap Job per database. Each Job needs two credentials, and each of the two
can be supplied either from a Secret the operator already manages or inline in
values:

| Credential | External Secret | Inline values |
|------------|-----------------|---------------|
| Postgres admin login | `postgresAdminLogin.useExistingSecret.name`, on a Secret carrying `DB_USER_ADMIN` and `DB_ADMIN_PASSWORD` | `postgresAdminLogin.username` and `postgresAdminLogin.password` |
| Application role password | `pixLerianCredentials.useExistingSecret.name`, on a Secret carrying `DB_PASSWORD_PIX_LERIAN` | `pixLerianCredentials.password` |

The two halves are independent: one may come from an external Secret while the
other stays inline.

Inline values are never written into a Job manifest. The chart collects them
into `templates/bootstrap-secret.yaml` and the Jobs read every credential
through `secretKeyRef`, so both supply paths reach the container the same way
and no password appears in the Job spec or in `kubectl describe job` output.
That Secret carries only the halves that are actually inline, and when both
halves name an external Secret it is not rendered at all.

An inline half left empty fails at render time. Rendering it as an empty string
would produce a Secret the Jobs then authenticate with, turning a values mistake
into an opaque PostgreSQL authentication error.

`pixswitchCredentials` was renamed to `pixLerianCredentials`, and there is no
alias. `values.schema.json` rejects the retired key outright, so a stale
override cannot quietly stop taking effect — it reports `'not' failed` at
`/global/externalPostgresDefinitions`. Rename the key in your values.

The Job sets the role password with psql's `\password` meta-command. The session
first pins `password_encryption = 'scram-sha-256'`, in the same file `psql -f`
processes, and `\password` then reads that setting to derive the verifier on the
client — so only the verifier reaches the server and the cleartext password never
does. Pinning it matters: on a server started with `password_encryption=md5`,
`\password` would otherwise derive an MD5 verifier. The parameter has context
`user`, so the bootstrap role needs no superuser and no extra `GRANT` to set it.

**The bootstrap image must ship psql 15 or newer.** `\password` is an old
meta-command, but `\getenv` — used to keep credentials out of process arguments —
was added in psql 15: psql 14 rejects it with `invalid command \getenv`. The
chart pins `postgres:17`, so the execution here is psql 17.

Before touching the cluster the Job validates its inputs, so a bad credential
cannot leave the databases half-bootstrapped: it refuses an empty
`DB_USER_ADMIN`, `DB_ADMIN_PASSWORD` or `DB_PASSWORD_PIX_LERIAN`, and refuses an
application password containing LF or CR — `\password` reads its two
confirmations as newline-delimited lines, so an embedded newline cannot be
transported without corrupting the password. Every other character works,
including spaces, quotes, backslashes and `$ @ /`. These checks run at runtime,
which is the only place the value is visible when it comes from a Secret the
template cannot read.

Each session that takes an advisory lock sets `lock_timeout = '60s'` first, so a
Job contending with a sibling fails with a clear error instead of blocking until
the release hook gives up.

### Why the Postgres role is still named `pixswitch`

The chart identity was renamed end to end, but `pixLerianCredentials.username`
still defaults to `pixswitch`. That default is deliberate: the name is live
data, not chart identity. It is the role that already owns the five databases in
every deployed environment.

An audit of `lerian-internal-gitops` at commit `65836367` found the value pinned
in four of the six environments, in three keys each — `postgresql.auth.username`,
the `initdb` script that creates the extra databases, and the RabbitMQ user —
each of them backed by existing state. The `initdb` script only runs against an
empty data directory, so it will not re-run to create a differently named role.
The remaining two environments provision the role outside the chart's tree
altogether and hold their DSNs in Vault.

Changing the default would therefore create a second role with no privileges on
the five existing databases, while the applications kept authenticating as the
old one. Renaming the role is a data operation — `ALTER ROLE ... RENAME`, or a
new role plus reassignment of ownership and GRANTs — and belongs in its own
change, sequenced together with the GitOps values that pin it.

## Enabling/disabling components

Each component's top-level key has an `enabled: true|false` field. Set
`enabled: false` to skip a component entirely (no resources rendered).
Default `enabled` values:

- `spi`, `spiSystemplane`, `dictHub`, `dictProxy`,
  `dictSystemplane`, `cobHub`, `cobProxy`, `cobSystemplane`: `true`
- `dictHubVsync`: `false` (RabbitMQ queue consumer — it does nothing without
  `secrets.RABBITMQ_URI`, and enabling it without one fails the render)
- `adapterProviderMock`: `false` (it's a mock — only enable in dev/staging)
- `adapterLerian`, `adapterLerianSystemplane`: `false`
  (Lerian provider adapter — enable per environment)
- `pixauto`, `pixautoSystemplane`: `false` (Pix Automático payer side — enable
  per environment once its `pix-pixauto` database and DSN secret exist)

## Configuration

Every component has its own `configmap`, `secrets` and `extraEnvVars` blocks in
`values.yaml`. They are open maps: any key you add is passed to the container,
so you are never limited to the keys shipped by default. The full rendered list
for a component is `templates/<component>/configmap.yaml` together with that
component's block in `values.yaml`.

Connection settings are full connection strings, never host and port apart:

| Setting | Format | Components that need it |
|---------|--------|-------------------------|
| `DATABASE_URL` | full Postgres DSN | every component except `adapterProviderMock` |
| `SYSTEMPLANE_POSTGRES_DSN` | full Postgres DSN | the runtime-configuration store; defaults to `DATABASE_URL` when unset |
| `VALKEY_URL` | full Redis URL | `spi`, `dictHub`, `dictHubVsync`, `pixauto` |
| `RABBITMQ_URI` | full AMQP URI | `dictHubVsync` only |

Use `ORGANIZATION_IDS` for the license organization list (`"global"` for a
single-license deployment) and `ORGANIZATION_ID` for the business organization.
They are different settings and both are logged at start-up.

### Which value wins

Two rules decide what a container actually uses.

**Within a component**, `extraEnvVars` overrides `secrets`, which overrides
`configmap`. Set a key in only one of them unless you mean to override.

**Across the deployment**, the runtime-configuration plane (systemplane) is the
effective source once a component has been provisioned. The values you set here
are the initial values: they populate the configuration store on first
start-up, and from then on the store is what the components read.

In practice that means **changing an environment variable on an already
provisioned component may have no effect** — update the value through the
systemplane component for that domain instead. Two situations behave
differently: in multi-tenant deployments the environment stays authoritative,
and if the configuration store is unreachable the components keep the values
they were given.

### Where to set each key

Settings that populate the configuration store must be set on the domain's
`*Systemplane` component — `spiSystemplane`, `dictSystemplane`, `cobSystemplane`,
`pixautoSystemplane`, `adapterLerianSystemplane`. That is the component that
writes them; the application components read them back.

This applies to the deployment identity and the addresses of the services each
domain calls: `ORGANIZATION_ID`, `ISPB`, `ADAPTER_BASE_URL`, and the
`*_BASE_URL` / `*_CLIENT_ID` / `*_CLIENT_SECRET` families. Set the same values
on the application component as well — they are the values used until the store
is populated, and readiness checks read the store, so a component can be
running with the right configuration while still reporting itself not ready if
the `*Systemplane` component was never given them.

### Authentication

`PLUGIN_AUTH_ENABLED` and `PLUGIN_AUTH_URL` exist on every component. Set
`PLUGIN_AUTH_ENABLED: "true"` and point `PLUGIN_AUTH_URL` at your Access
Manager to require authentication; `values-template.yaml` already does this for
the application components. Publishing Pix Automático through `appsIngress`
requires it — the chart refuses to render otherwise, because the application
only installs its authorization middleware when authentication is enabled.

`pixauto` additionally accepts the `IDP_*` settings for permission
declaration. Leave `IDP_DECLARATION_ENABLED` at `"false"` until an M2M
application is registered for this service in your Access Manager.

### Domain settings

`dictHubVsync` carries the `VSYNC_*` settings that tune the reconciliation
worker — cadence, retry attempts and cache TTLs — and the `MULTI_TENANT_REDIS_*`
settings, which point at the Redis instance the Tenant Manager publishes tenant
lifecycle events on. That is a separate instance from `VALKEY_URL`.

`adapterLerian` needs `AWS_REGION`, `ISPB_SECRET_PREFIX` and the `ISPB_CACHE_*`
pair when webhook ingress is enabled in a multi-tenant deployment. Enabling
webhook ingress also requires `VALKEY_URL` on that component.

`adapterProviderMock` is a test double. `MOCK_TEST_ENDPOINTS_ENABLED` mounts
routes that simulate provider callbacks; leave it `false` anywhere the pod can
be reached by callers you do not control.

## Image

Each component publishes and pulls its own image
(`ghcr.io/lerianstudio/plugin-br-pix-lerian-<component>-api`), set per
component under `<component>.image.repository`. Worker components omit the
`-api` suffix (e.g. `plugin-br-pix-lerian-dict-hub-vsync`). There is no shared
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
| 2.1.0-beta.2 | 1.0.0-beta.318 |

The rows above cover this chart only. Everything before the fork belongs to
the retired `plugin-br-pix-switch` chart, whose source no longer lives in
this repository; its published releases stay available on GHCR, and its
history is in the git log up to the removal commit.

There is no in-place upgrade path from `plugin-br-pix-switch` — moving to this chart is a fresh install (cutover), not a `helm upgrade`.

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
