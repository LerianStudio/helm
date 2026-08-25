# Helm Upgrade from v0.0.0 to v0.1.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Features](#features)**
  - [1. Initial Chart Release](#1-initial-chart-release)
  - [2. Multi-Component Architecture](#2-multi-component-architecture)
  - [3. Bundled PostgreSQL Subchart](#3-bundled-postgresql-subchart)
  - [4. AWS IAM Roles Anywhere Support](#4-aws-iam-roles-anywhere-support)
  - [5. Schema Migrations Job](#5-schema-migrations-job)
  - [6. Comprehensive Environment Configuration](#6-comprehensive-environment-configuration)
- **[Configuration Reference](#configuration-reference)**
  - [Global Configuration](#global-configuration)
  - [API Component](#api-component)
  - [Worker Component](#worker-component)
  - [PostgreSQL Configuration](#postgresql-configuration)
  - [Migrations Configuration](#migrations-configuration)
  - [AWS Roles Anywhere Configuration](#aws-roles-anywhere-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Prepare Values File](#step-1-prepare-values-file)
  - [Step 2: Configure Required Secrets](#step-2-configure-required-secrets)
  - [Step 3: Choose Database Topology](#step-3-choose-database-topology)
  - [Step 4: Configure Worker (Optional)](#step-4-configure-worker-optional)
  - [Step 5: Review Security Settings](#step-5-review-security-settings)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is the **initial release** of the `plugin-br-pix-jd-helm` chart (v0.1.0), introducing a production-ready Helm chart for the Lerian Bacen/JDPI Pix plugin. Version 0.0.0 did not exist as a published chart — this upgrade guide documents the transition from unmanaged deployments to the first Helm-managed release.

The chart ships two components built from one image: the HTTP API and the cron worker, with support for bundled or external PostgreSQL, AWS credential management via IAM Roles Anywhere or IRSA, and segregated schema migrations.

| Setting | v0.0.0 | v0.1.0 |
|---------|---------|---------|
| Chart exists | No | Yes |
| App version | N/A | 1.12.0-beta.8 |
| Multi-component support | N/A | API + Worker |
| Bundled PostgreSQL | N/A | Optional (Bitnami 16.3.5) |
| Migrations | N/A | Segregated Job |

## Breaking Changes

Since v0.0.0 represents a non-existent chart, there are no breaking changes from a previous Helm-managed state. However, operators migrating from manual deployments should note:

> **Warning:** The chart does **not** migrate on boot. The application reads `MIGRATIONS_PATH` but never calls golang-migrate. Schema changes are applied by a segregated Kubernetes Job (enabled by default via `migrations.enabled=true`). If you disable migrations, you must apply the schema out of band or the API will fail against an empty database.

> **Important:** The default `appVersion` is `1.12.0-beta.8`, but **no image exists at tag `0.0.0-unreleased`**. You must explicitly set `api.image.tag` to a valid published tag or pods will sit in `ImagePullBackOff`.

## Features

### 1. Initial Chart Release

The chart introduces Helm-managed deployments for the plugin-br-pix-jd application, replacing manual Kubernetes manifests with a declarative, version-controlled configuration.

**Key capabilities:**

- Declarative configuration via `values.yaml`
- Automated resource generation (Deployments, Services, ConfigMaps, Secrets)
- Integration with the `lerian-common-helm` library chart for shared contracts
- Support for both single-tenant and multi-tenant modes

**Chart metadata:**

```yaml
apiVersion: v2
name: plugin-br-pix-jd-helm
version: 0.1.0
appVersion: "1.12.0-beta.8"
type: application
```

### 2. Multi-Component Architecture

The chart supports **two components** from a single codebase:

1. **API** (`api`) — HTTP server exposing Pix operations (DICT, SPI, QR codes, webhooks)
2. **Worker** (`worker`) — Cron-based background jobs (reconciliation, MED pollers, refund sweeps)

Both components share:
- ServiceAccount
- ConfigMap environment variables
- Secret credentials
- Pod security context

**Component independence:**

| Component | Enabled by default | Image | Purpose |
|-----------|-------------------|-------|---------|
| `api` | Yes | `ghcr.io/lerianstudio/plugin-br-pix-jd` | HTTP API |
| `worker` | No | Inherits from API or dedicated worker image | Cron jobs |

**Enabling the worker:**

```yaml
worker:
  enabled: true
  replicaCount: 1
```

> **Note:** The worker is **disabled by default**. Transaction reconciliation, refund-park sweeps, MED pollers, and indirect-delivery drainers will not run unless you explicitly enable it.

### 3. Bundled PostgreSQL Subchart

The chart includes an **optional bundled PostgreSQL** via the Bitnami subchart (version 16.3.5), allowing operators to deploy a complete stack without provisioning external infrastructure.

**Topology options:**

#### Option 1: Bundled PostgreSQL (default)

```yaml
postgresql:
  enabled: true
  auth:
    username: plugin-br-pix-jd
    database: plugin-br-pix-jd
    # Password auto-generated by subchart
```

The bundled database:
- Provisions a StatefulSet during Helm sync
- Generates credentials into its own Secret
- Is referenced by the API/worker via `secretKeyRef` (no password duplication)

#### Option 2: External PostgreSQL

```yaml
postgresql:
  enabled: false
  external: true
  host: postgres.example.com
  port: 5432

api:
  secrets:
    POSTGRES_PASSWORD: "your-external-password"
```

**Migration Job timing:**

| Database | Hook Phase | Reason |
|----------|-----------|--------|
| Bundled | `post-install`, `post-upgrade` (PostSync) | StatefulSet provisioned during Sync; Job waits for it |
| External | `pre-install`, `pre-upgrade` (PreSync) | Database already exists; schema applied first |

> **Warning:** With bundled PostgreSQL, the API rolls out **before** the schema lands. PIX routes will error until the migration Job completes. Watch it with:
> ```bash
> kubectl -n plugin-br-pix-jd logs job/plugin-br-pix-jd-migrations
> ```

### 4. AWS IAM Roles Anywhere Support

For clusters **outside EKS**, the chart supports AWS credential provisioning via **IAM Roles Anywhere**, enabling multi-tenant M2M credential resolution from AWS Secrets Manager.

**Two mutually exclusive options:**

#### Option 1: EKS + IRSA (recommended on EKS)

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/plugin-pix-role

aws:
  rolesAnywhere:
    enabled: false
```

The EKS webhook injects credentials automatically; no sidecar needed.

#### Option 2: IAM Roles Anywhere (non-EKS clusters)

```yaml
aws:
  rolesAnywhere:
    enabled: true
    trustAnchorArn: arn:aws:rolesanywhere:us-east-2:123456789012:trust-anchor/abc123
    profileArn: arn:aws:rolesanywhere:us-east-2:123456789012:profile/def456
    roleArn: arn:aws:iam::123456789012:role/plugin-pix-role
    region: us-east-2
    sessionDuration: 3600
    certificateSecretName: plugin-pix-iam-tls
```

This adds an `aws-signing-helper` sidecar to **both** API and worker pods, which:
- Mounts an X.509 client certificate from a Secret (`tls.crt` / `tls.key`)
- Exchanges it for temporary AWS credentials
- Serves them on a loopback IMDS endpoint (`127.0.0.1:9911`)

> **Important:** The certificate Secret is **not** created by this chart. Provision it separately (e.g., via cert-manager) with keys `tls.crt` and `tls.key`.

**Sidecar resource defaults:**

```yaml
aws:
  rolesAnywhere:
    sidecar:
      image:
        repository: public.ecr.aws/rolesanywhere/credential-helper
        tag: latest-amd64
      resources:
        requests:
          cpu: 10m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
```

### 5. Schema Migrations Job

The chart renders a **segregated Kubernetes Job** for database migrations, following the repository convention (matching `plugin-br-bank-transfer`, `notifications`, `plugin-access-manager`).

**Key characteristics:**

- The application **does not migrate on boot** — it reads `MIGRATIONS_PATH` but never calls golang-migrate
- The Job extracts the migrations tree from the app image into an `emptyDir` and runs generic golang-migrate over it
- Schema and app come from the same tag by construction

**Default configuration:**

```yaml
migrations:
  enabled: true
  backoffLimit: 3
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 600
  waitTimeoutSeconds: 300
```

**Multi-tenant incompatibility:**

> **Warning:** The migrations Job is **incompatible with multi-tenant mode**. The Tenant Manager owns per-tenant database migrations; this Job targets the single-tenant database that multi-tenant never uses. The chart will **fail the render** if both are enabled:
> ```yaml
> migrations:
>   enabled: true
> api:
>   configmap:
>     MULTI_TENANT_ENABLED: "true"  # RENDER FAILS
> ```

### 6. Comprehensive Environment Configuration

The chart provides structured configuration blocks for all application environment variables, with three resolution tiers:

1. **Global defaults** (`global.datastores`, `global.observability`, `global.auth`, etc.)
2. **Chart defaults** (literals in `templates/_helpers.tpl`)
3. **Component overrides** (`api.configmap`, `worker.configmap`)

**Environment variable categories:**

| Category | Global Key | Component Override | Example Variables |
|----------|-----------|-------------------|-------------------|
| Observability | `global.observability` | `api.configmap` | `ENABLE_TELEMETRY`, `OTEL_EXPORTER_OTLP_ENDPOINT` |
| Auth | `global.auth` | `api.configmap` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` |
| Datastores | `global.datastores` | `api.configmap` | `POSTGRES_PORT`, `POSTGRES_USER`, `REDIS_HOST` |
| Multi-tenant | `global.multiTenant` | `api.configmap` | `MULTI_TENANT_ENABLED`, `TENANT_MANAGER_URL` |
| Streaming | `global.streaming` | `api.configmap` | `STREAMING_ENABLED`, `STREAMING_BROKER_URL` |
| Rate limiting | `api.rateLimit` | `api.configmap` | `RATE_LIMIT_ENABLED`, `RATE_LIMIT_REQUESTS_PER_SECOND` |
| CORS | `api.cors` | `api.configmap` | `ACCESS_CONTROL_ALLOWED_ORIGINS` |

**Chart defaults when keys are absent:**

| Variable | Default | Notes |
|----------|---------|-------|
| `LOG_LEVEL` | `info` | |
| `SERVER_ADDRESS` | `:8080` | |
| `TLS_TERMINATED_UPSTREAM` | `true` | |
| `POSTGRES_SSLMODE` | `disable` | Override with `global.datastores.postgres.ssl` |
| `POSTGRES_USER` | `plugin-br-pix-jd` | |
| `POSTGRES_NAME` | `plugin-br-pix-jd` | |
| `MIGRATIONS_PATH` | `/migrations` | |
| `SYSTEMPLANE_ENABLED` | `false` | |
| `SWAGGER_ENABLED` | `false` | |
| `ENVIRONMENT_NAME` | `""` | **Must be set to `production` for production installs** |
| `DEPLOYMENT_MODE` | `""` | Valid: `saas`, `byoc`, `local` |

> **Important:** `ENVIRONMENT_NAME` unset resolves to `"development"`, which **disables all production security gates**: Postgres SSL/auth requirements are not enforced, security-bypass rejections do not run, and panic stack traces are exposed. Always set:
> ```yaml
> api:
>   configmap:
>     ENVIRONMENT_NAME: production
> ```

## Configuration Reference

### Global Configuration

```yaml
global:
  # Registry prefix for air-gapped or mirrored installs
  imageRegistry: ""
  
  # Pull secrets applied to all components
  imagePullSecrets: []
  
  # Labels added to every rendered object
  commonLabels: {}
  
  # Annotations added to every object except HPA
  commonAnnotations: {}
  
  # Environment-wide datastore defaults
  datastores:
    postgres:
      port: 5432
      user: plugin-br-pix-jd
      ssl: disable
    redis:
      host: redis.example.com:6379
  
  # Multi-tenant configuration
  multiTenant:
    enabled: false
    tenantManagerUrl: ""
  
  # Auth defaults
  auth:
    enabled: false
    host: ""
  
  # Observability defaults
  observability:
    enabled: true
    otlpEndpoint: ""
    deploymentEnvironment: production
  
  # Streaming/broker defaults
  streaming:
    enabled: false
    brokerUrl: ""
```

### API Component

```yaml
api:
  enabled: true
  replicaCount: 1
  revisionHistoryLimit: 5
  
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    tag: ""  # Falls back to .Chart.AppVersion
    pullPolicy: IfNotPresent
  
  service:
    type: ClusterIP
    port: 8080
    targetPort: http
  
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts: []
    tls: []
  
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  livenessProbe:
    path: /health
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    failureThreshold: 3
  
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  
  startupProbe:
    enabled: false
    path: /readyz
    initialDelaySeconds: 10
    periodSeconds: 5
    failureThreshold: 30
  
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 12
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 85
  
  pdb:
    enabled: true
    minAvailable: 1
  
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  
  terminationGracePeriodSeconds: 60
  
  rateLimit:
    enabled: true
    requestsPerSecond: 100
  
  cors:
    allowedOrigins: []
    allowedMethods: ["GET", "POST", "PUT", "DELETE"]
    allowedHeaders: ["*"]
    exposeHeaders: []
    allowCredentials: false
  
  # Non-secret environment variables
  configmap:
    ENVIRONMENT_NAME: production
    LOG_LEVEL: info
    SERVER_ADDRESS: ":8080"
  
  # Secret values
  secrets:
    LICENSE_KEY: ""
    REDIS_PASSWORD: ""
    # POSTGRES_PASSWORD omitted when bundled subchart enabled
  
  # Escape hatches
  extraConfigmap: {}
  extraSecrets: {}
  extraEnvVars: []
  
  existingSecret:
    name: ""
```

### Worker Component

```yaml
worker:
  enabled: false  # Disabled by default
  replicaCount: 1
  revisionHistoryLimit: 5
  
  image:
    repository: ""  # Inherits from api if empty
    tag: ""
    pullPolicy: IfNotPresent
  
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  pdb:
    enabled: false
    minAvailable: 0
  
  deploymentStrategy:
    type: Recreate  # No rolling update for cron workers
  
  terminationGracePeriodSeconds: 60
  
  configmap:
    OTEL_RESOURCE_SERVICE_NAME: plugin-br-pix-jd-worker
  
  secrets: {}
  extraConfigmap: {}
  extraSecrets: {}
  extraEnvVars: []
  
  existingSecret:
    name: ""
```

### PostgreSQL Configuration

```yaml
postgresql:
  enabled: true  # Bundled by default
  external: false
  
  # Bundled subchart settings
  auth:
    username: plugin-br-pix-jd
    database: plugin-br-pix-jd
    # Password auto-generated
  
  # External database settings (when enabled=false)
  host: ""
  port: 5432
```

### Migrations Configuration

```yaml
migrations:
  enabled: true
  backoffLimit: 3
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 600
  waitTimeoutSeconds: 300
  annotations: {}
  resources: {}
```

### AWS Roles Anywhere Configuration

```yaml
aws:
  rolesAnywhere:
    enabled: false
    trustAnchorArn: ""
    profileArn: ""
    roleArn: ""
    region: us-east-2
    sessionDuration: 3600
    certificateSecretName: ""
    
    sidecar:
      image:
        repository: public.ecr.aws/rolesanywhere/credential-helper
        tag: latest-amd64
        pullPolicy: IfNotPresent
      port: 9911
      resources:
        requests:
          cpu: 10m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
```

## Migration Steps

### Step 1: Prepare Values File

Create a `values.yaml` file with your deployment configuration:

```yaml
nameOverride: plugin-br-pix-jd
namespaceOverride: ""

global:
  imageRegistry: ""
  imagePullSecrets: []
  
  datastores:
    postgres:
      port: 5432
      user: plugin-br-pix-jd
      ssl: disable
    redis:
      host: redis.default.svc.cluster.local:6379
  
  observability:
    enabled: true
    otlpEndpoint: http://otel-collector:4317
    deploymentEnvironment: production

api:
  enabled: true
  replicaCount: 2
  
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    tag: "1.12.0-beta.8"
  
  configmap:
    ENVIRONMENT_NAME: production
    LOG_LEVEL: info
  
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
```

### Step 2: Configure Required Secrets

The chart requires at minimum:

1. **LICENSE_KEY** (required) — validated on boot and every worker tick
2. **REDIS_PASSWORD** (optional if Redis has no auth)
3. **POSTGRES_PASSWORD** (only for external PostgreSQL)

**Option A: Set via values.yaml**

```yaml
api:
  secrets:
    LICENSE_KEY: "your-license-key-here"
    REDIS_PASSWORD: "your-redis-password"
```

**Option B: Use existing Secret**

```yaml
api:
  existingSecret:
    name: plugin-pix-credentials
```

The existing Secret must contain keys: `LICENSE_KEY`, `REDIS_PASSWORD`, and optionally `POSTGRES_PASSWORD`.

### Step 3: Choose Database Topology

#### Option 1: Use Bundled PostgreSQL

```yaml
postgresql:
  enabled: true
  auth:
    username: plugin-br-pix-jd
    database: plugin-br-pix-jd
```

The password is auto-generated. No `POSTGRES_PASSWORD` needed in `api.secrets`.

#### Option 2: Use External PostgreSQL

```yaml
postgresql:
  enabled: false
  external: true
  host: postgres.example.com
  port: 5432

api:
  secrets:
    POSTGRES_PASSWORD: "your-external-password"
```

### Step 4: Configure Worker (Optional)

If you need background jobs (reconciliation, MED pollers, refund sweeps):

```yaml
worker:
  enabled: true
  replicaCount: 1
  
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.12.0-beta.8"
```

> **Note:** If `worker.image.repository` is empty, the worker inherits the API image and the chart overrides the entrypoint to `/worker`.

### Step 5: Review Security Settings

**Production checklist:**

1. Set `ENVIRONMENT_NAME=production`:

```yaml
api:
  configmap:
    ENVIRONMENT_NAME: production
```

2. Enable TLS for datastores if using `DEPLOYMENT_MODE=saas`:

```yaml
global:
  datastores:
    postgres:
      ssl: require

api:
  configmap:
    DEPLOYMENT_MODE: saas
```

3. Configure CORS for browser-facing installs:

```yaml
api:
  cors:
    allowedOrigins:
      - https://console.example.com
    allowCredentials: true
```

4. Enable PodDisruptionBudget and autoscaling:

```yaml
api:
  pdb:
    enabled: true
    minAvailable: 1
  
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 12
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.1.0 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.1.0 -n plugin-br-pix-jd
```
