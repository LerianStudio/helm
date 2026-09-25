# Helm Upgrade from v0.x to v1.x

## Topics

- **[Breaking Changes](#breaking-changes)**
- **[Features](#features)**
  - [1. Multi-Component Architecture](#1-multi-component-architecture)
  - [2. External PostgreSQL Bootstrap](#2-external-postgresql-bootstrap)
  - [3. Global Configuration Contracts](#3-global-configuration-contracts)
  - [4. Database Migrations](#4-database-migrations)
  - [5. Service Discovery Integration](#5-service-discovery-integration)
  - [6. Streaming Support](#6-streaming-support)
  - [7. Multi-Tenant Support](#7-multi-tenant-support)
  - [8. Observability (OpenTelemetry)](#8-observability-opentelemetry)
  - [9. Authentication Integration](#9-authentication-integration)
  - [10. Component-Specific Datastores](#10-component-specific-datastores)
  - [11. Security Hardening](#11-security-hardening)
  - [12. Ingress Routing](#12-ingress-routing)
  - [13. Wait-for-Dependencies Init Container](#13-wait-for-dependencies-init-container)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: Fresh Installation with In-Cluster PostgreSQL](#scenario-1-fresh-installation-with-in-cluster-postgresql)
  - [Scenario 2: External PostgreSQL with Bootstrap](#scenario-2-external-postgresql-with-bootstrap)
  - [Scenario 3: External PostgreSQL without Bootstrap](#scenario-3-external-postgresql-without-bootstrap)
  - [Scenario 4: Production Deployment with All Features](#scenario-4-production-deployment-with-all-features)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

This is the **initial release (v1.0.0)** of the `plugin-br-pix-lerian` Helm chart. There is no v0.0.0 deployed in production — this upgrade guide documents the transition from **no chart** to **v1.0.0**.

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Chart existence | No Helm chart | Full multi-component chart with 14 services |
| Deployment method | Manual manifests or other tooling | Helm-managed with dependencies |
| Configuration | Scattered across multiple files | Centralized in `values.yaml` with global defaults |
| Database provisioning | Manual | Automated via bootstrap Job (optional) |
| Secrets management | Manual Secret creation | Chart-managed or `useExistingSecret` |

> **Important:** If you are currently running plugin-br-pix-lerian components via manual Kubernetes manifests, you must migrate to this Helm chart. The chart does **not** automatically import existing Secrets, ConfigMaps, or PVCs. Plan a migration window to transfer credentials and data.

## Features

### 1. Multi-Component Architecture

The chart deploys **14 independent components** of the plugin-br-pix-lerian application, each with its own Deployment, Service, ConfigMap, Secret, and optional HPA/PDB/Ingress:

- **spi/api** — PIX SPI (Single Person Interface)
- **spi/systemplane/api** — Runtime config plane for SPI
- **adapter-provider-mock/api** — BTG provider mock (dev/staging only)
- **dict/hub/api** — DICT hub (key directory operations)
- **dict/hub/vsync** — DICT verification sync worker
- **dict/proxy/api** — DICT proxy to BCB
- **dict/systemplane/api** — Runtime config plane for DICT
- **cob/hub/api** — COB hub (BR Code / charge operations)
- **cob/proxy/api** — COB proxy to BCB
- **cob/systemplane/api** — Runtime config plane for COB
- **adapter-lerian/api** — Lerian provider adapter (br-sfn)
- **adapter-lerian/systemplane/api** — Runtime config plane for adapter-lerian
- **pixauto/api** — Pix Automático payer side (recurrence authorization)
- **pixauto/systemplane/api** — Runtime config plane for Pix Automático

Each component can be independently enabled/disabled:

```yaml
spi:
  enabled: true
spiSystemplane:
  enabled: true
adapterProviderMock:
  enabled: false  # Safety default — explicitly enable in dev/staging
dictHub:
  enabled: true
# ... and so on for all 14 components
```

> **Note:** The `adapterProviderMock` component is **disabled by default** and should **never** be enabled in production. It is a test mock for the BTG provider.

### 2. External PostgreSQL Bootstrap

The chart includes an **optional bootstrap Job** that provisions PostgreSQL databases and roles for the 5 Pix Lerian databases:

- `pix-spi`
- `pix-dict`
- `pix-cob`
- `pix-adapter-lerian`
- `pix-pixauto`

```yaml
externalPostgresDefinitions:
  enabled: true
  databases:
    - pix-spi
    - pix-dict
    - pix-cob
    - pix-adapter-lerian
    - pix-pixauto
  connection:
    host: "postgres.example.com"
    port: "5432"
  postgresAdminLogin:
    useExistingSecret:
      name: "postgres-admin-secret"  # PRODUCTION: use this
    username: "postgres"
    password: ""  # Only when useExistingSecret.name is empty
  pixLerianCredentials:
    useExistingSecret:
      name: "pix-app-credentials"  # PRODUCTION: use this
    username: "pixswitch"
    password: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `externalPostgresDefinitions.enabled` | `false` | Enable the bootstrap Job |
| `externalPostgresDefinitions.databases` | `[pix-spi, pix-dict, pix-cob, pix-adapter-lerian, pix-pixauto]` | List of databases to create |
| `externalPostgresDefinitions.connection.host` | `""` | PostgreSQL server hostname |
| `externalPostgresDefinitions.connection.port` | `"5432"` | PostgreSQL server port |
| `externalPostgresDefinitions.postgresAdminLogin.username` | `"postgres"` | Admin user for provisioning |
| `externalPostgresDefinitions.postgresAdminLogin.useExistingSecret.name` | `""` | External Secret with admin credentials |
| `externalPostgresDefinitions.pixLerianCredentials.username` | `"pixswitch"` | Application database user |
| `externalPostgresDefinitions.pixLerianCredentials.useExistingSecret.name` | `""` | External Secret with app credentials |

> **Warning:** Never put production admin passwords in `values.yaml`. Always use `useExistingSecret.name` and create the Secret externally.

**When to use bootstrap:**

- **In-cluster PostgreSQL subchart** (`postgresql.enabled=true`) — set `connection.host` to the subchart's Service name: `<release-name>-postgresql` (e.g., `pix-postgresql` for a release named `pix`).
- **External PostgreSQL** (RDS, Cloud SQL, etc.) — set `connection.host` to the external server and provide admin credentials with `CREATE ROLE` / `CREATE DATABASE` privileges.

**When NOT to use bootstrap:**

- Databases already exist and are managed externally.
- You prefer to provision databases via Terraform, Ansible, or other tooling.

### 3. Global Configuration Contracts

The chart introduces **global defaults** that apply to all components unless overridden in a component's own block:

```yaml
global:
  imagePullSecrets: []
  datastores:
    postgres:
      host: "postgres.internal"
      user: "pixswitch"
      ssl: "require"
    redis:
      host: "valkey.internal"
      port: "6379"
      tls: "true"
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth:4000"
  multiTenant:
    url: "http://tenant-manager:8080"
  streaming:
    enabled: true
    brokers: "redpanda:9092"
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "pix"
  serviceDiscovery:
    enabled: true
    address: "consul-server.consul:8500"
    tls: false
    tlsSkipVerify: false
    workload: "production"
```

| Section | Environment Variables Emitted | Description |
|---------|-------------------------------|-------------|
| `global.datastores.postgres` | `DB_HOST`, `DB_USER`, `DB_NAME`, `DB_PORT`, `DB_SSLMODE`, `DB_REPLICA_*` | PostgreSQL connection for components with databases |
| `global.datastores.redis` | `REDIS_HOST`, `REDIS_PORT`, `REDIS_USER`, `REDIS_DB`, `REDIS_TLS` | Redis/Valkey connection for caching |
| `global.observability` | `ENABLE_TELEMETRY`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | OpenTelemetry configuration |
| `global.auth` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` | plugin-access-manager integration |
| `global.multiTenant` | `MULTI_TENANT_URL`, circuit breaker vars | tenant-manager integration |
| `global.streaming` | `STREAMING_ENABLED`, `STREAMING_*` transport vars | RedPanda/Kafka streaming |
| `global.serviceDiscovery` | `SD_ENABLED`, `SD_ADDRESS`, `SD_TLS`, `SD_TLS_SKIP_VERIFY`, `SD_WORKLOAD` | Consul service discovery |

> **Note:** A component's own `configmap.<KEY>` value **always wins** over the global default. Use global defaults to set environment-wide values once, then override per-component only when needed.

### 4. Database Migrations

Each component with a database (spi, dictHub, cobHub, adapterLerian, pixauto) includes a **golang-migrate Job** that runs as a Helm hook on `pre-install` and `pre-upgrade`:

```yaml
spi:
  migrations:
    enabled: true
    migrationsPath: /migrations
    ttlSecondsAfterFinished: 300
    backoffLimit: 3
```

| Flag | Default | Description |
|------|---------|-------------|
| `<component>.migrations.enabled` | `true` | Enable the migration Job |
| `<component>.migrations.migrationsPath` | `/migrations` | Path inside the image where SQL files live |
| `<component>.migrations.ttlSecondsAfterFinished` | `300` | Auto-delete completed Job after 5 minutes |
| `<component>.migrations.backoffLimit` | `3` | Retry failed migrations up to 3 times |

The Job reads `DATABASE_URL` from the component's Secret and applies migrations using the `/migrate` binary shipped in the same image.

> **Important:** The migration Job must complete successfully before the component Deployment rolls out. If migrations fail, the upgrade will block. Check Job logs with:

```bash
kubectl logs -l app.kubernetes.io/component=spi-migration -n plugin-br-pix-lerian
```

### 5. Service Discovery Integration

The chart supports **Consul service discovery** via the `global.serviceDiscovery` block:

```yaml
global:
  serviceDiscovery:
    enabled: true
    address: "consul-server.consul:8500"
    tls: false
    tlsSkipVerify: false
    workload: "production"
```

When enabled, the following environment variables are emitted to **systemplanes** and **adapter-provider-mock**:

- `SD_ENABLED` — `"true"` or `"false"`
- `SD_ADDRESS` — Consul server address
- `SD_TLS` — `"true"` or `"false"`
- `SD_TLS_SKIP_VERIFY` — `"true"` or `"false"`
- `SD_WORKLOAD` — Workload identifier (e.g., environment name)
- `SD_ADVERTISE_ADDRESS` — Derived from the component's Pod IP
- `SD_ADVERTISE_PORT` — Derived from the component's Service port

> **Note:** The per-component `SD_ADVERTISE_ADDRESS` and `SD_ADVERTISE_PORT` are **automatically derived** from the component's identity. You do not set them in `values.yaml`.

### 6. Streaming Support

The chart supports **RedPanda/Kafka streaming** via the `global.streaming` block:

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda:9092"
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "pix"
```

When enabled, the following environment variables are emitted to **cob-hub**, **dict-hub**, **pixauto**, and **spi**:

- `STREAMING_ENABLED` — `"true"` or `"false"`
- `STREAMING_BROKERS` — Comma-separated broker list
- `STREAMING_SASL_MECHANISM` — SASL mechanism (e.g., `SCRAM-SHA-512`)
- `STREAMING_SASL_USERNAME` — SASL username
- `STREAMING_SASL_PASSWORD` — Read from the component's Secret
- `STREAMING_TLS_CA_CERT` — Read from the component's Secret (optional)

> **Warning:** `STREAMING_SASL_PASSWORD` and `STREAMING_TLS_CA_CERT` are **secrets** and must be provided via the component's `secrets` block or `useExistingSecret`.

### 7. Multi-Tenant Support

The chart supports **tenant-manager integration** via the `global.multiTenant` block:

```yaml
global:
  multiTenant:
    url: "http://tenant-manager:8080"
```

When `url` is set, the following environment variables are emitted to all components:

- `MULTI_TENANT_URL` — tenant-manager service URL
- `MULTI_TENANT_SERVICE_API_KEY` — Read from the component's Secret
- Circuit breaker configuration (timeouts, thresholds, etc.)

> **Note:** The circuit breaker configuration is emitted **only when** `MULTI_TENANT_ENABLED=true` in the component's ConfigMap. The global block does not have an `enabled` flag; presence of `url` is sufficient.

### 8. Observability (OpenTelemetry)

The chart supports **OpenTelemetry** via the `global.observability` block:

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
```

When enabled, the following environment variables are emitted to all components:

- `ENABLE_TELEMETRY` — `"true"` or `"false"`
- `OTEL_EXPORTER_OTLP_ENDPOINT` — OTel collector endpoint
- `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` — Environment name (e.g., `production`, `staging`)

### 9. Authentication Integration

The chart supports **plugin-access-manager** via the `global.auth` block:

```yaml
global:
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth:4000"
```

When enabled, the following environment variables are emitted to all components:

- `PLUGIN_AUTH_ENABLED` — `"true"` or `"false"`
- `PLUGIN_AUTH_HOST` — plugin-access-manager service URL

### 10. Component-Specific Datastores

Each component can override the global datastore configuration:

```yaml
spi:
  datastores:
    postgres:
      host: "spi-postgres.internal"
      user: "spi_user"
      name: "pix-spi"
      port: "5432"
      ssl: "require"
      replicaHost: "spi-postgres-replica.internal"
      replicaPort: "5432"
    redis:
      host: "spi-redis.internal"
      port: "6379"
      user: "spi_redis"
      db: "0"
      tls: "true"
```

> **Note:** Component-specific datastores **override** the global defaults. Use this when a component needs a dedicated database or cache instance.

### 11. Security Hardening

All component Deployments include **security best practices** by default:

```yaml
securityContext:
  runAsGroup: 1000
  runAsUser: 1000
  runAsNonRoot: true
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
```

> **Important:** The `readOnlyRootFilesystem: true` setting requires that the application does not write to the container filesystem. Temporary files must use `emptyDir` volumes.

### 12. Ingress Routing

The chart supports **three Ingress resources** for routing external traffic:

- **appsIngress** — Routes for user-facing APIs (spi, dict-hub, cob-hub, pixauto, adapter-lerian)
- **providersIngress** — Routes for provider proxies (dict-proxy, cob-proxy, adapter-provider-mock)
- **systemplanesIngress** — Routes for systemplane APIs (all `*-systemplane` components)

Each Ingress is independently enabled and configured:

```yaml
appsIngress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - "pix.example.com"
  tls:
    - secretName: "pix-tls"
      hosts:
        - "pix.example.com"
  routes:
    - path: /spi
      component: spi
    - path: /dict
      component: dictHub
    - path: /cob
      component: cobHub
    - path: /pixauto
      component: pixauto
    - path: /adapter-lerian
      component: adapterLerian
```

| Flag | Default | Description |
|------|---------|-------------|
| `<ingress>.enabled` | `false` | Enable the Ingress resource |
| `<ingress>.className` | `""` | IngressClass name (e.g., `nginx`, `traefik`) |
| `<ingress>.annotations` | `{}` | Ingress annotations (e.g., cert-manager, rate limiting) |
| `<ingress>.hosts` | `[]` | List of hostnames |
| `<ingress>.tls` | `[]` | TLS configuration |
| `<ingress>.routes` | `[]` | List of path-to-component mappings |

> **Warning:** Each route in `routes` must name a component that exists in `values.yaml` and is enabled. The `component` key must match the camelCase values key (e.g., `dictHub`, not `dict-hub`). The optional `serviceName` key must match the kebab-case Service suffix (e.g., `dict-hub`). If both are set, they must name the **same component**, otherwise the rule pairs one component's Service with another component's port and every request fails.

### 13. Wait-for-Dependencies Init Container

All component Deployments include a **wait-for-dependencies init container** that blocks Pod startup until required services (PostgreSQL, Redis, RabbitMQ) are reachable:

```yaml
initContainers:
  - name: wait-for-dependencies
    image: busybox:1.36
    command: ["/bin/sh", "-c"]
    args:
      - |
        # Parse DATABASE_URL and wait for postgres:5432
        # Parse REDIS_HOST/REDIS_PORT and wait for redis:6379
        # Parse RABBITMQ_URI and wait for rabbitmq:5672
```

> **Note:** The init container uses `nc -z` to test TCP connectivity. It does **not** validate credentials or schema readiness — only that the port is open.

## Deployment Scenarios

### Scenario 1: Fresh Installation with In-Cluster PostgreSQL

Deploy the chart with the **bundled PostgreSQL subchart** and let the bootstrap Job create the 5 Pix Lerian databases:

```yaml
postgresql:
  enabled: true
  auth:
    username: "pixswitch"
    password: "changeme"
    database: "postgres"

externalPostgresDefinitions:
  enabled: true
  connection:
    host: "pix-postgresql"  # <release-name>-postgresql
    port: "5432"
  postgresAdminLogin:
    username: "postgres"
    password: "changeme"
  pixLerianCredentials:
    username: "pixswitch"
    password: "changeme"

global:
  datastores:
    postgres:
      host: "pix-postgresql"
      user: "pixswitch"
      ssl: "disable"
```

> **Note:** Replace `pix` with your actual release name. The subchart Service is `<release-name>-postgresql`, **not** `plugin-br-pix-lerian-postgresql`.

### Scenario 2: External PostgreSQL with Bootstrap

Deploy the chart with an **external PostgreSQL server** (RDS, Cloud SQL, etc.) and let the bootstrap Job create the databases:

```yaml
postgresql:
  enabled: false

externalPostgresDefinitions:
  enabled: true
  connection:
    host: "postgres.example.com"
    port: "5432"
  postgresAdminLogin:
    useExistingSecret:
      name: "postgres-admin-secret"
    username: "postgres"
  pixLerianCredentials:
    useExistingSecret:
      name: "pix-app-credentials"
    username: "pixswitch"

global:
  datastores:
    postgres:
      host: "postgres.example.com"
      user: "pixswitch"
      ssl: "require"
```

**Create the admin Secret externally:**

```bash
kubectl create secret generic postgres-admin-secret \
  --from-literal=DB_USER_ADMIN=postgres \
  --from-literal=DB_ADMIN_PASSWORD='your-admin-password' \
  -n plugin-br-pix-lerian
```

**Create the app credentials Secret externally:**

```bash
kubectl create secret generic pix-app-credentials \
  --from-literal=username=pixswitch \
  --from-literal=password='your-app-password' \
  -n plugin-br-pix-lerian
```

### Scenario 3: External PostgreSQL without Bootstrap

Deploy the chart with an **external PostgreSQL server** where databases already exist (managed via Terraform, Ansible, etc.):

```yaml
postgresql:
  enabled: false

externalPostgresDefinitions:
  enabled: false

global:
  datastores:
    postgres:
      host: "postgres.example.com"
      user: "pixswitch"
      ssl: "require"
```

**Provide database credentials per component:**

```yaml
spi:
  secrets:
    DATABASE_URL: "postgres://pixswitch:password@postgres.example.com:5432/pix-spi?sslmode=require"
    DB_PASSWORD: "password"

dictHub:
  secrets:
    DATABASE_URL: "postgres://pixswitch:password@postgres.example.com:5432/pix-dict?sslmode=require"
    DB_PASSWORD: "password"

# ... and so on for cobHub, adapterLerian, pixauto
```

> **Warning:** Never commit real passwords to `values.yaml`. Use `--set-file` or an external Secret with `useExistingSecret`.

### Scenario 4: Production Deployment with All Features

Deploy the chart with **all integrations enabled** (external PostgreSQL, Redis, RabbitMQ, Consul, RedPanda, OTel, plugin-access-manager, tenant-manager):

```yaml
postgresql:
  enabled: false

valkey:
  enabled: false

rabbitmq:
  enabled: false

externalPostgresDefinitions:
  enabled: false

global:
  imagePullSecrets:
    - name: ghcr-pull-secret
  datastores:
    postgres:
      host: "postgres.prod.example.com"
      user: "pixswitch"
      ssl: "require"
    redis:
      host: "valkey.prod.example.com"
      port: "6379"
      tls: "true"
  observability:
    enabled: true
    otlpEndpoint: "otel-collector.observability:4317"
    deploymentEnvironment: "production"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth.auth:4000"
  multiTenant:
    url: "http://tenant-manager.tenants:8080"
  streaming:
    enabled: true
    brokers: "redpanda-0.redpanda.streaming:9092,redpanda-1.redpanda.streaming:9092"
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "pix"
  serviceDiscovery:
    enabled: true
    address: "consul-server.consul:8500"
    tls: true
    tlsSkipVerify: false
    workload: "production"

appsIngress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"
  hosts:
    - "pix.example.com"
  tls:
    - secretName: "pix-tls"
      hosts:
        - "pix.example.com"
  routes:
    - path: /spi
      component: spi
    - path: /dict
      component: dictHub
    - path: /cob
      component: cobHub
    - path: /pixauto
      component: pixauto
    - path: /adapter-lerian
      component: adapterLerian

spi:
  replicaCount: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 200m
      memory: 256Mi
  useExistingSecret: true
  existingSecretName: "spi-secrets"

# ... repeat for other components
```

**Create the component Secrets externally:**

```bash
kubectl create secret generic spi-secrets \
  --from-literal=DATABASE_URL='postgres://pixswitch:password@postgres.prod.example.com:5432/pix-spi?sslmode=require' \
  --from-literal=DB_PASSWORD='password' \
  --from-literal=REDIS_PASSWORD='redis-password' \
  --from-literal=STREAMING_SASL_PASSWORD='streaming-password' \
  --from-literal=LICENSE_KEY='your-license-key' \
  --from-literal=MIDAZ_CLIENT_SECRET='midaz-secret' \
  --from-literal=DICT_CLIENT_SECRET='dict-secret' \
  --from-literal=COB_CLIENT_SECRET='cob-secret' \
  --from-literal=CRM_CLIENT_SECRET='crm-secret' \
  --from-literal=IDP_M2M_CLIENT_SECRET='idp-secret' \
  --from-literal=MULTI_TENANT_SERVICE_API_KEY='tenant-api-key' \
  -n plugin-br-pix-lerian
```

## Configuration Reference

### Global Defaults

```yaml
global:
  imagePullSecrets: []
  datastores:
    postgres:
      host: ""
      user: ""
      name: ""
      port: "5432"
      ssl: "require"
      replicaHost: ""
      replicaPort: "5432"
    redis:
      host: ""
      port: "6379"
      user: ""
      db: "0"
      tls: "false"
  observability:
    enabled: false
    otlpEndpoint: ""
    deploymentEnvironment: ""
  auth:
    enabled: false
    host: ""
  multiTenant:
    url: ""
  streaming:
    enabled: false
    brokers: ""
    saslMechanism: ""
    saslUsername: ""
  serviceDiscovery:
    enabled: false
    address: ""
    tls: false
    tlsSkipVerify: false
    workload: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.imagePullSecrets` | `[]` | Image pull secrets propagated to all components |
| `global.datastores.postgres.host` | `""` | PostgreSQL server hostname |
| `global.datastores.postgres.user` | `""` | PostgreSQL username |
| `global.datastores.postgres.name` | `""` | PostgreSQL database name (overridden per component) |
| `global.datastores.postgres.port` | `"5432"` | PostgreSQL server port |
| `global.datastores.postgres.ssl` | `"require"` | SSL mode (`disable`, `require`, `verify-ca`, `verify-full`) |
| `global.datastores.postgres.replicaHost` | `""` | PostgreSQL read replica hostname |
| `global.datastores.postgres.replicaPort` | `"5432"` | PostgreSQL read replica port |
| `global.datastores.redis.host` | `""` | Redis/Valkey server hostname |
| `global.datastores.redis.port` | `"6379"` | Redis/Valkey server port |
| `global.datastores.redis.user` | `""` | Redis/Valkey username (ACL) |
| `global.datastores.redis.db` | `"0"` | Redis/Valkey database number |
| `global.datastores.redis.tls` | `"false"` | Enable TLS for Redis/Valkey |
| `global.observability.enabled` | `false` | Enable OpenTelemetry |
| `global.observability.otlpEndpoint` | `""` | OTel collector endpoint |
| `global.observability.deploymentEnvironment` | `""` | Environment name (e.g., `production`) |
| `global.auth.enabled` | `false` | Enable plugin-access-manager integration |
| `global.auth.host` | `""` | plugin-access-manager service URL |
| `global.multiTenant.url` | `""` | tenant-manager service URL |
| `global.streaming.enabled` | `false` | Enable RedPanda/Kafka streaming |
| `global.streaming.brokers` | `""` | Comma-separated broker list |
| `global.streaming.saslMechanism` | `""` | SASL mechanism (e.g., `SCRAM-SHA-512`) |
| `global.streaming.saslUsername` | `""` | SASL username |
| `global.serviceDiscovery.enabled` | `false` | Enable Consul service discovery |
| `global.serviceDiscovery.address` | `""` | Consul server address |
| `global.serviceDiscovery.tls` | `false` | Enable TLS for Consul |
| `
