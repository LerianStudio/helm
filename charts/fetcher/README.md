# Fetcher Helm Chart

## Overview

Fetcher is a data extraction service for Lerian Studio that enables automated data collection from external sources. This plugin consists of two main components:

- **Manager**: REST API service that handles extraction job management and orchestration
- **Worker**: Background processor that executes data extraction tasks asynchronously

## Architecture

```
+----------------+      +----------------+      +----------------+
|                |      |                |      |                |
|  Manager API   +----->+    RabbitMQ    +----->+     Worker     |
|    (4006)      |      |                |      |                |
+-------+--------+      +----------------+      +-------+--------+
        |                                               |
        v                                               v
+-------+--------+                              +-------+--------+
|                |                              |                |
|    MongoDB     |                              |   SeaweedFS    |
|                |                              |                |
+----------------+                              +----------------+
        ^
        |
+-------+--------+
|                |
|  Valkey/Redis  |
|                |
+----------------+
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for MongoDB, SeaweedFS, and RabbitMQ persistence)
- Optional: KEDA 2.0+ for event-driven autoscaling

## Installing the Chart

### Install the chart

```bash
helm install fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version <version> -n midaz-plugins --create-namespace
```

To install the chart with a custom values file:

```bash
helm install fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version <version> -n midaz-plugins -f my-values.yaml
```

## Uninstalling the Chart

```bash
helm uninstall fetcher -n midaz-plugins
```

## Configuration

The following table lists the configurable parameters and their default values.

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full name | `""` |
| `namespaceOverride` | Override namespace | `""` |

### Manager Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `manager.name` | Manager component name | `fetcher-manager` |
| `manager.replicaCount` | Number of manager replicas | `1` |
| `manager.image.repository` | Manager image repository | `lerianstudio/fetcher-manager` |
| `manager.image.tag` | Manager image tag | `1.0.0` |
| `manager.image.pullPolicy` | Manager image pull policy | `IfNotPresent` |
| `manager.service.type` | Kubernetes Service type | `ClusterIP` |
| `manager.service.port` | Service HTTP port | `4006` |
| `manager.resources.requests.cpu` | CPU request | `100m` |
| `manager.resources.requests.memory` | Memory request | `256Mi` |
| `manager.resources.limits.cpu` | CPU limit | `200m` |
| `manager.resources.limits.memory` | Memory limit | `512Mi` |
| `manager.autoscaling.enabled` | Enable HPA | `false` |
| `manager.ingress.enabled` | Enable ingress | `false` |
| `manager.pdb.enabled` | Enable PodDisruptionBudget | `false` |

### Worker Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `worker.name` | Worker component name | `fetcher-worker` |
| `worker.replicaCount` | Number of worker replicas | `1` |
| `worker.image.repository` | Worker image repository | `lerianstudio/fetcher-worker` |
| `worker.image.tag` | Worker image tag | `1.0.0` |
| `worker.image.pullPolicy` | Worker image pull policy | `IfNotPresent` |
| `worker.resources.requests.cpu` | CPU request | `100m` |
| `worker.resources.requests.memory` | Memory request | `256Mi` |
| `worker.resources.limits.cpu` | CPU limit | `200m` |
| `worker.resources.limits.memory` | Memory limit | `512Mi` |

### Common Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `common.configmap.MONGO_HOST` | MongoDB host | `mongodb` |
| `common.configmap.MONGO_PORT` | MongoDB port | `27017` |
| `common.configmap.RABBITMQ_HOST` | RabbitMQ host | `rabbitmq` |
| `common.configmap.RABBITMQ_PORT_AMQP` | RabbitMQ AMQP port | `5672` |
| `common.configmap.SEAWEEDFS_HOST` | SeaweedFS host | `seaweedfs-filer` |
| `common.configmap.REDIS_HOST` | Redis/Valkey host | `valkey` |
| `common.configmap.REDIS_PORT` | Redis/Valkey port | `6379` |

### Secrets

| Parameter | Description | Default |
|-----------|-------------|---------|
| `manager.secrets.APP_ENC_KEY` | **REQUIRED** - Base64 encoded 32-byte encryption key | `""` |
| `worker.secrets.APP_ENC_KEY` | **REQUIRED** - Base64 encoded 32-byte encryption key | `""` |
| `secrets.MONGO_USER` | **REQUIRED** - MongoDB username | `fetcher` |
| `secrets.MONGO_PASSWORD` | **REQUIRED** - MongoDB password | `lerian` |
| `secrets.RABBITMQ_DEFAULT_USER` | **REQUIRED** - RabbitMQ username | `plugin` |
| `secrets.RABBITMQ_DEFAULT_PASS` | **REQUIRED** - RabbitMQ password | `Lerian@123` |
| `secrets.LICENSE_KEY` | **REQUIRED** - Lerian license key | `""` |

### External RabbitMQ Bootstrap

When using an external RabbitMQ instance, you can enable the bootstrap job to automatically apply the required queue, exchange, and binding definitions.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalRabbitmqDefinitions.enabled` | Enable RabbitMQ bootstrap job | `false` |
| `externalRabbitmqDefinitions.connection.protocol` | API protocol (http/https) | `http` |
| `externalRabbitmqDefinitions.connection.host` | RabbitMQ management API host | `""` |
| `externalRabbitmqDefinitions.connection.port` | Management API port | `15672` |
| `externalRabbitmqDefinitions.connection.portAmqp` | AMQP port for health check | `5672` |
| `externalRabbitmqDefinitions.rabbitmqAdminLogin.username` | Admin username | `""` |
| `externalRabbitmqDefinitions.rabbitmqAdminLogin.password` | Admin password | `""` |
| `externalRabbitmqDefinitions.rabbitmqAdminLogin.useExistingSecret.name` | Use existing secret for admin credentials | `""` |
| `externalRabbitmqDefinitions.appCredentials.pluginPassword` | Password for plugin user | `""` |
| `externalRabbitmqDefinitions.appCredentials.useExistingSecret.name` | Use existing secret for plugin password | `""` |

### Optional Dependencies

The chart includes optional dependencies that can be enabled for local development or testing:

| Dependency | Parameter | Description |
|------------|-----------|-------------|
| SeaweedFS | `seaweedfs.enabled` | Distributed file system for storing files |
| MongoDB | `mongodb.enabled` | Document database for metadata |
| RabbitMQ | `rabbitmq.enabled` | Message broker for async processing |
| Valkey | `valkey.enabled` | In-memory data store (Redis alternative) |
| KEDA | `keda.enabled` | Event-driven autoscaling |

## Examples

### Minimal Installation (External Dependencies)

```yaml
# values-minimal.yaml
manager:
  image:
    tag: "1.0.0"
  secrets:
    APP_ENC_KEY: "<your-base64-32byte-key>"  # Generate with: openssl rand -base64 32
  ingress:
    enabled: true
    hosts:
      - host: fetcher.example.com
        paths:
          - path: /
            pathType: Prefix

worker:
  image:
    tag: "1.0.0"
  secrets:
    APP_ENC_KEY: "<your-base64-32byte-key>"  # Same key as manager

common:
  configmap:
    MONGO_HOST: "my-mongodb.database.svc"
    RABBITMQ_HOST: "my-rabbitmq.messaging.svc"
    RABBITMQ_HEALTH_CHECK_URL: "http://my-rabbitmq.messaging.svc:15672"
    SEAWEEDFS_HOST: "my-seaweedfs.storage.svc"
    REDIS_HOST: "my-redis.cache.svc"

secrets:
  MONGO_USER: "myuser"
  MONGO_PASSWORD: "mypassword"
  RABBITMQ_DEFAULT_USER: "plugin"
  RABBITMQ_DEFAULT_PASS: "mypassword"
  LICENSE_KEY: "<your-license-key>"
```

### Full Installation (With Dependencies)

```yaml
# values-full.yaml
# When using embedded dependencies, service names include the release name prefix
# Assuming release name is "fetcher":
common:
  configmap:
    MONGO_HOST: "fetcher-mongodb"
    RABBITMQ_HOST: "fetcher-rabbitmq"
    RABBITMQ_HEALTH_CHECK_URL: "http://fetcher-rabbitmq:15672"
    REDIS_HOST: "fetcher-valkey"
    SEAWEEDFS_HOST: "seaweedfs-filer"

manager:
  secrets:
    APP_ENC_KEY: "<your-base64-32byte-key>"  # Generate with: openssl rand -base64 32

worker:
  secrets:
    APP_ENC_KEY: "<your-base64-32byte-key>"  # Same key as manager

mongodb:
  enabled: true
  auth:
    rootUser: fetcher
    rootPassword: securepassword

rabbitmq:
  enabled: true

seaweedfs:
  enabled: true

valkey:
  enabled: true

keda:
  enabled: true
```

### External RabbitMQ with Bootstrap

Use this approach when connecting to an external RabbitMQ instance that doesn't have fetcher definitions pre-configured.

**Important:** The bootstrap job only runs when `rabbitmq.enabled=false` (external RabbitMQ). When using the embedded RabbitMQ subchart (`rabbitmq.enabled=true`), definitions are automatically loaded via `customConfig`.

```yaml
# values-external-rabbitmq.yaml
manager:
  image:
    tag: "1.0.0"

worker:
  image:
    tag: "1.0.0"

common:
  configmap:
    RABBITMQ_HOST: "my-rabbitmq.messaging.svc"

secrets:
  RABBITMQ_DEFAULT_USER: "plugin"
  RABBITMQ_DEFAULT_PASS: "securepassword"

# Disable embedded RabbitMQ
rabbitmq:
  enabled: false

# Enable bootstrap job to apply RabbitMQ definitions
externalRabbitmqDefinitions:
  enabled: true
  connection:
    protocol: "http"
    host: "my-rabbitmq.messaging.svc"
    port: "15672"       # Management API port
    portAmqp: "5672"    # AMQP port (for health check)
  rabbitmqAdminLogin:
    username: "admin"           # Existing admin user
    password: "adminpassword"   # Admin password
  appCredentials:
    pluginPassword: "securepassword"  # Password for 'plugin' user (will be created)
```

The bootstrap job will:
1. Wait for RabbitMQ to be ready
2. Check if definitions already exist (idempotent)
3. Apply queues, exchanges, and bindings from `load_definitions.json`
4. Create/update the `plugin` user with the specified password

## Important Notes

### Service Names with Embedded Dependencies

When enabling the bundled dependencies (mongodb, rabbitmq, valkey), the service names include the Helm release name as prefix. Update the `common.configmap` values accordingly:

```yaml
# If your release name is "fetcher":
common:
  configmap:
    MONGO_HOST: "fetcher-mongodb"        # Not just "mongodb"
    RABBITMQ_HOST: "fetcher-rabbitmq"    # Not just "rabbitmq"
    REDIS_HOST: "fetcher-valkey"         # Not just "valkey"
    SEAWEEDFS_HOST: "seaweedfs-filer"    # SeaweedFS doesn't use release prefix
```

### Encryption Key

The `APP_ENC_KEY` must be a valid base64-encoded 32-byte key. Generate one using:

```bash
openssl rand -base64 32
```

### SeaweedFS Configuration

SeaweedFS is a distributed file system used for storing extracted files. When enabling SeaweedFS:

**Prerequisites:**
- Kubernetes cluster with dynamic PV provisioning (StorageClass) OR pre-created PersistentVolumes
- At least 40Gi of storage available (5Gi master + 10Gi volume + 25Gi filer)

**Architecture Support:**
The default SeaweedFS chart uses `kubernetes.io/arch=amd64` node selector. For ARM64 clusters (e.g., Apple Silicon Macs, AWS Graviton), the fetcher chart overrides this with empty `nodeSelector: {}`.

**Storage Requirements:**
| Component | Default Size | Purpose |
|-----------|-------------|---------|
| Master | 5Gi | Cluster metadata |
| Volume | 10Gi | Blob storage |
| Filer | 25Gi | File system layer |

**Custom Storage Class:**
```yaml
seaweedfs:
  enabled: true
  master:
    data:
      storageClass: "my-storage-class"
  volume:
    dataDirs:
      - name: data
        storageClass: "my-storage-class"
  filer:
    data:
      storageClass: "my-storage-class"
```

**Verify SeaweedFS is Running:**
```bash
# Check all pods are ready
kubectl get pods -l app.kubernetes.io/name=seaweedfs

# Test filer connectivity
kubectl port-forward svc/seaweedfs-filer 8888:8888
curl http://localhost:8888/
```

## Troubleshooting

### Common Issues

1. **Manager pod not starting**: Check if MongoDB and RabbitMQ are accessible
2. **Worker not processing jobs**: Verify RabbitMQ connection and queue configuration
3. **File upload failures**: Ensure SeaweedFS is properly configured and accessible
4. **Invalid encryption key error**: The `APP_ENC_KEY` must be a valid base64-encoded 32-byte key
5. **MongoDB/RabbitMQ host not found**: When using embedded dependencies, service names include the release prefix (e.g., `fetcher-mongodb` instead of `mongodb`)
6. **SeaweedFS pods pending**: Check if PVCs can be bound (requires StorageClass or pre-created PVs)
7. **SeaweedFS pods not scheduling on ARM64**: Ensure `nodeSelector: {}` is set in the SeaweedFS configuration

### Useful Commands

```bash
# Check pod status
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=fetcher-manager

# View manager logs
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=fetcher-manager

# View worker logs
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=fetcher-worker
```

## License

Apache 2.0 - See [LICENSE](https://github.com/LerianStudio/fetcher/blob/main/LICENSE) for details.
