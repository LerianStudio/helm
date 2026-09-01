# Helm Upgrade from v9.0.0 to v9.1.0

## Topics

- **[Features](#features)**
  - [1. New lerian-common-helm dependency](#1-new-lerian-common-helm-dependency)
  - [2. Ledger v4.0.0 with dedicated migration runner](#2-ledger-v400-with-dedicated-migration-runner)
  - [3. New Tracer component](#3-new-tracer-component)
  - [4. Global datastore masks and cloud presets](#4-global-datastore-masks-and-cloud-presets)
  - [5. MongoDB TLS support for bootstrap job](#5-mongodb-tls-support-for-bootstrap-job)
  - [6. Ledger CRM and Fees module integration](#6-ledger-crm-and-fees-module-integration)
  - [7. Ledger KMS and crypto configuration](#7-ledger-kms-and-crypto-configuration)
  - [8. Ledger billing and identity provider integration](#8-ledger-billing-and-identity-provider-integration)
  - [9. CRM v3.8.4 with simplified configuration](#9-crm-v384-with-simplified-configuration)
- **[Configuration Reference](#configuration-reference)**
  - [Global configuration](#global-configuration)
  - [Ledger configuration](#ledger-configuration)
  - [Tracer configuration](#tracer-configuration)
  - [CRM configuration](#crm-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. New lerian-common-helm dependency

Chart v9.1.0 introduces a new dependency on `lerian-common-helm` v2.1.0, which provides shared templates and helpers for environment-wide configuration masks (observability, multi-tenancy, streaming, auth, service discovery).

| Setting | v9.0.0 | v9.1.0 |
|---------|--------|--------|
| `dependencies` | valkey, mongodb, postgresql, rabbitmq | **lerian-common-helm v2.1.0** + valkey, mongodb, postgresql, rabbitmq |

This dependency is automatically fetched during `helm dependency update` and enables the new global configuration surface described in [Feature 4](#4-global-datastore-masks-and-cloud-presets).

> **Note:** The lerian-common-helm chart is hosted at `oci://ghcr.io/lerianstudio` and will be pulled automatically when you upgrade. No manual action is required.

### 2. Ledger v4.0.0 with dedicated migration runner

The ledger component has been upgraded from v3.8.3 to v4.0.0. This is a major version bump that removes in-process schema migration from the ledger binary.

| Setting | v9.0.0 | v9.1.0 |
|---------|--------|--------|
| `ledger.image.tag` | `3.8.3` | `4.0.0` |
| `ledger.migrations.enabled` | (not present) | Auto-detected (on for 4.x, off for 3.x) |

#### What changed

- **Ledger v4.0.0 no longer migrates its PostgreSQL schema at startup.** The application expects an already-migrated database.
- A new `midaz-ledger-migrations` Job (built from `migrate/migrate`) applies the onboarding and transaction migration sets before the ledger Deployment starts.
- The migration Job is **automatically enabled** when `ledger.image.tag` is 4.x or higher. For 3.x tags, it remains disabled (3.x still migrates in-process).

#### Migration Job configuration

**Default behavior (auto-enabled for 4.x):**

```yaml
ledger:
  image:
    tag: "4.0.0"
  migrations:
    enabled:  # unset = auto (on for 4.x, off for 3.x)
    image:
      repository: lerianstudio/midaz-ledger-migrations
      pullPolicy: IfNotPresent
      tag: ""  # empty = tracks ledger.image.tag
    backoffLimit: 6
    activeDeadlineSeconds: 600
    ttlSecondsAfterFinished: 259200
    deploymentSyncWave: "1"
```

**Explicit override (disable migrations when schema is applied out-of-band):**

```yaml
ledger:
  migrations:
    enabled: false
```

> **Important:** If you manage the ledger schema through an external pipeline (e.g., managed-Postgres S3 restore, Liquibase), set `ledger.migrations.enabled: false` to prevent the Job from running.

#### Argo CD sync wave ordering

When the migration Job renders, the ledger Deployment is stamped with `argocd.argoproj.io/sync-wave: "1"` so it only applies after the Job reports `Complete`. The Job itself stays in the default wave (with the bundled PostgreSQL Secret it reads).

To order the Job ahead of the Deployment in a pre-provisioned database scenario:

```yaml
ledger:
  migrations:
    annotations:
      argocd.argoproj.io/hook: PreSync
```

> **Note:** The `deploymentSyncWave` annotation is ignored by plain `helm install` / `helm upgrade` — it only affects Argo CD.

#### Wait-for-postgres init container

The migration Job includes an optional init container that waits for the PostgreSQL endpoint before running `migrate`:

```yaml
ledger:
  migrations:
    waitForPostgres:
      enabled: true
      image:
        repository: busybox
        tag: "1.37"
```

Set `enabled: false` to skip the wait (e.g., when the database is always available).

#### Resource limits

```yaml
ledger:
  migrations:
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 50m
        memory: 64Mi
```

### 3. New Tracer component

Chart v9.1.0 introduces a new **Tracer** component (disabled by default), which provides transaction tracing and validation services.

| Setting | v9.0.0 | v9.1.0 |
|---------|--------|--------|
| `tracer.enabled` | (not present) | `false` (opt-in per environment) |
| `tracer.image.repository` | (not present) | `lerianstudio/midaz-tracer` |
| `tracer.image.tag` | (not present) | `4.0.0` |

#### Enabling Tracer

```yaml
tracer:
  enabled: true
  replicaCount: 1
  image:
    repository: lerianstudio/midaz-tracer
    tag: "4.0.0"
```

#### Tracer migration Job

Like the ledger, Tracer v4.0.0 no longer migrates its PostgreSQL schema at startup. A dedicated `midaz-tracer-migrations` Job applies the schema before the Deployment starts.

```yaml
tracer:
  migrations:
    enabled: true
    image:
      repository: lerianstudio/midaz-tracer-migrations
      pullPolicy: IfNotPresent
      tag: ""  # empty = tracks tracer.image.tag
    backoffLimit: 6
    activeDeadlineSeconds: 600
    ttlSecondsAfterFinished: 259200
    deploymentSyncWave: "1"
```

> **Note:** The migration Job is **always enabled** when `tracer.enabled: true`. Set `tracer.migrations.enabled: false` only if you apply the schema out-of-band.

#### Tracer database configuration

The Tracer requires a PostgreSQL database. By default, it uses the bundled PostgreSQL primary:

```yaml
tracer:
  configmap:
    DB_HOST: ""  # empty = bundled PostgreSQL primary
    DB_PORT: "5432"
    DB_USER: "midaz"
    DB_NAME: "tracer"
  secrets:
    DB_PASSWORD: ""
```

For an external PostgreSQL instance:

```yaml
tracer:
  configmap:
    DB_HOST: "postgresql.external.example.com"
    DB_PORT: "5432"
    DB_USER: "tracer_user"
    DB_NAME: "tracer_db"
  secrets:
    DB_PASSWORD: "your-secure-password"
```

> **Warning:** When `postgresql.enabled: false` or `postgresql.external: true`, you **must** set `tracer.configmap.DB_HOST` explicitly. The chart will fail to render if the host is missing.

#### Tracer authentication and multi-tenancy

The Tracer supports API key authentication and multi-tenant mode:

| Flag | Default | Description |
|------|---------|-------------|
| `API_KEY_ENABLED` | `false` | Enable API key authentication |
| `MULTI_TENANT_ENABLED` | `false` | Enable multi-tenant mode (requires `PLUGIN_AUTH_ENABLED: true`) |
| `PLUGIN_AUTH_ENABLED` | `false` | Enable plugin-based authentication |

**Example: Enable API key auth**

```yaml
tracer:
  configmap:
    API_KEY_ENABLED: "true"
    CORS_ALLOWED_ORIGINS: "https://app.example.com"
  secrets:
    API_KEY: "your-api-key-here"
```

> **Important:** When `API_KEY_ENABLED: true`, you **must** set `tracer.secrets.API_KEY` and `tracer.configmap.CORS_ALLOWED_ORIGINS` to a concrete origin list (not `*`). The chart validates these at render time.

**Example: Enable multi-tenant mode**

```yaml
tracer:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    PLUGIN_AUTH_ENABLED: "true"
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "your-tenant-service-key"
```

> **Warning:** `MULTI_TENANT_ENABLED: true` requires `PLUGIN_AUTH_ENABLED: true`. API-key-only auth cannot verify tenant JWT signatures, so any caller could forge a `tenantId`. The chart will fail to render if this constraint is violated.

#### Tracer service ports

The Tracer exposes two ports:

| Port | Default | Description |
|------|---------|-------------|
| `service.port` | `4021` | HTTP API port |
| `service.grpcPort` | `4021` | gRPC port |

The gRPC port is automatically synchronized with `TRACER_GRPC_PORT` when set:

```yaml
tracer:
  configmap:
    TRACER_GRPC_PORT: ":5000"
  service:
    grpcPort: 5000  # must match the numeric tail of TRACER_GRPC_PORT
```

### 4. Global datastore masks and cloud presets

Chart v9.1.0 introduces a new **global datastore mask** system that allows you to configure connection parameters once at the environment level and have them propagate to all components.

#### Cloud presets

Set `global.cloud` to `aws`, `gcp`, or `azure` to apply managed-cloud topology defaults (TLS, SSL modes, connection parameters) in one knob:

```yaml
global:
  cloud: "aws"
```

| Preset | Effect |
|--------|--------|
| `aws` | Enables Redis TLS, AmazonMQ `amqps`, RDS `sslmode=require`, DocumentDB TLS params |
| `gcp` | Enables Cloud SQL proxy settings, GCP-managed Redis TLS |
| `azure` | Enables Azure Database SSL, Azure Service Bus TLS |
| `""` (empty) | Uses bundled in-cluster infrastructure (plaintext) |

> **Note:** A cloud preset sets **topology** fields (ssl/tls/scheme/ports) but not **identity** fields (host/port/user/name). You still configure endpoints via `global.datastores` below.

#### Global datastore masks

Configure shared connection parameters once and let each component resolve its native environment keys from them:

```yaml
global:
  datastores:
    # Per-module identity (host/port/user/name)
    postgresOnboarding:
      host: "postgresql.internal"
      user: "midaz"
      name: "onboarding"
    postgresTransaction:
      host: "postgresql.internal"
      user: "midaz"
      name: "transaction"
    mongoOnboarding:
      host: "mongodb.internal"
      user: "midaz"
      name: "onboarding"
    mongoTransaction:
      host: "mongodb.internal"
      user: "midaz"
      name: "transaction"
    mongoCrm:
      host: "mongodb.internal"
      user: "midaz"
      name: "midaz-crm"
    mongoFees:
      host: "mongodb.internal"
      user: "plugin-fees"
      name: "plugin-fees-db"
    
    # Shared topology (ssl/tls/params)
    postgres:
      ssl: "require"
    mongo:
      params: "tls=true"
    redis:
      host: "valkey.internal"
      port: "6379"
      tls: "true"
    broker:
      host: "rabbitmq.internal"
      user: "midaz"
```

> **Note:** Per-component overrides (`ledger.datastores`, `crm.datastores`) take precedence over `global.datastores`. Native environment variables in `<component>.configmap` always win (the escape hatch).

#### Environment-wide observability

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector-lerian:4317"
    deploymentEnvironment: "production"
```

Each component's `OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` resolve from this block.

#### Environment-wide multi-tenancy

```yaml
global:
  multiTenant:
    url: "http://tenant-manager:8080"
    redisHost: "valkey.internal"
    redisPort: "6379"
    redisTls: "false"
```

#### Environment-wide streaming

```yaml
global:
  streaming:
    brokers: "kafka:9092"
    saslMechanism: "PLAIN"
    saslUsername: "midaz"
    tlsEnabled: "true"
```

#### Environment-wide auth

```yaml
global:
  auth:
    enabled: true
    host: "plugin-access-manager:3000"
```

#### Environment-wide service discovery

```yaml
global:
  serviceDiscovery:
    address: "consul:8500"
    namespace: "midaz"
```

### 5. MongoDB TLS support for bootstrap job

The MongoDB bootstrap job now supports TLS connections, required for managed TLS-only Mongo-API services like AWS DocumentDB.

**Before (v9.0.0):**

```yaml
global:
  externalMongoDefinitions:
    enabled: true
    host: "docdb.us-east-1.amazonaws.com"
    port: "27017"
```

**After (v9.1.0):**

```yaml
global:
  externalMongoDefinitions:
    enabled: true
    host: "docdb.us-east-1.amazonaws.com"
    port: "27017"
    tls:
      enabled: true
      insecure: true  # DocumentDB doesn't ship its CA in every client trust store
```

| Flag | Default | Description |
|------|---------|-------------|
| `tls.enabled` | `false` | Enable TLS on the mongosh connection (`--tls`) |
| `tls.insecure` | `true` | Skip certificate/hostname verification (`--tlsAllowInvalidHostnames --tlsAllowInvalidCertificates`) |

> **Note:** The `tls.insecure` flag is only read when `tls.enabled: true`. The mongo:8 image's mongosh removed the older `--tlsInsecure` shorthand; the chart now uses `--tlsAllowInvalidHostnames --tlsAllowInvalidCertificates` instead.

#### Why this matters

Without TLS support, the bootstrap job would fail outright against DocumentDB or any TLS-only MongoDB service. The `insecure: true` default skips hostname/CA verification because DocumentDB doesn't ship its CA in every client trust store by default.

### 6. Ledger CRM and Fees module integration

The unified ledger binary (midaz v4) now opens the CRM and Fees MongoDB databases in-process. New secrets and configuration have been added to support this.

#### New MongoDB credentials

```yaml
ledger:
  secrets:
    MONGO_CRM_PASSWORD: ""
    MONGO_FEES_PASSWORD: ""
```

> **Important:** These passwords are rendered into the ledger Secret, never the ConfigMap. They follow the same single-source rule as `MONGO_ONBOARDING_PASSWORD` and `MONGO_TRANSACTION_PASSWORD`.

#### New Fees role in bootstrap job

The MongoDB bootstrap job now creates a `readWrite` role for the `fees` database:

```yaml
global:
  externalMongoDefinitions:
    midazCredentials:
      roles:
        - role: "readWrite"
          db: "onboarding"
        - role: "readWrite"
          db: "transaction"
        - role: "readWrite"
          db: "crm"
        - role: "readWrite"
          db: "fees"  # NEW
```

### 7. Ledger KMS and crypto configuration

The ledger now supports envelope encryption via HashiCorp Vault and operator-provided symmetric keys for CRM holder-field crypto (lib-crypto).

#### Symmetric key crypto (legacy mode)

When `KMS_VENDOR` is unset or `"none"`, the ledger uses operator-provided symmetric keys to protect PII at rest:

```yaml
ledger:
  secrets:
    LCRYPTO_HASH_SECRET_KEY: "your-hex-encoded-hash-key"
    LCRYPTO_ENCRYPT_SECRET_KEY: "your-hex-encoded-encrypt-key"
```

> **Important:** Both keys must be hex-encoded AES keys (32, 48, or 64 hex characters for AES-128/192/256). The chart validates this at render time. Non-hex values or wrong lengths will fail the render with a descriptive error.

#### Envelope encryption (Vault mode)

When `KMS_VENDOR: "hashicorp-vault"`, the ledger uses Vault AppRole authentication:

```yaml
ledger:
  configmap:
    KMS_VENDOR: "hashicorp-vault"
    KMS_VAULT_ROLE_ID: "your-role-id"
  secrets:
    KMS_VAULT_SECRET_ID: "your-secret-id"
```

> **Note:** The RoleID is not secret and stays in the ConfigMap. The SecretID is the credential half and is rendered into the Secret.

### 8. Ledger billing and identity provider integration

The ledger now supports billing event emission (via Schema Registry) and RI permission declaration to an IdP identity service.

#### Billing (Schema Registry)

```yaml
ledger:
  configmap:
    STREAMING_SCHEMA_REGISTRY_URL: "http://schema-registry:8081"
```

> **Note:** Leave empty to keep billing emission disabled.

#### Identity provider declaration

```yaml
ledger:
  configmap:
    IDP_DECLARATION_ENABLED: "false"
    IDP_HOST: ""
    IDP_M2M_CLIENT_ID: ""
  secrets:
    IDP_M2M_CLIENT_SECRET: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `IDP_DECLARATION_ENABLED` | `false` | Turn on manifest publication at boot (fail-open) |
| `IDP_HOST` | `""` | IdP identity service endpoint (`:4001`, distinct from auth `:4000`) |
| `IDP_M2M_CLIENT_ID` | `""` | M2M client ID for RI permission declaration |
| `IDP_M2M_CLIENT_SECRET` | `""` | M2M client secret (rendered into Secret) |

> **Warning:** Under `DEPLOYMENT_MODE: saas`, `IDP_HOST` **must** be an `https://` URL.

### 9. CRM v3.8.4 with simplified configuration

The CRM component has been upgraded from v3.8.2 to v3.8.4 and its configuration surface has been simplified.

| Setting | v9.0.0 | v9.1.0 |
|---------|--------|--------|
| `crm.image.tag` | `3.8.2` | `3.8.4` |
| `crm.configmap` | 30+ explicit env vars | Mask-based (override via `crm.datastores` or `crm.configmap`) |

#### What changed

**Before (v9.0.0):**

```yaml
crm:
  configmap:
    ALLOW_INSECURE_TLS: "true"
    ENV_NAME: "development"
    PLUGIN_AUTH_ENABLED: "false"
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth:4000"
    MONGO_HOST: "midaz-mongodb"
    MONGO_NAME: "crm"
    MONGO_PORT: "27017"
    MONGO_USER: "midaz"
    RATE_LIMIT_ENABLED: "true"
    RATE_LIMIT_MAX: "500"
    # ... 20+ more fields
```

**After (v9.1.0):**

```yaml
crm:
  datastores: {}  # override global.datastores.mongoCrm here
  configmap: {}   # escape hatch: any native env var overrides the template default
```

All connection parameters now resolve from `global.datastores.mongoCrm` (or `crm.datastores.mongo`) and the lerian-common-helm masks. Explicit overrides go in `crm.configmap`.

> **Note:** The CRM's shipped defaults (rate limiting, auth, etc.) are unchanged. The difference is that they now render from the mask system instead of being hardcoded in `values.yaml`.

## Configuration Reference

### Global configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `global.cloud` | string | `""` | Managed-cloud topology preset: `aws`, `gcp`, `azure`, or `""` (bundled in-cluster) |
| `global.datastores` | object | `{}` | Shared datastore masks (see [Feature 4](#4-global-datastore-masks-and-cloud-presets)) |
| `global.env` | object | `{}` | Environment name (consumed by lerian-common.globalValue) |
| `global.observability` | object | `{}` | OTel collector configuration |
| `global.multiTenant` | object | `{}` | Tenant-manager configuration |
| `global.streaming` | object | `{}` | Kafka/RedPanda configuration |
| `global.auth` | object | `{}` | Plugin-access-manager configuration |
| `global.serviceDiscovery` | object | `{}` | Consul configuration |
| `global.externalMongoDefinitions.tls` | object | `{ enabled: false, insecure: true }` | TLS for bootstrap job's mongosh connection |

### Ledger configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `ledger.image.tag` | string | `"4.0.0"` | Ledger image tag |
| `ledger.migrations.enabled` | bool | `nil` (auto) | Run migration Job (auto: on for 4.x, off for 3.x) |
| `ledger.migrations.image.repository` | string | `lerianstudio/midaz-ledger-migrations` | Migration runner image |
| `ledger.migrations.image.tag` | string | `""` (tracks ledger.image.tag) | Migration image tag |
| `ledger.migrations.backoffLimit` | int | `6` | Retries before Job is marked failed |
| `ledger.migrations.activeDeadlineSeconds` | int | `600` | Hard timeout for the Job |
| `ledger.migrations.ttlSecondsAfterFinished` | int | `259200` | How long the finished Job is kept |
| `ledger.migrations.deploymentSyncWave` | string | `"1"` | Argo CD sync wave for ledger Deployment |
| `ledger.datastores` | object | `{}` | Dedicated datastore masks (override global.datastores) |
| `ledger.configmap.STREAMING_SCHEMA_REGISTRY_URL` | string | `""` | Schema Registry for billing serializer |
| `ledger.configmap.IDP_DECLARATION_ENABLED` | string | `"false"` | Enable RI permission declaration at boot |
| `ledger.configmap.IDP_HOST` | string | `""` | IdP identity service endpoint |
| `ledger.configmap.IDP_M2M_CLIENT_ID` | string | `""` | M2M client ID |
| `ledger.secrets.MONGO_CRM_PASSWORD` | string | `""` | CRM module MongoDB password |
| `ledger.secrets.MONGO_FEES_PASSWORD` | string | `""` | Fees module MongoDB password |
| `ledger.secrets.LCRYPTO_HASH_SECRET_KEY` | string | `""` | Symmetric hash key (hex-encoded AES) |
| `ledger.secrets.LCRYPTO_ENCRYPT_SECRET_KEY` | string | `""` | Symmetric encrypt key (hex-encoded AES) |
| `ledger.secrets.KMS_VAULT_SECRET_ID` | string | `""` | Vault AppRole SecretID |
| `ledger.secrets.IDP_M2M_CLIENT_SECRET` | string | `""` | M2M client secret |

### Tracer configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `tracer.enabled` | bool | `false` | Enable Tracer component |
| `tracer.image.repository` | string | `lerianstudio/midaz-tracer` | Tracer image repository |
| `tracer.image.tag` | string | `"4.0.0"` | Tracer image tag |
| `tracer.migrations.enabled` | bool | `true` | Run migration Job |
| `tracer.migrations.image.repository` | string | `lerianstudio/midaz-tracer-migrations` | Migration runner image |
| `tracer.migrations.image.tag` | string | `""` (tracks tracer.image.tag) | Migration image tag |
| `tracer.configmap.DB_HOST` | string | `""` (bundled PostgreSQL) | PostgreSQL host |
| `tracer.configmap.DB_PORT` | string | `"5432"` | PostgreSQL port |
| `tracer.configmap.DB_USER` | string | `"midaz"` | PostgreSQL user |
| `tracer.configmap.DB_NAME` | string | `"tracer"` | PostgreSQL database name |
| `tracer.configmap.API_KEY_ENABLED` | string | `"false"` | Enable API key authentication |
| `tracer.configmap.MULTI_TENANT_ENABLED` | string | `"false"` | Enable multi-tenant mode |
| `tracer.configmap.PLUGIN_AUTH_ENABLED` | string | `"false"` | Enable plugin-based authentication |
| `tracer.secrets.DB_PASSWORD` | string | `""` | PostgreSQL password |
| `tracer.secrets.API_KEY` | string | `""` | API key (required when API_KEY_ENABLED=true) |
| `tracer.secrets.MULTI_TENANT_SERVICE_API_KEY` | string | `""` | Tenant service key (required when MULTI_TENANT_ENABLED=true) |

### CRM configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `crm.image.tag` | string | `"3.8.4"` | CRM image tag |
| `crm.datastores` | object | `{}` | Dedicated datastore mask (override global.datastores) |
| `crm.configmap` | object | `{}` | Escape hatch: native env vars override template defaults |

## Migration Steps

1. **Review the ledger migration Job configuration.** If you manage the ledger schema out-of-band, disable the Job:

   ```yaml
   ledger:
     migrations:
       enabled: false
   ```

2. **Configure Tracer if needed.** The Tracer component is disabled by default. Enable it only if your environment requires transaction tracing:

   ```yaml
   tracer:
     enabled: true
     configmap:
       DB_HOST: "postgresql.external.example.com"
     secrets:
       DB_PASSWORD: "your-secure-password"
   ```

3. **Set MongoDB TLS for DocumentDB or other TLS-only services:**

   ```yaml
   global:
     externalMongoDefinitions:
       tls:
         enabled: true
         insecure: true
   ```

4. **Configure CRM and Fees MongoDB credentials for the unified ledger:**

   ```yaml
   ledger:
     secrets:
       MONGO_CRM_PASSWORD: "your-crm-password"
       MONGO_FEES_PASSWORD: "your-fees-password"
   ```

5. **Set symmetric crypto keys if the ledger serves CRM and KMS_VENDOR is unset:**

   ```yaml
   ledger:
     secrets:
       LCRYPTO_HASH_SECRET_KEY: "your-hex-encoded-hash-key"
       LCRYPTO_ENCRYPT_SECRET_KEY: "your-hex-encoded-encrypt-key"
   ```

   > **Important:** Both keys must be 32, 48, or 64 hex characters (AES-128/192/256). The chart validates this at render time.

6. **Optionally adopt global datastore masks.** If you manage multiple environments with different connection parameters, consolidate them in `global.datastores`:

   ```yaml
   global:
     cloud: "aws"
     datastores:
       postgresOnboarding:
         host: "postgresql.internal"
         user: "midaz"
         name: "onboarding"
       redis:
         host: "valkey.internal"
         port: "6379"
         tls: "true"
   ```

7. **Run `helm dependency update` to fetch the new lerian-common-helm dependency:**

   ```bash
   helm dependency update charts/midaz
   ```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.1.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.1.0 -n midaz
```
