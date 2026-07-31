# Helm Upgrade from v0.x to v1.x

## Topics

- **[Breaking Changes](#breaking-changes)**
- **[Features](#features)**
  - [1. Multi-component architecture](#1-multi-component-architecture)
  - [2. API component](#2-api-component)
  - [3. UI component](#3-ui-component)
  - [4. Database migrations](#4-database-migrations)
  - [5. Shared ingress](#5-shared-ingress)
  - [6. Security contexts](#6-security-contexts)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: API only](#scenario-1-api-only)
  - [Scenario 2: API + UI with shared ingress](#scenario-2-api--ui-with-shared-ingress)
  - [Scenario 3: Full stack with migrations](#scenario-3-full-stack-with-migrations)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

This is the **initial release** of the `br-consignado-gw-helm` chart (v1.0.0). There is no v0.0.0 deployed in production. The chart is being introduced for the first time with all components disabled by default.

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Chart existence | Does not exist | Initial release |
| Default state | N/A | All components disabled (`api.enabled: false`, `ui.enabled: false`, `migrations.enabled: false`) |

> **Important:** Operators must explicitly enable each component they wish to deploy. Installing this chart without configuration changes will result in no workloads being created.

## Features

### 1. Multi-component architecture

The chart manages three independent components under a single release:

- **API**: The `br-consignado-gw` backend service
- **UI**: A Vite-based operator console served via nginx
- **Migrations**: An ArgoCD PreSync Job that runs database migrations

Each component has its own:
- Deployment/Job manifest
- Service (API and UI only)
- ConfigMap
- Image repository and tag
- Resource limits and probes
- Security context

**Component naming convention:**

```yaml
# API resources are suffixed with -api
br-consignado-gw-api (Deployment)
br-consignado-gw-api (Service)
br-consignado-gw-api (ConfigMap)

# UI resources are suffixed with -ui
br-consignado-gw-ui (Deployment)
br-consignado-gw-ui (Service)
br-consignado-gw-ui (ConfigMap)

# Migrations resource is suffixed with -migrations
br-consignado-gw-migrations (Job)
```

### 2. API component

The API component deploys the `ghcr.io/lerianstudio/br-consignado-gw` distroless image.

**Default configuration:**

```yaml
api:
  enabled: false
  replicaCount: 1
  revisionHistoryLimit: 10
  image:
    repository: ghcr.io/lerianstudio/br-consignado-gw
    tag: ""  # Defaults to Chart.appVersion (1.3.0-beta.33)
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8080
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      memory: 512Mi
```

**Health checks:**

| Probe | Path | Initial Delay | Period | Timeout | Failure Threshold |
|-------|------|---------------|--------|---------|-------------------|
| Liveness | `/health` | 15s | 20s | 5s | 3 |
| Readiness | `/readyz` | 5s | 10s | 5s | 3 |

**Environment variables:**

The API receives configuration via a ConfigMap and a Secret. All ConfigMap keys are rendered verbatim from `api.configmap`:

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV_NAME` | `development` | Environment name for logging and telemetry |
| `SERVER_ADDRESS` | `0.0.0.0:8080` | HTTP server bind address |
| `POSTGRES_HOST` | `""` (required) | PostgreSQL server hostname |
| `POSTGRES_PORT` | `5432` | PostgreSQL server port |
| `POSTGRES_USER` | `""` (required) | PostgreSQL username |
| `POSTGRES_NAME` | `""` (required) | PostgreSQL database name |
| `POSTGRES_SSLMODE` | `""` (required) | PostgreSQL SSL mode (`disable`, `require`, `verify-ca`, `verify-full`) |
| `REDIS_HOST` | `""` (required) | Redis server hostname |
| `LOG_LEVEL` | `info` | Log verbosity (`debug`, `info`, `warn`, `error`) |
| `VERSION` | Chart.appVersion | Injected automatically from image tag or appVersion |

**Secrets:**

The chart creates a Secret named `br-consignado-gw-api` containing:

| Key | Source | Description |
|-----|--------|-------------|
| `POSTGRES_PASSWORD` | `api.secrets.POSTGRES_PASSWORD` | PostgreSQL password |

**Using an existing secret:**

```yaml
api:
  useExistingSecret: true
  existingSecretName: "my-existing-secret"
```

> **Warning:** When `api.useExistingSecret: true`, the chart will **not** create a Secret. The existing secret must contain the `POSTGRES_PASSWORD` key.

**Extra environment variables:**

Operators can inject additional environment variables via `api.extraEnvVars`:

```yaml
api:
  extraEnvVars:
    - name: CUSTOM_VAR
      value: "custom-value"
    - name: SECRET_VAR
      valueFrom:
        secretKeyRef:
          name: external-secret
          key: secret-key
```

### 3. UI component

The UI component deploys the `ghcr.io/lerianstudio/br-consignado-gw-ui` nginx-unprivileged image serving a Vite SPA.

**Default configuration:**

```yaml
ui:
  enabled: false
  replicaCount: 1
  revisionHistoryLimit: 10
  image:
    repository: ghcr.io/lerianstudio/br-consignado-gw-ui
    tag: ""  # Defaults to Chart.appVersion (1.3.0-beta.33)
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8080
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      memory: 256Mi
```

**Health checks:**

| Probe | Path | Initial Delay | Period | Timeout | Failure Threshold |
|-------|------|---------------|--------|---------|-------------------|
| Liveness | `/healthz` | 5s | 20s | 5s | 3 |
| Readiness | `/healthz` | 3s | 10s | 5s | 3 |

**Environment variables:**

The UI ConfigMap contains public browser runtime configuration:

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE_URL` | `""` (empty = same origin) | API base URL; must remain empty to avoid CORS token leakage |
| `CASDOOR_CSP_ORIGIN` | `""` (required if auth enabled) | Casdoor issuer origin (no path) |
| `CASDOOR_ENDPOINT` | `""` (required if auth enabled) | Full Casdoor endpoint URL |
| `CASDOOR_CLIENT_ID` | `""` (required if auth enabled) | Casdoor OAuth2 client ID |
| `CASDOOR_ORG_NAME` | `""` (required if auth enabled) | Casdoor organization name |
| `CASDOOR_APP_NAME` | `""` (required if auth enabled) | Casdoor application name |
| `AUTH_DISABLED` | `false` | Set to `true` to disable authentication |

> **Important:** The UI **rejects** a cross-origin `API_BASE_URL` to prevent bearer token leakage. Always leave `API_BASE_URL` empty and use the shared ingress to serve both components on the same origin.

**Nginx configuration:**

The UI image is built on `nginxinc/nginx-unprivileged:alpine` and pins `worker_processes=1` to avoid over-provisioning on high-core cluster nodes. The container mounts `/tmp` as an emptyDir because nginx requires writable temporary paths while the root filesystem is read-only.

### 4. Database migrations

The migrations component runs as an ArgoCD PreSync Job using the `ghcr.io/lerianstudio/br-consignado-gw-migrations` image.

**Default configuration:**

```yaml
migrations:
  enabled: false
  image:
    repository: ghcr.io/lerianstudio/br-consignado-gw-migrations
    tag: ""  # Defaults to Chart.appVersion (1.3.0-beta.33)
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

**PostgreSQL connection:**

The Job constructs a connection string from these values:

| Field | Source | Fallback | Description |
|-------|--------|----------|-------------|
| `host` | `migrations.postgres.host` | `api.configmap.POSTGRES_HOST` | PostgreSQL hostname |
| `port` | `migrations.postgres.port` | `api.configmap.POSTGRES_PORT` | PostgreSQL port (default: `5432`) |
| `user` | `migrations.postgres.user` | `api.configmap.POSTGRES_USER` | PostgreSQL username |
| `database` | `migrations.postgres.database` | `api.configmap.POSTGRES_NAME` | Database name |
| `sslMode` | `migrations.postgres.sslMode` | `api.configmap.POSTGRES_SSLMODE` | SSL mode (default: `disable`) |
| `password` | `migrations.postgres.password` | N/A | Inline password (not recommended) |
| `passwordSecret.name` | `migrations.postgres.passwordSecret.name` | `""` | Secret name containing password |
| `passwordSecret.key` | `migrations.postgres.passwordSecret.key` | `POSTGRES_PASSWORD` | Secret key |

**Password sources (in order of precedence):**

1. `migrations.postgres.password` (inline, not recommended)
2. `migrations.postgres.passwordSecret.name` (recommended)
3. Falls back to the API secret if neither is set

> **Warning:** `migrations.enabled: true` requires `api.enabled: true`. The chart will fail validation if migrations are enabled without the API.

**Example configuration:**

```yaml
migrations:
  enabled: true
  postgres:
    passwordSecret:
      name: "postgres-credentials"
      key: "password"
```

### 5. Shared ingress

The chart provides a single Ingress resource that routes:
- API paths (`/v1`, `/health`, `/readyz`, `/version`, `/metrics`) to the API service
- Root path (`/`) to the UI service

**Default configuration:**

```yaml
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: ""  # Required when ingress.enabled=true
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

**Routing behavior:**

- If `api.enabled: true` and `ui.enabled: false`: Only API paths are routed
- If `api.enabled: false` and `ui.enabled: true`: Only the UI path is routed
- If both are enabled: All paths are routed to their respective services
- If neither is enabled and `ingress.enabled: true`: The chart will fail validation

**Example with TLS:**

```yaml
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

### 6. Security contexts

The chart enforces hardened security contexts for both components.

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

> **Note:** The UI mounts `/tmp` as an emptyDir to satisfy nginx's requirement for writable temporary paths while maintaining a read-only root filesystem.

## Deployment Scenarios

### Scenario 1: API only

Deploy the API without the UI or migrations.

**values.yaml:**

```yaml
api:
  enabled: true
  configmap:
    ENV_NAME: "production"
    POSTGRES_HOST: "postgres.database.svc.cluster.local"
    POSTGRES_PORT: "5432"
    POSTGRES_USER: "consignado"
    POSTGRES_NAME: "consignado_db"
    POSTGRES_SSLMODE: "require"
    REDIS_HOST: "redis.cache.svc.cluster.local"
    LOG_LEVEL: "info"
  secrets:
    POSTGRES_PASSWORD: "changeme"

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: "api.consignado.example.com"
```

**Upgrade command:**

```bash
helm upgrade --install br-consignado-gw-helm \
  oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm-helm \
  --version 1.0.0 \
  -n br-consignado-gw \
  -f values.yaml
```

### Scenario 2: API + UI with shared ingress

Deploy both components on the same origin.

**values.yaml:**

```yaml
api:
  enabled: true
  configmap:
    ENV_NAME: "production"
    POSTGRES_HOST: "postgres.database.svc.cluster.local"
    POSTGRES_PORT: "5432"
    POSTGRES_USER: "consignado"
    POSTGRES_NAME: "consignado_db"
    POSTGRES_SSLMODE: "require"
    REDIS_HOST: "redis.cache.svc.cluster.local"
    LOG_LEVEL: "info"
  secrets:
    POSTGRES_PASSWORD: "changeme"

ui:
  enabled: true
  configmap:
    API_BASE_URL: ""  # Same origin
    CASDOOR_CSP_ORIGIN: "https://auth.example.com"
    CASDOOR_ENDPOINT: "https://auth.example.com"
    CASDOOR_CLIENT_ID: "abc123"
    CASDOOR_ORG_NAME: "lerian"
    CASDOOR_APP_NAME: "consignado"
    AUTH_DISABLED: "false"

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

**Upgrade command:**

```bash
helm upgrade --install br-consignado-gw-helm \
  oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm-helm \
  --version 1.0.0 \
  -n br-consignado-gw \
  -f values.yaml
```

### Scenario 3: Full stack with migrations

Deploy all components including the PreSync migrations Job.

**values.yaml:**

```yaml
api:
  enabled: true
  configmap:
    ENV_NAME: "production"
    POSTGRES_HOST: "postgres.database.svc.cluster.local"
    POSTGRES_PORT: "5432"
    POSTGRES_USER: "consignado"
    POSTGRES_NAME: "consignado_db"
    POSTGRES_SSLMODE: "require"
    REDIS_HOST: "redis.cache.svc.cluster.local"
    LOG_LEVEL: "info"
  secrets:
    POSTGRES_PASSWORD: "changeme"

ui:
  enabled: true
  configmap:
    API_BASE_URL: ""
    CASDOOR_CSP_ORIGIN: "https://auth.example.com"
    CASDOOR_ENDPOINT: "https://auth.example.com"
    CASDOOR_CLIENT_ID: "abc123"
    CASDOOR_ORG_NAME: "lerian"
    CASDOOR_APP_NAME: "consignado"
    AUTH_DISABLED: "false"

migrations:
  enabled: true
  postgres:
    passwordSecret:
      name: "postgres-credentials"
      key: "password"

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

**Create the password secret:**

```bash
kubectl create secret generic postgres-credentials \
  --from-literal=password='changeme' \
  -n br-consignado-gw
```

**Upgrade command:**

```bash
helm upgrade --install br-consignado-gw-helm \
  oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm-helm \
  --version 1.0.0 \
  -n br-consignado-gw \
  -f values.yaml
```

> **Note:** The migrations Job will run as an ArgoCD PreSync hook. If you are not using ArgoCD, the Job will run as a normal Kubernetes Job before the Deployment rollout.

## Configuration Reference

**Global settings:**

| Field | Default | Description |
|-------|---------|-------------|
| `nameOverride` | `br-consignado-gw` | Override the chart name |
| `fullnameOverride` | `""` | Override the full resource name |
| `namespaceOverride` | `""` | Override the release namespace |
| `imagePullSecrets` | `[{name: ghcr-credential}]` | Image pull secrets for all components |
| `serviceAccount.create` | `true` | Create a ServiceAccount |
| `serviceAccount.annotations` | `{}` | ServiceAccount annotations |
| `serviceAccount.name` | `""` | ServiceAccount name (auto-generated if empty) |

**API component:**

| Field | Default | Description |
|-------|---------|-------------|
| `api.enabled` | `false` | Enable the API component |
| `api.replicaCount` | `1` | Number of API replicas |
| `api.revisionHistoryLimit` | `10` | Number of ReplicaSets to retain |
| `api.image.repository` | `ghcr.io/lerianstudio/br-consignado-gw` | API image repository |
| `api.image.tag` | `""` | API image tag (defaults to appVersion) |
| `api.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `api.imagePullSecrets` | `[]` | Component-specific pull secrets |
| `api.podAnnotations` | `{}` | Pod annotations |
| `api.service.type` | `ClusterIP` | Service type |
| `api.service.port` | `8080` | Service port |
| `api.service.annotations` | `{}` | Service annotations |
| `api.resources.requests.cpu` | `100m` | CPU request |
| `api.resources.requests.memory` | `128Mi` | Memory request |
| `api.resources.limits.memory` | `512Mi` | Memory limit |
| `api.livenessProbe.path` | `/health` | Liveness probe path |
| `api.livenessProbe.initialDelaySeconds` | `15` | Liveness initial delay |
| `api.livenessProbe.periodSeconds` | `20` | Liveness period |
| `api.livenessProbe.timeoutSeconds` | `5` | Liveness timeout |
| `api.livenessProbe.failureThreshold` | `3` | Liveness failure threshold |
| `api.readinessProbe.path` | `/readyz` | Readiness probe path |
| `api.readinessProbe.initialDelaySeconds` | `5` | Readiness initial delay |
| `api.readinessProbe.periodSeconds` | `10` | Readiness period |
| `api.readinessProbe.timeoutSeconds` | `5` | Readiness timeout |
| `api.readinessProbe.failureThreshold` | `3` | Readiness failure threshold |
| `api.nodeSelector` | `{}` | Node selector |
| `api.tolerations` | `[]` | Tolerations |
| `api.affinity` | `{}` | Affinity rules |
| `api.configmap` | See [API environment variables](#2-api-component) | ConfigMap data |
| `api.secrets.POSTGRES_PASSWORD` | `""` | PostgreSQL password |
| `api.useExistingSecret` | `false` | Use an existing Secret |
| `api.existingSecretName` | `""` | Existing Secret name |
| `api.extraEnvVars` | `[]` | Additional environment variables |

**UI component:**

| Field | Default | Description |
|-------|---------|-------------|
| `ui.enabled` | `false` | Enable the UI component |
| `ui.replicaCount` | `1` | Number of UI replicas |
| `ui.revisionHistoryLimit` | `10` | Number of ReplicaSets to retain |
| `ui.image.repository` | `ghcr.io/lerianstudio/br-consignado-gw-ui` | UI image repository |
| `ui.image.tag` | `""` | UI image tag (defaults to appVersion) |
| `ui.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `ui.imagePullSecrets` | `[]` | Component-specific pull secrets |
| `ui.podAnnotations` | `{}` | Pod annotations |
| `ui.service.type` | `ClusterIP` | Service type |
| `ui.service.port` | `8080` | Service port |
| `ui.service.annotations` | `{}` | Service annotations |
| `ui.resources.requests.cpu` | `50m` | CPU request |
| `ui.resources.requests.memory` | `128Mi` | Memory request |
| `ui.resources.limits.memory` | `256Mi` | Memory limit |
| `ui.livenessProbe.path` | `/healthz` | Liveness probe path |
| `ui.livenessProbe.initialDelaySeconds` | `5` | Liveness initial delay |
| `ui.livenessProbe.periodSeconds` | `20` | Liveness period |
| `ui.livenessProbe.timeoutSeconds` | `5` | Liveness timeout |
| `ui.livenessProbe.failureThreshold` | `3` | Liveness failure threshold |
| `ui.readinessProbe.path` | `/healthz` | Readiness probe path |
| `ui.readinessProbe.initialDelaySeconds` | `3` | Readiness initial delay |
| `ui.readinessProbe.periodSeconds` | `10` | Readiness period |
| `ui.readinessProbe.timeoutSeconds` | `5` | Readiness timeout |
| `ui.readinessProbe.failureThreshold` | `3` | Readiness failure threshold |
| `ui.nodeSelector` | `{}` | Node selector |
| `ui.tolerations` | `[]` | Tolerations |
| `ui.affinity` | `{}` | Affinity rules |
| `ui.configmap` | See [UI environment variables](#3-ui-component) | ConfigMap data |

**Ingress:**

| Field | Default | Description |
|-------|---------|-------------|
| `ingress.enabled` | `false` | Enable the Ingress |
| `ingress.className` | `""` | IngressClass name |
| `ingress.annotations` | `{}` | Ingress annotations |
| `ingress.hosts` | `[{host: ""}]` | Ingress hosts (host is required) |
| `ingress.apiPaths` | See [Shared ingress](#5-shared-ingress) | API path rules |
| `ingress.uiPath` | `{path: /, pathType: Prefix}` | UI path rule |
| `ingress.tls` | `[]` | TLS configuration |

**Migrations:**

| Field | Default | Description |
|-------|---------|-------------|
| `migrations.enabled` | `false` | Enable the migrations Job |
| `migrations.image.repository` | `ghcr.io/lerianstudio/br-consignado-gw-migrations` | Migrations image repository |
| `migrations.image.tag` | `""` | Migrations image tag (defaults to appVersion) |
| `migrations.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `migrations.imagePullSecrets` | `[]` | Component-specific pull secrets |
| `migrations.postgres.host` | `""` | PostgreSQL host (falls back to API config) |
| `migrations.postgres.port` | `""` | PostgreSQL port (falls back to API config) |
| `migrations.postgres.user` | `""` | PostgreSQL user (falls back to API config) |
| `migrations.postgres.database` | `""` | PostgreSQL database (falls back to API config) |
| `migrations.postgres.sslMode` | `""` | PostgreSQL SSL mode (falls back to API config) |
| `migrations.postgres.password` | `""` | PostgreSQL password (inline, not recommended) |
| `migrations.postgres.passwordSecret.name` | `""` | Secret name containing password |
| `migrations.postgres.passwordSecret.key` | `POSTGRES_PASSWORD` | Secret key |
| `migrations.backoffLimit` | `3` | Job backoff limit |
| `migrations.activeDeadlineSeconds` | `600` | Job active deadline |
| `migrations.ttlSecondsAfterFinished` | `600` | Job TTL after completion |
| `migrations.resources.requests.cpu` | `50m` | CPU request |
| `migrations.resources.requests.memory` | `64Mi` | Memory request |
| `migrations.resources.limits.memory` | `256Mi` | Memory limit |

**Security contexts:**

| Field | Default | Description |
|-------|---------|-------------|
| `apiSecurityContext` | See [Security contexts](#6-security-contexts) | API container security context |
| `uiSecurityContext` | See [Security contexts](#6-security-contexts) | UI container security context |

## Preview changes before upgrading

```bash
helm diff upgrade br-consignado-gw-helm oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm-helm --version 1.0.0 -n br-consignado-gw-helm
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-consignado-gw-helm oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm-helm --version 1.0.0 -n br-consignado-gw-helm
```
