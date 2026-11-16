# Helm Upgrade from v0.x to v1.x

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Chart is now available](#chart-is-now-available)
- **[Features](#features)**
  - [1. Multi-datastore architecture with bundled subcharts](#1-multi-datastore-architecture-with-bundled-subcharts)
  - [2. PostgreSQL migrations job](#2-postgresql-migrations-job)
  - [3. External datastore bootstrap jobs](#3-external-datastore-bootstrap-jobs)
  - [4. Global observability configuration](#4-global-observability-configuration)
  - [5. Multi-tenancy support](#5-multi-tenancy-support)
  - [6. Service discovery integration](#6-service-discovery-integration)
  - [7. Streaming (Kafka) integration](#7-streaming-kafka-integration)
  - [8. Authentication plugin integration](#8-authentication-plugin-integration)
  - [9. Production-grade security defaults](#9-production-grade-security-defaults)
  - [10. Horizontal Pod Autoscaling](#10-horizontal-pod-autoscaling)
  - [11. PodDisruptionBudget](#11-poddisruptionbudget)
  - [12. Comprehensive secrets management](#12-comprehensive-secrets-management)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: Bundled datastores (default)](#scenario-1-bundled-datastores-default)
  - [Scenario 2: External datastores](#scenario-2-external-datastores)
  - [Scenario 3: Mixed (some bundled, some external)](#scenario-3-mixed-some-bundled-some-external)
- **[Configuration Reference](#configuration-reference)**
  - [Core service configuration](#core-service-configuration)
  - [Datastore configuration](#datastore-configuration)
  - [Secrets configuration](#secrets-configuration)
  - [Global configuration blocks](#global-configuration-blocks)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### Chart is now available

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Chart existence | Chart did not exist | Chart is now published and available |
| Installation method | N/A | Helm chart installation required |

**Before (v0.0.0):**

The br-ccs chart did not exist. Operators deployed the br-ccs service using custom manifests or other deployment methods.

**After (v1.0.0):**

The br-ccs chart is now available as a complete Helm chart with full lifecycle management. This is the initial release (v1.0.0) of the chart.

> **Important:** This is a new chart release. If you were previously deploying br-ccs using custom manifests, you will need to migrate to the Helm chart deployment model. Ensure you back up your existing configuration and data before proceeding.

## Features

### 1. Multi-datastore architecture with bundled subcharts

The chart now includes three bundled datastore subcharts that can be enabled or disabled based on your deployment needs:

- **PostgreSQL** (Bitnami postgresql v16.3.5) - Primary application database
- **Valkey** (Bitnami valkey v2.4.7) - Redis-compatible cache
- **RabbitMQ** (groundhog2k rabbitmq v2.1.11) - Message broker

**Default configuration (bundled datastores):**

```yaml
postgresql:
  enabled: true
  external: false

valkey:
  enabled: true
  external: false

rabbitmq:
  enabled: true
  external: false
```

**External datastores configuration:**

```yaml
postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true

rabbitmq:
  enabled: false
  external: true

global:
  datastores:
    postgres:
      host: "my-external-postgres.example.com"
      port: "5432"
      user: "br-ccs"
      name: "br-ccs"
      ssl: "require"
    redis:
      host: "my-external-redis.example.com:6379"
    broker:
      host: "my-external-rabbitmq.example.com"
      port: "5672"
      user: "br-ccs"
```

| Flag | Default | Description |
|------|---------|-------------|
| `postgresql.enabled` | `true` | Enable bundled PostgreSQL subchart |
| `postgresql.external` | `false` | Use external PostgreSQL (disables subchart when true) |
| `valkey.enabled` | `true` | Enable bundled Valkey subchart |
| `valkey.external` | `false` | Use external Valkey (disables subchart when true) |
| `rabbitmq.enabled` | `true` | Enable bundled RabbitMQ subchart |
| `rabbitmq.external` | `false` | Use external RabbitMQ (disables subchart when true) |

### 2. PostgreSQL migrations job

The chart includes an automated database migration job that runs as a Helm hook before the main application starts.

**Migration job configuration:**

```yaml
brCcs:
  migrations:
    enabled: true
    useExistingSecret: false
    existingSecretName: ""
    path: "/migrations"
    image:
      repository: ghcr.io/lerianstudio/br-ccs-migrations
      tag: ""  # Defaults to brCcs.image.tag
      pullPolicy: IfNotPresent
    backoffLimit: 3
    resources:
      limits:
        cpu: 250m
        memory: 256Mi
      requests:
        cpu: 50m
        memory: 64Mi
```

| Flag | Default | Description |
|------|---------|-------------|
| `brCcs.migrations.enabled` | `true` | Enable database migrations job |
| `brCcs.migrations.useExistingSecret` | `false` | Read POSTGRES_PASSWORD from existing secret |
| `brCcs.migrations.existingSecretName` | `""` | Name of existing secret (when useExistingSecret=true) |
| `brCcs.migrations.path` | `"/migrations"` | Path to migrations inside the image |
| `brCcs.migrations.backoffLimit` | `3` | Maximum retries before job fails |

> **Note:** The migration job uses a dedicated `br-ccs-migrations` image that contains the golang-migrate runner. The application image never runs migrations directly.

**Hook behavior:**

- **Bundled PostgreSQL**: Runs as `post-install,post-upgrade` (after PostgreSQL is ready)
- **External PostgreSQL**: Runs as `pre-install,pre-upgrade` (before application starts)

### 3. External datastore bootstrap jobs

When using external datastores, the chart provides optional bootstrap jobs to create required databases, roles, and permissions.

#### PostgreSQL bootstrap job

```yaml
global:
  externalPostgresDefinitions:
    enabled: true
    connection:
      host: "my-postgres.example.com"
      port: "5432"
    postgresAdminLogin:
      useExistingSecret:
        name: "postgres-admin-secret"
      username: "postgres"
      password: ""
    brCcsCredentials:
      useExistingSecret:
        name: "br-ccs-db-secret"
      password: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.externalPostgresDefinitions.enabled` | `false` | Enable PostgreSQL bootstrap job |
| `global.externalPostgresDefinitions.connection.host` | `"br-ccs-postgresql-primary"` | PostgreSQL host |
| `global.externalPostgresDefinitions.connection.port` | `"5432"` | PostgreSQL port |
| `global.externalPostgresDefinitions.postgresAdminLogin.username` | `"postgres"` | Admin username |
| `global.externalPostgresDefinitions.brCcsCredentials.password` | `""` | Password for br-ccs role |

**What the job creates:**

1. PostgreSQL role `br-ccs` with LOGIN privilege
2. Database `br-ccs` owned by the `br-ccs` role

#### RabbitMQ bootstrap job

```yaml
global:
  externalRabbitmqDefinitions:
    enabled: true
    connection:
      protocol: "http"
      host: "my-rabbitmq.example.com"
      port: "15672"
      portAmqp: "5672"
      skipTlsVerify: false
    rabbitmqAdminLogin:
      useExistingSecret:
        name: "rabbitmq-admin-secret"
      username: "admin"
      password: ""
    brCcsCredentials:
      useExistingSecret:
        name: "br-ccs-rabbitmq-secret"
      password: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.externalRabbitmqDefinitions.enabled` | `false` | Enable RabbitMQ bootstrap job |
| `global.externalRabbitmqDefinitions.connection.protocol` | `"http"` | Management API protocol |
| `global.externalRabbitmqDefinitions.connection.host` | `"br-ccs-rabbitmq"` | RabbitMQ host |
| `global.externalRabbitmqDefinitions.connection.port` | `"15672"` | Management API port |
| `global.externalRabbitmqDefinitions.connection.portAmqp` | `"5672"` | AMQP port |

**What the job creates:**

1. RabbitMQ user `br-ccs`
2. Virtual host `/br-ccs`
3. Permissions for the `br-ccs` user on the `/br-ccs` vhost

### 4. Global observability configuration

The chart provides a centralized observability configuration block for OpenTelemetry integration.

```yaml
global:
  observability:
    enabled: false
    otlpEndpoint: ""
    deploymentEnvironment: "production"
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.observability.enabled` | `false` | Enable telemetry export (ENABLE_TELEMETRY) |
| `global.observability.otlpEndpoint` | `""` | OTLP collector endpoint (OTEL_EXPORTER_OTLP_ENDPOINT) |
| `global.observability.deploymentEnvironment` | `"production"` | Deployment environment tag (OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT) |

**Environment variables generated:**

- `ENABLE_TELEMETRY`
- `OTEL_EXPORTER_OTLP_ENDPOINT`
- `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`

> **Note:** Per-service overrides can be set via `brCcs.configmap.ENABLE_TELEMETRY`, `brCcs.configmap.OTEL_EXPORTER_OTLP_ENDPOINT`, etc.

### 5. Multi-tenancy support

The chart includes configuration for multi-tenant deployments with tenant-manager integration.

```yaml
brCcs:
  multiTenant:
    enabled: false

global:
  multiTenant:
    url: ""
    redisHost: ""
    redisPort: "6379"
    redisTls: "false"
```

| Flag | Default | Description |
|------|---------|-------------|
| `brCcs.multiTenant.enabled` | `false` | Enable multi-tenancy (MULTI_TENANT_ENABLED) |
| `global.multiTenant.url` | `""` | Tenant-manager URL (MULTI_TENANT_URL) |
| `global.multiTenant.redisHost` | `""` | Tenant-manager Redis host (MULTI_TENANT_REDIS_HOST) |
| `global.multiTenant.redisPort` | `"6379"` | Tenant-manager Redis port |
| `global.multiTenant.redisTls` | `"false"` | Enable TLS for tenant-manager Redis |

**Required secrets (when enabled):**

```yaml
brCcs:
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: ""
    MULTI_TENANT_REDIS_PASSWORD: ""
```

### 6. Service discovery integration

The chart supports Consul service discovery integration.

```yaml
brCcs:
  serviceDiscovery:
    enabled: false

global:
  serviceDiscovery:
    address: "localhost:8500"
    tls: "false"
    workload: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `brCcs.serviceDiscovery.enabled` | `false` | Enable Consul service discovery (SD_ENABLED) |
| `global.serviceDiscovery.address` | `"localhost:8500"` | Consul address (SD_ADDRESS) |
| `global.serviceDiscovery.tls` | `"false"` | Enable TLS for Consul (SD_TLS) |
| `global.serviceDiscovery.workload` | `""` | Workload identifier for environment isolation (SD_WORKLOAD) |

**Required secrets (when enabled):**

```yaml
brCcs:
  secrets:
    SD_TOKEN: ""  # Consul ACL token
```

### 7. Streaming (Kafka) integration

The chart supports lib-streaming integration for Kafka-based event streaming.

```yaml
brCcs:
  streaming:
    enabled: false

global:
  streaming:
    brokers: ""
    tlsEnabled: "false"
    saslMechanism: ""
    saslUsername: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `brCcs.streaming.enabled` | `false` | Enable lib-streaming (STREAMING_ENABLED) |
| `global.streaming.brokers` | `""` | Kafka broker list (STREAMING_BROKERS) |
| `global.streaming.tlsEnabled` | `"false"` | Enable TLS for Kafka (STREAMING_TLS_ENABLED) |
| `global.streaming.saslMechanism` | `""` | SASL mechanism (PLAIN, SCRAM-SHA-256, SCRAM-SHA-512) |
| `global.streaming.saslUsername` | `""` | SASL username (STREAMING_SASL_USERNAME) |

**Required secrets (when enabled):**

```yaml
brCcs:
  secrets:
    STREAMING_SASL_PASSWORD: ""
```

### 8. Authentication plugin integration

The chart supports plugin-access-manager integration for inbound authentication.

```yaml
global:
  auth:
    enabled: "true"
    host: "http://plugin-access-manager:4000"
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.auth.enabled` | `"false"` | Enable plugin-access-manager auth (PLUGIN_AUTH_ENABLED) |
| `global.auth.host` | `""` | Plugin-access-manager URL (PLUGIN_AUTH_HOST) |

**Environment variables generated:**

- `PLUGIN_AUTH_ENABLED`
- `PLUGIN_AUTH_HOST`

### 9. Production-grade security defaults

The chart enforces production-grade security settings by default.

**Security context:**

```yaml
brCcs:
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
```

**Key security features:**

- Non-root user (UID/GID 1000)
- Read-only root filesystem
- All capabilities dropped
- No privilege escalation
- RuntimeDefault seccomp profile

### 10. Horizontal Pod Autoscaling

The chart includes HPA configuration for automatic scaling based on CPU and memory utilization.

```yaml
brCcs:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80
    targetMemoryUtilizationPercentage: 80
```

| Flag | Default | Description |
|------|---------|-------------|
| `brCcs.autoscaling.enabled` | `true` | Enable horizontal pod autoscaling |
| `brCcs.autoscaling.minReplicas` | `2` | Minimum number of replicas |
| `brCcs.autoscaling.maxReplicas` | `5` | Maximum number of replicas |
| `brCcs.autoscaling.targetCPUUtilizationPercentage` | `80` | Target CPU utilization for scaling |
| `brCcs.autoscaling.targetMemoryUtilizationPercentage` | `80` | Target memory utilization for scaling |

> **Note:** When autoscaling is enabled, the `brCcs.replicaCount` value is ignored.

### 11. PodDisruptionBudget

The chart includes a PodDisruptionBudget to ensure availability during voluntary disruptions.

```yaml
brCcs:
  pdb:
    enabled: true
    minAvailable: 1
    maxUnavailable: 1
    annotations: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `brCcs.pdb.enabled` | `true` | Enable PodDisruptionBudget |
| `brCcs.pdb.minAvailable` | `1` | Minimum number of available pods |
| `brCcs.pdb.maxUnavailable` | `1` | Maximum number of unavailable pods |

> **Important:** Only one of `minAvailable` or `maxUnavailable` should be set. The default configuration sets both; you should choose one based on your availability requirements.

### 12. Comprehensive secrets management

The chart provides a complete secrets structure covering all application credentials and keys.

**Required secrets (production):**

```yaml
brCcs:
  secrets:
    # Database credentials
    POSTGRES_PASSWORD: ""
    
    # Redis credentials
    REDIS_PASSWORD: ""
    
    # RabbitMQ credentials (when enabled)
    RABBITMQ_DEFAULT_PASS: ""
    
    # Crypto keys (REQUIRED)
    CCS_CRYPTO_MASTER_KEY: ""  # 64 hex chars (openssl rand -hex 32)
    FETCHER_CRYPTO_KEY: ""     # base64 encoded
    
    # License (REQUIRED)
    LICENSE_KEY: ""
    ORGANIZATION_IDS: ""
    
    # Object storage credentials
    OBJECT_STORAGE_STA_ACCESS_KEY: ""
    OBJECT_STORAGE_STA_SECRET_KEY: ""
    OBJECT_STORAGE_CCS_ACCESS_KEY: ""
    OBJECT_STORAGE_CCS_SECRET_KEY: ""
    OBJECT_STORAGE_FETCHER_ACCESS_KEY: ""
    OBJECT_STORAGE_FETCHER_SECRET_KEY: ""
```

**Optional secrets (per-upstream M2M OAuth2):**

```yaml
brCcs:
  secrets:
    # Fetcher integration
    FETCHER_CLIENT_ID: ""
    FETCHER_CLIENT_SECRET: ""
    
    # Reporter integration
    REPORTER_CLIENT_ID: ""
    REPORTER_CLIENT_SECRET: ""
    
    # STA integration
    STA_CLIENT_ID: ""
    STA_CLIENT_SECRET: ""
    
    # CRM integration
    CRM_CLIENT_ID: ""
    CRM_CLIENT_SECRET: ""
    
    # IdP integration (when IDP_DECLARATION_ENABLED=true)
    IDP_M2M_CLIENT_ID: ""
    IDP_M2M_CLIENT_SECRET: ""
```

> **Warning:** Never commit real secret values to version control. Use a secrets manager (e.g., AWS Secrets Manager, HashiCorp Vault) or Kubernetes external secrets operator.

## Deployment Scenarios

### Scenario 1: Bundled datastores (default)

This is the default configuration where all datastores are deployed as subcharts within the same namespace.

**Configuration:**

```yaml
postgresql:
  enabled: true
  external: false

valkey:
  enabled: true
  external: false

rabbitmq:
  enabled: true
  external: false

brCcs:
  enabled: true
  secrets:
    POSTGRES_PASSWORD: "change-me"
    REDIS_PASSWORD: "change-me"
    RABBITMQ_DEFAULT_PASS: "change-me"
    CCS_CRYPTO_MASTER_KEY: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    FETCHER_CRYPTO_KEY: "base64-encoded-key"
    LICENSE_KEY: "your-license-key"
    ORGANIZATION_IDS: "global"
```

**Migration steps:**

1. Create a `values.yaml` file with your configuration
2. Set all required secrets
3. Install the chart:

```bash
helm install br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm \
  --version 1.0.0 \
  --namespace br-ccs \
  --create-namespace \
  --values values.yaml
```

### Scenario 2: External datastores

Use this configuration when you have existing external PostgreSQL, Redis, and RabbitMQ instances.

**Configuration:**

```yaml
postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true

rabbitmq:
  enabled: false
  external: true

global:
  datastores:
    postgres:
      host: "my-postgres.example.com"
      port: "5432"
      user: "br-ccs"
      name: "br-ccs"
      ssl: "require"
    redis:
      host: "my-redis.example.com:6379"
    broker:
      host: "my-rabbitmq.example.com"
      port: "5672"
      user: "br-ccs"

brCcs:
  secrets:
    POSTGRES_PASSWORD: "external-db-password"
    REDIS_PASSWORD: "external-redis-password"
    RABBITMQ_DEFAULT_PASS: "external-rabbitmq-password"
    CCS_CRYPTO_MASTER_KEY: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    FETCHER_CRYPTO_KEY: "base64-encoded-key"
    LICENSE_KEY: "your-license-key"
    ORGANIZATION_IDS: "global"
```

**Migration steps:**

1. Ensure your external datastores are accessible from the Kubernetes cluster
2. Create the required databases and users manually, or use the bootstrap jobs:

```yaml
global:
  externalPostgresDefinitions:
    enabled: true
    connection:
      host: "my-postgres.example.com"
      port: "5432"
    postgresAdminLogin:
      username: "postgres"
      password: "admin-password"
    brCcsCredentials:
      password: "br-ccs-password"

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
    brCcsCredentials:
      password: "br-ccs-password"
```

3. Install the chart:

```bash
helm install br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm \
  --version 1.0.0 \
  --namespace br-ccs \
  --create-namespace \
  --values values.yaml
```

### Scenario 3: Mixed (some bundled, some external)

You can mix bundled and external datastores based on your needs.

**Example: Bundled PostgreSQL and Redis, external RabbitMQ:**

```yaml
postgresql:
  enabled: true
  external: false

valkey:
  enabled: true
  external: false

rabbitmq:
  enabled: false
  external: true

global:
  datastores:
    broker:
      host: "my-rabbitmq.example.com"
      port: "5672"
      user: "br-ccs"

brCcs:
  secrets:
    POSTGRES_PASSWORD: "bundled-db-password"
    REDIS_PASSWORD: "bundled-redis-password"
    RABBITMQ_DEFAULT_PASS: "external-rabbitmq-password"
    CCS_CRYPTO_MASTER_KEY: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    FETCHER_CRYPTO_KEY: "base64-encoded-key"
    LICENSE_KEY: "your-license-key"
    ORGANIZATION_IDS: "global"
```

## Configuration Reference

### Core service configuration

```yaml
brCcs:
  name: br-ccs
  enabled: true
  replicaCount: 2
  revisionHistoryLimit: 10
  
  image:
    repository: ghcr.io/lerianstudio/br-ccs
    pullPolicy: IfNotPresent
    tag: "1.1.2"
  
  service:
    type: ClusterIP
    port: 4030
    annotations: {}
  
  resources:
    limits:
      cpu: 1500m
      memory: 512Mi
    requests:
      cpu: 500m
      memory: 256Mi
  
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 100%
    maxUnavailable: 0
```

| Flag | Default | Description |
|------|---------|-------------|
| `brCcs.name` | `br-ccs` | Service name |
| `brCcs.enabled` | `true` | Enable the br-ccs service |
| `brCcs.replicaCount` | `2` | Number of replicas (ignored when autoscaling is enabled) |
| `brCcs.revisionHistoryLimit` | `10` | Number of old ReplicaSets to retain |
| `brCcs.image.repository` | `ghcr.io/lerianstudio/br-ccs` | Container image repository |
| `brCcs.image.tag` | `"1.1.2"` | Container image tag |
| `brCcs.service.type` | `ClusterIP` | Kubernetes service type |
| `brCcs.service.port` | `4030` | HTTP API port |

### Datastore configuration

**Precedence order (highest to lowest):**

1. `brCcs.configmap.<KEY>` - Direct environment variable override
2. `brCcs.datastores.<type>.<field>` - Service-specific datastore config
3. `global.datastores.<type>.<field>` - Environment-wide datastore config
4. Chart defaults (bundled subchart or native key defaults)

**PostgreSQL configuration:**

```yaml
global:
  datastores:
    postgres:
      host: ""          # POSTGRES_HOST (required for external)
      port: "5432"      # POSTGRES_PORT
      user: "br-ccs"    # POSTGRES_USER
      name: "br-ccs"    # POSTGRES_NAME (database name)
      ssl: "require"    # POSTGRES_SSLMODE
      replicaHost: ""   # POSTGRES_REPLICA_HOST (enables replica when set)
```

**Redis configuration:**

```yaml
global:
  datastores:
    redis:
      host: ""  # REDIS_HOST (host:port format; required for external)
```

**RabbitMQ configuration:**

```yaml
global:
  datastores:
    broker:
      host: ""          # RABBITMQ_HOST (required for external)
      port: "5672"      # RABBITMQ_PORT_AMQP
      user: "br-ccs"    # RABBITMQ_DEFAULT_USER
```

### Secrets configuration

**Using chart-managed secrets:**

```yaml
brCcs:
  secrets:
    POSTGRES_PASSWORD: "my-password"
    REDIS_PASSWORD: "my-password"
    # ... other secrets
```

**Using existing secrets:**

For bundled subcharts, you can reference existing secrets:

```yaml
postgresql:
  auth:
    existingSecret: "my-postgres-secret"

valkey:
  auth:
    existingSecret: "my-redis-secret"

rabbitmq:
  auth:
    existingSecret: "my-rabbitmq-secret"
```

For the migration job with external PostgreSQL:

```yaml
brCcs:
  migrations:
    useExistingSecret: true
    existingSecretName: "my-postgres-secret"
```

### Global configuration blocks

**Complete global configuration example:**

```yaml
global:
  # Observability
  observability:
    enabled: true
    otlpEndpoint: "http://otel-collector:4317"
    deploymentEnvironment: "production"
  
  # Datastores
  datastores:
    postgres:
      host: "my-postgres.example.com"
      port: "5432"
      user: "br-ccs"
      name: "br-ccs"
      ssl: "require"
    redis:
      host: "my-redis.example.com:6379"
    broker:
      host: "my-rabbitmq.example.com"
      port: "5672"
      user: "br-ccs"
  
  # Multi-tenancy
  multiTenant:
    url: "http://tenant-manager:4000"
    redisHost: "tenant-redis.example.com"
    redisPort: "6379"
    redisTls: "false"
  
  # Service discovery
  serviceDiscovery:
    address: "consul.example.com:8500"
    tls: "true"
    workload: "production"
  
  # Streaming
  streaming:
    brokers: "kafka-1.example.com:9092,kafka-2.example.com:9092"
    tlsEnabled: "true"
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "br-ccs"
  
  # Authentication
  auth:
    enabled: "true"
    host: "http://plugin-access-manager:4000"
```

## Preview changes before upgrading

```bash
helm diff upgrade br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm --version 1.0.0 -n br-ccs
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm --version 1.0.0 -n br-ccs
```
