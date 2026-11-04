# Helm Upgrade from v4.0.0 to v4.0.1

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. RabbitMQ dependency removed](#1-rabbitmq-dependency-removed)
  - [2. Streaming broker (Kafka API) now required](#2-streaming-broker-kafka-api-now-required)
  - [3. Environment variable naming changes](#3-environment-variable-naming-changes)
  - [4. License key now required in all environments](#4-license-key-now-required-in-all-environments)
  - [5. Multi-tenancy configuration removed](#5-multi-tenancy-configuration-removed)
  - [6. Plugin Auth client configuration simplified](#6-plugin-auth-client-configuration-simplified)
  - [7. AI Insights rate limiting configuration simplified](#7-ai-insights-rate-limiting-configuration-simplified)
  - [8. BC Correio retry configuration removed](#8-bc-correio-retry-configuration-removed)
- **[Features](#features)**
  - [1. Application version bump to 1.1.0](#1-application-version-bump-to-110)
- **[Configuration Changes](#configuration-changes)**
  - [Removed Settings](#removed-settings)
  - [New Settings](#new-settings)
  - [Modified Settings](#modified-settings)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Provision external streaming broker](#step-1-provision-external-streaming-broker)
  - [Step 2: Update values file](#step-2-update-values-file)
  - [Step 3: Remove RabbitMQ-related overrides](#step-3-remove-rabbitmq-related-overrides)
  - [Step 4: Review environment variable changes](#step-4-review-environment-variable-changes)
  - [Step 5: Upgrade the chart](#step-5-upgrade-the-chart)
  - [Step 6: Verify deployment](#step-6-verify-deployment)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from 1.0.0 to 1.1.0 and introduces **breaking changes** to the messaging architecture. The chart removes the bundled RabbitMQ dependency and replaces it with a Kafka-compatible streaming broker. Several configuration keys have been removed, renamed, or simplified. Operators must provision an external Kafka-compatible broker and update their values files before upgrading.

| Component   | v4.0.0  | v4.0.1   |
|-------------|---------|----------|
| version     | 4.0.0   | 4.0.1    |
| appVersion  | 1.0.0   | 1.1.0    |

> **Warning:** This upgrade requires manual intervention. The application will refuse to start without a configured streaming broker. Review all breaking changes and migration steps before proceeding.

## Breaking Changes

### 1. RabbitMQ dependency removed

The chart no longer bundles RabbitMQ as a subchart dependency. All RabbitMQ-related configuration has been removed from `values.yaml`, including the `rabbitmq` subchart block, the `global.externalRabbitmqDefinitions` bootstrap job, and all RabbitMQ environment variables and secrets.

**Before (v4.0.0):**

```yaml
rabbitmq:
  enabled: true
  image:
    tag: "4.0.5"
  persistence:
    size: 4Gi
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 1Gi
  authentication:
    existingSecret: "bc-correios"
    user:
      value: "plugin-bc-correios"
    password:
      value: ""
    erlangCookie:
      secretKey: RABBITMQ_ERLANG_COOKIE
```

**After (v4.0.1):**

The entire `rabbitmq` block is removed. The chart no longer renders RabbitMQ resources.

**Removed configuration blocks:**

- `rabbitmq` (subchart dependency)
- `global.externalRabbitmqDefinitions` (bootstrap job for external RabbitMQ)
- `bc-correios.configmap.RABBITMQ_USER`
- `bc-correios.configmap.RABBITMQ_HOST`
- `bc-correios.secrets.RABBITMQ_PASS`
- `bc-correios.secrets.RABBITMQ_URL`
- `bc-correios.secrets.RABBITMQ_ERLANG_COOKIE`

**Operational impact:**

- If you were using the bundled RabbitMQ (`rabbitmq.enabled: true`), the RabbitMQ StatefulSet and Service will be removed during the upgrade. **Queue data will be lost** unless you migrate it to the new streaming broker before upgrading.
- If you were using an external RabbitMQ with the bootstrap job (`global.externalRabbitmqDefinitions.enabled: true`), the bootstrap job will no longer run. Remove the `global.externalRabbitmqDefinitions` block from your values file.
- The application no longer connects to RabbitMQ. All messaging is now handled by the Kafka-compatible streaming broker.

> **Important:** The chart does not provide a migration path for RabbitMQ queue data. If you have critical messages in RabbitMQ queues, you must drain or migrate them manually before upgrading.

### 2. Streaming broker (Kafka API) now required

The application now requires a Kafka-compatible streaming broker (e.g., Apache Kafka, Redpanda, AWS MSK). The `STREAMING_BROKERS` environment variable is **mandatory** — the application refuses to start without it, and the chart includes a render-time validation that fails if `STREAMING_BROKERS` is empty or unset (unless you use `bc-correios.useExistingSecret`).

**New configuration:**

```yaml
bc-correios:
  configmap:
    STREAMING_BROKERS: ""
    STREAMING_TLS_ENABLED: "false"
    # STREAMING_SASL_MECHANISM: "SCRAM-SHA-512"
    # STREAMING_SASL_USERNAME: ""
  secrets:
    # STREAMING_SASL_PASSWORD: ""
```

**Required action:**

Set `bc-correios.configmap.STREAMING_BROKERS` to your Kafka broker list (comma-separated, with ports):

```yaml
bc-correios:
  configmap:
    STREAMING_BROKERS: "broker1.example.com:9092,broker2.example.com:9092"
```

**Optional TLS and SASL configuration:**

If your broker requires TLS:

```yaml
bc-correios:
  configmap:
    STREAMING_BROKERS: "broker.example.com:9093"
    STREAMING_TLS_ENABLED: "true"
  extraEnvVars:
    STREAMING_TLS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
```

If your broker requires SASL authentication:

```yaml
bc-correios:
  configmap:
    STREAMING_BROKERS: "broker.example.com:9092"
    # STREAMING_SASL_MECHANISM: "SCRAM-SHA-512"
    # STREAMING_SASL_USERNAME: "plugin-bc-correios"
  secrets:
    STREAMING_SASL_PASSWORD: "your-sasl-password"
```

Uncomment the `STREAMING_SASL_MECHANISM` and `STREAMING_SASL_USERNAME` lines and set the appropriate values. The password goes in `bc-correios.secrets.STREAMING_SASL_PASSWORD`.

> **Note:** The chart validates `STREAMING_BROKERS` at render time. If it is empty or unset (and you are not using `bc-correios.useExistingSecret`), the upgrade will fail with an error message before any resources are applied.

**Additional streaming configuration:**

Other streaming settings (e.g., `STREAMING_CLIENT_ID`, `STREAMING_TLS_CA_CERT`) can be set via `bc-correios.extraEnvVars`:

```yaml
bc-correios:
  extraEnvVars:
    STREAMING_CLIENT_ID: "plugin-bc-correios-prod"
```

### 3. Environment variable naming changes

The application's environment variable naming has been simplified. `APP_ENV` is removed, and `ENV_NAME` is now the single environment variable that controls the application's environment mode.

**Before (v4.0.0):**

```yaml
bc-correios:
  configmap:
    ENV_NAME: "production"
    APP_ENV: "production"
    APP_VERSION: "1.0.0"
```

The chart rendered both `ENV_NAME` and `APP_ENV`. The application read `APP_ENV` for its own validation logic (production checks for `LICENSE_KEY`, `POSTGRES_SSLMODE`, `ALLOWED_ORIGINS`), while libraries read `ENV_NAME` for log format and security tier.

**After (v4.0.1):**

```yaml
bc-correios:
  configmap:
    ENV_NAME: "production"
```

`APP_ENV` and `APP_VERSION` are removed. The application now reads `ENV_NAME` for all environment-specific behavior. The chart's production validation logic (license key, TLS mode, CORS origins) is now gated on `ENV_NAME` instead of `APP_ENV`.

**Operational impact:**

- If you set `APP_ENV` explicitly in your values file (via `bc-correios.configmap.APP_ENV` or `bc-correios.extraEnvVars.APP_ENV`), remove it and ensure `ENV_NAME` is set to the correct value.
- If you set `APP_VERSION` explicitly, remove it. The application no longer reads this variable.
- The chart's render-time validation now checks `ENV_NAME` instead of `APP_ENV`. If `ENV_NAME` is not `"development"`, the chart requires a non-empty `LICENSE_KEY`, a `POSTGRES_SSLMODE` other than `"disable"`, and explicit `ALLOWED_ORIGINS` (not `"*"`).

**Migration example:**

If your v4.0.0 values file had:

```yaml
bc-correios:
  configmap:
    APP_ENV: "staging"
```

Change it to:

```yaml
bc-correios:
  configmap:
    ENV_NAME: "staging"
```

### 4. License key now required in all environments

The `LICENSE_KEY` environment variable is now **mandatory in all environments**, including development. Previously, the chart only required `LICENSE_KEY` when `APP_ENV` was not `"development"`. The new validation logic requires `LICENSE_KEY` to be set (or present in an existing secret) regardless of the `ENV_NAME` value.

**Before (v4.0.0):**

The chart failed at render time if `APP_ENV` was not `"development"` and `LICENSE_KEY` was empty.

**After (v4.0.1):**

The chart fails at render time if `LICENSE_KEY` is empty, regardless of `ENV_NAME` (unless you use `bc-correios.useExistingSecret`).

**Required action:**

Set `bc-correios.configmap.LICENSE_KEY` in your values file:

```yaml
bc-correios:
  configmap:
    LICENSE_KEY: "your-license-key-here"
```

Or, if you use an existing secret:

```yaml
bc-correios:
  useExistingSecret: true
  existingSecretName: "my-bc-correios-secret"
```

Ensure the secret contains a `LICENSE_KEY` key.

> **Important:** The application will refuse to start without a valid license key. Obtain a license from Lerian Studio before upgrading.

### 5. Multi-tenancy configuration removed

The multi-tenancy feature has been removed from the application. All related configuration keys are removed from `values.yaml`.

**Removed settings:**

- `bc-correios.configmap.MULTI_TENANT_ENABLED`
- `bc-correios.configmap.MULTI_TENANT_URL`
- `bc-correios.configmap.DEFAULT_TENANT_ID`

**Before (v4.0.0):**

```yaml
bc-correios:
  configmap:
    MULTI_TENANT_ENABLED: "false"
    MULTI_TENANT_URL: ""
    DEFAULT_TENANT_ID: "00000000-0000-0000-0000-000000000001"
```

**After (v4.0.1):**

These keys are removed. The application no longer supports multi-tenancy.

**Operational impact:**

- If you set any of these keys in your values file, remove them before upgrading.
- If your deployment relied on multi-tenancy features, contact Lerian Studio for migration guidance.

### 6. Plugin Auth client configuration simplified

The Plugin Auth (Access Manager) client configuration has been simplified. The `PLUGIN_AUTH_CLIENT_ID` environment variable and the `PLUGIN_AUTH_CLIENT_SECRET` secret are removed.

**Removed settings:**

- `bc-correios.configmap.PLUGIN_AUTH_CLIENT_ID`
- `bc-correios.secrets.PLUGIN_AUTH_CLIENT_SECRET` (commented out in v4.0.0, now removed entirely)

**Before (v4.0.0):**

```yaml
bc-correios:
  configmap:
    PLUGIN_AUTH_CLIENT_ID: "plugin-bc-correios"
  secrets:
    # PLUGIN_AUTH_CLIENT_SECRET: ""
```

**After (v4.0.1):**

These keys are removed. The application no longer requires a client ID or secret for Plugin Auth.

**Operational impact:**

- If you set `PLUGIN_AUTH_CLIENT_ID` in your values file, remove it.
- If you uncommented and set `PLUGIN_AUTH_CLIENT_SECRET`, remove it.
- The application still connects to Plugin Auth via `PLUGIN_AUTH_ADDRESS` (or `PLUGIN_AUTH_HOST`), but no longer uses M2M client credentials.

### 7. AI Insights rate limiting configuration simplified

The AI Insights rate limiting configuration has been simplified. The per-tenant rate limiting and concurrency settings are removed, and the global concurrency limit is removed. The remaining settings are renamed.

**Before (v4.0.0):**

```yaml
bc-correios:
  configmap:
    AI_TENANT_RATE_LIMIT_PER_MIN: "50"
    AI_TENANT_MAX_CONCURRENT: "3"
    AI_GLOBAL_MAX_CONCURRENT: "15"
```

**After (v4.0.1):**

```yaml
bc-correios:
  configmap:
    AI_RATE_LIMIT_PER_MIN: "50"
    AI_MAX_CONCURRENT: "3"
```

**Changes:**

| Setting (v4.0.0)                | Setting (v4.0.1)          | Default |
|---------------------------------|---------------------------|---------|
| `AI_TENANT_RATE_LIMIT_PER_MIN`  | `AI_RATE_LIMIT_PER_MIN`   | `"50"`  |
| `AI_TENANT_MAX_CONCURRENT`      | `AI_MAX_CONCURRENT`       | `"3"`   |
| `AI_GLOBAL_MAX_CONCURRENT`      | _(removed)_               | —       |

**Operational impact:**

- If you set `AI_TENANT_RATE_LIMIT_PER_MIN` in your values file, rename it to `AI_RATE_LIMIT_PER_MIN`.
- If you set `AI_TENANT_MAX_CONCURRENT`, rename it to `AI_MAX_CONCURRENT`.
- If you set `AI_GLOBAL_MAX_CONCURRENT`, remove it. The application no longer enforces a global concurrency limit.

**Migration example:**

If your v4.0.0 values file had:

```yaml
bc-correios:
  configmap:
    AI_TENANT_RATE_LIMIT_PER_MIN: "100"
    AI_TENANT_MAX_CONCURRENT: "5"
    AI_GLOBAL_MAX_CONCURRENT: "20"
```

Change it to:

```yaml
bc-correios:
  configmap:
    AI_RATE_LIMIT_PER_MIN: "100"
    AI_MAX_CONCURRENT: "5"
```

### 8. BC Correio retry configuration removed

The `BC_CORREIO_RETRY_MAX_RETRIES` environment variable is removed. The application no longer exposes retry configuration via environment variables.

**Before (v4.0.0):**

```yaml
bc-correios:
  configmap:
    BC_CORREIO_RETRY_MAX_RETRIES: "3"
```

**After (v4.0.1):**

This key is removed.

**Operational impact:**

- If you set `BC_CORREIO_RETRY_MAX_RETRIES` in your values file, remove it.
- The application's retry behavior is now controlled internally and cannot be configured via environment variables.

## Features

### 1. Application version bump to 1.1.0

The chart now ships with `appVersion` `1.1.0`, replacing the previous `1.0.0`. The chart version itself moves from `4.0.0` to `4.0.1`.

| Component   | v4.0.0  | v4.0.1   |
|-------------|---------|----------|
| version     | 4.0.0   | 4.0.1    |
| appVersion  | 1.0.0   | 1.1.0    |

The `bc-correios.image.tag` value in `values.yaml` defaults to `"1.1.0"`:

```yaml
bc-correios:
  image:
    repository: lerianstudio/plugin-bc-correios
    tag: "1.1.0"
```

If you set `bc-correios.image.tag` explicitly in your overrides, align it with the new `appVersion`:

```yaml
bc-correios:
  image:
    tag: "1.1.0"
```

> **Note:** For application-level changes included in version 1.1.0, refer to the plugin-bc-correios changelog.

## Configuration Changes

### Removed Settings

The following settings are removed in v4.0.1:

| Setting                                                      | Reason                                      |
|--------------------------------------------------------------|---------------------------------------------|
| `rabbitmq` (entire subchart block)                           | RabbitMQ dependency removed                 |
| `global.externalRabbitmqDefinitions` (entire block)          | RabbitMQ bootstrap job removed              |
| `bc-correios.configmap.RABBITMQ_USER`                        | RabbitMQ removed                            |
| `bc-correios.configmap.RABBITMQ_HOST`                        | RabbitMQ removed                            |
| `bc-correios.configmap.APP_ENV`                              | Replaced by `ENV_NAME`                      |
| `bc-correios.configmap.APP_VERSION`                          | No longer used by application               |
| `bc-correios.configmap.PLUGIN_AUTH_CLIENT_ID`                | Plugin Auth client config simplified        |
| `bc-correios.configmap.MULTI_TENANT_ENABLED`                 | Multi-tenancy feature removed               |
| `bc-correios.configmap.MULTI_TENANT_URL`                     | Multi-tenancy feature removed               |
| `bc-correios.configmap.DEFAULT_TENANT_ID`                    | Multi-tenancy feature removed               |
| `bc-correios.configmap.AI_TENANT_RATE_LIMIT_PER_MIN`         | Renamed to `AI_RATE_LIMIT_PER_MIN`          |
| `bc-correios.configmap.AI_TENANT_MAX_CONCURRENT`             | Renamed to `AI_MAX_CONCURRENT`              |
| `bc-correios.configmap.AI_GLOBAL_MAX_CONCURRENT`             | Removed (no global limit)                   |
| `bc-correios.configmap.BC_CORREIO_RETRY_MAX_RETRIES`         | Retry config no longer exposed              |
| `bc-correios.secrets.RABBITMQ_PASS`                          | RabbitMQ removed                            |
| `bc-correios.secrets.RABBITMQ_URL`                           | RabbitMQ removed                            |
| `bc-correios.secrets.RABBITMQ_ERLANG_COOKIE`                 | RabbitMQ removed                            |
| `bc-correios.secrets.PLUGIN_AUTH_CLIENT_SECRET` (commented)  | Plugin Auth client config simplified        |

### New Settings

The following settings are added in v4.0.1:

| Setting                                      | Default         | Description                                                                 |
|----------------------------------------------|-----------------|-----------------------------------------------------------------------------|
| `bc-correios.configmap.STREAMING_BROKERS`    | `""`            | Kafka-compatible broker list (comma-separated, with ports). **Required.**   |
| `bc-correios.configmap.STREAMING_TLS_ENABLED`| `"false"`       | Enable TLS for streaming broker connection                                  |
| `bc-correios.configmap.AI_RATE_LIMIT_PER_MIN`| `"50"`          | AI Insights rate limit per minute (renamed from `AI_TENANT_RATE_LIMIT_PER_MIN`) |
| `bc-correios.configmap.AI_MAX_CONCURRENT`    | `"3"`           | AI Insights max concurrent requests (renamed from `AI_TENANT_MAX_CONCURRENT`) |
| `bc-correios.secrets.STREAMING_SASL_PASSWORD`| _(commented)_   | SASL password for streaming broker authentication (optional)                |

**Additional streaming settings (via `extraEnvVars`):**

- `STREAMING_SASL_MECHANISM`: SASL mechanism (e.g., `"SCRAM-SHA-512"`)
- `STREAMING_SASL_USERNAME`: SASL username
- `STREAMING_CLIENT_ID`: Kafka client ID
- `STREAMING_TLS_CA_CERT`: TLS CA certificate (PEM format)

### Modified Settings

The following settings have changed behavior or defaults:

| Setting                                  | v4.0.0 Default  | v4.0.1 Default  | Change                                                                 |
|------------------------------------------|-----------------|-----------------|------------------------------------------------------------------------|
| `bc-correios.image.tag`                  | `"1.0.0"`       | `"1.1.0"`       | Application version bump                                               |
| `bc-correios.configmap.ENV_NAME`         | `"production"`  | `"production"`  | Now the single environment variable (replaces `APP_ENV`)               |
| `bc-correios.configmap.LICENSE_KEY`      | `""`            | `""`            | Now required in all environments (previously only non-development)     |

## Migration Steps

### Step 1: Provision external streaming broker

Before upgrading, provision a Kafka-compatible streaming broker (e.g., Apache Kafka, Redpanda, AWS MSK, Confluent Cloud). The application requires a broker that supports the Kafka protocol.

**Minimum broker requirements:**

- Kafka API version 2.0.0 or later
- At least one accessible broker endpoint
- (Optional) TLS support if you require encrypted connections
- (Optional) SASL authentication if you require access control

**Example: Deploy Redpanda using Helm:**

```bash
helm repo add redpanda https://charts.redpanda.com
helm install redpanda redpanda/redpanda --namespace streaming --create-namespace
```

**Example: Use AWS MSK:**

Provision an MSK cluster via the AWS Console or Terraform, then note the broker endpoints (e.g., `b-1.msk-cluster.abc123.kafka.us-east-1.amazonaws.com:9092`).

### Step 2: Update values file

Create or update your values override file with the new streaming broker configuration and remove all RabbitMQ-related settings.

**Minimal required changes:**

```yaml
bc-correios:
  configmap:
    STREAMING_BROKERS: "broker1.example.com:9092,broker2.example.com:9092"
    LICENSE_KEY: "your-license-key-here"
```

**If you were using the bundled RabbitMQ:**

Remove the entire `rabbitmq` block from your values file:

```yaml
# Remove this entire block:
# rabbitmq:
#   enabled: true
#   persistence:
#     size: 8Gi
#   resources:
#     requests:
#       cpu: 500m
#       memory: 1Gi
```

**If you were using the RabbitMQ bootstrap job:**

Remove the `global.externalRabbitmqDefinitions` block:

```yaml
# Remove this entire block:
# global:
#   externalRabbitmqDefinitions:
#     enabled: true
#     connection:
#       host: "external-rabbitmq.example.com"
```

**If your broker requires TLS:**

```yaml
bc-correios:
  configmap:
    STREAMING_BROKERS: "broker.example.com:9093"
    STREAMING_TLS_ENABLED: "true"
  extraEnvVars:
    STREAMING_TLS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKJ...
      -----END CERTIFICATE-----
```

**If your broker requires SASL authentication:**

```yaml
bc-correios:
  configmap:
    STREAMING_BROKERS: "broker.example.com:9092"
  extraEnvVars:
    STREAMING_SASL_MECHANISM: "SCRAM-SHA-512"
    STREAMING_SASL_USERNAME: "plugin-bc-correios"
  secrets:
    STREAMING_SASL_PASSWORD: "your-sasl-password"
```

### Step 3: Remove RabbitMQ-related overrides

Search your values file for any RabbitMQ-related overrides and remove them:

**Remove these keys if present:**

- `bc-correios.configmap.RABBITMQ_USER`
- `bc-correios.configmap.RABBITMQ_HOST`
- `bc-correios.secrets.RABBITMQ_PASS`
- `bc-correios.secrets.RABBITMQ_URL`
- `bc-correios.secrets.RABBITMQ_ERLANG_COOKIE`

**Example:**

If your v4.0.0 values file had:

```yaml
bc-correios:
  configmap:
    RABBITMQ_USER: "my-custom-user"
    RABBITMQ_HOST: "external-rabbitmq.example.com"
  secrets:
    RABBITMQ_PASS: "my-password"
```

Remove all three keys.

### Step 4: Review environment variable changes

Review your values file for the environment variable changes described in [Breaking Changes](#breaking-changes):

1. **Rename `APP_ENV` to `ENV_NAME`** (if you set it explicitly)
2. **Remove `APP_VERSION`** (if you set it explicitly)
3. **Rename AI Insights settings:**
   - `AI_TENANT_RATE_LIMIT_PER_MIN` → `AI_RATE_LIMIT_PER_MIN`
   - `AI_TENANT_MAX_CONCURRENT` → `AI_MAX_CONCURRENT`
   - Remove `AI_GLOBAL_MAX_CONCURRENT`
4. **Remove multi-tenancy settings:**
   - `MULTI_TENANT_ENABLED`
   - `MULTI_TENANT_URL`
   - `DEFAULT_TENANT_ID`
5. **Remove Plugin Auth client settings:**
   - `PLUGIN_AUTH_CLIENT_ID`
   - `PLUGIN_AUTH_CLIENT_SECRET`
6. **Remove BC Correio retry setting:**
   - `BC_CORREIO_RETRY_MAX_RETRIES`

**Example migration:**

**Before (v4.0.0):**

```yaml
bc-correios:
  configmap:
    APP_ENV: "staging"
    APP_VERSION: "1.0.0"
    RABBITMQ_USER: "plugin-bc-correios"
    RABBITMQ_HOST: "my-rabbitmq.example.com"
    PLUGIN_AUTH_CLIENT_ID: "plugin-bc-correios"
    AI_TENANT_RATE_LIMIT_PER_MIN: "100"
    AI_TENANT_MAX_CONCURRENT: "5"
    AI_GLOBAL_MAX_CONCURRENT: "20"
    MULTI_TENANT_ENABLED: "false"
    BC_CORREIO_RETRY_MAX_RETRIES: "5"
  secrets:
    RABBITMQ_PASS: "my-password"
```

**After (v4.0.1):**

```yaml
bc-correios:
  configmap:
    ENV_NAME: "staging"
    STREAMING_BROKERS: "broker.example.com:9092"
    LICENSE_KEY: "your-license-key-here"
    AI_RATE_LIMIT_PER_MIN: "100"
    AI_MAX_CONCURRENT: "5"
```

### Step 5: Upgrade the chart

Run the Helm upgrade command with your updated values file:

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm \
  --version 4.0.1 \
  --namespace plugin-bc-correios \
  --values your-values.yaml
```

> **Warning:** If you were using the bundled RabbitMQ, the RabbitMQ StatefulSet and PersistentVolumeClaims will be removed during the upgrade. Ensure you have drained or migrated any critical queue data before proceeding.

### Step 6: Verify deployment

After the upgrade completes, verify that the application is running and connected to the streaming broker:

1. **Check pod status:**

```bash
kubectl get pods -n plugin-bc-correios -l app.kubernetes.io/name=bc-correios
```

All pods should be in `Running` state with `READY 1/1`.

2. **Check application logs:**

```bash
kubectl logs -n plugin-bc-correios -l app.kubernetes.io/name=bc-correios --tail=100
```

Look for log lines indicating successful connection to the streaming broker. There should be no errors about missing `STREAMING_BROKERS` or connection failures.

3. **Verify streaming broker connectivity:**

```bash
kubectl exec -n plugin-bc-correios -it deployment/bc-correios -- sh -c 'nc -zv ${STREAMING_BROKERS%%,*}'
```

This command extracts the first broker from `STREAMING_BROKERS` and tests TCP connectivity. You should see a success message.

4. **Check for RabbitMQ resources (should be absent):**

```bash
kubectl get statefulset,service,pvc -n plugin-bc-correios | grep rabbitmq
```

This command should return no results. If you see RabbitMQ resources, they were not removed during the upgrade (possibly due to Helm's resource retention policy). You can delete them manually if desired:

```bash
kubectl delete statefulset plugin-bc-correios-rabbitmq -n plugin-bc-correios
kubectl delete service plugin-bc-correios-rabbitmq -n plugin-bc-correios
kubectl delete pvc data-plugin-bc-correios-rabbitmq-0 -n plugin-bc-correios
```

> **Note:** Deleting the PVC will permanently delete any remaining RabbitMQ queue data.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 4.0.1 -n plugin-bc-correios
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerian
