<!-- {% raw %} -->
# Helm Upgrade from v3.0.2 to v3.0.3

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Configuration Changes](#configuration-changes)**
  - [1. Redis User Field Removed](#1-redis-user-field-removed)
  - [2. CORS Configuration Removed](#2-cors-configuration-removed)
  - [3. Multi-Tenant Configuration Simplified](#3-multi-tenant-configuration-simplified)
  - [4. RabbitMQ URL Moved to Secret](#4-rabbitmq-url-moved-to-secret)
  - [5. OpenTelemetry Configuration Simplified](#5-opentelemetry-configuration-simplified)
  - [6. JD Configuration Changes](#6-jd-configuration-changes)
  - [7. MongoDB Connection Handling Updated](#7-mongodb-connection-handling-updated)
  - [8. Streaming Library Updated to v4](#8-streaming-library-updated-to-v4)
  - [9. Rate Limiting Configuration Removed](#9-rate-limiting-configuration-removed)
  - [10. PostgreSQL SSL Mode Defaults Updated](#10-postgresql-ssl-mode-defaults-updated)
- **[Template Changes](#template-changes)**
  - [MongoDB Environment Variable Logic](#mongodb-environment-variable-logic)
  - [ConfigMap Rendering Changes](#configmap-rendering-changes)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review CORS Configuration](#step-1-review-cors-configuration)
  - [Step 2: Migrate RabbitMQ URL to Secret](#step-2-migrate-rabbitmq-url-to-secret)
  - [Step 3: Review Multi-Tenant Configuration](#step-3-review-multi-tenant-configuration)
  - [Step 4: Review JD Configuration](#step-4-review-jd-configuration)
  - [Step 5: Review OpenTelemetry Configuration](#step-5-review-opentelemetry-configuration)
  - [Step 6: Remove Deprecated Fields](#step-6-remove-deprecated-fields)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.0.3 updates the application from v3.3.0 to v3.4.0 and introduces several configuration changes focused on security improvements, simplified configuration patterns, and alignment with the lib-streaming v4 library. This release removes several deprecated or systemplane-managed configuration fields, moves credentials from ConfigMap to Secret, and updates default behaviors for bundled infrastructure components.

Most changes are non-breaking and require no operator action. However, operators using CORS configuration, RabbitMQ, or multi-tenant mode should review the relevant sections below.

## Application Version Update

The chart updates the application image from v3.3.0 to v3.4.0:

| Component | v3.0.2 | v3.0.3 |
|-----------|--------|--------|
| Chart version | `3.0.2` | `3.0.3` |
| App version (`appVersion`) | `3.3.0` | `3.4.0` |
| Default image tag | `3.3.0` | `3.4.0` |

## Configuration Changes

### 1. Redis User Field Removed

**What changed:**  
The `REDIS_USER` environment variable and its corresponding configuration paths have been removed from the chart. The Redis datastore mask no longer includes a `user` field.

**Before (v3.0.2):**
```yaml
global:
  datastores:
    redis:
      host: "my-elasticache.example.com:6379"
      user: "default"  # Only needed for ACL-authenticated Redis/Valkey
      tls: "true"
```

**After (v3.0.3):**
```yaml
global:
  datastores:
    redis:
      host: "my-elasticache.example.com:6379"
      tls: "true"
```

**Why it matters:**  
The application no longer supports Redis ACL username authentication via `REDIS_USER`. Authentication now relies solely on password-based authentication via `REDIS_PASSWORD` (set in `bankTransfer.secrets`).

**Migration required:**  
If you currently set `global.datastores.redis.user`, remove it from your values. If your Redis/Valkey deployment requires ACL authentication with a username, you must reconfigure it to use password-only authentication or update your infrastructure to support the application's authentication model.

### 2. CORS Configuration Removed

**What changed:**  
The CORS configuration fields (`CORS_ALLOWED_ORIGINS`, `CORS_ALLOWED_METHODS`, `CORS_ALLOWED_HEADERS`) have been removed from `bankTransfer.configmap` and are no longer rendered in the ConfigMap template.

**Before (v3.0.2):**
```yaml
bankTransfer:
  configmap:
    CORS_ALLOWED_ORIGINS: "https://bank-transfer.sa-east-1.lerian.io"
    CORS_ALLOWED_METHODS: "GET,POST,PUT,DELETE"
    CORS_ALLOWED_HEADERS: "Content-Type,Authorization"
```

**After (v3.0.3):**
```yaml
# CORS configuration is now systemplane-managed via runtime keys:
# - cors.allowed_origins (default "*")
# - cors.allowed_methods
# - cors.allowed_headers
# These keys are not set via Helm values.
```

**Why it matters:**  
CORS policy is now managed at runtime via systemplane configuration keys (`cors.allowed_origins`, `cors.allowed_methods`, `cors.allowed_headers`) rather than environment variables. The application defaults `cors.allowed_origins` to `"*"` when unset.

**Migration required:**  
Yes — see [Step 1: Review CORS Configuration](#step-1-review-cors-configuration).

### 3. Multi-Tenant Configuration Simplified

**What changed:**  
Two multi-tenant configuration fields have been removed: `MULTI_TENANT_ENVIRONMENT` and `MULTI_TENANT_ALLOW_INSECURE_HTTP`. Both now follow the global `ENVIRONMENT_NAME` setting.

**Before (v3.0.2):**
```yaml
bankTransfer:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_URL: "https://tenant-manager.example.com"
    MULTI_TENANT_ENVIRONMENT: "production"  # Required when MULTI_TENANT_ENABLED=true
    MULTI_TENANT_ALLOW_INSECURE_HTTP: "false"
```

**After (v3.0.3):**
```yaml
bankTransfer:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_URL: "https://tenant-manager.example.com"
    # MULTI_TENANT_ENVIRONMENT and MULTI_TENANT_ALLOW_INSECURE_HTTP removed:
    # both now follow ENVIRONMENT_NAME (global.env.name)
```

**Why it matters:**  
The tenant environment and whether plaintext `http://` URLs are allowed to the Tenant Manager now automatically follow `ENVIRONMENT_NAME` (set via `global.env.name`). Plaintext URLs are only permitted when `ENVIRONMENT_NAME` is `"development"` or `"test"`.

**Additional change:**  
A new secret field `MULTI_TENANT_SERVICE_API_KEY` is now **required** when `MULTI_TENANT_ENABLED=true`:

```yaml
bankTransfer:
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "<api-key-for-tenant-manager>"
```

**Migration required:**  
Yes — see [Step 3: Review Multi-Tenant Configuration](#step-3-review-multi-tenant-configuration).

### 4. RabbitMQ URL Moved to Secret

**What changed:**  
The `RABBITMQ_URL` configuration field has been moved from `bankTransfer.configmap` to `bankTransfer.secrets`. The ConfigMap template no longer assembles a default URL with embedded `$(RABBITMQ_PASSWORD)` expansion.

**Before (v3.0.2):**
```yaml
bankTransfer:
  configmap:
    RABBITMQ_ENABLED: "true"
    RABBITMQ_URL: "amqps://bank_transfer:my-password@rabbitmq.example.com:5671/"
    RABBITMQ_EXCHANGE: "bank_transfer.lifecycle"
```

**After (v3.0.3):**
```yaml
bankTransfer:
  configmap:
    RABBITMQ_ENABLED: "true"
    RABBITMQ_EXCHANGE: "bank_transfer.lifecycle"

bankTransfer:
  secrets:
    RABBITMQ_URL: "amqps://bank_transfer:my-password@rabbitmq.example.com:5671/"
```

**Why it matters:**  
`RABBITMQ_URL` contains credentials and should not be stored in a ConfigMap. The application now reads it exclusively from the Secret.

**Migration required:**  
Yes — see [Step 2: Migrate RabbitMQ URL to Secret](#step-2-migrate-rabbitmq-url-to-secret).

### 5. OpenTelemetry Configuration Simplified

**What changed:**  
Several OpenTelemetry environment variables have been removed. The application now derives service name, version, and environment internally.

**Removed fields:**

| Field | v3.0.2 Default | Reason for Removal |
|-------|----------------|-------------------|
| `OTEL_LIBRARY_NAME` | `"github.com/LerianStudio/plugin-br-bank-transfer"` | Derived by application |
| `OTEL_RESOURCE_SERVICE_NAME` | `"plugin-br-bank-transfer"` | Derived by application |
| `OTEL_RESOURCE_SERVICE_VERSION` | `<image-tag>` | Derived by application |
| `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `"production"` | Derived by application |
| `OTEL_SDK_DISABLED` | `"false"` | No longer used |

**Retained fields:**

| Field | Description | Default |
|-------|-------------|---------|
| `ENABLE_TELEMETRY` | Toggle for telemetry (via `global.observability.enabled`) | `"false"` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector endpoint (via `global.observability.otlpEndpoint`) | `""` (empty = node-local collector at `$(HOST_IP):4317`) |

**Why it matters:**  
The application now manages its own OpenTelemetry resource attributes. Operators only need to configure the toggle and the collector endpoint.

**Migration required:**  
No — the changes are transparent. If you previously overrode these fields, remove them from your values. See [Step 5: Review OpenTelemetry Configuration](#step-5-review-opentelemetry-configuration).

### 6. JD Configuration Changes

**What changed:**  
Three JD-related configuration changes:

1. `JD_ORIGIN_ISPB` removed from environment variables (now a systemplane key: `tenancy.ispb_organization_bindings`)
2. `JD_LEGACY_CODE` is now **required** in single-tenant mode when `JD_SANDBOX_MODE` is not `true`
3. `MIDAZ_AUTH_ADDRESS` is now optional and defaults to `PLUGIN_AUTH_ADDRESS` (from `global.auth.host`) when unset

**Before (v3.0.2):**
```yaml
bankTransfer:
  configmap:
    JD_BASE_URL: "https://jd.example.com/soap"
    JD_ORIGIN_ISPB: "12345678"  # Required
    JD_LEGACY_CODE: ""  # Optional
```

**After (v3.0.3):**
```yaml
bankTransfer:
  configmap:
    JD_BASE_URL: "https://jd.example.com/soap"
    JD_LEGACY_CODE: "12345"  # REQUIRED in single-tenant mode when JD_SANDBOX_MODE != true
    # JD_ORIGIN_ISPB removed: seed systemplane key tenancy.ispb_organization_bindings instead
```

**Why it matters:**  
- `JD_ORIGIN_ISPB` is now managed at runtime via systemplane, not as an environment variable
- `JD_LEGACY_CODE` is now enforced as required for production single-tenant deployments
- `MIDAZ_AUTH_ADDRESS` no longer needs explicit configuration if you use the standard `global.auth.host` pattern

**Migration required:**  
Yes — see [Step 4: Review JD Configuration](#step-4-review-jd-configuration).

### 7. MongoDB Connection Handling Updated

**What changed:**  
The MongoDB connection logic in the `bank-transfer.mongoEnv` template helper has been refactored. The chart now supports three scenarios more explicitly:

1. **Bundled MongoDB (default):** `MONGO_PASSWORD` is read from the subchart Secret, and `MONGO_URI` is assembled via `$(MONGO_PASSWORD)` expansion
2. **External MongoDB with `$(MONGO_PASSWORD)` reference:** Operators set `bankTransfer.secrets.MONGO_URI` with a `$(MONGO_PASSWORD)` placeholder; the chart emits both `MONGO_PASSWORD` (from `bankTransfer.secrets` or `mongodb.auth.existingSecret`) and the URI
3. **External MongoDB with inline credentials:** Operators set `bankTransfer.secrets.MONGO_URI` with the full connection string (including password); the chart emits only the URI

**Before (v3.0.2):**
```yaml
# The chart always emitted MONGO_PASSWORD followed by MONGO_URI.
# If bankTransfer.secrets.MONGO_URI was set, it was used verbatim.
# Otherwise, the chart assembled a URI for bundled MongoDB.
```

**After (v3.0.3):**
```yaml
# The chart detects whether bankTransfer.secrets.MONGO_URI contains "$(" (a variable reference).
# If it does, MONGO_PASSWORD is emitted first (from the appropriate Secret).
# If it doesn't (inline credential), only MONGO_URI is emitted.
# For bundled MongoDB with no explicit URI, the chart assembles the URI as before.
```

**New secret field:**

```yaml
bankTransfer:
  secrets:
    MONGO_URI: ""  # REQUIRED for external MongoDB in single-tenant mode
                   # Can be a full connection string (inline credential) or use $(MONGO_PASSWORD)
```

**Why it matters:**  
This change improves security by allowing operators to avoid storing MongoDB passwords in `bankTransfer.secrets.MONGO_PASSWORD` when using an inline-credential URI. It also clarifies the three supported patterns.

**Migration required:**  
No — existing configurations continue to work. If you use external MongoDB, consider setting `bankTransfer.secrets.MONGO_URI` explicitly to avoid relying on the chart's assembly logic.

### 8. Streaming Library Updated to v4

**What changed:**  
The chart now references lib-streaming v4 (previously v3). The comments and documentation have been updated, but the configuration fields remain the same.

**Configuration fields (unchanged):**

| Field | Description | Default |
|-------|-------------|---------|
| `STREAMING_ENABLED` | Toggle for streaming (via `global.streaming.enabled`) | `"false"` |
| `STREAMING_BROKERS` | Kafka/RedPanda broker list (via `global.streaming.brokers`) | `""` |
| `STREAMING_TLS_ENABLED` | Enable TLS for streaming (via `global.streaming.tlsEnabled`) | `"false"` |
| `STREAMING_SASL_MECHANISM` | SASL mechanism (via `global.streaming.saslMechanism`) | `""` |
| `STREAMING_SASL_USERNAME` | SASL username (via `global.streaming.saslUsername`) | `""` |
| `STREAMING_SASL_ALLOW_PLAINTEXT` | Allow plaintext SASL (via `global.streaming.saslAllowPlaintext`) | `"false"` |

**Why it matters:**  
The v4 library introduces internal changes but does not affect the Helm configuration surface. The chart comments now note that `compression`, `requiredAcks`, `batchLingerMs`, and `importantEmitTimeoutMs` are ignored by this application (fixed in code).

**Migration required:**  
No — the configuration interface is unchanged.

### 9. Rate Limiting Configuration Removed

**What changed:**  
The `RATE_LIMIT_ENABLED` field has been removed from `bankTransfer.configmap`.

**Before (v3.0.2):**
```yaml
bankTransfer:
  configmap:
    RATE_LIMIT_ENABLED: "false"
```

**After (v3.0.3):**
```yaml
# RATE_LIMIT_ENABLED removed: rate limiting is now systemplane-managed via
# runtime keys (rate_limit.*), off by default.
```

**Why it matters:**  
Rate limiting is now configured at runtime via systemplane keys (`rate_limit.*`) rather than environment variables.

**Migration required:**  
No — if you previously set this field, remove it from your values. Rate limiting configuration is now handled outside Helm.

### 10. PostgreSQL SSL Mode Defaults Updated

**What changed:**  
The default `POSTGRES_SSLMODE` and `POSTGRES_REPLICA_SSLMODE` values now depend on whether the bundled PostgreSQL subchart is enabled:

| Scenario | v3.0.2 Default | v3.0.3 Default |
|----------|----------------|----------------|
| Bundled PostgreSQL (`postgresql.enabled=true`) | `"require"` | `"disable"` |
| External PostgreSQL | `"require"` | `"require"` |

**Why it matters:**  
The bundled Bitnami PostgreSQL subchart does not serve TLS by default. Setting `POSTGRES_SSLMODE=require` against a non-TLS PostgreSQL causes connection failures. The chart now defaults to `"disable"` for bundled PostgreSQL and `"require"` for external PostgreSQL.

**Migration required:**  
No — the change is automatic. If you previously overrode `POSTGRES_SSLMODE` to `"disable"` for bundled PostgreSQL, you can remove that override.

## Template Changes

### MongoDB Environment Variable Logic

The `bank-transfer.mongoEnv` template helper has been refactored to support three MongoDB connection patterns more explicitly.

**Before (v3.0.2):**
```yaml
{{- define "bank-transfer.mongoEnv" -}}
{{- /* Always emit MONGO_PASSWORD (secretKeyRef) followed by MONGO_URI.
     If bankTransfer.secrets.MONGO_URI is set, use it verbatim.
     Otherwise, assemble a URI for bundled MongoDB. */}}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: <subchart-or-app-secret>
      key: mongodb-passwords
- name: MONGO_URI
  value: <explicit-or-assembled-uri>
{{- end }}
```

**After (v3.0.3):**
```yaml
{{- define "bank-transfer.mongoEnv" -}}
{{- /* Detect whether bankTransfer.secrets.MONGO_URI contains "$(" (variable reference).
     If yes: emit MONGO_PASSWORD (secretKeyRef) followed by MONGO_URI with $(MONGO_PASSWORD).
     If no (inline credential): emit only MONGO_URI.
     If unset and bundled: emit MONGO_PASSWORD and assemble MONGO_URI. */}}
{{- if or (and $internal (not $uri)) (and $ref (or $internal $mongoAuth.existingSecret)) }}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: <subchart-or-existingSecret>
      key: mongodb-passwords
{{- end }}
{{- if $ref }}
- name: MONGO_URI
  value: <uri-with-$(MONGO_PASSWORD)>
{{- else if and $internal (not $uri) }}
- name: MONGO_URI
  value: <assembled-uri-with-$(MONGO_PASSWORD)>
{{- end }}
{{- end }}
```

**Operational impact:**  
- **Bundled MongoDB:** No change — `MONGO_PASSWORD` and `MONGO_URI` are emitted as before
- **External MongoDB with `$(MONGO_PASSWORD)` in URI:** The chart emits `MONGO_PASSWORD` from `bankTransfer.secrets` or `mongodb.auth.existingSecret`, followed by the URI
- **External MongoDB with inline credential:** Only `MONGO_URI` is emitted; no `MONGO_PASSWORD` env entry

### ConfigMap Rendering Changes

Several ConfigMap fields are no longer rendered:

| Field | v3.0.2 Behavior | v3.0.3 Behavior |
|-------|-----------------|-----------------|
| `APPLICATION_NAME` | Always rendered (default `"plugin-br-bank-transfer"`) | Removed (application derives it internally) |
| `DEPLOYMENT_MODE` | Rendered only in single-tenant mode | Always rendered (both modes) |
| `CORS_ALLOWED_ORIGINS` | Rendered when set | Removed (systemplane-managed) |
| `CORS_ALLOWED_METHODS` | Rendered when set | Removed (systemplane-managed) |
| `CORS_ALLOWED_HEADERS` | Rendered when set | Removed (systemplane-managed) |
| `MULTI_TENANT_ENVIRONMENT` | Required when `MULTI_TENANT_ENABLED=true` | Removed (follows `ENVIRONMENT_NAME`) |
| `MULTI_TENANT_ALLOW_INSECURE_HTTP` | Rendered when `MULTI_TENANT_ENABLED=true` | Removed (follows `ENVIRONMENT_NAME`) |
| `MIGRATIONS_PATH` | Always rendered (default `"migrations"`) | Removed (application uses fixed path) |
| `REDIS_USER` | Rendered when set via datastore mask | Removed (no longer supported) |
| `RABBITMQ_URL` | Rendered with default or explicit value | Removed from ConfigMap (moved to Secret) |
| `OTEL_LIBRARY_NAME` | Rendered in single-tenant mode | Removed (application derives it) |
| `OTEL_RESOURCE_SERVICE_NAME` | Rendered in single-tenant mode | Removed (application derives it) |
| `OTEL_RESOURCE_SERVICE_VERSION` | Rendered in single-tenant mode | Removed (application derives it) |
| `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | Rendered in single-tenant mode | Removed (application derives it) |
| `OTEL_SDK_DISABLED` | Always rendered (default `"false"`) | Removed (no longer used) |
| `JD_ORIGIN_ISPB` | Required in single-tenant mode | Removed (systemplane key `tenancy.ispb_organization_bindings`) |
| `MIDAZ_AUTH_ADDRESS` | Always rendered with default | Rendered only when explicitly set (defaults to `PLUGIN_AUTH_ADDRESS` in app) |
| `RATE_LIMIT_ENABLED` | Always rendered (default `"false"`) | Removed (systemplane-managed) |

**New ConfigMap rendering behavior:**

- `DEPLOYMENT_MODE` is now always rendered (both single-tenant and multi-tenant modes)
- `HTTP_BODY_LIMIT_BYTES`, `TLS_TERMINATED_UPSTREAM`, and related HTTP server tuning fields are now rendered in both modes (previously single-tenant only)
- `RABBITMQ_ENABLED` and `RABBITMQ_EXCHANGE` are now rendered in both modes (previously single-tenant only)
- `JD_LEGACY_CODE` is now **required** (enforced via `required` template function) in single-tenant mode when `JD_SANDBOX_MODE` is not `true`

## Migration Steps

### Step 1: Review CORS Configuration

If you currently set CORS configuration via `bankTransfer.configmap`, remove those fields from your values:

**Remove from your values:**
```yaml
bankTransfer:
  configmap:
    CORS_ALLOWED_ORIGINS: "https://bank-transfer.sa-east-1.lerian.io"
    CORS_ALLOWED_METHODS: "GET,POST,PUT,DELETE"
    CORS_ALLOWED_HEADERS: "Content-Type,Authorization"
```

**Action required:**  
CORS policy is now managed at runtime via systemplane configuration keys. Coordinate with your systemplane administrator to configure:

- `cors.allowed_origins` (default `"*"`)
- `cors.allowed_methods`
- `cors.allowed_headers`

> **Important:** The application defaults `cors.allowed_origins` to `"*"` when unset. In production environments, you **must** configure a restrictive origin allowlist via systemplane to avoid security risks.

### Step 2: Migrate RabbitMQ URL to Secret

If you currently set `bankTransfer.configmap.RABBITMQ_URL`, move it to `bankTransfer.secrets.RABBITMQ_URL`.

**Before (v3.0.2):**
```yaml
bankTransfer:
  configmap:
    RABBITMQ_ENABLED: "true"
    RABBITMQ_URL: "amqps://bank_transfer:my-password@rabbitmq.example.com:5671/"
```

**After (v3.0.3):**
```yaml
bankTransfer:
  configmap:
    RABBITMQ_ENABLED: "true"

bankTransfer:
  secrets:
    RABBITMQ_URL: "amqps://bank_transfer:my-password@rabbitmq.example.com:5671/"
```

> **Important:** Use `amqps://` (TLS) for production deployments. Plaintext `amqp://` URLs are only permitted when `ENVIRONMENT_NAME` is `"development"`, `"test"`, or `"local"`.

### Step 3: Review Multi-Tenant Configuration

If you use multi-tenant mode (`MULTI_TENANT_ENABLED=true`), remove the `MULTI_TENANT_ENVIRONMENT` and `MULTI_TENANT_ALLOW_INSECURE_HTTP` fields and add the required `MULTI_TENANT_SERVICE_API_KEY` secret.

**Before (v3.0.2):**
```yaml
bankTransfer:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_URL: "https://tenant-manager.example.com"
    MULTI_TENANT_ENVIRONMENT: "production"
    MULTI_TENANT_ALLOW_INSECURE_HTTP: "false"
```

**After (v3.0.3):**
```yaml
bankTransfer:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_URL: "https://tenant-manager.example.com"

bankTransfer:
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "<api-key-for-tenant-manager>"
```

**Why this matters:**  
- The tenant environment now follows `ENVIRONMENT_NAME` (set via `global.env.name`)
- Plaintext `http://` URLs to the Tenant Manager are only allowed when `ENVIRONMENT_NAME` is `"development"` or `"test"`
- The `MULTI_TENANT_SERVICE_API_KEY` is now **required** for authentication with the Tenant Manager

> **Important:** Ensure `global.env.name` is set to the correct environment (`"production"`, `"development"`, or `"test"`). The application will reject plaintext `MULTI_TENANT_URL` values in production.

### Step 4: Review JD Configuration

If you use JD integration in single-tenant mode, ensure `JD_LEGACY_CODE` is set and remove `JD_ORIGIN_ISPB` from your values.

**Before (v3.0.2):**
```yaml
bankTransfer:
  configmap:
    JD_SANDBOX_MODE: "false"
    JD_BASE_URL: "https://jd.example.com/soap"
    JD_ORIGIN_ISPB: "12345678"
    JD_LEGACY_CODE: ""  # Optional
```

**After (v3.0.3):**
```yaml
bankTransfer:
  configmap:
    JD_SANDBOX_MODE: "false"
    JD_BASE_URL: "https://jd.example.com/soap"
    JD_LEGACY_CODE: "12345"  # REQUIRED when JD_SANDBOX_MODE != true
```

**Action required:**  
1. Remove `JD_ORIGIN_ISPB` from your values
2. Ensure `JD_LEGACY_CODE` is set (the chart will fail validation if it's missing in production single-tenant mode)
3. Coordinate with your systemplane administrator to seed the `tenancy.ispb_organization_bindings` runtime key

> **Note:** If you use `JD_SANDBOX_MODE=true` (development/testing), `JD_LEGACY_CODE` is optional.

### Step 5: Review OpenTelemetry Configuration

If you previously overrode OpenTelemetry resource attributes, remove those fields from your values.

**Remove from your values:**
```yaml
bankTransfer:
  configmap:
    OTEL_LIBRARY_NAME: "github.com/LerianStudio/plugin-br-bank-transfer"
    OTEL_RESOURCE_SERVICE_NAME: "plugin-br-bank-transfer"
    OTEL_RESOURCE_SERVICE_VERSION: "3.3.0"
    OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "production"
    OTEL_SDK_DISABLED: "false"
```

**Retain only:**
```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: ""  # Empty = node-local collector at $(HOST_IP):4317
```

**Why this matters:**  
The application now derives service name, version, and environment internally. Operators only need to configure the telemetry toggle and the collector endpoint.

### Step 6: Remove Deprecated Fields

Remove the following deprecated fields from your values if present:

```yaml
bankTransfer:
  configmap:
    APPLICATION_NAME: "plugin-br-bank-transfer"  # Remove: derived by application
    MIGRATIONS_PATH: "migrations"  # Remove: fixed in application
    RATE_LIMIT_ENABLED: "false"  # Remove: systemplane-managed
    CORS_ALLOWED_ORIGINS: ""  # Remove: systemplane-managed
    CORS_ALLOWED_METHODS: ""  # Remove: systemplane-managed
    CORS_ALLOWED_HEADERS: ""  # Remove: systemplane-managed
    MULTI_TENANT_ENVIRONMENT: "production"  # Remove: follows ENVIRONMENT_NAME
    MULTI_TENANT_ALLOW_INSECURE_HTTP: "false"  # Remove: follows ENVIRONMENT_NAME
    JD_ORIGIN_ISPB: "12345678"  # Remove: systemplane key tenancy.ispb_organization_bindings

global:
  datastores:
    redis:
      user: "default"  # Remove: no longer supported
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.3 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.3 -n plugin-br-bank-transfer
```
<!-- {% endraw %} -->
