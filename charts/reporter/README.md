# Reporter Helm Chart

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
| `manager.image.tag` | Manager image tag | `1.0.0` |
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
| `worker.image.tag` | Worker image tag | `1.0.0` |
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
  MONGO_PASSWORD: lerian
  REDIS_PASSWORD: lerian
  RABBITMQ_DEFAULT_USER: plugin
  RABBITMQ_DEFAULT_PASS: Lerian@123
  DATASOURCE_ONBOARDING_PASSWORD: lerian
  # Add any custom datasource password:
  DATASOURCE_EXTERNAL_PASSWORD: db_password
```

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
    pluginPassword: "Lerian@123"
```

The bootstrap job:

1. Waits for the RabbitMQ instance to be reachable (AMQP port)
2. Applies the definitions file (exchanges, queues, bindings, and the `plugin` user)
3. Updates the `plugin` user password

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
