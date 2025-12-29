# Plugin BR PIX Indirect BTG - Helm Chart

This Helm chart deploys **Plugin BR PIX Indirect BTG** for Midaz, enabling PIX instant payment integration with BTG Pactual.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Required Configuration](#required-configuration)
- [Installation](#installation)
- [Configuration Examples](#configuration-examples)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Parameters](#parameters)
- [Support](#support)

---

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.x
- BTG Pactual API credentials
- Midaz platform credentials
- Valid PIX ISPB code

---

## Quick Start

### 1. Customize Values Template

```yaml
pix:
  configmap:
    # BTG Configuration (REQUIRED)
    BTG_BASE_URL: "https://api.btgpactual.com"  # Production
    # BTG_BASE_URL: "https://api.sandbox.developer.btgpactual.com"  # Sandbox
    PIX_ISPB: "12345678"  # Your bank's ISPB (8 digits)

    # Midaz Configuration (REQUIRED)
    MIDAZ_ORGANIZATION_ID: "your-organization-id"
    MIDAZ_LEDGER_ID: "your-ledger-id"

    # Fee Configuration
    CASHIN_FEE_CALCULATION_TYPE: "segment"

    # License
    ORGANIZATION_IDS: global

  secrets:
    # BTG Credentials (REQUIRED)
    BTG_CLIENT_ID: "your-btg-client-id"
    BTG_CLIENT_SECRET: "your-btg-client-secret"

    # Midaz Credentials (REQUIRED)
    MIDAZ_CLIENT_ID: "your-midaz-client-id"
    MIDAZ_CLIENT_SECRET: "your-midaz-client-secret"

    # Database Passwords (CHANGE FROM DEFAULTS)
    DB_PASSWORD: "strong-database-password"
    DB_REPLICA_PASSWORD: "strong-replica-password"
    REPLICATION_PASSWORD: "strong-replication-password"
    MONGO_PASSWORD: "strong-mongo-password"
    REDIS_PASSWORD: ""  # Optional, only if valkey auth is enabled

    # License (REQUIRED)
    LICENSE_KEY: "your-license-key"

    # CRM Credentials (Optional)
    PLUGIN_CRM_CLIENT_ID: ""
    PLUGIN_CRM_CLIENT_SECRET: ""

# Outbound Worker (sends webhook notifications to your API)
outbound:
  configmap:
    # Webhook URLs (REQUIRED for notifications)
    WEBHOOK_CLIENT_URL: "https://your-api.com/webhook"
    WEBHOOK_DICT_CLAIM_URL: "https://your-api.com/webhook/dict-claim"
    WEBHOOK_DICT_INFRACTION_REPORT_URL: "https://your-api.com/webhook/dict-infraction"
    WEBHOOK_DICT_REFUND_URL: "https://your-api.com/webhook/dict-refund"
    WEBHOOK_TRANSFER_CASHIN_URL: "https://your-api.com/webhook/transfer-in"
    WEBHOOK_TRANSFER_CASHOUT_URL: "https://your-api.com/webhook/transfer-out"

# Database configuration (optional - uses bundled PostgreSQL/MongoDB/Valkey by default)
postgresql:
  auth:
    password: "strong-postgresql-password"

mongodb:
  auth:
    rootPassword: "strong-mongodb-password"
```

> **Note:** Internal service URLs (CRM, Transaction, Onboarding, Auth, Fee) use Kubernetes DNS defaults and don't need to be configured. Database, MongoDB, and Redis hosts also have sensible defaults for the bundled dependencies.

### 2. Install the Chart

```bash
helm install plugin-pix-btg . \
  -f values-custom.yaml \
  --namespace your-namespace \
  --create-namespace
```

### 3. Verify Installation

```bash
# Check pods status
kubectl get pods -n your-namespace

# Check logs
kubectl logs -n your-namespace -l app.kubernetes.io/name=plugin-br-pix-indirect-btg -f
```

---

## Required Configuration

The following fields are **REQUIRED** and will cause deployment to fail if not set:

### BTG Configuration
- `pix.configmap.BTG_BASE_URL` - BTG API endpoint
- `pix.configmap.PIX_ISPB` - Your bank's ISPB code
- `pix.secrets.BTG_CLIENT_ID` - BTG client ID
- `pix.secrets.BTG_CLIENT_SECRET` - BTG client secret

### Midaz Configuration
- `pix.configmap.MIDAZ_ORGANIZATION_ID` - Midaz organization ID
- `pix.configmap.MIDAZ_LEDGER_ID` - Midaz ledger ID
- `pix.secrets.MIDAZ_CLIENT_ID` - Midaz client ID
- `pix.secrets.MIDAZ_CLIENT_SECRET` - Midaz client secret

### License
- `pix.secrets.LICENSE_KEY` - Your license key

### Security
⚠️ **IMPORTANT**: Change default passwords before production deployment:
- `pix.secrets.DB_PASSWORD`
- `pix.secrets.DB_REPLICA_PASSWORD`
- `pix.secrets.REPLICATION_PASSWORD`
- `pix.secrets.MONGO_PASSWORD`
- `postgresql.auth.password`
- `mongodb.auth.rootPassword`

---

## Installation

### From OCI Registry

```bash
helm install plugin-pix-btg \
  oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg \
  --version <version> \
  -f values-custom.yaml \
  -n your-namespace \
  --create-namespace
```

### From Local Chart

```bash
helm install plugin-pix-btg . \
  -f values-custom.yaml \
  -n your-namespace \
  --create-namespace
```

---

## Configuration Examples

The `values-template.yaml` file contains all configurable options with comments. Here are environment-specific overrides:

### Production Environment

Create `values-production.yaml`:

```yaml
pix:
  autoscaling:
    minReplicas: 3
    maxReplicas: 9
    targetCPUUtilizationPercentage: 70
  configmap:
    BTG_BASE_URL: "https://api.btgpactual.com"
  resources:
    limits:
      cpu: 500m
      memory: 512Mi

outbound:
  configmap:
    ENV_NAME: "production"

postgresql:
  persistence:
    size: 50Gi
    storageClass: "fast-ssd"
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi

mongodb:
  persistence:
    enabled: true
    size: 20Gi
```

Then deploy with:
```bash
helm install plugin-pix-btg . \
  -f values-template.yaml \
  -f values-production.yaml \
  -n production
```

### Staging Environment

Create `values-staging.yaml`:

```yaml
pix:
  autoscaling:
    minReplicas: 1
    maxReplicas: 3
  configmap:
    BTG_BASE_URL: "https://api-h.developer.btgpactual.com"

outbound:
  configmap:
    ENV_NAME: "staging"

postgresql:
  persistence:
    size: 10Gi
```

### Development Environment

Create `values-development.yaml`:

```yaml
pix:
  autoscaling:
    enabled: false
  replicaCount: 1
  configmap:
    BTG_BASE_URL: "https://api.sandbox.developer.btgpactual.com"

outbound:
  configmap:
    ENV_NAME: "development"

postgresql:
  persistence:
    size: 5Gi
```

---

## Upgrading

To upgrade the chart to a new version:

```bash
helm upgrade plugin-pix-btg \
  oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg \
  --version <new-version> \
  -f values-custom.yaml \
  -n your-namespace
```

---

## Uninstalling

To uninstall the chart:

```bash
helm uninstall plugin-pix-btg -n your-namespace
```

**Note**: This will also delete the bundled PostgreSQL and MongoDB instances. Ensure you have backups if needed.

---

## Configuring Ingress for Different Controllers

The Plugin pix Helm Chart optionally supports different Ingress Controllers for exposing services when necessary. Below are the configurations for commonly used controllers.

- **Note:** Before configuring Ingress, ensure that you have an Ingress Controller installed in your cluster. Examples include NGINX, AWS ALB, and Traefik.

### NGINX Ingress Controller
To use the **NGINX Ingress Controller**, configure the `values.yaml` as follows:

```yaml
pix:
  ingress:
    enabled: true
    className: "nginx"
    annotations: {}
    hosts:
      - host: midaz.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: midaz-tls
        hosts:
          - midaz.example.com
```

---

## Parameters

### pix Service

| Parameter | Description | Default |
| --- | --- | --- |
| `pix.replicaCount` | Number of replicas for the deployment | `1` |
| `pix.image.repository` | Repository for the container image | `ghcr.io/lerianstudio/plugin-br-pix-indirect-btg` |
| `pix.image.pullPolicy` | Image pull policy | `Always` |
| `pix.image.tag` | Image tag used for deployment | `""` (defaults to Chart.AppVersion) |
| `pix.imagePullSecrets` | Secrets for pulling images from a private registry | `{}` |
| `pix.revisionHistoryLimit` | Old ReplicaSets to retain | `10` |
| `pix.nameOverride` | Overrides the default generated name by Helm | `""` |
| `pix.fullnameOverride` | Overrides the full name generated by Helm | `""` |
| `pix.ingress.enabled` | Enable or disable ingress | `false` |
| `pix.ingress.className` | Ingress class name | `""` |
| `pix.ingress.annotations` | Additional ingress annotations | `{}` |
| `pix.ingress.hosts` | Ingress host configuration | `[{"host": "", "paths": [{"path": "/", "pathType": "Prefix"}]}]` |
| `pix.ingress.tls` | TLS configuration for ingress | `[]` |
| `pix.service.type` | Kubernetes service type | `ClusterIP` |
| `pix.service.port` | Service port | `4014` |
| `pix.deploymentStrategy` | Deployment strategy | See `values.yaml` |
| `pix.podSecurityContext` | Pod security context | `{}` |
| `pix.securityContext` | Security context for the container | See `values.yaml` |
| `pix.pdb.enabled` | Enable or disable PodDisruptionBudget | `true` |
| `pix.pdb.maxUnavailable` | Maximum number of unavailable pods | `1` |
| `pix.pdb.minAvailable` | Minimum number of available pods | `0` |
| `pix.resources` | CPU and memory limits for pods | See `values.yaml` |
| `pix.autoscaling.enabled` | Enable or disable horizontal pod autoscaling | `true` |
| `pix.autoscaling.minReplicas` | Minimum number of replicas | `1` |
| `pix.autoscaling.maxReplicas` | Maximum number of replicas | `3` |
| `pix.nodeSelector` | Node selector for scheduling pods | `{}` |
| `pix.tolerations` | Tolerations for scheduling on tainted nodes | `{}` |
| `pix.affinity` | Affinity rules for pod scheduling | `{}` |
| `pix.extraEnvVars` | Extra environment variables to be added to the deployment | `{}` |
| `pix.useExistingSecrets` | Use an existing secret instead of creating a new one | `false` |
| `pix.existingSecretName` | The name of the existing secret to use | `""` |
| `pix.configmap.BTG_BASE_URL` | BTG API endpoint (REQUIRED) | `""` |
| `pix.configmap.PIX_ISPB` | Your bank's ISPB code (REQUIRED) | `""` |
| `pix.configmap.MIDAZ_ORGANIZATION_ID` | Midaz organization ID (REQUIRED) | `""` |
| `pix.configmap.MIDAZ_LEDGER_ID` | Midaz ledger ID (REQUIRED) | `""` |
| `pix.configmap.CASHIN_FEE_CALCULATION_TYPE` | Fee calculation type | `"segment"` |
| `pix.configmap.ORGANIZATION_IDS` | License organization IDs | `"global"` |
| `pix.secrets.BTG_CLIENT_ID` | BTG client ID (REQUIRED) | `""` |
| `pix.secrets.BTG_CLIENT_SECRET` | BTG client secret (REQUIRED) | `""` |
| `pix.secrets.MIDAZ_CLIENT_ID` | Midaz client ID (REQUIRED) | `""` |
| `pix.secrets.MIDAZ_CLIENT_SECRET` | Midaz client secret (REQUIRED) | `""` |
| `pix.secrets.DB_PASSWORD` | Database password | `"lerian"` |
| `pix.secrets.DB_REPLICA_PASSWORD` | Database replica password | `"lerian"` |
| `pix.secrets.REPLICATION_PASSWORD` | Replication password | `""` |
| `pix.secrets.MONGO_PASSWORD` | MongoDB password | `"lerian"` |
| `pix.secrets.REDIS_PASSWORD` | Redis password | `""` |
| `pix.secrets.LICENSE_KEY` | License key (REQUIRED) | `""` |
| `pix.secrets.PLUGIN_CRM_CLIENT_ID` | CRM client ID | `""` |
| `pix.secrets.PLUGIN_CRM_CLIENT_SECRET` | CRM client secret | `""` |

### Inbound Worker

| Parameter | Description | Default |
| --- | --- | --- |
| `inbound.replicaCount` | Number of replicas | `1` |
| `inbound.image.repository` | Repository for the container image | `ghcr.io/lerianstudio/plugin-br-pix-indirect-btg-worker-inbound` |
| `inbound.image.pullPolicy` | Image pull policy | `Always` |
| `inbound.image.tag` | Image tag used for deployment | `"1.0.0-rc.11"` |
| `inbound.autoscaling.enabled` | Enable autoscaling | `true` |
| `inbound.autoscaling.minReplicas` | Minimum replicas | `1` |
| `inbound.autoscaling.maxReplicas` | Maximum replicas | `3` |
| `inbound.autoscaling.targetCPUUtilizationPercentage` | Target CPU % | `80` |
| `inbound.autoscaling.targetMemoryUtilizationPercentage` | Target Memory % | `80` |
| `inbound.service.type` | Kubernetes service type | `ClusterIP` |
| `inbound.service.port` | Service port | `4016` |
| `inbound.resources` | CPU and memory limits | See `values.yaml` |
| `inbound.useExistingSecrets` | Use existing secret | `false` |
| `inbound.existingSecretName` | Existing secret name | `""` |

### Outbound Worker

| Parameter | Description | Default |
| --- | --- | --- |
| `outbound.replicaCount` | Number of replicas | `1` |
| `outbound.image.repository` | Repository for the container image | `ghcr.io/lerianstudio/plugin-br-pix-indirect-btg-worker-outbound` |
| `outbound.image.pullPolicy` | Image pull policy | `Always` |
| `outbound.image.tag` | Image tag used for deployment | `"1.0.0-rc.11"` |
| `outbound.autoscaling.enabled` | Enable autoscaling | `true` |
| `outbound.autoscaling.minReplicas` | Minimum replicas | `1` |
| `outbound.autoscaling.maxReplicas` | Maximum replicas | `3` |
| `outbound.autoscaling.targetCPUUtilizationPercentage` | Target CPU % | `80` |
| `outbound.autoscaling.targetMemoryUtilizationPercentage` | Target Memory % | `80` |
| `outbound.service.type` | Kubernetes service type | `ClusterIP` |
| `outbound.service.port` | Service port | `4015` |
| `outbound.configmap.ENV_NAME` | Environment name | `"development"` |
| `outbound.configmap.WEBHOOK_CLIENT_URL` | Main webhook URL | `""` |
| `outbound.configmap.WEBHOOK_DICT_CLAIM_URL` | Dict claim webhook URL | `""` |
| `outbound.configmap.WEBHOOK_DICT_INFRACTION_REPORT_URL` | Infraction webhook URL | `""` |
| `outbound.configmap.WEBHOOK_DICT_REFUND_URL` | Refund webhook URL | `""` |
| `outbound.configmap.WEBHOOK_TRANSFER_CASHIN_URL` | Cash-in webhook URL | `""` |
| `outbound.configmap.WEBHOOK_TRANSFER_CASHOUT_URL` | Cash-out webhook URL | `""` |
| `outbound.resources` | CPU and memory limits | See `values.yaml` |
| `outbound.useExistingSecrets` | Use existing secret | `false` |
| `outbound.existingSecretName` | Existing secret name | `""` |

### MongoDB Dependency

| Parameter | Description | Default |
| --- | --- | --- |
| `mongodb.enabled` | Enable MongoDB dependency | `true` |
| `mongodb.image.repository` | MongoDB image repository | `bitnamisecure/mongodb` |
| `mongodb.image.tag` | MongoDB image tag | `latest` |
| `mongodb.auth.enabled` | Enable authentication | `true` |
| `mongodb.auth.rootUser` | Root user | `pix_btg` |
| `mongodb.auth.rootPassword` | Root password | `lerian` |

> IMPORTANT: The bundled MongoDB is not intended for production. For production, use an external/managed MongoDB and set `mongodb.enabled=false`.

### Valkey/Redis Dependency

| Parameter | Description | Default |
| --- | --- | --- |
| `valkey.enabled` | Enable Valkey dependency | `true` |
| `valkey.auth.enabled` | Enable authentication | `false` |

> NOTE: Valkey is used for caching and session management. For production, consider enabling authentication.

### PostgreSQL Dependency

| Parameter | Description | Default |
| --- | --- | --- |
| `postgresql.enabled` | Enable the PostgreSQL dependency | `true` |
| `postgresql.external` | Use an external PostgreSQL instance | `false` |
| `postgresql.image.repository` | PostgreSQL image repository | `bitnamisecure/postgresql` |
| `postgresql.image.tag` | PostgreSQL image tag | `latest` |
| `postgresql.auth.enabled` | Enable authentication | `true` |
| `postgresql.auth.enablePostgresUser` | Create default postgres user | `false` |
| `postgresql.auth.username` | Application DB user | `pix_btg` |
| `postgresql.auth.password` | Application DB password | `lerian` |
| `postgresql.auth.database` | Application DB name | `pix_btg` |

> IMPORTANT: The bundled PostgreSQL is not intended for production. For production, use an external/managed PostgreSQL and set `postgresql.enabled=false`.


## Support

For more information, see the [Lerian Studio Documentation](https://docs.lerian.studio/) or contact the maintainers.
