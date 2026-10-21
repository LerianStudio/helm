# Helm Upgrade from v0.x to v1.x

This guide covers the upgrade of the `system-facts` Helm chart from version **0.0.0** to **1.0.0**. This is the initial release of the chart, introducing the System Facts service with optional bundled infrastructure and an internal-facts-worker component.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[New Features](#new-features)**
  - [1. System Facts Service](#1-system-facts-service)
  - [2. Optional Internal Facts Worker](#2-optional-internal-facts-worker)
  - [3. Bundled Infrastructure Subcharts](#3-bundled-infrastructure-subcharts)
  - [4. Database Migrations Job](#4-database-migrations-job)
  - [5. External PostgreSQL Bootstrap Job](#5-external-postgresql-bootstrap-job)
  - [6. AWS IAM Roles Anywhere Integration](#6-aws-iam-roles-anywhere-integration)
  - [7. Feature Toggles](#7-feature-toggles)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: External Infrastructure (Production)](#scenario-1-external-infrastructure-production)
  - [Scenario 2: Bundled Infrastructure (Development/Testing)](#scenario-2-bundled-infrastructure-developmenttesting)
  - [Scenario 3: With Internal Facts Worker](#scenario-3-with-internal-facts-worker)
- **[Configuration Reference](#configuration-reference)**
  - [System Facts Service Configuration](#system-facts-service-configuration)
  - [Worker Configuration](#worker-configuration)
  - [Infrastructure Configuration](#infrastructure-configuration)
  - [Global Configuration](#global-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.0.0** is the initial release of the `system-facts` Helm chart. This chart deploys:

- **System Facts API service**: The Lerian fact registry HTTP service
- **Optional internal-facts-worker**: Event consumer that delivers facts from RedPanda to the System Facts API
- **Optional bundled PostgreSQL and Valkey**: For self-contained development/testing environments
- **Database migrations Job**: ArgoCD Sync-hook Job for applying root schema migrations
- **External PostgreSQL bootstrap Job**: Creates databases, roles, and grants for external PostgreSQL instances

Since this is the first release (upgrading from a non-existent v0.0.0), all features are new. Operators installing this chart for the first time should review the deployment scenarios and configuration reference sections.

---

## Breaking Changes

**None.** This is the initial release. There are no breaking changes from a previous version.

---

## New Features

### 1. System Facts Service

The chart deploys the System Facts API service with full production-ready configuration:

**Key capabilities:**

- HTTP API on port 8080 with configurable ingress
- PostgreSQL database backend with connection pooling
- Redis/Valkey for caching and rate limiting
- CORS configuration
- Rate limiting with configurable thresholds
- Swagger documentation endpoint
- Optional systemplane runtime configuration
- Horizontal Pod Autoscaling
- PodDisruptionBudget for high availability

**Default service configuration:**

```yaml
system-facts:
  enabled: true
  replicaCount: 1
  image:
    repository: ghcr.io/lerianstudio/system-facts
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8080
  ingress:
    enabled: true
    className: "nginx"
    hosts:
      - host: "system-facts.lerian.net"
        paths:
          - path: /
            pathType: Prefix
```

**Environment variables added:**

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV_NAME` | `production` | Environment name |
| `LOG_LEVEL` | `info` | Logging level |
| `SERVER_ADDRESS` | `:8080` | HTTP server bind address |
| `HTTP_BODY_LIMIT_BYTES` | `104857600` | Maximum HTTP request body size (100MB) |
| `TLS_TERMINATED_UPSTREAM` | `true` | Whether TLS is terminated by ingress/load balancer |
| `DEFAULT_TENANT_ID` | `11111111-1111-1111-1111-111111111111` | Default tenant UUID |
| `INFRA_CONNECT_TIMEOUT_SEC` | `30` | Infrastructure connection timeout |
| `DB_METRICS_INTERVAL_SEC` | `15` | Database metrics collection interval |
| `IDEMPOTENCY_RETRY_WINDOW_SEC` | `300` | Idempotency key retry window |
| `POSTGRES_NAME` | `system-facts` | PostgreSQL database name |
| `MIGRATIONS_PATH` | `migrations` | Path to migration files |
| `POSTGRES_MAX_OPEN_CONNS` | `25` | Maximum open database connections |
| `POSTGRES_MAX_IDLE_CONNS` | `5` | Maximum idle database connections |
| `POSTGRES_CONN_MAX_LIFETIME_MINS` | `30` | Connection maximum lifetime |
| `POSTGRES_CONN_MAX_IDLE_TIME_MINS` | `5` | Connection maximum idle time |
| `POSTGRES_CONNECT_TIMEOUT_SEC` | `10` | Database connection timeout |
| `REDIS_DB` | `0` | Redis database number |
| `REDIS_PROTOCOL` | `3` | Redis protocol version |
| `REDIS_POOL_SIZE` | `10` | Redis connection pool size |
| `REDIS_MIN_IDLE_CONNS` | `2` | Minimum idle Redis connections |
| `REDIS_READ_TIMEOUT_MS` | `3000` | Redis read timeout |
| `REDIS_WRITE_TIMEOUT_MS` | `3000` | Redis write timeout |
| `REDIS_DIAL_TIMEOUT_MS` | `5000` | Redis dial timeout |
| `RATE_LIMIT_ENABLED` | `true` | Enable rate limiting |
| `RATE_LIMIT_MAX` | `500` | Maximum requests per window |
| `RATE_LIMIT_WINDOW_SEC` | `60` | Rate limit window duration |
| `SYSTEMPLANE_ENABLED` | `false` | Enable runtime configuration plane |
| `SWAGGER_ENABLED` | `true` | Enable Swagger documentation |
| `SWAGGER_TITLE` | `System Facts` | Swagger UI title |
| `CORS_ALLOWED_ORIGINS` | `*` | CORS allowed origins |
| `CORS_ALLOWED_METHODS` | `GET,POST,PUT,PATCH,DELETE,OPTIONS` | CORS allowed methods |
| `CORS_ALLOWED_HEADERS` | `Origin,Content-Type,Accept,Authorization,X-Request-ID` | CORS allowed headers |

### 2. Optional Internal Facts Worker

The chart includes an optional `internal-facts-worker` component that consumes product events from RedPanda and delivers facts to the System Facts API.

**Worker is disabled by default:**

```yaml
worker:
  enabled: false
```

**Enable the worker:**

```yaml
worker:
  enabled: true
  replicaCount: 1
  image:
    repository: ghcr.io/lerianstudio/system-facts-worker
    tag: "1.0.0"
  products:
    - "product-a"
    - "product-b"
  systemFacts:
    url: "http://system-facts:8080"
    authUrl: "http://plugin-access-manager-auth:4000"
    allowInsecureHttp: false
  streaming:
    brokers: "redpanda:9092"
    cloudeventsSource: "internal-facts-worker"
    tlsEnabled: true
    requireSecurity: true
```

**Worker environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SYSTEM_FACTS_URL` | (required) | System Facts API endpoint |
| `SYSTEM_FACTS_AUTH_URL` | (required) | Plugin access manager auth endpoint |
| `SYSTEM_FACTS_ALLOW_INSECURE_HTTP` | `false` | Allow HTTP (non-TLS) connections |
| `WORKER_PRODUCTS` | (required) | Comma-separated list of products to process |
| `STREAMING_CONSUMER_ENABLED` | `true` | Enable streaming consumer |
| `STREAMING_CONSUMER_BROKERS` | (required) | Kafka/RedPanda broker addresses |
| `STREAMING_CLOUDEVENTS_SOURCE` | (required) | CloudEvents source identifier |
| `STREAMING_TLS_ENABLED` | `true` | Enable TLS for broker connections |
| `REQUIRE_BROKER_SECURITY` | `true` | Require broker security (TLS/SASL) |
| `SERVER_ADDRESS` | `:8080` | Admin server bind address (health checks only) |
| `ENVIRONMENT_NAME` | `""` | Environment name |

> **Note:** The worker is a separate binary that does NOT expose an HTTP API for traffic. It only runs an admin server for kubelet health checks. The chart does not render a Service, Ingress, or HPA for the worker.

### 3. Bundled Infrastructure Subcharts

The chart includes optional PostgreSQL and Valkey subcharts for self-contained development/testing environments.

**Both are disabled by default:**

```yaml
postgresql:
  enabled: false

valkey:
  enabled: false
```

**Enable bundled infrastructure:**

```yaml
postgresql:
  enabled: true
  auth:
    username: "system-facts"
    password: "changeme"
    database: "system-facts"
  primary:
    persistence:
      enabled: true
      size: 8Gi

valkey:
  enabled: true
  auth:
    enabled: true
    password: "changeme"
  master:
    persistence:
      enabled: true
      size: 8Gi
```

> **Warning:** Bundled infrastructure is intended for development and testing only. Production deployments should use external, managed PostgreSQL and Redis/Valkey instances configured via `global.datastores`.

### 4. Database Migrations Job

The chart includes an ArgoCD Sync-hook Job that applies root schema migrations using a dedicated runner image.

**Migrations are disabled by default:**

```yaml
migrations:
  enabled: false
```

**Enable migrations:**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/system-facts-migrations
    tag: "1.0.0"
```

> **Important:** The migrations Job requires the `system-facts-migrations` runner image. The service image is distroless and cannot apply migrations directly. The Job only applies the flat root sequence (`/migrations`); tenant-specific migrations (`/migrations/tenant`) are applied by the service at boot or on tenant-added events.

**Migration Job configuration:**

| Field | Default | Description |
|-------|---------|-------------|
| `migrations.enabled` | `false` | Render the migrations Job |
| `migrations.image.repository` | (required) | Runner image repository |
| `migrations.image.tag` | (chart appVersion) | Runner image tag |
| `migrations.backoffLimit` | `3` | Job retry limit |
| `migrations.activeDeadlineSeconds` | `600` | Job timeout (10 minutes) |
| `migrations.ttlSecondsAfterFinished` | `600` | Job cleanup delay |

### 5. External PostgreSQL Bootstrap Job

The chart includes a bootstrap Job that creates databases, roles, and grants privileges on external PostgreSQL instances.

**Bootstrap is disabled by default:**

```yaml
global:
  externalPostgresDefinitions:
    enabled: false
```

**Enable external PostgreSQL bootstrap:**

```yaml
global:
  externalPostgresDefinitions:
    enabled: true
    connection:
      host: "my-rds.example.com"
      port: "5432"
    postgresAdminLogin:
      username: "postgres"
      password: "admin-password"
    boilerplateCredentials:
      password: "service-password"
```

> **Important:** The `boilerplateCredentials.password` must match `system-facts.secrets.POSTGRES_PASSWORD`. The bootstrap Job creates the role with this password, and the service uses it to authenticate. Prefer `useExistingSecret` to avoid duplicating the password in values.

**Using an existing secret:**

```yaml
global:
  externalPostgresDefinitions:
    enabled: true
    postgresAdminLogin:
      useExistingSecret:
        name: "postgres-admin-secret"
    boilerplateCredentials:
      useExistingSecret:
        name: "system-facts-db-secret"

system-facts:
  useExistingSecret: true
  existingSecretName: "system-facts-db-secret"
```

### 6. AWS IAM Roles Anywhere Integration

The chart supports AWS IAM Roles Anywhere for credential exchange using X.509 certificates.

**AWS integration is disabled by default:**

```yaml
aws:
  rolesAnywhere:
    enabled: false
```

**Enable IAM Roles Anywhere:**

```yaml
aws:
  rolesAnywhere:
    enabled: true
    trustAnchorArn: "arn:aws:rolesanywhere:us-east-2:123456789012:trust-anchor/abc123"
    profileArn: "arn:aws:rolesanywhere:us-east-2:123456789012:profile/def456"
    roleArn: "arn:aws:iam::123456789012:role/SystemFactsRole"
    region: "us-east-2"
    certificateSecretName: "system-facts-iam-tls"
```

> **Note:** When enabled, an `aws-signing-helper` sidecar exchanges the X.509 certificate (mounted from `certificateSecretName`) for temporary AWS credentials via IAM Roles Anywhere. Credentials are exposed to the application over a local IMDS endpoint on port 9911.

### 7. Feature Toggles

The chart includes feature toggles for optional integrations:

**Multi-tenancy:**

```yaml
system-facts:
  multiTenant:
    enabled: false

global:
  multiTenant:
    url: "http://tenant-manager:8080"
    redisHost: "my-elasticache.example.com"
```

**Service discovery (Consul):**

```yaml
system-facts:
  serviceDiscovery:
    enabled: false

global:
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"
```

**Streaming (RedPanda/Kafka):**

```yaml
system-facts:
  streaming:
    enabled: false

global:
  streaming:
    brokers: "redpanda:9092"
```

**OpenTelemetry:**

```yaml
system-facts:
  otel:
    enabled: false
    libraryName: "github.com/LerianStudio/system-facts"
    serviceName: "system-facts"

global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
```

---

## Deployment Scenarios

### Scenario 1: External Infrastructure (Production)

Production deployments should use external, managed PostgreSQL and Redis/Valkey instances.

**Configuration:**

```yaml
global:
  cloud: "aws"
  datastores:
    postgres:
      host: "my-rds.example.com"
      port: "5432"
      user: "system-facts"
      ssl: "require"
    redis:
      host: "my-elasticache.example.com"
      port: "6379"
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"

system-facts:
  enabled: true
  replicaCount: 3
  secrets:
    POSTGRES_PASSWORD: "secure-password"
    REDIS_PASSWORD: "secure-password"
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10

migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/system-facts-migrations
    tag: "1.0.0"

postgresql:
  enabled: false

valkey:
  enabled: false
```

### Scenario 2: Bundled Infrastructure (Development/Testing)

Development and testing environments can use bundled PostgreSQL and Valkey.

**Configuration:**

```yaml
system-facts:
  enabled: true
  replicaCount: 1
  autoscaling:
    enabled: false

migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/system-facts-migrations
    tag: "1.0.0"

postgresql:
  enabled: true
  auth:
    username: "system-facts"
    password: "dev-password"
    database: "system-facts"
  primary:
    persistence:
      enabled: true
      size: 8Gi

valkey:
  enabled: true
  auth:
    enabled: true
    password: "dev-password"
  master:
    persistence:
      enabled: true
      size: 8Gi
```

> **Note:** When bundled subcharts are enabled, the service automatically reads database and Redis passwords from the subchart's own Secret. No need to duplicate passwords in `system-facts.secrets`.

### Scenario 3: With Internal Facts Worker

Deploy both the System Facts API and the internal-facts-worker.

**Configuration:**

```yaml
global:
  datastores:
    postgres:
      host: "my-rds.example.com"
      user: "system-facts"
    redis:
      host: "my-elasticache.example.com"
  streaming:
    brokers: "redpanda:9092"
    tlsEnabled: true

system-facts:
  enabled: true
  secrets:
    POSTGRES_PASSWORD: "secure-password"
    REDIS_PASSWORD: "secure-password"

worker:
  enabled: true
  replicaCount: 2
  products:
    - "product-a"
    - "product-b"
  systemFacts:
    url: "http://system-facts:8080"
    authUrl: "http://plugin-access-manager-auth:4000"
  streaming:
    brokers: "redpanda:9092"
    cloudeventsSource: "internal-facts-worker"
    tlsEnabled: true
  secrets:
    STREAMING_SASL_PASSWORD: "broker-password"
    SYSTEM_FACTS_M2M_CLIENT_SECRET: "m2m-secret"
```

---

## Configuration Reference

### System Facts Service Configuration

**Core application settings:**

```yaml
system-facts:
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

**CORS configuration:**

```yaml
system-facts:
  cors:
    allowedOrigins: "*"
    allowedMethods: "GET,POST,PUT,PATCH,DELETE,OPTIONS"
    allowedHeaders: "Origin,Content-Type,Accept,Authorization,X-Request-ID"
```

**Database configuration:**

```yaml
system-facts:
  database:
    name: "system-facts"
    migrationsPath: "migrations"
    maxOpenConns: "25"
    maxIdleConns: "5"
    connMaxLifetimeMins: "30"
    connMaxIdleTimeMins: "5"
    connectTimeoutSec: "10"
```

**Redis configuration:**

```yaml
system-facts:
  redis:
    db: "0"
    protocol: "3"
    poolSize: "10"
    minIdleConns: "2"
    readTimeoutMs: "3000"
    writeTimeoutMs: "3000"
    dialTimeoutMs: "5000"
```

**Rate limiting:**

```yaml
system-facts:
  rateLimit:
    enabled: "true"
    max: "500"
    windowSec: "60"
```

**Systemplane (runtime configuration):**

```yaml
system-facts:
  systemplane:
    enabled: "false"
```

**Swagger documentation:**

```yaml
system-facts:
  swagger:
    enabled: "true"
    title: "System Facts"
```

**Secrets:**

```yaml
system-facts:
  secrets:
    POSTGRES_PASSWORD: ""
    REDIS_PASSWORD: ""
    MULTI_TENANT_SERVICE_API_KEY: ""
    MULTI_TENANT_REDIS_PASSWORD: ""
```

### Worker Configuration

**Worker deployment:**

```yaml
worker:
  enabled: false
  replicaCount: 1
  image:
    repository: ghcr.io/lerianstudio/system-facts-worker
    tag: "1.0.0"
    pullPolicy: IfNotPresent
```

**Worker products:**

```yaml
worker:
  products:
    - "product-a"
    - "product-b"
```

**System Facts connection:**

```yaml
worker:
  systemFacts:
    url: "http://system-facts:8080"
    authUrl: "http://plugin-access-manager-auth:4000"
    allowInsecureHttp: false
```

**Streaming configuration:**

```yaml
worker:
  streaming:
    brokers: "redpanda:9092"
    cloudeventsSource: "internal-facts-worker"
    tlsEnabled: true
    saslMechanism: "PLAIN"
    saslUsername: "worker"
    topicAutoProvision: false
    requireSecurity: true
```

**Multi-tenancy:**

```yaml
worker:
  multiTenant:
    enabled: false
    env: "production"
    m2mApplicationName: "internal-facts-worker"
    m2mTargetService: "system-facts"
```

**OpenTelemetry:**

```yaml
worker:
  otel:
    enabled: false
    serviceName: "internal-facts-worker"
    libraryName: "github.com/LerianStudio/system-facts/worker"
    deploymentEnvironment: "production"
    endpoint: ""
```

**Worker secrets:**

```yaml
worker:
  secrets:
    STREAMING_SASL_PASSWORD: ""
    SYSTEM_FACTS_M2M_CLIENT_SECRET: ""
    MULTI_TENANT_SERVICE_API_KEY: ""
    MULTI_TENANT_M2M_CLIENT_SECRET: ""
```

### Infrastructure Configuration

**PostgreSQL subchart:**

```yaml
postgresql:
  enabled: false
  auth:
    username: "system-facts"
    password: "changeme"
    database: "system-facts"
  primary:
    persistence:
      enabled: true
      size: 8Gi
```

**Valkey subchart:**

```yaml
valkey:
  enabled: false
  auth:
    enabled: true
    password: "changeme"
  master:
    persistence:
      enabled: true
      size: 8Gi
```

### Global Configuration

**Cloud topology preset:**

```yaml
global:
  cloud: "aws"
```

**Datastore endpoints:**

```yaml
global:
  datastores:
    postgres:
      host: "my-rds.example.com"
      port: "5432"
      user: "system-facts"
      ssl: "require"
    redis:
      host: "my-elasticache.example.com"
      port: "6379"
```

**Observability:**

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
```

**Authentication:**

```yaml
global:
  auth:
    host: "http://plugin-access-manager-auth:4000"
```

**Multi-tenancy:**

```yaml
global:
  multiTenant:
    url: "http://tenant-manager:8080"
    redisHost: "my-elasticache.example.com"
    redisPort: "6379"
    redisTls: "true"
```

**Service discovery:**

```yaml
global:
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"
    tlsSkipVerify: "false"
```

**Streaming:**

```yaml
global:
  streaming:
    brokers: "redpanda:9092"
    tlsEnabled: true
    saslMechanism: "PLAIN"
    saslUsername: "system-facts"
```

---

## Migration Steps

Since this is the initial release (v0.0.0 → v1.0.0), there is no existing deployment to migrate. Follow these steps for a new installation:

### Step 1: Prepare infrastructure

Ensure external PostgreSQL and Redis/Valkey instances are available, or plan to use bundled subcharts for development/testing.

**For external infrastructure:**

1. Create a PostgreSQL database and user
2. Create a Redis/Valkey instance
3. Note the connection endpoints (host, port, credentials)

**For bundled infrastructure:**

1. Ensure sufficient storage is available for PersistentVolumes
2. Review storage class requirements

### Step 2: Create secrets

Create a Kubernetes Secret for sensitive credentials:

```bash
kubectl create secret generic system-facts-db-secret \
  --from-literal=POSTGRES_PASSWORD='your-postgres-password' \
  --from-literal=REDIS_PASSWORD='your-redis-password' \
  -n system-facts
```

### Step 3: Prepare values file

Create a `values.yaml` file with your configuration. See [Deployment Scenarios](#deployment-scenarios) for examples.

**Minimum required values for external infrastructure:**

```yaml
global:
  datastores:
    postgres:
      host: "my-rds.example.com"
      user: "system-facts"
    redis:
      host: "my-elasticache.example.com"

system-facts:
  useExistingSecret: true
  existingSecretName: "system-facts-db-secret"

migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/system-facts-migrations
    tag: "1.0.0"
```

### Step 4: Install the chart

```bash
helm install system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.0.0 \
  --namespace system-facts \
  --create-namespace \
  --values values.yaml
```

### Step 5: Verify deployment

Check that all pods are running:

```bash
kubectl get pods -n system-facts
```

Check the service endpoint:

```bash
kubectl get svc -n system-facts
```

Check the ingress:

```bash
kubectl get ingress -n system-facts
```

### Step 6: Verify migrations

If migrations are enabled, check the Job status:

```bash
kubectl get jobs -n system-facts
kubectl logs -n system-facts job/system-facts-migrations
```

### Step 7: Test the API

Access the Swagger documentation (if ingress is configured):

```bash
curl https://system-facts.lerian.net/swagger/index.html
```

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.0.0 -n system-facts
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.0.0 -n system-facts
```
