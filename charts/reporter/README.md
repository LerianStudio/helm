# Plugin Smart Templates Helm Chart

## Overview

The Smart Templates plugin provides a flexible document templating system that enables dynamic report generation based on predefined templates. This plugin consists of two main components:

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
- KEDA 2.0+ installed in the cluster
- PV provisioner support in the underlying infrastructure (for MongoDB, SeaweedFS, and RabbitMQ persistence)

## Installing the Chart

### Install the charts

```bash
helm install reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version <> -n midaz-plugins --create-namespace
```

To install the chart with a custom values file:

```bash
helm install reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version <> -n midaz-plugins -f my-values.yaml
```

## Uninstalling the Chart

```bash
helm uninstall reporter -n midaz-plugins
```

## Configuration

The following table lists the configurable parameters and their default values.

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Global Docker image registry | `""` |
| `global.imagePullSecrets` | Global Docker registry secret names | `[]` |

### Common Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `common.configmap` | Common environment variables for all components | See `values.yaml` |
| `secrets` | Shared secrets for all components | See `values.yaml` |

### Manager Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `manager.replicaCount` | Number of manager replicas | `1` |
| `manager.image.repository` | Manager image repository | `ghcr.io/lerianstudio/reporter/manager` |
| `manager.image.tag` | Manager image tag | `latest` |
| `manager.image.pullPolicy` | Manager image pull policy | `Always` |
| `manager.service.type` | Kubernetes Service type | `ClusterIP` |
| `manager.service.port` | Service HTTP port | `80` |
| `manager.resources` | CPU/Memory resource requests/limits | See `values.yaml` |
| `manager.keda.scaledObject` | KEDA ScaledObject configuration | See `values.yaml` |
| `manager.useExistingSecrets` | Use an existing secret instead of creating a new one | `false` |
| `manager.existingSecretName` | The name of the existing secret to use | `""` |

### Worker Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `worker.image.repository` | Worker image repository | `ghcr.io/lerianstudio/reporter/worker` |
| `worker.image.tag` | Worker image tag | `latest` |
| `worker.image.pullPolicy` | Worker image pull policy | `Always` |
| `worker.resources` | CPU/Memory resource requests/limits | See `values.yaml` |
| `worker.keda.scaledJob` | KEDA ScaledJob configuration | See `values.yaml` |

### Frontend Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `frontend.enabled` | Enable or disable the frontend service | `true` |
| `frontend.replicaCount` | Number of replicas for the deployment | `1` |
| `frontend.image.repository` | Repository for the frontend service container image | `ghcr.io/lerianstudio/reporter-frontend` |
| `frontend.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `frontend.image.tag` | Image tag used for deployment | `2.0.0-beta.3` |
| `frontend.imagePullSecrets` | Secrets for pulling images from a private registry | `[]` |
| `frontend.podAnnotations` | Annotations to be added to the Pod | `{}` |
| `frontend.securityContext` | Defines security settings for the container | See `values.yaml` |
| `frontend.pdb` | PodDisruptionBudget configuration | See `values.yaml` |
| `frontend.deploymentUpdate` | Deployment update strategy | See `values.yaml` |
| `frontend.service.type` | Kubernetes service type | `ClusterIP` |
| `frontend.service.port` | Service port | `8083` |
| `frontend.ingress.enabled` | Enable or disable ingress | `false` |
| `frontend.resources` | CPU and memory limits for pods | See `values.yaml` |
| `frontend.autoscaling.enabled` | Enable or disable horizontal pod autoscaling | `false` |
| `frontend.nodeSelector` | Node selector for scheduling pods on specific nodes | `{}` |
| `frontend.tolerations` | Tolerations for scheduling on tainted nodes | `{}` |
| `frontend.configmap` | ConfigMap for environment variables | `{}` |
| `frontend.extraEnvVars` | Extra environment variables to be added to the deployment | `{}` |
| `frontend.secrets` | Secrets for storing sensitive data | `{}` |
| `frontend.serviceAccount.create` | Specifies whether a ServiceAccount should be created | `true` |
| `frontend.serviceAccount.name` | Name of the service account | `""` |

### Dependency Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mongodb` | MongoDB configuration | See `values.yaml` |
| `rabbitmq` | RabbitMQ configuration | See `values.yaml` |
| `seaweedfs` | SeaweedFS configuration | See `values.yaml` |
| `redis` | Redis configuration | See `values.yaml` |

## KEDA Integration

This chart utilizes KEDA (Kubernetes Event-driven Autoscaling) for scaling the worker component based on RabbitMQ queue length. The KEDA resources are created after the main application components using Helm hooks to ensure proper dependency management.

The following KEDA resources are created:

- **ScaledObject**: For scaling the manager deployment based on metrics
- **ScaledJob**: For scaling worker jobs based on RabbitMQ queue length
- **TriggerAuthentication**: Shared authentication for RabbitMQ access

## Accessing the API

After deploying the chart, you can access the manager API using the following endpoint (within the cluster):

```
http://reporter-manager.reporter.svc.cluster.local:80
```

For external access, you can use port-forwarding:

```bash
kubectl port-forward svc/reporter-manager 8080:80 -n midaz-plugins
```

Then access: http://localhost:8080

## API Documentation

The API documentation is available at the `/swagger/index.html` endpoint.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
