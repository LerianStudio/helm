# system-facts-helm

## Chart Contract

- Chart type: `single-service`
- Required secrets: `system-facts.secrets.POSTGRES_PASSWORD` (no default). `system-facts.secrets.LICENSE_KEY` (with `system-facts.configmap.ORGANIZATION_IDS`) unless the license gate is turned off with `LICENSE_ENABLED=false`: the application's license gate is on by default and refuses to boot without a key. `REDIS_PASSWORD` only when Redis/Valkey auth is on, `MULTI_TENANT_SERVICE_API_KEY` and `MULTI_TENANT_REDIS_PASSWORD` only when `system-facts.multiTenant.enabled=true`. When the bootstrap Job runs, `global.externalPostgresDefinitions.postgresAdminLogin.password` and `.boilerplateCredentials.password` are required too — or point both at an existing Secret.
- Dependency notes: `lerian-common-helm` (library, no objects of its own) plus PostgreSQL and Valkey, both declared with exact pins, condition-gated and **disabled by default** — the target environments provide them externally. Archives are not vendored in git; `helm dependency update` resolves them from `Chart.lock`.
- Access Manager prerequisite: `plugin-access-manager` app **3.11.2 or later** (it catalogs the `system-facts` and `internal-facts-worker` applications), plus `AUTH_M2M_INVERSION_ENABLED` and `AUTH_M2M_PRODUCT_FORWARD_ENABLED` set to `"true"` on the service when authorization is on. See [Access Manager](#access-manager).
- Production overrides: image tag and pull secrets, ingress host/TLS, resources, autoscaling, `system-facts.configmap.POSTGRES_HOST` / `REDIS_HOST`, and every credential above. Never ship a published default as a production secret.
- Source/license: Source is in `github.com/LerianStudio/helm/tree/main/charts/system-facts`. The application is distributed under the Lerian Studio General License; running it requires a Lerian license.

Helm chart for [`LerianStudio/system-facts`](https://github.com/LerianStudio/system-facts) — the Lerian fact registry, with an optional `internal-facts-worker` workload.

## Install

From the OCI registry:

```sh
helm upgrade --install system-facts \
  oci://ghcr.io/lerianstudio/system-facts-helm \
  --namespace system-facts --create-namespace \
  --values my-values.yaml
```

From a working copy of this repository:

```sh
helm dependency update ./charts/system-facts
helm upgrade --install system-facts ./charts/system-facts \
  --namespace system-facts --create-namespace \
  --values ./charts/system-facts/values-template.yaml
```

`values-template.yaml` is the starting point for an environment: it carries only the keys an install actually has to decide.

## Access Manager

With authorization on (`global.auth.enabled=true`, which renders `PLUGIN_AUTH_ENABLED=true`), System Facts authorizes every call through the Access Manager. The chart does not install it and does not declare it as a dependency. It must already be running at `global.auth.host`, at a version that knows both applications.

| Access Manager app | What it adds |
|--------------------|--------------|
| `3.11.0` | Catalogs the `system-facts` application, the target of every producer credential. |
| `3.11.2` | Catalogs the `internal-facts-worker` application, the source of the worker credential. **Minimum for this chart.** |

Earlier versions do not catalog these applications. The Access Manager requires a credential's source to be catalogued, so a worker credential cannot declare `internal-facts-worker` as its source before `3.11.2`. At the time of writing the `plugin-access-manager` chart (`9.8.2`) still ships app `3.11.1`: until a chart release carries `3.11.2`, set the Access Manager image tags to `3.11.2` or later.

System Facts also refuses to boot with authorization on unless both M2M flags are the exact string `true`. Set them on the System Facts service, not on the callers:

```yaml
global:
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth:4000"

system-facts:
  extraEnvVars:
    - name: AUTH_M2M_INVERSION_ENABLED
      value: "true"
    - name: AUTH_M2M_PRODUCT_FORWARD_ENABLED
      value: "true"
```

`1`, `TRUE` and a leading space all count as off. Without inversion, every M2M producer gets `401` `SF-0013` on a service that boots and reports healthy. Without the product forward, every M2M token is denied with a `403`.

## Database credentials

Passwords have **no defaults**. `system-facts.secrets.POSTGRES_PASSWORD` and `global.externalPostgresDefinitions.boilerplateCredentials.password` are two separate values that must be equal: the second is the password the bootstrap Job gives the role, the first is the one the service logs in with. The chart does not link them, so a mismatch creates the role with one password while the service starts with another.

When the bootstrap is enabled, the render fails unless the role password is set (`boilerplateCredentials.password`) or an existing Secret is named (`boilerplateCredentials.useExistingSecret.name`). An empty inline value causes rendering to fail.

To keep one source of truth, put both keys in one existing Secret and name it on both sides: `system-facts.useExistingSecret: true` with `system-facts.existingSecretName` (key `POSTGRES_PASSWORD`) for the service, and `boilerplateCredentials.useExistingSecret.name` (key `DB_PASSWORD_BOILERPLATE`) for the bootstrap:

```yaml
global:
  externalPostgresDefinitions:
    enabled: true
    boilerplateCredentials:
      useExistingSecret:
        name: my-db-credentials     # key: DB_PASSWORD_BOILERPLATE
```

The bootstrap Job only ever runs against an **external** database: it creates the database, the role and the grants. Leave it disabled when the role already exists.

The Job sets the role password on creation only; it never rotates it. To rotate the password of an existing role:

1. Change it in PostgreSQL as an administrator (`ALTER ROLE "system-facts" PASSWORD '...'`).
2. Set `system-facts.secrets.POSTGRES_PASSWORD` and `DB_PASSWORD_BOILERPLATE` (`boilerplateCredentials`) to that same value.
3. Keep the bootstrap Job disabled.

## Datastores

PostgreSQL and Valkey are declared as subcharts but disabled by default. Enable them for a self-contained install (chaos/fuzzing environments, local clusters):

```yaml
postgresql:
  enabled: true
  external: false
valkey:
  enabled: true
  external: false
```

When enabled, hosts resolve to the subchart Services and the passwords are read straight from the subchart's own Secret rather than copied into this chart's — a copy would go stale the moment the subchart rotated it.

## Global masks (`global.*`)

Every `global.*` mask below is env-wide: set it once per environment and every
component that consumes it inherits the value, with a native
`system-facts.configmap.<KEY>` always overriding it, and this component's own
productized param (`system-facts.<field>`) as the last fallback before the
hardcoded default — so an install that sets none of this renders unchanged.

```yaml
global:
  cloud: "aws"   # aws | gcp | azure — topology preset (TLS/SSL mode); leave unset for the bundled dev topology
  datastores:
    postgres: { host: "my-rds.example.com", user: "system-facts" }
    redis: { host: "my-elasticache.example.com", port: "6379" }
  observability: { enabled: true, otlpEndpoint: "otel-collector:4317" }
  auth: { host: "http://plugin-access-manager-auth:4000" }
  idp: { host: "http://plugin-access-manager-identity:4001" }
  multiTenant: { url: "http://tenant-manager:8080", redisHost: "my-elasticache.example.com" }
  serviceDiscovery: { address: "consul.internal:8500" }
  streaming: { brokers: "redpanda:9092" }
```

- `cloud` sets the connection TOPOLOGY (TLS, SSL mode) for `global.datastores`;
  only the ENDPOINTS (host/port/user) come from `global.datastores` itself — a
  cloud preset can't know your RDS host.
- `datastores` only declares `postgres`/`redis` sub-keys — this chart has no
  Mongo or message-broker datastore, so `mongo`/`broker` sub-keys are not
  applicable here (don't set them, they're inert).
- `observability` covers enable/endpoint/deployment-environment only.
  Per-service OTEL identity (library name, service name, version) is NOT a
  global mask — it stays productized under `system-facts.otel.libraryName` /
  `.serviceName` (version tracks `system-facts.image.tag`).
- **`objectStorage` is not applicable to this chart** — system-facts has
  no S3/object-storage surface (no template calls `lerian-common.objectStorage.value`).
  Do not add this block; there is nothing here to configure.

## Optional capabilities

Each is off by default, gated per-component; the connection/topology config
for the enabled ones comes from the matching `global.*` mask above:

```yaml
system-facts:
  multiTenant: {enabled: true}       # requires global.multiTenant.url and .redisHost (or configmap.MULTI_TENANT_*)
  streaming: {enabled: true}         # requires global.streaming.brokers
  serviceDiscovery: {enabled: true}
  otel: {enabled: true}              # also gates the OTLP podEnv (local-collector sidecar via HOST_IP); global.observability.enabled independently controls ENABLE_TELEMETRY/endpoint
```

`aws.rolesAnywhere` adds the IAM Roles Anywhere sidecar and the IMDS env for workloads outside EKS.

## Schema migrations

`migrations.enabled` is **false** by default, and `migrations.image.repository` is
never the application image: the Job refuses to render without a runner image.

Nothing else applies the root (control-plane) migration sequence. The service
image is `gcr.io/distroless/static-debian12` (`ENTRYPOINT /service`): it ships the
SQL at `/migrations` but has no `migrate` binary and no shell. Without the Job the
control-plane tables (`fact_contracts`, `reference_types`, `outbox_events`,
`systemplane_entries`, `namespace_bindings`) are never created, and `/v1/contracts`
and `/v1/reference-types` answer 500 (`relation "fact_contracts" does not exist`).

```yaml
migrations:
  enabled: true
  image:
    tag: ""   # empty tracks the chart appVersion; the app release writes it to .migrations.image.tag
```

- **Two sequences, two owners.** This Job applies only the flat root sequence
  (`schema_migrations`). The tenant-partition sequence (`migrations/tenant`) stays
  with the service: boot in single-tenant mode, the `tenant-added` event in
  multi-tenant mode, into `schema_migrations_tenant`. `golang-migrate` does not
  recurse, so the runner never touches it.
- **Multi-tenant.** The contract catalog is environment-global (ADR-004), so the
  Job is **not** refused when multi-tenant is enabled, unlike charts whose database
  is per tenant.
- **Hook.** `argocd.argoproj.io/hook: Sync` with `BeforeHookCreation,HookSucceeded`.
  Sync, not PreSync: the Job reads `POSTGRES_PASSWORD` from a Secret this chart
  renders, which PreSync would run before. There is no `helm.sh/hook`, so a plain
  `helm install` does not run the Job; run the runner image by hand there.
- **Password.** It follows the workload: the bundled `postgresql` subchart Secret
  when bundled, this chart's Secret (or `useExistingSecret`) when external.
  `migrations.postgres.passwordSecret` overrides both.
- **Runner image.** Published by the `system-facts` release as
  `system-facts-migrations`; `.migrations.image.tag` is written by the release.

## internal-facts-worker (optional)

`worker.enabled=true` adds a second workload next to the API: the `system-facts-worker` image, which consumes product events from RedPanda and delivers them to the System Facts API as facts. Off by default, so a chart bump alone changes nothing.

It renders a Deployment, ConfigMap, Secret and ServiceAccount, and **no** Service, Ingress, HPA, PDB, database, Redis or migrations: the admin port (`/health`, `/readyz`) is for the kubelet only. The worker pod carries its own `app.kubernetes.io/name` (`<name>-worker`), because the API Service, HPA and PDB select on the API's name and would otherwise pick it up.

| Value | Env | Notes |
|-------|-----|-------|
| `worker.systemFacts.url`, `.authUrl` | `SYSTEM_FACTS_URL`, `SYSTEM_FACTS_AUTH_URL` | required |
| `worker.streaming.brokers` | `STREAMING_CONSUMER_BROKERS` | required. Consumer variables only: `STREAMING_ENABLED` / `STREAMING_BROKERS` do nothing for the worker |
| `worker.streaming.saslMechanism`, `.saslUsername` | `STREAMING_SASL_*` | password in `worker.secrets.STREAMING_SASL_PASSWORD` |
| `worker.streaming.requireSecurity` | `REQUIRE_BROKER_SECURITY` | default `true`: refuses to boot without TLS+SASL, and on a missing or ungranted topic |
| `worker.secrets.SYSTEM_FACTS_CLIENT_ID/_SECRET` | same | required. An M2M Application targeting system-facts that may register the reserved `lerian` prefix (`catalog:reserved`); the reconciler grants every such Application all roles today |
| `worker.multiTenant.enabled`, `.env` | `MULTI_TENANT_ENABLED`, `ENV_NAME` | `env` required when enabled |
| `worker.products` | `WORKER_PRODUCTS` | default `[]`: every product. System Facts producer names `midaz`, `plugin-br-pix-jd`; `plugin-br-pix-jd` requires `midaz`. Rendered comma-joined in the given order |
| `worker.systemFacts.allowInsecureHttp` | `SYSTEM_FACTS_ALLOW_INSECURE_HTTP` | default `false`, always rendered. `true` admits plain `http://` for `url` and `authUrl`; only inside a namespace whose pod-to-pod traffic is already encrypted (istio ambient). The worker logs a WARN at every boot |

The consumer switch (`STREAMING_CONSUMER_ENABLED=true`) is always rendered. The chart **refuses to render** when:

- `STREAMING_CONSUMER_TOPICS`, `_COMMANDS`, `_APPS` or `_GROUP` is set through `worker.configmap` / `worker.extraEnvVars`: the products fix them and the binary refuses to boot on them;
- the consumer switch is turned off (the worker would boot, stay ready and read nothing);
- a required URL, broker, credential or SASL username/password is missing;
- `worker.replicaCount` exceeds `worker.partitionCeiling` (default `1`). Parallelism is bounded by distinct tenants, so extra replicas idle with a green probe. Single-tenant Midaz stamps tenant `default` on every record: the ceiling there is 1;
- `worker.terminationGracePeriodSeconds` is below 60 (consumer close 30 s + admin drain 10 s + telemetry flush);
- `WORKER_PRODUCTS` (from `worker.products`, `worker.configmap` or `worker.extraEnvVars`) has an empty entry, a duplicate, an unknown product, or `plugin-br-pix-jd` without `midaz` (its manifest mirrors `lerian.midaz.transaction_id`);
- `SYSTEM_FACTS_URL` or `SYSTEM_FACTS_AUTH_URL` is plain `http://` while `SYSTEM_FACTS_ALLOW_INSECURE_HTTP` is not `true`. There is no loopback exception: a pod never reaches the API on its own loopback;
- `SYSTEM_FACTS_ALLOW_INSECURE_HTTP` (through `worker.configmap` or `worker.extraEnvVars`) is not a Go boolean (`true`/`false`, `1`/`0`, `t`/`f`, `T`/`F`, `TRUE`/`FALSE`, `True`/`False`): the binary refuses it at boot.

The image tag tracks `appVersion` when `worker.image.tag` is empty; the app release writes `.worker.image.tag`.

### Product selection and in-cluster http

`worker.products` selects which products this worker serves. A product left out has no topic checked by the broker preflight, no consumer subscription and no contract registered by this worker, so the worker identity needs no broker grant on that product's topic. `plugin-br-pix-jd` requires `midaz`. A deployment that drops `plugin-br-pix-jd` from the worker must keep Pix JD's own in-process System Facts emitter on, or Pix JD facts stop. An empty list keeps every product.

`worker.systemFacts.allowInsecureHttp` is for cluster-local URLs inside a namespace whose pod-to-pod traffic is already encrypted (for example `istio.io/dataplane-mode: ambient`) only. The worker logs it as a WARN at every boot, production included.

Both values need a worker image that carries the matching binary change (system-facts #65 and #71). An older image ignores the unknown variables: it still refuses to boot on a plain `http://` URL and still consumes every product.

## Permission declaration (RI)

The API publishes its embedded `permissions.yaml` to the Access Manager at boot (lib-auth `declaration.WireFromEnv`). It is off by default; with the gate on, the app refuses to boot without the host and the client pair:

```yaml
global:
  idp: { host: "http://plugin-access-manager-identity:4001" }

system-facts:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
  secrets:
    IDP_M2M_CLIENT_ID: "<client-id>"
    IDP_M2M_CLIENT_SECRET: "<client-secret>"
```

| Key | Where | Rendered |
|---|---|---|
| `IDP_DECLARATION_ENABLED` | `system-facts.configmap` > `system-facts.extraEnvVars` entry (legacy) > `global.idp.declarationEnabled` | ConfigMap, always, default `"false"` |
| `IDP_HOST` | same precedence, with `global.idp.host` | ConfigMap, only when non-empty |
| `IDP_M2M_CLIENT_ID` / `IDP_M2M_CLIENT_SECRET` | `system-facts.secrets` | Secret, each only when non-empty |

- All four keys are rendered by `lerian-common.idp.*` and come out once each: `IDP_*` entries in `system-facts.extraEnvVars` still work, but feed the helper instead of the raw passthrough.
- With `useExistingSecret: true`, put the client pair in the existing Secret.
- Prefer the gate in `system-facts.configmap`: `global.idp.declarationEnabled` turns it on for every component of the release, and each one then needs its own client pair. The worker never declares and renders none of these keys.

## Environment variables

Non-secret values live in the ConfigMap, credentials in the Secret. Any value can be overridden natively through `system-facts.configmap.<ENV_VAR_NAME>`, which wins over the productized parameter.

## A typo in your values is not an error

`values.schema.json` validates the top level strictly, but `system-facts` and
`global` both set `additionalProperties: true`, and `system-facts` declares only
`configmap` and `secrets` of its own. Everything else you put under them is
accepted without being checked — including a key the chart does not read.

So `system-facts.revisionHistoryLimits`, where the chart reads
`system-facts.revisionHistoryLimit`, installs cleanly, reports success, and
leaves the Deployment on the default of 10. The same applies to a key this
chart used to have and no longer does: an upgrade keeps the stale entry in your
values and quietly falls back.

Nothing in `helm install` will tell you. Render the version you are actually
installing and read the field back:

```sh
helm template system-facts \
  oci://ghcr.io/lerianstudio/system-facts-helm \
  --version <chart-version> \
  --values my-values.yaml \
  | grep -E 'revisionHistoryLimit|replicas:'
```

`--version` matters: without it Helm pulls the newest chart in the registry,
which is not necessarily the one your release is on, and you would be reading
back the wrong template.

Note that `spec.replicas` is emitted **only** when
`system-facts.autoscaling.enabled` is `false`. It defaults to `true`, so on a
default install the field is absent from the Deployment entirely and replica
count is the HPA's business — checking `replicas:` proves nothing unless you
turned autoscaling off.

Environments managed through the Lerian GitOps repository are covered: the
chart-update pipeline runs an orphan-key gate that fails the bump when an
environment sets a key the chart no longer declares. This section is for
installs outside it.

## Upgrades

Per-version notes are generated under `docs/` as releases ship.
