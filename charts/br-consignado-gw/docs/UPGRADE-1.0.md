# Helm Upgrade from v0.x to v1.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Features](#features)**
  - [1. Multi-component architecture](#1-multi-component-architecture)
  - [2. API component](#2-api-component)
  - [3. UI component](#3-ui-component)
  - [4. Database migrations](#4-database-migrations)
  - [5. Ingress configuration](#5-ingress-configuration)
  - [6. Security hardening](#6-security-hardening)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: API only](#scenario-1-api-only)
  - [Scenario 2: API + UI with ingress](#scenario-2-api--ui-with-ingress)
  - [Scenario 3: Full stack with migrations](#scenario-3-full-stack-with-migrations)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.0.0 is the initial release of the `br-consignado-gw-helm` chart. This chart packages the Brazilian consignado gateway API, its operator console UI, and database migration tooling into a single Helm release with independent component toggles.

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Chart exists | No | Yes |
| Components | N/A | API, UI, Migrations (all disabled by default) |
| Deployment model | N/A | Opt-in multi-component |

> **Important:** All components (`api.enabled`, `ui.enabled`, `migrations.enabled`) default to `false`. Operators must explicitly enable the components they need.

## Breaking Changes

This is the first release. There are no breaking changes from a previous version.

> **Note:** Because all components are disabled by default, installing this chart without configuration changes will deploy no workloads. You must set at least `api.enabled: true` or `ui.enabled: true` to deploy resources.

## Features

### 1. Multi-component architecture

The chart manages three independent components under a single release:

- **API**: The `br-consignado-gw` Go service (distroless container)
- **UI**: The Vite-based operator console (nginx-unprivileged container)
- **Migrations**: A PreSync Job that runs SQL migrations before the API starts

Each component has its own:
- Deployment/Job resource
- Service (API and UI only)
- ConfigMap
- Image repository and tag override
- Resource requests/limits
- Health probes
- Security context

**Chart metadata:**

```yaml
apiVersion: v2
name: br-consignado-gw-helm
type: application
version: 1.0.0
appVersion: "1.3.0-beta.36"
annotations:
  lerian.studio/chart-type: multi-component
```

### 2. API component

The API component deploys the `ghcr.io/lerianstudio/br-consignado-gw` image as a Deployment with a ClusterIP Service.

**Key configuration:**

| Flag | Default | Description |
|------|---------|-------------|
| `api.enabled` | `false` | Enable the API deployment |
| `api.replicaCount` | `1` | Number of API pod replicas |
| `api.image.repository` | `ghcr.io/lerianstudio/br-consignado-gw` | API container image |
| `api.image.tag` | `""` (uses `appVersion`) | Image tag override |
| `api.service.port` | `8080` | API service port |
| `api.useExistingSecret` | `false` | Use an external secret for sensitive config |

**Environment variables (ConfigMap):**

The API ConfigMap is generated from `api.configmap` and includes:

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV_NAME` | `"development"` | Environment name |
| `SERVER_ADDRESS` | `"0.0.0.0:8080"` | HTTP server bind address |
| `POSTGRES_HOST` | `""` | PostgreSQL host (required) |
| `POSTGRES_PORT` | `"5432"` | PostgreSQL port |
| `POSTGRES_USER` | `""` | PostgreSQL user (required) |
| `POSTGRES_NAME` | `""` | PostgreSQL database name (required) |
| `POSTGRES_SSLMODE` | `""` | PostgreSQL SSL mode |
| `REDIS_HOST` | `""` | Redis host |
| `LOG_LEVEL` | `"info"` | Application log level |
| `VERSION` | (auto-injected) | Image tag or `appVersion` |

**Environment variables (Secret):**

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_PASSWORD` | `""` | PostgreSQL password (required) |

**Health probes:**

| Probe | Path | Initial Delay | Period | Timeout | Failure Threshold |
|-------|------|---------------|--------|---------|-------------------|
| Liveness | `/health` | 15s | 20s | 5s | 3 |
| Readiness | `/readyz` | 5s | 10s | 5s | 3 |

**Resource defaults:**

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 512Mi
```

**Example minimal API configuration:**

```yaml
api:
  enabled: true
  configmap:
    POSTGRES_HOST: "postgres.database.svc.cluster.local"
    POSTGRES_USER: "consignado"
    POSTGRES_NAME: "consignado_db"
    POSTGRES_SSLMODE: "require"
    REDIS_HOST: "redis.cache.svc.cluster.local:6379"
  secrets:
    POSTGRES_PASSWORD: "changeme"
```

> **Warning:** Never commit `api.secrets.POSTGRES_PASSWORD` to version control. Use `api.useExistingSecret: true` and reference an external secret for production deployments.

**Using an existing secret:**

```yaml
api:
  enabled: true
  useExistingSecret: true
  existingSecretName: "br-consignado-gw-secrets"
  configmap:
    POSTGRES_HOST: "postgres.database.svc.cluster.local"
    POSTGRES_USER: "consignado"
    POSTGRES_NAME: "consignado_db"
```

The external secret must contain a `POSTGRES_PASSWORD` key.

### 3. UI component

The UI component deploys the `ghcr.io/lerianstudio/br-consignado-gw-ui` image as a Deployment with a ClusterIP Service. The UI is a Vite SPA served by nginx-unprivileged.

**Key configuration:**

| Flag | Default | Description |
|------|---------|-------------|
| `ui.enabled` | `false` | Enable the UI deployment |
| `ui.replicaCount` | `1` | Number of UI pod replicas |
| `ui.image.repository` | `ghcr.io/lerianstudio/br-consignado-gw-ui` | UI container image |
| `ui.image.tag` | `""` (uses `appVersion`) | Image tag override |
| `ui.service.port` | `8080` | UI service port |

**Environment variables (ConfigMap):**

All UI configuration is public and rendered at pod boot:

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE_URL` | `""` | API base URL (must be empty for same-origin) |
| `CASDOOR_CSP_ORIGIN` | `""` | Casdoor issuer origin (no path) |
| `CASDOOR_ENDPOINT` | `""` | Casdoor endpoint URL |
| `CASDOOR_CLIENT_ID` | `""` | Casdoor OAuth client ID |
| `CASDOOR_ORG_NAME` | `""` | Casdoor organization name |
| `CASDOOR_APP_NAME` | `""` | Casdoor application name |
| `AUTH_DISABLED` | `"false"` | Disable authentication (dev only) |

> **Important:** `API_BASE_URL` must remain empty (`""`) when the UI and API share the same ingress host. The console rejects cross-origin API URLs to prevent bearer token leakage.

**Health probes:**

| Probe | Path | Initial Delay | Period | Timeout | Failure Threshold |
|-------|------|---------------|--------|---------|-------------------|
| Liveness | `/healthz` | 5s | 20s | 5s | 3 |
| Readiness | `/healthz` | 3s | 10s | 5s | 3 |

**Resource defaults:**

```yaml
resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    memory: 256Mi
```

**Example UI configuration:**

```yaml
ui:
  enabled: true
  configmap:
    API_BASE_URL: ""
    CASDOOR_CSP_ORIGIN: "https://auth.example.com"
    CASDOOR_ENDPOINT: "https://auth.example.com"
    CASDOOR_CLIENT_ID: "abc123"
    CASDOOR_ORG_NAME: "my-org"
    CASDOOR_APP_NAME: "consignado-gw"
    AUTH_DISABLED: "false"
```

**nginx configuration:**

The UI image uses nginx-unprivileged with:
- `worker_processes=1` (pinned for high-core nodes)
- `/tmp` mounted as an emptyDir (nginx requires writable temp paths)
- Read-only root filesystem

### 4. Database migrations

The migrations component runs as an ArgoCD PreSync Job using the `ghcr.io/lerianstudio/br-consignado-gw-migrations` image. This image is built from `migrations/Dockerfile` and executes SQL migrations from `/migrations` before the API starts.

**Key configuration:**

| Flag | Default | Description |
|------|---------|-------------|
| `migrations.enabled` | `false` | Enable the migrations Job |
| `migrations.image.repository` | `ghcr.io/lerianstudio/br-consignado-gw-migrations` | Migrations container image |
| `migrations.image.tag` | `""` (uses `appVersion`) | Image tag override |
| `migrations.backoffLimit` | `3` | Job retry limit |
| `migrations.activeDeadlineSeconds` | `600` | Job timeout (10 minutes) |
| `migrations.ttlSecondsAfterFinished` | `600` | Job cleanup delay (10 minutes) |

> **Important:** `migrations.enabled` requires `api.enabled: true`. The chart will fail if migrations are enabled without the API.

**PostgreSQL connection:**

The migrations Job can inherit connection settings from `api.configmap` or use explicit overrides:

| Setting | Fallback | Description |
|---------|----------|-------------|
| `migrations.postgres.host` | `api.configmap.POSTGRES_HOST` | PostgreSQL host |
| `migrations.postgres.port` | `api.configmap.POSTGRES_PORT` | PostgreSQL port (default `"5432"`) |
| `migrations.postgres.user` | `api.configmap.POSTGRES_USER` | PostgreSQL user |
| `migrations.postgres.database` | `api.configmap.POSTGRES_NAME` | PostgreSQL database name |
| `migrations.postgres.sslMode` | `api.configmap.POSTGRES_SSLMODE` | SSL mode (default `"disable"`) |
| `migrations.postgres.password` | N/A | Direct password (not recommended) |
| `migrations.postgres.passwordSecret.name` | `""` | Secret name for password |
| `migrations.postgres.passwordSecret.key` | `POSTGRES_PASSWORD` | Secret key for password |

> **Warning:** The chart will fail with a descriptive error if `migrations.postgres.host` or `migrations.postgres.user` cannot be resolved from either source.

**Resource defaults:**

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    memory: 256Mi
```

**Example migrations configuration (inheriting from API):**

```yaml
api:
  enabled: true
  configmap:
    POSTGRES_HOST: "postgres.database.svc.cluster.local"
    POSTGRES_USER: "consignado"
    POSTGRES_NAME: "consignado_db"
    POSTGRES_SSLMODE: "require"
  secrets:
    POSTGRES_PASSWORD: "changeme"

migrations:
  enabled: true
```

**Example migrations configuration (explicit overrides):**

```yaml
api:
  enabled: true

migrations:
  enabled: true
  postgres:
    host: "postgres-primary.database.svc.cluster.local"
    port: "5432"
    user: "migration_user"
    database: "consignado_db"
    sslMode: "require"
    passwordSecret:
      name: "postgres-migration-secret"
      key: "password"
```

### 5. Ingress configuration

The chart provides a single Ingress resource that routes:
- API paths (`/v1`, `/health`, `/readyz`, `/version`, `/metrics`) to the API service
- Root path (`/`) to the UI service

This ensures the UI and API share the same origin, allowing the UI to call the API without CORS issues.

**Key configuration:**

| Flag | Default | Description |
|------|---------|-------------|
| `ingress.enabled` | `false` | Enable the Ingress resource |
| `ingress.className` | `""` | IngressClass name |
| `ingress.hosts[].host` | `""` | Hostname (required) |

> **Important:** `ingress.enabled` requires at least one of `api.enabled` or `ui.enabled` to be `true`. The chart will fail if the ingress is enabled without any backend services.

**Default API paths:**

```yaml
apiPaths:
  - path: /v1
    pathType: Prefix
  - path: /health
    pathType: Exact
  - path: /readyz
    pathType: Exact
  - path: /version
    pathType: Exact
  - path: /metrics
    pathType: Exact
```

**Default UI path:**

```yaml
uiPath:
  path: /
  pathType: Prefix
```

**Example ingress configuration:**

```yaml
api:
  enabled: true

ui:
  enabled: true

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: "consignado.example.com"
  tls:
    - secretName: "consignado-tls"
      hosts:
        - "consignado.example.com"
```

**Resulting ingress behavior:**

| Path | Backend | Service Port |
|------|---------|--------------|
| `/v1/*` | API | 8080 |
| `/health` | API | 8080 |
| `/readyz` | API | 8080 |
| `/version` | API | 8080 |
| `/metrics` | API | 8080 |
| `/*` | UI | 8080 |

> **Note:** The UI path uses `pathType: Prefix` and will match all paths not explicitly routed to the API. Ensure API paths are listed before the UI path in the ingress rule.

### 6. Security hardening

All components use hardened security contexts aligned with the Pod Security Standards (restricted profile).

**API security context (distroless):**

```yaml
apiSecurityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
  seccompProfile:
    type: RuntimeDefault
```

**UI security context (nginx-unprivileged):**

```yaml
uiSecurityContext:
  runAsNonRoot: true
  runAsUser: 101
  runAsGroup: 101
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
  seccompProfile:
    type: RuntimeDefault
```

**Additional security features:**

- `automountServiceAccountToken: false` on all pods
- ServiceAccount created by default (`serviceAccount.create: true`)
- Image pull secrets support (`imagePullSecrets`)
- Read-only root filesystems for all containers
- UI mounts `/tmp` as an emptyDir for nginx temporary files

## Deployment Scenarios

### Scenario 1: API only

Deploy only the API component without the UI or migrations.

**Use case:** Headless API deployment, external UI, or API-only testing.

**Configuration:**

```yaml
api:
  enabled: true
  configmap:
    POSTGRES_HOST: "postgres.database.svc.cluster.local"
    POSTGRES_USER: "consignado"
    POSTGRES_NAME: "consignado_db"
    POSTGRES_SSLMODE: "require"
    REDIS_HOST: "redis.cache.svc.cluster.local:6379"
  secrets:
    POSTGRES_PASSWORD: "changeme"
```

**Deployed resources:**

- Deployment: `br-consignado-gw-api`
- Service: `br-consignado-gw-api`
- ConfigMap: `br-consignado-gw-api`
- Secret: `br-consignado-gw-api`

### Scenario 2: API + UI with ingress

Deploy the API and UI with a shared ingress for same-origin access.

**Use case:** Full-stack deployment with operator console.

**Configuration:**

```yaml
api:
  enabled: true
  configmap:
    POSTGRES_HOST: "postgres.database.svc.cluster.local"
    POSTGRES_USER: "consignado"
    POSTGRES_NAME: "consignado_db"
    POSTGRES_SSLMODE: "require"
    REDIS_HOST: "redis.cache.svc.cluster.local:6379"
  secrets:
    POSTGRES_PASSWORD: "changeme"

ui:
  enabled: true
  configmap:
    API_BASE_URL: ""
    CASDOOR_CSP_ORIGIN: "https://auth.example.com"
    CASDOOR_ENDPOINT: "https://auth.example.com"
    CASDOOR_CLIENT_ID: "abc123"
    CASDOOR_ORG_NAME: "my-org"
    CASDOOR_APP_NAME: "consignado-gw"

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: "consignado.example.com"
  tls:
    - secretName: "consignado-tls"
      hosts:
        - "consignado.example.com"
```

**Deployed resources:**

- Deployment: `br-consignado-gw-api`, `br-consignado-gw-ui`
- Service: `br-consignado-gw-api`, `br-consignado-gw-ui`
- ConfigMap: `br-consignado-gw-api`, `br-consignado-gw-ui`
- Secret: `br-consignado-gw-api`
- Ingress: `br-consignado-gw`

### Scenario 3: Full stack with migrations

Deploy the API, UI, ingress, and migrations Job.

**Use case:** Production deployment with automated schema management.

**Configuration:**

```yaml
api:
  enabled: true
  configmap:
    POSTGRES_HOST: "postgres.database.svc.cluster.local"
    POSTGRES_USER: "consignado"
    POSTGRES_NAME: "consignado_db"
    POSTGRES_SSLMODE: "require"
    REDIS_HOST: "redis.cache.svc.cluster.local:6379"
  secrets:
    POSTGRES_PASSWORD: "changeme"

ui:
  enabled: true
  configmap:
    API_BASE_URL: ""
    CASDOOR_CSP_ORIGIN: "https://auth.example.com"
    CASDOOR_ENDPOINT: "https://auth.example.com"
    CASDOOR_CLIENT_ID: "abc123"
    CASDOOR_ORG_NAME: "my-org"
    CASDOOR_APP_NAME: "consignado-gw"

migrations:
  enabled: true

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: "consignado.example.com"
  tls:
    - secretName: "consignado-tls"
      hosts:
        - "consignado.example.com"
```

**Deployed resources:**

- Deployment: `br-consignado-gw-api`, `br-consignado-gw-ui`
- Service: `br-consignado-gw-api`, `br-consignado-gw-ui`
- ConfigMap: `br-consignado-gw-api`, `br-consignado-gw-ui`
- Secret: `br-consignado-gw-api`
- Ingress: `br-consignado-gw`
- Job: `br-consignado-gw-migrations` (PreSync)

> **Note:** The migrations Job runs before the API deployment when using ArgoCD. For Helm-only deployments, the Job runs in parallel with the Deployment.

## Configuration Reference

**Top-level settings:**

```yaml
nameOverride: "br-consignado-gw"
fullnameOverride: ""
namespaceOverride: ""

imagePullSecrets:
  - name: ghcr-credential

serviceAccount:
  create: true
  annotations: {}
  name: ""
```

**API component:**

```yaml
api:
  enabled: false
  replicaCount: 1
  revisionHistoryLimit: 10
  image:
    repository: ghcr.io/lerianstudio/br-consignado-gw
    tag: ""
    pullPolicy: IfNotPresent
  imagePullSecrets: []
  podAnnotations: {}
  service:
    type: ClusterIP
    port: 8080
    annotations: {}
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
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
  nodeSelector: {}
  tolerations: []
  affinity: {}
  configmap:
    ENV_NAME: "development"
    SERVER_ADDRESS: "0.0.0.0:8080"
    POSTGRES_HOST: ""
    POSTGRES_PORT: "5432"
    POSTGRES_USER: ""
    POSTGRES_NAME: ""
    POSTGRES_SSLMODE: ""
    REDIS_HOST: ""
    LOG_LEVEL: "info"
  secrets:
    POSTGRES_PASSWORD: ""
  useExistingSecret: false
  existingSecretName: ""
  extraEnvVars: []
```

**UI component:**

```yaml
ui:
  enabled: false
  replicaCount: 1
  revisionHistoryLimit: 10
  image:
    repository: ghcr.io/lerianstudio/br-consignado-gw-ui
    tag: ""
    pullPolicy: IfNotPresent
  imagePullSecrets: []
  podAnnotations: {}
  service:
    type: ClusterIP
    port: 8080
    annotations: {}
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      memory: 256Mi
  livenessProbe:
    path: /healthz
    initialDelaySeconds: 5
    periodSeconds: 20
    timeoutSeconds: 5
    failureThreshold: 3
  readinessProbe:
    path: /healthz
    initialDelaySeconds: 3
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  nodeSelector: {}
  tolerations: []
  affinity: {}
  configmap:
    API_BASE_URL: ""
    CASDOOR_CSP_ORIGIN: ""
    CASDOOR_ENDPOINT: ""
    CASDOOR_CLIENT_ID: ""
    CASDOOR_ORG_NAME: ""
    CASDOOR_APP_NAME: ""
    AUTH_DISABLED: "false"
```

**Ingress:**

```yaml
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: ""
  apiPaths:
    - path: /v1
      pathType: Prefix
    - path: /health
      pathType: Exact
    - path: /readyz
      pathType: Exact
    - path: /version
      pathType: Exact
    - path: /metrics
      pathType: Exact
  uiPath:
    path: /
    pathType: Prefix
  tls: []
```

**Migrations:**

```yaml
migrations:
  enabled: false
  image:
    repository: ghcr.io/lerianstudio/br-consignado-gw-migrations
    tag: ""
    pullPolicy: IfNotPresent
  imagePullSecrets: []
  postgres:
    host: ""
    port: ""
    user: ""
    database: ""
    sslMode: ""
    password: ""
    passwordSecret:
      name: ""
      key: POSTGRES_PASSWORD
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

**Security contexts:**

```yaml
apiSecurityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
  seccompProfile:
    type: RuntimeDefault

uiSecurityContext:
  runAsNonRoot: true
  runAsUser: 101
  runAsGroup: 101
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
  seccompProfile:
    type: RuntimeDefault
```

## Migration Steps

This is the initial release. No migration from a previous version is required.

**To install the chart for the first time:**

1. Create a `values.yaml` file with your desired configuration (see [Deployment Scenarios](#deployment-scenarios))

2. Create the namespace:

```bash
kubectl create namespace br-consignado-gw
```

3. Create the image pull secret (if using private registries):

```bash
kubectl create secret docker-registry ghcr-credential \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<token> \
  -n br-consignado-gw
```

4. Install the chart:

```bash
helm install br-consignado-gw oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm \
  --version 1.0.0 \
  -n br-consignado-gw \
  -f values.yaml
```

> **Note:** Replace `<username>` and `<token>` with your GitHub credentials if the images are in a private registry.

## Preview changes before upgrading

```bash
helm diff upgrade br-consignado-gw oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm --version 1.0.0 -n br-consignado-gw
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-consignado-gw oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm --version 1.0.0 -n br-consignado-gw
```
