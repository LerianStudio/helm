# Tracer Helm Chart

A Helm chart for deploying Tracer - Real-time transaction validation and fraud prevention API.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PostgreSQL database (external or managed)

## Installation

```bash
helm install tracer ./charts/tracer -n tracer --create-namespace
```

## Configuration

### Namespace Override

By default, resources are deployed to the `tracer` namespace. Override with:

```bash
helm install tracer ./charts/tracer --set namespaceOverride=custom-namespace -n custom-namespace
```

### PostgreSQL Bootstrap Job

For external PostgreSQL databases, enable the bootstrap job to create the database and role:

```yaml
global:
  externalPostgresDefinitions:
    enabled: true
    connection:
      host: "your-postgres-host"
      port: "5432"
    postgresAdminLogin:
      username: "postgres"
      password: "admin-password"
    tracerCredentials:
      password: "tracer-password"
```

Or use existing secrets:

```yaml
global:
  externalPostgresDefinitions:
    enabled: true
    connection:
      host: "your-postgres-host"
      port: "5432"
    postgresAdminLogin:
      useExistingSecret:
        name: "postgres-admin-secret"  # Must contain DB_USER_ADMIN and DB_ADMIN_PASSWORD keys
    tracerCredentials:
      useExistingSecret:
        name: "tracer-credentials-secret"  # Must contain DB_PASSWORD_TRACER key
```

## Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespaceOverride` | Override the namespace for all resources | `tracer` |
| `tracer.enabled` | Enable tracer deployment | `true` |
| `tracer.replicaCount` | Number of replicas | `1` |
| `tracer.image.repository` | Image repository | `lerianstudio/tracer` |
| `tracer.image.tag` | Image tag | `1.0.0` |
| `tracer.service.port` | Service port | `8080` |
| `tracer.ingress.enabled` | Enable ingress | `false` |
| `tracer.autoscaling.enabled` | Enable HPA | `true` |
| `tracer.pdb.enabled` | Enable PodDisruptionBudget | `true` |
| `global.externalPostgresDefinitions.enabled` | Enable PostgreSQL bootstrap job | `false` |

For full configuration options, see [values.yaml](values.yaml).
