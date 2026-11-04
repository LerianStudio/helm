# Tracer Helm Chart

> **Deprecated.** This chart no longer receives new Tracer image versions. New installs use the Tracer that the [`midaz` chart](../midaz/README.md) installs, configured under the `tracer:` values block.

## Chart Contract

- Chart type: `single-service`
- Required secrets: None for default render. `tracer.secrets.LICENSE_KEY` is rendered into the Secret only when non-empty.
- Dependency notes: No local dependency chart is bundled. PostgreSQL is external; when `global.externalPostgresDefinitions.enabled=true` a bootstrap Job provisions and initializes the database and role on the external PostgreSQL.
- Production overrides: Provide production PostgreSQL credentials through chart secrets; override image tags, ingress, resources, and namespace.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Elastic License 2.0.

A Helm chart for deploying Tracer - Real-time transaction validation and fraud prevention API.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.2.0+
- PostgreSQL database (external or managed)

## Installation

```bash
helm install tracer ./charts/tracer -n tracer --create-namespace
```

Before you install, set `tracer.configmap.DB_HOST` to your PostgreSQL host and `tracer.secrets.DB_PASSWORD` to the password of the `tracer` role. The bootstrap Job does not set them.

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
| `tracer.service.port` | Service port | `4020` |
| `tracer.ingress.enabled` | Enable ingress | `false` |
| `tracer.autoscaling.enabled` | Enable HPA | `true` |
| `tracer.pdb.enabled` | Enable PodDisruptionBudget | `true` |
| `global.externalPostgresDefinitions.enabled` | Enable PostgreSQL bootstrap job | `false` |

For full configuration options, see [values.yaml](values.yaml).
