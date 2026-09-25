# Helm Upgrade from v3.x to v4.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Swagger UI toggle for PIX service](#1-swagger-ui-toggle-for-pix-service)
  - [2. Transaction timing webhook reporting](#2-transaction-timing-webhook-reporting)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Configuration Reference](#configuration-reference)**
  - [PIX Swagger configuration](#pix-swagger-configuration)
  - [Outbound webhook reporting configuration](#outbound-webhook-reporting-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a major release that upgrades the application from `1.9.1` to `1.10.0` and introduces new configuration options for Swagger UI control and transaction timing webhook reporting. The chart version bumps from `3.8.0` to `4.0.0`.

All five service components receive image tag updates:
- **pix**: `1.9.1` → `1.10.0`
- **inbound**: `1.9.0` → `1.10.0`
- **outbound**: `1.9.0` → `1.10.0`
- **reconciliation**: `1.9.0` → `1.10.0`
- **schedule**: `1.9.0` → `1.10.0`

No values are removed or renamed. All new configuration fields are additive with sensible defaults, so existing custom values continue to work without modification.

The expected upgrade path is an in-place Helm upgrade after reviewing the new webhook reporting defaults.

## Features

### 1. Swagger UI toggle for PIX service

The PIX service now supports runtime control of the Swagger UI endpoint via the `SWAGGER_ENABLED` environment variable.

**What changed:**

A new configuration flag `pix.configmap.SWAGGER_ENABLED` has been added to the PIX service ConfigMap, defaulting to `"true"`.

| Component | Configuration key | Default value |
|-----------|------------------|---------------|
| `pix` | `pix.configmap.SWAGGER_ENABLED` | `"true"` |

**Why it matters:**

Operators can now disable the Swagger UI in production environments for security or compliance reasons without rebuilding the application image. The API documentation endpoint can be toggled per deployment.

**Operational impact:**

By default, Swagger UI remains **enabled** after upgrading to v4.0.0. If you want to disable it, override the flag in your values file:

```yaml
pix:
  configmap:
    SWAGGER_ENABLED: "false"
```

> **Note:** Disabling Swagger UI does not affect the PIX service's core API functionality — only the interactive documentation endpoint is disabled.

### 2. Transaction timing webhook reporting

The outbound service now includes a configurable webhook client for reporting transaction timing metrics (`tempos-transacoes`) to an external endpoint.

**What changed:**

Nine new environment variables have been added to the outbound service ConfigMap to control webhook reporting behavior:

| Variable | Default | Description |
|----------|---------|-------------|
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_ENABLED` | `"true"` | Master toggle for webhook reporting |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_URL` | `"https://client-api/v1/webhooks/tempos-transacoes"` | Target webhook endpoint URL |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_BATCH_SIZE` | `"50"` | Number of records per batch |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_WORKER_COUNT` | `"1"` | Number of concurrent workers |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_MAX_CONCURRENT` | `"2"` | Maximum concurrent requests per worker |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_POLLING_INTERVAL` | `"1s"` | Interval between batch polls |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_REQUEST_TIMEOUT` | `"5s"` | HTTP request timeout |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_MAX_RETRIES` | `"10"` | Maximum retry attempts on failure |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_BACKOFF_MULTIPLIER` | `"2"` | Exponential backoff multiplier |

**Why it matters:**

The outbound service can now push transaction timing data to an external analytics or monitoring system. This enables centralized performance tracking and alerting without requiring operators to poll the outbound service directly.

**Operational impact:**

After upgrading, the outbound service will **attempt to send** transaction timing reports to the default URL `https://client-api/v1/webhooks/tempos-transacoes`. If this endpoint does not exist in your environment, you have two options:

#### Option 1: Disable webhook reporting

If you do not need transaction timing reports, disable the feature:

```yaml
outbound:
  configmap:
    WEBHOOK_REPORT_TEMPOSTRANSACOES_ENABLED: "false"
```

#### Option 2: Configure the correct webhook URL

If you have a webhook endpoint ready, update the URL and tune the batch/retry settings:

```yaml
outbound:
  configmap:
    WEBHOOK_REPORT_TEMPOSTRANSACOES_URL: "https://your-analytics-api.example.com/v1/webhooks/tempos-transacoes"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_BATCH_SIZE: "100"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_REQUEST_TIMEOUT: "10s"
```

> **Warning:** If webhook reporting is enabled and the target URL is unreachable, the outbound service will log retry attempts but will **not block** transaction processing. Failed webhook deliveries are retried up to `MAX_RETRIES` times with exponential backoff before being dropped.

> **Important:** The default URL `https://client-api/v1/webhooks/tempos-transacoes` is a placeholder. You **must** either disable the feature or configure a valid endpoint before upgrading to production.

## Configuration Changes

The following table summarizes all configuration changes between v3.8.0 and v4.0.0:

| Setting | v3.8.0 | v4.0.0 |
|---------|--------|--------|
| Chart version | `3.8.0` | `4.0.0` |
| App version | `1.9.1` | `1.10.0` |
| `pix.image.tag` | `1.9.1` | `1.10.0` |
| `inbound.image.tag` | `1.9.0` | `1.10.0` |
| `outbound.image.tag` | `1.9.0` | `1.10.0` |
| `reconciliation.image.tag` | `1.9.0` | `1.10.0` |
| `schedule.image.tag` | `1.9.0` | `1.10.0` |
| `pix.configmap.SWAGGER_ENABLED` | (not present) | `"true"` |
| `outbound.configmap.WEBHOOK_REPORT_TEMPOSTRANSACOES_*` | (not present) | 9 new variables (see table above) |

## Migration Steps

This upgrade requires minimal operator intervention. The new features are enabled by default but will not break existing deployments if the webhook endpoint is unreachable.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Decide whether to enable or disable transaction timing webhook reporting:
   - If you do **not** have a webhook endpoint ready, add the following to your values file:

   ```yaml
   outbound:
     configmap:
       WEBHOOK_REPORT_TEMPOSTRANSACOES_ENABLED: "false"
   ```

   - If you **do** have a webhook endpoint, configure the URL:

   ```yaml
   outbound:
     configmap:
       WEBHOOK_REPORT_TEMPOSTRANSACOES_URL: "https://your-endpoint.example.com/v1/webhooks/tempos-transacoes"
   ```

3. (Optional) If you want to disable Swagger UI in the PIX service, add:

   ```yaml
   pix:
     configmap:
       SWAGGER_ENABLED: "false"
   ```

4. Run the upgrade command during a maintenance window.

5. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n plugin-br-pix-indirect-btg
   ```

6. Check outbound service logs for webhook delivery status:

   ```bash
   kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=outbound --tail=100 | grep -i webhook
   ```

7. If webhook reporting is enabled, confirm that your webhook endpoint is receiving POST requests with transaction timing data.

> **Note:** The upgrade triggers a rolling restart of all five service deployments because the image tags and ConfigMap data change. Depending on your replica count and readiness probe timing, this may cause brief service interruptions.

## Configuration Reference

### PIX Swagger configuration

The PIX service now accepts a Swagger UI toggle in its ConfigMap:

```yaml
pix:
  configmap:
    SWAGGER_ENABLED: "true"  # Set to "false" to disable Swagger UI
```

| Flag | Default | Description |
|------|---------|-------------|
| `SWAGGER_ENABLED` | `"true"` | Enables or disables the Swagger UI documentation endpoint |

### Outbound webhook reporting configuration

The outbound service accepts the following webhook configuration in its ConfigMap:

```yaml
outbound:
  configmap:
    WEBHOOK_REPORT_TEMPOSTRANSACOES_ENABLED: "true"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_URL: "https://client-api/v1/webhooks/tempos-transacoes"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_BATCH_SIZE: "50"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_WORKER_COUNT: "1"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_MAX_CONCURRENT: "2"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_POLLING_INTERVAL: "1s"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_REQUEST_TIMEOUT: "5s"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_MAX_RETRIES: "10"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_BACKOFF_MULTIPLIER: "2"
```

| Flag | Default | Description |
|------|---------|-------------|
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_ENABLED` | `"true"` | Master toggle for webhook reporting feature |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_URL` | `"https://client-api/v1/webhooks/tempos-transacoes"` | Target webhook endpoint URL |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_BATCH_SIZE` | `"50"` | Number of transaction timing records sent per batch |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_WORKER_COUNT` | `"1"` | Number of concurrent worker goroutines processing batches |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_MAX_CONCURRENT` | `"2"` | Maximum concurrent HTTP requests per worker |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_POLLING_INTERVAL` | `"1s"` | Interval between polling for new batches to send |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_REQUEST_TIMEOUT` | `"5s"` | HTTP request timeout for webhook POST requests |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_MAX_RETRIES` | `"10"` | Maximum retry attempts for failed webhook deliveries |
| `WEBHOOK_REPORT_TEMPOSTRANSACOES_BACKOFF_MULTIPLIER` | `"2"` | Exponential backoff multiplier for retry delays |

**Example: High-throughput webhook configuration**

For environments with high transaction volumes, increase batch size and concurrency:

```yaml
outbound:
  configmap:
    WEBHOOK_REPORT_TEMPOSTRANSACOES_BATCH_SIZE: "200"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_WORKER_COUNT: "3"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_MAX_CONCURRENT: "5"
    WEBHOOK_REPORT_TEMPOSTRANSACOES_REQUEST_TIMEOUT: "10s"
```

**Example: Disable webhook reporting**

For environments without a webhook endpoint:

```yaml
outbound:
  configmap:
    WEBHOOK_REPORT_TEMPOSTRANSACOES_ENABLED: "false"
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.0.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.0.0 -n plugin-br-pix-indirect-btg
```
