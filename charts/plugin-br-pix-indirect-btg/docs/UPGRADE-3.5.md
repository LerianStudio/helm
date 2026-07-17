# Helm Upgrade from v3.4.0 to v3.5.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. New Schedule Worker for Pix Recurrence](#1-new-schedule-worker-for-pix-recurrence)
  - [2. Pix Recurrence and Schedule Webhook Handlers](#2-pix-recurrence-and-schedule-webhook-handlers)
  - [3. Recurring Payment Configuration](#3-recurring-payment-configuration)
  - [4. Schedule Business Rules](#4-schedule-business-rules)
  - [5. MongoDB TLS Configuration](#5-mongodb-tls-configuration)
  - [6. Deployment Mode Configuration](#6-deployment-mode-configuration)
- **[Configuration Reference](#configuration-reference)**
  - [Schedule Worker Configuration](#schedule-worker-configuration)
  - [Inbound Webhook Configuration](#inbound-webhook-configuration)
  - [Outbound Webhook Configuration](#outbound-webhook-configuration)
  - [Pix Service Configuration](#pix-service-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This minor release introduces support for Pix Automático (recurring payments) by adding a new `schedule` worker component and expanding webhook handling across all services. The application version bumps from `1.7.6` to `1.8.0` across all four existing components (`pix`, `inbound`, `outbound`, `reconciliation`) and introduces a fifth component (`schedule`).

The expected upgrade path is an in-place Helm upgrade. The new `schedule` worker is enabled by default with conservative resource limits and a 15-minute polling interval. Existing deployments will continue to function without configuration changes, but operators should review the new schedule worker settings and webhook configurations to ensure they align with their environment requirements.

| Component | v3.4.0 | v3.5.0 |
|-----------|--------|--------|
| Chart version | `3.4.0` | `3.5.0` |
| App version | `1.7.6` | `1.8.0` |
| Components | 4 (pix, inbound, outbound, reconciliation) | 5 (pix, inbound, outbound, reconciliation, schedule) |

## Features

### 1. New Schedule Worker for Pix Recurrence

A new `schedule` worker component has been added to handle Pix Automático (recurring payment) scheduling and execution. This worker runs as a separate deployment with its own service, probes, and configuration.

**What changed:**

The chart now deploys a fifth service component that polls for scheduled payment executions and drives the domain API to process them. The worker is configured with a 15-minute polling interval by default and runs with a single replica.

**Why it matters:**

The schedule worker enables automated recurring payment processing without manual intervention. It handles scheduled cashouts, recurring charges, and authorization requests according to configured business rules.

**Operational impact:**

The upgrade will create new Kubernetes resources:

- Deployment: `plugin-br-pix-indirect-btg-worker-schedule`
- Service: `plugin-br-pix-indirect-btg-worker-schedule` (ClusterIP on port 4018)
- ConfigMap: `plugin-br-pix-indirect-btg-worker-schedule`
- Secret: `plugin-br-pix-indirect-btg-worker-schedule`
- PodDisruptionBudget: `plugin-br-pix-indirect-btg-worker-schedule`

**Default configuration:**

```yaml
schedule:
  replicaCount: 1
  name: "plugin-br-pix-indirect-btg-worker-schedule"
  description: "Schedule (Pix recurrence) Worker for Plugin BR PIX Indirect BTG"
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-indirect-btg-worker-schedule
    pullPolicy: Always
    tag: "1.8.0"
  service:
    type: ClusterIP
    port: 4018
  readinessProbe:
    path: /readyz
  livenessProbe:
    path: /health
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi
  pdb:
    enabled: true
    maxUnavailable: null
    minAvailable: 1
  configmap:
    SCHEDULE_WORKER_ENABLED: "true"
    SCHEDULE_WORKER_INTERVAL: "15m"
    SCHEDULE_WORKER_BATCH_SIZE: "50"
    SCHEDULE_WORKER_STALE_THRESHOLD: "5m"
    SCHEDULE_WORKER_SWEEP_EVERY_N_CYCLES: "10"
    SCHEDULE_WORKER_TIME_WINDOW_ENABLED: "false"
    SCHEDULE_APP_HTTP_TIMEOUT: "30s"
    SCHEDULE_APP_BASE_URL: ""
    PLUGIN_AUTH_URL: ""
    OTEL_RESOURCE_SERVICE_NAME: "schedule-worker"
    OTEL_LIBRARY_NAME: "schedule"
    ENABLE_TELEMETRY: "false"
  secrets:
    PLUGIN_PIX_BTG_CLIENT_ID: ""
    PLUGIN_PIX_BTG_CLIENT_SECRET: ""
```

> **Important:** The `SCHEDULE_APP_BASE_URL` and `PLUGIN_AUTH_URL` must be configured for your environment. The worker requires these endpoints to communicate with the domain API and authenticate. See [Migration Steps](#migration-steps) for required configuration.

**Resource requirements:**

The schedule worker is configured with conservative resource limits suitable for low-throughput recurring payment processing:

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 200m | 500m |
| Memory | 256Mi | 512Mi |

**Autoscaling:**

Autoscaling is disabled by default for the schedule worker:

```yaml
schedule:
  autoscaling:
    enabled: false
    minReplicas: 1
    maxReplicas: 1
```

> **Note:** The schedule worker is designed to run as a single replica with leader election. Horizontal scaling is not recommended for this component.

### 2. Pix Recurrence and Schedule Webhook Handlers

The `inbound` and `outbound` workers now include webhook handlers for Pix Automático entities and schedule terminal events.

**What changed:**

Four new webhook entity types have been added to the `inbound` worker:

- `PIX_RECURRENCE_PAYER`: Handles payer-side recurring payment webhooks
- `PIX_RECURRENCE_COLLECTION`: Handles collection-side recurring payment webhooks
- `SCHEDULE_TERMINAL_EVENT`: Handles schedule execution terminal events
- `CASHOUT_TERMINAL_EVENT`: Handles cashout terminal events

Five new webhook entity types have been added to the `outbound` worker:

- `RECURRING_AUTHORIZATION_REQUEST`: Sends authorization requests to external systems
- `RECURRING_AUTHORIZATION`: Sends authorization updates to external systems
- `RECURRING_CHARGE`: Sends charge notifications to external systems
- `RECURRING_RECURRENCE`: Sends recurrence updates to external systems
- `SCHEDULE_CASHOUT`: Sends scheduled cashout notifications to external systems

**Why it matters:**

These webhook handlers enable the plugin to send and receive recurring payment events, allowing integration with external payment systems and customer notification workflows.

**Operational impact:**

All new webhook handlers are enabled by default with low-throughput settings (1 worker, 50 batch size, 5-10s polling interval). The upgrade will not affect existing webhook processing.

**Inbound webhook defaults:**

```yaml
inbound:
  configmap:
    # PIX_RECURRENCE_PAYER
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_ENABLED: "true"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_WORKER_COUNT: "1"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_BATCH_SIZE: "50"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_POLLING_INTERVAL: "5s"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_PROCESSING_TIMEOUT: "12s"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_MAX_RETRIES: "5"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_MAX_PENDING_TIME: "2m"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_MAX_CONCURRENT: "2"

    # PIX_RECURRENCE_COLLECTION
    WEBHOOK_ENTITY_PIX_RECURRENCE_COLLECTION_ENABLED: "true"
    WEBHOOK_ENTITY_PIX_RECURRENCE_COLLECTION_WORKER_COUNT: "1"
    WEBHOOK_ENTITY_PIX_RECURRENCE_COLLECTION_BATCH_SIZE: "50"
    WEBHOOK_ENTITY_PIX_RECURRENCE_COLLECTION_POLLING_INTERVAL: "5s"
    WEBHOOK_ENTITY_PIX_RECURRENCE_COLLECTION_PROCESSING_TIMEOUT: "12s"
    WEBHOOK_ENTITY_PIX_RECURRENCE_COLLECTION_MAX_RETRIES: "5"
    WEBHOOK_ENTITY_PIX_RECURRENCE_COLLECTION_MAX_PENDING_TIME: "2m"
    WEBHOOK_ENTITY_PIX_RECURRENCE_COLLECTION_MAX_CONCURRENT: "2"

    # SCHEDULE_TERMINAL_EVENT
    WEBHOOK_ENTITY_SCHEDULE_TERMINAL_EVENT_ENABLED: "true"
    WEBHOOK_ENTITY_SCHEDULE_TERMINAL_EVENT_WORKER_COUNT: "1"
    WEBHOOK_ENTITY_SCHEDULE_TERMINAL_EVENT_BATCH_SIZE: "50"
    WEBHOOK_ENTITY_SCHEDULE_TERMINAL_EVENT_POLLING_INTERVAL: "5s"
    WEBHOOK_ENTITY_SCHEDULE_TERMINAL_EVENT_PROCESSING_TIMEOUT: "12s"
    WEBHOOK_ENTITY_SCHEDULE_TERMINAL_EVENT_MAX_RETRIES: "5"
    WEBHOOK_ENTITY_SCHEDULE_TERMINAL_EVENT_MAX_PENDING_TIME: "2m"
    WEBHOOK_ENTITY_SCHEDULE_TERMINAL_EVENT_MAX_CONCURRENT: "2"

    # CASHOUT_TERMINAL_EVENT
    WEBHOOK_ENTITY_CASHOUT_TERMINAL_EVENT_ENABLED: "true"
    WEBHOOK_ENTITY_CASHOUT_TERMINAL_EVENT_WORKER_COUNT: "1"
    WEBHOOK_ENTITY_CASHOUT_TERMINAL_EVENT_BATCH_SIZE: "50"
    WEBHOOK_ENTITY_CASHOUT_TERMINAL_EVENT_POLLING_INTERVAL: "5s"
    WEBHOOK_ENTITY_CASHOUT_TERMINAL_EVENT_PROCESSING_TIMEOUT: "12s"
    WEBHOOK_ENTITY_CASHOUT_TERMINAL_EVENT_MAX_RETRIES: "5"
    WEBHOOK_ENTITY_CASHOUT_TERMINAL_EVENT_MAX_PENDING_TIME: "2m"
    WEBHOOK_ENTITY_CASHOUT_TERMINAL_EVENT_MAX_CONCURRENT: "2"
```

**Outbound webhook defaults:**

```yaml
outbound:
  configmap:
    # RECURRING_AUTHORIZATION_REQUEST
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_ENABLED: "true"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_URL: ""
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_WORKER_COUNT: "1"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_BATCH_SIZE: "50"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_POLLING_INTERVAL: "10s"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_REQUEST_TIMEOUT: "30s"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_MAX_RETRIES: "5"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_BACKOFF_MULTIPLIER: "2"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_MAX_CONCURRENT: "2"

    # RECURRING_AUTHORIZATION
    WEBHOOK_RECURRING_AUTHORIZATION_ENABLED: "true"
    WEBHOOK_RECURRING_AUTHORIZATION_URL: ""
    WEBHOOK_RECURRING_AUTHORIZATION_WORKER_COUNT: "1"
    WEBHOOK_RECURRING_AUTHORIZATION_BATCH_SIZE: "50"
    WEBHOOK_RECURRING_AUTHORIZATION_POLLING_INTERVAL: "10s"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_TIMEOUT: "30s"
    WEBHOOK_RECURRING_AUTHORIZATION_MAX_RETRIES: "5"
    WEBHOOK_RECURRING_AUTHORIZATION_BACKOFF_MULTIPLIER: "2"
    WEBHOOK_RECURRING_AUTHORIZATION_MAX_CONCURRENT: "2"

    # RECURRING_CHARGE
    WEBHOOK_RECURRING_CHARGE_ENABLED: "true"
    WEBHOOK_RECURRING_CHARGE_URL: ""
    WEBHOOK_RECURRING_CHARGE_WORKER_COUNT: "1"
    WEBHOOK_RECURRING_CHARGE_BATCH_SIZE: "50"
    WEBHOOK_RECURRING_CHARGE_POLLING_INTERVAL: "10s"
    WEBHOOK_RECURRING_CHARGE_REQUEST_TIMEOUT: "30s"
    WEBHOOK_RECURRING_CHARGE_MAX_RETRIES: "5"
    WEBHOOK_RECURRING_CHARGE_BACKOFF_MULTIPLIER: "2"
    WEBHOOK_RECURRING_CHARGE_MAX_CONCURRENT: "2"

    # RECURRING_RECURRENCE
    WEBHOOK_RECURRING_RECURRENCE_ENABLED: "true"
    WEBHOOK_RECURRING_RECURRENCE_URL: ""
    WEBHOOK_RECURRING_RECURRENCE_WORKER_COUNT: "1"
    WEBHOOK_RECURRING_RECURRENCE_BATCH_SIZE: "50"
    WEBHOOK_RECURRING_RECURRENCE_POLLING_INTERVAL: "10s"
    WEBHOOK_RECURRING_RECURRENCE_REQUEST_TIMEOUT: "30s"
    WEBHOOK_RECURRING_RECURRENCE_MAX_RETRIES: "5"
    WEBHOOK_RECURRING_RECURRENCE_BACKOFF_MULTIPLIER: "2"
    WEBHOOK_RECURRING_RECURRENCE_MAX_CONCURRENT: "2"

    # SCHEDULE_CASHOUT
    WEBHOOK_SCHEDULE_CASHOUT_ENABLED: "true"
    WEBHOOK_SCHEDULE_CASHOUT_URL: ""
    WEBHOOK_SCHEDULE_CASHOUT_WORKER_COUNT: "1"
    WEBHOOK_SCHEDULE_CASHOUT_BATCH_SIZE: "50"
    WEBHOOK_SCHEDULE_CASHOUT_POLLING_INTERVAL: "10s"
    WEBHOOK_SCHEDULE_CASHOUT_REQUEST_TIMEOUT: "30s"
    WEBHOOK_SCHEDULE_CASHOUT_MAX_RETRIES: "5"
    WEBHOOK_SCHEDULE_CASHOUT_BACKOFF_MULTIPLIER: "2"
    WEBHOOK_SCHEDULE_CASHOUT_MAX_CONCURRENT: "2"
```

> **Important:** Outbound webhook URLs must be configured for your environment. The `*_URL` fields are empty by default and must be set to valid endpoints. See [Migration Steps](#migration-steps) for required configuration.

### 3. Recurring Payment Configuration

The `pix` service now includes configuration for recurring payment processing, including anti-spam windows, retry logic, and schedule lead times.

**What changed:**

Four new environment variables control recurring payment behavior:

| Variable | Default | Description |
|----------|---------|-------------|
| `RECURRING_ANTISPAM_WINDOW` | `720h` (30 days) | Time window for duplicate authorization request detection |
| `RECURRING_REPLY_MAX_ATTEMPTS` | `3` | Maximum retry attempts for recurring payment replies |
| `RECURRING_REPLY_BACKOFF` | `150ms` | Backoff duration between retry attempts |
| `RECURRING_SCHEDULE_LEAD_DAYS` | `1` | Number of days in advance to schedule recurring payments |

**Why it matters:**

These settings control how the plugin handles recurring payment authorization requests and scheduling, preventing duplicate processing and ensuring timely execution.

**Operational impact:**

The default values are conservative and suitable for most deployments. Operators may need to adjust these based on their specific requirements:

- Increase `RECURRING_ANTISPAM_WINDOW` for longer duplicate detection periods
- Increase `RECURRING_REPLY_MAX_ATTEMPTS` for more aggressive retry behavior
- Adjust `RECURRING_SCHEDULE_LEAD_DAYS` based on business requirements for advance scheduling

**Example configuration:**

```yaml
pix:
  configmap:
    RECURRING_ANTISPAM_WINDOW: "720h"
    RECURRING_REPLY_MAX_ATTEMPTS: "3"
    RECURRING_REPLY_BACKOFF: "150ms"
    RECURRING_SCHEDULE_LEAD_DAYS: "1"
```

### 4. Schedule Business Rules

The `pix` service now includes business rule configuration for scheduled payment validation and execution.

**What changed:**

Four new environment variables define schedule business rules:

| Variable | Default | Description |
|----------|---------|-------------|
| `SCHEDULE_MAX_FUTURE_DAYS` | `180` | Maximum days in the future a payment can be scheduled |
| `SCHEDULE_MIN_FUTURE_SECONDS` | `60` | Minimum seconds in the future a payment can be scheduled |
| `SCHEDULE_DEFAULT_EXECUTE_HOUR_BRT` | `6` | Default execution hour (BRT timezone) when no time is specified |
| `SCHEDULE_MAX_ATTEMPTS` | `2` | Maximum execution attempts for a scheduled payment |

**Why it matters:**

These rules enforce business constraints on scheduled payments, preventing invalid scheduling requests and defining retry behavior for failed executions.

**Operational impact:**

The default values align with typical Pix Automático requirements. Operators should review these settings to ensure they match their business rules:

- `SCHEDULE_MAX_FUTURE_DAYS`: Limits how far in advance payments can be scheduled (default 180 days = 6 months)
- `SCHEDULE_MIN_FUTURE_SECONDS`: Prevents scheduling payments too close to the current time (default 60 seconds)
- `SCHEDULE_DEFAULT_EXECUTE_HOUR_BRT`: Sets the default execution time for payments without a specified time (default 6 AM BRT)
- `SCHEDULE_MAX_ATTEMPTS`: Controls retry behavior for failed executions (default 2 attempts)

**Example configuration:**

```yaml
pix:
  configmap:
    SCHEDULE_MAX_FUTURE_DAYS: "180"
    SCHEDULE_MIN_FUTURE_SECONDS: "60"
    SCHEDULE_DEFAULT_EXECUTE_HOUR_BRT: "6"
    SCHEDULE_MAX_ATTEMPTS: "2"
```

### 5. MongoDB TLS Configuration

The `pix` service now includes explicit MongoDB TLS configuration.

**What changed:**

A new `MONGO_TLS` environment variable has been added to control TLS connections to MongoDB:

| Setting | v3.4.0 | v3.5.0 |
|---------|--------|--------|
| `pix.configmap.MONGO_TLS` | (not present) | `"false"` |

**Why it matters:**

This setting allows operators to enable TLS for MongoDB connections when required by their infrastructure security policies.

**Operational impact:**

The default value is `"false"`, which maintains backward compatibility with existing deployments. If your MongoDB instance requires TLS, set this to `"true"`:

```yaml
pix:
  configmap:
    MONGO_TLS: "true"
```

> **Note:** Enabling MongoDB TLS may require additional configuration such as certificate paths or trust store settings. Consult your MongoDB documentation for TLS setup requirements.

### 6. Deployment Mode Configuration

The `pix` service now includes a deployment mode configuration flag.

**What changed:**

A new `DEPLOYMENT_MODE` environment variable has been added:

| Setting | v3.4.0 | v3.5.0 |
|---------|--------|--------|
| `pix.configmap.DEPLOYMENT_MODE` | (not present) | `"local"` |

**Why it matters:**

This setting allows the application to adjust its behavior based on the deployment environment (e.g., local development, staging, production).

**Operational impact:**

The default value is `"local"`. For production deployments, operators should set this to an appropriate value:

```yaml
pix:
  configmap:
    DEPLOYMENT_MODE: "production"
```

> **Note:** Consult the application documentation for valid deployment mode values and their effects on application behavior.

## Configuration Reference

### Schedule Worker Configuration

The schedule worker is configured through the `schedule` values block. All settings are optional and default to the values shown below.

**Worker loop settings:**

| Flag | Default | Description |
|------|---------|-------------|
| `SCHEDULE_WORKER_ENABLED` | `"true"` | Enable or disable the schedule worker loop |
| `SCHEDULE_WORKER_INTERVAL` | `"15m"` | Polling interval for checking scheduled payments |
| `SCHEDULE_WORKER_BATCH_SIZE` | `"50"` | Number of scheduled payments to process per batch |
| `SCHEDULE_WORKER_STALE_THRESHOLD` | `"5m"` | Time threshold for considering a payment stale |
| `SCHEDULE_WORKER_SWEEP_EVERY_N_CYCLES` | `"10"` | Run stale payment cleanup every N polling cycles |
| `SCHEDULE_WORKER_TIME_WINDOW_ENABLED` | `"false"` | Enable time window restrictions for worker execution |
| `SCHEDULE_WORKER_WINDOW_START` | `""` | Start time for worker execution window (HH:MM format) |
| `SCHEDULE_WORKER_WINDOW_END` | `""` | End time for worker execution window (HH:MM format) |
| `SCHEDULE_WORKER_DISPATCH_CONCURRENCY` | `"0"` | Maximum concurrent payment dispatches (0 = unlimited) |
| `SCHEDULE_WORKER_JOB_TIMEOUT` | `"0s"` | Timeout for individual payment processing jobs (0 = no timeout) |
| `SCHEDULE_WORKER_NSF_RETRY_HOUR_BRT` | `"0"` | Hour (BRT) to retry NSF (insufficient funds) payments |
| `SCHEDULE_WORKER_RECONCILE_ENABLED` | `"false"` | Enable reconciliation of stuck payments |
| `SCHEDULE_WORKER_RECONCILE_THRESHOLD` | `"30m"` | Time threshold for reconciliation |
| `SCHEDULE_WORKER_RECONCILE_EVERY_N_CYCLES` | `"40"` | Run reconciliation every N polling cycles |
| `SCHEDULE_WORKER_RECONCILE_BATCH_SIZE` | `"50"` | Batch size for reconciliation queries |

**Application endpoint settings:**

| Flag | Default | Description |
|------|---------|-------------|
| `SCHEDULE_APP_BASE_URL` | `""` | Base URL of the domain API the worker drives |
| `SCHEDULE_APP_HTTP_TIMEOUT` | `"30s"` | HTTP timeout for domain API requests |
| `PLUGIN_AUTH_URL` | `""` | Authentication endpoint URL |

**Observability settings:**

| Flag | Default | Description |
|------|---------|-------------|
| `OTEL_RESOURCE_SERVICE_NAME` | `"schedule-worker"` | Service name for OpenTelemetry traces |
| `OTEL_LIBRARY_NAME` | `"schedule"` | Library name for OpenTelemetry traces |
| `ENABLE_TELEMETRY` | `"false"` | Enable or disable OpenTelemetry telemetry |

**Example custom configuration:**

```yaml
schedule:
  configmap:
    SCHEDULE_WORKER_ENABLED: "true"
    SCHEDULE_WORKER_INTERVAL: "10m"
    SCHEDULE_WORKER_BATCH_SIZE: "100"
    SCHEDULE_WORKER_TIME_WINDOW_ENABLED: "true"
    SCHEDULE_WORKER_WINDOW_START: "06:00"
    SCHEDULE_WORKER_WINDOW_END: "22:00"
    SCHEDULE_APP_BASE_URL: "http://plugin-br-pix-indirect-btg.midaz-plugins.svc.cluster.local:4014"
    PLUGIN_AUTH_URL: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000/v1/login/oauth/access_token"
    ENABLE_TELEMETRY: "true"
  secrets:
    PLUGIN_PIX_BTG_CLIENT_ID: "your-client-id"
    PLUGIN_PIX_BTG_CLIENT_SECRET: "your-client-secret"
```

### Inbound Webhook Configuration

The inbound worker now supports four additional webhook entity types. Each entity type has the same configuration structure:

| Flag | Default | Description |
|------|---------|-------------|
| `WEBHOOK_ENTITY_<TYPE>_ENABLED` | `"true"` | Enable or disable the webhook handler |
| `WEBHOOK_ENTITY_<TYPE>_WORKER_COUNT` | `"1"` | Number of concurrent workers |
| `WEBHOOK_ENTITY_<TYPE>_BATCH_SIZE` | `"50"` | Number of webhooks to process per batch |
| `WEBHOOK_ENTITY_<TYPE>_POLLING_INTERVAL` | `"5s"` | Polling interval for checking pending webhooks |
| `WEBHOOK_ENTITY_<TYPE>_PROCESSING_TIMEOUT` | `"12s"` | Timeout for processing a single webhook |
| `WEBHOOK_ENTITY_<TYPE>_MAX_RETRIES` | `"5"` | Maximum retry attempts for failed webhooks |
| `WEBHOOK_ENTITY_<TYPE>_MAX_PENDING_TIME` | `"2m"` | Maximum time a webhook can remain pending |
| `WEBHOOK_ENTITY_<TYPE>_MAX_CONCURRENT` | `"2"` | Maximum concurrent webhook processing |

Replace `<TYPE>` with one of:

- `PIX_RECURRENCE_PAYER`
- `PIX_RECURRENCE_COLLECTION`
- `SCHEDULE_TERMINAL_EVENT`
- `CASHOUT_TERMINAL_EVENT`

**Example custom configuration:**

```yaml
inbound:
  configmap:
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_ENABLED: "true"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_WORKER_COUNT: "2"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_BATCH_SIZE: "100"
    WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_POLLING_INTERVAL: "3s"
```

### Outbound Webhook Configuration

The outbound worker now supports five additional webhook entity types. Each entity type has the same configuration structure:

| Flag | Default | Description |
|------|---------|-------------|
| `WEBHOOK_<TYPE>_ENABLED` | `"true"` | Enable or disable the webhook handler |
| `WEBHOOK_<TYPE>_URL` | `""` | Target URL for webhook delivery |
| `WEBHOOK_<TYPE>_WORKER_COUNT` | `"1"` | Number of concurrent workers |
| `WEBHOOK_<TYPE>_BATCH_SIZE` | `"50"` | Number of webhooks to process per batch |
| `WEBHOOK_<TYPE>_POLLING_INTERVAL` | `"10s"` | Polling interval for checking pending webhooks |
| `WEBHOOK_<TYPE>_REQUEST_TIMEOUT` | `"30s"` | HTTP timeout for webhook delivery |
| `WEBHOOK_<TYPE>_MAX_RETRIES` | `"5"` | Maximum retry attempts for failed webhooks |
| `WEBHOOK_<TYPE>_BACKOFF_MULTIPLIER` | `"2"` | Backoff multiplier for retry delays |
| `WEBHOOK_<TYPE>_MAX_CONCURRENT` | `"2"` | Maximum concurrent webhook delivery |

Replace `<TYPE>` with one of:

- `RECURRING_AUTHORIZATION_REQUEST`
- `RECURRING_AUTHORIZATION`
- `RECURRING_CHARGE`
- `RECURRING_RECURRENCE`
- `SCHEDULE_CASHOUT`

**Example custom configuration:**

```yaml
outbound:
  configmap:
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_ENABLED: "true"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_URL: "https://api.example.com/webhooks/recurring-auth-request"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_WORKER_COUNT: "2"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_BATCH_SIZE: "100"
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_REQUEST_TIMEOUT: "60s"
```

### Pix Service Configuration

The pix service includes new configuration for recurring payments and schedule business rules.

**Recurring payment settings:**

| Flag | Default | Description |
|------|---------|-------------|
| `RECURRING_ANTISPAM_WINDOW` | `"720h"` | Time window for duplicate authorization request detection |
| `RECURRING_REPLY_MAX_ATTEMPTS` | `"3"` | Maximum retry attempts for recurring payment replies |
| `RECURRING_REPLY_BACKOFF` | `"150ms"` | Backoff duration between retry attempts |
| `RECURRING_SCHEDULE_LEAD_DAYS` | `"1"` | Number of days in advance to schedule recurring payments |

**Schedule business rules:**

| Flag | Default | Description |
|------|---------|-------------|
| `SCHEDULE_MAX_FUTURE_DAYS` | `"180"` | Maximum days in the future a payment can be scheduled |
| `SCHEDULE_MIN_FUTURE_SECONDS` | `"60"` | Minimum seconds in the future a payment can be scheduled |
| `SCHEDULE_DEFAULT_EXECUTE_HOUR_BRT` | `"6"` | Default execution hour (BRT timezone) when no time is specified |
| `SCHEDULE_MAX_ATTEMPTS` | `"2"` | Maximum execution attempts for a scheduled payment |

**Infrastructure settings:**

| Flag | Default | Description |
|------|---------|-------------|
| `DEPLOYMENT_MODE` | `"local"` | Deployment environment mode |
| `MONGO_TLS` | `"false"` | Enable TLS for MongoDB connections |

## Migration Steps

This upgrade requires configuration of the new schedule worker endpoints and optional review of webhook settings.

**Required configuration:**

1. **Configure schedule worker endpoints:**

The schedule worker requires two endpoint URLs to function. Set these in your values file or via `--set` flags:

```yaml
schedule:
  configmap:
    SCHEDULE_APP_BASE_URL: "http://plugin-br-pix-indirect-btg.midaz-plugins.svc.cluster.local:4014"
    PLUGIN_AUTH_URL: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000/v1/login/oauth/access_token"
  secrets:
    PLUGIN_PIX_BTG_CLIENT_ID: "your-client-id"
    PLUGIN_PIX_BTG_CLIENT_SECRET: "your-client-secret"
```

> **Important:** Replace the URLs and credentials with values appropriate for your environment. The schedule worker will fail to start if these are not configured.

2. **Configure outbound webhook URLs (if using recurring payments):**

If you plan to use recurring payment features, configure the outbound webhook URLs:

```yaml
outbound:
  configmap:
    WEBHOOK_RECURRING_AUTHORIZATION_REQUEST_URL: "https://api.example.com/webhooks/recurring-auth-request"
    WEBHOOK_RECURRING_AUTHORIZATION_URL: "https://api.example.com/webhooks/recurring-auth"
    WEBHOOK_RECURRING_CHARGE_URL: "https://api.example.com/webhooks/recurring-charge"
    WEBHOOK_RECURRING_RECURRENCE_URL: "https://api.example.com/webhooks/recurring-recurrence"
    WEBHOOK_SCHEDULE_CASHOUT_URL: "https://api.example.com/webhooks/schedule-cashout"
```

> **Note:** If you do not configure these URLs, the outbound worker will log errors when attempting to deliver recurring payment webhooks. You can disable individual webhook handlers by setting their `*_ENABLED` flag to `"false"`.

**Optional configuration:**

3. **
