<!-- {% raw %} -->
# Helm Upgrade from v5.0.0 to v5.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. PostgreSQL TLS Configuration](#1-postgresql-tls-configuration)
  - [2. Outbound HTTP Client Configuration](#2-outbound-http-client-configuration)
  - [3. Outbound Webhook Health Monitoring](#3-outbound-webhook-health-monitoring)
  - [4. Enhanced Installation Notes](#4-enhanced-installation-notes)
  - [5. Template Cleanup](#5-template-cleanup)
- **[Configuration Reference](#configuration-reference)**
  - [PostgreSQL TLS Settings](#postgresql-tls-settings)
  - [Outbound HTTP Client Settings](#outbound-http-client-settings)
  - [Outbound Webhook Monitoring Settings](#outbound-webhook-monitoring-settings)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This minor release adds PostgreSQL TLS configuration support, enhanced HTTP client tuning for webhook delivery, and improved operational visibility through enhanced installation notes. The application version remains at `1.11.0` across all components.

The expected upgrade path is an in-place Helm upgrade. All new configuration fields have safe defaults that maintain backward compatibility with existing deployments. Operators should review the new PostgreSQL TLS settings and consider enabling encryption for production environments.

| Component | v5.0.0 | v5.1.0 |
|-----------|--------|--------|
| Chart version | `5.0.0` | `5.1.0` |
| App version | `1.11.0` | `1.11.0` |
| Components | 5 (pix, inbound, outbound, reconciliation, schedule) | 5 (pix, inbound, outbound, reconciliation, schedule) |

## Features

### 1. PostgreSQL TLS Configuration

All four service components that connect to PostgreSQL (`pix`, `inbound`, `outbound`, `reconciliation`) now support explicit TLS mode configuration through the `DB_SSL_MODE` environment variable.

**What changed:**

A new `DB_SSL_MODE` configuration field has been added to each component's configmap block:

| Setting | v5.0.0 | v5.1.0 |
|---------|--------|--------|
| `pix.configmap.DB_SSL_MODE` | (not present) | `"disable"` |
| `inbound.configmap.DB_SSL_MODE` | (not present) | `"disable"` |
| `outbound.configmap.DB_SSL_MODE` | (not present) | `"disable"` |
| `reconciliation.configmap.DB_SSL_MODE` | (not present) | `"disable"` |

**Why it matters:**

PostgreSQL TLS mode controls whether database connections are encrypted. The default value `"disable"` maintains backward compatibility with existing deployments, but operators should enable TLS for production environments to protect database credentials and Pix data in transit.

**Operational impact:**

The upgrade will add the `DB_SSL_MODE` environment variable to all four component deployments with the default value `"disable"`. This maintains existing behavior—no connections will be encrypted unless you explicitly configure TLS.

**Valid TLS modes:**

PostgreSQL supports six TLS modes with varying levels of security:

| Mode | Encryption | Certificate Validation | Description |
|------|------------|------------------------|-------------|
| `disable` | No | No | No TLS encryption (default) |
| `allow` | Opportunistic | No | Try TLS, fall back to plaintext |
| `prefer` | Opportunistic | No | Prefer TLS, fall back to plaintext |
| `require` | Yes | No | Require TLS, no certificate validation |
| `verify-ca` | Yes | CA only | Require TLS, validate CA certificate |
| `verify-full` | Yes | CA + hostname | Require TLS, validate CA and hostname |

> **Important:** Only `require`, `verify-ca`, and `verify-full` guarantee encrypted connections. The `disable`, `allow`, and `prefer` modes may transmit data in plaintext.

**Example configuration for production:**

```yaml
pix:
  configmap:
    DB_SSL_MODE: "require"

inbound:
  configmap:
    DB_SSL_MODE: "require"

outbound:
  configmap:
    DB_SSL_MODE: "require"

reconciliation:
  configmap:
    DB_SSL_MODE: "require"
```

> **Note:** If you set `DB_SSL_MODE` to `require` or stricter, you must also set `ALLOW_INSECURE_TLS: "false"` to prevent the component from starting if any datastore connection (PostgreSQL, MongoDB, or Valkey) cannot be encrypted. See [Migration Steps](#migration-steps) for details.

### 2. Outbound HTTP Client Configuration

The `outbound` worker now exposes fine-grained HTTP client configuration for webhook delivery transport tuning.

**What changed:**

Six new environment variables control HTTP client behavior for webhook delivery:

| Setting | v5.0.0 | v5.1.0 |
|---------|--------|--------|
| `outbound.configmap.HTTP_IDLE_CONN_TIMEOUT` | (not present) | `"90s"` |
| `outbound.configmap.HTTP_DIAL_TIMEOUT` | (not present) | `"5s"` |
| `outbound.configmap.HTTP_KEEP_ALIVE` | (not present) | `"30s"` |
| `outbound.configmap.HTTP_TLS_HANDSHAKE_TIMEOUT` | (not present) | `"5s"` |
| `outbound.configmap.HTTP_RESPONSE_HEADER_TIMEOUT` | (not present) | `"0s"` |
| `outbound.configmap.HTTP_EXPECT_CONTINUE_TIMEOUT` | (not present) | `"1s"` |

**Why it matters:**

These settings allow operators to tune HTTP client behavior for webhook delivery based on network conditions, target endpoint characteristics, and throughput requirements. The defaults are conservative and suitable for most deployments.

**Operational impact:**

The upgrade will add these environment variables to the `outbound` deployment with the default values shown above. Existing webhook delivery behavior will not change unless you customize these settings.

**HTTP client tuning guide:**

| Flag | Default | Description | When to adjust |
|------|---------|-------------|----------------|
| `HTTP_IDLE_CONN_TIMEOUT` | `"90s"` | Maximum time an idle connection remains in the pool | Increase for long-lived connections; decrease to free resources faster |
| `HTTP_DIAL_TIMEOUT` | `"5s"` | Maximum time to establish a TCP connection | Increase for slow networks; decrease to fail fast |
| `HTTP_KEEP_ALIVE` | `"30s"` | TCP keep-alive probe interval | Match your network's keep-alive requirements |
| `HTTP_TLS_HANDSHAKE_TIMEOUT` | `"5s"` | Maximum time for TLS handshake | Increase for slow TLS endpoints |
| `HTTP_RESPONSE_HEADER_TIMEOUT` | `"0s"` | Maximum time to read response headers (0 = no separate limit) | Set to enforce header deadlines independent of `WEBHOOK_WORKER_TIMEOUT` |
| `HTTP_EXPECT_CONTINUE_TIMEOUT` | `"1s"` | Maximum time to wait for 100-Continue response | Adjust based on target endpoint behavior |

> **Note:** The `HTTP_RESPONSE_HEADER_TIMEOUT` default of `"0s"` means no separate header deadline is enforced. The overall webhook delivery timeout is controlled by `WEBHOOK_WORKER_TIMEOUT` (default `30s`), which bounds the entire HTTP request including headers and body.

**Example configuration for high-throughput environments:**

```yaml
outbound:
  configmap:
    HTTP_IDLE_CONN_TIMEOUT: "120s"
    HTTP_DIAL_TIMEOUT: "3s"
    HTTP_KEEP_ALIVE: "60s"
    HTTP_TLS_HANDSHAKE_TIMEOUT: "3s"
    HTTP_RESPONSE_HEADER_TIMEOUT: "10s"
```

**Example configuration for unreliable networks:**

```yaml
outbound:
  configmap:
    HTTP_DIAL_TIMEOUT: "10s"
    HTTP_TLS_HANDSHAKE_TIMEOUT: "10s"
    HTTP_RESPONSE_HEADER_TIMEOUT: "15s"
```

### 3. Outbound Webhook Health Monitoring

The `outbound` worker now includes configuration for webhook endpoint health monitoring and recovery.

**What changed:**

Three new environment variables control webhook health monitoring:

| Setting | v5.0.0 | v5.1.0 |
|---------|--------|--------|
| `outbound.configmap.WEBHOOK_HEALTH_CHECK_INTERVAL` | (not present) | `"30s"` |
| `outbound.configmap.WEBHOOK_RECOVERY_INTERVAL` | (not present) | `"5m"` |
| `outbound.configmap.WEBHOOK_SLOW_REQUEST_THRESHOLD` | (not present) | `"3s"` |

**Why it matters:**

These settings enable the outbound worker to monitor webhook endpoint health, detect slow or failing endpoints, and adjust delivery behavior accordingly. This improves reliability and observability for webhook delivery.

**Operational impact:**

The upgrade will add these environment variables to the `outbound` deployment with the default values shown above. The worker will begin monitoring webhook endpoint health using these thresholds.

**Health monitoring configuration:**

| Flag | Default | Description |
|------|---------|-------------|
| `WEBHOOK_HEALTH_CHECK_INTERVAL` | `"30s"` | Interval for checking webhook endpoint health |
| `WEBHOOK_RECOVERY_INTERVAL` | `"5m"` | Interval for attempting recovery of unhealthy endpoints |
| `WEBHOOK_SLOW_REQUEST_THRESHOLD` | `"3s"` | Threshold for considering a webhook request slow |

**Example configuration for aggressive monitoring:**

```yaml
outbound:
  configmap:
    WEBHOOK_HEALTH_CHECK_INTERVAL: "15s"
    WEBHOOK_RECOVERY_INTERVAL: "2m"
    WEBHOOK_SLOW_REQUEST_THRESHOLD: "1s"
```

**Example configuration for relaxed monitoring:**

```yaml
outbound:
  configmap:
    WEBHOOK_HEALTH_CHECK_INTERVAL: "60s"
    WEBHOOK_RECOVERY_INTERVAL: "10m"
    WEBHOOK_SLOW_REQUEST_THRESHOLD: "5s"
```

### 4. Enhanced Installation Notes

The Helm chart now generates enhanced installation notes (NOTES.txt) that provide detailed information about database configuration, TLS settings, and security warnings.

**What changed:**

The installation notes template has been significantly enhanced to:

- Display actual database connection details from rendered ConfigMaps
- Show whether each datastore (PostgreSQL, MongoDB, Valkey) is bundled or external
- Generate specific TLS configuration warnings for external datastores
- Provide actionable remediation steps for insecure configurations

**Before (v5.0.0):**

```yaml
💾 Database Information:

{{- if .Values.postgresql.enabled }}
  PostgreSQL (bundled):
  - Host: plugin-br-pix-indirect-btg-postgresql.{{ .Release.Namespace }}.svc.cluster.local
  - Port: 5432
  - Database: {{ .Values.postgresql.auth.database }}
  - User: {{ .Values.postgresql.auth.username }}
  
  ⚠️  NOTE: Bundled PostgreSQL is for development/testing only.
      For production, use external managed PostgreSQL.
{{- end }}
```

**After (v5.1.0):**

```yaml
💾 Database Information:
{{- $pix := include (printf "%s/pix/configmap.yaml" .Template.BasePath) . | fromYaml }}
{{- $pgBundled := eq (include "plugin-br-pix-indirect-btg.postgresInternal" .) "true" }}
{{- $mongoBundled := eq (include "plugin-br-pix-indirect-btg.mongoInternal" .) "true" }}

  PostgreSQL ({{ ternary "bundled" "external" $pgBundled }}):
  - Host: {{ $pix.data.DB_HOST }}
  - Port: {{ $pix.data.DB_PORT }}
  - Database: {{ $pix.data.DB_NAME }}
  - User: {{ $pix.data.DB_USER }}
{{- if $pgBundled }}

  ⚠️  NOTE: Bundled PostgreSQL is for development/testing only.
      For production, use external managed PostgreSQL.
{{- end }}
```

**Why it matters:**

The enhanced notes provide operators with immediate visibility into their deployment configuration and highlight security issues that require attention. This reduces the risk of accidentally deploying with insecure settings in production.

**Operational impact:**

After upgrading, the `helm upgrade` output will display enhanced installation notes. The notes will include:

1. **Actual connection details:** Shows the real database hosts, ports, and names from your configuration
2. **Bundled vs. external indicators:** Clearly marks which datastores are bundled vs. external
3. **TLS warnings:** Generates specific warnings if external datastores are not encrypted
4. **Remediation steps:** Provides exact configuration changes needed to enable TLS

**Example warning output for unencrypted PostgreSQL:**

```
⚠️  WARNING: external datastore connections are NOT encrypted

  The components below reach PostgreSQL or Valkey without TLS, so credentials
  and Pix data cross the network in plaintext. To require TLS, set:
    pix.configmap.DB_SSL_MODE: "require"
    pix.configmap.ALLOW_INSECURE_TLS: "false"
    inbound.configmap.DB_SSL_MODE: "require"
    inbound.configmap.ALLOW_INSECURE_TLS: "false"
    outbound.configmap.DB_SSL_MODE: "require"
    outbound.configmap.ALLOW_INSECURE_TLS: "false"
    reconciliation.configmap.DB_SSL_MODE: "require"
    reconciliation.configmap.ALLOW_INSECURE_TLS: "false"

  ALLOW_INSECURE_TLS "false" makes the component refuse to start on any
  plaintext datastore, bundled ones included.
```

**Example warning output for unencrypted MongoDB:**

```
  pix reaches the external MongoDB without TLS. No value in this chart
  encrypts that link; pix.configmap.MONGO_TLS only changes what /readyz
  and the SaaS TLS check report.
```

> **Important:** The MongoDB TLS warning indicates a limitation in the current chart version. The `MONGO_TLS` configuration flag does not actually encrypt the MongoDB connection—it only affects health check reporting. If you require encrypted MongoDB connections, you must configure TLS at the MongoDB driver level or use a MongoDB proxy that enforces TLS.

### 5. Template Cleanup

The chart templates have been cleaned up to remove unused validation helpers and warning annotations.

**What changed:**

The following template helpers have been removed from `_helpers.tpl`:

- `plugin-br-pix-indirect-btg.validatePostgreSQL` (empty validation function)
- `plugin-br-pix-indirect-btg.validateMongoDB` (empty validation function)
- `plugin-br-pix-indirect-btg.secretWarnings` (warning annotation generator)

The `pix/deployment.yaml` template no longer calls the removed validation helpers:

**Before (v5.0.0):**

```yaml
{{- include "plugin-br-pix-indirect-btg.validateRequired" . }}
{{- include "plugin-br-pix-indirect-btg.validatePostgreSQL" . }}
{{- include "plugin-br-pix-indirect-btg.validateMongoDB" . }}
apiVersion: apps/v1
kind: Deployment
```

**After (v5.1.0):**

```yaml
{{- include "plugin-br-pix-indirect-btg.validateRequired" . }}
apiVersion: apps/v1
kind: Deployment
```

**Why it matters:**

These helpers were placeholders that never implemented actual validation logic. Removing them simplifies the template codebase without affecting functionality.

**Operational impact:**

No operational impact. The removed helpers were empty functions that performed no validation. The enhanced installation notes (see [Feature 4](#4-enhanced-installation-notes)) now provide better security warnings than the removed annotation system.

## Configuration Reference

### PostgreSQL TLS Settings

PostgreSQL TLS mode is configured through the `DB_SSL_MODE` environment variable in each component's configmap block.

| Flag | Default | Valid Values | Description |
|------|---------|--------------|-------------|
| `DB_SSL_MODE` | `"disable"` | `disable`, `allow`, `prefer`, `require`, `verify-ca`, `verify-full` | PostgreSQL TLS mode |

**TLS mode security levels:**

| Mode | Encrypted | Safe for Production |
|------|-----------|---------------------|
| `disable` | No | ❌ No |
| `allow` | Maybe | ❌ No |
| `prefer` | Maybe | ❌ No |
| `require` | Yes | ✅ Yes |
| `verify-ca` | Yes | ✅ Yes |
| `verify-full` | Yes | ✅ Yes (recommended) |

**Example configuration:**

```yaml
pix:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

inbound:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

outbound:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

reconciliation:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"
```

> **Note:** Setting `ALLOW_INSECURE_TLS: "false"` makes the component refuse to start if any datastore connection (PostgreSQL, MongoDB, or Valkey) cannot be encrypted. This provides defense-in-depth by preventing accidental plaintext connections.

### Outbound HTTP Client Settings

HTTP client behavior for webhook delivery is configured through the `outbound` component's configmap block.

| Flag | Default | Description |
|------|---------|-------------|
| `HTTP_IDLE_CONN_TIMEOUT` | `"90s"` | Maximum time an idle connection remains in the pool |
| `HTTP_DIAL_TIMEOUT` | `"5s"` | Maximum time to establish a TCP connection |
| `HTTP_KEEP_ALIVE` | `"30s"` | TCP keep-alive probe interval |
| `HTTP_TLS_HANDSHAKE_TIMEOUT` | `"5s"` | Maximum time for TLS handshake |
| `HTTP_RESPONSE_HEADER_TIMEOUT` | `"0s"` | Maximum time to read response headers (0 = no separate limit) |
| `HTTP_EXPECT_CONTINUE_TIMEOUT` | `"1s"` | Maximum time to wait for 100-Continue response |

**Example configuration:**

```yaml
outbound:
  configmap:
    HTTP_IDLE_CONN_TIMEOUT: "120s"
    HTTP_DIAL_TIMEOUT: "5s"
    HTTP_KEEP_ALIVE: "30s"
    HTTP_TLS_HANDSHAKE_TIMEOUT: "5s"
    HTTP_RESPONSE_HEADER_TIMEOUT: "10s"
    HTTP_EXPECT_CONTINUE_TIMEOUT: "1s"
```

### Outbound Webhook Monitoring Settings

Webhook endpoint health monitoring is configured through the `outbound` component's configmap block.

| Flag | Default | Description |
|------|---------|-------------|
| `WEBHOOK_HEALTH_CHECK_INTERVAL` | `"30s"` | Interval for checking webhook endpoint health |
| `WEBHOOK_RECOVERY_INTERVAL` | `"5m"` | Interval for attempting recovery of unhealthy endpoints |
| `WEBHOOK_SLOW_REQUEST_THRESHOLD` | `"3s"` | Threshold for considering a webhook request slow |

**Example configuration:**

```yaml
outbound:
  configmap:
    WEBHOOK_HEALTH_CHECK_INTERVAL: "30s"
    WEBHOOK_RECOVERY_INTERVAL: "5m"
    WEBHOOK_SLOW_REQUEST_THRESHOLD: "3s"
```

## Migration Steps

This upgrade requires no mandatory configuration changes. All new fields have safe defaults that maintain backward compatibility. However, operators should review and configure PostgreSQL TLS for production environments.

### Recommended migration process

**1. Review current database configuration:**

Check whether you are using bundled or external datastores:

```bash
helm get values plugin-br-pix-indirect-btg -n plugin-br-pix-indirect-btg
```

Look for:
- `postgresql.enabled: true` (bundled PostgreSQL)
- `mongodb.enabled: true` (bundled MongoDB)
- `valkey.enabled: true` (bundled Valkey)

**2. Preview the upgrade:**

Use the helm-diff plugin to see what will change:

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.1.0 -n plugin-br-pix-indirect-btg
```

**3. Decide on TLS configuration:**

#### Option 1: Keep existing behavior (no TLS)

If you are using bundled datastores or your external datastores do not support TLS, no configuration changes are required. The upgrade will maintain existing behavior with `DB_SSL_MODE: "disable"`.

#### Option 2: Enable PostgreSQL TLS (recommended for production)

If you are using external PostgreSQL with TLS support, enable TLS mode:

```yaml
pix:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

inbound:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

outbound:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

reconciliation:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"
```

> **Important:** Before setting `ALLOW_INSECURE_TLS: "false"`, ensure all your datastores support TLS. The component will refuse to start if any datastore connection cannot be encrypted.

**4. Run the upgrade:**

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.1.0 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

**5. Review installation notes:**

The upgrade output will display enhanced installation notes with database configuration details and security warnings. Review these carefully:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.1.0 -n plugin-br-pix-indirect-btg -f your-values.yaml | grep -A 50 "Database Information"
```

**6. Verify deployment health:**

Check that all pods are running and healthy:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg
```

**7. Verify TLS configuration (if enabled):**

If you enabled PostgreSQL TLS, verify that connections are encrypted by checking the logs:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/name=plugin-br-pix-indirect-btg-pix --tail=50 | grep -i tls
```

Look for log messages indicating successful TLS connections.

### Optional: Tune HTTP client settings

If you experience webhook delivery issues or want to optimize for your network environment, customize the HTTP client settings:

```yaml
outbound:
  configmap:
    HTTP_DIAL_TIMEOUT: "10s"
    HTTP_TLS_HANDSHAKE_TIMEOUT: "10s"
    HTTP_RESPONSE_HEADER_TIMEOUT: "15s"
```

Apply the changes:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.1.0 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

### Optional: Adjust webhook health monitoring

If you want more aggressive or relaxed health monitoring, customize the monitoring settings:

```yaml
outbound:
  configmap:
    WEBHOOK_HEALTH_CHECK_INTERVAL: "15s"
    WEBHOOK_RECOVERY_INTERVAL: "2m"
    WEBHOOK_SLOW_REQUEST_THRESHOLD: "1s"
```

Apply the changes:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.1.0 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.1.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.1.0 -n plugin-br-pix-indirect-btg
```
<!-- {% endraw %} -->
