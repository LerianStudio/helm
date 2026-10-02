# Helm Upgrade from v9.4.0 to v9.5.0

## Topics

- **[Features](#features)**
  - [1. Application version bump to 4.2.0](#1-application-version-bump-to-420)
  - [2. Multi-tenant configuration expansion](#2-multi-tenant-configuration-expansion)
  - [3. Ledger service enhancements](#3-ledger-service-enhancements)
  - [4. Tracer service enhancements](#4-tracer-service-enhancements)
  - [5. CRM service multi-tenant support](#5-crm-service-multi-tenant-support)
  - [6. RabbitMQ TLS support](#6-rabbitmq-tls-support)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version bump to 4.2.0

The Midaz application components have been upgraded from version `4.1.2` to `4.2.0`.

| Component | v9.4.0 | v9.5.0 |
|-----------|--------|--------|
| Chart version | 9.4.0 | 9.5.0 |
| App version | 4.1.2 | 4.2.0 |
| Ledger image tag | 4.1.2 | 4.2.0 |
| Tracer image tag | 4.1.2 | 4.2.0 |

For application-level changes, refer to the [Midaz changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

### 2. Multi-tenant configuration expansion

Multi-tenant support has been significantly enhanced across all services with new configuration options for connection management, health checks, and circuit breakers.

#### Ledger multi-tenant configuration

**Before (v9.4.0):**

```yaml
ledger:
  configmap:
    MULTI_TENANT_ENABLED: "false"
```

**After (v9.5.0):**

```yaml
ledger:
  configmap:
    MULTI_TENANT_ENABLED: "false"
    # New: Seconds between tenant-connection health checks; 0 keeps the library default
    MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "0"
```

#### Tracer multi-tenant configuration

The tracer service now includes comprehensive multi-tenant settings with connection pooling, circuit breaker configuration, and Redis support.

**New environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC` | `"0"` | Seconds between tenant-connection health checks; 0 keeps the library default |
| `MULTI_TENANT_TIMEOUT` | `"30"` | Timeout for multi-tenant operations |
| `MULTI_TENANT_POOL_MAX_OPEN` | `"100"` | Maximum open connections in the pool |
| `MULTI_TENANT_POOL_MAX_IDLE` | `"300"` | Maximum idle connections in the pool |
| `MULTI_TENANT_BREAKER_THRESHOLD` | `"5"` | Circuit breaker failure threshold |
| `MULTI_TENANT_BREAKER_TIMEOUT` | `"30"` | Circuit breaker timeout in seconds |
| `MULTI_TENANT_REDIS_PORT` | `"6379"` | Redis port for tenant events |
| `MULTI_TENANT_REDIS_TLS` | `"false"` | Enable TLS for Redis connections |

These values are automatically configured via the `lerian-common.multiTenant.env` helper when `MULTI_TENANT_ENABLED` is set to `"true"`.

### 3. Ledger service enhancements

#### Application name configuration

A new `APPLICATION_NAME` variable has been added to support multi-tenant service registration.

```yaml
ledger:
  configmap:
    # Service name the ledger registers with the tenant manager; REQUIRED when
    # MULTI_TENANT_ENABLED=true (the app refuses to boot without it) and part of the
    # tenants/{ENV_NAME}/{tenant}/{APPLICATION_NAME}/m2m/tracer secret path
    APPLICATION_NAME: "ledger"
```

> **Important:** When `MULTI_TENANT_ENABLED=true`, the `APPLICATION_NAME` field is **required**. The application will refuse to start without it.

#### OpenAPI documentation control

```yaml
ledger:
  configmap:
    # OpenAPI document/UI (off by default, as the app does)
    OPENAPI_DOCS_ENABLED: "false"
```

#### Transaction database read routing

A new configuration option controls whether transactional reads are routed to the primary database or can use replicas.

```yaml
ledger:
  configmap:
    # Transactional-flow reads go to the primary, not the replica (the app defaults
    # it on, so a just-written row is never read stale from a lagging replica)
    DB_TRANSACTION_ROUTE_TX_READS_TO_PRIMARY: "true"
```

| Flag | Default | Description |
|------|---------|-------------|
| `DB_TRANSACTION_ROUTE_TX_READS_TO_PRIMARY` | `"true"` | When enabled, reads within transactions are routed to the primary database to avoid stale reads from lagging replicas |

#### M2M secrets backend configuration

New configuration options for managing machine-to-machine authentication secrets in multi-tenant environments.

```yaml
ledger:
  configmap:
    # Where the multi-tenant seam identity (each tenant's ledger-m2m-tracer-{tenant}
    # client) is read from: "" (off), "aws" (Secrets Manager at
    # tenants/{ENV_NAME}/{tenant}/{APPLICATION_NAME}/m2m/tracer/credentials) or "vault"
    M2M_SECRETS_BACKEND: ""
    # Vault KV v2 mount holding those credentials when M2M_SECRETS_BACKEND=vault
    M2M_VAULT_MOUNT: ""
    AWS_REGION: ""
```

| Variable | Default | Description |
|----------|---------|-------------|
| `M2M_SECRETS_BACKEND` | `""` | Backend for M2M secrets: `""` (disabled), `"aws"` (AWS Secrets Manager), or `"vault"` (HashiCorp Vault) |
| `M2M_VAULT_MOUNT` | `""` | Vault KV v2 mount path when using `M2M_SECRETS_BACKEND=vault` |
| `AWS_REGION` | `""` | AWS region for Secrets Manager; empty falls through to SDK's region sources |

#### Tracer M2M token wait timeout

The previously optional `TRACER_M2M_WAIT_TIMEOUT_MS` variable now has an explicit default value.

**Before (v9.4.0):**

```yaml
ledger:
  configmap:
    # Emitted only when set; the ledger defaults it
    TRACER_M2M_WAIT_TIMEOUT_MS: ""
```

**After (v9.5.0):**

```yaml
ledger:
  configmap:
    # How long a reservation seam call may wait for an M2M token that is not cached yet,
    # before the TRACER_TIMEOUT_MS budget of the call itself starts.
    # 3000 is the ledger's own default (tracerclient.DefaultTokenWaitTimeout)
    TRACER_M2M_WAIT_TIMEOUT_MS: "3000"
```

#### Balance sync TTL keepalive

```yaml
ledger:
  configmap:
    # How often the cache TTL of every synced balance is refreshed (ms)
    BALANCE_SYNC_TTL_KEEPALIVE_INTERVAL_MS: "300000"
```

### 4. Tracer service enhancements

#### Application identity and deployment configuration

```yaml
tracer:
  configmap:
    # Service name used with the tenant manager (the app falls back to "tracer")
    APPLICATION_NAME: "tracer"
    DEPLOYMENT_MODE: "local"
    # Comma-separated CIDRs whose X-Forwarded-For is trusted ("" trusts none)
    TRUSTED_PROXY_CIDRS: ""
```

#### Authentication enhancements

New authentication configuration options for M2M inversion, caching, circuit breakers, and JWT verification.

```yaml
tracer:
  configmap:
    API_KEY_ENABLED: "false"
    # New: Validation-only mode for API keys
    API_KEY_ENABLED_ONLY_VALIDATION: "false"
    
    # AUTH_M2M_INVERSION_ENABLED and AUTH_CACHE_TTL are read by lib-auth: inversion is
    # off unless "true", and the decision cache is off unless AUTH_CACHE_TTL is a
    # positive Go duration (e.g. "60s"). Defaults keep both off, as the library does.
    AUTH_M2M_INVERSION_ENABLED: "false"
    AUTH_CACHE_TTL: ""
    
    # lib-auth circuit breaker: on only when "true" (the .env.example recommends it)
    AUTH_BREAKER_ENABLED: "false"
    
    # PEM used to verify the Access Manager JWT signature ("" uses the JWKS)
    AUTH_JWT_VERIFY_CERT: ""
```

| Variable | Default | Description |
|----------|---------|-------------|
| `API_KEY_ENABLED_ONLY_VALIDATION` | `"false"` | When enabled, API key is validated but not used for authorization decisions |
| `AUTH_M2M_INVERSION_ENABLED` | `"false"` | Enable M2M authentication inversion pattern |
| `AUTH_CACHE_TTL` | `""` | Decision cache TTL as Go duration (e.g., `"60s"`); empty disables caching |
| `AUTH_BREAKER_ENABLED` | `"false"` | Enable circuit breaker for authentication calls |
| `AUTH_JWT_VERIFY_CERT` | `""` | PEM certificate for JWT signature verification; empty uses JWKS |

#### API key label for audit

A new secret field has been added to record the audit actor ID for API-key-authenticated requests.

```yaml
tracer:
  secrets:
    API_KEY: ""
    # New: Audit actor ID recorded for API-key-authenticated requests
    # ("" when unset, as the app does)
    API_KEY_LABEL: ""
```

> **Note:** The `API_KEY_LABEL` lives beside `API_KEY` in secrets. The chart treats `API_KEY_*` names as credentials.

#### gRPC TLS configuration

Comprehensive TLS configuration for the reservation gRPC seam, supporting plain, server-only, and mutual TLS modes.

```yaml
tracer:
  configmap:
    # TRACER_TLS_MODE: "" (plain gRPC), "server" or "mtls"
    TRACER_TLS_MODE: ""
    # Server certificate/key (required for "server" and "mtls")
    TRACER_TLS_CERT_FILE: ""
    TRACER_TLS_KEY_FILE: ""
    # Client CA and accepted client identities (required for "mtls")
    TRACER_TLS_CLIENT_CA_FILE: ""
    TRACER_TLS_CLIENT_ALLOWED_NAMES: ""
    # Access Manager client names allowed to reserve over the seam
    # ("" = in multi-tenant only ledger-m2m-tracer-{tenant} matching the token's tenant)
    TRACER_SEAM_ALLOWED_CLIENTS: ""
```

| Variable | Default | Description |
|----------|---------|-------------|
| `TRACER_TLS_MODE` | `""` | TLS mode: `""` (plain gRPC), `"server"` (server TLS), or `"mtls"` (mutual TLS) |
| `TRACER_TLS_CERT_FILE` | `""` | Path to server certificate (required for `"server"` and `"mtls"`) |
| `TRACER_TLS_KEY_FILE` | `""` | Path to server private key (required for `"server"` and `"mtls"`) |
| `TRACER_TLS_CLIENT_CA_FILE` | `""` | Path to client CA certificate (required for `"mtls"`) |
| `TRACER_TLS_CLIENT_ALLOWED_NAMES` | `""` | Comma-separated list of allowed client certificate names (required for `"mtls"`) |
| `TRACER_SEAM_ALLOWED_CLIENTS` | `""` | Access Manager client names allowed to reserve; empty uses tenant-based default |

#### Background workers and operational tuning

New configuration options for reservation reaper, rule synchronization, readiness checks, and tenant capacity management.

```yaml
tracer:
  configmap:
    # RESERVATIONS — background reaper that returns capacity held past a
    # reservation's expiry (the app defaults it on), and the long-lived TTL
    RESERVATION_REAPER_ENABLED: "true"
    RESERVATION_REAPER_INTERVAL_SECONDS: "30"
    RESERVATION_LONG_LIVED_TTL_HOURS: "720"
    
    # RULE SYNC — worker polling for rule changes, cache staleness and delta overlap
    RULE_SYNC_POLL_INTERVAL_SECONDS: "10"
    RULE_SYNC_STALENESS_THRESHOLD_SECONDS: "50"
    RULE_SYNC_OVERLAP_BUFFER_SECONDS: "2"
    
    # READINESS — drain grace on shutdown and the rule-cache staleness /readyz tolerates
    READYZ_DRAIN_GRACE_SECONDS: "12"
    READYZ_CACHE_STALENESS_THRESHOLD_SECONDS: "300"
    
    # Retry-After (seconds) returned when a tenant hits its connection-pool cap
    TENANT_CAP_RETRY_AFTER_SECONDS: "5"
```

| Variable | Default | Description |
|----------|---------|-------------|
| `RESERVATION_REAPER_ENABLED` | `"true"` | Enable background worker that returns capacity from expired reservations |
| `RESERVATION_REAPER_INTERVAL_SECONDS` | `"30"` | How often the reaper runs |
| `RESERVATION_LONG_LIVED_TTL_HOURS` | `"720"` | TTL for long-lived reservations (30 days) |
| `RULE_SYNC_POLL_INTERVAL_SECONDS` | `"10"` | How often to poll for rule changes |
| `RULE_SYNC_STALENESS_THRESHOLD_SECONDS` | `"50"` | Maximum acceptable rule cache staleness |
| `RULE_SYNC_OVERLAP_BUFFER_SECONDS` | `"2"` | Buffer for rule delta overlap detection |
| `READYZ_DRAIN_GRACE_SECONDS` | `"12"` | Grace period for draining connections on shutdown |
| `READYZ_CACHE_STALENESS_THRESHOLD_SECONDS` | `"300"` | Maximum rule cache staleness before marking unhealthy |
| `TENANT_CAP_RETRY_AFTER_SECONDS` | `"5"` | Retry-After header value when tenant pool is exhausted |

#### OpenAPI documentation control

```yaml
tracer:
  configmap:
    # OPENAPI DOCS (serves the OpenAPI document/UI; off by default, as the app does)
    OPENAPI_DOCS_ENABLED: "false"
```

#### Observability configuration

```yaml
tracer:
  configmap:
    OTEL_EXPORTER_OTLP_ENDPOINT: ""
    # New: Explicit port configuration
    OTEL_EXPORTER_OTLP_ENDPOINT_PORT: "4317"
```

### 5. CRM service multi-tenant support

The CRM service now includes full multi-tenant configuration with connection pooling, circuit breakers, and Redis support.

**Before (v9.4.0):**

```yaml
crm:
  configmap:
    # MULTI-TENANT (knob only; CRM emits just the gate)
    MULTI_TENANT_ENABLED: "false"
```

**After (v9.5.0):**

```yaml
crm:
  configmap:
    # =============================================================================
    # MULTI-TENANT — knob inline; gated block via lerian-common.multiTenant.env
    # (URL + redis host come from global.multiTenant or configmap.MULTI_TENANT_*).
    # Defaults are the CRM's own (.env.example): timeout 30, pools 100 / idle 300,
    # circuit breaker 5 / 30, redis port 6379 without TLS. The redis host is
    # optional: without it the CRM only skips the tenant-event listener (Pub/Sub).
    # =============================================================================
    MULTI_TENANT_ENABLED: "false"
    MULTI_TENANT_TIMEOUT: "30"
    # Seconds between tenant-connection health checks; 0 keeps the library default
    MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "0"
```

The CRM service now also includes multi-tenant secrets support via the `lerian-common.multiTenant.secret` helper, which validates required credentials when multi-tenant mode is enabled.

> **Important:** When `MULTI_TENANT_ENABLED=true`, the CRM requires multi-tenant credentials to be set in `crm.secrets` or via `crm.useExistingSecret`. The chart will fail-fast if these are missing.

### 6. RabbitMQ TLS support

The ledger service now supports TLS connections to RabbitMQ brokers, required for managed services like Amazon MQ.

```yaml
ledger:
  configmap:
    # TLS to the broker (AmazonMQ requires it). Native key, else the broker mask's tls
    RABBITMQ_TLS: "false"
```

This can also be configured via the datastore mask:

```yaml
ledger:
  datastores:
    broker:
      tls: "false"
```

## Configuration Reference

### Ledger service

#### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APPLICATION_NAME` | `"ledger"` | Service name for tenant manager registration (required when multi-tenant enabled) |
| `OPENAPI_DOCS_ENABLED` | `"false"` | Enable OpenAPI document and UI |
| `DB_TRANSACTION_ROUTE_TX_READS_TO_PRIMARY` | `"true"` | Route transactional reads to primary database |
| `M2M_SECRETS_BACKEND` | `""` | M2M secrets backend: `""`, `"aws"`, or `"vault"` |
| `M2M_VAULT_MOUNT` | `""` | Vault KV v2 mount for M2M secrets |
| `AWS_REGION` | `""` | AWS region for Secrets Manager |
| `TRACER_M2M_WAIT_TIMEOUT_MS` | `"3000"` | M2M token wait timeout in milliseconds |
| `RABBITMQ_TLS` | `"false"` | Enable TLS for RabbitMQ connections |
| `BALANCE_SYNC_TTL_KEEPALIVE_INTERVAL_MS` | `"300000"` | Balance cache TTL refresh interval (5 minutes) |
| `MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC` | `"0"` | Tenant connection health check interval |

### Tracer service

#### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APPLICATION_NAME` | `"tracer"` | Service name for tenant manager |
| `DEPLOYMENT_MODE` | `"local"` | Deployment mode |
| `TRUSTED_PROXY_CIDRS` | `""` | Trusted proxy CIDRs for X-Forwarded-For |
| `API_KEY_ENABLED_ONLY_VALIDATION` | `"false"` | API key validation-only mode |
| `AUTH_M2M_INVERSION_ENABLED` | `"false"` | Enable M2M authentication inversion |
| `AUTH_CACHE_TTL` | `""` | Authentication decision cache TTL |
| `AUTH_BREAKER_ENABLED` | `"false"` | Enable authentication circuit breaker |
| `AUTH_JWT_VERIFY_CERT` | `""` | JWT verification certificate PEM |
| `TRACER_TLS_MODE` | `""` | gRPC TLS mode: `""`, `"server"`, or `"mtls"` |
| `TRACER_TLS_CERT_FILE` | `""` | Server certificate path |
| `TRACER_TLS_KEY_FILE` | `""` | Server private key path |
| `TRACER_TLS_CLIENT_CA_FILE` | `""` | Client CA certificate path |
| `TRACER_TLS_CLIENT_ALLOWED_NAMES` | `""` | Allowed client certificate names |
| `TRACER_SEAM_ALLOWED_CLIENTS` | `""` | Allowed Access Manager client names |
| `RESERVATION_REAPER_ENABLED` | `"true"` | Enable reservation reaper worker |
| `RESERVATION_REAPER_INTERVAL_SECONDS` | `"30"` | Reaper run interval |
| `RESERVATION_LONG_LIVED_TTL_HOURS` | `"720"` | Long-lived reservation TTL |
| `RULE_SYNC_POLL_INTERVAL_SECONDS` | `"10"` | Rule sync poll interval |
| `RULE_SYNC_STALENESS_THRESHOLD_SECONDS` | `"50"` | Rule cache staleness threshold |
| `RULE_SYNC_OVERLAP_BUFFER_SECONDS` | `"2"` | Rule delta overlap buffer |
| `READYZ_DRAIN_GRACE_SECONDS` | `"12"` | Shutdown drain grace period |
| `READYZ_CACHE_STALENESS_THRESHOLD_SECONDS` | `"300"` | Readiness cache staleness threshold |
| `TENANT_CAP_RETRY_AFTER_SECONDS` | `"5"` | Retry-After for tenant pool exhaustion |
| `OPENAPI_DOCS_ENABLED` | `"false"` | Enable OpenAPI document and UI |
| `OTEL_EXPORTER_OTLP_ENDPOINT_PORT` | `"4317"` | OTLP exporter port |

#### New secret fields

| Variable | Description |
|----------|-------------|
| `API_KEY_LABEL` | Audit actor ID for API-key-authenticated requests |

### CRM service

#### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MULTI_TENANT_TIMEOUT` | `"30"` | Multi-tenant operation timeout |
| `MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC` | `"0"` | Tenant connection health check interval |

The CRM service now also supports the full set of multi-tenant configuration options via the `lerian-common.multiTenant.env` helper, including connection pooling, circuit breakers, and Redis configuration.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.5.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.5.0 -n midaz
```
