# Helm Upgrade from v6.x to v7.x

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. Removal of onboarding and transaction services](#1-removal-of-onboarding-and-transaction-services)
  - [2. Removal of console service](#2-removal-of-console-service)
  - [3. Template helper functions removed](#3-template-helper-functions-removed)
  - [4. NOTES.txt updated for ledger-only deployment](#4-notestxt-updated-for-ledger-only-deployment)
- **[Features](#features)**
  - [1. New ledger probe configuration](#1-new-ledger-probe-configuration)
  - [2. New CRM probe configuration](#2-new-crm-probe-configuration)
  - [3. New ledger environment variables](#3-new-ledger-environment-variables)
  - [4. New multi-tenant configuration](#4-new-multi-tenant-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### 1. Removal of onboarding and transaction services

The `onboarding` and `transaction` services have been completely removed from the chart. All functionality has been consolidated into the `ledger` service.

#### What was removed

| Component | v6.4.1 | v7.0.0 |
|-----------|--------|--------|
| `onboarding` service | Deployed separately | **Removed** |
| `transaction` service | Deployed separately | **Removed** |
| `onboarding` templates | Full deployment, service, ingress, configmap, secrets | **Removed** |
| `transaction` templates | Full deployment, service, ingress, configmap, secrets | **Removed** |

#### Configuration removed from values.yaml

**Before (v6.4.1):**

```yaml
onboarding:
  name: onboarding
  enabled: false
  replicaCount: 2
  image:
    repository: lerianstudio/midaz-onboarding
    tag: "3.5.3"
  service:
    port: 3000
  configmap:
    MONGO_URI: "mongodb"
    DB_HOST: "midaz-postgresql-primary.midaz.svc.cluster.local."
    # ... (385+ lines of configuration)
  secrets:
    MONGO_PASSWORD: "lerian"
    DB_PASSWORD: "lerian"

transaction:
  name: transaction
  enabled: false
  replicaCount: 1
  image:
    repository: lerianstudio/midaz-transaction
    tag: "3.5.3"
  service:
    port: 3001
    grpcPort: 3011
  configmap:
    RABBITMQ_HOST: "midaz-rabbitmq.midaz.svc.cluster.local."
    MONGO_URI: "mongodb"
    # ... (385+ lines of configuration)
  secrets:
    MONGO_PASSWORD: "lerian"
    RABBITMQ_DEFAULT_PASS: "lerian"
```

**After (v7.0.0):**

```yaml
ledger:
  # All onboarding and transaction functionality is now in ledger
  name: ledger
  enabled: true
  # ... ledger configuration only
```

> **Warning:** If you have `onboarding.enabled: true` or `transaction.enabled: true` in your values.yaml, remove these sections entirely before upgrading. The chart will fail to render if these values are present.

#### Migration impact

- **Ingress routes**: If you configured ingress for `onboarding` or `transaction`, you must reconfigure them to point to the `ledger` service
- **Service discovery**: Any external services calling `midaz-onboarding:3000` or `midaz-transaction:3001` must be updated to call `midaz-ledger:3002`
- **Secrets and ConfigMaps**: All configuration previously split between onboarding and transaction is now consolidated in ledger's ConfigMap and Secrets
- **Database connections**: The ledger service now handles all database connections that were previously managed by separate services

#### Port changes

| Service | v6.4.1 Port | v7.0.0 Port |
|---------|-------------|-------------|
| Onboarding HTTP | 3000 | **Removed** (use ledger 3002) |
| Transaction HTTP | 3001 | **Removed** (use ledger 3002) |
| Transaction gRPC | 3011 | **Removed** (use ledger 3012) |
| Ledger HTTP | 3002 | 3002 (unchanged) |
| Ledger gRPC | 3012 | 3012 (unchanged) |

### 2. Removal of console service

The `console` service has been completely removed from the chart.

> **Important:** If you were using the midaz-console UI, you must deploy it separately or use an external console solution. The console is no longer bundled with the core ledger chart.

#### What was removed

- All `templates/console/` templates (deployment, service, ingress, configmap, secrets)
- All `console.*` values from values.yaml
- NGINX proxy configuration for plugin UIs
- Console-related helper functions

### 3. Template helper functions removed

The following Helm template helper functions have been removed:

**Removed helpers:**

```yaml
# _helpers.tpl
{{- define "midaz-onboarding.fullname" -}}
{{- define "midaz-onboarding.serviceAccountName" -}}
{{- define "midaz-transaction.fullname" -}}
{{- define "midaz-transaction.serviceAccountName" -}}
{{- define "onboarding.defaultTag" -}}
{{- define "onboarding.versionLabelValue" -}}
{{- define "migration.allowAllServices" -}}
{{- define "onboarding.shouldDeploy" -}}
{{- define "transaction.shouldDeploy" -}}
{{- define "onboarding.ingress.targetService" -}}
{{- define "onboarding.ingress.targetPort" -}}
{{- define "transaction.ingress.targetService" -}}
{{- define "transaction.ingress.targetPort" -}}
```

> **Note:** If you have custom templates that reference these helpers, you must update them before upgrading.

### 4. NOTES.txt updated for ledger-only deployment

The post-install notes have been simplified to reflect the ledger-only architecture.

**Before (v6.4.1):**

```
Accessing midaz-console, midaz-onboarding, and midaz-transaction using port-forward in Helm

Steps:
1. Port-Forward to midaz-console:
   kubectl port-forward svc/midaz-console 8081:8081

2. Port-Forward to midaz-onboarding:
   kubectl port-forward svc/midaz-onboarding 3000:3000

3. Port-Forward to midaz-transaction:
   kubectl port-forward svc/midaz-transaction 3001:3001
```

**After (v7.0.0):**

```
Accessing midaz ledger services using port-forward in Helm

Steps:
1. Port-Forward to midaz-ledger:
   kubectl port-forward svc/midaz-ledger 3002:3002
```

## Features

### 1. New ledger probe configuration

Readiness and liveness probes for the ledger service are now fully configurable via values.yaml.

#### New configuration structure

```yaml
ledger:
  readinessProbe: {}
  livenessProbe: {}
```

#### Available probe settings

| Setting | Default | Description |
|---------|---------|-------------|
| `path` | `/readyz` (readiness), `/health` (liveness) | HTTP endpoint path |
| `initialDelaySeconds` | `10` | Seconds before first probe |
| `periodSeconds` | `5` | Seconds between probes |
| `timeoutSeconds` | `1` | Probe timeout |
| `successThreshold` | `1` | Consecutive successes required |
| `failureThreshold` | `3` | Consecutive failures before restart |

#### Example configuration

```yaml
ledger:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 15
    periodSeconds: 10
    timeoutSeconds: 2
    successThreshold: 1
    failureThreshold: 5
  livenessProbe:
    path: /health
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 2
    successThreshold: 1
    failureThreshold: 3
```

> **Note:** If you don't specify these values, the chart uses the defaults shown in the table above.

### 2. New CRM probe configuration

The CRM service now supports the same configurable probe structure as ledger.

#### Template changes

**Before (v6.4.1):**

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: {{ .Values.crm.service.port }}
  initialDelaySeconds: 10
  periodSeconds: 5
livenessProbe:
  initialDelaySeconds: 10
  periodSeconds: 5
  httpGet:
    path: /health
    port: {{ .Values.crm.service.port }}
```

**After (v7.0.0):**

```yaml
readinessProbe:
  httpGet:
    path: {{ .Values.crm.readinessProbe.path | default "/readyz" }}
    port: {{ .Values.crm.service.port }}
  initialDelaySeconds: {{ .Values.crm.readinessProbe.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.crm.readinessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.crm.readinessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ .Values.crm.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.crm.readinessProbe.failureThreshold | default 3 }}
livenessProbe:
  httpGet:
    path: {{ .Values.crm.livenessProbe.path | default "/health" }}
    port: {{ .Values.crm.service.port }}
  initialDelaySeconds: {{ .Values.crm.livenessProbe.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.crm.livenessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.crm.livenessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ .Values.crm.livenessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.crm.livenessProbe.failureThreshold | default 3 }}
```

#### Configuration example

```yaml
crm:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: /health
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
```

### 3. New ledger environment variables

Several new environment variables have been added to the ledger ConfigMap.

#### New variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEPLOYMENT_MODE` | `local` | Deployment environment mode |
| `SWAGGER_TITLE` | `""` | Swagger API documentation title |
| `SWAGGER_DESCRIPTION` | `""` | Swagger API documentation description |
| `SWAGGER_VERSION` | `{{ .Chart.AppVersion }}` | API version in Swagger docs |
| `SWAGGER_HOST` | `""` | Swagger host URL |
| `SWAGGER_BASE_PATH` | `""` | Swagger base path |
| `SWAGGER_SCHEMES` | `""` | Swagger URL schemes (http, https) |
| `SWAGGER_LEFT_DELIM` | `""` | Swagger template left delimiter |
| `SWAGGER_RIGHT_DELIM` | `""` | Swagger template right delimiter |

#### Configuration example

```yaml
ledger:
  configmap:
    DEPLOYMENT_MODE: "production"
    SWAGGER_TITLE: "Midaz Ledger API"
    SWAGGER_DESCRIPTION: "Core ledger service API"
    SWAGGER_HOST: "api.example.com"
    SWAGGER_BASE_PATH: "/v1"
    SWAGGER_SCHEMES: "https"
```

> **Note:** These variables control the Swagger/OpenAPI documentation generation. Leave them empty to use application defaults.

### 4. New multi-tenant configuration

Enhanced multi-tenant support with circuit breaker and Redis caching.

#### New multi-tenant variables

| Variable | Default | Required When | Description |
|----------|---------|---------------|-------------|
| `MULTI_TENANT_ENABLED` | `false` | - | Enable multi-tenant mode |
| `MULTI_TENANT_URL` | - | `MULTI_TENANT_ENABLED=true` | Multi-tenant service URL |
| `MULTI_TENANT_SERVICE_NAME` | `ledger` | - | Service identifier |
| `MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD` | `5` | - | Failures before circuit opens |
| `MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC` | `30` | - | Circuit breaker timeout |
| `MULTI_TENANT_REDIS_HOST` | - | `MULTI_TENANT_ENABLED=true` | Redis host for tenant cache |

#### Configuration example

```yaml
ledger:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_URL: "http://tenant-service.default.svc.cluster.local:8080"
    MULTI_TENANT_SERVICE_NAME: "ledger"
    MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"
    MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: "30"
    MULTI_TENANT_REDIS_HOST: "redis.default.svc.cluster.local:6379"
```

> **Warning:** When `MULTI_TENANT_ENABLED` is set to `"true"`, both `MULTI_TENANT_URL` and `MULTI_TENANT_REDIS_HOST` are required. The chart will fail to render if these are not provided.

#### Validation logic

The chart now includes validation for multi-tenant configuration:

```yaml
{{- if eq (.Values.ledger.configmap.MULTI_TENANT_ENABLED | default "false" | toString) "true" }}
MULTI_TENANT_URL: {{ required "ledger.configmap.MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true" .Values.ledger.configmap.MULTI_TENANT_URL | quote }}
MULTI_TENANT_REDIS_HOST: {{ required "ledger.configmap.MULTI_TENANT_REDIS_HOST is required when MULTI_TENANT_ENABLED=true" .Values.ledger.configmap.MULTI_TENANT_REDIS_HOST | quote }}
{{- end }}
```

## Migration Steps

Follow these steps to migrate from v6.4.1 to v7.0.0:

### Step 1: Back up existing configuration

```bash
helm get values midaz -n midaz > midaz-v6-values.yaml
```

### Step 2: Remove deprecated services from values

Edit your values file and remove the following sections entirely:

- `onboarding.*`
- `transaction.*`
- `console.*`
- `nginx.*`
- `otel-collector-lerian.*`

### Step 3: Update service references

If you have external services or ingress rules pointing to:

- `midaz-onboarding:3000` → Update to `midaz-ledger:3002`
- `midaz-transaction:3001` → Update to `midaz-ledger:3002`
- `midaz-transaction:3011` (gRPC) → Update to `midaz-ledger:3012`

### Step 4: Migrate secrets and configuration

If you were using `onboarding.secrets` or `transaction.secrets`, consolidate them into `ledger.secrets`:

```yaml
ledger:
  secrets:
    MONGO_PASSWORD: "your-mongo-password"
    DB_PASSWORD: "your-postgres-password"
    DB_REPLICA_PASSWORD: "your-replica-password"
    RABBITMQ_DEFAULT_PASS: "your-rabbitmq-password"
    REDIS_PASSWORD: "your-redis-password"
```

### Step 5: Configure probes (optional)

If you need custom probe settings:

```yaml
ledger:
  readinessProbe:
    initialDelaySeconds: 15
    periodSeconds: 10
  livenessProbe:
    initialDelaySeconds: 30
    periodSeconds: 10
```

### Step 6: Configure multi-tenant (if needed)

If you're enabling multi-tenant mode:

```yaml
ledger:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_URL: "http://your-tenant-service:8080"
    MULTI_TENANT_REDIS_HOST: "your-redis-host:6379"
```

### Step 7: Update ingress configuration

If you have ingress enabled, update your configuration:

**Before (v6.4.1):**

```yaml
onboarding:
  ingress:
    enabled: true
    hosts:
      - host: onboarding.example.com
        paths:
          - path: /
            pathType: Prefix

transaction:
  ingress:
    enabled: true
    hosts:
      - host: transaction.example.com
        paths:
          - path: /
            pathType: Prefix
```

**After (v7.0.0):**

```yaml
ledger:
  ingress:
    enabled: true
    hosts:
      - host: api.example.com
        paths:
          - path: /
            pathType: Prefix
```

### Step 8: Verify MongoDB roles

Ensure your MongoDB configuration includes all required database roles:

```yaml
global:
  mongodb:
    auth:
      databases:
        - role: "readWrite"
          db: "ledger"
        - role: "readWrite"
          db: "transaction"
        - role: "readWrite"
          db: "crm"
```

> **Note:** The ledger service now requires access to all three databases.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 7.0.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 7.0.0 -n midaz
```
