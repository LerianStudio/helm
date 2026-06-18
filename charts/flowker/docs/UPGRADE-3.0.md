# Helm Upgrade from v2.x to v3.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Empty default passwords](#1-empty-default-passwords)
  - [2. Service port default changed to 4021](#2-service-port-default-changed-to-4021)
  - [3. MongoDB connection consolidated to MONGO_URI](#3-mongodb-connection-consolidated-to-mongo_uri)
  - [4. Health check endpoints changed](#4-health-check-endpoints-changed)
  - [5. Security context hardening](#5-security-context-hardening)
- **[Features](#features)**
  - [1. Multi-tenant support](#1-multi-tenant-support)
  - [2. Audit database configuration](#2-audit-database-configuration)
  - [3. Access Manager plugin authentication](#3-access-manager-plugin-authentication)
  - [4. Deployment mode and TLS controls](#4-deployment-mode-and-tls-controls)
  - [5. Feature flags and operational knobs](#5-feature-flags-and-operational-knobs)
  - [6. MongoDB TLS CA certificate support](#6-mongodb-tls-ca-certificate-support)
  - [7. Configurable health probes](#7-configurable-health-probes)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `flowker` chart upgrade from `2.0.0` to `3.0.0`. This is a **major version bump** with multiple breaking changes that require operator action before upgrading. The application image (`appVersion: 1.0.0`) is unchanged, but the chart introduces significant security improvements, multi-tenant support, and consolidates MongoDB configuration.

The upgrade is **not transparent**: default passwords are now empty (requiring explicit configuration), the service port changes to `4021`, MongoDB connection variables are consolidated into a single `MONGO_URI`, and health check endpoints have changed. Read [Breaking Changes](#breaking-changes) and [Migration Steps](#migration-steps) carefully before upgrading any environment.

## Breaking Changes

### 1. Empty default passwords

All default passwords in `values.yaml` are now empty strings, enforcing explicit configuration in production environments.

| Setting | v2.0.0 | v3.0.0 |
|---------|--------|--------|
| `global.mongodb.adminCredentials.password` | `"lerian"` | `""` |
| `global.mongodb.flowkerCredentials.password` | `"lerian"` | `""` |
| `mongodb.auth.rootPassword` | `"lerian"` | `""` |

> **Warning:** Upgrading without setting these passwords will cause the MongoDB subchart to fail. You **must** provide passwords via values overrides or existing secrets before upgrading.

**Action required:**

```yaml
global:
  mongodb:
    adminCredentials:
      password: "your-secure-admin-password"
    flowkerCredentials:
      password: "your-secure-flowker-password"

mongodb:
  auth:
    rootPassword: "your-secure-root-password"
```

Or use existing secrets:

```yaml
global:
  mongodb:
    adminCredentials:
      useExistingSecret:
        name: "mongodb-admin-secret"
        key: "password"
    flowkerCredentials:
      useExistingSecret:
        name: "mongodb-flowker-secret"
        key: "password"
```

### 2. Service port default changed to 4021

The chart default port moves from `4000` to `4021`, matching the upstream Flowker source convention (`.env.example SERVER_PORT=4021`).

| Setting | v2.0.0 | v3.0.0 |
|---------|--------|--------|
| `flowker.service.port` | `4000` | `4021` |
| `flowker.configmap.SERVER_PORT` | `"4000"` | `"4021"` |
| `flowker.configmap.SERVER_ADDRESS` | `":4000"` | `":4021"` |
| `flowker.configmap.SWAGGER_HOST` | `":4000"` | `":4021"` |

> **Warning:** Any Ingress, Service consumers, NetworkPolicy, or downstream clients pinned to port `4000` will fail after the upgrade unless you explicitly pin the port back to `4000` in your values override.

**Action required if you need to keep port 4000:**

```yaml
flowker:
  service:
    port: 4000
  configmap:
    SERVER_PORT: "4000"
    SERVER_ADDRESS: ":4000"
    SWAGGER_HOST: ":4000"
```

### 3. MongoDB connection consolidated to MONGO_URI

The previous chart exposed MongoDB via discrete environment variables (`MONGO_HOST`, `MONGO_PORT`, `MONGO_APP_USER`, `MONGO_APP_PASSWORD`, and multiple pool/timeout knobs). v3.0.0 consolidates these into a single `MONGO_URI` secret, aligning with how the Flowker application now reads its configuration.

**Removed values:**

```yaml
flowker:
  configmap:
    MONGO_URI: "mongodb://flowker:lerian@flowker-mongodb:27017/flowker?authSource=admin"
    MONGO_HOST: "flowker-mongodb"
    MONGO_PORT: "27017"
    MONGO_APP_USER: "flowker"
    MONGO_MIN_POOL_SIZE: "5"
    MONGO_MAX_IDLE_TIME_MS: "60000"
    MONGO_CONNECT_TIMEOUT_MS: "10000"
    MONGO_SOCKET_TIMEOUT_MS: "30000"
  secrets:
    MONGO_APP_PASSWORD: "lerian"
```

**New values:**

```yaml
flowker:
  configmap:
    MONGO_DB_NAME: "flowker"
    MONGO_MAX_POOL_SIZE: "20"
  secrets:
    MONGO_URI: ""
    MONGO_TLS_CA_CERT: ""
```

> **Important:** The `MONGO_URI` is now in `secrets` (not `configmap`) because it embeds the password. The application only reads `MONGO_URI`, `MONGO_DB_NAME`, `MONGO_TLS_CA_CERT`, and `MONGO_MAX_POOL_SIZE`.

**Action required:**

When using the bundled MongoDB subchart (`mongodb.enabled: true`), the chart automatically assembles `MONGO_URI` from the subchart's credentials. You only need to ensure passwords are set (see [Breaking Change #1](#1-empty-default-passwords)).

When using an external MongoDB (`mongodb.enabled: false`), you **must** provide `MONGO_URI`:

```yaml
flowker:
  secrets:
    MONGO_URI: "mongodb://flowker:your-password@external-mongo-host:27017/flowker?authSource=flowker"
```

For AWS DocumentDB with TLS:

```yaml
flowker:
  secrets:
    MONGO_URI: "mongodb://flowker:your-password@docdb-cluster.region.docdb.amazonaws.com:27017/flowker?tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&authSource=flowker"
    MONGO_TLS_CA_CERT: "LS0tLS1CRUdJTi... (base64-encoded PEM CA certificate)"
```

### 4. Health check endpoints changed

The liveness and readiness probe paths have changed to match the application's new health check endpoints.

| Probe | v2.0.0 | v3.0.0 |
|-------|--------|--------|
| Liveness path | `/health/live` | `/health` |
| Readiness path | `/health/ready` | `/readyz` |

> **Note:** The chart now supports configurable probe settings via `flowker.readinessProbe` and `flowker.livenessProbe`. All fields override chart defaults.

**Before (v2.0.0):**

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 15
  periodSeconds: 20
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**After (v3.0.0):**

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 15
  periodSeconds: 20
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
```

**Action required:**

No action required unless you have custom probe configurations. The chart automatically uses the new endpoints. To customize probe settings:

```yaml
flowker:
  readinessProbe:
    path: "/readyz"
    initialDelaySeconds: 10
    periodSeconds: 15
  livenessProbe:
    path: "/health"
    initialDelaySeconds: 30
    periodSeconds: 30
```

### 5. Security context hardening

The pod security context has been hardened with additional restrictions.

| Setting | v2.0.0 | v3.0.0 |
|---------|--------|--------|
| `flowker.securityContext.allowPrivilegeEscalation` | (not set) | `false` |
| `flowker.securityContext.seccompProfile.type` | (not set) | `RuntimeDefault` |

**Before (v2.0.0):**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

**After (v3.0.0):**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
```

> **Note:** These changes improve security posture and align with Pod Security Standards (restricted profile). No action required unless your cluster has custom security policies that conflict with these settings.

## Features

### 1. Multi-tenant support

The chart now includes configuration for multi-tenant database pool management. When enabled, database connections are resolved per-tenant via Tenant Manager instead of using a static MongoDB connection.

```yaml
flowker:
  configmap:
    MULTI_TENANT_ENABLED: "false"
    MULTI_TENANT_URL: ""
    MULTI_TENANT_ALLOW_INSECURE_HTTP: "false"
    MULTI_TENANT_REDIS_HOST: ""
    MULTI_TENANT_REDIS_PORT: "6379"
    MULTI_TENANT_REDIS_TLS: "false"
    MULTI_TENANT_MAX_TENANT_POOLS: "100"
    MULTI_TENANT_IDLE_TIMEOUT_SEC: "300"
    MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "30"
    MULTI_TENANT_TIMEOUT: "30"
    MULTI_TENANT_CACHE_TTL_SEC: "120"
    MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"
    MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: "30"
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: ""
    MULTI_TENANT_REDIS_PASSWORD: ""
```

> **Important:** When `MULTI_TENANT_ENABLED=true`, the chart requires `MULTI_TENANT_URL` (configmap) and `MULTI_TENANT_SERVICE_API_KEY` (secrets). The static MongoDB connection is not used; per-tenant connections are managed by the dispatch layer.

**To enable multi-tenant mode:**

```yaml
flowker:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_URL: "https://tenant-manager.example.com"
    MULTI_TENANT_REDIS_HOST: "redis.example.com"
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "your-tenant-manager-api-key"
    MULTI_TENANT_REDIS_PASSWORD: "your-redis-password"
```

### 2. Audit database configuration

A separate audit PostgreSQL connection is now configurable for the audit trail subsystem. Required when `MULTI_TENANT_ENABLED=false`.

```yaml
flowker:
  configmap:
    AUDIT_DB_HOST: ""
    AUDIT_DB_PORT: "5432"
    AUDIT_DB_USER: "flowker_audit"
    AUDIT_DB_NAME: "flowker_audit"
    AUDIT_DB_SSL_MODE: "disable"
    AUDIT_MIGRATIONS_PATH: "/migrations"
  secrets:
    AUDIT_DB_PASSWORD: ""
```

> **Warning:** When `MULTI_TENANT_ENABLED=false`, the chart requires `AUDIT_DB_HOST` (configmap) and `AUDIT_DB_PASSWORD` (secrets). The application will fail to start without these values.

**To configure audit database:**

```yaml
flowker:
  configmap:
    AUDIT_DB_HOST: "postgres.example.com"
    AUDIT_DB_PORT: "5432"
    AUDIT_DB_USER: "flowker_audit"
    AUDIT_DB_NAME: "flowker_audit"
    AUDIT_DB_SSL_MODE: "require"
  secrets:
    AUDIT_DB_PASSWORD: "your-audit-db-password"
```

### 3. Access Manager plugin authentication

The chart now supports plugin-based authentication via Access Manager, an external authentication service.

```yaml
flowker:
  configmap:
    PLUGIN_AUTH_ENABLED: "false"
    PLUGIN_AUTH_ADDRESS: ""
```

**To enable Access Manager authentication:**

```yaml
flowker:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "https://access-manager.example.com"
```

> **Note:** When `PLUGIN_AUTH_ENABLED=true`, the `API_KEY_ENABLED` setting acts as a fallback authentication mechanism.

### 4. Deployment mode and TLS controls

The chart introduces a `DEPLOYMENT_MODE` setting that controls TLS enforcement at startup.

```yaml
flowker:
  configmap:
    DEPLOYMENT_MODE: "local"
    ALLOW_INSECURE_TLS: "true"
```

| Mode | Description | TLS Enforcement |
|------|-------------|-----------------|
| `local` | Local development | TLS optional |
| `byoc` | Bring-your-own-cloud | TLS recommended |
| `saas` | SaaS production | TLS mandatory |

**For production deployments:**

```yaml
flowker:
  configmap:
    DEPLOYMENT_MODE: "saas"
    ALLOW_INSECURE_TLS: "false"
```

### 5. Feature flags and operational knobs

New operational feature flags for development and debugging:

```yaml
flowker:
  configmap:
    SKIP_LIB_COMMONS_TELEMETRY: "false"
    FAULT_INJECTION_ENABLED: "false"
    SSRF_ALLOW_PRIVATE: "false"
```

| Flag | Default | Description |
|------|---------|-------------|
| `SKIP_LIB_COMMONS_TELEMETRY` | `"false"` | Skip telemetry initialization in lib-commons |
| `FAULT_INJECTION_ENABLED` | `"false"` | Enable fault injection for chaos testing |
| `SSRF_ALLOW_PRIVATE` | `"false"` | Allow SSRF to private IPs (localhost providers in dev) |

> **Warning:** `SSRF_ALLOW_PRIVATE` should **NEVER** be enabled in production. It allows Server-Side Request Forgery to private IP addresses and is intended only for local development with localhost providers.

### 6. MongoDB TLS CA certificate support

The chart now supports MongoDB TLS connections with custom CA certificates (required for AWS DocumentDB).

```yaml
flowker:
  secrets:
    MONGO_TLS_CA_CERT: ""
```

**For AWS DocumentDB:**

```yaml
flowker:
  secrets:
    MONGO_URI: "mongodb://flowker:password@docdb-cluster.region.docdb.amazonaws.com:27017/flowker?tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&authSource=flowker"
    MONGO_TLS_CA_CERT: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t... (base64-encoded PEM)"
```

> **Note:** The `MONGO_TLS_CA_CERT` must be base64-encoded PEM format. Download the DocumentDB CA certificate and encode it with `base64 -w 0 rds-combined-ca-bundle.pem`.

### 7. Configurable health probes

The chart now exposes top-level configuration for readiness and liveness probes, allowing operators to override all probe settings.

```yaml
flowker:
  readinessProbe: {}
  livenessProbe: {}
```

**To customize probe settings:**

```yaml
flowker:
  readinessProbe:
    path: "/readyz"
    initialDelaySeconds: 10
    periodSeconds: 15
    timeoutSeconds: 3
    successThreshold: 1
    failureThreshold: 5
  livenessProbe:
    path: "/health"
    initialDelaySeconds: 30
    periodSeconds: 30
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
```

## Configuration Reference

### New ConfigMap Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `"true"` | Allow insecure TLS connections (disable in production) |
| `DEPLOYMENT_MODE` | `"local"` | Deployment mode: `local`, `byoc`, or `saas` (controls TLS enforcement) |
| `PLUGIN_AUTH_ENABLED` | `"false"` | Enable Access Manager plugin authentication |
| `PLUGIN_AUTH_ADDRESS` | `""` | Access Manager service URL (required when PLUGIN_AUTH_ENABLED=true) |
| `SKIP_LIB_COMMONS_TELEMETRY` | `"false"` | Skip telemetry initialization in lib-commons |
| `FAULT_INJECTION_ENABLED` | `"false"` | Enable fault injection for chaos testing |
| `SSRF_ALLOW_PRIVATE` | `"false"` | Allow SSRF to private IPs (NEVER enable in production) |
| `AUDIT_DB_HOST` | `""` | Audit DB host (required when MULTI_TENANT_ENABLED=false) |
| `AUDIT_DB_PORT` | `"5432"` | Audit DB port |
| `AUDIT_DB_USER` | `"flowker_audit"` | Audit DB username |
| `AUDIT_DB_NAME` | `"flowker_audit"` | Audit DB database name |
| `AUDIT_DB_SSL_MODE` | `"disable"` | Audit DB SSL mode |
| `AUDIT_MIGRATIONS_PATH` | `"/migrations"` | Path to audit DB migrations |
| `MULTI_TENANT_ENABLED` | `"false"` | Enable multi-tenant mode |
| `MULTI_TENANT_URL` | `""` | Tenant Manager API URL (required when MULTI_TENANT_ENABLED=true) |
| `MULTI_TENANT_ALLOW_INSECURE_HTTP` | `"false"` | Allow http:// MULTI_TENANT_URL (NEVER enable in production) |
| `MULTI_TENANT_REDIS_HOST` | `""` | Redis host for Pub/Sub event-driven tenant discovery |
| `MULTI_TENANT_REDIS_PORT` | `"6379"` | Redis port |
| `MULTI_TENANT_REDIS_TLS` | `"false"` | Enable Redis TLS |
| `MULTI_TENANT_MAX_TENANT_POOLS` | `"100"` | Maximum number of tenant connection pools |
| `MULTI_TENANT_IDLE_TIMEOUT_SEC` | `"300"` | Idle timeout for tenant pools (seconds) |
| `MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC` | `"30"` | Connection health check interval (seconds) |
| `MULTI_TENANT_TIMEOUT` | `"30"` | HTTP client timeout for Tenant Manager (seconds) |
| `MULTI_TENANT_CACHE_TTL_SEC` | `"120"` | Tenant metadata cache TTL (seconds) |
| `MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD` | `"5"` | Circuit breaker failure threshold |
| `MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC` | `"30"` | Circuit breaker timeout (seconds) |

### New Secret Variables

| Variable | Description |
|----------|-------------|
| `MONGO_URI` | MongoDB connection URI (REQUIRED — must include password) |
| `MONGO_TLS_CA_CERT` | Base64-encoded PEM CA certificate for MongoDB TLS |
| `AUDIT_DB_PASSWORD` | Audit DB password (required when MULTI_TENANT_ENABLED=false) |
| `MULTI_TENANT_SERVICE_API_KEY` | Tenant Manager service API key (required when MULTI_TENANT_ENABLED=true) |
| `MULTI_TENANT_REDIS_PASSWORD` | Redis password for tenant Pub/Sub |

### Changed Defaults

| Setting | v2.0.0 | v3.0.0 |
|---------|--------|--------|
| `flowker.service.port` | `4000` | `4021` |
| `flowker.configmap.SERVER_PORT` | `"4000"` | `"4021"` |
| `flowker.configmap.SERVER_ADDRESS` | `":4000"` | `":4021"` |
| `flowker.configmap.SWAGGER_HOST` | `":4000"` | `":4021"` |
| `flowker.configmap.MONGO_MAX_POOL_SIZE` | `"10"` | `"20"` |
| `global.mongodb.adminCredentials.password` | `"lerian"` | `""` |
| `global.mongodb.flowkerCredentials.password` | `"lerian"` | `""` |
| `mongodb.auth.rootPassword` | `"lerian"` | `""` |

## Migration Steps

### Step 1: Backup your current values

```bash
helm get values flowker -n flowker > flowker-v2-values.yaml
```

### Step 2: Set required passwords

Create a new values file for v3.0.0 with explicit passwords:

```yaml
# flowker-v3-values.yaml
global:
  mongodb:
    adminCredentials:
      password: "your-secure-admin-password"
    flowkerCredentials:
      password: "your-secure-flowker-password"

mongodb:
  auth:
    rootPassword: "your-secure-root-password"
```

> **Important:** Use strong, unique passwords for production deployments. Consider using a secrets management solution like HashiCorp Vault or AWS Secrets Manager.

### Step 3: Migrate MongoDB configuration

If you were using custom MongoDB settings in v2.0.0, migrate them to the new `MONGO_URI` format.

**If using bundled MongoDB (default):**

No action required. The chart automatically assembles `MONGO_URI` from the subchart credentials.

**If using external MongoDB:**

```yaml
flowker:
  secrets:
    MONGO_URI: "mongodb://flowker:your-password@external-mongo-host:27017/flowker?authSource=flowker"
```

**If using AWS DocumentDB:**

```yaml
flowker:
  secrets:
    MONGO_URI: "mongodb://flowker:your-password@docdb-cluster.region.docdb.amazonaws.com:27017/flowker?tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&authSource=flowker"
    MONGO_TLS_CA_CERT: "LS0tLS1CRUdJTi... (base64-encoded PEM)"
```

### Step 4: Configure audit database

Add audit database configuration to your values file:

```yaml
flowker:
  configmap:
    AUDIT_DB_HOST: "postgres.example.com"
    AUDIT_DB_PORT: "5432"
    AUDIT_DB_USER: "flowker_audit"
    AUDIT_DB_NAME: "flowker_audit"
    AUDIT_DB_SSL_MODE: "require"
  secrets:
    AUDIT_DB_PASSWORD: "your-audit-db-password"
```

> **Note:** If you don't have an audit database yet, you'll need to provision a PostgreSQL instance before upgrading.

### Step 5: Decide on service port

**Option 1: Migrate to port 4021 (recommended)**

Update any downstream clients, Ingress rules, NetworkPolicies, or service mesh configurations to use port `4021` instead of `4000`. No values override needed.

**Option 2: Keep port 4000 (legacy compatibility)**

Add to your values file:

```yaml
flowker:
  service:
    port: 4000
  configmap:
    SERVER_PORT: "4000"
    SERVER_ADDRESS: ":4000"
    SWAGGER_HOST: ":4000"
```

### Step 6: Review security settings

The new security context settings are applied automatically. If your cluster has custom Pod Security Policies or Pod Security Standards that conflict, adjust accordingly:

```yaml
flowker:
  securityContext:
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

### Step 7: (Optional) Configure multi-tenant mode

If you're deploying in multi-tenant mode, add the required configuration:

```yaml
flowker:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_URL: "https://tenant-manager.example.com"
    MULTI_TENANT_REDIS_HOST: "redis.example.com"
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "your-tenant-manager-api-key"
    MULTI_TENANT_REDIS_PASSWORD: "your-redis-password"
```

> **Note:** When multi-tenant mode is enabled, the static audit database configuration is ignored. Per-tenant audit databases are managed by the dispatch layer.

### Step 8: Preview the upgrade

Use the helm-diff plugin to preview changes:

```bash
helm diff upgrade flowker oci://registry-1.docker.io/lerianstudio/flowker-helm \
  --version 3.0.0 \
  -n flowker \
  -f flowker-v3-values.yaml
```

Review the diff output carefully, paying special attention to:
- Secret changes (passwords, connection strings)
- Service port changes
- ConfigMap environment variable changes
- Deployment probe changes

### Step 9: Perform the upgrade

```bash
helm upgrade flowker oci://registry-1.docker.io/lerianstudio/flowker-helm \
  --version 3.0.0 \
  -n flowker \
  -f flowker-v3-values.yaml
```

### Step 10: Verify the deployment

```bash
# Check rollout status
kubectl rollout status -n flowker deploy/flowker

# Check pod status
kubectl get pods -n flowker

# Check application logs
kubectl logs -n flowker -l app.kubernetes.io/name=flowker --tail=50

# Verify the application is listening on the correct port
kubectl logs -n flowker -l app.kubernetes.io/name=flowker | grep "Server listening"
```

### Step 11: Test connectivity

```bash
# Port-forward to test locally
kubectl port-forward -n flowker svc/flowker 4021:4021

# Test health endpoint
curl http://localhost:4021/health

# Test readiness endpoint
curl http://localhost:4021/readyz
```

## Preview changes before upgrading

```bash
helm diff upgrade flowker oci://registry-1.docker.io/lerianstudio/flowker-helm --version 3.0.0 -n flowker
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade flowker oci://registry-1.docker.io/lerianstudio/flowker-helm --version 3.0.0 -n flowker
```
