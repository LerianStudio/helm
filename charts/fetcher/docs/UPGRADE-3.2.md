# Helm Upgrade from v3.1.4 to v3.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. lerian-common-helm dependency integration](#1-lerian-common-helm-dependency-integration)
  - [2. Environment-wide configuration masks](#2-environment-wide-configuration-masks)
  - [3. Pod topology spread constraints](#3-pod-topology-spread-constraints)
  - [4. Service mesh native sidecar support](#4-service-mesh-native-sidecar-support)
  - [5. Shared secrets support](#5-shared-secrets-support)
  - [6. Streaming configuration for worker](#6-streaming-configuration-for-worker)
  - [7. Object storage configuration mask](#7-object-storage-configuration-mask)
  - [8. Auth plugin configuration via global mask](#8-auth-plugin-configuration-via-global-mask)
- **[Configuration Reference](#configuration-reference)**
  - [Global configuration blocks](#global-configuration-blocks)
  - [Dedicated datastore masks](#dedicated-datastore-masks)
  - [Component-level spread overrides](#component-level-spread-overrides)
  - [New worker environment variables](#new-worker-environment-variables)
  - [Common configmap changes](#common-configmap-changes)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review dependency update](#step-1-review-dependency-update)
  - [Step 2: Configure streaming for worker](#step-2-configure-streaming-for-worker)
  - [Step 3: Migrate datastore configuration (optional)](#step-3-migrate-datastore-configuration-optional)
  - [Step 4: Review topology spread constraints (optional)](#step-4-review-topology-spread-constraints-optional)
  - [Step 5: Validate service mesh annotations (optional)](#step-5-validate-service-mesh-annotations-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.1.4` to `3.2.0`. This is a **minor** release that introduces a new dependency (`lerian-common-helm` v2.2.0) and refactors configuration management to support environment-wide shared settings, typed datastore masks, and pod topology spread constraints.

The application version (`appVersion: 3.1.0`) is unchanged. No breaking changes are introduced, but operators must configure streaming settings for the worker component before upgrading, as the worker now hard-requires a reachable Kafka/Redpanda broker at startup.

> **Warning:** The worker component will not boot without a valid `STREAMING_BROKERS` configuration. You must set either `global.streaming.brokers` or `worker.configmap.STREAMING_BROKERS` before upgrading if you are deploying the worker.

## Features

### 1. lerian-common-helm dependency integration

The chart now depends on `lerian-common-helm` v2.2.0, which provides reusable templates for datastore connections, observability, multi-tenancy, and scheduling. This dependency is pulled from `oci://ghcr.io/lerianstudio`.

**Chart.yaml change:**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.2.0"
    repository: "oci://ghcr.io/lerianstudio"
  - name: keda
    version: "2.17.1"
    repository: "https://kedacore.github.io/charts"
```

> **Note:** Helm will automatically download the `lerian-common-helm` dependency during upgrade. No manual action is required.

### 2. Environment-wide configuration masks

The chart now supports environment-wide shared configuration blocks under `global`, allowing operators to set datastore endpoints, observability settings, and other infrastructure details once per environment instead of duplicating them across multiple charts.

**New global configuration blocks:**

| Block | Purpose | Example |
|-------|---------|---------|
| `global.cloud` | Managed-cloud topology preset (aws, gcp, azure) | `cloud: "aws"` |
| `global.datastores` | Shared datastore endpoints (mongo, redis, broker) | `datastores: { mongo: { host: "documentdb.example.com" } }` |
| `global.objectStorage` | S3/SeaweedFS configuration | `objectStorage: { fetcher: { endpoint: "https://s3.us-east-1.amazonaws.com" } }` |
| `global.observability` | OTLP endpoint and deployment environment | `observability: { enabled: true, otlpEndpoint: "otel-collector:4317" }` |
| `global.auth` | Access-manager plugin configuration | `auth: { enabled: true, host: "http://plugin-access-manager-auth:4000" }` |
| `global.streaming` | Kafka/Redpanda broker configuration | `streaming: { enabled: true, brokers: "redpanda:9092" }` |
| `global.multiTenant` | Multi-tenant infrastructure settings | `multiTenant: { enabled: true, url: "http://tenant-manager:8080" }` |
| `global.scheduling` | Pod topology spread constraints preset | `scheduling: { spread: { enabled: true, hostname: "ScheduleAnyway" } }` |

**Example configuration:**

```yaml
global:
  cloud: "aws"
  datastores:
    mongo:
      host: "my-documentdb.example.com"
      port: "27017"
    redis:
      host: "my-elasticache.example.com"
      port: "6379"
      tls: "true"
    broker:
      host: "my-amazonmq.example.com"
      scheme: "amqps"
      amqpPort: "5671"
  objectStorage:
    fetcher:
      endpoint: "https://s3.us-east-1.amazonaws.com"
      region: "us-east-1"
      bucket: "my-bucket"
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth:4000"
  streaming:
    enabled: true
    brokers: "redpanda:9092"
  multiTenant:
    enabled: true
    url: "http://tenant-manager:8080"
```

> **Note:** These global settings provide defaults that can be overridden at the chart level via `datastores` (dedicated masks) or component level via `common.configmap.<KEY>` or `manager.configmap.<KEY>` / `worker.configmap.<KEY>`.

### 3. Pod topology spread constraints

Both `manager` and `worker` Deployments now support pod topology spread constraints via a preset system controlled by `global.scheduling.spread`. This allows operators to configure pod distribution across nodes and availability zones.

**Default configuration:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ""
      maxSkew: 1
```

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `true` | Master switch for the spread preset |
| `hostname` | `ScheduleAnyway` | Spread across nodes (kubernetes.io/hostname): `ScheduleAnyway` (soft), `DoNotSchedule` (hard), or `""` (off) |
| `zone` | `""` | Spread across zones (topology.kubernetes.io/zone): `ScheduleAnyway`, `DoNotSchedule`, or `""` (off) |
| `maxSkew` | `1` | Max allowed pod-count difference between topology domains (integer >= 1) |

**Per-component override:**

```yaml
manager:
  spread:
    hostname: DoNotSchedule
    maxSkew: 2

worker:
  spread:
    hostname: ScheduleAnyway
    zone: ScheduleAnyway
```

**Raw topologySpreadConstraints:**

```yaml
manager:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: fetcher
          app.kubernetes.io/component: manager
```

> **Note:** The `zone` spread is disabled by default because clusters without zone labels (bare-metal, k3s) silently cancel the hostname spread when a soft zone constraint is present. Enable it only on managed clouds (EKS, GKE, AKS) where every node has zone labels.

### 4. Service mesh native sidecar support

Bootstrap Jobs (`bootstrap-mongodb` and `bootstrap-rabbitmq`) now include annotations for Istio and Linkerd native sidecar mode, ensuring Jobs complete successfully when a service mesh is enabled.

**Before (v3.1.4):**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: fetcher-bootstrap-mongodb
spec:
  template:
    spec:
      restartPolicy: Never
```

**After (v3.2.0):**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: fetcher-bootstrap-mongodb
spec:
  template:
    metadata:
      annotations:
        sidecar.istio.io/nativeSidecar: "true"
        config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"
    spec:
      restartPolicy: Never
```

> **Note:** These annotations prevent the mesh proxy from blocking Job completion. No operator action is required unless you have custom mesh configuration that conflicts with native sidecar mode.

### 5. Shared secrets support

A new `common` Secret (`fetcher-common`) is now created to hold shared credentials (e.g., `MONGO_USER`, `MONGO_PASSWORD`, `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS`) that are used by both manager and worker. Component-specific secrets still override shared values.

**Secret precedence (highest to lowest):**

1. Component-specific secret (`fetcher-manager` or `fetcher-worker`)
2. Component-specific `existingSecret`
3. Shared `common` secret (`fetcher-common`)

**Example configuration:**

```yaml
secrets:
  MONGO_USER: "fetcher"
  MONGO_PASSWORD: "secure-password"
  RABBITMQ_DEFAULT_USER: "plugin"
  RABBITMQ_DEFAULT_PASS: "secure-rabbitmq-password"

manager:
  secrets:
    APP_ENC_KEY: "manager-specific-key"

worker:
  secrets:
    APP_ENC_KEY: "worker-specific-key"
```

> **Note:** Empty keys in `secrets` are skipped, so an unset shared value never masks the application default. Component secrets are loaded after the shared secret, so they always win on duplicate keys.

### 6. Streaming configuration for worker

The worker component now hard-requires streaming (Kafka/Redpanda) configuration at startup for mandatory job event notifications. The worker will not boot without a reachable broker.

**New worker environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAMING_CLOUDEVENTS_SOURCE` | `"fetcher"` | CloudEvents source identifier (must be "fetcher") |
| `STREAMING_ENABLED` | (from `global.streaming.enabled`) | Enable streaming integration |
| `STREAMING_BROKERS` | (from `global.streaming.brokers`) | Kafka/Redpanda bootstrap servers (e.g., "redpanda:9092") |
| `STREAMING_TLS_ENABLED` | (from `global.streaming.tlsEnabled`) | Enable TLS for broker connections |
| `STREAMING_SASL_MECHANISM` | (from `global.streaming.saslMechanism`) | SASL mechanism (PLAIN, SCRAM-SHA-256, SCRAM-SHA-512) |
| `STREAMING_SASL_USERNAME` | (from `global.streaming.saslUsername`) | SASL username |

**New worker secrets:**

| Secret | Description |
|--------|-------------|
| `STREAMING_SASL_PASSWORD` | SASL password (only needed when `STREAMING_SASL_MECHANISM` is set) |
| `STREAMING_TLS_CA_CERT` | TLS CA certificate (only needed when `STREAMING_TLS_ENABLED` is true) |

**Example configuration:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda.messaging:9092"
    tlsEnabled: false
    saslMechanism: ""

worker:
  secrets:
    STREAMING_SASL_PASSWORD: ""
    STREAMING_TLS_CA_CERT: ""
```

> **Warning:** The worker refuses to boot unless `STREAMING_BROKERS` is set to a real Kafka/Redpanda bootstrap address. Set it via `global.streaming.brokers` or `worker.configmap.STREAMING_BROKERS` before installing with the bundled worker.

> **Important:** The worker refuses to boot unless `STREAMING_CLOUDEVENTS_SOURCE` is "fetcher". The broker topics and ACLs are provisioned for that name only. Do not change this value.

### 7. Object storage configuration mask

The worker's object storage configuration (S3/SeaweedFS) is now managed via `global.objectStorage.fetcher` instead of individual `worker.configmap.OBJECT_STORAGE_*` keys.

**Before (v3.1.4):**

```yaml
worker:
  configmap:
    STORAGE_PROVIDER: "seaweedfs"
    OBJECT_STORAGE_ENDPOINT: ""
    OBJECT_STORAGE_REGION: "us-east-1"
    OBJECT_STORAGE_BUCKET: "external-data"
    OBJECT_STORAGE_KEY_PREFIX: ""
    OBJECT_STORAGE_USE_PATH_STYLE: "false"
```

**After (v3.2.0):**

```yaml
global:
  objectStorage:
    fetcher:
      endpoint: "https://s3.us-east-1.amazonaws.com"
      region: "us-east-1"
      bucket: "my-bucket"

worker:
  configmap:
    STORAGE_PROVIDER: "seaweedfs"
    OBJECT_STORAGE_KEY_PREFIX: ""
```

| Setting | v3.1.4 | v3.2.0 |
|---------|--------|--------|
| `worker.configmap.OBJECT_STORAGE_ENDPOINT` | `""` (empty) | (removed, use `global.objectStorage.fetcher.endpoint`) |
| `worker.configmap.OBJECT_STORAGE_REGION` | `"us-east-1"` | (removed, use `global.objectStorage.fetcher.region`) |
| `worker.configmap.OBJECT_STORAGE_BUCKET` | `"external-data"` | (removed, use `global.objectStorage.fetcher.bucket`) |
| `worker.configmap.OBJECT_STORAGE_USE_PATH_STYLE` | `"false"` | (removed, use `global.objectStorage.fetcher.pathStyle`) |

> **Note:** The native `worker.configmap.OBJECT_STORAGE_*` keys still override the global mask if set explicitly. This provides backwards compatibility for existing installations.

### 8. Auth plugin configuration via global mask

The manager's auth plugin configuration (`PLUGIN_AUTH_ENABLED` and `PLUGIN_AUTH_ADDRESS`) is now managed via `global.auth` instead of individual `manager.configmap` keys.

**Before (v3.1.4):**

```yaml
manager:
  configmap:
    PLUGIN_AUTH_ENABLED: "false"
    PLUGIN_AUTH_ADDRESS: ""
```

**After (v3.2.0):**

```yaml
global:
  auth:
    enabled: false
    host: ""

# Or override at component level:
manager:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth:4000"
```

| Setting | v3.1.4 | v3.2.0 |
|---------|--------|--------|
| `manager.configmap.PLUGIN_AUTH_ENABLED` | `"false"` | (emitted by `lerian-common.auth.env`, defaults to `global.auth.enabled`) |
| `manager.configmap.PLUGIN_AUTH_ADDRESS` | `""` | (emitted by `lerian-common.auth.env`, defaults to `global.auth.host`) |

> **Note:** The native `manager.configmap.PLUGIN_AUTH_*` keys still override the global mask if set explicitly. Legacy `manager.extraEnvVars.PLUGIN_AUTH_*` values are also migrated to the mask automatically.

## Configuration Reference

### Global configuration blocks

The following global configuration blocks are now available:

#### global.cloud

Sets managed-cloud topology presets (TLS, scheme, ports, object storage path-style) for all datastore and object storage connections.

| Value | Description |
|-------|-------------|
| `""` | Bundled in-cluster infrastructure (plaintext, no TLS) |
| `"aws"` | AWS managed services (DocumentDB, ElastiCache, AmazonMQ, S3) |
| `"gcp"` | GCP managed services (Cloud SQL, Memorystore, Cloud Pub/Sub, GCS) |
| `"azure"` | Azure managed services (Cosmos DB, Azure Cache for Redis, Service Bus, Blob Storage) |

**Example:**

```yaml
global:
  cloud: "aws"
```

#### global.datastores

Shared datastore endpoints for MongoDB, Redis, and RabbitMQ. Sub-keys: `mongo`, `redis`, `broker`.

**Example:**

```yaml
global:
  datastores:
    mongo:
      host: "my-documentdb.example.com"
      port: "27017"
      params: "retryWrites=false&tls=true"
    redis:
      host: "my-elasticache.example.com"
      port: "6379"
      tls: "true"
    broker:
      host: "my-amazonmq.example.com"
      scheme: "amqps"
      amqpPort: "5671"
      port: "443"
```

#### global.objectStorage

Object storage (S3/SeaweedFS) configuration for the worker's extraction output bucket. Sub-key: `fetcher`.

**Example:**

```yaml
global:
  objectStorage:
    fetcher:
      endpoint: "https://s3.us-east-1.amazonaws.com"
      region: "us-east-1"
      bucket: "my-bucket"
      pathStyle: "false"
```

#### global.observability

Observability settings (OTLP endpoint, deployment environment).

**Example:**

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
```

#### global.auth

Access-manager plugin configuration.

**Example:**

```yaml
global:
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth:4000"
```

#### global.streaming

Kafka/Redpanda streaming configuration.

**Example:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda:9092"
    tlsEnabled: false
    saslMechanism: ""
    saslUsername: ""
    compression: "snappy"
    requiredAcks: "1"
```

#### global.multiTenant

Multi-tenant infrastructure configuration.

**Example:**

```yaml
global:
  multiTenant:
    enabled: true
    url: "http://tenant-manager:8080"
```

#### global.scheduling

Pod topology spread constraints preset.

**Example:**

```yaml
global:
  scheduling:
    spread:
      enabled: true
      hostname: ScheduleAnyway
      zone: ""
      maxSkew: 1
```

### Dedicated datastore masks

The chart-level `datastores` block allows per-release overrides of `global.datastores`.

**Example:**

```yaml
datastores:
  mongo:
    host: "fetcher-specific-mongodb"
    port: "27017"
  redis:
    host: "fetcher-specific-redis"
    port: "6379"
  broker:
    host: "fetcher-specific-rabbitmq"
    scheme: "amqp"
    amqpPort: "5672"
    port: "15672"
```

> **Note:** Native `common.configmap.<KEY>` values still win over both `datastores` and `global.datastores`.

### Component-level spread overrides

Both `manager` and `worker` support per-component overrides of `global.scheduling.spread`.

**Example:**

```yaml
manager:
  spread:
    hostname: DoNotSchedule
    maxSkew: 2

worker:
  spread:
    hostname: ScheduleAnyway
    zone: ScheduleAnyway
```

**Raw topologySpreadConstraints:**

```yaml
manager:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
```

> **Note:** Non-empty `topologySpreadConstraints` replaces the spread preset entirely. An entry without `labelSelector` gets the component's selector labels automatically.

### New worker environment variables

The following environment variables are now emitted by the worker ConfigMap:

| Variable | Source | Default | Description |
|----------|--------|---------|-------------|
| `STREAMING_CLOUDEVENTS_SOURCE` | `worker.configmap` | `"fetcher"` | CloudEvents source identifier (must be "fetcher") |
| `STREAMING_ENABLED` | `global.streaming.enabled` | (none) | Enable streaming integration |
| `STREAMING_BROKERS` | `global.streaming.brokers` | (none) | Kafka/Redpanda bootstrap servers |
| `STREAMING_TLS_ENABLED` | `global.streaming.tlsEnabled` | (none) | Enable TLS for broker connections |
| `STREAMING_SASL_MECHANISM` | `global.streaming.saslMechanism` | (none) | SASL mechanism |
| `STREAMING_SASL_USERNAME` | `global.streaming.saslUsername` | (none) | SASL username |
| `OBJECT_STORAGE_ENDPOINT` | `global.objectStorage.fetcher.endpoint` | (none) | S3/SeaweedFS endpoint |
| `OBJECT_STORAGE_REGION` | `global.objectStorage.fetcher.region` | (none) | S3 region |
| `OBJECT_STORAGE_BUCKET` | `global.objectStorage.fetcher.bucket` | (none) | S3 bucket name |
| `OBJECT_STORAGE_USE_PATH_STYLE` | `global.objectStorage.fetcher.pathStyle` | (none) | Use path-style S3 URLs |

### Common configmap changes

The `common.configmap` block has been refactored to use typed masks from `lerian-common-helm`. The following keys are now emitted via helper templates instead of being set directly in `values.yaml`:

**Before (v3.1.4):**

```yaml
common:
  configmap:
    MONGO_URI: "mongodb"
    MONGO_HOST: "mongodb"
    MONGO_NAME: "fetcher-db"
    MONGO_PORT: "27017"
    MONGO_MAX_POOL_SIZE: "1000"
    MONGO_PARAMETERS: ""
    MONGO_TLS_CA_CERT: ""
    RABBITMQ_URI: "amqp"
    RABBITMQ_HOST: "rabbitmq"
    RABBITMQ_PORT_AMQP: "5672"
    RABBITMQ_PORT_HOST: "15672"
    RABBITMQ_HEALTH_CHECK_URL: "http://rabbitmq:15672"
    SEAWEEDFS_HOST: "seaweedfs-filer"
    SEAWEEDFS_FILER_PORT: "8888"
    SEAWEEDFS_TTL: "6M"
    REDIS_HOST: "valkey"
    REDIS_PORT: "6379"
    REDIS_DB: "0"
    OTEL_RESOURCE_SERVICE_NAME: "fetcher"
    OTEL_LIBRARY_NAME: "github.com/LerianStudio/fetcher"
    OTEL_RESOURCE_SERVICE_VERSION: "1.0.0-beta.1"
    OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "development"
    OTEL_EXPORTER_OTLP_ENDPOINT_PORT: "4317"
    OTEL_EXPORTER_OTLP_ENDPOINT: "http://$(HOST_IP):4317"
    ENABLE_TELEMETRY: "false"
    OTEL_INSECURE_EXPORTER: "false"
    MULTI_TENANT_ENABLED: "false"
    MULTI_TENANT_URL: ""
    MULTI_TENANT_ENVIRONMENT: ""
    MULTI_TENANT_MAX_TENANT_POOLS: "100"
    MULTI_TENANT_IDLE_TIMEOUT_SEC: "300"
    MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"
    MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: "30"
```

**After (v3.2.0):**

```yaml
common:
  configmap: {}
```

| Setting | v3.1.4 | v3.2.0 |
|---------|--------|--------|
| `common.configmap.MONGO_HOST` | `"mongodb"` | (emitted by `lerian-common.datastore.value`, defaults to `"mongodb"`) |
| `common.configmap.MONGO_PORT` | `"27017"` | (emitted by `lerian-common.datastore.value`, defaults to `"27017"`) |
| `common.configmap.MONGO_PARAMETERS` | `""` | (emitted by `lerian-common.datastore.value`, defaults to `""`) |
| `common.configmap.RABBITMQ_URI` | `"amqp"` | (emitted by `lerian-common.datastore.value`, defaults to `"amqp"`) |
| `common.configmap.RABBITMQ_HOST` | `"rabbitmq"` | (emitted by `lerian-common.datastore.value`, defaults to `"rabbitmq"`) |
| `common.configmap.RABBITMQ_PORT_AMQP` | `"5672"` | (emitted by `lerian-common.datastore.value`, defaults to `"5672"`) |
| `common.configmap.RABBITMQ_PORT_HOST` | `"15672"` | (emitted by `lerian-common.datastore.value`, defaults to `"15672"`) |
| `common.configmap.RABBITMQ_HEALTH_CHECK_URL` | `"http://rabbitmq:15672"` | (derived from `RABBITMQ_HOST` and `RABBITMQ_PORT_HOST`) |
| `common.configmap.REDIS_HOST` | `"valkey"` | (emitted by `lerian-common.datastore.value`, defaults to `"valkey"`) |
| `common.configmap.REDIS_PORT` | `"6379"` | (emitted by `lerian-common.datastore.value`, defaults to `"6379"`) |
| `common.configmap.ENABLE_TELEMETRY` | `"false"` | (emitted by `lerian-common.otel.env`, defaults to `"false"`) |
| `common.configmap.OTEL_EXPORTER_OTLP_ENDPOINT` | `"http://$(HOST_IP):4317"` | (emitted by `lerian-common.otel.env`, defaults to `"http://$(HOST_IP):4317"`) |
| `common.configmap.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `"development"` | (emitted by `lerian-common.otel.env`, defaults to `"development"`) |
| `common.configmap.MULTI_TENANT_ENABLED` | `"false"` | (emitted by `lerian-common.multiTenant.env`, defaults to `"false"`) |
| `common.configmap.MULTI_TENANT_URL` | `""` | (emitted by `lerian-common.multiTenant.env`, defaults to `""`) |
| `common.configmap.MULTI_TENANT_ENVIRONMENT` | `""` | (emitted by `lerian-common.multiTenant.env`, defaults to `""`) |
| `common.configmap.MULTI_TENANT_MAX_TENANT_POOLS` | `"100"` | (emitted by `lerian-common.multiTenant.env`, defaults to `"100"`) |
| `common.configmap.MULTI_TENANT_IDLE_TIMEOUT_SEC` | `"300"` | (emitted by `lerian-common.multiTenant.env`, defaults to `"300"`) |
| `common.configmap.MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD` | `"5"` | (emitted by `lerian-common.multiTenant.env`, defaults to `"5"`) |
| `common.configmap.MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC` | `"30"` | (emitted by `lerian-common.multiTenant.env`, defaults to `"30"`) |

> **Note:** All keys can still be overridden by setting `common.configmap.<KEY>` explicitly. The native configmap key always wins over the mask.

## Migration Steps

### Step 1: Review dependency update

The chart now depends on `lerian-common-helm` v2.2.0. Helm will automatically download this dependency during upgrade.

```bash
helm dependency update oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.2.0
```

> **Note:** No operator action is required unless you have custom Helm repository configuration that blocks OCI registry access.

### Step 2: Configure streaming for worker

The worker component now hard-requires streaming configuration at startup. You must set `STREAMING_BROKERS` before upgrading if you are deploying the worker.

#### Option 1: Use global streaming configuration (recommended)

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda.messaging:9092"
```

#### Option 2: Use component-level configuration

```yaml
worker:
  configmap:
    STREAMING_ENABLED: "true"
    STREAMING_BROKERS: "redpanda.messaging:9092"
```

> **Warning:** The worker will not boot without a valid `STREAMING_BROKERS` value. Set it to your Kafka/Redpanda bootstrap address (e.g., `"redpanda.<namespace>:9092"`) before upgrading.

**If using SASL authentication:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda.messaging:9092"
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "fetcher"

worker:
  secrets:
    STREAMING_SASL_PASSWORD: "secure-password"
```

**If using TLS:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda.messaging:9093"
    tlsEnabled: true

worker:
  secrets:
    STREAMING_TLS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
```

### Step 3: Migrate datastore configuration (optional)

If you have custom datastore endpoints, you can migrate them to the new global configuration blocks for consistency across multiple charts.

#### Option 1: Keep existing configuration (no action required)

Your existing `common.configmap` values will continue to work. The chart preserves backwards compatibility by checking `common.configmap
