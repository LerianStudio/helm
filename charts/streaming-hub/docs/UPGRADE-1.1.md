# Helm Upgrade from v1.0.1 to v1.1.0

## Topics

- **[Features](#features)**
  - [1. Redis/Valkey integration for rate limiting](#1-redisvalkey-integration-for-rate-limiting)
  - [2. Three-tier rate limiting contract](#2-three-tier-rate-limiting-contract)
  - [3. Fail-open rate limiter posture](#3-fail-open-rate-limiter-posture)
- **[Configuration Reference](#configuration-reference)**
  - [Global datastores](#global-datastores)
  - [StreamingHub datastores](#streaminghub-datastores)
  - [Rate limit configuration](#rate-limit-configuration)
  - [Secrets](#secrets)
  - [New environment variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review rate limiting requirements](#step-1-review-rate-limiting-requirements)
  - [Step 2: Provision Redis/Valkey (optional)](#step-2-provision-redisvalkey-optional)
  - [Step 3: Configure Redis connection (optional)](#step-3-configure-redis-connection-optional)
  - [Step 4: Configure rate limits (optional)](#step-4-configure-rate-limits-optional)
  - [Step 5: Set Redis password (optional)](#step-5-set-redis-password-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Features

### 1. Redis/Valkey integration for rate limiting

The chart now supports an external Redis or Valkey instance for control-plane rate limiting. This is a **new optional feature** — the chart remains fully functional without Redis configured.

| Setting | v1.0.1 | v1.1.0 |
|---------|--------|--------|
| Redis datastore mask | Not available | `streamingHub.datastores.redis` |
| Redis connection fields | Not available | `host`, `tls`, `caCert` |
| Redis password secret | Not available | `secrets.STREAMING_HUB_REDIS_PASSWORD` |

**Impact:** When no Redis address is configured, the application builds a pass-through limiter and serves all requests unlimited. This is a **silent no-op** — the control plane does not fail or log errors. Rate limiting is entirely opt-in.

**Configuration:**

```yaml
streamingHub:
  datastores:
    redis:
      host: "valkey.internal:6379"
      tls: "true"
      caCert: ""
  secrets:
    STREAMING_HUB_REDIS_PASSWORD: "your-redis-password"
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.datastores.redis.host` | `""` | Full Redis address (host:port) for rate limiter |
| `streamingHub.datastores.redis.tls` | `"true"` | Enable TLS for Redis connection |
| `streamingHub.datastores.redis.caCert` | `""` | Base64-encoded PEM CA bundle (optional, trusts system roots when empty) |

> **Note:** The Redis connection is **separate** from the multi-tenant contract. The hub reads tenant credentials from AWS Secrets Manager and does not use a tenant-registry Redis (`MULTI_TENANT_REDIS_*` remains unset). The `streamingHub.datastores.redis` connection is used **only** for control-plane rate limiting.

**New environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAMING_HUB_REDIS_ADDRESS` | `""` | Redis host:port (empty disables rate limiting) |
| `STREAMING_HUB_REDIS_TLS` | `"true"` | Enable TLS for Redis connection |
| `STREAMING_HUB_REDIS_CA_CERT` | `""` | Base64-encoded PEM CA bundle for Redis TLS |
| `STREAMING_HUB_REDIS_PASSWORD` | `""` | Redis AUTH password (Secret, emit-when-set) |

### 2. Three-tier rate limiting contract

The chart now exposes the `lib-commons` three-tier rate-limit contract, controlled by the `streamingHub.rateLimit` block.

**Configuration:**

```yaml
streamingHub:
  rateLimit:
    enabled: "true"
    allowDisabled: "false"
    allowFailOpen: "true"
    max: "500"
    windowSec: "60"
    aggressiveMax: "100"
    aggressiveWindowSec: "60"
    relaxedMax: "1000"
    relaxedWindowSec: "60"
    redisTimeoutMs: "500"
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.rateLimit.enabled` | `"true"` | Enable rate limiting (requires Redis address) |
| `streamingHub.rateLimit.allowDisabled` | `"false"` | Permit runtime disable via per-request header |
| `streamingHub.rateLimit.allowFailOpen` | `"false"` | Permit fail-open when Redis is unreachable (see below) |
| `streamingHub.rateLimit.max` | `"500"` | Default tier: max requests per window |
| `streamingHub.rateLimit.windowSec` | `"60"` | Default tier: window duration in seconds |
| `streamingHub.rateLimit.aggressiveMax` | `"100"` | Aggressive tier: max requests per window |
| `streamingHub.rateLimit.aggressiveWindowSec` | `"60"` | Aggressive tier: window duration in seconds |
| `streamingHub.rateLimit.relaxedMax` | `"1000"` | Relaxed tier: max requests per window |
| `streamingHub.rateLimit.relaxedWindowSec` | `"60"` | Relaxed tier: window duration in seconds |
| `streamingHub.rateLimit.redisTimeoutMs` | `"500"` | Redis operation timeout in milliseconds |

> **Important:** The chart ships with **empty** `streamingHub.rateLimit` by default, so the helper's own defaults apply (enabled "true", max 500/60s, aggressive 100/60s, relaxed 1000/60s, Redis timeout 500ms). Any `configmap.<NATIVE_KEY>` override still wins over these typed fields.

**New environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `RATE_LIMIT_ENABLED` | `"true"` | Enable rate limiting (requires Redis address) |
| `ALLOW_RATELIMIT_DISABLED` | `"false"` | Permit runtime disable via per-request header |
| `ALLOW_RATELIMIT_FAIL_OPEN` | `"false"` | Permit fail-open when Redis is unreachable |
| `RATE_LIMIT_MAX` | `"500"` | Default tier: max requests per window |
| `RATE_LIMIT_WINDOW_SEC` | `"60"` | Default tier: window duration in seconds |
| `AGGRESSIVE_RATE_LIMIT_MAX` | `"100"` | Aggressive tier: max requests per window |
| `AGGRESSIVE_RATE_LIMIT_WINDOW_SEC` | `"60"` | Aggressive tier: window duration in seconds |
| `RELAXED_RATE_LIMIT_MAX` | `"1000"` | Relaxed tier: max requests per window |
| `RELAXED_RATE_LIMIT_WINDOW_SEC` | `"60"` | Relaxed tier: window duration in seconds |
| `RATE_LIMIT_REDIS_TIMEOUT_MS` | `"500"` | Redis operation timeout in milliseconds |

> **Note:** These environment variables land **ahead** of the application release that reads them. No streaming-hub branch reads `STREAMING_HUB_REDIS_ADDRESS` as of app v1.7.0, so on the current appVersion these keys are inert. They replace **nothing** — in particular not `STREAMING_HUB_PULL_RATE` / `_BURST`, which are the app's own inbound pull gate and remain unchanged.

### 3. Fail-open rate limiter posture

The chart now ships with `streamingHub.rateLimit.allowFailOpen: "true"` as the **default** fail-open posture.

| Setting | v1.0.1 | v1.1.0 |
|---------|--------|--------|
| Fail-open default | Not available | `allowFailOpen: "true"` |
| lib-commons default | Not available | Fail-closed (forbids fail-open) |

**Impact:** When Redis is unreachable, the rate limiter **allows** the request instead of refusing it. This means a Redis outage degrades enforcement rather than taking the control plane down. This is the hub's **intended posture** and is a deliberate security trade-off.

**Configuration:**

```yaml
streamingHub:
  rateLimit:
    allowFailOpen: "true"
```

> **Warning:** `lib-commons` classifies fail-open as a **security bypass** and logs it as one (`commons/net/http/ratelimit/middleware.go`). Setting `allowFailOpen: "true"` makes an unreachable limiter ALLOW the request instead of refusing it. Unset this field (or set it to `"false"`) for fail-**closed** behavior, where requests are refused when the limiter is unreachable.

---

## Configuration Reference

### Global datastores

The global `datastores` block now supports a `redis` type for shared Redis/Valkey configuration.

```yaml
global:
  datastores:
    redis:
      host: "valkey.internal:6379"
      tls: "true"
      caCert: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.datastores.redis.host` | `""` | Full Redis address (host:port) |
| `global.datastores.redis.tls` | `"true"` | Enable TLS for Redis connection |
| `global.datastores.redis.caCert` | `""` | Base64-encoded PEM CA bundle (optional) |

> **Note:** `global.datastores.redis` is the **shared tier**. `streamingHub.datastores.redis` overrides it for this component only. The `configmap.<NATIVE_KEY>` override still wins over both.

### StreamingHub datastores

The `streamingHub.datastores` block now includes a `redis` mask for component-specific Redis configuration.

**Before (v1.0.1):**

```yaml
streamingHub:
  datastores: {}
```

**After (v1.1.0):**

```yaml
streamingHub:
  datastores:
    postgres:
      host: "pg.internal"
      port: "5432"
      user: "streaming_hub"
      name: "streaming_hub"
      ssl: "require"
    redis:
      host: "valkey.internal:6379"
      tls: "true"
      caCert: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.datastores.postgres.*` | (unchanged) | PostgreSQL connection mask (existing) |
| `streamingHub.datastores.redis.host` | `""` | Full Redis address (host:port) for rate limiter |
| `streamingHub.datastores.redis.tls` | `"true"` | Enable TLS for Redis connection |
| `streamingHub.datastores.redis.caCert` | `""` | Base64-encoded PEM CA bundle (optional) |

> **Important:** The `redis` mask carries the **full host:port** in the `host` field — the same shape the `reporter` chart uses (`reporter/templates/_helpers.tpl`). This is different from the `postgres` mask, which splits `host` and `port` into separate fields.

### Rate limit configuration

The `streamingHub.rateLimit` block is a new typed surface for the `lib-commons` three-tier rate-limit contract.

```yaml
streamingHub:
  rateLimit:
    enabled: "true"
    allowDisabled: "false"
    allowFailOpen: "true"
    max: "500"
    windowSec: "60"
    aggressiveMax: "100"
    aggressiveWindowSec: "60"
    relaxedMax: "1000"
    relaxedWindowSec: "60"
    redisTimeoutMs: "500"
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.rateLimit.enabled` | `"true"` | Enable rate limiting (requires Redis address) |
| `streamingHub.rateLimit.allowDisabled` | `"false"` | Permit runtime disable via per-request header |
| `streamingHub.rateLimit.allowFailOpen` | `"true"` (chart default) | Permit fail-open when Redis is unreachable |
| `streamingHub.rateLimit.max` | `"500"` | Default tier: max requests per window |
| `streamingHub.rateLimit.windowSec` | `"60"` | Default tier: window duration in seconds |
| `streamingHub.rateLimit.aggressiveMax` | `"100"` | Aggressive tier: max requests per window |
| `streamingHub.rateLimit.aggressiveWindowSec` | `"60"` | Aggressive tier: window duration in seconds |
| `streamingHub.rateLimit.relaxedMax` | `"1000"` | Relaxed tier: max requests per window |
| `streamingHub.rateLimit.relaxedWindowSec` | `"60"` | Relaxed tier: window duration in seconds |
| `streamingHub.rateLimit.redisTimeoutMs` | `"500"` | Redis operation timeout in milliseconds |

> **Note:** The chart ships with **empty** `streamingHub.rateLimit` by default, so the helper's own defaults apply. Any `configmap.<NATIVE_KEY>` override still wins over these typed fields.

### Secrets

The `streamingHub.secrets` block now includes a `STREAMING_HUB_REDIS_PASSWORD` field.

**Before (v1.0.1):**

```yaml
streamingHub:
  secrets:
    STREAMING_HUB_POSTGRES_DSN: ""
    STREAMING_HUB_KAFKA_CA_CERT: ""
    STREAMING_HUB_DEV_KEK: ""
    STREAMING_HUB_KAFKA_SCRAM_PASSWORD: ""
    POSTGRES_PASSWORD: ""
```

**After (v1.1.0):**

```yaml
streamingHub:
  secrets:
    STREAMING_HUB_POSTGRES_DSN: ""
    STREAMING_HUB_KAFKA_CA_CERT: ""
    STREAMING_HUB_DEV_KEK: ""
    STREAMING_HUB_KAFKA_SCRAM_PASSWORD: ""
    POSTGRES_PASSWORD: ""
    STREAMING_HUB_REDIS_PASSWORD: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `secrets.STREAMING_HUB_REDIS_PASSWORD` | `""` | Redis AUTH password (emit-when-set, may stay empty when Redis takes no AUTH) |

> **Important:** The Redis password is **emit-when-set** and may legitimately stay empty when the Redis instance takes no AUTH. This is why it is **not** pinned via `secretKeyRef` on the `useExistingSecret` path (unlike `STREAMING_HUB_POSTGRES_DSN`, which is always required).

### New environment variables

The following environment variables are added to the ConfigMap in v1.1.0:

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAMING_HUB_REDIS_ADDRESS` | `""` | Redis host:port (empty disables rate limiting) |
| `STREAMING_HUB_REDIS_TLS` | `"true"` | Enable TLS for Redis connection |
| `STREAMING_HUB_REDIS_CA_CERT` | `""` | Base64-encoded PEM CA bundle for Redis TLS |
| `RATE_LIMIT_ENABLED` | `"true"` | Enable rate limiting (requires Redis address) |
| `ALLOW_RATELIMIT_DISABLED` | `"false"` | Permit runtime disable via per-request header |
| `ALLOW_RATELIMIT_FAIL_OPEN` | `"false"` (lib-commons default) | Permit fail-open when Redis is unreachable |
| `RATE_LIMIT_MAX` | `"500"` | Default tier: max requests per window |
| `RATE_LIMIT_WINDOW_SEC` | `"60"` | Default tier: window duration in seconds |
| `AGGRESSIVE_RATE_LIMIT_MAX` | `"100"` | Aggressive tier: max requests per window |
| `AGGRESSIVE_RATE_LIMIT_WINDOW_SEC` | `"60"` | Aggressive tier: window duration in seconds |
| `RELAXED_RATE_LIMIT_MAX` | `"1000"` | Relaxed tier: max requests per window |
| `RELAXED_RATE_LIMIT_WINDOW_SEC` | `"60"` | Relaxed tier: window duration in seconds |
| `RATE_LIMIT_REDIS_TIMEOUT_MS` | `"500"` | Redis operation timeout in milliseconds |

The following secret key is added to the Secret in v1.1.0:

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAMING_HUB_REDIS_PASSWORD` | `""` | Redis AUTH password (emit-when-set) |

---

## Migration Steps

### Step 1: Review rate limiting requirements

Determine whether you need control-plane rate limiting for your environment.

**No action required if:**

- You are running in a development or staging environment where rate limiting is not required
- You do not have a Redis or Valkey instance available
- You want to defer rate limiting configuration to a future release

**Action required if:**

- You are running in a production environment and want to enforce rate limits on control-plane API endpoints
- You have a Redis or Valkey instance available for the rate limiter store

> **Note:** Leaving the Redis address empty is a **silent no-op**. The control plane will serve all requests unlimited and will not log errors or fail health checks. Rate limiting is entirely opt-in.

### Step 2: Provision Redis/Valkey (optional)

If you want to enable rate limiting, provision an external Redis or Valkey instance.

**Requirements:**

- Redis 6.0+ or Valkey 7.0+
- Network reachable from the streaming-hub pods
- TLS enabled (recommended for production)
- AUTH enabled (recommended for production)

**Example provisioning (external to this chart):**

```bash
# Example: Deploy Valkey via Helm (not part of streaming-hub chart)
helm install valkey oci://registry-1.docker.io/bitnami/valkey \
  --set auth.enabled=true \
  --set auth.password="your-redis-password" \
  --set tls.enabled=true \
  --namespace streaming-hub
```

> **Important:** The streaming-hub chart does **not** include a Redis or Valkey subchart. You must provision the instance externally (e.g., managed Redis service, separate Helm chart, or Kubernetes operator).

### Step 3: Configure Redis connection (optional)

If you provisioned a Redis/Valkey instance, configure the connection in your `values.yaml`.

**Option 1: Component-specific Redis (recommended)**

```yaml
streamingHub:
  datastores:
    redis:
      host: "valkey.streaming-hub.svc.cluster.local:6379"
      tls: "true"
      caCert: ""
```

**Option 2: Shared Redis (global tier)**

```yaml
global:
  datastores:
    redis:
      host: "valkey.streaming-hub.svc.cluster.local:6379"
      tls: "true"
      caCert: ""
```

> **Note:** The `host` field carries the **full host:port** (e.g., `valkey.internal:6379`). This is the same shape the `reporter` chart uses.

**TLS configuration:**

If your Redis instance uses a custom CA certificate, encode it as base64 and set `caCert`:

```bash
cat redis-ca.crt | base64 -w 0
```

```yaml
streamingHub:
  datastores:
    redis:
      host: "valkey.streaming-hub.svc.cluster.local:6379"
      tls: "true"
      caCert: "LS0tLS1CRUdJTi..."
```

If your Redis instance uses the system CA bundle, leave `caCert` empty:

```yaml
streamingHub:
  datastores:
    redis:
      host: "valkey.streaming-hub.svc.cluster.local:6379"
      tls: "true"
      caCert: ""
```

### Step 4: Configure rate limits (optional)

If you want to override the default rate limits, configure the `streamingHub.rateLimit` block.

**Default behavior (no configuration required):**

The chart ships with **empty** `streamingHub.rateLimit`, so the `lib-commons` helper's own defaults apply:

- Enabled: `"true"`
- Default tier: 500 requests per 60 seconds
- Aggressive tier: 100 requests per 60 seconds
- Relaxed tier: 1000 requests per 60 seconds
- Redis timeout: 500ms
- Fail-open: `"false"` (lib-commons default, overridden by chart to `"true"`)

**Custom rate limits:**

```yaml
streamingHub:
  rateLimit:
    enabled: "true"
    allowFailOpen: "true"
    max: "1000"
    windowSec: "60"
    aggressiveMax: "200"
    aggressiveWindowSec: "60"
    relaxedMax: "2000"
    relaxedWindowSec: "60"
    redisTimeoutMs: "1000"
```

**Fail-closed posture:**

If you want the rate limiter to **refuse** requests when Redis is unreachable (instead of allowing them), unset `allowFailOpen`:

```yaml
streamingHub:
  rateLimit:
    allowFailOpen: "false"
```

> **Warning:** Fail-closed means a Redis outage will take the control plane down. This is the `lib-commons` default but **not** the chart's default. The chart ships with `allowFailOpen: "true"` as the intended posture.

### Step 5: Set Redis password (optional)

If your Redis instance requires AUTH, set the password in `streamingHub.secrets`.

**Chart-managed secret (default):**

```yaml
streamingHub:
  secrets:
    STREAMING_HUB_REDIS_PASSWORD: "your-redis-password"
```

**External secret (useExistingSecret: true):**

If you use an external secret, ensure it contains the `STREAMING_HUB_REDIS_PASSWORD` key:

```bash
kubectl create secret generic streaming-hub-external \
  --from-literal=STREAMING_HUB_POSTGRES_DSN="postgresql://..." \
  --from-literal=STREAMING_HUB_REDIS_PASSWORD="your-redis-password" \
  --namespace streaming-hub
```

```yaml
streamingHub:
  useExistingSecret: true
  existingSecretName: "streaming-hub-external"
```

> **Note:** The Redis password is **emit-when-set** and may legitimately stay empty when the Redis instance takes no AUTH. This is why it is **not** pinned via `secretKeyRef` on the `useExistingSecret` path.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 1.1.0 -n streaming-hub
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 1.1.0 -n streaming-hub
```
