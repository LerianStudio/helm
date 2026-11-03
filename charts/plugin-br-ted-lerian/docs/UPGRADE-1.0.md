# plugin-br-ted-lerian Helm chart v1.0

## Topics

- **[Installing](#installing)**
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

---

## Installing

Chart `1.0.0` is the first release of this chart. Its name is `plugin-br-ted-lerian-helm` and it deploys app version `1.0.0-beta.33`.

```sh
helm upgrade --install plugin-br-ted-lerian \
  oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm \
  --version 1.0.0 \
  --namespace plugin-br-ted-lerian --create-namespace \
  --values my-values.yaml
```

All service settings sit under the `plugin-br-ted-lerian` key in the values file. The chart's own resources render into the namespace set by `namespaceOverride` (default `plugin-br-ted-lerian`), and the bundled PostgreSQL and Valkey subcharts render into the release namespace, so keep `--namespace` and `namespaceOverride` equal.

---

## Features

### 1. Bundled Infrastructure Subcharts

The chart includes optional PostgreSQL and Valkey (Redis) subcharts for self-contained deployments.

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
- `POSTGRES_HOST`: Defaults to `<postgresql-subchart-fullname>.<namespace>.svc.cluster.local` (the in-cluster PostgreSQL Service)
- `REDIS_HOST`: Defaults to `<valkey-subchart-fullname>-primary.<namespace>.svc.cluster.local:6379` (the in-cluster Valkey primary Service)

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

> **Important:** The `boilerplateCredentials.password` (the password the Job gives the role) must be the same value as `plugin-br-ted-lerian.secrets.POSTGRES_PASSWORD` (the password the service logs in with).

**Job behavior:**
- Creates role `plugin-br-ted-lerian` if it doesn't exist
- Creates database `plugin-br-ted-lerian` if it doesn't exist
- Grants all privileges on the database and the `public` schema
- Idempotent: safe to run multiple times
- TTL: 300 seconds after completion

### 3. AWS IAM Roles Anywhere Integration

The chart supports AWS IAM Roles Anywhere for temporary credential provisioning via X.509 certificates.

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
- `AWS_EC2_METADATA_SERVICE_ENDPOINT`: Points to the local IMDS endpoint (`http://127.0.0.1:9911`)
- `AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE`: `IPv4`

> **Note:** The sidecar exchanges the X.509 certificate for temporary AWS credentials, exposing them via a local IMDS-compatible endpoint.

### 4. Cloud Topology Presets

The chart supports cloud-specific topology presets that configure TLS, SSL, and connection defaults for managed cloud services.

| Feature | Default | Description |
|---------|---------|-------------|
| `global.cloud` | `""` | Cloud preset: `aws`, `gcp`, `azure`, or empty |

```yaml
global:
  cloud: "aws"
```

**Impact:** When set, the cloud preset configures default TLS/SSL settings for PostgreSQL connections. Explicit configuration in `global.datastores` or `plugin-br-ted-lerian.configmap` still overrides the preset.

### 5. Enhanced Security Context

The chart includes a comprehensive security context with non-root user enforcement and read-only root filesystem.

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

**Impact:** The container runs as user `65532:65532` with a read-only root filesystem.

### 6. PodDisruptionBudget

The chart creates a PodDisruptionBudget to control voluntary disruptions during cluster maintenance.

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

**Impact:** When both `minAvailable` and `maxUnavailable` are set, the chart renders only `maxUnavailable`. To use `minAvailable`, set `maxUnavailable: null` in your values.

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

The chart includes feature toggles for optional integrations.

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
- `OTEL_EXPORTER_OTLP_ENDPOINT`: OTLP endpoint (from `global.observability.otlpEndpoint`; with `otel.enabled: true` the chart replaces it with `$(HOST_IP):4317`, the node IP)
- `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`: Deployment environment (default: `production`)

---

## Deployment Scenarios

### Scenario 1: External Datastores (Default)

This configuration is for environments where PostgreSQL and Redis are managed externally (e.g., AWS RDS, ElastiCache).

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
      host: "my-elasticache.example.com:6379"

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
      host: "my-elasticache.example.com:6379"
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
  useExistingSecret: true
  existingSecretName: "plugin-br-ted-lerian-db-credentials"

postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true
```

The Secret `plugin-br-ted-lerian-db-credentials` must hold the key `DB_PASSWORD_BOILERPLATE` (read by the Job) and the keys the service reads from it: `POSTGRES_PASSWORD` with the same value, plus `REDIS_PASSWORD` when Redis auth is on. With `useExistingSecret: true` the chart does not render its own Secret.
