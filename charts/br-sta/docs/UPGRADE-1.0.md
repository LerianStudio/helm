# Helm Upgrade from v0.x to v1.x

This guide helps operators upgrade the **br-sta** Helm chart from version **0.0.0** (non-existent) to **1.0.0** (initial release). This is the first production-ready release of the BACEN STA (Sistema de Transferência de Arquivos) service chart, which deploys a manager (HTTP API) and a worker (background processor) for Brazilian Central Bank file transfers.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Features](#features)**
  - [1. Multi-component architecture](#1-multi-component-architecture)
  - [2. Shared configuration model](#2-shared-configuration-model)
  - [3. Global environment contract](#3-global-environment-contract)
  - [4. Bundled infrastructure subcharts](#4-bundled-infrastructure-subcharts)
  - [5. Database migrations](#5-database-migrations)
  - [6. Streaming integration](#6-streaming-integration)
  - [7. Multi-tenancy support](#7-multi-tenancy-support)
  - [8. Mock STA server](#8-mock-sta-server)
  - [9. Observability and security](#9-observability-and-security)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: Production with external infrastructure](#scenario-1-production-with-external-infrastructure)
  - [Scenario 2: Development with bundled infrastructure](#scenario-2-development-with-bundled-infrastructure)
  - [Scenario 3: Multi-tenant SaaS deployment](#scenario-3-multi-tenant-saas-deployment)
- **[Configuration Reference](#configuration-reference)**
  - [Global configuration](#global-configuration)
  - [Common application configuration](#common-application-configuration)
  - [Manager configuration](#manager-configuration)
  - [Worker configuration](#worker-configuration)
  - [Migrations configuration](#migrations-configuration)
  - [Mock STA configuration](#mock-sta-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.0.0** is the **initial release** of the br-sta Helm chart. There is no prior version to migrate from. This guide documents the chart's architecture, configuration model, and deployment patterns for operators installing it for the first time.

| Aspect | v0.0.0 | v1.0.0 |
|--------|--------|--------|
| Chart exists | No | Yes |
| Manager component | N/A | Enabled by default |
| Worker component | N/A | Enabled by default |
| Database migrations | N/A | Pre-install/pre-upgrade hook |
| Bundled infrastructure | N/A | Optional (PostgreSQL, Valkey, RabbitMQ, SeaweedFS, Redpanda) |
| Multi-tenancy | N/A | Optional via tenant-manager integration |
| Streaming | N/A | Enabled by default (Redpanda/Kafka) |

---

## Breaking Changes

This section is not applicable for the initial release (v0.0.0 → v1.0.0). All configuration is new.

---

## Features

### 1. Multi-component architecture

The chart deploys two primary workloads:

- **Manager** (`cmd/manager`): HTTP API for transfers, credentials, and audit queries. Stateless, horizontally scalable.
- **Worker** (`cmd/worker`): Background processor for BACEN outbound scheduling, inbound polling, audit publishing, business-event delivery, and scheduled jobs. Runs as a single replica with `Recreate` strategy (no leader election).

Both components share the same application configuration (one ConfigMap, one Secret) and read identical environment variables. The worker adds a small overlay ConfigMap for worker-specific keys.

**Manager Service:**

```yaml
manager:
  enabled: true
  replicaCount: 1
  service:
    type: ClusterIP
    port: 4028
    name: ""  # Defaults to <fullname>-manager
```

**Worker Deployment:**

```yaml
worker:
  enabled: true
  replicaCount: 1  # Must be exactly 1
  deploymentUpdate:
    type: Recreate
```

> **Important:** The worker must run as exactly one replica. Setting `worker.replicaCount` to any value other than 1 will cause the chart to fail rendering.

---

### 2. Shared configuration model

Configuration is organized into three layers:

1. **`global`**: Environment-wide settings shared across all Lerian charts (datastores, object storage, auth, streaming, observability). Set once in an umbrella chart or GitOps values.
2. **`common`**: Application-specific settings shared by manager and worker (Postgres pool tuning, Redis config, RabbitMQ, transfer pipeline, audit, business events).
3. **Component-specific**: Manager and worker overrides (image tags, resources, replicas, probes).

**Configuration precedence** (highest to lowest):

1. `common.configmap.<KEY>` — Escape hatch for native environment variable keys
2. `common.<group>.<field>` — Grouped chart parameters (e.g., `common.postgres.maxOpenConns`)
3. `common.datastores` / `common.objectStorage` / `common.kms` — Release-specific connection masks
4. `global.datastores` / `global.objectStorage` / `global.kms` — Environment-wide connection masks
5. `global.cloud` preset — Managed-cloud topology defaults (`aws`, `gcp`, `azure`)
6. Chart defaults — Defined in `templates/_helpers.tpl`

**Example shared configuration:**

```yaml
common:
  postgres:
    maxOpenConns: 25
    maxIdleConns: 5
    connMaxLifetimeMins: 30
  redis:
    poolSize: 10
    minIdleConns: 2
  transfer:
    schedulerEnabled: true
    maxFileSizeBytes: 104857600  # 100 MB
    pollIntervalSeconds: 300
```

---

### 3. Global environment contract

The `global` block defines environment-wide infrastructure and service endpoints. These values are typically set once per environment (dev, staging, production) in an umbrella chart.

**Key global blocks:**

| Block | Purpose | Example Keys |
|-------|---------|--------------|
| `global.datastores` | Postgres, Redis, RabbitMQ connection identity | `postgres.host`, `redis.host`, `broker.host` |
| `global.objectStorage` | S3-compatible storage for transfers and audit exports | `sta.endpoint`, `sta.bucket`, `staAuditExports.bucket` |
| `global.kms` | Envelope encryption master key provider | `vendor`, `keyId`, `awsRegion` |
| `global.streaming` | Redpanda/Kafka brokers for business events | `enabled`, `brokers`, `tlsEnabled`, `saslMechanism` |
| `global.auth` | Plugin-access-manager integration | `enabled`, `host` |
| `global.multiTenant` | Tenant-manager integration | `enabled`, `url`, `redisHost` |
| `global.observability` | OpenTelemetry configuration | `enabled`, `otlpEndpoint` |
| `global.env` | Environment classification | `name` (e.g., `production`, `development`) |

**Example global configuration:**

```yaml
global:
  cloud: "aws"
  env:
    name: "production"
  datastores:
    postgres:
      host: "postgresql.internal"
      user: "br_sta"
      name: "br_sta"
      ssl: "require"
    redis:
      host: "valkey.internal:6379"
      tls: "true"
    broker:
      host: "rabbitmq.internal"
      amqpPort: "5671"
      user: "br_sta"
      scheme: "amqps"
  objectStorage:
    sta:
      endpoint: "https://s3.sa-east-1.amazonaws.com"
      region: "sa-east-1"
      bucket: "br-sta-transfer"
    staAuditExports:
      bucket: "br-sta-audit-exports"
  streaming:
    enabled: true
    brokers: "redpanda.internal:9093"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "br-sta"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000"
  observability:
    enabled: true
    otlpEndpoint: "http://otel-collector:4317"
```

> **Note:** The `global.cloud` preset (`aws`, `gcp`, `azure`) automatically sets TLS/SSL defaults for managed cloud services. For self-managed infrastructure, leave `global.cloud` empty and set TLS flags explicitly.

---

### 4. Bundled infrastructure subcharts

The chart declares five infrastructure subcharts for development and evaluation. All are **disabled by default** and should remain disabled in production.

| Subchart | Condition | Purpose | Production Use |
|----------|-----------|---------|----------------|
| `postgresql` (Bitnami) | `postgresql.enabled` | Single-replica Postgres | ❌ Use managed RDS/CloudSQL |
| `valkey` (Bitnami) | `valkey.enabled` | Single-replica Redis-compatible cache | ❌ Use managed ElastiCache/Memorystore |
| `rabbitmq` (groundhog2k) | `rabbitmq.enabled` | Single-replica message broker | ❌ Use managed AmazonMQ/CloudAMQP |
| `seaweedfs` | `seaweedfs.enabled` | S3-compatible object storage | ❌ Use S3/GCS/Azure Blob |
| `redpanda` | `redpandaBundle.enabled` | Kafka-compatible streaming broker | ❌ Use managed MSK/Confluent Cloud |

**Development bundle example:**

```yaml
global:
  env:
    name: "development"
  cloud: ""  # No cloud preset for local infra

postgresql:
  enabled: true
  auth:
    username: "br_sta"
    password: "dev-password"
    database: "br_sta"

valkey:
  enabled: true
  auth:
    enabled: true
    password: "dev-password"

rabbitmq:
  enabled: true
  auth:
    username: "br_sta"
    password: "dev-password"

seaweedfs:
  enabled: true

redpandaBundle:
  enabled: true
```

> **Warning:** The chart refuses bundled infrastructure in production-like environments. If `global.env.name` is `production` (or unset, defaulting to `production`), enabling any bundled subchart will cause the render to fail with an error message.

---

### 5. Database migrations

The chart includes a `migrations` Job that applies the SQL schema to Postgres. It runs as a Helm hook (`pre-install`, `pre-upgrade`) or an ArgoCD `PreSync` hook, ensuring the database is ready before the application boots.

**Migrations configuration:**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/br-sta-migrations
    tag: ""  # Defaults to Chart.appVersion
  hookWeight: "-5"
  hookDeletePolicy: "before-hook-creation"
  backoffLimit: 3
  activeDeadlineSeconds: 600
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
```

| Flag | Default | Description |
|------|---------|-------------|
| `migrations.enabled` | `true` | Whether to render the migrations Job |
| `migrations.hookWeight` | `"-5"` | Helm hook weight (runs before weight 0) |
| `migrations.hookDeletePolicy` | `"before-hook-creation"` | Deletes previous Job before creating a new one |
| `migrations.backoffLimit` | `3` | Number of retries on failure |
| `migrations.activeDeadlineSeconds` | `600` | Job timeout (10 minutes) |
| `migrations.useExistingSecret` | `false` | Use a custom Secret for `POSTGRES_PASSWORD` |

> **Important:** In multi-tenant mode (`global.multiTenant.enabled: true`), the migrations Job is **not rendered**. Tenant schemas are provisioned through the tenant-manager service, not this chart.

**Disabling migrations:**

```yaml
migrations:
  enabled: false
```

When disabled, operators must apply the schema manually or through an external tool before the first install.

---

### 6. Streaming integration

The chart integrates with Redpanda or Kafka for business-event streaming. The worker publishes business facts to the `lerian.streaming.br-sta` topic (plus `.dlq` for dead letters), which `br-sisbajud` consumes.

**Streaming is enabled by default** (`global.streaming.enabled: true`). When enabled, the `global.streaming.brokers` field is **required**.

**Streaming configuration:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda.internal:9093"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "br-sta"
    compression: "snappy"
    requiredAcks: "all"
    topicAutoProvision: true

common:
  secrets:
    STREAMING_SASL_PASSWORD: "<path:secret/data/br-sta#STREAMING_SASL_PASSWORD>"
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.streaming.enabled` | `true` | Enable streaming integration |
| `global.streaming.brokers` | (required) | Comma-separated broker list (e.g., `host:9093`) |
| `global.streaming.tlsEnabled` | `false` (or `true` if `global.cloud` is set) | Enable TLS for broker connections |
| `global.streaming.saslMechanism` | `""` | SASL mechanism (`PLAIN`, `SCRAM-SHA-256`, `SCRAM-SHA-512`) |
| `global.streaming.topicAutoProvision` | `true` | Auto-create topics at boot if principal has `CreateTopics` |

**Topic auto-provisioning:**

- When `topicAutoProvision: true` (default), both manager and worker create the two topics at boot if they don't exist. A denied create is logged as a warning, not a boot failure.
- When `topicAutoProvision: false`, the topics **must exist** on the broker before the first boot. Provision them via IaC or the broker's admin tools.

**Disabling streaming:**

```yaml
global:
  streaming:
    enabled: false
```

> **Warning:** Business facts produced while streaming is disabled are **never re-sent**. Disable streaming only for initial installs without a broker; enable it before processing real transfers.

---

### 7. Multi-tenancy support

The chart supports multi-tenant deployments via integration with the `tenant-manager` service. When enabled, the application reads tenant-specific database credentials from a shared Redis cache and connects to per-tenant Postgres schemas.

**Multi-tenancy configuration:**

```yaml
global:
  multiTenant:
    enabled: true
    url: "http://tenant-manager:4026"
    redisHost: "valkey.internal"
    redisPort: "6379"
    redisTls: "true"

common:
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "<path:secret/data/br-sta#MULTI_TENANT_SERVICE_API_KEY>"
    MULTI_TENANT_REDIS_PASSWORD: "<path:secret/data/br-sta#MULTI_TENANT_REDIS_PASSWORD>"
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.multiTenant.enabled` | `false` | Enable multi-tenant mode |
| `global.multiTenant.url` | (required when enabled) | Tenant-manager API URL |
| `global.multiTenant.redisHost` | (required when enabled) | Redis host for tenant credential cache |
| `global.multiTenant.redisPort` | `"6379"` | Redis port |
| `global.multiTenant.redisTls` | `"false"` | Enable TLS for Redis connections |

> **Important:** When multi-tenancy is enabled, the migrations Job is **not rendered**. Tenant schemas are provisioned through the tenant-manager, not this chart.

---

### 8. Mock STA server

The chart includes an optional mock STA server for development and testing. When enabled, the STA client redirects to the mock instead of the real BACEN endpoints.

**Mock STA configuration:**

```yaml
mockSta:
  enabled: true
  replicaCount: 1
  image:
    repository: ghcr.io/lerianstudio/br-sta-mock-sta
    tag: ""  # Defaults to Chart.appVersion
  service:
    type: ClusterIP
    filePort: 8080
    passwordPort: 8081
```

| Flag | Default | Description |
|------|---------|-------------|
| `mockSta.enabled` | `false` | Enable the mock STA server |
| `mockSta.service.filePort` | `8080` | Port for file transfer endpoints |
| `mockSta.service.passwordPort` | `8081` | Port for password endpoints |

When `mockSta.enabled: true`, the chart automatically sets the STA client redirect environment variables:

- `STA_FILE_HOST` → `http://<mock-service>.<namespace>.svc.cluster.local:8080`
- `STA_PASSWORD_HOST` → `http://<mock-service>.<namespace>.svc.cluster.local:8081`
- `STA_SCHEME` → `http`

> **Warning:** The mock STA server is for **development and testing only**. It does not connect to BACEN. Disable it in production.

---

### 9. Observability and security

**Observability:**

The chart integrates with OpenTelemetry for distributed tracing and metrics. When enabled, the application exports telemetry to an OTLP endpoint.

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "http://otel-collector:4317"
    deploymentEnvironment: "production"
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.observability.enabled` | `false` | Enable OpenTelemetry |
| `global.observability.otlpEndpoint` | `"http://$(HOST_IP):4317"` | OTLP gRPC endpoint (defaults to node-local collector) |
| `global.observability.deploymentEnvironment` | (from `global.env.name`) | Value for `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` |

**Security:**

The chart enforces security best practices:

- **Container security context**: Runs as non-root user (UID/GID 65532), read-only root filesystem, drops all capabilities.
- **TLS enforcement**: In `deploymentMode: saas`, the application refuses non-TLS connections to Postgres, Redis, RabbitMQ, S3, and the broker.
- **Auth requirement**: `PLUGIN_AUTH_ENABLED` defaults to `true` in production-class environments. The application refuses `PLUGIN_AUTH_ENABLED=false` unless `global.env.name` is `development`, `develop`, `dev`, `local`, or `test`.

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
  seccompProfile:
    type: RuntimeDefault
```

---

## Deployment Scenarios

### Scenario 1: Production with external infrastructure

**Requirements:**
- Managed PostgreSQL (RDS, CloudSQL, Azure Database)
- Managed Redis (ElastiCache, Memorystore)
- Managed RabbitMQ (AmazonMQ, CloudAMQP)
- S3-compatible object storage (S3, GCS, Azure Blob)
- Managed Kafka/Redpanda (MSK, Confluent Cloud)
- Plugin-access-manager for authentication
- License key and organization IDs

**values.yaml:**

```yaml
global:
  cloud: "aws"
  env:
    name: "production"
  datastores:
    postgres:
      host: "br-sta-db.cluster-xyz.sa-east-1.rds.amazonaws.com"
      user: "br_sta"
      name: "br_sta"
      ssl: "require"
    redis:
      host: "br-sta-cache.abc123.0001.sae1.cache.amazonaws.com:6379"
      tls: "true"
    broker:
      host: "b-xyz.mq.sa-east-1.amazonaws.com"
      amqpPort: "5671"
      user: "br_sta"
      scheme: "amqps"
  objectStorage:
    sta:
      endpoint: "https://s3.sa-east-1.amazonaws.com"
      region: "sa-east-1"
      bucket: "br-sta-transfer-prod"
    staAuditExports:
      bucket: "br-sta-audit-exports-prod"
  streaming:
    enabled: true
    brokers: "b-1.prod-cluster.xyz.kafka.sa-east-1.amazonaws.com:9096"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "br-sta"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000"
  observability:
    enabled: true
    otlpEndpoint: "http://otel-collector.observability.svc.cluster.local:4317"

common:
  app:
    deploymentMode: "byoc"
    logLevel: "info"
  cors:
    allowedOrigins: "https://app.example.com,https://admin.example.com"
  license:
    organizationIds: "org-123,org-456"
  secrets:
    POSTGRES_PASSWORD: "<path:secret/data/br-sta#POSTGRES_PASSWORD>"
    REDIS_PASSWORD: "<path:secret/data/br-sta#REDIS_PASSWORD>"
    RABBITMQ_DEFAULT_PASS: "<path:secret/data/br-sta#RABBITMQ_DEFAULT_PASS>"
    AWS_ACCESS_KEY_ID: "<path:secret/data/br-sta#AWS_ACCESS_KEY_ID>"
    AWS_SECRET_ACCESS_KEY: "<path:secret/data/br-sta#AWS_SECRET_ACCESS_KEY>"
    MASTER_KEYS: "<path:secret/data/br-sta#MASTER_KEYS>"
    LICENSE_KEY: "<path:secret/data/br-sta#LICENSE_KEY>"
    STREAMING_SASL_PASSWORD: "<path:secret/data/br-sta#STREAMING_SASL_PASSWORD>"

manager:
  replicaCount: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 2000m
      memory: 1Gi
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - host: "br-sta-api.example.com"
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: br-sta-tls
        hosts:
          - br-sta-api.example.com

worker:
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 2000m
      memory: 1Gi

postgresql:
  enabled: false

valkey:
  enabled: false

rabbitmq:
  enabled: false

seaweedfs:
  enabled: false

redpandaBundle:
  enabled: false
```

---

### Scenario 2: Development with bundled infrastructure

**Requirements:**
- Local Kubernetes cluster (kind, minikube, Docker Desktop)
- No external dependencies

**values.yaml:**

```yaml
global:
  env:
    name: "development"
  cloud: ""
  auth:
    enabled: false
  streaming:
    enabled: true
    brokers: "br-sta-redpanda.br-sta.svc.cluster.local:9093"
    tlsEnabled: false
    topicAutoProvision: true
  observability:
    enabled: false

common:
  app:
    deploymentMode: "local"
    logLevel: "debug"
  cors:
    allowedOrigins: "*"
  license:
    organizationIds: "dev-org"
  secrets:
    LICENSE_KEY: "dev-license-key-placeholder"
    MASTER_KEYS: "0000000000000000000000000000000000000000000000000000000000000000"

postgresql:
  enabled: true
  auth:
    username: "br_sta"
    password: "dev-password"
    database: "br_sta"

valkey:
  enabled: true
  auth:
    enabled: true
    password: "dev-password"

rabbitmq:
  enabled: true
  auth:
    username: "br_sta"
    password: "dev-password"

seaweedfs:
  enabled: true

redpandaBundle:
  enabled: true

mockSta:
  enabled: true

manager:
  replicaCount: 1
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

worker:
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
```

> **Note:** This configuration is for **local development only**. All bundled subcharts use plaintext connections and single replicas. Do not use in production.

---

### Scenario 3: Multi-tenant SaaS deployment

**Requirements:**
- Tenant-manager service deployed
- Shared Redis for tenant credential cache
- Managed infrastructure (same as Scenario 1)
- SaaS deployment mode (enforces TLS for all dependencies)

**values.yaml:**

```yaml
global:
  cloud: "aws"
  env:
    name: "production"
  datastores:
    postgres:
      host: "br-sta-db.cluster-xyz.sa-east-1.rds.amazonaws.com"
      user: "br_sta"
      name: "br_sta"
      ssl: "require"
    redis:
      host: "br-sta-cache.abc123.0001.sae1.cache.amazonaws.com:6379"
      tls: "true"
    broker:
      host: "b-xyz.mq.sa-east-1.amazonaws.com"
      amqpPort: "5671"
      user: "br_sta"
      scheme: "amqps"
  objectStorage:
    sta:
      endpoint: "https://s3.sa-east-1.amazonaws.com"
      region: "sa-east-1"
      bucket: "br-sta-transfer-saas"
    staAuditExports:
      bucket: "br-sta-audit-exports-saas"
  streaming:
    enabled: true
    brokers: "b-1.saas-cluster.xyz.kafka.sa-east-1.amazonaws.com:9096"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "br-sta"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000"
  multiTenant:
    enabled: true
    url: "http://tenant-manager.tenant-manager.svc.cluster.local:4026"
    redisHost: "tenant-cache.abc123.0001.sae1.cache.amazonaws.com"
    redisPort: "6379"
    redisTls: "true"
  observability:
    enabled: true

common:
  app:
    deploymentMode: "saas"
    logLevel: "info"
  cors:
    allowedOrigins: "https://saas.example.com"
  license:
    organizationIds: "saas-org-123"
  secrets:
    POSTGRES_PASSWORD: "<path:secret/data/br-sta#POSTGRES_PASSWORD>"
    REDIS_PASSWORD: "<path:secret/data/br-sta#REDIS_PASSWORD>"
    RABBITMQ_DEFAULT_PASS: "<path:secret/data/br-sta#RABBITMQ_DEFAULT_PASS>"
    AWS_ACCESS_KEY_ID: "<path:secret/data/br-sta#AWS_ACCESS_KEY_ID>"
    AWS_SECRET_ACCESS_KEY: "<path:secret/data/br-sta#AWS_SECRET_ACCESS_KEY>"
    MASTER_KEYS: "<path:secret/data/br-sta#MASTER_KEYS>"
    LICENSE_KEY: "<path:secret/data/br-sta#LICENSE_KEY>"
    STREAMING_SASL_PASSWORD: "<path:secret/data/br-sta#STREAMING_SASL_PASSWORD>"
    MULTI_TENANT_SERVICE_API_KEY: "<path:secret/data/br-sta#MULTI_TENANT_SERVICE_API_KEY>"
    MULTI_TENANT_REDIS_PASSWORD: "<path:secret/data/br-sta#MULTI_TENANT_REDIS_PASSWORD>"

migrations:
  enabled: false  # Tenant schemas provisioned by tenant-manager

manager:
  replicaCount: 5
  autoscaling:
    enabled: true
    minReplicas: 5
    maxReplicas: 20

worker:
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 4000m
      memory: 2Gi

postgresql:
  enabled: false

valkey:
  enabled: false

rabbitmq:
  enabled: false

seaweedfs:
  enabled: false

redpandaBundle:
  enabled: false
```

> **Important:** In `deploymentMode: saas`, the application **refuses** any non-TLS connection to Postgres, Redis, RabbitMQ, S3, or the streaming broker. All `global.datastores` and `global.objectStorage` endpoints must use TLS.

---

## Configuration Reference

### Global configuration

**`global.cloud`** (string, default: `""`):
Managed-cloud topology preset. Sets TLS/SSL defaults for datastores and object storage.

- `"aws"`: `POSTGRES_SSLMODE=require`, `REDIS_TLS=true`, `RABBITMQ_SCHEME=amqps` (port 5671)
- `"gcp"`: Same as AWS
- `"azure"`: Same as AWS
- `""`: No preset (self-managed infrastructure)

**`global.env.name`** (string, default: `"production"`):
Environment classification. Maps to `ENV_NAME` and `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`.

- `"production"`: Production gates enabled (TLS required, license required, bundled infra refused)
- `"development"`, `"develop"`, `"dev"`, `"local"`, `"test"`: Development class (allows `PLUGIN_AUTH_ENABLED=false`, bundled infra)

**`global.datastores`** (object):
