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
| `manager.image.tag` | Manager image tag | `1.0.0-beta.1` |
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
| `worker.image.tag` | Worker image tag | `1.0.0-beta.1` |
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
| `secrets.MONGO_USER` | MongoDB username | `fetcher` |
| `secrets.MONGO_PASSWORD` | MongoDB password | `lerian` |
| `secrets.RABBITMQ_DEFAULT_USER` | RabbitMQ username | `plugin` |
| `secrets.RABBITMQ_DEFAULT_PASS` | RabbitMQ password | `Lerian@123` |
| `secrets.LICENSE_KEY` | License key | `""` |

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

common:
  configmap:
    MONGO_HOST: "my-mongodb.database.svc"
    RABBITMQ_HOST: "my-rabbitmq.messaging.svc"
    SEAWEEDFS_HOST: "my-seaweedfs.storage.svc"
    REDIS_HOST: "my-redis.cache.svc"

secrets:
  MONGO_USER: "myuser"
  MONGO_PASSWORD: "mypassword"
  RABBITMQ_DEFAULT_USER: "myuser"
  RABBITMQ_DEFAULT_PASS: "mypassword"
```

### Full Installation (With Dependencies)

```yaml
# values-full.yaml
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

## Troubleshooting

### Common Issues

1. **Manager pod not starting**: Check if MongoDB and RabbitMQ are accessible
2. **Worker not processing jobs**: Verify RabbitMQ connection and queue configuration
3. **File upload failures**: Ensure SeaweedFS is properly configured and accessible

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
