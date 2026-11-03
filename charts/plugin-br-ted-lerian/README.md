# plugin-br-ted-lerian (Helm chart)

## Chart Contract

- Chart type: `single-service`
- Required secrets: `plugin-br-ted-lerian.secrets.POSTGRES_PASSWORD` (no default). `CRM_CLIENT_ID` and `CRM_CLIENT_SECRET` (Access Manager M2M pair; the app refuses to boot single-tenant without them, ignored when multi-tenant). `plugin-br-ted-lerian.secrets.RECONCILIATION_QUEUE_CURSOR_KEY` (standard base64 of 32 random bytes, e.g. `openssl rand -base64 32`; the app refuses to boot without it in every mode). `REDIS_PASSWORD` only when Redis/Valkey auth is on, `MULTI_TENANT_SERVICE_API_KEY` and `MULTI_TENANT_REDIS_PASSWORD` only when `plugin-br-ted-lerian.multiTenant.enabled=true`. When the bootstrap Job runs, `global.externalPostgresDefinitions.postgresAdminLogin.password` and `.boilerplateCredentials.password` are required too — or point both at an existing Secret. `plugin-br-ted-lerian.secrets.LICENSE_KEY` is optional (empty by default, left out of the Secret when empty); set it for app versions that require a license at boot.
- Dependency notes: `lerian-common-helm` (library, no objects of its own) plus PostgreSQL and Valkey, both declared with exact pins, condition-gated and **disabled by default** — the target environments provide them externally. Archives are not vendored in git; `helm dependency update` resolves them from `Chart.lock`.
- Production overrides: image tag and pull secrets, ingress host/TLS, resources, autoscaling, `global.datastores` (or `plugin-br-ted-lerian.configmap.POSTGRES_HOST` / `REDIS_HOST`), and every credential above. Never ship a published default as a production secret.
- Source/license: chart source in [github.com/LerianStudio/helm](https://github.com/LerianStudio/helm) (Elastic License 2.0); application in `LerianStudio/plugin-br-ted-lerian`.

## Overview

Helm chart for `LerianStudio/plugin-br-ted-lerian`, the TED transfers plugin for Midaz.

| Resource | Notes |
|---|---|
| Deployment | `ghcr.io/lerianstudio/plugin-br-ted-lerian`, HTTP API `:8080` (liveness `/health`, readiness `/readyz`) |
| Service / Ingress | ClusterIP; Ingress on by default (`nginx`) |
| HPA / PDB | on by default (1-5 replicas, `maxUnavailable: 1`) |
| ConfigMap / Secret | env; no credential is ever rendered in the ConfigMap |
| Job `-bootstrap-postgres` | optional (`global.externalPostgresDefinitions.enabled`): creates database, role and grants on an external PostgreSQL |

## Install

From the OCI registry:

```sh
helm upgrade --install plugin-br-ted-lerian \
  oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm \
  --version <chart-version> \
  --namespace plugin-br-ted-lerian --create-namespace \
  --values my-values.yaml
```

From a working copy of this repository:

```sh
helm dependency update ./charts/plugin-br-ted-lerian
helm upgrade --install plugin-br-ted-lerian ./charts/plugin-br-ted-lerian \
  --namespace plugin-br-ted-lerian --create-namespace \
  --values ./charts/plugin-br-ted-lerian/values-template.yaml
```

`values-template.yaml` is the starting point for an environment. Its `configmap` keys (`ENV_NAME`, `POSTGRES_*`, `REDIS_HOST`, `PLUGIN_AUTH_*`, `OTEL_EXPORTER_OTLP_ENDPOINT`) win over `plugin-br-ted-lerian.env` and the matching `global.*` masks: set the values there or delete those keys. It does not carry the settings under [Required app settings](#required-app-settings): add them.

## Database credentials

Passwords have **no defaults**. `plugin-br-ted-lerian.secrets.POSTGRES_PASSWORD` and `global.externalPostgresDefinitions.boilerplateCredentials.password` are two sides of one credential — the second creates the role, the first is what the service logs in with — so setting only one creates the role with password A while the service starts with password B.

Set both to the same value. `boilerplateCredentials.useExistingSecret.name` (key `DB_PASSWORD_BOILERPLATE`) feeds only the bootstrap Job. The service reads `POSTGRES_PASSWORD` from this chart's Secret, or from `existingSecretName` when `plugin-br-ted-lerian.useExistingSecret: true`.

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

The bundled datastores run without TLS. The app refuses plaintext Postgres and Valkey in production and, in other environments, without `ALLOW_INSECURE_TLS`. With them, set `plugin-br-ted-lerian.env: development` and `plugin-br-ted-lerian.allowInsecureTls: "true"`.

When enabled, hosts resolve to the subchart Services and the passwords are read straight from the subchart's own Secret rather than copied into this chart's — a copy would go stale the moment the subchart rotated it.

## Global masks (`global.*`)

Every `global.*` mask below is env-wide: set it once per environment and every
component that consumes it inherits the value, with a native
`plugin-br-ted-lerian.configmap.<KEY>` overriding it (the `serviceDiscovery` and `streaming` masks ignore `configmap`), and this component's own
productized param (`plugin-br-ted-lerian.<field>`) as the last fallback before the
hardcoded default — so an install that sets none of this renders unchanged.

```yaml
global:
  cloud: "aws"   # aws | gcp | azure — Postgres SSL mode preset; leave unset for the bundled dev topology
  datastores:
    postgres: { host: "my-rds.example.com", user: "plugin-br-ted-lerian" }
    redis: { host: "my-elasticache.example.com:6379" }
  observability: { enabled: true, otlpEndpoint: "otel-collector:4317" }
  auth: { host: "http://plugin-access-manager-auth:4000" }
  multiTenant: { url: "http://tenant-manager:8080", redisHost: "my-elasticache.example.com" }
  serviceDiscovery: { address: "consul.internal:8500" }
  streaming: { brokers: "redpanda:9092" }
```

- `cloud` sets the Postgres SSL mode (`POSTGRES_SSLMODE`) for `global.datastores`; this chart renders no `REDIS_TLS` key;
  only the ENDPOINTS (host/port/user) come from `global.datastores` itself — a
  cloud preset can't know your RDS host.
- `datastores` only declares `postgres`/`redis` sub-keys — this chart has no
  Mongo or message-broker datastore, so `mongo`/`broker` sub-keys are not
  applicable here (don't set them, they're inert).
- `observability` covers enable/endpoint/deployment-environment only.
  Per-service OTEL identity (library name, service name, version) is NOT a
  global mask — it stays productized under `plugin-br-ted-lerian.otel.libraryName` /
  `.serviceName` (version tracks `plugin-br-ted-lerian.image.tag`).
- **`objectStorage` is not applicable to this chart** — plugin-br-ted-lerian has
  no S3/object-storage surface (no template calls `lerian-common.objectStorage.value`).

## Optional capabilities

Each is off by default, gated per-component; the connection/topology config
for the enabled ones comes from the matching `global.*` mask above:

```yaml
plugin-br-ted-lerian:
  multiTenant: {enabled: true}       # requires global.multiTenant.url and .redisHost (or configmap.MULTI_TENANT_*), global.auth.enabled: true and M2M_TARGET_SERVICE (extraEnvVars); production also requires global.multiTenant.redisTls: "true"
  streaming: {enabled: true, cloudeventsSource: "br-ted"}  # requires global.streaming.brokers and OUTBOX_ENABLED=true (extraEnvVars); production also requires SASL (global.streaming.saslMechanism, .saslUsername, .tlsEnabled: "true", and secrets.STREAMING_SASL_PASSWORD)
  serviceDiscovery: {enabled: true}
  otel: {enabled: true}              # also sets OTEL_EXPORTER_OTLP_ENDPOINT=$(HOST_IP):4317 (a collector on the node), which wins over any configured endpoint; global.observability.enabled independently controls ENABLE_TELEMETRY
```

`aws.rolesAnywhere` adds the IAM Roles Anywhere sidecar and the IMDS env for workloads outside EKS.

## Environment variables

Non-secret values live in the ConfigMap, credentials in the Secret. A key the ConfigMap already renders can be overridden through `plugin-br-ted-lerian.configmap.<ENV_VAR_NAME>`, which wins over the productized parameter. The ConfigMap drops any other `configmap` key: add new keys with `plugin-br-ted-lerian.extraEnvVars` or `plugin-br-ted-lerian.secrets.<KEY>`. `MULTI_TENANT_ENABLED`, `VERSION`, `OTEL_RESOURCE_SERVICE_VERSION` and every `SD_*` and `STREAMING_*` key ignore `configmap`.

### Required app settings

App `1.0.0-beta.64` refuses to boot without these, and the chart does not set them:

- `RAIL_ALLOWED_HOSTS`: the comma-separated `host[:port]` values of the rail this installation calls.
- `AUDIT_MONGO_URI` (single-tenant only). In production the URI must request TLS (`tls=true` or `mongodb+srv://`).
- With `plugin-br-ted-lerian.env: production` (the default): `global.auth.enabled: true`, `TRUSTED_PROXIES` (the IPs or CIDRs of the proxy in front of the service), `REDIS_TLS: "true"`, and a `POSTGRES_SSLMODE` of `require`, `verify-ca` or `verify-full` (`global.cloud` or `global.datastores.postgres.ssl`).
- Outside production, `POSTGRES_SSLMODE: disable` (the chart default and the `values-template.yaml` value) also needs `plugin-br-ted-lerian.allowInsecureTls: "true"`.

## Application Version Mapping

| Chart Version | App Version |
| :---: | :---: |
| `1.0.0` | `1.0.0-beta.33` |

## Upgrades

Per-version notes are generated under `docs/` as releases ship.
