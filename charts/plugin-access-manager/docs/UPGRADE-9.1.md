# Helm Upgrade from v9.0.0 to v9.1.0

# Topics

- **[Features](#features)**
  - [1. Lerian Common Helm Library Integration](#1-lerian-common-helm-library-integration)
  - [2. Global Configuration Masks](#2-global-configuration-masks)
  - [3. Datastore Connection Masks](#3-datastore-connection-masks)
  - [4. Service Discovery Configuration](#4-service-discovery-configuration)
  - [5. OpenTelemetry Configuration Consolidation](#5-opentelemetry-configuration-consolidation)
  - [6. Template Refactoring](#6-template-refactoring)
  - [7. Auth Backend Service Configuration](#7-auth-backend-service-configuration)
- **[Configuration Reference](#configuration-reference)**
  - [Global Configuration](#global-configuration)
  - [Datastore Masks](#datastore-masks)
  - [Service Discovery](#service-discovery)
  - [Environment Variables](#environment-variables)
- **[Migration Guide](#migration-guide)**
  - [Step 1: Review Your Current Configuration](#step-1-review-your-current-configuration)
  - [Step 2: Migrate to Global Masks (Optional)](#step-2-migrate-to-global-masks-optional)
  - [Step 3: Update Service Discovery Configuration (If Enabled)](#step-3-update-service-discovery-configuration-if-enabled)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Lerian Common Helm Library Integration

This release introduces the `lerian-common-helm` library chart as a dependency, providing shared templates and configuration patterns across all Lerian Studio charts.

**What changed:**

A new chart dependency has been added:

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.0.0"
    repository: "oci://ghcr.io/lerianstudio"
```

**Why this matters:**

- Standardized configuration patterns across all Lerian Studio charts
- Reduced template duplication and maintenance burden
- Consistent behavior for datastore connections, service discovery, and observability
- Foundation for managed cloud topology presets (AWS, GCP, Azure)

**What operators need to do:**

The library is automatically pulled as a chart dependency. After upgrading, run:

```bash
helm dependency update
```

> **Note:** This is a foundational change that enables the new configuration masks described in the following sections. Your existing configuration will continue to work without modification.

### 2. Global Configuration Masks

Version 9.1.0 introduces a new `global` configuration block that allows you to set environment-wide defaults once instead of duplicating them across multiple components.

**What changed:**

A new top-level `global` section has been added to `values.yaml`:

```yaml
global:
  cloud: ""
  datastores: {}
  env: {}
  multiTenant: {}
  serviceDiscovery: {}
  observability: {}
```

**Why this matters:**

Previously, configuration like `ENV_NAME`, `MULTI_TENANT_ENABLED`, and `ENABLE_TELEMETRY` had to be set separately for both the `auth` and `identity` components. Now you can set these once in the `global` block, and both components will inherit the values.

**Configuration precedence:**

The new mask system follows this precedence order (highest to lowest):

1. Native component configmap key (e.g., `auth.configmap.ENV_NAME`)
2. Dedicated component-level override (e.g., `auth.datastores`)
3. Global shared mask (e.g., `global.datastores`)
4. Cloud topology preset (e.g., `global.cloud: "aws"`)
5. Chart default value

**Example: Setting environment name globally**

**Before (v9.0.0):**

```yaml
auth:
  configmap:
    ENV_NAME: "production"

identity:
  configmap:
    ENV_NAME: "production"
```

**After (v9.1.0):**

```yaml
global:
  env:
    name: "production"

# auth.configmap.ENV_NAME and identity.configmap.ENV_NAME are no longer needed
```

> **Important:** If you have `ENV_NAME` set in `auth.configmap` or `identity.configmap`, it will override the global value. Remove these keys to use the global mask.

### 3. Datastore Connection Masks

Database and Redis connection parameters can now be configured once at the environment level using the new datastore masks.

**What changed:**

Connection parameters previously hardcoded in component configmaps are now resolved through a mask system:

| Setting | v9.0.0 Location | v9.1.0 Location |
|---------|----------------|-----------------|
| PostgreSQL host | `auth.configmap.DB_HOST` | `global.datastores.postgres.host` |
| PostgreSQL port | `auth.configmap.DB_PORT` | `global.datastores.postgres.port` |
| PostgreSQL user | `auth.configmap.DB_USER` | `global.datastores.postgres.user` |
| PostgreSQL SSL mode | `auth.configmap.DB_SSLMODE` | `global.datastores.postgres.ssl` |
| Redis host | `auth.configmap.REDIS_HOST` | `global.datastores.redis.host` |
| Redis port | `auth.configmap.REDIS_PORT` | `global.datastores.redis.port` |
| Redis user | `auth.configmap.REDIS_USER` | `global.datastores.redis.user` |
| Redis TLS | `auth.configmap.REDIS_TLS` | `global.datastores.redis.tls` |
| Redis CA cert | `auth.configmap.REDIS_CA_CERT` | `global.datastores.redis.caCert` |

**Why this matters:**

- Configure external datastores (RDS, ElastiCache, Cloud SQL, etc.) once for the entire environment
- Automatically apply cloud-specific defaults (TLS, SSL modes, ports) based on the `global.cloud` preset
- Eliminate duplication between auth and identity components
- Support per-component overrides when needed (e.g., different databases for auth vs. identity)

**Default behavior:**

If you don't configure the global masks, the chart continues to use the bundled in-cluster PostgreSQL and Valkey (Redis-compatible) instances with the same defaults as v9.0.0.

**Example: Configuring external datastores**

```yaml
global:
  cloud: "aws"
  datastores:
    postgres:
      host: "my-rds-instance.us-east-1.rds.amazonaws.com"
      port: "5432"
      user: "access_manager"
      ssl: "require"
    redis:
      host: "my-elasticache.abc123.0001.use1.cache.amazonaws.com"
      port: "6379"
      user: "default"
      tls: "true"
```

> **Note:** The `global.cloud: "aws"` preset automatically sets `postgres.ssl: "require"` and `redis.tls: "true"` unless you explicitly override them.

**Example: Per-component override**

If you need different database hosts for auth and identity:

```yaml
global:
  datastores:
    postgres:
      host: "shared-postgres.example.com"
      user: "shared_user"

auth:
  datastores:
    postgres:
      host: "auth-specific-postgres.example.com"
      user: "auth_user"

# identity will use shared-postgres.example.com
# auth will use auth-specific-postgres.example.com
```

> **Warning:** Do not set connection parameters in both `auth.configmap.DB_*` and `global.datastores.postgres`. The native configmap keys take precedence and will override the mask, defeating the purpose of centralized configuration.

### 4. Service Discovery Configuration

Service discovery (Consul) configuration has been enhanced with a new mask system that derives all `SD_*` environment variables from a single global configuration block.

**What changed:**

| Setting | v9.0.0 | v9.1.0 |
|---------|--------|--------|
| Opt-in flag | `auth.configmap.SD_ENABLED` | `auth.configmap.SD_ENABLED` (unchanged) |
| Consul address | `auth.configmap.SD_ADDRESS` | `global.serviceDiscovery.address` |
| External address | `auth.configmap.SD_EXTERNAL_ADDRESS` | Derived from ingress host |
| External port | `auth.configmap.SD_EXTERNAL_PORT` | `global.serviceDiscovery.externalPort` |
| TLS enabled | `auth.configmap.SD_TLS` | `global.serviceDiscovery.tls` |

**Why this matters:**

When `SD_ENABLED=true`, the chart now automatically derives the full set of service discovery environment variables (`SD_ADDRESS`, `SD_EXTERNAL_ADDRESS`, `SD_EXTERNAL_PORT`, `SD_TLS`, `SD_TLS_SKIP_VERIFY`, `SD_WORKLOAD`, `SD_PREFER_VIEW`, `SD_INTERNAL_SCHEME`) from the global configuration and component metadata (service ports, ingress hosts).

> **Important:** `SD_ENABLED` is **not** part of the `global.serviceDiscovery` mask — it is read directly from each component's own `configmap.SD_ENABLED` (`auth.configmap.SD_ENABLED`, `identity.configmap.SD_ENABLED`). The global block only supplies the *connection* settings (`address`, `tls`, `externalPort`, ...) once you opt a component in. Setting `global.serviceDiscovery.*` alone does **not** enable service discovery for any component — you must still set `SD_ENABLED: "true"` on every component (`auth`, `identity`) you want registered with Consul.

**Backward compatibility:**

When `SD_ENABLED` is unset or `false`, the legacy static `SD_*` keys in `auth.configmap` and `identity.configmap` continue to work exactly as before, ensuring zero diff for existing installations.

**Before (v9.0.0):**

```yaml
auth:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.internal:8500"
    SD_EXTERNAL_ADDRESS: "auth.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"

identity:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.internal:8500"
    SD_EXTERNAL_ADDRESS: "identity.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"
```

**After (v9.1.0):**

```yaml
global:
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"
    externalPort: "443"

auth:
  configmap:
    SD_ENABLED: "true"

identity:
  configmap:
    SD_ENABLED: "true"
```

> **Note:** The `SD_EXTERNAL_ADDRESS` is automatically derived from the first ingress host configured for each component. If no ingress is configured, it falls back to the internal Kubernetes service name.

### 5. OpenTelemetry Configuration Consolidation

OpenTelemetry configuration has been consolidated using the `lerian-common.otel.envFlat` template helper.

**What changed:**

The following OpenTelemetry environment variables are now managed through a shared template:

| Variable | Default (v9.0.0) | Default (v9.1.0) |
|----------|------------------|------------------|
| `OTEL_RESOURCE_SERVICE_NAME` | `"auth"` | `"auth"` (unchanged) |
| `OTEL_LIBRARY_NAME` | `"github.com/LerianStudio/auth"` | `"github.com/LerianStudio/auth"` (unchanged) |
| `OTEL_RESOURCE_SERVICE_VERSION` | `auth.image.tag` | `auth.image.tag` (unchanged) |
| `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `"dev"` | `"dev"` (unchanged) |
| `OTEL_EXPORTER_OTLP_ENDPOINT_PORT` | `"4317"` | `"4317"` (unchanged) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `""` | `""` (unchanged) |
| `ENABLE_TELEMETRY` | `"true"` | `global.observability.enabled` or `"true"` |

**Why this matters:**

- Consistent OpenTelemetry configuration across all components
- The `ENABLE_TELEMETRY` flag can now be set globally via `global.observability.enabled`
- Reduced template duplication

**Example: Enabling telemetry globally**

```yaml
global:
  observability:
    enabled: true
```

> **Note:** If you have `ENABLE_TELEMETRY` set in `auth.configmap` or `identity.configmap`, it will override the global value.

### 6. Template Refactoring

Several Kubernetes resource templates have been refactored to use shared helpers from the `lerian-common-helm` library.

**What changed:**

| Resource | Change |
|----------|--------|
| HorizontalPodAutoscaler | Now uses `lerian-common.hpa` template |
| PodDisruptionBudget | Now uses `lerian-common.pdb` template |
| Service (auth-backend) | Now uses `lerian-common.service` template |

**Why this matters:**

- Consistent resource definitions across all Lerian Studio charts
- Bug fixes and improvements in the library automatically benefit all charts
- Reduced maintenance burden

**Operational impact:**

These changes are transparent to operators. The rendered Kubernetes manifests remain functionally identical, with only minor formatting differences.

**Example: PodDisruptionBudget default change**

The auth-backend PodDisruptionBudget now has an explicit `minAvailable: 1` default (previously `minAvailable: 0`):

**Before (v9.0.0):**

```yaml
spec:
  minAvailable: 0
```

**After (v9.1.0):**

```yaml
spec:
  minAvailable: 1
```

> **Note:** This change only affects deployments with `auth.pdb.enabled: true` and no explicit `minAvailable` or `maxUnavailable` value set.

**Example: Auth backend migrations Job name truncation**

The auth-backend migrations Job name is now truncated to 63 characters to prevent Kubernetes validation errors:

**Before (v9.0.0):**

```yaml
metadata:
  name: {{ include "plugin-auth-backend.fullname" . }}-migrations
```

**After (v9.1.0):**

```yaml
metadata:
  name: {{ printf "%s-migrations" (include "plugin-auth-backend.fullname" .) | trunc 63 | trimSuffix "-" }}
```

**Why this matters:**

The Job controller automatically adds a `job-name` label to pods with the Job name as the value. If the Job name exceeds 63 characters, the label value becomes invalid and the Job fails to create pods. This fix prevents that failure in environments with long release names.

### 7. Auth Backend Service Configuration

The auth-backend service configuration has been moved from the top-level `auth.service` block to a dedicated `auth.backend.service` block.

**What changed:**

| Setting | v9.0.0 Location | v9.1.0 Location |
|---------|----------------|-----------------|
| Service type | `auth.service.type` | `auth.backend.service.type` |
| Service port | Hardcoded `8000` | `auth.backend.service.port` |

**Why this matters:**

- Clearer separation between the auth service (port 4000) and auth-backend service (port 8000)
- The auth-backend service port is now configurable instead of hardcoded

**Default values:**

```yaml
auth:
  backend:
    service:
      type: ClusterIP
      port: 8000
```

> **Note:** If you were overriding `auth.service.type` expecting it to affect the auth-backend, you now need to set `auth.backend.service.type` instead.

# Configuration Reference

### Global Configuration

The new `global` block provides environment-wide defaults:

```yaml
global:
  # Cloud topology preset: aws | gcp | azure
  cloud: ""
  
  # Environment name
  env:
    name: "production"
  
  # Multi-tenancy gate
  multiTenant:
    enabled: false
  
  # Observability gate
  observability:
    enabled: true
  
  # Datastore connection masks
  datastores:
    postgres:
      host: "postgres.example.com"
      port: "5432"
      user: "access_manager"
      ssl: "require"
    redis:
      host: "redis.example.com"
      port: "6379"
      user: "default"
      tls: "true"
      caCert: ""
  
  # Service discovery configuration
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"
    tlsSkipVerify: "false"
    workload: ""
    preferView: ""
    internalScheme: ""
    externalPort: "443"
```

| Field | Default | Description |
|-------|---------|-------------|
| `cloud` | `""` | Cloud topology preset (`aws`, `gcp`, `azure`, or empty for bundled in-cluster) |
| `env.name` | `"development"` | Environment name (development, staging, production) |
| `multiTenant.enabled` | `false` | Enable multi-tenancy features |
| `observability.enabled` | `true` | Enable OpenTelemetry instrumentation |
| `datastores.postgres.*` | See table below | PostgreSQL connection parameters |
| `datastores.redis.*` | See table below | Redis connection parameters |
| `serviceDiscovery.*` | See table below | Consul service discovery parameters |

### Datastore Masks

#### PostgreSQL Configuration

| Field | Default | Description |
|-------|---------|-------------|
| `host` | Bundled auth-database service | PostgreSQL server hostname |
| `port` | `"5432"` | PostgreSQL server port |
| `user` | `"auth"` | PostgreSQL username |
| `ssl` | `"disable"` | SSL mode (`disable`, `require`, `verify-ca`, `verify-full`) |

#### Redis Configuration

| Field | Default | Description |
|-------|---------|-------------|
| `host` | Bundled valkey service | Redis server hostname |
| `port` | `"6379"` | Redis server port |
| `user` | `"auth"` | Redis username (Redis 6+ ACL) |
| `tls` | `"false"` | Enable TLS connection |
| `caCert` | `""` | CA certificate for TLS verification |

### Service Discovery

When `SD_ENABLED=true`, the following fields configure Consul integration:

| Field | Default | Description |
|-------|---------|-------------|
| `address` | `"localhost:8500"` | Consul agent address |
| `tls` | `"false"` | Enable TLS for Consul connection |
| `tlsSkipVerify` | `"false"` | Skip TLS certificate verification |
| `workload` | `""` | Workload identifier for service registration |
| `preferView` | `""` | Preferred service view (internal/external) |
| `internalScheme` | `""` | Scheme for internal service URLs |
| `externalPort` | `"0"` | External port for service registration |

### Environment Variables

#### Removed from values.yaml

The following environment variables have been removed from the default `values.yaml` because they are now resolved through masks or have defaults in the templates:

**Auth component:**

- `DB_USER` (use `global.datastores.postgres.user`)
- `DB_PORT` (use `global.datastores.postgres.port`)
- `DB_SSLMODE` (use `global.datastores.postgres.ssl`)
- `REDIS_HOST` (use `global.datastores.redis.host`)
- `REDIS_PORT` (use `global.datastores.redis.port`)
- `REDIS_USER` (use `global.datastores.redis.user`)
- `REDIS_TLS` (use `global.datastores.redis.tls`)
- `REDIS_CA_CERT` (use `global.datastores.redis.caCert`)
- `ENV_NAME` (use `global.env.name`)

**Identity component:**

- `ENV_NAME` (use `global.env.name`)
- `AUTH_ENABLED` (default in template)
- `AUTH_PORT` (default in template)

> **Important:** These variables can still be set directly in `auth.configmap` or `identity.configmap` if you need to override the mask values. The native configmap keys take precedence.

# Migration Guide

### Step 1: Review Your Current Configuration

Before upgrading, review your current `values.yaml` to identify any configuration that can be migrated to the new global masks.

**Check for duplicated configuration:**

```bash
# Look for duplicated environment names
grep -A 1 "ENV_NAME:" values.yaml

# Look for duplicated datastore configuration
grep -A 1 "DB_HOST:\|REDIS_HOST:" values.yaml
```

### Step 2: Migrate to Global Masks (Optional)

Migrating to global masks is optional but recommended for cleaner configuration.

#### Option 1: Keep Existing Configuration

Your existing configuration will continue to work without modification. Native configmap keys take precedence over global masks.

```yaml
# This continues to work in v9.1.0
auth:
  configmap:
    ENV_NAME: "production"
    DB_HOST: "postgres.example.com"
    DB_PORT: "5432"
    REDIS_HOST: "redis.example.com"
    REDIS_PORT: "6379"
```

#### Option 2: Migrate to Global Masks

For cleaner configuration, migrate duplicated values to the global block:

**Before (v9.0.0):**

```yaml
auth:
  configmap:
    ENV_NAME: "production"
    DB_HOST: "postgres.example.com"
    DB_PORT: "5432"
    DB_USER: "auth"
    DB_SSLMODE: "require"
    REDIS_HOST: "redis.example.com"
    REDIS_PORT: "6379"
    REDIS_USER: "auth"
    REDIS_TLS: "true"
    MULTI_TENANT_ENABLED: "true"
    ENABLE_TELEMETRY: "true"

identity:
  configmap:
    ENV_NAME: "production"
    MULTI_TENANT_ENABLED: "true"
    ENABLE_TELEMETRY: "true"
```

**After (v9.1.0):**

```yaml
global:
  env:
    name: "production"
  multiTenant:
    enabled: true
  observability:
    enabled: true
  datastores:
    postgres:
      host: "postgres.example.com"
      port: "5432"
      user: "auth"
      ssl: "require"
    redis:
      host: "redis.example.com"
      port: "6379"
      user: "auth"
      tls: "true"

# Remove duplicated keys from auth.configmap and identity.configmap
auth:
  configmap: {}

identity:
  configmap: {}
```

> **Note:** After migrating to global masks, remove the corresponding keys from `auth.configmap` and `identity.configmap` to avoid confusion about which value is active.

### Step 3: Update Service Discovery Configuration (If Enabled)

If you have service discovery enabled (`SD_ENABLED=true`), migrate the static `SD_*` keys to the global mask:

**Before (v9.0.0):**

```yaml
auth:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.internal:8500"
    SD_EXTERNAL_ADDRESS: "auth.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"

identity:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.internal:8500"
    SD_EXTERNAL_ADDRESS: "identity.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"
```

**After (v9.1.0):**

```yaml
global:
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"
    externalPort: "443"

auth:
  configmap:
    SD_ENABLED: "true"
  ingress:
    enabled: true
    hosts:
      - host: auth.example.com
        paths:
          - path: /
            pathType: Prefix

identity:
  configmap:
    SD_ENABLED: "true"
  ingress:
    enabled: true
    hosts:
      - host: identity.example.com
        paths:
          - path: /
            pathType: Prefix
```

> **Note:** The `SD_EXTERNAL_ADDRESS` is now automatically derived from the first ingress host. Remove the `SD_EXTERNAL_ADDRESS` key from your configmaps.

# Known Gotchas (Field-Verified)

The following were found while running a real `global.cloud: "aws"` install against managed RDS/ElastiCache. They are not template-diff changes, so they don't show up in the sections above — they are operational pitfalls worth knowing before you configure the masks.

### Redis `caCert` must be Amazon's root CA, not the RDS bundle

`global.datastores.redis.caCert` (or `auth.configmap.REDIS_CA_CERT`) must be the **Amazon Root CA1** certificate, not the RDS regional truststore bundle (`https://truststore.pki.rds.amazonaws.com/...`). RDS's bundle signs RDS/Aurora endpoints; ElastiCache/MemoryDB (and managed Valkey) TLS certificates chain to Amazon's general trust root instead. Using the RDS bundle fails at connection time with:

```
x509: certificate signed by unknown authority
```

Fetch the correct certificate with:

```bash
curl -s https://www.amazontrust.com/repository/AmazonRootCA1.pem | base64 -w0
```

and set the base64 output as `global.datastores.redis.caCert`.

### Dedicated (non-master) PostgreSQL role

Running with a dedicated, least-privilege PostgreSQL role instead of the RDS/Aurora master user is the recommended production pattern. `auth.backend.createDatabase` controls whether the auth-backend (Casdoor) migrations attempt `CREATE DATABASE` themselves:

- `createDatabase: true` (default) — the connecting user must have `CREATEDB`. Fine with the master user, but defeats least-privilege if you've already created a dedicated role.
- `createDatabase: false` — use this when the database is pre-created by a dedicated role that does **not** have `CREATEDB` (e.g., provisioned by your own bootstrap job, Terraform, or DBA tooling). The migrations Job connects and runs schema migrations only.

Example: pre-create the dedicated role and database once (outside the chart), then point the chart at it without `CREATEDB`:

```sql
CREATE ROLE plugin_access_manager WITH LOGIN PASSWORD '...';
CREATE DATABASE casdoor OWNER plugin_access_manager;
```

```yaml
global:
  datastores:
    postgres:
      host: "my-rds-instance.us-east-1.rds.amazonaws.com"
      user: "plugin_access_manager"

auth:
  backend:
    createDatabase: false
```

> **Note:** This is unrelated to `auth.configmap.SD_ENABLED` or the datastore masks above — it is a one-time provisioning decision, independent of whether you use `global.datastores` or native `configmap.DB_*` keys.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.1.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.1.0 -n plugin-access-manager
```
