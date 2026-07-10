# Flowker Helm Chart

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `flowker.secrets.AUDIT_DB_PASSWORD` for the default non-multi-tenant render. With the bundled MongoDB subchart, `MONGO_URI` is assembled automatically from the subchart-generated Secret; supply `flowker.secrets.MONGO_URI` only when pointing at external MongoDB.
- Dependency notes: Bundles the Bitnami MongoDB subchart unless external MongoDB is configured. MongoDB credentials are single-sourced from the subchart Secret (`mongodb-root-password`) — operators do not supply them for the bundled instance. The audit PostgreSQL (required when `MULTI_TENANT_ENABLED=false`) is always external — no PostgreSQL dependency chart is bundled.
- Production overrides: Provide production database credentials through chart secrets or an existing Secret where supported; override image tags, ingress, resources, and dependency persistence for the target environment.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

A Helm chart for deploying Flowker - Workflow orchestration platform for financial validation.

## Components

The chart renders these workloads (all but the api are toggleable):

| Component | Toggle | Default | Description |
|-----------|--------|---------|-------------|
| api | `flowker.enabled` | on | The Flowker HTTP API Deployment (port 4021). |
| worker | `worker.enabled` | on | A second Deployment running the `/worker` binary from the same flowker image: the queue-backed scheduler consume server and background jobs (single replica, no HPA). |
| xsd-validator sidecar | `flowker.xsdValidator.enabled` | on | In-pod XML/XSD validation sidecar (port 8081) injected into the api and worker pods; reached over loopback. |
| valkey | `valkey.enabled` | off | Bundled Redis-compatible store backing the scheduler queue. When off, set `flowker.configmap.SCHEDULER_REDIS_HOST` to an external Redis. |
| aws-signing-helper sidecar | `aws.rolesAnywhere.enabled` | off | IAM Roles Anywhere credential sidecar for non-EKS clusters. On EKS use IRSA via `flowker.serviceAccount.annotations` instead. |

> The worker and XSD sidecar require an app image that bundles the `/worker` binary and a published `flowker-xsd-validator` sidecar image (>= `1.2.0-beta.82`).
>
> The worker and XSD sidecar are also gated on `flowker.enabled` — setting `flowker.enabled=false` disables them regardless of their own toggle.

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
  secrets:
    MONGO_URI: "mongodb://user:password@your-mongo-host:27017/flowker?authSource=admin"
```

### Existing Secrets

To use an existing Kubernetes secret instead of the chart-managed one:

```yaml
flowker:
  useExistingSecret: true
  existingSecretName: "my-flowker-secret"
```

The secret must contain the keys defined in `flowker.secrets` (e.g., `MONGO_URI`, `AUDIT_DB_PASSWORD`, `API_KEY`).

## Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespaceOverride` | Override the namespace for all resources | `flowker` |
| `flowker.enabled` | Enable flowker deployment | `true` |
| `flowker.replicaCount` | Number of replicas | `1` |
| `flowker.image.repository` | Image repository | `ghcr.io/lerianstudio/flowker` |
| `flowker.image.tag` | Image tag (must bundle `/worker`, >= `1.2.0-beta.82`) | `1.2.0-beta.82` |
| `flowker.service.port` | Service port | `4021` |
| `flowker.ingress.enabled` | Enable ingress | `false` |
| `flowker.autoscaling.enabled` | Enable HPA | `true` |
| `flowker.pdb.enabled` | Enable PodDisruptionBudget | `true` |
| `flowker.useExistingSecret` | Use an existing secret | `false` |
| `flowker.existingSecretName` | Name of the existing secret | `""` |
| `flowker.workosTmEnabled` | Enable WorkOS Tenant Manager token mint (all-or-none) | `false` |
| `flowker.xsdValidator.enabled` | Inject the in-pod XSD validator sidecar | `true` |
| `worker.enabled` | Deploy the scheduler worker Deployment | `true` |
| `valkey.enabled` | Bundle valkey as the scheduler queue Redis | `false` |
| `aws.rolesAnywhere.enabled` | Inject the IAM Roles Anywhere signing sidecar | `false` |
| `mongodb.enabled` | Enable bundled MongoDB subchart | `true` |

For full configuration options, see [values.yaml](values.yaml).
