# Flowker Helm Chart

A Helm chart for deploying Flowker - Workflow orchestration platform for financial validation.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- MongoDB database (bundled or external)

## Installation

```bash
helm install flowker ./charts/flowker -n flowker --create-namespace
```

## Configuration

### Namespace Override

By default, resources are deployed to the `flowker` namespace. Override with:

```bash
helm install flowker ./charts/flowker --set namespaceOverride=custom-namespace -n custom-namespace
```

### MongoDB

The chart includes a MongoDB subchart (Bitnami) enabled by default. To use an external MongoDB instance, disable the bundled one:

```yaml
mongodb:
  enabled: false

flowker:
  configmap:
    MONGO_URI: "mongodb://user:password@your-mongo-host:27017/flowker?authSource=admin"
```

### Existing Secrets

To use an existing Kubernetes secret instead of the chart-managed one:

```yaml
flowker:
  useExistingSecret: true
  existingSecretName: "my-flowker-secret"
```

The secret must contain the keys defined in `flowker.secrets` (e.g., `MONGO_APP_PASSWORD`, `API_KEY`).

## Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespaceOverride` | Override the namespace for all resources | `flowker` |
| `flowker.enabled` | Enable flowker deployment | `true` |
| `flowker.replicaCount` | Number of replicas | `1` |
| `flowker.image.repository` | Image repository | `ghcr.io/lerianstudio/flowker` |
| `flowker.image.tag` | Image tag | `1.0.0-beta.22` |
| `flowker.service.port` | Service port | `4000` |
| `flowker.ingress.enabled` | Enable ingress | `false` |
| `flowker.autoscaling.enabled` | Enable HPA | `true` |
| `flowker.pdb.enabled` | Enable PodDisruptionBudget | `true` |
| `flowker.useExistingSecret` | Use an existing secret | `false` |
| `flowker.existingSecretName` | Name of the existing secret | `""` |
| `mongodb.enabled` | Enable bundled MongoDB subchart | `true` |

For full configuration options, see [values.yaml](values.yaml).
