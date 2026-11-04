<!-- {% raw %} -->
# Helm Upgrade from v2.0.3 to v2.0.4

## Topics

- **[Fixes](#fixes)**
  - [1. Graceful shutdown window extension](#1-graceful-shutdown-window-extension)
  - [2. Pod label stability](#2-pod-label-stability)
  - [3. ConfigMap and Secret checksum precision](#3-configmap-and-secret-checksum-precision)
  - [4. Rate limiting configuration simplification](#4-rate-limiting-configuration-simplification)
  - [5. Removed configuration keys](#5-removed-configuration-keys)
  - [6. Production environment hardening guard](#6-production-environment-hardening-guard)
  - [7. Chart home URL correction](#7-chart-home-url-correction)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review termination grace period override](#step-1-review-termination-grace-period-override)
  - [Step 2: Verify rate limiting configuration](#step-2-verify-rate-limiting-configuration)
  - [Step 3: Remove deprecated configuration keys](#step-3-remove-deprecated-configuration-keys)
  - [Step 4: Validate production environment requirements](#step-4-validate-production-environment-requirements)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### 1. Graceful shutdown window extension

The default termination grace period has been increased from 80 seconds to 90 seconds to accommodate a longer shutdown sequence in the application.

| Setting | v2.0.3 | v2.0.4 |
|---------|--------|--------|
| Default `terminationGracePeriodSeconds` | `80` | `90` |
| Shutdown ceiling calculation | 80s (30s HTTP + 5s consumer-commit + 30s dispatcher + 10s slack + 5s pre-stop) | 87s (5s pre-stop + 30s HTTP + 5s consumer-commit + 30s dispatcher + 7s runtime-config close + 10s slack) |

**Impact:** The application now requires an additional 7 seconds for runtime configuration cleanup during graceful shutdown. The new default (90s) provides a 3-second buffer above the 87-second drain ceiling to prevent Kubernetes from sending SIGKILL before the application completes its shutdown sequence.

**Configuration:**

If you have explicitly overridden `streamingHub.terminationGracePeriodSeconds` in your values, review whether your custom value is still appropriate:

```yaml
streamingHub:
  terminationGracePeriodSeconds: 90  # New default; adjust if you've tuned shutdown timeouts
```

**New shutdown sequence:**

The application's graceful shutdown now includes:
1. **5s** — Pre-stop delay (allows load balancer deregistration)
2. **30s** — HTTP server drain (`STREAMING_HUB_SHUTDOWN_TIMEOUT`)
3. **5s** — Kafka consumer commit (`STREAMING_HUB_PRE_STOP_DRAIN_TIMEOUT`)
4. **30s** — Webhook dispatcher drain
5. **7s** — Runtime configuration close (new step)
6. **10s** — Slack buffer

**Total:** 87 seconds

> **Important:** If you have tuned `STREAMING_HUB_SHUTDOWN_TIMEOUT` or `STREAMING_HUB_PRE_STOP_DRAIN_TIMEOUT` to values higher than the defaults, recalculate your termination grace period using the formula: `5s (pre-stop) + SHUTDOWN_TIMEOUT + PRE_STOP_DRAIN_TIMEOUT + 30s (dispatcher) + 7s (runtime-config) + 10s (slack)`. Set `streamingHub.terminationGracePeriodSeconds` to AT LEAST this value, plus a 3-5 second buffer.

### 2. Pod label stability

Pod template labels no longer include the `helm.sh/chart` label, preventing unnecessary pod rollouts when only the chart version changes.

**Before (v2.0.3):**

```yaml
# Pod template labels included helm.sh/chart
template:
  metadata:
    labels:
      helm.sh/chart: streaming-hub-2.0.3
      app.kubernetes.io/name: streaming-hub
      app.kubernetes.io/instance: streaming-hub
      app.kubernetes.io/version: "3.1.0"
      app.kubernetes.io/managed-by: Helm
      app.kubernetes.io/component: all
```

**After (v2.0.4):**

```yaml
# Pod template labels exclude helm.sh/chart
template:
  metadata:
    labels:
      app.kubernetes.io/name: streaming-hub
      app.kubernetes.io/instance: streaming-hub
      app.kubernetes.io/version: "3.1.0"
      app.kubernetes.io/managed-by: Helm
      app.kubernetes.io/component: all
```

**Impact:** Future chart version bumps that change no pod spec (e.g., documentation-only releases, values.yaml schema additions) will no longer trigger a rolling restart of all pods. The `helm.sh/chart` label is still present on Deployment, Service, and other top-level resources for inventory tracking, but is excluded from the pod template to improve rollout stability.

> **Note:** This change takes effect on the v2.0.4 upgrade. The upgrade itself will trigger a pod rollout because the pod template labels are changing (removing `helm.sh/chart: streaming-hub-2.0.3`). Subsequent chart upgrades that change only metadata will not roll pods.

**Template changes:**

The chart now uses two label helpers:
- `streaming-hub.labels` — Full label set including `helm.sh/chart` (for Deployment, Service, ConfigMap, Secret)
- `streaming-hub.podLabels` — Pod-only label set excluding `helm.sh/chart` (for pod template)

### 3. ConfigMap and Secret checksum precision

The checksum annotations that trigger pod rollouts on configuration changes now hash only the `data` section of the ConfigMap and Secret, excluding metadata.

**Before (v2.0.3):**

```yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") $ | sha256sum }}
  checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") $ | sha256sum }}
```

**After (v2.0.4):**

```yaml
annotations:
  checksum/config: {{ (include (print $.Template.BasePath "/configmap.yaml") $ | fromYaml).data | toYaml | sha256sum }}
  checksum/secret: {{ (include (print $.Template.BasePath "/secrets.yaml") $ | fromYaml).data | toYaml | sha256sum }}
```

**Impact:** Changes to ConfigMap or Secret metadata (labels, annotations) will no longer trigger a pod rollout. Only changes to the actual configuration data (the `data:` section) will produce a new checksum and restart pods. This prevents unnecessary restarts when, for example, a chart upgrade adds a new label to the ConfigMap but does not change any environment variables.

> **Note:** This is a template-level optimization with no operator configuration. The behavior is automatic.

### 4. Rate limiting configuration simplification

The chart now renders only the three rate limiting environment variables that the application and `lib-commons` actually read, instead of the full ten-key contract.

**Before (v2.0.3):**

```yaml
# ConfigMap included all ten RATE_LIMIT_* keys from lerian-common.rateLimit.env
data:
  RATE_LIMIT_ENABLED: "true"
  RATE_LIMIT_MAX: "100"
  RATE_LIMIT_WINDOW_SEC: "60"
  AGGRESSIVE_RATE_LIMIT_MAX: "50"
  AGGRESSIVE_RATE_LIMIT_WINDOW_SEC: "60"
  RELAXED_RATE_LIMIT_MAX: "200"
  RELAXED_RATE_LIMIT_WINDOW_SEC: "60"
  ALLOW_RATELIMIT_FAIL_OPEN: ""
  RATE_LIMIT_REDIS_TIMEOUT_MS: "500"
  # ... plus STREAMING_HUB_PULL_RATE, _DASHBOARD_RATE, _READ_RATE
```

**After (v2.0.4):**

```yaml
# ConfigMap includes only the three keys the hub reads
data:
  RATE_LIMIT_ENABLED: "true"
  ALLOW_RATELIMIT_FAIL_OPEN: ""
  RATE_LIMIT_REDIS_TIMEOUT_MS: "500"
  # Per-tier allowances remain at STREAMING_HUB_PULL_RATE, _DASHBOARD_RATE, _READ_RATE
```

**Impact:** The seven unused `RATE_LIMIT_*` keys (`RATE_LIMIT_MAX`, `RATE_LIMIT_WINDOW_SEC`, `AGGRESSIVE_*`, `RELAXED_*`) are no longer rendered in the ConfigMap. The application never read these keys; rate limiting is controlled by the three hub-specific variables (`STREAMING_HUB_PULL_RATE`, `STREAMING_HUB_DASHBOARD_RATE`, `STREAMING_HUB_READ_RATE`) plus the three lib-commons switches (`RATE_LIMIT_ENABLED`, `ALLOW_RATELIMIT_FAIL_OPEN`, `RATE_LIMIT_REDIS_TIMEOUT_MS`).

**Configuration:**

The productized rate limiting configuration remains unchanged:

```yaml
streamingHub:
  rateLimit:
    enabled: true
    allowFailOpen: false
    redisTimeoutMs: 500
  configmap:
    STREAMING_HUB_PULL_RATE: "100"
    STREAMING_HUB_DASHBOARD_RATE: "50"
    STREAMING_HUB_READ_RATE: "200"
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.rateLimit.enabled` | `true` | Enable Redis-backed rate limiting |
| `streamingHub.rateLimit.allowFailOpen` | `false` | Allow requests when Redis is unavailable (fail-open mode) |
| `streamingHub.rateLimit.redisTimeoutMs` | `500` | Redis operation timeout in milliseconds |

> **Note:** The values.yaml schema still accepts the seven removed keys (for backward compatibility), but they are silently ignored. If you have set `streamingHub.configmap.RATE_LIMIT_MAX` or similar keys, they will have no effect. Remove them from your values to avoid confusion.

### 5. Removed configuration keys

Four configuration keys have been removed from the ConfigMap because they are no longer read by the application or were deprecated.

| Key | Status | Replacement |
|-----|--------|-------------|
| `STREAMING_HUB_ALLOW_PRIVATE_SINKS` | Removed | None (feature removed from application) |
| `STREAMING_HUB_DISPATCH_CLAIM_BATCH` | Removed | None (dispatcher no longer uses batch claiming) |
| `STREAMING_HUB_DLQ_GROUP` | Removed | None (DLQ consumer group is now hardcoded) |
| `IS_DEVELOPMENT` | Removed | Use `STREAMING_HUB_ENV=local` instead |

**Impact:**

- **`STREAMING_HUB_ALLOW_PRIVATE_SINKS`**: The application no longer supports private sink URLs (RFC 1918 addresses, localhost, link-local). This feature was a development-only bypass and has been removed. If you have set this key to `"true"`, remove it from your values. Attempts to create subscriptions with private sink URLs will now fail at the application layer.

- **`STREAMING_HUB_DISPATCH_CLAIM_BATCH`**: The dispatcher's job-claiming logic has been refactored and no longer uses batch claiming. The key is ignored. If you have tuned this value, remove it from your values.

- **`STREAMING_HUB_DLQ_GROUP`**: The DLQ consumer group name is now hardcoded in the application. The key is ignored. If you have overridden this value, remove it from your values.

- **`IS_DEVELOPMENT`**: This boolean flag has been replaced by the `STREAMING_HUB_ENV` enum. Use `STREAMING_HUB_ENV=local` for development environments instead of `IS_DEVELOPMENT=true`.

**Configuration:**

If your values.yaml includes any of these keys, remove them:

```yaml
streamingHub:
  configmap:
    # Remove these lines:
    # STREAMING_HUB_ALLOW_PRIVATE_SINKS: "true"
    # STREAMING_HUB_DISPATCH_CLAIM_BATCH: "32"
    # STREAMING_HUB_DLQ_GROUP: "my-custom-dlq-group"
    # IS_DEVELOPMENT: "true"
    
    # Use this instead of IS_DEVELOPMENT:
    STREAMING_HUB_ENV: "local"  # or "staging", "production"
```

> **Note:** The values.yaml schema still accepts these keys (for backward compatibility during the upgrade), but they are not rendered in the ConfigMap. The application will not see them.

### 6. Production environment hardening guard

The chart now enforces two security requirements at render time when `STREAMING_HUB_ENV` is set to `production` or `staging`: Kafka TLS must be enabled, and a KEK reference must be configured.

**New validation logic:**

```yaml
# The chart will fail to render if:
# 1. STREAMING_HUB_ENV is "production" or "staging", AND
# 2. STREAMING_HUB_KAFKA_TLS_ENABLED is "false" (or unset), OR
# 3. STREAMING_HUB_KEK_REF is empty (or unset)
```

**Error messages:**

If Kafka TLS is disabled in production/staging:

```
ERROR: STREAMING_HUB_ENV=production requires Kafka TLS. Set streamingHub.configmap.STREAMING_HUB_KAFKA_TLS_ENABLED="true" (and streamingHub.secrets.STREAMING_HUB_KAFKA_CA_CERT for a private CA), or set streamingHub.configmap.STREAMING_HUB_ENV=local for a development install.
```

If KEK reference is missing in production/staging:

```
ERROR: STREAMING_HUB_ENV=production requires a KEK reference. Set streamingHub.configmap.STREAMING_HUB_KEK_REF to the name of the variable that carries the KEK in the Secret, or set streamingHub.configmap.STREAMING_HUB_ENV=local for a development install.
```

**Impact:** Operators can no longer deploy to production or staging environments without encryption at rest (KEK) and encryption in transit (Kafka TLS). This mirrors the application's own boot-time refusal of these configurations, but catches the error earlier (at Helm render time) with a clearer message.

**Configuration:**

For production and staging environments, ensure both requirements are met:

```yaml
streamingHub:
  configmap:
    STREAMING_HUB_ENV: "production"  # or "staging"
    STREAMING_HUB_KAFKA_TLS_ENABLED: "true"
    STREAMING_HUB_KEK_SOURCE: "env"
    STREAMING_HUB_KEK_REF: "STREAMING_HUB_PROD_KEK"  # Name of the Secret key
  secrets:
    STREAMING_HUB_KAFKA_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
    STREAMING_HUB_PROD_KEK: "base64-encoded-kek-material"
```

For local development environments, set `STREAMING_HUB_ENV=local` to bypass the guard:

```yaml
streamingHub:
  configmap:
    STREAMING_HUB_ENV: "local"
    STREAMING_HUB_KAFKA_TLS_ENABLED: "false"  # Allowed in local mode
    STREAMING_HUB_KEK_REF: ""  # Allowed in local mode
```

> **Important:** The guard evaluates the **effective** value of each variable, respecting `streamingHub.extraEnvVars` overrides. If you set `STREAMING_HUB_ENV` via `extraEnvVars`, the guard will use that value instead of the ConfigMap value.

| Environment Variable | Required in production/staging | Default | Description |
|---------------------|-------------------------------|---------|-------------|
| `STREAMING_HUB_ENV` | (defines requirement) | `production` | Environment mode: `local`, `staging`, or `production` |
| `STREAMING_HUB_KAFKA_TLS_ENABLED` | `"true"` | `"false"` | Enable Kafka TLS (required in production/staging) |
| `STREAMING_HUB_KEK_REF` | Non-empty string | `""` | Name of the Secret key containing the KEK (required in production/staging) |

### 7. Chart home URL correction

The `home` field in `Chart.yaml` has been updated to point to the chart's location in the monorepo instead of the application repository.

| Setting | v2.0.3 | v2.0.4 |
|---------|--------|--------|
| Chart home URL | `https://github.com/LerianStudio/streaming-hub` | `https://github.com/LerianStudio/helm/tree/main/charts/streaming-hub` |

**Impact:** This is a metadata-only change with no operational impact. The `home` URL now correctly points to the chart's source in the `helm` repository, while the application repository remains listed in the `sources` array.

---

## Migration Steps

### Step 1: Review termination grace period override

If you have explicitly set `streamingHub.terminationGracePeriodSeconds` in your values, verify that it is still appropriate for the new shutdown sequence.

**Check your current override:**

```bash
helm get values streaming-hub -n streaming-hub | grep terminationGracePeriodSeconds
```

**If you have NOT overridden the default:**

No action required. The chart will automatically use the new default (90 seconds).

**If you HAVE overridden the default:**

Recalculate your termination grace period using the new formula:

```
terminationGracePeriodSeconds = 5s (pre-stop)
                              + STREAMING_HUB_SHUTDOWN_TIMEOUT (default 30s)
                              + STREAMING_HUB_PRE_STOP_DRAIN_TIMEOUT (default 5s)
                              + 30s (dispatcher)
                              + 7s (runtime-config close)
                              + 10s (slack)
                              + 3-5s (buffer)
```

For the default timeout values, this is `5 + 30 + 5 + 30 + 7 + 10 + 3 = 90` seconds.

If you have tuned `STREAMING_HUB_SHUTDOWN_TIMEOUT` or `STREAMING_HUB_PRE_STOP_DRAIN_TIMEOUT` to higher values, update your override:

```yaml
streamingHub:
  terminationGracePeriodSeconds: 120  # Example: if you've set SHUTDOWN_TIMEOUT=60s
  configmap:
    STREAMING_HUB_SHUTDOWN_TIMEOUT: "60s"
```

### Step 2: Verify rate limiting configuration

If you have set any of the seven removed `RATE_LIMIT_*` keys in your values, remove them.

**Check for removed keys:**

```bash
helm get values streaming-hub -n streaming-hub | grep -E 'RATE_LIMIT_(MAX|WINDOW_SEC)|AGGRESSIVE_|RELAXED_'
```

**If any of these keys are present, remove them:**

```yaml
streamingHub:
  configmap:
    # Remove these lines:
    # RATE_LIMIT_MAX: "100"
    # RATE_LIMIT_WINDOW_SEC: "60"
    # AGGRESSIVE_RATE_LIMIT_MAX: "50"
    # AGGRESSIVE_RATE_LIMIT_WINDOW_SEC: "60"
    # RELAXED_RATE_LIMIT_MAX: "200"
    # RELAXED_RATE_LIMIT_WINDOW_SEC: "60"
    
    # Keep only these three lib-commons keys:
    RATE_LIMIT_ENABLED: "true"
    ALLOW_RATELIMIT_FAIL_OPEN: "false"
    RATE_LIMIT_REDIS_TIMEOUT_MS: "500"
    
    # And the three hub-specific tier allowances:
    STREAMING_HUB_PULL_RATE: "100"
    STREAMING_HUB_DASHBOARD_RATE: "50"
    STREAMING_HUB_READ_RATE: "200"
```

Or use the productized `streamingHub.rateLimit` block:

```yaml
streamingHub:
  rateLimit:
    enabled: true
    allowFailOpen: false
    redisTimeoutMs: 500
  configmap:
    STREAMING_HUB_PULL_RATE: "100"
    STREAMING_HUB_DASHBOARD_RATE: "50"
    STREAMING_HUB_READ_RATE: "200"
```

### Step 3: Remove deprecated configuration keys

If you have set any of the four removed keys (`STREAMING_HUB_ALLOW_PRIVATE_SINKS`, `STREAMING_HUB_DISPATCH_CLAIM_BATCH`, `STREAMING_HUB_DLQ_GROUP`, `IS_DEVELOPMENT`) in your values, remove them.

**Check for removed keys:**

```bash
helm get values streaming-hub -n streaming-hub | grep -E 'ALLOW_PRIVATE_SINKS|DISPATCH_CLAIM_BATCH|DLQ_GROUP|IS_DEVELOPMENT'
```

**If any of these keys are present, remove them:**

```yaml
streamingHub:
  configmap:
    # Remove these lines:
    # STREAMING_HUB_ALLOW_PRIVATE_SINKS: "true"
    # STREAMING_HUB_DISPATCH_CLAIM_BATCH: "32"
    # STREAMING_HUB_DLQ_GROUP: "my-custom-dlq-group"
    # IS_DEVELOPMENT: "true"
    
    # If you were using IS_DEVELOPMENT, replace with:
    STREAMING_HUB_ENV: "local"  # or "staging", "production"
```

### Step 4: Validate production environment requirements

If you are deploying to a production or staging environment (`STREAMING_HUB_ENV=production` or `STREAMING_HUB_ENV=staging`), ensure that Kafka TLS and KEK are configured.

**Check your current environment mode:**

```bash
helm get values streaming-hub -n streaming-hub | grep STREAMING_HUB_ENV
```

**If `STREAMING_HUB_ENV` is `production` or `staging`, verify these requirements:**

1. **Kafka TLS must be enabled:**

```yaml
streamingHub:
  configmap:
    STREAMING_HUB_KAFKA_TLS_ENABLED: "true"
  secrets:
    STREAMING_HUB_KAFKA_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
```

2. **KEK reference must be set:**

```yaml
streamingHub:
  configmap:
    STREAMING_HUB_KEK_SOURCE: "env"
    STREAMING_HUB_KEK_REF: "STREAMING_HUB_PROD_KEK"
  secrets:
    STREAMING_HUB_PROD_KEK: "base64-encoded-kek-material"
```

**If either requirement is missing, the upgrade will fail with a clear error message.** Fix the configuration before proceeding.

**For local development environments, explicitly set `STREAMING_HUB_ENV=local` to bypass the guard:**

```yaml
streamingHub:
  configmap:
    STREAMING_HUB_ENV: "local"
```

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 2.0.4 -n streaming-hub
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 2.0.4 -n streaming-hub
```
<!-- {% endraw %} -->
