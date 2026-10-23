# public-bedatty-application-helm

## Chart Contract

- Chart type: `single-service`
- Required secrets: `boilerplate.secrets.POSTGRES_PASSWORD` (no default). `REDIS_PASSWORD` only when Redis/Valkey auth is on, `MULTI_TENANT_SERVICE_API_KEY` and `MULTI_TENANT_REDIS_PASSWORD` only when `boilerplate.multiTenant.enabled=true`. When the bootstrap Job runs, `global.externalPostgresDefinitions.postgresAdminLogin.password` and `.boilerplateCredentials.password` are required too — or point both at an existing Secret.
- Dependency notes: `lerian-common-helm` (library, no objects of its own) plus PostgreSQL and Valkey, both declared with exact pins, condition-gated and **disabled by default** — the target environments provide them externally. Archives are not vendored in git; `helm dependency update` resolves them from `Chart.lock`.
- Production overrides: image tag and pull secrets, ingress host/TLS, resources, autoscaling, `boilerplate.configmap.POSTGRES_HOST` / `REDIS_HOST`, and every credential above. Never ship a published default as a production secret.
- Source/license: Source is in `github.com/LerianStudio/helm-boilerplates`; license is Apache-2.0.

Helm chart for [`LerianStudio/public-bedatty-application`](https://github.com/LerianStudio/public-bedatty-application) — the Lerian reference template for a Go DDD service. Fork it as the starting point for a new service chart; the fullstack variant (`public-bedatty-application-fullstack`) adds a React UI on the same host.

## Install

From the OCI registry:

```sh
helm upgrade --install public-bedatty-application \
  oci://ghcr.io/lerianstudio/helm-boilerplates/public-bedatty-application-helm \
  --namespace public-bedatty-application --create-namespace \
  --values my-values.yaml
```

From a working copy of this repository:

```sh
helm dependency update ./charts/public-bedatty-application
helm upgrade --install public-bedatty-application ./charts/public-bedatty-application \
  --namespace public-bedatty-application --create-namespace \
  --values ./charts/public-bedatty-application/values-template.yaml
```

`values-template.yaml` is the starting point for an environment: it carries only the keys an install actually has to decide.

## Database credentials

Passwords have **no defaults**. `boilerplate.secrets.POSTGRES_PASSWORD` and `global.externalPostgresDefinitions.boilerplateCredentials.password` are two sides of one credential — the second creates the role, the first is what the service logs in with — so setting only one creates the role with password A while the service starts with password B.

Point the bootstrap at an existing Secret and both read the same value:

```yaml
global:
  externalPostgresDefinitions:
    enabled: true
    boilerplateCredentials:
      useExistingSecret:
        name: my-db-credentials     # key: DB_PASSWORD_BOILERPLATE
```

The bootstrap Job only ever runs against an **external** database: it creates the database, the role and the grants. Leave it disabled when the role already exists.

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
`boilerplate.configmap.<KEY>` always overriding it, and this component's own
productized param (`boilerplate.<field>`) as the last fallback before the
hardcoded default — so an install that sets none of this renders unchanged.

```yaml
global:
  cloud: "aws"   # aws | gcp | azure — topology preset (TLS/SSL mode); leave unset for the bundled dev topology
  datastores:
    postgres: { host: "my-rds.example.com", user: "public-bedatty-application" }
    redis: { host: "my-elasticache.example.com", port: "6379" }
  observability: { enabled: true, otlpEndpoint: "otel-collector:4317" }
  auth: { host: "http://plugin-access-manager-auth:4000" }
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
  global mask — it stays productized under `boilerplate.otel.libraryName` /
  `.serviceName` (version tracks `boilerplate.image.tag`).
- **`objectStorage` is not applicable to this chart** — public-bedatty-application has
  no S3/object-storage surface (no template calls `lerian-common.objectStorage.value`).
  Do not add this block; there is nothing here to configure.

## Optional capabilities

Each is off by default, gated per-component; the connection/topology config
for the enabled ones comes from the matching `global.*` mask above:

```yaml
public-bedatty-application:
  multiTenant: {enabled: true}       # requires global.multiTenant.url and .redisHost (or configmap.MULTI_TENANT_*)
  streaming: {enabled: true}         # requires global.streaming.brokers
  serviceDiscovery: {enabled: true}
  otel: {enabled: true}              # also gates the OTLP podEnv (local-collector sidecar via HOST_IP); global.observability.enabled independently controls ENABLE_TELEMETRY/endpoint
```

`aws.rolesAnywhere` adds the IAM Roles Anywhere sidecar and the IMDS env for workloads outside EKS.

## Environment variables

Non-secret values live in the ConfigMap, credentials in the Secret. Any value can be overridden natively through `boilerplate.configmap.<ENV_VAR_NAME>`, which wins over the productized parameter.

## A typo in your values is not an error

`values.schema.json` validates the top level strictly, but `boilerplate` and
`global` both set `additionalProperties: true`, and `boilerplate` declares only
`configmap` and `secrets` of its own. Everything else you put under them is
accepted without being checked — including a key the chart does not read.

So `boilerplate.revisionHistoryLimits`, where the chart reads
`boilerplate.revisionHistoryLimit`, installs cleanly, reports success, and
leaves the Deployment on the default of 10. The same applies to a key this
chart used to have and no longer does: an upgrade keeps the stale entry in your
values and quietly falls back.

Nothing in `helm install` will tell you. Render the version you are actually
installing and read the field back:

```sh
helm template public-bedatty-application \
  oci://ghcr.io/lerianstudio/helm-boilerplates/public-bedatty-application-helm \
  --version 1.2.0 \
  --values my-values.yaml \
  | grep -E 'revisionHistoryLimit|replicas:'
```

`--version` matters: without it Helm pulls the newest chart in the registry,
which is not necessarily the one your release is on, and you would be reading
back the wrong template.

Note that `spec.replicas` is emitted **only** when
`boilerplate.autoscaling.enabled` is `false`. It defaults to `true`, so on a
default install the field is absent from the Deployment entirely and replica
count is the HPA's business — checking `replicas:` proves nothing unless you
turned autoscaling off.

Environments managed through the Lerian GitOps repository are covered: the
chart-update pipeline runs an orphan-key gate that fails the bump when an
environment sets a key the chart no longer declares. This section is for
installs outside it.

## Upgrades

Per-version notes are generated under `docs/` as releases ship.
