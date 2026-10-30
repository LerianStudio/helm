# Helm Upgrade from v0.x to v1.x

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Chart Name Change](#chart-name-change)
  - [Values Structure](#values-structure)
  - [Namespace Override](#namespace-override)
- **[Features](#features)**
  - [1. Bundled Infrastructure Subcharts](#1-bundled-infrastructure-subcharts)
  - [2. External PostgreSQL Bootstrap Job](#2-external-postgresql-bootstrap-job)
  - [3. AWS IAM Roles Anywhere Integration](#3-aws-iam-roles-anywhere-integration)
  - [4. Cloud Topology Presets](#4-cloud-topology-presets)
  - [5. Enhanced Security Context](#5-enhanced-security-context)
  - [6. PodDisruptionBudget](#6-poddisruptionbudget)
  - [7. Productized Configuration](#7-productized-configuration)
  - [8. Feature Toggles](#8-feature-toggles)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: External Datastores (Default)](#scenario-1-external-datastores-default)
  - [Scenario 2: Bundled Datastores](#scenario-2-bundled-datastores)
  - [Scenario 3: External Datastores with Bootstrap Job](#scenario-3-external-datastores-with-bootstrap-job)
- **[Configuration Reference](#configuration-reference)**
  - [Global Configuration](#global-configuration)
  - [Service Configuration](#service-configuration)
  - [Infrastructure Subcharts](#infrastructure-subcharts)
  - [AWS Integration](#aws-integration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### Chart Name Change

The chart name has changed from `plugin-br-ted-lerian` to `plugin-br-ted-lerian-helm`.

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Chart name | N/A (chart did not exist) | `plugin-br-ted-lerian-helm` |
| OCI repository | N/A | `oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm` |

**Impact:** When upgrading, you must reference the new chart name in your `helm upgrade` command.

### Values Structure

All service-specific configuration is now nested under the `plugin-br-ted-lerian` key. This is a fundamental restructuring that affects every configuration value.

**Before (v0.0.0):**
```yaml
replicaCount: 1
image:
  repository: ghcr.io/lerianstudio/plugin-br-ted-lerian
  tag: "1.0.0-beta.33"
service:
  port: 8080
```

**After (v1.0.0):**
```yaml
plugin-br-ted-lerian:
  replicaCount: 1
  image:
    repository: ghcr.io/lerianstudio/plugin-br-ted-lerian
    tag: "1.0.0-beta.33"
  service:
    port: 8080
```

> **Warning:** All existing values files must be restructured. Every configuration key that was previously at the root level must now be nested under `plugin-br-ted-lerian`.

### Namespace Override

The chart now supports explicit namespace configuration through `namespaceOverride`.

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Namespace control | Implicit (Release.Namespace) | Explicit via `namespaceOverride` |
| Default namespace | Release namespace | `plugin-br-ted-lerian` |

```yaml
namespaceOverride: "plugin-br-ted-lerian"
```

**Impact:** If you were relying on the release namespace, you may need to explicitly set `namespaceOverride` to match your current deployment namespace.

---

## Features

### 1. Bundled Infrastructure Subcharts

The chart now includes optional PostgreSQL and Valkey (Redis) subcharts for self-contained deployments.

| Feature | Default | Description |
|---------|---------|-------------|
| `postgresql.enabled` | `false` | Enable bundled PostgreSQL subchart |
| `postgresql.external` | `true` | Indicates external PostgreSQL is expected |
| `valkey.enabled` | `false` | Enable bundled Valkey (Redis) subchart |
| `valkey.external` | `true` | Indicates external Valkey is expected |

**Default behavior (external datastores):**
```yaml
postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true
```

**Self-contained deployment:**
```yaml
postgresql:
  enabled: true
  external: false
  auth:
    username: "plugin-br-ted-lerian"
    database: "plugin-br-ted-lerian"
    password: ""  # Auto-generated

valkey:
  enabled: true
  external: false
  auth:
    enabled: true
    password: ""  # Auto-generated
```

> **Note:** When subcharts are enabled, `POSTGRES_HOST` and `REDIS_HOST` automatically resolve to the in-cluster service names, and passwords are read directly from the subchart's own Secret. No manual configuration is required.

**New environment variables (when subcharts enabled):**
- `POSTGRES_HOST`: Defaults to `<release-name>-postgresql` (subchart service)
- `REDIS_HOST`: Defaults to `<release-name>-valkey-master` (subchart service)

### 2. External PostgreSQL Bootstrap Job

A new optional Job can bootstrap an external PostgreSQL database by creating the required role, database, and privileges.

| Feature | Default | Description |
|---------|---------|-------------|
| `global.externalPostgresDefinitions.enabled` | `false` | Enable PostgreSQL bootstrap Job |
| `global.externalPostgresDefinitions.connection.host` | `plugin-br-ted-lerian-postgresql` | PostgreSQL host |
| `global.externalPostgresDefinitions.connection.port` | `5432` | PostgreSQL port |

```yaml
global:
  externalPostgresDefinitions:
    enabled: true
    connection:
      host: "my-rds.example.com"
      port: "5432"
    postgresAdminLogin:
      useExistingSecret:
        name: "postgres-admin-credentials"
      username: "postgres"
      password: ""
    boilerplateCredentials:
      useExistingSecret:
        name: "plugin-br-ted-lerian-db-credentials"
      password: ""
```

> **Important:** The `boilerplateCredentials.password` must match `plugin-br-ted-lerian.secrets.POSTGRES_PASSWORD`. Use `useExistingSecret.name` to ensure both read from the same Secret.

**Job behavior:**
- Creates role `plugin-br-ted-lerian` if it doesn't exist
- Creates database `plugin-br-ted-lerian` if it doesn't exist
- Grants all privileges on the database and schema
- Idempotent: safe to run multiple times
- TTL: 300 seconds after completion

### 3. AWS IAM Roles Anywhere Integration

The chart now supports AWS IAM Roles Anywhere for temporary credential provisioning via X.509 certificates.

| Feature | Default | Description |
|---------|---------|-------------|
| `aws.rolesAnywhere.enabled` | `false` | Enable IAM Roles Anywhere sidecar |
| `aws.rolesAnywhere.trustAnchorArn` | `""` | Trust anchor ARN (required when enabled) |
| `aws.rolesAnywhere.profileArn` | `""` | Profile ARN (required when enabled) |
| `aws.rolesAnywhere.roleArn` | `""` | Role ARN to assume (required when enabled) |
| `aws.rolesAnywhere.region` | `us-east-2` | AWS region |
| `aws.rolesAnywhere.sessionDuration` | `3600` | Session duration in seconds |
| `aws.rolesAnywhere.certificateSecretName` | `plugin-br-ted-lerian-iam-tls` | Secret containing X.509 cert |
| `aws.rolesAnywhere.sidecar.port` | `9911` | Local IMDS endpoint port |

```yaml
aws:
  rolesAnywhere:
    enabled: true
    trustAnchorArn: "arn:aws:rolesanywhere:us-east-2:123456789012:trust-anchor/abc123"
    profileArn: "arn:aws:rolesanywhere:us-east-2:123456789012:profile/def456"
    roleArn: "arn:aws:iam::123456789012:role/MyRole"
    region: "us-east-2"
    sessionDuration: 3600
    certificateSecretName: "plugin-br-ted-lerian-iam-tls"
```

**New environment variables (when enabled):**
- `AWS_CONTAINER_CREDENTIALS_FULL_URI`: Points to local IMDS endpoint (`http://127.0.0.1:9911/credentials`)
- `AWS_REGION`: Set to `aws.rolesAnywhere.region`

> **Note:** The sidecar exchanges the X.509 certificate for temporary AWS credentials, exposing them via a local IMDS-compatible endpoint.

### 4. Cloud Topology Presets

The chart now supports cloud-specific topology presets that configure TLS, SSL, and connection defaults for managed cloud services.

| Feature | Default | Description |
|---------|---------|-------------|
| `global.cloud` | `""` | Cloud preset: `aws`, `gcp`, `azure`, or empty |

```yaml
global:
  cloud: "aws"
```

**Impact:** When set, the cloud preset configures default TLS/SSL settings for PostgreSQL and Redis connections. Explicit configuration in `global.datastores` or `plugin-br-ted-lerian.configmap` still overrides the preset.

### 5. Enhanced Security Context

The chart now includes a comprehensive security context with non-root user enforcement and read-only root filesystem.

**Before (v0.0.0):**
```yaml
# No security context defined
```

**After (v1.0.0):**
```yaml
plugin-br-ted-lerian:
  securityContext:
    runAsGroup: 65532
    runAsUser: 65532
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
```

**Impact:** The container now runs as user `65532:65532` with a read-only root filesystem. If your application writes to the filesystem, you must mount writable volumes explicitly.

### 6. PodDisruptionBudget

The chart now creates a PodDisruptionBudget to control voluntary disruptions during cluster maintenance.

| Feature | Default | Description |
|---------|---------|-------------|
| `plugin-br-ted-lerian.pdb.enabled` | `true` | Enable PodDisruptionBudget |
| `plugin-br-ted-lerian.pdb.minAvailable` | `1` | Minimum available pods |
| `plugin-br-ted-lerian.pdb.maxUnavailable` | `1` | Maximum unavailable pods |

```yaml
plugin-br-ted-lerian:
  pdb:
    enabled: true
    minAvailable: 1
    maxUnavailable: 1
    annotations: {}
```

**Impact:** During cluster maintenance or node drains, Kubernetes will ensure at least 1 pod remains available.

### 7. Productized Configuration

The chart introduces clean, grouped configuration parameters that replace raw environment variable overrides.

**New configuration blocks:**

#### Application Settings

```yaml
plugin-br-ted-lerian:
  env: "production"
  logLevel: "info"
  serverAddress: ":8080"
  httpBodyLimitBytes: "104857600"
  allowInsecureTls: ""
  tlsTerminatedUpstream: "true"
  defaultTenantId: "11111111-1111-1111-1111-111111111111"
  infraConnectTimeoutSec: "30"
  dbMetricsIntervalSec: "15"
  idempotencyRetryWindowSec: "300"
```

**New environment variables:**
- `ENV_NAME`: Environment name (default: `production`)
- `LOG_LEVEL`: Logging level (default: `info`)
- `SERVER_ADDRESS`: HTTP server bind address (default: `:8080`)
- `HTTP_BODY_LIMIT_BYTES`: Maximum request body size (default: `104857600`)
- `ALLOW_INSECURE_TLS`: Allow insecure TLS connections (default: `""`)
- `TLS_TERMINATED_UPSTREAM`: TLS terminated by upstream proxy (default: `true`)
- `DEFAULT_TENANT_ID`: Default tenant UUID (default: `11111111-1111-1111-1111-111111111111`)
- `INFRA_CONNECT_TIMEOUT_SEC`: Infrastructure connection timeout (default: `30`)
- `DB_METRICS_INTERVAL_SEC`: Database metrics collection interval (default: `15`)
- `IDEMPOTENCY_RETRY_WINDOW_SEC`: Idempotency retry window (default: `300`)

#### CORS Configuration

```yaml
plugin-br-ted-lerian:
  cors:
    allowedOrigins: "*"
    allowedMethods: "GET,POST,PUT,PATCH,DELETE,OPTIONS"
    allowedHeaders: "Origin,Content-Type,Accept,Authorization,X-Request-ID"
```

**New environment variables:**
- `CORS_ALLOWED_ORIGINS`: Allowed CORS origins (default: `*`)
- `CORS_ALLOWED_METHODS`: Allowed HTTP methods (default: `GET,POST,PUT,PATCH,DELETE,OPTIONS`)
- `CORS_ALLOWED_HEADERS`: Allowed HTTP headers (default: `Origin,Content-Type,Accept,Authorization,X-Request-ID`)

#### Database Configuration

```yaml
plugin-br-ted-lerian:
  database:
    name: "plugin-br-ted-lerian"
    migrationsPath: "migrations"
    maxOpenConns: "25"
    maxIdleConns: "5"
    connMaxLifetimeMins: "30"
    connMaxIdleTimeMins: "5"
    connectTimeoutSec: "10"
```

**New environment variables:**
- `POSTGRES_NAME`: Database name (default: `plugin-br-ted-lerian`)
- `MIGRATIONS_PATH`: Database migrations path (default: `migrations`)
- `POSTGRES_MAX_OPEN_CONNS`: Maximum open connections (default: `25`)
- `POSTGRES_MAX_IDLE_CONNS`: Maximum idle connections (default: `5`)
- `POSTGRES_CONN_MAX_LIFETIME_MINS`: Connection max lifetime in minutes (default: `30`)
- `POSTGRES_CONN_MAX_IDLE_TIME_MINS`: Connection max idle time in minutes (default: `5`)
- `POSTGRES_CONNECT_TIMEOUT_SEC`: Connection timeout in seconds (default: `10`)

#### Redis Configuration

```yaml
plugin-br-ted-lerian:
  redis:
    db: "0"
    protocol: "3"
    poolSize: "10"
    minIdleConns: "2"
    readTimeoutMs: "3000"
    writeTimeoutMs: "3000"
    dialTimeoutMs: "5000"
```

**New environment variables:**
- `REDIS_DB`: Redis database number (default: `0`)
- `REDIS_PROTOCOL`: Redis protocol version (default: `3`)
- `REDIS_POOL_SIZE`: Connection pool size (default: `10`)
- `REDIS_MIN_IDLE_CONNS`: Minimum idle connections (default: `2`)
- `REDIS_READ_TIMEOUT_MS`: Read timeout in milliseconds (default: `3000`)
- `REDIS_WRITE_TIMEOUT_MS`: Write timeout in milliseconds (default: `3000`)
- `REDIS_DIAL_TIMEOUT_MS`: Dial timeout in milliseconds (default: `5000`)

#### Rate Limiting

```yaml
plugin-br-ted-lerian:
  rateLimit:
    enabled: "true"
    max: "500"
    windowSec: "60"
```

**New environment variables:**
- `RATE_LIMIT_ENABLED`: Enable rate limiting (default: `true`)
- `RATE_LIMIT_MAX`: Maximum requests per window (default: `500`)
- `RATE_LIMIT_WINDOW_SEC`: Rate limit window in seconds (default: `60`)

#### Swagger Configuration

```yaml
plugin-br-ted-lerian:
  swagger:
    enabled: "true"
    title: "Plugin Br Ted Lerian"
```

**New environment variables:**
- `SWAGGER_ENABLED`: Enable Swagger UI (default: `true`)
- `SWAGGER_TITLE`: Swagger UI title (default: `Plugin Br Ted Lerian`)

> **Note:** The raw `plugin-br-ted-lerian.configmap` override still exists as an escape hatch. Any key set there wins over the productized parameters.

### 8. Feature Toggles

The chart now includes feature toggles for optional integrations.

| Feature | Default | Description |
|---------|---------|-------------|
| `plugin-br-ted-lerian.multiTenant.enabled` | `false` | Enable multi-tenancy support |
| `plugin-br-ted-lerian.serviceDiscovery.enabled` | `false` | Enable Consul service discovery |
| `plugin-br-ted-lerian.streaming.enabled` | `false` | Enable RedPanda streaming |
| `plugin-br-ted-lerian.otel.enabled` | `false` | Enable OpenTelemetry |

```yaml
plugin-br-ted-lerian:
  multiTenant:
    enabled: false
  serviceDiscovery:
    enabled: false
  streaming:
    enabled: false
  otel:
    enabled: false
    libraryName: "github.com/LerianStudio/plugin-br-ted-lerian"
    serviceName: "plugin-br-ted-lerian"
    endpoint: ""
    deploymentEnvironment: "production"
```

**New environment variables (when enabled):**

**Multi-tenancy:**
- `MULTI_TENANT_ENABLED`: Enable multi-tenancy (default: `false`)
- `MULTI_TENANT_URL`: Tenant manager URL (from `global.multiTenant.url`)
- `MULTI_TENANT_REDIS_HOST`: Multi-tenant Redis host (from `global.multiTenant.redisHost`)
- `MULTI_TENANT_REDIS_PORT`: Multi-tenant Redis port (from `global.multiTenant.redisPort`)
- `MULTI_TENANT_REDIS_TLS`: Multi-tenant Redis TLS (from `global.multiTenant.redisTls`)

**Service Discovery:**
- `SD_ENABLED`: Enable service discovery (default: `false`)
- `SD_ADDRESS`: Consul address (from `global.serviceDiscovery.address`)
- `SD_TLS`: Consul TLS enabled (from `global.serviceDiscovery.tls`)
- `SD_TLS_SKIP_VERIFY`: Skip TLS verification (from `global.serviceDiscovery.tlsSkipVerify`)

**Streaming:**
- `STREAMING_ENABLED`: Enable streaming (default: `false`)
- `STREAMING_BROKERS`: RedPanda broker addresses (from `global.streaming.brokers`)
- `STREAMING_TLS_ENABLED`: Streaming TLS enabled (from `global.streaming.tlsEnabled`)
- `STREAMING_SASL_MECHANISM`: SASL mechanism (from `global.streaming.saslMechanism`)

**OpenTelemetry:**
- `ENABLE_TELEMETRY`: Enable telemetry (default: `false`)
- `OTEL_LIBRARY_NAME`: Library name (default: `github.com/LerianStudio/plugin-br-ted-lerian`)
- `OTEL_RESOURCE_SERVICE_NAME`: Service name (default: `plugin-br-ted-lerian`)
- `OTEL_EXPORTER_OTLP_ENDPOINT`: OTLP endpoint (from `global.observability.otlpEndpoint` or pod IP)
- `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`: Deployment environment (default: `production`)

> **Note:** These features are inert until both the toggle is enabled and the corresponding `global.*` configuration is provided.

---

## Deployment Scenarios

### Scenario 1: External Datastores (Default)

This is the default configuration for production environments where PostgreSQL and Redis are managed externally (e.g., AWS RDS, ElastiCache).

```yaml
global:
  cloud: "aws"
  datastores:
    postgres:
      host: "my-rds.example.com"
      port: "5432"
      user: "plugin-br-ted-lerian"
      ssl: "require"
    redis:
      host: "my-elasticache.example.com"
      port: "6379"

plugin-br-ted-lerian:
  secrets:
    POSTGRES_PASSWORD: "my-postgres-password"
    REDIS_PASSWORD: "my-redis-password"

postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true
```

**Migration from v0.0.0:**
1. Nest all existing configuration under `plugin-br-ted-lerian`
2. Move datastore connection details to `global.datastores`
3. Keep existing secrets under `plugin-br-ted-lerian.secrets`

### Scenario 2: Bundled Datastores

This configuration is suitable for development, testing, or self-contained deployments where each application brings its own infrastructure.

```yaml
plugin-br-ted-lerian:
  enabled: true

postgresql:
  enabled: true
  external: false
  auth:
    username: "plugin-br-ted-lerian"
    database: "plugin-br-ted-lerian"
    password: ""  # Auto-generated

valkey:
  enabled: true
  external: false
  auth:
    enabled: true
    password: ""  # Auto-generated
```

**Migration from v0.0.0:**
1. Nest all existing configuration under `plugin-br-ted-lerian`
2. Enable subcharts: `postgresql.enabled: true` and `valkey.enabled: true`
3. Remove `plugin-br-ted-lerian.secrets.POSTGRES_PASSWORD` and `REDIS_PASSWORD` (auto-generated by subcharts)
4. Remove any explicit `POSTGRES_HOST` or `REDIS_HOST` configuration (auto-resolved)

### Scenario 3: External Datastores with Bootstrap Job

This configuration uses external datastores but automates the initial database setup via the bootstrap Job.

```yaml
global:
  cloud: "aws"
  datastores:
    postgres:
      host: "my-rds.example.com"
      port: "5432"
      user: "plugin-br-ted-lerian"
      ssl: "require"
    redis:
      host: "my-elasticache.example.com"
      port: "6379"
  externalPostgresDefinitions:
    enabled: true
    connection:
      host: "my-rds.example.com"
      port: "5432"
    postgresAdminLogin:
      useExistingSecret:
        name: "postgres-admin-credentials"
    boilerplateCredentials:
      useExistingSecret:
        name: "plugin-br-ted-lerian-db-credentials"

plugin-br-ted-lerian:
  secrets:
    POSTGRES_PASSWORD: ""  # Read from boilerplateCredentials secret
    REDIS_PASSWORD: "my-redis-password"
  useExistingSecret: true
  existingSecretName: "plugin-br-ted-lerian-db-credentials"

postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true
```

**Migration from v0.0.0:**
1. Nest all existing configuration under `plugin-br-ted-lerian`
2. Move datastore connection details to `global.datastores`
3. Create a Secret with `DB_PASSWORD_BOILERPLATE` key containing the database password
4. Enable bootstrap Job: `global.externalPostgresDefinitions.enabled: true`
5. Configure admin credentials via `postgresAdminLogin.useExistingSecret`
6. Set `plugin-br-ted-lerian.useExistingSecret: true` and reference the same Secret

---

## Configuration Reference

### Global Configuration

```yaml
global:
  # Cloud topology preset
  cloud: ""  # aws | gcp | azure | ""

  # Shared datastore configuration
  datastores:
    postgres:
      host: ""
      port: "5432"
      user: "plugin-br-ted-lerian"
      ssl: ""
    redis:
      host: ""
      port: "6379"

  # Observability configuration
  observability:
    enabled: false
    otlpEndpoint: ""
    deploymentEnvironment: ""

  # Authentication configuration
  auth:
    enabled: false
    host: ""

  # Multi-tenancy configuration
  multiTenant:
    url: ""
    redisHost: ""
    redisPort: ""
    redisTls: ""

  # Service discovery configuration
  serviceDiscovery:
    address: ""
    tls: ""
    tlsSkipVerify: ""
    workload: ""
    preferView: ""
    internalScheme: ""
    externalPort: ""

  # Streaming configuration
  streaming:
    brokers: ""
    tlsEnabled: ""
    saslMechanism: ""
    saslUsername: ""
    saslAllowPlaintext: ""
    compression: ""
    requiredAcks: ""
    batchLingerMs: ""
    importantEmitTimeoutMs: ""

  # External PostgreSQL bootstrap
  externalPostgresDefinitions:
    enabled: false
    connection:
      host: "plugin-br-ted-lerian-postgresql"
      port: "5432"
    postgresAdminLogin:
      useExistingSecret:
        name: ""
      username: "postgres"
      password: ""
    boilerplateCredentials:
      useExistingSecret:
        name: ""
      password: ""
```

### Service Configuration

```yaml
plugin-br-ted-lerian:
  # Identity
  name: plugin-br-ted-lerian
  description: "TED transfers plugin for Midaz"
  enabled: true
  replicaCount: 1
  revisionHistoryLimit: 10

  # Image
  image:
    repository: ghcr.io/lerianstudio/plugin-br-ted-lerian
    pullPolicy: IfNotPresent
    tag: "1.0.0-beta.33"
  imagePullSecrets:
    - name: ghcr-credential

  # Security
  podAnnotations: {}
  podSecurityContext: {}
  securityContext:
    runAsGroup: 65532
    runAsUser: 65532
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true

  # Availability
  pdb:
    enabled: true
    minAvailable: 1
    maxUnavailable: 1
    annotations: {}
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 1

  # Networking
  service:
    type: ClusterIP
    port: 8080
    annotations: {}
  ingress:
    enabled: true
    className: "nginx"
    annotations: {}
    hosts:
      - host: "plugin-br-ted-lerian.lerian.net"
        paths:
          - path: /
            pathType: Prefix
    tls: []

  # Resources
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 64Mi
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80
    targetMemoryUtilizationPercentage: 80

  # Scheduling
  nodeSelector: {}
  tolerations: {}
  affinity: {}

  # Feature toggles
  multiTenant:
    enabled: false
  serviceDiscovery:
    enabled: false
  streaming:
    enabled: false
  otel:
    enabled: false
    libraryName: "github.com/LerianStudio/plugin-br-ted-lerian"
    serviceName: "plugin-br-ted-lerian"
    endpoint: ""
    deploymentEnvironment: "production"

  # Application configuration
  env: "production"
  logLevel: "info"
  serverAddress: ":8080"
  httpBodyLimitBytes: "104857600"
  allowInsecureTls: ""
  tlsTerminatedUpstream: "true"
  defaultTenantId: "11111111-1111-1111-1111-111111111111"
  infraConnectTimeoutSec: "30"
  dbMetricsIntervalSec: "15"
  idempotencyRetryWindowSec: "300"

  # CORS
  cors:
    allowedOrigins: "*"
    allowedMethods: "GET,POST,PUT,PATCH,DELETE,OPTIONS"
    allowedHeaders: "Origin,Content-Type,Accept,Authorization,X-Request-ID"

  # Database
  database:
    name: "plugin-br-ted-lerian"
    migrationsPath: "migrations"
    maxOpenConns: "25"
    maxIdleConns: "5"
    connMaxLifetimeMins: "30"
    connMaxIdleTimeMins: "5"
    connectTimeoutSec: "10"

  # Redis
  redis:
    db: "0"
    protocol: "3"
    poolSize: "10"
    minIdleConns: "2"
    readTimeoutMs: "3000"
    writeTimeoutMs: "3000"
    dialTimeoutMs: "5000"

  # Rate limiting
  rateLimit:
    enabled: "true"
    max: "500"
    windowSec: "60"

  # Swagger
  swagger:
    enabled: "true"
    title: "Plugin Br Ted Lerian"

  # Raw overrides (escape hatch)
  configmap: {}

  # Secrets
  secrets:
    POSTGRES_PASSWORD: ""
    REDIS_PASSWORD: ""
    MULTI_TENANT_SERVICE_API_KEY: ""
    MULTI_TENANT_REDIS_PASSWORD: ""
  useExistingSecret: false
  existingSecretName: ""

  # Extra environment variables
  extraEnvVars: []

  # Service account
  serviceAccount:
    create: true
    annotations: {}
    name: ""
```

### Infrastructure Subcharts

```yaml
postgresql:
  enabled: false
  external: true
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamisecure/postgresql
    tag: ""
    digest: "sha256:db2312d9b243afa8c3b3f5496e478d17d0dff9791d06f3b93b9567abd86ae92f"
  auth:
    username: "plugin-br-ted-lerian"
    database: "plugin-br-ted-lerian"
    password: ""

valkey:
  enabled: false
  external: true
  auth:
    enabled: true
    password: ""
```

### AWS Integration

```yaml
aws:
  rolesAnywhere:
    enabled: false
    trustAnchorArn: ""
    profileArn: ""
    roleArn: ""
    region:
