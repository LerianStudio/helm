# Tracer Helm Chart

## Chart Contract

- Chart type: `single-service`
- Required secrets: None for default render.
- Dependency notes: No local dependency chart is bundled. Depends on `lerian-common-helm` (shared library chart) for the HPA/PDB/Service/Ingress templates and the `global.*` config masks below. PostgreSQL is external; when `global.externalPostgresDefinitions.enabled=true` a bootstrap Job provisions and initializes the database and role on the external PostgreSQL (its host/port resolve through the same Postgres mask as the app's own `DB_HOST`/`DB_PORT`, so both stay in sync).
- Production overrides: Provide production PostgreSQL credentials through chart secrets or dependency Secret settings; override image tags, ingress, resources, namespace, and persistence.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

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

## Managed Cloud (`global.cloud`)

Point this chart at a managed-cloud environment (AWS/GCP/Azure) instead of an
ad hoc PostgreSQL host with one knob:

```yaml
global:
  cloud: "aws"   # aws | gcp | azure — leave unset for the plain default topology
  datastores:
    postgres: { host: "my-rds.example.com", user: "tracer" }
  env:
    name: "production"
  auth:
    host: "http://plugin-access-manager-auth:4000"
  observability:
    enabled: true
```

`global.cloud` sets the connection TOPOLOGY (e.g. `DB_SSL_MODE`) for the masks
above; only the ENDPOINTS (host/port/user) still come from
`global.datastores` — a cloud preset can't know your RDS host. A native
`tracer.configmap.<KEY>` always overrides any mask, and `global.datastores.postgres`
also drives the external-Postgres bootstrap Job's host/port (see above), so
there is a single place to point both at the same database.

`values.yaml` documents every masked key inline; `values.schema.json`
validates the `global.*` shape.

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
