# Helm Upgrade from v0.x to v1.x

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Chart name change](#chart-name-change)
  - [Values structure reorganization](#values-structure-reorganization)
  - [Secret management model](#secret-management-model)
  - [Deployment topology mode](#deployment-topology-mode)
- **[Features](#features)**
  - [1. Multi-component deployment architecture](#1-multi-component-deployment-architecture)
  - [2. PostgreSQL bootstrap job](#2-postgresql-bootstrap-job)
  - [3. Database migrations job](#3-database-migrations-job)
  - [4. AWS IAM Roles Anywhere support](#4-aws-iam-roles-anywhere-support)
  - [5. Lerian-common library integration](#5-lerian-common-library-integration)
  - [6. Enhanced observability configuration](#6-enhanced-observability-configuration)
  - [7. Per-role autoscaling and PDB](#7-per-role-autoscaling-and-pdb)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: Single deployment (mode: all)](#scenario-1-single-deployment-mode-all)
  - [Scenario 2: Split deployment (mode: split)](#scenario-2-split-deployment-mode-split)
- **[Configuration Reference](#configuration-reference)**
  - [Root-level values](#root-level-values)
  - [Global configuration](#global-configuration)
  - [StreamingHub configuration](#streaminghub-configuration)
  - [Role-specific configuration](#role-specific-configuration)
  - [Migrations configuration](#migrations-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Back up existing configuration](#step-1-back-up-existing-configuration)
  - [Step 2: Restructure values.yaml](#step-2-restructure-valuesyaml)
  - [Step 3: Configure secrets](#step-3-configure-secrets)
  - [Step 4: Set deployment mode](#step-4-set-deployment-mode)
  - [Step 5: Enable migrations job](#step-5-enable-migrations-job)
  - [Step 6: Review connection budget](#step-6-review-connection-budget)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### Chart name change

The chart name has changed from `streaming-hub` to `streaming-hub-helm` in the Chart.yaml metadata.

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Chart name | `streaming-hub` | `streaming-hub-helm` |

**Impact:** This change affects how the chart is referenced in Helm commands and OCI registry paths. The chart is now published as `oci://registry-1.docker.io/lerianstudio/streaming-hub-helm`.

> **Important:** Update any CI/CD pipelines, ArgoCD applications, or automation scripts that reference the old chart name.

### Values structure reorganization

All configuration has been moved under a single root key `streamingHub`. The flat structure from v0.0.0 no longer exists.

**Before (v0.0.0):**

```yaml
replicaCount: 1
image:
  repository: ghcr.io/lerianstudio/streaming-hub
  tag: "1.5.0"
service:
  type: ClusterIP
  port: 8080
```

**After (v1.0.0):**

```yaml
streamingHub:
  mode: all
  image:
    repository: ghcr.io/lerianstudio/streaming-hub
    tag: "1.5.0"
  service:
    type: ClusterIP
    port: 8080
  all:
    replicaCount: 1
```

**Migration required:** All existing values must be nested under `streamingHub`. Additionally, replica count and resource configuration are now per-role (under `streamingHub.all`, `streamingHub.ingest`, or `streamingHub.delivery`).

### Secret management model

The chart now provides two secret management paths: chart-managed secrets (default) or external secrets (opt-in).

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Secret management | Undefined | `streamingHub.useExistingSecret: false` (default) |
| Secret name control | Not available | `streamingHub.existingSecretName` |
| Required secret keys | Undefined | `STREAMING_HUB_POSTGRES_DSN` (always required) |

**Before (v0.0.0):**

Secrets were managed outside the chart or through unspecified mechanisms.

**After (v1.0.0):**

```yaml
streamingHub:
  useExistingSecret: false
  existingSecretName: ""
  secrets:
    STREAMING_HUB_POSTGRES_DSN: "postgresql://user:pass@host:5432/db?sslmode=require"
    STREAMING_HUB_KAFKA_CA_CERT: ""
    STREAMING_HUB_DEV_KEK: ""
    STREAMING_HUB_KAFKA_SCRAM_PASSWORD: ""
    POSTGRES_PASSWORD: ""
```

> **Warning:** The `STREAMING_HUB_POSTGRES_DSN` secret is **always required** for a working installation. An empty DSN will cause the application to fail at boot.

**Migration required:** Operators must either:
1. Populate `streamingHub.secrets.STREAMING_HUB_POSTGRES_DSN` for chart-managed secrets, or
2. Set `streamingHub.useExistingSecret: true` and point `existingSecretName` to a pre-existing secret containing the `STREAMING_HUB_POSTGRES_DSN` key

### Deployment topology mode

The chart now enforces a deployment mode selection via `streamingHub.mode`.

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Deployment mode | Implicit single deployment | `streamingHub.mode: all` (default) or `split` |
| Role selection | Not available | `STREAMING_HUB_ROLE` environment variable set per deployment |

**Impact:** The `mode` field controls whether the chart renders:
- `all`: One Deployment with `STREAMING_HUB_ROLE=all` (ingest + delivery co-resident)
- `split`: Two Deployments with `STREAMING_HUB_ROLE=ingest` and `STREAMING_HUB_ROLE=delivery`

> **Critical:** Never run both an `all` deployment AND split deployments against the same Kafka cluster. They join the same consumer group and will double-consume every event.

---

## Features

### 1. Multi-component deployment architecture

The chart now supports runtime role selection through the `STREAMING_HUB_ROLE` environment variable, controlled by the `streamingHub.mode` field.

**Configuration:**

```yaml
streamingHub:
  mode: all  # or "split"
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.mode` | `all` | Deployment topology: `all` (single deployment) or `split` (separate ingest/delivery) |

**Behavior:**

- **mode: all** — Renders one Deployment named `streaming-hub` with `STREAMING_HUB_ROLE=all`
- **mode: split** — Renders two Deployments: `streaming-hub-ingest` with `STREAMING_HUB_ROLE=ingest` and `streaming-hub-delivery` with `STREAMING_HUB_ROLE=delivery`

Each role has independent scaling, resource allocation, and PostgreSQL connection pool sizing:

```yaml
streamingHub:
  all:
    replicaCount: 1
    poolMaxOpenConns: 25
    poolMaxIdleConns: 12
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
  ingest:
    replicaCount: 1
    poolMaxOpenConns: 8
    poolMaxIdleConns: 4
  delivery:
    replicaCount: 1
    poolMaxOpenConns: 16
    poolMaxIdleConns: 10
```

**New environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAMING_HUB_ROLE` | Set by mode | Runtime role: `all`, `ingest`, or `delivery` |
| `STREAMING_HUB_POSTGRES_MAX_OPEN_CONNS` | Role-specific | Maximum open database connections per pod |
| `STREAMING_HUB_POSTGRES_MAX_IDLE_CONNS` | Role-specific | Maximum idle database connections per pod |

### 2. PostgreSQL bootstrap job

A new optional Helm hook job creates the database and role before the application starts.

**Configuration:**

```yaml
global:
  externalPostgresDefinitions:
    enabled: false
    database: "streaming-hub"
    role: "streaming-hub"
    connection:
      host: "streaming-hub-postgresql"
      port: "5432"
    postgresAdminLogin:
      useExistingSecret:
        name: ""
      username: "postgres"
      password: ""
    hubCredentials:
      useExistingSecret:
        name: ""
      password: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.externalPostgresDefinitions.enabled` | `false` | Enable PostgreSQL bootstrap job |
| `global.externalPostgresDefinitions.database` | `streaming-hub` | Database name to create |
| `global.externalPostgresDefinitions.role` | `streaming-hub` | Role name to create |

**Hook ordering:**

The bootstrap job runs as a Helm PreSync hook with weight `-10`, before the migrations job (weight `-1`) and the main application deployment.

> **Note:** This job is optional. Operators may instead provision the database and role externally (e.g., managed PostgreSQL service) and point the application DSN at the pre-existing database.

### 3. Database migrations job

A new required job applies SQL schema migrations before the application starts.

**Configuration:**

```yaml
streamingHub:
  migrations:
    enabled: false
    useExistingSecret: false
    existingSecretName: ""
    image:
      repository: ghcr.io/lerianstudio/streaming-hub-migrations
      tag: ""
      digest: ""
      pullPolicy: IfNotPresent
    backoffLimit: 3
    activeDeadlineSeconds: 600
    ttlSecondsAfterFinished: 600
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
| `streamingHub.migrations.enabled` | `false` | Enable the migrations job (opt-in per environment) |
| `streamingHub.migrations.useExistingSecret` | `false` | Read DSN from an external secret instead of chart-managed secret |
| `streamingHub.migrations.backoffLimit` | `3` | Maximum retries before job fails |
| `streamingHub.migrations.activeDeadlineSeconds` | `600` | Hard wall-clock cap on job execution |

**Hook ordering:**

The migrations job runs as a Helm PreSync hook with weight `-1`, after the optional bootstrap job (weight `-10`) and before the main application deployment.

> **Important:** The application will fail to start without this job. Ingest and delivery workers will spin on `relation "event_inbox"/"delivery_jobs" does not exist (42P01)` errors if the schema is not initialized.

**New environment variables (migrations job only):**

| Variable | Source | Description |
|----------|--------|-------------|
| `STREAMING_HUB_POSTGRES_DSN` | Secret | PostgreSQL connection string for migrations |

### 4. AWS IAM Roles Anywhere support

The chart now supports AWS IAM Roles Anywhere for workload identity, injecting a credential-vending sidecar and IMDS environment variables.

**Configuration:**

```yaml
aws:
  rolesAnywhere:
    enabled: false
    image:
      repository: ghcr.io/lerianstudio/aws-signing-helper
      tag: "1.1.1"
    port: 9911
    region: us-east-1
    roleArn: ""
    profileArn: ""
    trustAnchorArn: ""
    certificateSecretName: ""
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 10m
        memory: 32Mi
```

| Flag | Default | Description |
|------|---------|-------------|
| `aws.rolesAnywhere.enabled` | `false` | Enable IAM Roles Anywhere sidecar |
| `aws.rolesAnywhere.port` | `9911` | IMDS-compatible endpoint port |
| `aws.rolesAnywhere.roleArn` | (required) | IAM role ARN to assume |
| `aws.rolesAnywhere.certificateSecretName` | (required) | Secret containing X.509 client cert/key |

**New environment variables (when enabled):**

| Variable | Value | Description |
|----------|-------|-------------|
| `AWS_EC2_METADATA_SERVICE_ENDPOINT` | `http://127.0.0.1:<port>` | Points AWS SDK to sidecar |
| `AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE` | `IPv4` | IMDS endpoint mode |

> **Note:** The sidecar requires an X.509 client certificate provisioned outside the chart (e.g., via cert-manager). The certificate secret must be mounted as `iam-certs` with keys `tls.crt` and `tls.key`.

### 5. Lerian-common library integration

The chart now depends on `lerian-common-helm` v2.1.0 as a local file dependency, adopting shared helpers for workload boilerplate and domain-level configuration.

**Adopted helpers:**

- `lerian-common.datastore.value` — PostgreSQL connection mask (resolves `global.datastores.postgres` and `streamingHub.datastores.postgres` into `POSTGRES_*` environment variables)
- `lerian-common.auth.env` — Plugin-access-manager JWT auth contract (`PLUGIN_AUTH_*` variables)
- `lerian-common.globalValue` — Observability and multi-tenant base configuration
- `lerian-common.service`, `lerian-common.hpa`, `lerian-common.pdb` — Workload resource templates
- `lerian-common.otel.podEnv` — OTEL downward API snippet
- `lerian-common.rolesAnywhere.*` — AWS IAM Roles Anywhere fragments

**Configuration:**

```yaml
global:
  datastores:
    postgres:
      host: "pg.internal"
      port: "5432"
      user: "streaming_hub"
      name: "streaming_hub"
      ssl: "require"
  auth:
    enabled: true
  observability:
    otlpEndpoint: ""
    insecureExporter: false
    deploymentEnvironment: ""
  multiTenant:
    enabled: false
```

**New environment variables (from lerian-common helpers):**

| Variable | Source | Description |
|----------|---------|-------------|
| `POSTGRES_HOST` | `global.datastores.postgres.host` | PostgreSQL host |
| `POSTGRES_PORT` | `global.datastores.postgres.port` | PostgreSQL port |
| `POSTGRES_USER` | `global.datastores.postgres.user` | PostgreSQL user |
| `POSTGRES_DB` | `global.datastores.postgres.name` | PostgreSQL database name |
| `POSTGRES_SSLMODE` | `global.datastores.postgres.ssl` | PostgreSQL SSL mode |
| `PLUGIN_AUTH_ENABLED` | `global.auth.enabled` | Enable JWT auth |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `global.observability.otlpEndpoint` or downward API | OTEL collector endpoint |
| `ENV_NAME` | `global.observability.deploymentEnvironment` | Deployment environment name |
| `MULTI_TENANT_ENABLED` | `global.multiTenant.enabled` | Enable multi-tenant mode |

> **Note:** The `lerian-common` dependency is a library chart (renders nothing on its own). It provides template helpers only; no subcharts for OTEL collectors, Kafka, or PostgreSQL are bundled.

### 6. Enhanced observability configuration

The chart now supports per-pod OTEL endpoint overrides via the downward API, controlled by a chart-level toggle.

**Configuration:**

```yaml
streamingHub:
  telemetry:
    enabled: false
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.telemetry.enabled` | `false` | Inject per-pod OTLP endpoint override (HOST_IP downward API) |

**Behavior:**

When `streamingHub.telemetry.enabled: true`, each pod receives:

```yaml
env:
  - name: HOST_IP
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://$(HOST_IP):4317"
```

This overrides the global `observability.otlpEndpoint` with a node-local DaemonSet collector endpoint.

> **Note:** This is independent of the application's Prometheus metrics exposition, which is controlled by `STREAMING_HUB_METRICS_ENABLED` in the ConfigMap.

### 7. Per-role autoscaling and PDB

Each role (all, ingest, delivery) now has independent HPA and PDB configuration.

**Configuration:**

```yaml
streamingHub:
  all:
    autoscaling:
      enabled: false
      minReplicas: 1
      maxReplicas: 3
      targetCPUUtilizationPercentage: 80
      targetMemoryUtilizationPercentage: 80
    pdb:
      enabled: false
      minAvailable: 1
      annotations: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.<role>.autoscaling.enabled` | `false` | Enable HPA for this role |
| `streamingHub.<role>.autoscaling.maxReplicas` | Role-specific | Maximum replica count (connection budget critical) |
| `streamingHub.<role>.pdb.enabled` | `false` | Enable PodDisruptionBudget for this role |
| `streamingHub.<role>.pdb.minAvailable` | `1` | Minimum available pods during disruption |

> **Critical:** When HPA is enabled, `maxReplicas × poolMaxOpenConns` must fit within the PostgreSQL `max_connections` budget. The sum across all active roles (all OR ingest+delivery, never both) must not exceed the database connection limit.

**Example connection budget calculation:**

```yaml
# mode: split, HPA enabled on both roles
streamingHub:
  ingest:
    autoscaling:
      maxReplicas: 4
    poolMaxOpenConns: 8  # 4 × 8 = 32 connections
  delivery:
    autoscaling:
      maxReplicas: 3
    poolMaxIdleConns: 16  # 3 × 16 = 48 connections
# Total: 32 + 48 = 80 connections + headroom ≤ max_connections
```

---

## Deployment Scenarios

### Scenario 1: Single deployment (mode: all)

**Use case:** Development, staging, or small production environments where ingest and delivery co-reside in one process.

**Configuration:**

```yaml
streamingHub:
  mode: all
  all:
    replicaCount: 2
    poolMaxOpenConns: 25
    poolMaxIdleConns: 12
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 200m
        memory: 256Mi
    autoscaling:
      enabled: false
```

**Rendered resources:**

- 1 Deployment: `streaming-hub` with `STREAMING_HUB_ROLE=all`
- 1 Service: `streaming-hub` (ClusterIP, port 8080)
- 1 ConfigMap: `streaming-hub`
- 1 Secret: `streaming-hub` (or external if `useExistingSecret: true`)
- 1 ServiceAccount: `streaming-hub`

**Connection budget:**

```
2 replicas × 25 max_open_conns = 50 connections
```

### Scenario 2: Split deployment (mode: split)

**Use case:** Production environments requiring independent scaling of ingest (Kafka consumer) and delivery (webhook dispatcher) workloads.

**Configuration:**

```yaml
streamingHub:
  mode: split
  ingest:
    replicaCount: 3
    poolMaxOpenConns: 8
    poolMaxIdleConns: 4
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
    autoscaling:
      enabled: true
      minReplicas: 3
      maxReplicas: 6
      targetCPUUtilizationPercentage: 70
  delivery:
    replicaCount: 5
    poolMaxOpenConns: 16
    poolMaxIdleConns: 10
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 200m
        memory: 256Mi
    autoscaling:
      enabled: true
      minReplicas: 5
      maxReplicas: 10
      targetCPUUtilizationPercentage: 80
```

**Rendered resources:**

- 2 Deployments: `streaming-hub-ingest` (role=ingest), `streaming-hub-delivery` (role=delivery)
- 2 Services: `streaming-hub-ingest`, `streaming-hub-delivery`
- 2 HPAs: `streaming-hub-ingest`, `streaming-hub-delivery` (when autoscaling.enabled)
- 1 ConfigMap: `streaming-hub` (shared)
- 1 Secret: `streaming-hub` (shared)
- 1 ServiceAccount: `streaming-hub` (shared)

**Connection budget:**

```
Ingest:   6 maxReplicas × 8 max_open_conns  = 48 connections
Delivery: 10 maxReplicas × 16 max_open_conns = 160 connections
Total: 48 + 160 = 208 connections + headroom ≤ max_connections
```

> **Warning:** Ensure your PostgreSQL instance has `max_connections` set to at least 250 for this configuration.

---

## Configuration Reference

### Root-level values

```yaml
nameOverride: ""
fullnameOverride: ""
namespaceOverride: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `nameOverride` | `""` | Override chart name component of resource names |
| `fullnameOverride` | `""` | Override fully-qualified release name (wins verbatim) |
| `namespaceOverride` | `""` | Override namespace (defaults to `.Release.Namespace`) |

### Global configuration

```yaml
global:
  datastores:
    postgres:
      host: ""
      port: "5432"
      user: "streaming_hub"
      name: "streaming_hub"
      ssl: "disable"
  auth:
    enabled: true
  observability:
    otlpEndpoint: ""
    insecureExporter: false
    deploymentEnvironment: ""
  multiTenant:
    enabled: false
  externalPostgresDefinitions:
    enabled: false
    database: "streaming-hub"
    role: "streaming-hub"
    connection:
      host: "streaming-hub-postgresql"
      port: "5432"
    postgresAdminLogin:
      useExistingSecret:
        name: ""
      username: "postgres"
      password: ""
    hubCredentials:
      useExistingSecret:
        name: ""
      password: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.datastores.postgres.host` | `""` | PostgreSQL host (empty uses app default: localhost) |
| `global.datastores.postgres.port` | `"5432"` | PostgreSQL port |
| `global.datastores.postgres.user` | `"streaming_hub"` | PostgreSQL user |
| `global.datastores.postgres.name` | `"streaming_hub"` | PostgreSQL database name |
| `global.datastores.postgres.ssl` | `"disable"` | PostgreSQL SSL mode |
| `global.auth.enabled` | `true` | Enable plugin-access-manager JWT auth |
| `global.observability.otlpEndpoint` | `""` | Global OTEL collector endpoint |
| `global.observability.deploymentEnvironment` | `""` | Deployment environment name (ENV_NAME) |
| `global.multiTenant.enabled` | `false` | Enable multi-tenant mode |

### StreamingHub configuration

```yaml
streamingHub:
  mode: all
  image:
    repository: ghcr.io/lerianstudio/streaming-hub
    pullPolicy: IfNotPresent
    tag: ""
  imagePullSecrets:
    - name: ghcr-credential
  revisionHistoryLimit: 10
  annotations: {}
  podAnnotations: {}
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  podSecurityContext: {}
  securityContext:
    runAsGroup: 65532
    runAsUser: 65532
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
  service:
    type: ClusterIP
    port: 8080
    annotations: {}
  ingress:
    enabled: false
    className: "nginx"
    annotations: {}
    hosts: []
    tls: []
  serviceAccount:
    create: true
    annotations: {}
    name: ""
    automountServiceAccountToken: false
  terminationGracePeriodSeconds: 80
  livenessProbe:
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  readinessProbe:
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  nodeSelector: {}
  tolerations: []
  affinity: {}
  extraEnvVars: {}
  telemetry:
    enabled: false
  useExistingSecret: false
  existingSecretName: ""
  datastores: {}
  configmap: {}
  secrets:
    STREAMING_HUB_POSTGRES_DSN: ""
    STREAMING_HUB_KAFKA_CA_CERT: ""
    STREAMING_HUB_DEV_KEK: ""
    STREAMING_HUB_KAFKA_SCRAM_PASSWORD: ""
    POSTGRES_PASSWORD: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.mode` | `all` | Deployment topology: `all` or `split` |
| `streamingHub.image.repository` | `ghcr.io/lerianstudio/streaming-hub` | Container image repository |
| `streamingHub.image.tag` | `""` | Image tag (empty falls back to Chart.appVersion) |
| `streamingHub.revisionHistoryLimit` | `10` | Number of old ReplicaSets to retain |
| `streamingHub.service.type` | `ClusterIP` | Service type (must be ClusterIP) |
| `streamingHub.service.port` | `8080` | Control-plane HTTP port |
| `streamingHub.terminationGracePeriodSeconds` | `80` | Graceful shutdown window |
| `streamingHub.telemetry.enabled` | `false` | Inject per-pod OTLP endpoint override |
| `streamingHub.useExistingSecret` | `false` | Use external secret instead of chart-managed |
| `streamingHub.existingSecretName` | `""` | Name of external secret (when useExistingSecret=true) |

### Role-specific configuration

Each role (`all`, `ingest`, `delivery`) has the same structure:

```yaml
streamingHub:
  all:
    replicaCount: 1
    poolMaxOpenConns: 25
    poolMaxIdleConns: 12
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
    autoscaling:
      enabled: false
      minReplicas: 1
      maxReplicas: 3
      targetCPUUtilizationPercentage: 80
      targetMemoryUtilizationPercentage: 80
    pdb:
      enabled: false
      minAvailable: 1
      annotations: {}
    nodeSelector: {}
    tolerations: []
    affinity: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.<role>.replicaCount` | Role-specific | Static replica count (ignored when autoscaling.enabled) |
| `streamingHub.<role>.poolMaxOpenConns` | Role-specific | Maximum open database connections per pod |
| `streamingHub.<role>.poolMaxIdleConns` | Role-specific | Maximum idle database connections per pod |
| `streamingHub.<role>.autoscaling.enabled` | `false` | Enable HPA for this role |
| `streamingHub.<role>.autoscaling.maxReplicas` | Role-specific | Maximum replicas (connection budget critical) |
| `streamingHub.<role>.pdb.enabled` | `false` | Enable PodDisruptionBudget |

### Migrations configuration

```yaml
streamingHub:
  migrations:
    enabled: false
    useExistingSecret: false
    existingSecretName: ""
    image:
      repository: ghcr.io/lerianstudio/streaming-hub-migrations
      tag: ""
      digest: ""
      pullPolicy: IfNotPresent
    backoffLimit: 3
    activeDeadlineSeconds: 600
    ttlSecondsAfterFinished: 600
    annotations: {}
    podAnnotations: {}
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
| `streamingHub.migrations.enabled` | `false` | Enable migrations job (required for first install) |
| `streamingHub.migrations.useExistingSecret` | `false` | Read DSN from external secret |
| `streamingHub.migrations.backoffLimit` | `3` | Maximum retries before job fails |
| `streamingHub.migrations.activeDeadlineSeconds` | `600` | Hard wall-clock cap on job execution |
| `streamingHub.migrations.ttlSecondsAfterFinished` | `600` | TTL for finished job garbage collection |

---

## Migration Steps

### Step 1: Back up existing configuration

Export your current values to a file:

```bash
helm get values streaming-hub -n streaming-hub > streaming-hub-v0-values.yaml
```

### Step 2: Restructure values.yaml

Create a new `values.yaml` file with the v1.0.0
