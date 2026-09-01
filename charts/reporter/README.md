# Reporter Helm Chart

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `secrets.RABBITMQ_DEFAULT_PASS`, `secrets.RABBITMQ_ERLANG_COOKIE` (required when the bundled RabbitMQ subchart is enabled — must be stable across upgrades), and `secrets.DATASOURCE_ONBOARDING_PASSWORD`. The MongoDB password is **not** operator-provided with the bundled subchart: it is auto-generated into the `<release>-mongodb` Secret (key `mongodb-root-password`) and read via `secretKeyRef`.
- Required from app 3.0.0 on: `secrets.DATASOURCE_CRED_ENC_KEY` — a hex-encoded AES key (16/24/32 bytes; `openssl rand -hex 32`) that both components use to encrypt registered data-source credentials at rest. It must be **identical** on the manager and the worker, and it **cannot be rotated** in that release. The render fails when either component's `image.tag` is `>= 3.0.0` and the key is empty; app 2.4.x (the chart's default appVersion) ignores it. See `docs/UPGRADE-4.1.md`.
- Single-source infra secrets: MongoDB follows Pattern A (app reads the subchart Secret). RabbitMQ follows Pattern B (the groundhog2k broker is pointed at the application `reporter-manager` Secret via `rabbitmq.authentication.existingSecret`, so the broker password lives only in `secrets.RABBITMQ_DEFAULT_PASS`; this also removes the prior `midaz`-vs-`plugin` user mismatch). Valkey: the valkey.io subchart exposes no Secret-based password mechanism (auth is an inline ACL) and ships with `auth.enabled: false`, so there is no single-source wiring for it here. See `docs/helm-chart-standard.md` "Single-Source Infra Secrets".
- Release name: the hardcoded infra hosts and the `<release>-mongodb` / `reporter-manager` Secret references assume the release is installed as `reporter`. If you override `manager.name`/`manager.existingSecretName`, set `rabbitmq.authentication.existingSecret` to match.
- Dependency notes: Uses local MongoDB and RabbitMQ dependency charts unless external services are configured.
- Production overrides: Provide reporting database and messaging credentials through chart secrets or existing Secrets where supported; override manager/worker image tags, ingress, resources, KEDA settings, and persistence.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

## Overview

The Reporter plugin provides a flexible document templating system that enables dynamic report generation based on predefined templates. This plugin consists of two main components:

- **Manager**: API service that handles template management and orchestrates report generation
- **Worker**: Background processor that handles asynchronous report generation tasks

## Architecture

```
+----------------+      +----------------+      +----------------+
|                |      |                |      |                |
|  Manager API   +----->+    RabbitMQ    +----->+     Worker     |
|                |      |                |      |                |
+-------+--------+      +----------------+      +-------+--------+
        |                                               |
        v                                               v
+-------+--------+                              +-------+--------+
|                |                              |                |
|    MongoDB     |                              |    SeaweedFS   |
|                |                              |                |
+----------------+                              +----------------+
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- KEDA 2.0+ (can be installed by the chart or externally)
- PV provisioner support in the underlying infrastructure (for MongoDB, SeaweedFS, and RabbitMQ persistence)

## Installing the Chart

```bash
helm install reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version <version> -n reporter --create-namespace
```

To install with a custom values file:

```bash
helm install reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version <version> -n reporter -f my-values.yaml
```

## Uninstalling the Chart

```bash
helm uninstall reporter -n reporter
```

## Configuration

The following table lists the configurable parameters and their default values.

### Managed Cloud (`global.cloud`)

Point this chart at a managed-cloud environment (AWS/GCP/Azure) instead of the
bundled in-cluster MongoDB/Redis/RabbitMQ/SeaweedFS with one knob:

```yaml
global:
  cloud: "aws"   # aws | gcp | azure — leave unset for the bundled dev topology
  datastores:
    mongo: { host: "my-documentdb.example.com", port: "27017", user: "reporter" }
    redis: { host: "my-elasticache.example.com:6379" }
    broker: { host: "my-amazonmq.example.com" }
  objectStorage:
    s3: { endpoint: "https://s3.us-east-1.amazonaws.com", region: "us-east-1", bucket: "my-bucket" }
  observability:
    enabled: true
  auth:
    host: "http://plugin-access-manager-auth:4000"
```

`global.cloud` sets the connection TOPOLOGY (TLS, AMQP scheme/ports, S3
path-style) for the masks above; only the ENDPOINTS (host/port/user) still
come from `global.datastores`/`global.objectStorage` — a cloud preset can't
know your RDS host. A native `common.configmap.<KEY>` always overrides any
mask.

Copy `values-template.yaml` as your starting point — it documents every
`global.*` mask with a working example. `values.yaml` is the full
power-user reference; `values.schema.json` validates it.

### Notable Default Changes (lerian-common adoption + OTEL/TLS fix)

This chart version adopts `lerian-common` typed masks and, alongside the stated
OTEL/TLS fix, ships a few deliberate operational default changes. Each is
render-equivalent for the bundled dev topology (no override needed) unless noted:

| Key | Old default | New default | Rationale |
|-----|--------------|-------------|-----------|
| `common.configmap.ALLOW_INSECURE_TLS` | `"false"` | **`"true"`** (security-relevant) | The bundled mongo/redis/rabbitmq/postgres subcharts run without TLS; the app *requires* this flag to bypass (mongo hard-fails with "TLS required" otherwise), so a zero-override `helm install` previously crashed. Same convention as `plugin-access-manager`. Flip to `"false"` explicitly for any managed-cloud/TLS-terminated topology (`global.cloud` presets do this for you). |
| `common.configmap.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `"production"` | derived from `ENV_NAME` (default `"development"`) | Single-sources the OTEL deployment-environment with `ENV_NAME` instead of two independent hardcoded literals, so a zero-override install no longer contradicts itself (`ENV_NAME=development` but `deployment_environment=production`), which previously tripped the app's own production safety check against the non-TLS bundled OTel endpoint. |
| `manager.configmap.LOG_LEVEL` / `worker.configmap.LOG_LEVEL` | `debug` | `info` | Reduce default log noise; override to `debug` for local troubleshooting. |
| `worker.configmap.PDF_POOL_WORKERS` | `"5"` | `"3"` | Aligns the worker's default pool size with the manager's existing default (`3`), which was already `3` pre-PR. |
| `worker.configmap.PDF_TIMEOUT_SECONDS` | `"30"` | `"90"` | Gives PDF generation enough headroom for larger reports before timing out. |
| `common.configmap.MONGO_PARAMETERS` | `""` | `"maxIdleTimeMS=60000"` | Bounds idle MongoDB connections instead of holding them open indefinitely; a sensible production-safe default, not required by the OTEL/TLS fix but bundled here as part of the same "sensible chart defaults" pass. Override with `common.configmap.MONGO_PARAMETERS: ""` to restore the old (unbounded) behavior. |
| `seaweedfs.global.serviceAccountName` | *(unset — subchart default `"seaweedfs"`)* | `"reporter-seaweedfs"` | **Upgrade note:** paired with `seaweedfs.global.createClusterRole: false` (also new) to avoid a fixed-name cluster-scoped `ClusterRole`/`ClusterRoleBinding` collision when more than one release runs on the same cluster. Because `createClusterRole` defaults to `false`, the ClusterRole itself is not created either way — but this **does rename the SeaweedFS `ServiceAccount`** object referenced by the master/volume/filer StatefulSets on any existing install that had `seaweedfs.enabled: true` before this change (old name `seaweedfs` → new name `reporter-seaweedfs`). Expect a one-time rolling restart of the SeaweedFS pods on upgrade; if you have IRSA/IAM-role annotations or RoleBindings pinned to the old ServiceAccount name, update them to `reporter-seaweedfs` before upgrading. |

`MONGO_MAX_POOL_SIZE` (`100`) and `MONGO_HOST`/`RABBITMQ_HOST`/`RABBITMQ_HEALTH_CHECK_URL`/`REDIS_HOST`/`OBJECT_STORAGE_ENDPOINT`
(FQDN `<svc>.reporter.svc.cluster.local` form, restored in this PR after an
unintentional short-name drift was caught in review) are unchanged from the
pre-adoption defaults — kept byte-identical for existing installs.

### Common Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `common.configmap` | Common environment variables shared by manager and worker | See `values.yaml` |
| `secrets` | Shared secrets for all components (dynamic - any key added here is rendered into the Secret) | See `values.yaml` |

### Manager Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `manager.replicaCount` | Number of manager replicas | `1` |
| `manager.image.repository` | Manager image repository | `ghcr.io/lerianstudio/reporter-manager` |
| `manager.image.tag` | Manager image tag | `1.2.0` |
| `manager.image.pullPolicy` | Manager image pull policy | `IfNotPresent` |
| `manager.service.type` | Kubernetes Service type | `ClusterIP` |
| `manager.service.port` | Service HTTP port | `4005` |
| `manager.resources` | CPU/Memory resource requests/limits | See `values.yaml` |
| `manager.useExistingSecret` | Use an existing secret instead of creating a new one | `false` |
| `manager.existingSecretName` | Name of the existing secret to use | `""` |
| `manager.clusterRole.create` | Enable or disable ClusterRole and ClusterRoleBinding creation | `true` |
| `manager.keda.scaledObject` | KEDA ScaledObject configuration | See `values.yaml` |

### Worker Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `worker.image.repository` | Worker image repository | `ghcr.io/lerianstudio/reporter-worker` |
| `worker.image.tag` | Worker image tag | `1.2.0` |
| `worker.image.pullPolicy` | Worker image pull policy | `IfNotPresent` |
| `worker.resources` | CPU/Memory resource requests/limits | See `values.yaml` |
| `worker.useExistingSecret` | Use an existing secret instead of creating a new one | `false` |
| `worker.existingSecretName` | Name of the existing secret to use | `""` |
| `worker.keda.scaledJob` | KEDA ScaledJob configuration | See `values.yaml` |

### Dependency Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mongodb.enabled` | Enable or disable MongoDB deployment | `true` |
| `rabbitmq.enabled` | Enable or disable RabbitMQ deployment | `true` |
| `seaweedfs.enabled` | Enable or disable SeaweedFS deployment | `true` |
| `valkey.enabled` | Enable or disable Valkey (Redis) deployment | `true` |
| `keda.enabled` | Enable or disable KEDA operator deployment | `true` |
| `keda.external` | Use an externally installed KEDA operator | `false` |

## Secrets Management

### Dynamic Secrets

The `secrets` section in `values.yaml` is fully dynamic. Any key/value pair added under `secrets:` is automatically rendered into the Kubernetes Secret for both manager and worker:

```yaml
secrets:
  RABBITMQ_DEFAULT_USER: reporter
  RABBITMQ_DEFAULT_PASS: Lerian@123
  # Stable Erlang cookie for the bundled RabbitMQ (required when rabbitmq.enabled).
  # Generate once with: openssl rand -hex 32
  RABBITMQ_ERLANG_COOKIE: <stable-cookie>
  DATASOURCE_ONBOARDING_PASSWORD: lerian
  # MONGO_PASSWORD is single-sourced from the bundled mongodb subchart Secret and read
  # via secretKeyRef — leave it unset; only set it for an EXTERNAL MongoDB.
  # REDIS_PASSWORD is omitted because the bundled valkey runs with auth disabled.
  # At-rest encryption of registered data-source credentials. Required by app >= 3.0.0
  # (both components); same value on manager and worker; NOT rotatable.
  # Generate with: openssl rand -hex 32
  DATASOURCE_CRED_ENC_KEY: <64-hex-chars>
  # Add any custom datasource password:
  DATASOURCE_EXTERNAL_PASSWORD: db_password
```

> `DATASOURCE_CRED_ENC_KEY` belongs under `secrets:`, never under `common.configmap:` — the
> configmap escape hatch accepts any `DATASOURCE_*` key, so a misplaced one lands in a
> plaintext ConfigMap without any warning.

### Using Existing Secrets

For production environments, you can use pre-existing Kubernetes Secrets instead of having the chart create them. When enabled, the chart skips Secret creation and references the provided secret name in the deployments.

```yaml
manager:
  useExistingSecret: true
  existingSecretName: "my-manager-secret"

worker:
  useExistingSecret: true
  existingSecretName: "my-worker-secret"
```

When using existing secrets, ensure they contain all required keys (including any custom datasource passwords). The deployments inject secrets via `envFrom`/`secretRef`, so all keys from the external secret are loaded as environment variables.

The KEDA TriggerAuthentication also respects this setting and will automatically reference the existing secret for RabbitMQ credentials.

## External Datasources

The Reporter supports connecting to additional external databases beyond the built-in Midaz onboarding datasource. You can register multiple datasources by following the naming convention `DATASOURCE_<NAME>_*`.

### Naming Convention

All variables follow the pattern `DATASOURCE_<NAME>_<PROPERTY>`, where `<NAME>` is a unique identifier you choose for the datasource (e.g., `EXTERNAL`, `SALES`, `ANALYTICS`).

### Schema Validation

`DATASOURCE_*` is a **declared open namespace**: the operator names each datasource at
deploy time, so a closed allowlist could only ever list example names. The strict
`values.schema.json` therefore accepts any well-formed `DATASOURCE_<NAME>_<PROPERTY>` key
under `common.configmap` — you can register datasources without ever touching the schema —
while a typo *outside* the namespace (e.g. `REDIS_HOSTX`) is still rejected at
`helm install`. The guard is `propertyNames: anyOf: [enum, pattern ^DATASOURCE_...]`,
generated with `gen-schema.py --open-prefixes DATASOURCE_` (see `config/schema-keys.txt`).
It is a *named* open family, never a fully-open ConfigMap.

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATASOURCE_<NAME>_CONFIG_NAME` | Logical name used to reference this datasource in report templates | `external_db` |
| `DATASOURCE_<NAME>_HOST` | Database hostname or IP address | `external-postgres.example.com` |
| `DATASOURCE_<NAME>_PORT` | Database port | `5432` |
| `DATASOURCE_<NAME>_USER` | Database username | `db_user` |
| `DATASOURCE_<NAME>_PASSWORD` | Database password (must be defined under `secrets`) | `db_password` |
| `DATASOURCE_<NAME>_DATABASE` | Database name | `external_database` |
| `DATASOURCE_<NAME>_TYPE` | Database type | `postgresql` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATASOURCE_<NAME>_SSLMODE` | SSL connection mode | `disable` |
| `DATASOURCE_<NAME>_SSLROOTCERT` | Path to SSL root certificate | `""` |
| `DATASOURCE_<NAME>_DB_SCHEMAS` | Comma-separated list of schemas to query | `public` |

### Configuration

Connection details go under `common.configmap` and passwords go under `secrets`:

```yaml
common:
  configmap:
    DATASOURCE_EXTERNAL_CONFIG_NAME: external_db
    DATASOURCE_EXTERNAL_HOST: external-postgres.example.com
    DATASOURCE_EXTERNAL_PORT: "5432"
    DATASOURCE_EXTERNAL_USER: db_user
    DATASOURCE_EXTERNAL_DATABASE: external_database
    DATASOURCE_EXTERNAL_TYPE: postgresql
    DATASOURCE_EXTERNAL_SSLMODE: disable
    DATASOURCE_EXTERNAL_DB_SCHEMAS: sales,inventory,reporting

secrets:
  DATASOURCE_EXTERNAL_PASSWORD: db_password
```

### Multiple Datasources

You can register as many datasources as needed. Each one must have a unique `<NAME>`:

```yaml
common:
  configmap:
    # First datasource
    DATASOURCE_SALES_CONFIG_NAME: sales_db
    DATASOURCE_SALES_HOST: sales-postgres.example.com
    DATASOURCE_SALES_PORT: "5432"
    DATASOURCE_SALES_USER: sales_user
    DATASOURCE_SALES_DATABASE: sales
    DATASOURCE_SALES_TYPE: postgresql
    DATASOURCE_SALES_SSLMODE: require

    # Second datasource
    DATASOURCE_ANALYTICS_CONFIG_NAME: analytics_db
    DATASOURCE_ANALYTICS_HOST: analytics-postgres.example.com
    DATASOURCE_ANALYTICS_PORT: "5432"
    DATASOURCE_ANALYTICS_USER: analytics_user
    DATASOURCE_ANALYTICS_DATABASE: analytics
    DATASOURCE_ANALYTICS_TYPE: postgresql
    DATASOURCE_ANALYTICS_SSLMODE: require
    DATASOURCE_ANALYTICS_DB_SCHEMAS: reports,aggregations

secrets:
  DATASOURCE_SALES_PASSWORD: sales_password
  DATASOURCE_ANALYTICS_PASSWORD: analytics_password
```

### Using in Report Templates

Reference datasources by their `CONFIG_NAME` value. When querying specific schemas, use the syntax `<config_name>:<schema>.<table>`:

```
# Default schema (public)
external_db:orders

# Explicit schema
external_db:sales.orders
external_db:inventory.products

# Different datasources
sales_db:invoices
analytics_db:reports.monthly_summary
```

### Using Existing Secrets

When `useExistingSecret` is enabled for manager/worker, datasource passwords must be included in the external secret alongside all other required keys. The chart does not create any Secret resources in this mode.

## External RabbitMQ Bootstrap

When using an external RabbitMQ instance (not deployed by this chart), you can enable the bootstrap job to automatically apply the required definitions (exchanges, queues, bindings, and users).

```yaml
externalRabbitmqDefinitions:
  enabled: true
  connection:
    protocol: "http"
    host: "my-rabbitmq.example.com"
    port: "15672"
    portAmqp: "5672"
  rabbitmqAdminLogin:
    username: "admin"
    password: "admin-password"
  appCredentials:
    reporterPassword: "Lerian@123"
```

The bootstrap job:

1. Waits for the RabbitMQ instance to be reachable (AMQP port)
2. Applies the definitions file (exchanges, queues, bindings, and the `reporter` user)
3. Updates the `reporter` user password

### Using Existing Secrets for Bootstrap Credentials

```yaml
externalRabbitmqDefinitions:
  enabled: true
  connection:
    protocol: "https"
    host: "my-rabbitmq.example.com"
    port: "443"
    portAmqp: "5672"
  rabbitmqAdminLogin:
    useExistingSecret:
      name: "my-rabbitmq-admin-secret"  # must contain RABBITMQ_ADMIN_USER and RABBITMQ_ADMIN_PASS keys
  appCredentials:
    useExistingSecret:
      name: "my-rabbitmq-app-secret"    # must contain RABBITMQ_DEFAULT_PASS key
```

## KEDA Integration

This chart utilizes KEDA (Kubernetes Event-driven Autoscaling) for scaling components based on metrics and RabbitMQ queue length.

The following KEDA resources are created:

- **ScaledObject**: For scaling the manager deployment based on CPU/memory metrics
- **ScaledJob**: For scaling worker jobs based on RabbitMQ queue length
- **TriggerAuthentication**: Shared authentication for RabbitMQ access

### Using an External KEDA Operator

If KEDA is already installed in your cluster, disable the bundled operator and set `external: true`:

```yaml
keda:
  enabled: false
  external: true
```

The chart will still create ScaledJob and TriggerAuthentication resources but will not install the KEDA operator itself.

## ClusterRole

The chart creates a ClusterRole and ClusterRoleBinding for the manager to access CRDs and deployments. If these resources already exist in the cluster (e.g., from a previous installation), you can disable their creation:

```yaml
manager:
  clusterRole:
    create: false
```

## Accessing the API

After deploying the chart, you can access the manager API within the cluster:

```
http://reporter-manager.reporter.svc.cluster.local:4005
```

For external access via port-forwarding:

```bash
kubectl port-forward svc/reporter-manager 4005:4005 -n reporter
```

Then access: http://localhost:4005

## API Documentation

The API documentation is available at the `/swagger/index.html` endpoint.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
