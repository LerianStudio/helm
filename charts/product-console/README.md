# Product Console Helm Chart

## Chart Contract

- Chart type: `single-service`
- Required secrets: None for default render.
- Dependency notes: Uses a local MongoDB dependency chart unless external MongoDB is configured. Also depends on `lerian-common-helm` (shared library chart) for the HPA/PDB/Service/Ingress templates and the `global.*` config masks below.
- Production overrides: Provide production MongoDB credentials through chart secrets or dependency Secret settings; override image tags, ingress, resources, namespace, and persistence.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

A Helm chart for deploying Product Console - Lerian Studio's web interface for managing Midaz ledger.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8.0+ (OCI registry support is enabled by default)

## Installing the Chart

To install the chart with the release name `product-console`:

```bash
helm install product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version <version> -n product-console --create-namespace
```

**This chart pins its own namespace.** `namespaceOverride` ships as
`product-console`, and every template writes that into `metadata.namespace`, so
resources land there whatever `-n` says. `--create-namespace` only creates the
release namespace, so installing with `-n <anything else>` fails on a fresh
cluster with `namespaces "product-console" not found`. Either install into
`product-console` as printed above, or set `namespaceOverride` to the namespace
you passed to `-n`. The bundled MongoDB does not inherit `namespaceOverride`: it
lands in `global.namespaceOverride` when that is set, and in the namespace you
passed to `-n` otherwise. Keeping the two the same is what lets the console read
the bundled database's password by itself, since a Secret cannot be read across
namespaces (see [MongoDB and readiness](#mongodb-and-readiness)).

## Configuration

See [values.yaml](values.yaml) for the full list of configuration options.

### Quick Start

Copy `values-template.yaml` and customize it for your deployment:

```bash
cp values-template.yaml my-values.yaml
# Edit my-values.yaml with your configuration
helm install product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version <version> -f my-values.yaml -n product-console --create-namespace
```

### Key Configuration Options

Every `configmap.<KEY>` and its shipped default are declared in
`templates/configmap.yaml` (`values.yaml`'s `configmap:` map is intentionally
empty — set a key there only to override its shipped default).

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `lerianstudio/product-console` |
| `image.tag` | Container image tag | Chart appVersion |
| `ingress.enabled` | Enable ingress | `false` |
| `configmap.NODE_ENV` | Node environment | `production` |
| `configmap.MIDAZ_CONSOLE_PORT` | Console port | `8081` |
| `configmap.MIDAZ_BASE_PATH` | Midaz API base path | `http://midaz-ledger.midaz.svc.cluster.local:3002/v1` |
| `configmap.NEXTAUTH_URL` | Public URL NextAuth uses for OAuth callbacks | `ingress.hosts[0].host` (as `https://<host>`) when ingress is enabled with a host, else `http://localhost:8081` |
| `configmap.TRUSTED_PROXIES` | Comma list of CIDRs the console trusts as its own hops, see [Client IP resolution](#client-ip-resolution) | unset (no client IP is resolved) |
| `configmap.PLUGIN_AUTH_PUBLIC_BASE_PATH` | Browser-facing Access Manager address used for the SSO redirect, see [Keys with no default](#keys-with-no-default) | unset (falls back to the cluster-internal `PLUGIN_AUTH_BASE_PATH`) |
| `configmap.MFA_ENABLED` | Tells the console the Access Manager may answer a password with an MFA challenge, see [Keys with no default](#keys-with-no-default) | unset (the image's own default) |
| `configmap.MIDAZ_CONSOLE_BASE_PATH` / `configmap.MIDAZ_CONSOLE_SERVICE_HOST` | The console's own public origin and in-cluster host name | unset |
| `configmap.FETCHER_BASE_PATH` / `PLUGIN_FEES_BASE_PATH` / `FLOWKER_BASE_PATH` / `TRACER_BASE_PATH` | Optional sibling services, see [Keys with no default](#keys-with-no-default) | unset (feature addressed nowhere) |
| `readinessProbe.path` | Readiness endpoint. Defaults to the MongoDB-independent one, see [MongoDB and readiness](#mongodb-and-readiness) | `/api/admin/health/alive` |
| `secrets.NEXTAUTH_SECRET` | NextAuth secret (must be supplied for production) | `""` |
| `secrets.MONGODB_PASS` | MongoDB password. Leave empty with the bundled MongoDB: the console reads the subchart's own generated password, see [MongoDB and readiness](#mongodb-and-readiness) | `""` |
| `secrets.PLUGIN_AUTH_CLIENT_ID` | Alternative to `configmap.PLUGIN_AUTH_CLIENT_ID` when the client_id shouldn't sit in a ConfigMap; when set, the ConfigMap key is omitted | `""` |

### Inter-service defaults (cross-namespace)

Product Console talks to several sibling Lerian services (Midaz ledger,
plugin-access-manager, CRM, Reporter). By default these are addressed by the
standard in-cluster FQDN (`<service>.<namespace>.svc.cluster.local`), so the
chart works out of the box even when each dependency is deployed in its own
namespace — no service mesh or DNS wiring required. Override the
corresponding `configmap.<KEY>` if your environment uses different
service/namespace names.

| Service | `configmap` keys | Default host |
|---|---|---|
| Midaz ledger | `MIDAZ_API_HOST`, `MIDAZ_TRANSACTION_BASE_HOST` (+ `*_PORT`/`*_PATH`) | `midaz-ledger.midaz.svc.cluster.local` |
| plugin-access-manager (auth) | `PLUGIN_AUTH_HOST` (+ `PLUGIN_AUTH_PORT`/`PLUGIN_AUTH_BASE_PATH`) | `plugin-access-manager-auth.plugin-access-manager.svc.cluster.local` |
| plugin-access-manager (identity) | `PLUGIN_IDENTITY_HOST` (+ `PLUGIN_IDENTITY_PORT`/`PLUGIN_IDENTITY_BASE_PATH`) | `plugin-access-manager-identity.plugin-access-manager.svc.cluster.local` |
| CRM plugin | `CRM_BASE_PATH` | `http://midaz-crm.midaz.svc.cluster.local:4003/v1/` |
| Reporter | `REPORTER_BASE_PATH` | `http://reporter-manager.reporter.svc.cluster.local:4005/v1` |

### Keys with no default

Most `configmap.<KEY>` entries ship a default that is right for a standard
in-cluster install. Nine do not, because no default is safe to invent for
them: an address that depends on where you deployed a sibling release, an
assertion about the deployment, or a flag the browser reads. The chart writes
nothing for an unset one, so the console keeps whatever its own image does.

| Key | What it is | If it is wrong or missing |
|---|---|---|
| `TRUSTED_PROXIES` | CIDRs the console trusts as its own hops | Missing: no caller is ever named, so a tenant IP allowlist has nothing to judge. Wrong: see [Client IP resolution](#client-ip-resolution) |
| `PLUGIN_AUTH_PUBLIC_BASE_PATH` | Browser-facing Access Manager address (absolute, https, ends in `/v1`) | Missing: SSO redirects the browser to the cluster-internal name, which it cannot resolve. Only local dev, where both are `localhost`, can leave it out |
| `MFA_ENABLED` | Assertion that the Access Manager in front of this console may answer a correct password with an MFA challenge. It enables MFA for nobody — that is per user, in the Access Manager | Missing where MFA is on: the console does not recognise the challenge, and a user with MFA enabled cannot sign in at all |
| `MIDAZ_CONSOLE_BASE_PATH` | The console's own public origin, as the browser sees it | Links the console builds for itself point where the user cannot reach |
| `MIDAZ_CONSOLE_SERVICE_HOST` | The console's own in-cluster host name | The console cannot address itself from inside the cluster |
| `FETCHER_BASE_PATH` | Fetcher, `/v1` | Feature pages have no address to call |
| `PLUGIN_FEES_BASE_PATH` | Fees, `/v1` | idem |
| `FLOWKER_BASE_PATH` | Flowker, `/v1` | idem |
| `TRACER_BASE_PATH` | Tracer, **bare origin, no `/v1`** — the console adds it | idem; with a `/v1` suffix every call goes to `/v1/v1/...` |

The four sibling services are optional deployments, which is why the chart
invents no address for them: a default would turn "this feature is not
installed" into a connection error on the page.

**Set each key in one place only.** `TRUSTED_PROXIES`, `MFA_ENABLED` and
`PLUGIN_AUTH_PUBLIC_BASE_PATH` were reachable only through `extraEnvVars`
before they were declared here, and still work from there, so no existing
install has to change. Supplying one through both `configmap` and
`extraEnvVars` is refused at render time: both write into the same ConfigMap
`data` map, and the surviving value would be whatever the YAML parser kept.

`MULTI_TENANT_ENABLED` and `NEXT_PUBLIC_DEMO_MODE` are platform configuration
rather than customer surface, so the chart declares no key for them: an install
that needs either one sets it through `extraEnvVars`.

### Client IP resolution

`TRUSTED_PROXIES` is the comma list of CIDRs the console treats as its own
infrastructure hops while reading `X-Forwarded-For`, so it can tell which
address in that chain is the real caller. The container image ships it empty on
purpose, so each environment must name its own hops.

**Set it through `configmap`:**

```yaml
configmap:
  TRUSTED_PROXIES: "198.51.100.0/24" # example: the /24 your edge egresses from
```

`configmap` is an explicit allowlist of the keys `templates/configmap.yaml`
declares. `TRUSTED_PROXIES` was not one of them before, so a value put there
was accepted by `helm lint`, `helm template` and `helm upgrade` and then
dropped, with nothing in the deploy path to say so; `extraEnvVars` was the only
working channel. It is declared now, and `extraEnvVars` still works, so an
install already delivering it from there needs no change — but set it in one
place only, or the render is refused.

**Name the addresses that are actually in front of this service**, meaning the
ingress and load-balancer addresses as they appear as `X-Forwarded-For` hops.
Every proxy APPENDS the address it observed and rewrites nothing, so the hop an
ingress controller contributes is its own peer, typically the load balancer in
front of it, not the ingress pod. Two ranges that look plausible and are always
wrong:

- **The Service (cluster IP) CIDR.** A cluster IP is a virtual destination and
  is never the source of a packet, so it can never appear as a hop. Trusting it
  matches nothing.
- **The pod CIDR.** It covers every pod in the cluster, so it tells the console
  to discard any in-cluster address. A workload already inside the cluster can
  then send `X-Forwarded-For: <an address on your allowlist>` through the
  ingress: its own pod IP is discarded as infrastructure, the walk continues
  left, and the console hands the Access Manager the address the caller chose.
  With nothing configured the console would have refused to name any caller,
  so this setting is worse than leaving it empty.

**Empty means no caller is ever named.** The console resolves no client IP and
stamps `X-Client-Ip-Resolution: unresolved; reason=trusted-proxies-not-configured`
on its calls to Lerian backends. That header is always `unresolved; reason=<cause>`
and never the bare word `unresolved`, so a detection rule written as an exact
match on `unresolved` never fires. At app image `1.12.0`, the version this chart
deploys, there are SEVEN causes. Five report the trust boundary itself:
`trusted-proxies-not-configured`, `forwarded-for-absent`,
`forwarded-for-malformed`, `all-hops-trusted` and `unresolved-upstream`. Two
more report that the resolver never got to run: `request-headers-unavailable`
and `client-ip-extraction-failed`. A rule enumerating only the first five misses
exactly the two cases that mean the console is broken rather than
under-configured.

**The header does not reach every backend, on purpose.** At app image `1.12.0`,
12 of the console's 14 outbound services stamp it. The two that do not are the
Slack webhook and the Pix indirect rail, and both omissions are a deliberate
privacy boundary the console holds under test: at that tag,
`forward-client-ip-exclusions.test.ts` asserts that neither service sends the
header "even when a real client IP IS resolvable", because the client IP is
personal data and the Pix indirect rail terminates at BTG, an external bank. Do
not read those two as missing hops to be closed: traffic on them is out of scope
for client-IP attribution, not unattributed, and any tooling keyed on the
header's presence should treat them that way.

**Entries can be refused.** An entry that is not a CIDR is refused, and so is
one wider than `/8` (IPv4) or `/48` (IPv6). A refused entry is named in the
console's own log ONLY when the whole list is refused, which also puts the
deployment back in the empty case above. A list that keeps at least one usable
range drops its bad entries silently, so `198.51.100.0/24,0.0.0.0/0` trusts the
first range, discards the second, and logs nothing naming the discarded entry.
The console still logs whenever a request ends up with no caller named, so the
warnings are there; the entry that caused them is not.

**Do not widen the range to be safe.** Trusting a range means discarding its
hops and continuing to look left, so a range that covers real callers (a
corporate VPN, a peered VPC, an in-cluster client) makes those callers
invisible and lets the walk reach a hop the caller wrote. Narrow is correct.

### MongoDB and readiness

**With the bundled MongoDB, land both in one namespace and there is nothing to
configure.** `configmap.MONGO_HOST` defaults to the Service the subchart really
creates for the topology shipped here, and `MONGODB_PASS` is read straight from
the Secret the subchart generates (key `mongodb-root-password`), so the console
reaches its database and authenticates to it without an operator copying a
generated password by hand.

**Two bundled configurations have no default and the chart says so.** The
default host follows the subchart's own name, which is what its Service is
called for a standalone MongoDB and nothing else. Set
`mongodb.architecture: replicaset` and the subchart publishes a headless
Service plus one DNS name per replica; set `mongodb.service.nameOverride` and it
renames the Service outright. In both cases the chart refuses to render until
you set `configmap.MONGO_HOST` (or `global.datastores.mongo.host`), and the
refusal prints the host to use, plus the `replicaSet=` parameter to add to
`configmap.MONGO_PARAMETERS` for a replica set. Refusing is deliberate: the
alternative is a console that comes up Ready pointing at a name that resolves
in no namespace. Set both, and the rename wins: the refusal names the Service
Bitnami really creates for that combination, which is the renamed one.

**The password wiring** above applies only while the subchart's namespace equals
the console's, which is what `-n product-console` gives you as long as
`global.namespaceOverride` is unset. Your own value still wins when you set one,
either as `secrets.MONGODB_PASS` or in your own Secret, which is switched on
with `useExistingSecret: true` and named with `existingSecretName` (the switch
is a boolean; the name lives in the other key).

**The one case that needs you: a namespace split.** The subchart does not
inherit `namespaceOverride`; it lands in `global.namespaceOverride` when set and
in the `-n` namespace otherwise, while the console always lives in
`namespaceOverride`. So setting `global.namespaceOverride` splits them even when
`-n` matches. When those two namespaces differ a Secret cannot be read across
them, so the chart leaves `MONGODB_PASS` alone and the install notes say so.
Either move the subchart next to the console by naming the console's namespace
in `global.namespaceOverride`, which the install notes print as a command to
complete with your own values file and flags (with `global.namespaceOverride`
set the subchart reads it instead of `-n`, so changing `-n` alone no longer
moves it; with it unset the subchart follows `-n`, which is why a fresh install
with `-n product-console` lands it beside the console), or set both of these to
the same value, or every MongoDB-backed page (product enablement, guided tour)
fails on an auth error:

```yaml
mongodb:
  auth:
    rootPassword: "<your password>"
secrets:
  MONGODB_PASS: "<the same password>"
```

Moving the subchart re-creates the database. With the shipped values it is a
standalone Deployment plus a PersistentVolumeClaim named after it, and that
claim carries no `helm.sh/resource-policy`, so the upgrade brings the database
up in the console's namespace with an empty volume and deletes the volume it
left behind. Back up whatever that database holds before you run it and restore
it afterwards: nothing carries the data across. Whether a split console ever
authenticated against that database depends on credentials the operator wired
by hand, which the chart cannot see, so do not assume the volume is empty.

**Compatibility of the `MONGO_HOST` default.** `configmap.MONGO_HOST` and
`global.datastores.mongo.host` still win, so an operator who names their host
keeps it. One configuration's WORKING value moves: a deployment that runs its
own MongoDB as a Service literally named `mongodb` in the console's namespace,
left `mongodb.enabled: true`, and never set `MONGO_HOST` was resolving the old
bare `mongodb` through the pod's DNS search path. That deployment now points at
the bundled subchart. The remedy is one line, `configmap.MONGO_HOST: mongodb`,
or `mongodb.enabled: false` if the bundled database was never wanted.

**Readiness does not gate on MongoDB by default.** `readinessProbe.path`
defaults to `/api/admin/health/alive`. The MongoDB-aware endpoint,
`/api/admin/health/readyz`, returns 200 only once the app has connected, and
app image `1.12.0` connects on the first request that needs the database rather
than at startup. Readiness on `readyz` therefore deadlocks a fresh pod: not
Ready, so no traffic, so no connection, so never Ready. Measured on image
`1.12.0`: `readyz` stays 503 (`readyState=0`) for as long as the pod is left
alone, and turns 200 within three seconds of the first request to a
MongoDB-backed route.

**What that default costs you, plainly.** Readiness no longer detects the
database. A MongoDB outage does not withdraw a pod from the Service: every
replica stays Ready and keeps taking traffic for MongoDB-backed routes, which
answer 500 rather than being routed away, and an install whose database is
unusable still reports `STATUS: deployed`. Scrape `/api/admin/health/readyz` and
alert on it, because it remains the honest report of whether a pod can serve a
MongoDB-backed page; it is only no longer wired to anything that acts on it. Set
`readinessProbe.path: /api/admin/health/readyz` to get that detection back, and
only on an app image whose `readyz` opens the connection it reports on: on image
`1.12.0` it never does, and the pod deadlocks as above. Keep liveness on a
MongoDB-independent path, or a database outage becomes a crash-loop.

### Managed Cloud (`global.cloud`)

These fields are consumed by `lerian-common` and let an operator set a value
ONCE per environment for every chart that shares it, instead of pinning it
per-component. A native `configmap.<KEY>` (see table above / `values.yaml`)
always wins over the corresponding mask.

| `global.*` field | Consumed by | Overriding native key(s) |
|---|---|---|
| `global.auth.enabled` / `global.auth.host` | `lerian-common.auth.env` | `configmap.PLUGIN_AUTH_ENABLED` / `configmap.PLUGIN_AUTH_HOST` |
| `global.observability.enabled` | `lerian-common.globalValue` | `configmap.ENABLE_TELEMETRY` |
| `global.datastores.mongo.{uri,host,port,user,params}` | `lerian-common.datastore.value` | `configmap.MONGODB_URI` / `MONGO_HOST` / `MONGO_PORT` / `MONGODB_USER` / `MONGO_PARAMETERS` |

**Authorization is OFF unless it is switched on explicitly.** The console
enforces permissions only when the variable it reads is the word `true`:
`PLUGIN_AUTH_ENABLED` on the server, `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` in the
browser. Any other rendered value (`false`, empty, `1`, `TRUE`, `yes`) reads as
OFF for that half: pages open without a permission check and upstream calls
carry no bearer. `/api/**` requires a session when either `PLUGIN_AUTH_ENABLED`
or `OAUTH_ENABLED` is the word `true`, and answers without one only when both
are off; `OAUTH_ENABLED` alone keeps the session requirement but never enables
permission checks or bearer forwarding.

How this chart renders the two variables: the server value is
`configmap.PLUGIN_AUTH_ENABLED` when set, else `global.auth.enabled`, else
`false`. The browser value copies the server value while
`configmap.NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` is unset or empty. A non-empty
browser key is rendered as given and is never compared with the server value,
so `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED: "TRUE"` next to an enabled server yields
server ON and browser OFF. Leave the browser key unset, or set both to the same
word. A staging or production release MUST set `global.auth.enabled: true` (or
the native key) on purpose; the console does not fail closed on a missing
switch (product decision, 2026-09-12, recorded in the console repository's
[`SECURITY.md`](https://github.com/LerianStudio/product-console/blob/develop/SECURITY.md)).

`global.cloud: aws` also applies automatically (no chart change needed): it
sets `MONGO_PARAMETERS` to the real DocumentDB connection-string shape
(`tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&...`)
whenever no more specific override (native key or `global.datastores.mongo.params`)
is set. `gcp`/`azure` have no Mongo preset today.

## Uninstalling the Chart

```bash
helm uninstall product-console
```
