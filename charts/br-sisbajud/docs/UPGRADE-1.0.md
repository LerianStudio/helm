# Helm Upgrade from v0.x to v1.x

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Chart is now available](#chart-is-now-available)
  - [New required configuration](#new-required-configuration)
  - [Image pull secrets](#image-pull-secrets)
- **[Features](#features)**
  - [1. Single-service deployment](#1-single-service-deployment)
  - [2. Database migrations](#2-database-migrations)
  - [3. Bundled infrastructure subcharts](#3-bundled-infrastructure-subcharts)
  - [4. Security hardening](#4-security-hardening)
  - [5. High availability support](#5-high-availability-support)
  - [6. Flexible configuration](#6-flexible-configuration)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: External infrastructure (recommended for production)](#scenario-1-external-infrastructure-recommended-for-production)
  - [Scenario 2: Bundled infrastructure (development/testing)](#scenario-2-bundled-infrastructure-developmenttesting)
- **[Configuration Reference](#configuration-reference)**
  - [Core application settings](#core-application-settings)
  - [Migration settings](#migration-settings)
  - [Infrastructure settings](#infrastructure-settings)
  - [New environment variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### Chart is now available

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Chart existence | No chart published | Chart available at `oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm` |
| Chart name | N/A | `br-sisbajud-helm` |
| App version | N/A | `1.0.0-beta.109` |

**Before (v0.0.0):**

The br-sisbajud application had no Helm chart. Operators deployed the application using custom manifests or other deployment methods.

**After (v1.0.0):**

The chart is now published and provides a complete deployment solution including:
- Application deployment with configurable replicas
- Database migration job
- Optional bundled PostgreSQL and Valkey (Redis-compatible) subcharts
- Service, Ingress, and autoscaling resources

> **Important:** This is the initial release of the Helm chart. If you were deploying br-sisbajud using custom manifests, you must migrate your configuration to the chart's values.yaml format.

### New required configuration

The chart requires several configuration values to be set for successful deployment:

| Configuration | Required | Default | Description |
|--------------|----------|---------|-------------|
| `brSisbajud.configmap.POSTGRES_HOST` | Yes (if external) | Auto-detected from subchart | PostgreSQL host address |
| `brSisbajud.secrets.POSTGRES_PASSWORD` | Yes | `""` | PostgreSQL password |
| `brSisbajud.secrets.REDIS_PASSWORD` | Yes (if Redis uses auth) | `""` | Redis/Valkey password |
| `imagePullSecrets` | Yes (for GHCR) | `[{name: ghcr-credential}]` | Pull secret for private registry |

> **Warning:** The chart will deploy but the application will fail to start if database credentials are not provided. You must supply these values via `values.yaml` or `--set` flags.

### Image pull secrets

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Default pull secret | N/A | `ghcr-credential` |
| Image repository | N/A | `ghcr.io/lerianstudio/br-sisbajud` |
| Migrations repository | N/A | `ghcr.io/lerianstudio/br-sisbajud-migrations` |

The chart expects a Kubernetes secret named `ghcr-credential` to exist in the target namespace for pulling images from GitHub Container Registry.

**Create the pull secret before installing:**

```bash
kubectl create secret docker-registry ghcr-credential \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token> \
  -n br-sisbajud
```

Or override the default:

```yaml
imagePullSecrets:
  - name: my-custom-pull-secret
```

---

## Features

### 1. Single-service deployment

The chart deploys br-sisbajud as a single Go binary that runs both the HTTP API and background workers in one process.

**Default deployment configuration:**

```yaml
brSisbajud:
  enabled: true
  replicaCount: 1
  image:
    repository: ghcr.io/lerianstudio/br-sisbajud
    tag: ""  # Defaults to Chart.appVersion (1.0.0-beta.109)
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 4029
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
```

The service exposes port 4029, matching the application's `SERVER_ADDRESS=0.0.0.0:4029` default.

### 2. Database migrations

The chart includes an automated migration system that applies SQL schema changes before the application starts.

**Migration job configuration:**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/br-sisbajud-migrations
    tag: ""  # Defaults to Chart.appVersion
    pullPolicy: IfNotPresent
  backoffLimit: 3
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 600
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 256Mi
```

| Flag | Default | Description |
|------|---------|-------------|
| `migrations.enabled` | `true` | Enable the migration job |
| `migrations.backoffLimit` | `3` | Number of retries before marking job as failed |
| `migrations.activeDeadlineSeconds` | `600` | Maximum time (seconds) for job to complete |
| `migrations.ttlSecondsAfterFinished` | `600` | Time to keep completed job pods before cleanup |

**ArgoCD integration:**

The migration job uses the `argocd.argoproj.io/hook: PreSync` annotation, ensuring migrations run before the application deployment when using ArgoCD. Under plain `helm install`, the job runs as a normal Kubernetes Job.

**Migration database connection:**

```yaml
migrations:
  postgres:
    host: ""       # Falls back to brSisbajud.configmap.POSTGRES_HOST
    port: ""       # Falls back to brSisbajud.configmap.POSTGRES_PORT
    user: ""       # Falls back to brSisbajud.configmap.POSTGRES_USER
    database: ""   # Falls back to brSisbajud.configmap.POSTGRES_DATABASE
    sslMode: ""    # Falls back to brSisbajud.configmap.POSTGRES_SSL_MODE
    password: ""   # Falls back to brSisbajud.secrets.POSTGRES_PASSWORD
```

> **Note:** Leave these fields empty to reuse the application's database configuration. Override only if migrations need to connect to a different database or use different credentials.

### 3. Bundled infrastructure subcharts

The chart can optionally bundle PostgreSQL and Valkey (Redis-compatible) for development or self-contained deployments.

**Subchart dependencies:**

```yaml
dependencies:
  - name: postgresql
    version: "16.3.5"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
  - name: valkey
    version: "2.4.7"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: valkey.enabled
```

**Default configuration (external infrastructure):**

```yaml
postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true
```

> **Important:** By default, both subcharts are **disabled**. The chart expects external PostgreSQL and Redis instances. See [Deployment Scenarios](#deployment-scenarios) for configuration options.

### 4. Security hardening

The chart implements security best practices with a hardened container security context.

**Security context configuration:**

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

| Setting | Value | Description |
|---------|-------|-------------|
| `runAsNonRoot` | `true` | Enforces non-root user |
| `runAsUser` | `65532` | Matches distroless nonroot user |
| `runAsGroup` | `65532` | Matches distroless nonroot group |
| `allowPrivilegeEscalation` | `false` | Prevents privilege escalation |
| `readOnlyRootFilesystem` | `true` | Makes root filesystem read-only |
| `capabilities.drop` | `ALL` | Drops all Linux capabilities |
| `seccompProfile.type` | `RuntimeDefault` | Uses default seccomp profile |

The application image is based on `distroless static-debian12:nonroot` (UID/GID 65532).

### 5. High availability support

The chart includes optional horizontal pod autoscaling and pod disruption budgets for production deployments.

**Autoscaling configuration:**

```yaml
brSisbajud:
  autoscaling:
    enabled: false
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilizationPercentage: 80
    targetMemoryUtilizationPercentage: 80
```

**Pod disruption budget:**

```yaml
brSisbajud:
  pdb:
    enabled: true
    minAvailable: 0
    # maxUnavailable: 1  # Uncomment to use maxUnavailable instead
```

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.autoscaling.enabled` | `false` | Enable HorizontalPodAutoscaler |
| `brSisbajud.pdb.enabled` | `true` | Enable PodDisruptionBudget |
| `brSisbajud.pdb.minAvailable` | `0` | Minimum pods that must remain available |

> **Note:** When `autoscaling.enabled` is `true`, the `replicaCount` field is ignored and the HPA controls the number of replicas.

**Health checks:**

```yaml
brSisbajud:
  livenessProbe:
    path: /health
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
```

### 6. Flexible configuration

The chart uses a verbatim ConfigMap pattern that allows operators to add any environment variable without modifying the chart.

**ConfigMap emission:**

```yaml
brSisbajud:
  configmap:
    ENV_NAME: "development"
    SERVER_ADDRESS: "0.0.0.0:4029"
    LOG_LEVEL: "info"
    # Add any additional environment variables here
    CUSTOM_VAR: "custom-value"
```

All keys under `brSisbajud.configmap` are emitted directly into the ConfigMap, except for `POSTGRES_HOST` and `REDIS_HOST` which are computed from subchart settings or explicit values.

**Secrets management:**

```yaml
brSisbajud:
  secrets:
    POSTGRES_PASSWORD: ""
    REDIS_PASSWORD: ""
    # Add any additional secrets here
  useExistingSecret: false
  existingSecretName: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.useExistingSecret` | `false` | Use an operator-provided Secret instead of chart-managed |
| `brSisbajud.existingSecretName` | `""` | Name of existing Secret (required if `useExistingSecret` is `true`) |

> **Important:** When using GitOps with ArgoCD Vault Plugin, place AVP placeholders in the `secrets` section:
> ```yaml
> brSisbajud:
>   secrets:
>     POSTGRES_PASSWORD: <path:secret/data/br-sisbajud#postgres-password>
>     REDIS_PASSWORD: <path:secret/data/br-sisbajud#redis-password>
> ```

**Extra environment variables:**

```yaml
brSisbajud:
  extraEnvVars:
    - name: SPECIAL_VAR
      value: "special-value"
    - name: SECRET_FROM_ANOTHER_SOURCE
      valueFrom:
        secretKeyRef:
          name: external-secret
          key: token
```

Use `extraEnvVars` for environment variables that need explicit `env:` entries (e.g., with `valueFrom` references).

---

## Deployment Scenarios

### Scenario 1: External infrastructure (recommended for production)

This is the default configuration. PostgreSQL and Redis are pre-provisioned and managed outside the chart.

**Configuration:**

```yaml
brSisbajud:
  configmap:
    ENV_NAME: "production"
    SERVER_ADDRESS: "0.0.0.0:4029"
    LOG_LEVEL: "info"
    POSTGRES_HOST: "postgres.example.com"
    POSTGRES_PORT: "5432"
    POSTGRES_USER: "br_sisbajud"
    POSTGRES_DATABASE: "br_sisbajud"
    POSTGRES_SSL_MODE: "require"
    REDIS_HOST: "redis.example.com:6379"
  secrets:
    POSTGRES_PASSWORD: "<vault-placeholder-or-actual-password>"
    REDIS_PASSWORD: "<vault-placeholder-or-actual-password>"

postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true
```

**Install command:**

```bash
helm install br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm \
  --version 1.0.0 \
  -n br-sisbajud \
  --create-namespace \
  -f production-values.yaml
```

### Scenario 2: Bundled infrastructure (development/testing)

Enable the bundled PostgreSQL and Valkey subcharts for a self-contained deployment.

**Configuration:**

```yaml
brSisbajud:
  configmap:
    ENV_NAME: "development"
    SERVER_ADDRESS: "0.0.0.0:4029"
    LOG_LEVEL: "debug"
    POSTGRES_USER: "br_sisbajud"
    POSTGRES_DATABASE: "br_sisbajud"
    POSTGRES_SSL_MODE: "disable"
  secrets:
    POSTGRES_PASSWORD: "dev-password"
    REDIS_PASSWORD: "dev-redis-password"

postgresql:
  enabled: true
  external: false
  auth:
    username: "br_sisbajud"
    password: "dev-password"
    database: "br_sisbajud"
  primary:
    persistence:
      enabled: true
      size: 8Gi

valkey:
  enabled: true
  external: false
  auth:
    enabled: true
    password: "dev-redis-password"
  master:
    persistence:
      enabled: true
      size: 8Gi
```

> **Warning:** This configuration is **not recommended for production**. Use external, managed databases for production workloads.

**Install command:**

```bash
helm install br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm \
  --version 1.0.0 \
  -n br-sisbajud \
  --create-namespace \
  -f dev-values.yaml
```

---

## Configuration Reference

### Core application settings

```yaml
nameOverride: "br-sisbajud"
fullnameOverride: ""
namespaceOverride: ""

global:
  imageRegistry: ""
  imagePullSecrets: []

imagePullSecrets:
  - name: ghcr-credential

serviceAccount:
  create: true
  annotations: {}
  name: ""

brSisbajud:
  enabled: true
  replicaCount: 1
  revisionHistoryLimit: 10
  image:
    repository: ghcr.io/lerianstudio/br-sisbajud
    tag: ""
    pullPolicy: IfNotPresent
  imagePullSecrets: []
  podAnnotations: {}
  waitImage: busybox:1.36
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 1
  service:
    type: ClusterIP
    port: 4029
    annotations: {}
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts:
      - host: ""
        paths:
          - path: /
            pathType: Prefix
    tls: []
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  nodeSelector: {}
  tolerations: {}
  affinity: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `nameOverride` | `"br-sisbajud"` | Override the chart name |
| `fullnameOverride` | `""` | Override the full resource name |
| `namespaceOverride` | `""` | Override the target namespace |
| `brSisbajud.enabled` | `true` | Enable the br-sisbajud deployment |
| `brSisbajud.replicaCount` | `1` | Number of replicas (ignored if autoscaling enabled) |
| `brSisbajud.revisionHistoryLimit` | `10` | Number of old ReplicaSets to retain |
| `brSisbajud.waitImage` | `busybox:1.36` | Image for init container that waits for dependencies |
| `brSisbajud.service.type` | `ClusterIP` | Kubernetes service type |
| `brSisbajud.service.port` | `4029` | Service port (matches application SERVER_ADDRESS) |

### Migration settings

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/br-sisbajud-migrations
    tag: ""
    pullPolicy: IfNotPresent
  imagePullSecrets: []
  waitImage: busybox:1.36
  useExistingSecret: false
  existingSecretName: ""
  postgres:
    host: ""
    port: ""
    user: ""
    database: ""
    sslMode: ""
    password: ""
  backoffLimit: 3
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 600
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 256Mi
```

| Flag | Default | Description |
|------|---------|-------------|
| `migrations.enabled` | `true` | Enable the migration job |
| `migrations.useExistingSecret` | `false` | Use an operator-provided Secret for migrations |
| `migrations.existingSecretName` | `""` | Name of existing Secret (required if `useExistingSecret` is `true`) |
| `migrations.postgres.host` | `""` | Override PostgreSQL host for migrations (falls back to app config) |
| `migrations.postgres.password` | `""` | Override PostgreSQL password for migrations (falls back to app secret) |

### Infrastructure settings

```yaml
postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true
```

| Flag | Default | Description |
|------|---------|-------------|
| `postgresql.enabled` | `false` | Enable bundled PostgreSQL subchart |
| `postgresql.external` | `true` | Indicates PostgreSQL is external (affects connection logic) |
| `valkey.enabled` | `false` | Enable bundled Valkey (Redis-compatible) subchart |
| `valkey.external` | `true` | Indicates Valkey is external (affects connection logic) |

> **Note:** When subcharts are enabled (`enabled: true`), set `external: false` to use the bundled instance. When disabled, set `external: true` and provide connection details via `brSisbajud.configmap`.

### New environment variables

The following environment variables are configured via `brSisbajud.configmap`:

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV_NAME` | `"development"` | Environment name (development, staging, production) |
| `SERVER_ADDRESS` | `"0.0.0.0:4029"` | HTTP server bind address and port |
| `LOG_LEVEL` | `"info"` | Logging level (debug, info, warn, error) |
| `POSTGRES_HOST` | Auto-detected | PostgreSQL host address |
| `POSTGRES_PORT` | `"5432"` | PostgreSQL port |
| `POSTGRES_USER` | `""` | PostgreSQL username |
| `POSTGRES_DATABASE` | `""` | PostgreSQL database name |
| `POSTGRES_SSL_MODE` | `""` | PostgreSQL SSL mode (disable, require, verify-ca, verify-full) |
| `REDIS_HOST` | Auto-detected | Redis host address with port (e.g., `redis.example.com:6379`) |
| `ENABLE_TELEMETRY` | `"false"` | Enable OpenTelemetry tracing |

The following secrets are configured via `brSisbajud.secrets`:

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_PASSWORD` | `""` | PostgreSQL password |
| `REDIS_PASSWORD` | `""` | Redis/Valkey password |

> **Important:** `POSTGRES_HOST` and `REDIS_HOST` are automatically computed from subchart settings when bundled infrastructure is enabled. Override them explicitly in `brSisbajud.configmap` when using external infrastructure.

**Telemetry configuration:**

When `ENABLE_TELEMETRY` is set to `"true"`, the deployment automatically injects:

```yaml
- name: HOST_IP
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://$(HOST_IP):4317"
```

This configures OpenTelemetry to send traces to an OTLP collector running on the host node.

---

## Migration Steps

Since this is the initial release of the Helm chart (v0.0.0 → v1.0.0), there is no previous Helm-managed deployment to migrate from. Follow these steps to deploy br-sisbajud using the new chart:

### 1. Create the namespace

```bash
kubectl create namespace br-sisbajud
```

### 2. Create the image pull secret

```bash
kubectl create secret docker-registry ghcr-credential \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token> \
  -n br-sisbajud
```

### 3. Prepare your values file

Create a `values.yaml` file with your configuration. For production with external infrastructure:

```yaml
brSisbajud:
  replicaCount: 2
  configmap:
    ENV_NAME: "production"
    SERVER_ADDRESS: "0.0.0.0:4029"
    LOG_LEVEL: "info"
    POSTGRES_HOST: "postgres.example.com"
    POSTGRES_PORT: "5432"
    POSTGRES_USER: "br_sisbajud"
    POSTGRES_DATABASE: "br_sisbajud"
    POSTGRES_SSL_MODE: "require"
    REDIS_HOST: "redis.example.com:6379"
  secrets:
    POSTGRES_PASSWORD: "<your-postgres-password>"
    REDIS_PASSWORD: "<your-redis-password>"
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
  ingress:
    enabled: true
    className: "nginx"
    hosts:
      - host: sisbajud.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: sisbajud-tls
        hosts:
          - sisbajud.example.com

postgresql:
  enabled: false
  external: true

valkey:
  enabled: false
  external: true
```

### 4. Install the chart

```bash
helm install br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm \
  --version 1.0.0 \
  -n br-sisbajud \
  -f values.yaml
```

### 5. Verify the deployment

```bash
kubectl -n br-sisbajud get pods -l app.kubernetes.io/instance=br-sisbajud
kubectl -n br-sisbajud get cm,secret -l app.kubernetes.io/instance=br-sisbajud
kubectl -n br-sisbajud logs -l app.kubernetes.io/instance=br-sisbajud
```

### 6. Check migration job status

```bash
kubectl -n br-sisbajud get jobs
kubectl -n br-sisbajud logs job/br-sisbajud-migrations
```

> **Note:** The migration job runs automatically before the application starts. If the job fails, the application pods will wait in init state until the database is ready.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.0.0 -n br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.0.0 -n br-sisbajud
```
