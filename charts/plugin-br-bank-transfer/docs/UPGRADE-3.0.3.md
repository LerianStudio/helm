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
  - [Step 7: Set MONGO_URI for an External MongoDB](#step-7-set-mongo_uri-for-an-external-mongodb)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.0.3 updates the application from v3.3.0 to v3.4.0. The chart stops rendering settings that the application ignores or that systemplane owns (CORS, rate limiting, several OpenTelemetry and multi-tenant keys, `REDIS_USER`, `JD_ORIGIN_ISPB`), moves `RABBITMQ_URL` to the Secret, and changes the default `POSTGRES_SSLMODE` for the bundled PostgreSQL. It also adds `required` checks, so `helm upgrade` fails at render time when a value the application needs at boot is missing.

Check these cases before upgrading, because the render now fails without the listed values:

- Single-tenant with `JD_SANDBOX_MODE` not `true`: `bankTransfer.configmap.JD_LEGACY_CODE` and the secrets `JD_USER_CODE`, `JD_PASSWORD`, `JD_PRIVATE_KEY_KEYINFO`, plus `JD_PRIVATE_KEY_PEM` in `local_pem` signing mode (the default). See [6. JD Configuration Changes](#6-jd-configuration-changes).
- Single-tenant with an external MongoDB: `bankTransfer.secrets.MONGO_URI`. See [7. MongoDB Connection Handling Updated](#7-mongodb-connection-handling-updated).
- `RABBITMQ_ENABLED=true`: a `RABBITMQ_URL`. The chart no longer builds a default URL. See [4. RabbitMQ URL Moved to Secret](#4-rabbitmq-url-moved-to-secret).
- `MULTI_TENANT_ENABLED=true`: `bankTransfer.secrets.MULTI_TENANT_SERVICE_API_KEY`. See [3. Multi-Tenant Configuration Simplified](#3-multi-tenant-configuration-simplified).

The CORS, rate limiting, OpenTelemetry resource attribute and `REDIS_USER` removals need no action. A leftover key for any of them in your values is not rendered and does not fail validation.

The in-cluster `http://` defaults for `MIDAZ_BASE_URL`, `MIDAZ_TRANSACTION_URL`, `CRM_BASE_URL` and `FEES_BASE_URL` boot only outside `ENVIRONMENT_NAME=production` (the default). In production the application refuses non-`https://` values for those URLs, for `JD_BASE_URL`, `COURIER_BASE_URL` and `MULTI_TENANT_URL`, and for `PLUGIN_AUTH_ADDRESS` when auth is enabled. This check is identical in app v3.3.0 and v3.4.0; the chart's values comments now document it.

## Application Version Update

The chart updates the application image from v3.3.0 to v3.4.0:

| Component | v3.0.2 | v3.0.3 |
|-----------|--------|--------|
| Chart version | `3.0.2` | `3.0.3` |
| App version (`appVersion`) | `3.3.0` | `3.4.0` |
| Default image tag (`bankTransfer.image.tag`) | `3.3.0` | `3.4.0` |

**Rollout:** the application pod template carries the `helm.sh/chart` and `app.kubernetes.io/version` labels and the new image tag, so `helm upgrade` rolls every application pod (strategy `RollingUpdate` by default). A chart version bump alone would also roll the pods, because the `helm.sh/chart` label changes. The Deployment has no ConfigMap or Secret checksum annotation, so this pod roll is what applies the new ConfigMap and Secret values.

**Database migration:** app v3.4.0 adds migration `000070_fee_context`, which adds a nullable `fee_context` column to `payment_initiations` and `transfers`. The migrations image tag defaults to the application tag, so it also moves to `3.4.0` unless you set `bankTransfer.migrations.image.tag`. With bundled PostgreSQL the migrations run as an initContainer of each application pod. With external PostgreSQL they run as a Helm `pre-install,pre-upgrade` hook Job (ArgoCD PreSync).

## Configuration Changes

### 1. Redis User Field Removed

**What changed:**  
The chart no longer renders the `REDIS_USER` environment variable. The Redis datastore mask (`global.datastores.redis`) no longer documents or reads a `user` field.

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
No Go code in app v3.3.0 or v3.4.0 reads `REDIS_USER` (it appears only in the application's `.env.example`). The application's Redis settings are host, master name, password, DB, protocol, TLS, CA certificate and pool settings. The password comes from `REDIS_PASSWORD`: with the bundled Valkey it is read from the subchart Secret; for an external Valkey set `bankTransfer.secrets.REDIS_PASSWORD` or `valkey.auth.existingSecret`.

**Migration required:**  
No. If you set `global.datastores.redis.user`, remove it. A leftover value is not rendered and does not fail validation.

### 2. CORS Configuration Removed

**What changed:**  
The CORS configuration fields (`CORS_ALLOWED_ORIGINS`, `CORS_ALLOWED_METHODS`, `CORS_ALLOWED_HEADERS`) have been removed from the default `bankTransfer.configmap` values and are no longer rendered in the ConfigMap template.

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
App v3.3.0 and v3.4.0 list these three variables as legacy environment twins of systemplane keys: the application ignores them and logs them as deprecated at startup. Values set through Helm in v3.0.2 were therefore not applied by app v3.3.0 either, and this upgrade does not change the effective CORS policy. When `cors.allowed_origins` is not set in systemplane, the application uses `"*"`.

**Migration required:**  
No chart change is required. See [Step 1: Review CORS Configuration](#step-1-review-cors-configuration) if you want a restricted origin list.

### 3. Multi-Tenant Configuration Simplified

**What changed:**  
Two multi-tenant fields are no longer rendered: `MULTI_TENANT_ENVIRONMENT` and `MULTI_TENANT_ALLOW_INSECURE_HTTP`. The tenant environment and the plaintext allowance now follow `ENVIRONMENT_NAME`. In v3.0.2 the render failed when `MULTI_TENANT_ENVIRONMENT` was missing.

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
In app v3.3.0 and v3.4.0 the Tenant Manager client takes its environment from `ENVIRONMENT_NAME` and allows plaintext `http://` only when it is `"development"` or `"test"`. The application code does not read the two removed variables. `ENVIRONMENT_NAME` comes from `bankTransfer.configmap.ENVIRONMENT_NAME` or `global.env.name` and defaults to `"production"`.

**Additional change:**  
`bankTransfer.secrets.MULTI_TENANT_SERVICE_API_KEY` is now **required** when `MULTI_TENANT_ENABLED=true`. In v3.0.2 the chart wrote it only when set. The render now fails with `Secret value required but empty: MULTI_TENANT_SERVICE_API_KEY` when it is missing. The check does not apply when `bankTransfer.extraEnvVars` carries the key, and none of the Secret checks apply when `bankTransfer.useExistingSecret=true` (the chart then does not render the Secret).

```yaml
bankTransfer:
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "<api-key-for-tenant-manager>"
```

**Migration required:**  
Yes, for multi-tenant installs. See [Step 3: Review Multi-Tenant Configuration](#step-3-review-multi-tenant-configuration).

### 4. RabbitMQ URL Moved to Secret

**What changed:**  
`RABBITMQ_URL` now belongs in `bankTransfer.secrets`. The chart no longer assembles a default URL (`amqp://bank_transfer:...@<release>-rabbitmq.<namespace>.svc.cluster.local:5672/`) in the ConfigMap, and `bankTransfer.secrets.RABBITMQ_PASSWORD` is no longer written to the Secret. With `RABBITMQ_ENABLED=true` the render fails with `bankTransfer.secrets.RABBITMQ_URL is required` unless a URL comes from `bankTransfer.secrets`, from `bankTransfer.configmap.RABBITMQ_URL` (legacy, still rendered into the ConfigMap), or from `bankTransfer.extraEnvVars`. `RABBITMQ_ENABLED` and `RABBITMQ_EXCHANGE` are now rendered in both single-tenant and multi-tenant modes.

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
  secrets:
    RABBITMQ_URL: "amqps://bank_transfer:my-password@rabbitmq.example.com:5671/"
```

**Why it matters:**  
`RABBITMQ_URL` contains credentials and should not be stored in a ConfigMap. The Secret is loaded into the pod through `envFrom`. The chart writes `RABBITMQ_URL` to the Secret only when no URL is set in `bankTransfer.configmap` or `bankTransfer.extraEnvVars`. If you set the URL in both `bankTransfer.configmap` and `bankTransfer.secrets`, the ConfigMap value is the one the pod uses and the Secret value is ignored. Remove the ConfigMap entry when you move the URL.

**Bundled RabbitMQ definitions:**  
`files/rabbitmq/load_definitions.json` no longer declares the `bank_transfer.lifecycle` and `bank_transfer.lifecycle.dlx` exchanges, the `transfer.webhook.delivery` and `transfer.webhook.dlq` queues, or their bindings. It now defines only the `bank_transfer` user, the `/` vhost and the user's permissions. App v3.4.0 declares the `bank_transfer.lifecycle` exchange itself (the event publisher and the webhook delivery worker call `ExchangeDeclare`) and declares the webhook delivery queue. I did not verify that the application declares the `.dlx` exchange and the `transfer.webhook.dlq` queue, so check a fresh broker if you use webhook delivery with dead-lettering. The file is used by the bundled RabbitMQ subchart (`rabbitmq.enabled=true`) and by the bootstrap Job when `global.externalRabbitmqDefinitions.enabled=true`. Existing brokers keep the objects they already have.

**Migration required:**  
Yes if `RABBITMQ_ENABLED=true`. See [Step 2: Migrate RabbitMQ URL to Secret](#step-2-migrate-rabbitmq-url-to-secret).

### 5. OpenTelemetry Configuration Simplified

**What changed:**  
Several OpenTelemetry environment variables are no longer rendered. The application derives service name, version and environment itself.

**Removed fields:**

| Field | v3.0.2 Default | Reason for Removal |
|-------|----------------|-------------------|
| `OTEL_LIBRARY_NAME` | `"github.com/LerianStudio/plugin-br-bank-transfer"` | Derived by application |
| `OTEL_RESOURCE_SERVICE_NAME` | `"plugin-br-bank-transfer"` | Derived by application |
| `OTEL_RESOURCE_SERVICE_VERSION` | `<image-tag>` | Derived by application |
| `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `"production"` | Derived by application |
| `OTEL_SDK_DISABLED` | `"false"` | Not read by the application (v3.3.0, v3.4.0) |

**Retained fields:**

| Field | Description | Default |
|-------|-------------|---------|
| `ENABLE_TELEMETRY` | Toggle for telemetry (via `global.observability.enabled`) | `"false"` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector endpoint (via `global.observability.otlpEndpoint`) | `""` (empty with telemetry on = node-local collector at `$(HOST_IP):4317`) |

**Endpoint behavior change:**  
When telemetry is enabled (through `bankTransfer.configmap.ENABLE_TELEMETRY` or `global.observability.enabled`), the Deployment now injects `HOST_IP`, `POD_IP` and `OTEL_RESOURCE_ATTRIBUTES`. It sets `OTEL_EXPORTER_OTLP_ENDPOINT=$(HOST_IP):4317` only when no endpoint resolves from `bankTransfer.configmap.OTEL_EXPORTER_OTLP_ENDPOINT` or `global.observability.otlpEndpoint`. In v3.0.2 the Deployment overwrote any configured endpoint with `$(HOST_IP):4317` whenever `bankTransfer.configmap.ENABLE_TELEMETRY` was `"true"`, and did nothing when telemetry was enabled only through `global.observability.enabled`, which left the endpoint empty. If you relied on the old overwrite, remove your endpoint setting or point it at the collector you want.

**Migration required:**  
No for the removed fields. If you previously overrode them, remove them from your values. See [Step 5: Review OpenTelemetry Configuration](#step-5-review-opentelemetry-configuration).

### 6. JD Configuration Changes

**What changed:**  

1. `JD_ORIGIN_ISPB` is no longer rendered and its empty default key is gone from `values.yaml`. The origin ISPB is the systemplane key `tenancy.ispb_organization_bindings`.
2. `JD_LEGACY_CODE` is now **required** in single-tenant mode when `JD_SANDBOX_MODE` is not `true`. The check is skipped when `bankTransfer.extraEnvVars` carries `JD_LEGACY_CODE`, or when `bankTransfer.useExistingSecret=true` and `bankTransfer.configmap.JD_LEGACY_CODE` is empty.
3. In the same mode the chart now requires `bankTransfer.secrets.JD_USER_CODE`, `JD_PASSWORD` and `JD_PRIVATE_KEY_KEYINFO`, plus `JD_PRIVATE_KEY_PEM` when `JD_SIGNING_MODE` is `local_pem` (the default). The render fails with a `bankTransfer.secrets.<KEY> is required` error for a missing key. In v3.0.2 these keys were written only when set. A key present in `bankTransfer.extraEnvVars` satisfies its check, and no check runs when `bankTransfer.useExistingSecret=true`.
4. New optional secret `bankTransfer.secrets.JD_EXTERNAL_SIGNER_AUTH_TOKEN` (bearer token for `JD_EXTERNAL_SIGNER_URL`). The values comments say to set `JD_EXTERNAL_SIGNER_URL`, `JD_EXTERNAL_SIGNER_TIMEOUT_MS` and `JD_ALLOW_PRIVATE_NETWORK` under `bankTransfer.extraEnvVars`.
5. `MIDAZ_AUTH_ADDRESS` is rendered only when you set it. The chart no longer defaults it to `http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000`. When unset, the application falls back to `PLUGIN_AUTH_ADDRESS` (`global.auth.host`).

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
  secrets:
    JD_USER_CODE: "<jd-user-code>"
    JD_PASSWORD: "<jd-password>"
    JD_PRIVATE_KEY_KEYINFO: "<key-info>"
    JD_PRIVATE_KEY_PEM: "<pem>"  # local_pem signing mode (default)
```

**Why it matters:**  
- The application refuses to start without `JD_LEGACY_CODE`, `JD_USER_CODE` and `JD_PASSWORD` when `JD_BASE_URL` is configured, and without `JD_PRIVATE_KEY_KEYINFO` (and `JD_PRIVATE_KEY_PEM` in `local_pem` mode) when signing is enabled. The chart now reports these at render time instead of at pod start.
- `JD_ORIGIN_ISPB` is managed at runtime through systemplane, not as an environment variable.
- If you set `MIDAZ_AUTH_ENABLED=true` and relied on the old `MIDAZ_AUTH_ADDRESS` default, the application now uses `PLUGIN_AUTH_ADDRESS`. Set `MIDAZ_AUTH_ADDRESS` explicitly if the Midaz auth endpoint differs from `global.auth.host`.

**Migration required:**  
Yes for single-tenant installs with `JD_SANDBOX_MODE` not `true`. See [Step 4: Review JD Configuration](#step-4-review-jd-configuration).

### 7. MongoDB Connection Handling Updated

**What changed:**  
The `bank-transfer.mongoEnv` helper and `templates/secrets.yaml` were refactored. The application reads only `MONGO_URI`. The chart now handles three cases:

1. **Bundled MongoDB (default):** the Deployment gets a `MONGO_PASSWORD` env (secretKeyRef on the `<release>-mongodb` subchart Secret, key `mongodb-passwords`, or on `mongodb.auth.existingSecret`) and a `MONGO_URI` assembled with `$(MONGO_PASSWORD)` expansion. No change from v3.0.2.
2. **External MongoDB, `bankTransfer.secrets.MONGO_URI` contains `$(`:** the URI is a literal `env` entry on the Deployment. The password comes from `mongodb.auth.existingSecret` (key `mongodb-passwords`, emitted as a `MONGO_PASSWORD` secretKeyRef env), or else from `bankTransfer.secrets.MONGO_PASSWORD`, which the chart writes into the chart Secret and the pod reads through `envFrom`.
3. **External MongoDB, `bankTransfer.secrets.MONGO_URI` with an inline credential:** the URI is written into the chart Secret and reaches the pod through `envFrom`. In v3.0.2 the same URI was emitted as a literal `env` value on the Deployment, so the credential was visible in the pod spec.

**Before (v3.0.2):**
```yaml
# External MongoDB with only MONGO_PASSWORD set: the chart assembled a URI that pointed at
# the release's own bundled-MongoDB hostname (<release>-mongodb), not at your external host.
# bankTransfer.secrets.MONGO_URI, when set, was used verbatim as a literal env value.
```

**After (v3.0.3):**
```yaml
bankTransfer:
  secrets:
    MONGO_URI: "mongodb://bank_transfer:<password>@<host>:27017/plugin_br_bank_transfer?authSource=plugin_br_bank_transfer&tls=true"
    # or, with a separate password:
    # MONGO_URI: "mongodb://bank_transfer:$(MONGO_PASSWORD)@<host>:27017/plugin_br_bank_transfer?authSource=plugin_br_bank_transfer&tls=true"
    # MONGO_PASSWORD: "<password>"   # only when mongodb.auth.existingSecret is not set
```

**Breaking change:**  
In single-tenant mode, an external MongoDB (`mongodb.external=true`, or `mongodb.enabled=false`) now requires `bankTransfer.secrets.MONGO_URI`. The render fails with `bankTransfer.secrets.MONGO_URI is required for an external MongoDB in single-tenant mode`. The check does not apply when `bankTransfer.extraEnvVars` carries `MONGO_URI` or when `bankTransfer.useExistingSecret=true`. Multi-tenant mode does not need it, because MongoDB is resolved per tenant. `bankTransfer.secrets.MONGO_PASSWORD` is now written only when `MONGO_URI` references `$(MONGO_PASSWORD)`.

**Migration required:**  
Yes for an external MongoDB in single-tenant mode. See [Step 7: Set MONGO_URI for an External MongoDB](#step-7-set-mongo_uri-for-an-external-mongodb). No change for the bundled MongoDB.

### 8. Streaming Library Updated to v4

**What changed:**  
The chart comments now refer to lib-streaming v4 (previously v3). The application already used `lib-streaming/v4` v4.2.0 in both v3.3.0 and v3.4.0, so no library change comes with this app bump. The rendered streaming fields are unchanged.

**Configuration fields (unchanged):**

| Field | Description | Default |
|-------|-------------|---------|
| `STREAMING_ENABLED` | Toggle for streaming (via `global.streaming.enabled`) | `"false"` |
| `STREAMING_BROKERS` | Kafka/RedPanda broker list (via `global.streaming.brokers`) | not rendered until enabled and set |
| `STREAMING_TLS_ENABLED` | Enable TLS for streaming (via `global.streaming.tlsEnabled`) | `"false"` |
| `STREAMING_SASL_MECHANISM` | SASL mechanism (via `global.streaming.saslMechanism`) | `""` |
| `STREAMING_SASL_USERNAME` | SASL username (via `global.streaming.saslUsername`) | `""` |
| `STREAMING_SASL_ALLOW_PLAINTEXT` | Allow plaintext SASL (via `global.streaming.saslAllowPlaintext`) | `"false"` |

Fields other than `STREAMING_ENABLED` and `STREAMING_CLOUDEVENTS_SOURCE` render only when `STREAMING_ENABLED=true` and brokers are set.

**Why it matters:**  
The values comments now state that the shared helper still renders `compression`, `requiredAcks`, `batchLingerMs` and `importantEmitTimeoutMs`, but this application ignores them (fixed in code).

**Migration required:**  
No.

### 9. Rate Limiting Configuration Removed

**What changed:**  
The `RATE_LIMIT_ENABLED` field is no longer rendered in the ConfigMap.

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
Rate limiting is configured at runtime through the systemplane keys `rate_limit.enabled`, `rate_limit.max` and `rate_limit.expiry_sec`. App v3.3.0 and v3.4.0 already ignore the `RATE_LIMIT_ENABLED` environment variable (it is on the application's list of legacy systemplane env twins), so a value set through Helm had no effect before this release either.

**Migration required:**  
No. If you previously set this field, remove it from your values.

### 10. PostgreSQL SSL Mode Defaults Updated

**What changed:**  
The default `POSTGRES_SSLMODE` and `POSTGRES_REPLICA_SSLMODE` values now depend on whether the bundled PostgreSQL subchart provides the database (`postgresql.enabled=true` and `postgresql.external` not true). The same default applies to the migrations initContainer or Job.

| Scenario | v3.0.2 Default | v3.0.3 Default |
|----------|----------------|----------------|
| Bundled PostgreSQL | `"require"` | `"disable"` |
| External PostgreSQL | `"require"` | `"require"` |

`POSTGRES_REPLICA_SSLMODE` defaults to `"disable"` only with the bundled PostgreSQL and a `POSTGRES_REPLICA_HOST` that starts with `<release>-postgresql`. Any other replica host keeps `"require"`. An explicit value from `global.datastores.postgres.ssl` or `bankTransfer.configmap.POSTGRES_SSLMODE` still wins.

**Why it matters:**  
The chart comment states that the bundled subchart serves no TLS, so `require` against it cannot connect. The chart now defaults to `"disable"` for the bundled PostgreSQL and keeps `"require"` for external PostgreSQL.

**Related change (migrations Secret with bundled PostgreSQL):**  
With bundled PostgreSQL and `bankTransfer.useExistingSecret=true`, the migrations initContainer now reads `POSTGRES_PASSWORD` from the bundled `<release>-postgresql` Secret. In v3.0.2 it read it from `bankTransfer.existingSecretName`. The application container is unchanged. If your existing Secret holds a different PostgreSQL password than the subchart Secret, review this before upgrading. For external PostgreSQL the migrations still use `bankTransfer.migrations.existingSecretName`, then `bankTransfer.existingSecretName`.

**Migration required:**  
No for the SSL default; the change is automatic. If you previously overrode `POSTGRES_SSLMODE` to `"disable"` for the bundled PostgreSQL, you can remove that override.

## Template Changes

### MongoDB Environment Variable Logic

The `bank-transfer.mongoEnv` template helper decides which `MONGO_PASSWORD` and `MONGO_URI` env entries the Deployment gets. The chart Secret (`templates/secrets.yaml`) carries `MONGO_URI` or `MONGO_PASSWORD` in the remaining cases.

**Before (v3.0.2):**

- `MONGO_PASSWORD` env: secretKeyRef on the subchart Secret or `mongodb.auth.existingSecret` (key `mongodb-passwords`), or on the chart Secret key `MONGO_PASSWORD` when `bankTransfer.secrets.MONGO_PASSWORD` was set.
- `MONGO_URI` env: `bankTransfer.secrets.MONGO_URI` verbatim as a literal value, or the assembled URI for the bundled MongoDB.
- `templates/secrets.yaml` wrote `MONGO_URI` itself when it was set, and otherwise assembled one pointing at `<release>-mongodb`.

**After (v3.0.3):** the helper checks whether `bankTransfer.secrets.MONGO_URI` contains `$(`:

```yaml
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
```

**Operational impact:**  
- **Bundled MongoDB:** no change.
- **External MongoDB with `$(MONGO_PASSWORD)` in the URI:** the URI is a Deployment env value. The password is a Deployment env secretKeyRef when `mongodb.auth.existingSecret` is set, otherwise it comes from the chart Secret through `envFrom`.
- **External MongoDB with an inline credential:** the helper emits nothing. `MONGO_URI` is written into the chart Secret instead of the pod spec.

### ConfigMap Rendering Changes

Several ConfigMap fields changed:

| Field | v3.0.2 Behavior | v3.0.3 Behavior |
|-------|-----------------|-----------------|
| `APPLICATION_NAME` | Always rendered (default `"plugin-br-bank-transfer"`) | Removed (the application does not read it) |
| `DEPLOYMENT_MODE` | Rendered only in single-tenant mode | Always rendered (both modes, default `"byoc"`) |
| `CORS_ALLOWED_ORIGINS` | Rendered when set | Removed (systemplane-managed) |
| `CORS_ALLOWED_METHODS` | Rendered when set | Removed (systemplane-managed) |
| `CORS_ALLOWED_HEADERS` | Rendered when set | Removed (systemplane-managed) |
| `MULTI_TENANT_ENVIRONMENT` | Required when `MULTI_TENANT_ENABLED=true` | Removed (follows `ENVIRONMENT_NAME`) |
| `MULTI_TENANT_ALLOW_INSECURE_HTTP` | Rendered when `MULTI_TENANT_ENABLED=true` | Removed (follows `ENVIRONMENT_NAME`) |
| `MIGRATIONS_PATH` | Always rendered (default `"migrations"`) | Removed from the ConfigMap (the migrations container sets `MIGRATIONS_PATH=/migrations` itself) |
| `REDIS_USER` | Rendered when set via datastore mask | Removed |
| `RABBITMQ_URL` | Rendered with a chart default or the explicit value | Rendered only when set in `bankTransfer.configmap` (legacy); the chart default is gone and the Secret carries the URL |
| `OTEL_LIBRARY_NAME` | Rendered in single-tenant mode | Removed (application derives it) |
| `OTEL_RESOURCE_SERVICE_NAME` | Rendered in single-tenant mode | Removed (application derives it) |
| `OTEL_RESOURCE_SERVICE_VERSION` | Rendered in single-tenant mode | Removed (application derives it) |
| `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | Rendered in single-tenant mode | Removed (application derives it) |
| `OTEL_SDK_DISABLED` | Always rendered (default `"false"`) | Removed (not read by the application) |
| `JD_ORIGIN_ISPB` | Required in single-tenant mode | Removed (systemplane key `tenancy.ispb_organization_bindings`) |
| `MIDAZ_AUTH_ADDRESS` | Always rendered with an access-manager default | Rendered only when explicitly set (the application falls back to `PLUGIN_AUTH_ADDRESS`) |
| `RATE_LIMIT_ENABLED` | Always rendered (default `"false"`) | Removed (systemplane-managed) |
| `POSTGRES_SSLMODE` / `POSTGRES_REPLICA_SSLMODE` | Default `"require"` | Default `"disable"` for the bundled PostgreSQL, `"require"` otherwise |

**New ConfigMap rendering behavior:**

- `DEPLOYMENT_MODE` is always rendered (both single-tenant and multi-tenant modes).
- `HTTP_BODY_LIMIT_BYTES`, `TLS_TERMINATED_UPSTREAM` and the related HTTP server fields (TLS cert/key files, trusted proxies) are rendered in both modes (previously single-tenant only).
- `RABBITMQ_ENABLED` and `RABBITMQ_EXCHANGE` are rendered in both modes (previously single-tenant only).
- `JD_LEGACY_CODE` is **required** (enforced with the `required` template function) in single-tenant mode when `JD_SANDBOX_MODE` is not `true`.

**Secret rendering changes (`templates/secrets.yaml`):**

- `RABBITMQ_URL` is written (and required) when `RABBITMQ_ENABLED=true` and no URL is set in `bankTransfer.configmap` or `bankTransfer.extraEnvVars`. `RABBITMQ_PASSWORD` is no longer written.
- `JD_USER_CODE`, `JD_PASSWORD`, `JD_PRIVATE_KEY_KEYINFO` and, in `local_pem` mode, `JD_PRIVATE_KEY_PEM` are required in single-tenant mode when `JD_SANDBOX_MODE` is not `true`. `JD_EXTERNAL_SIGNER_AUTH_TOKEN` is written when set.
- `MULTI_TENANT_SERVICE_API_KEY` is required in multi-tenant mode.
- `MONGO_URI` is required for an external MongoDB in single-tenant mode. `MONGO_PASSWORD` is written only when the URI references `$(MONGO_PASSWORD)`.

**Other changes:**

- `values.schema.json` no longer lists a top-level `br-bank-transfer` property. The schema root still allows additional properties, so existing values files are not rejected.

## Migration Steps

### Step 1: Review CORS Configuration

No chart change is required. If you set CORS values via `bankTransfer.configmap`, remove them. The chart no longer renders them and the application already ignored them:

**Remove from your values:**
```yaml
bankTransfer:
  configmap:
    CORS_ALLOWED_ORIGINS: "https://bank-transfer.sa-east-1.lerian.io"
    CORS_ALLOWED_METHODS: "GET,POST,PUT,DELETE"
    CORS_ALLOWED_HEADERS: "Content-Type,Authorization"
```

**Action to consider:**  
CORS policy is a runtime setting. If you want a restricted policy, set these systemplane keys through your systemplane administration:

- `cors.allowed_origins` (default `"*"`)
- `cors.allowed_methods`
- `cors.allowed_headers`

> **Note:** until `cors.allowed_origins` is set in systemplane, the application allows all origins (`"*"`). Restrict it for production if the API is reachable from browsers.

### Step 2: Migrate RabbitMQ URL to Secret

If `RABBITMQ_ENABLED=true`, set `bankTransfer.secrets.RABBITMQ_URL` and remove `bankTransfer.configmap.RABBITMQ_URL` (a ConfigMap value takes precedence over the Secret). Remove `bankTransfer.secrets.RABBITMQ_PASSWORD` too if you set it. If you relied on the chart's default URL for the bundled RabbitMQ, you must now set the URL yourself.

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
  secrets:
    RABBITMQ_URL: "amqps://bank_transfer:my-password@rabbitmq.example.com:5671/"
```

> **Important:** Use `amqps://` (TLS) for production deployments. The application requires `amqps://` outside development and test environments; the chart's own messages also list `local`.

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
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "<api-key-for-tenant-manager>"
```

**Why this matters:**  
- The tenant environment follows `ENVIRONMENT_NAME` (`bankTransfer.configmap.ENVIRONMENT_NAME` or `global.env.name`)
- Plaintext `http://` URLs to the Tenant Manager are only allowed when `ENVIRONMENT_NAME` is `"development"` or `"test"`
- The render fails without `MULTI_TENANT_SERVICE_API_KEY` (unless `bankTransfer.extraEnvVars` carries it or `bankTransfer.useExistingSecret=true`)

> **Important:** Ensure the environment name is correct for the target environment. It defaults to `"production"` when neither `bankTransfer.configmap.ENVIRONMENT_NAME` nor `global.env.name` is set, and a plaintext `MULTI_TENANT_URL` is not allowed in production.

### Step 4: Review JD Configuration

If you use JD integration in single-tenant mode (`JD_SANDBOX_MODE` not `true`), set `JD_LEGACY_CODE` and the JD secrets, and remove `JD_ORIGIN_ISPB` from your values.

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
  secrets:
    JD_USER_CODE: "<jd-user-code>"
    JD_PASSWORD: "<jd-password>"
    JD_PRIVATE_KEY_KEYINFO: "<key-info>"
    JD_PRIVATE_KEY_PEM: "<pem>"  # required in JD_SIGNING_MODE=local_pem (the default)
```

**Action required:**  
1. Remove `JD_ORIGIN_ISPB` from your values
2. Ensure `JD_LEGACY_CODE` and the JD secrets above are set (the chart fails the render if they are missing in single-tenant mode outside sandbox)
3. Coordinate with your systemplane administrator to seed the `tenancy.ispb_organization_bindings` runtime key
4. If `MIDAZ_AUTH_ENABLED=true`, set `MIDAZ_AUTH_ADDRESS` explicitly unless `global.auth.host` is also the Midaz auth endpoint

> **Note:** With `JD_SANDBOX_MODE=true` (development/testing), `JD_LEGACY_CODE` and the JD secrets are not required by the chart. With `bankTransfer.useExistingSecret=true` the chart does not check the JD secrets, but the application still needs them in your Secret.

### Step 5: Review OpenTelemetry Configuration

If you previously overrode OpenTelemetry resource attributes, remove those fields from your values. They are no longer rendered.

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
The application derives service name, version and environment itself. Operators only need the telemetry toggle and, optionally, the collector endpoint. A configured endpoint is now honored (see [5. OpenTelemetry Configuration Simplified](#5-opentelemetry-configuration-simplified)).

### Step 6: Remove Deprecated Fields

Optional cleanup. Remove the following fields from your values if present. The chart no longer renders them, so leftovers are ignored and do not fail validation:

```yaml
bankTransfer:
  configmap:
    APPLICATION_NAME: "plugin-br-bank-transfer"  # Remove: not read by the application
    MIGRATIONS_PATH: "migrations"  # Remove: no longer rendered
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
      user: "default"  # Remove: no longer rendered
```

### Step 7: Set MONGO_URI for an External MongoDB

If you run single-tenant mode with an external MongoDB (`mongodb.external=true` or `mongodb.enabled=false`), set `bankTransfer.secrets.MONGO_URI`. The render fails without it.

```yaml
bankTransfer:
  secrets:
    MONGO_URI: "mongodb://bank_transfer:<password>@<host>:27017/plugin_br_bank_transfer?authSource=plugin_br_bank_transfer&tls=true"
```

To keep the password out of the URI, reference `$(MONGO_PASSWORD)` in the URI and supply the password through `mongodb.auth.existingSecret` (key `mongodb-passwords`) or `bankTransfer.secrets.MONGO_PASSWORD`. Bundled MongoDB installs need no change.

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
