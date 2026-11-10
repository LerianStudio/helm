<!-- {% raw %} -->
# Helm Upgrade from v2.4.0 to v2.5.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. TRUSTED_PROXIES configuration restored](#1-trusted_proxies-configuration-restored)
  - [2. HTTP body limit default reduced](#2-http-body-limit-default-reduced)
  - [3. New HTTP server timeout controls](#3-new-http-server-timeout-controls)
  - [4. Sandbox simulation mode](#4-sandbox-simulation-mode)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.4.0` to `2.5.0`. The application version remains `1.3.0`; the chart bump to `2.5.0` is a minor release that restores the `TRUSTED_PROXIES` configuration variable, reduces the default HTTP body size limit, adds new HTTP server timeout controls, and introduces optional sandbox simulation flags for non-production environments.

Existing deployments will continue to work without values changes. Operators who previously set `TRUSTED_PROXIES` in their values overlay and removed it after upgrading to a version that retired the field should restore the configuration. Operators who rely on large request bodies (>4 MB) must explicitly increase `HTTP_BODY_LIMIT_BYTES`.

## Features

### 1. TRUSTED_PROXIES configuration restored

The `TRUSTED_PROXIES` environment variable was previously retired and blocked by the `_retired.tpl` template. In v2.5.0, the retirement check has been removed, and the variable is now supported again in the ConfigMap. This allows operators to configure the application to trust proxy headers (e.g., `X-Forwarded-For`, `X-Real-IP`) from specific IP ranges when the service runs behind a reverse proxy or load balancer.

**Before (v2.4.0):**

The `_retired.tpl` template included:

```yaml
{{- if hasKey $cm "TRUSTED_PROXIES" }}{{- fail "\n\nERROR: app.configmap.TRUSTED_PROXIES is no longer read by plugin-br-payments.\n   Remove it from your values overlay.\n" }}{{- end }}
```

**After (v2.5.0):**

The retirement check is removed, and `configmap.yaml` now includes:

```yaml
{{- if hasKey $cm "TRUSTED_PROXIES" }}
TRUSTED_PROXIES: {{ index $cm "TRUSTED_PROXIES" | quote }}
{{- end }}
```

#### Operational impact

- **Existing deployments without `TRUSTED_PROXIES`**: No action required. The variable remains optional.

- **Deployments that previously set `TRUSTED_PROXIES`**: If you removed `TRUSTED_PROXIES` from your values overlay after a previous upgrade that retired the field, you can now restore it. The application will honor the proxy configuration.

- **New deployments behind a proxy**: If your service runs behind a load balancer or ingress controller that sets `X-Forwarded-For` or similar headers, configure `TRUSTED_PROXIES` to the CIDR ranges of your proxy infrastructure. Without this setting, the application may reject or misinterpret client IP addresses.

**Example values overlay:**

```yaml
app:
  configmap:
    TRUSTED_PROXIES: "10.0.0.0/8,172.16.0.0/12"
```

> **Note:** The `TRUSTED_PROXIES` value should be a comma-separated list of IP addresses or CIDR ranges. Consult your infrastructure documentation for the correct proxy IP ranges.

> **Warning:** Setting `TRUSTED_PROXIES` to `0.0.0.0/0` (trust all sources) is insecure and allows any client to spoof the `X-Forwarded-For` header. Only trust known proxy IP ranges.

### 2. HTTP body limit default reduced

The default value for `HTTP_BODY_LIMIT_BYTES` has been reduced from `104857600` (100 MB) to `4194304` (4 MB). This change reduces memory consumption and mitigates the risk of denial-of-service attacks via large request bodies. Most payment API requests are small (JSON payloads under 1 MB); the new default is sufficient for typical workloads.

| Setting | v2.4.0 | v2.5.0 |
|---------|--------|--------|
| `HTTP_BODY_LIMIT_BYTES` (default) | `104857600` (100 MB) | `4194304` (4 MB) |

#### Operational impact

- **Existing deployments with default settings**: After the upgrade, the application will reject HTTP requests with bodies larger than 4 MB. If your workload includes large file uploads, bulk payment batches, or other large payloads, you must explicitly increase the limit in your values overlay.

- **Deployments with explicit `HTTP_BODY_LIMIT_BYTES` override**: If you already set `HTTP_BODY_LIMIT_BYTES` in your values overlay, the upgrade will not change your configuration. Your explicit value takes precedence.

**Example values overlay to restore the previous 100 MB limit:**

```yaml
app:
  configmap:
    HTTP_BODY_LIMIT_BYTES: "104857600"
```

**Example values overlay for a 10 MB limit:**

```yaml
app:
  configmap:
    HTTP_BODY_LIMIT_BYTES: "10485760"
```

> **Important:** If you see HTTP 413 (Request Entity Too Large) errors after the upgrade, increase `HTTP_BODY_LIMIT_BYTES` to accommodate your largest expected request body size. Monitor application logs for rejected requests during the first hours after the upgrade.

> **Note:** The body limit applies to all HTTP endpoints, including webhooks and bulk upload endpoints. If your integration sends large webhook payloads or batch files, verify the maximum payload size and adjust the limit accordingly.

### 3. New HTTP server timeout controls

Three new optional environment variables allow operators to configure HTTP server read, receive, and idle timeouts. These settings help prevent slow client attacks and resource exhaustion when clients hold connections open without sending data or keep idle connections alive indefinitely.

| Flag | Default | Description |
|------|---------|-------------|
| `HTTP_RECEIVE_TIMEOUT_SEC` | not set (application default) | Maximum time in seconds to read the entire request (headers + body). |
| `HTTP_IDLE_TIMEOUT_SEC` | not set (application default) | Maximum time in seconds an idle keep-alive connection is kept open. |
| `HTTP_READ_BUFFER_SIZE` | not set (application default) | Size in bytes of the HTTP read buffer (already present in v2.4.0, included here for completeness). |

**After (v2.5.0):**

The `configmap.yaml` template now includes:

```yaml
{{- if hasKey $cm "HTTP_RECEIVE_TIMEOUT_SEC" }}
HTTP_RECEIVE_TIMEOUT_SEC: {{ index $cm "HTTP_RECEIVE_TIMEOUT_SEC" | quote }}
{{- end }}
{{- if hasKey $cm "HTTP_IDLE_TIMEOUT_SEC" }}
HTTP_IDLE_TIMEOUT_SEC: {{ index $cm "HTTP_IDLE_TIMEOUT_SEC" | quote }}
{{- end }}
```

#### Operational impact

- **Existing deployments**: No action required. The new variables are optional; the application uses its internal defaults when they are not set.

- **Deployments with slow clients or large uploads**: If you increased `HTTP_BODY_LIMIT_BYTES` to allow large payloads, you may also need to increase `HTTP_RECEIVE_TIMEOUT_SEC` to give clients enough time to upload the data. The receive timeout covers the entire request (headers + body), not just the body.

- **Deployments with aggressive connection reuse**: If your load balancer or clients use HTTP keep-alive and you want to limit how long idle connections remain open, set `HTTP_IDLE_TIMEOUT_SEC` to a value shorter than your load balancer's idle timeout.

**Example values overlay for a 60-second receive timeout and 120-second idle timeout:**

```yaml
app:
  configmap:
    HTTP_RECEIVE_TIMEOUT_SEC: "60"
    HTTP_IDLE_TIMEOUT_SEC: "120"
```

> **Note:** The `HTTP_RECEIVE_TIMEOUT_SEC` value should be larger than the time required to upload your largest expected request body at your slowest expected network speed. For example, a 10 MB payload over a 1 Mbps connection requires at least 80 seconds.

> **Warning:** Setting `HTTP_RECEIVE_TIMEOUT_SEC` too low will cause legitimate large uploads to fail with timeout errors. Setting `HTTP_IDLE_TIMEOUT_SEC` too low will force clients to reconnect frequently, increasing overhead.

### 4. Sandbox simulation mode

Two new optional environment variables enable a sandbox simulation mode for non-production environments. When `SANDBOX_SIMULATION_ENABLED` is set to `true`, the application activates a fake BTG provider simulator for testing payment flows without connecting to the real BTG API. The `SANDBOX_FAKEBTG_ADMIN_URL` variable configures the admin endpoint for the simulator.

| Flag | Default | Description |
|------|---------|-------------|
| `SANDBOX_SIMULATION_ENABLED` | not set (disabled) | Enables the sandbox BTG provider simulator. The application refuses to boot with this flag in production environments. |
| `SANDBOX_FAKEBTG_ADMIN_URL` | not set | Admin URL for the fake BTG simulator. Must share the same origin as the BTG API URLs. |

**After (v2.5.0):**

The `configmap.yaml` template now includes:

```yaml
{{- if hasKey $cm "SANDBOX_SIMULATION_ENABLED" }}
SANDBOX_SIMULATION_ENABLED: {{ index $cm "SANDBOX_SIMULATION_ENABLED" | quote }}
{{- end }}
{{- if hasKey $cm "SANDBOX_FAKEBTG_ADMIN_URL" }}
SANDBOX_FAKEBTG_ADMIN_URL: {{ index $cm "SANDBOX_FAKEBTG_ADMIN_URL" | quote }}
{{- end }}
```

#### Operational impact

- **Production deployments**: Do not set `SANDBOX_SIMULATION_ENABLED` in production. The application will refuse to start if the flag is enabled in a production environment.

- **Non-production deployments**: If you run integration tests or development environments that do not connect to the real BTG API, you can enable the sandbox simulator. The simulator allows you to test payment creation, status updates, and webhooks without external dependencies.

**Example values overlay for a sandbox environment:**

```yaml
app:
  configmap:
    SANDBOX_SIMULATION_ENABLED: "true"
    SANDBOX_FAKEBTG_ADMIN_URL: "http://fakebtg-admin.sandbox.svc.cluster.local:8080"
```

> **Important:** The application enforces that `SANDBOX_FAKEBTG_ADMIN_URL` shares the same origin (scheme, host, port) as the BTG API URLs configured in `BTG_API_URL` and related variables. If the origins do not match, the application will refuse to start.

> **Warning:** The sandbox simulation mode is intended for testing only. It does not perform real payment processing and should never be enabled in production environments. The application will exit with an error if `SANDBOX_SIMULATION_ENABLED` is set to `true` and the environment is detected as production.

> **Note:** The fake BTG simulator is a separate component. The `SANDBOX_FAKEBTG_ADMIN_URL` must point to a running simulator instance. Consult your development or testing documentation for how to deploy the simulator.

## Configuration Reference

### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TRUSTED_PROXIES` | not set | Comma-separated list of IP addresses or CIDR ranges of trusted reverse proxies. When set, the application trusts `X-Forwarded-For` and similar headers from these sources. |
| `HTTP_RECEIVE_TIMEOUT_SEC` | not set (application default) | Maximum time in seconds to read the entire HTTP request (headers + body). |
| `HTTP_IDLE_TIMEOUT_SEC` | not set (application default) | Maximum time in seconds an idle HTTP keep-alive connection is kept open. |
| `SANDBOX_SIMULATION_ENABLED` | not set (disabled) | Enables the sandbox BTG provider simulator. Must not be set in production. |
| `SANDBOX_FAKEBTG_ADMIN_URL` | not set | Admin URL for the fake BTG simulator. Required when `SANDBOX_SIMULATION_ENABLED` is `true`. |

### Changed defaults

| Setting | v2.4.0 | v2.5.0 |
|---------|--------|--------|
| `HTTP_BODY_LIMIT_BYTES` | `104857600` (100 MB) | `4194304` (4 MB) |

## Migration Steps

1. **Review your current `HTTP_BODY_LIMIT_BYTES` usage**. If your workload includes requests larger than 4 MB (e.g., bulk payment uploads, large webhook payloads), add an explicit override to your values overlay:

```yaml
app:
  configmap:
    HTTP_BODY_LIMIT_BYTES: "104857600"  # 100 MB, or adjust to your needs
```

2. **(Optional)** If you previously removed `TRUSTED_PROXIES` from your values overlay after a version that retired the field, and your service runs behind a reverse proxy or load balancer, restore the configuration:

```yaml
app:
  configmap:
    TRUSTED_PROXIES: "10.0.0.0/8,172.16.0.0/12"  # Replace with your proxy IP ranges
```

3. **(Optional)** If you need to configure HTTP server timeouts (e.g., to allow large uploads or limit idle connection duration), add the new timeout variables to your values overlay:

```yaml
app:
  configmap:
    HTTP_RECEIVE_TIMEOUT_SEC: "60"
    HTTP_IDLE_TIMEOUT_SEC: "120"
```

4. **(Optional)** If you run a non-production environment and want to enable the sandbox BTG simulator, add the sandbox flags to your values overlay:

```yaml
app:
  configmap:
    SANDBOX_SIMULATION_ENABLED: "true"
    SANDBOX_FAKEBTG_ADMIN_URL: "http://fakebtg-admin.sandbox.svc.cluster.local:8080"
```

> **Warning:** Do not enable `SANDBOX_SIMULATION_ENABLED` in production. The application will refuse to start.

5. **Run the upgrade** during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

6. **Verify application pods** are running and healthy after the upgrade:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments
```

7. **Monitor application logs** for HTTP 413 errors or timeout errors during the first hours after the upgrade. If you see rejected requests due to body size limits, increase `HTTP_BODY_LIMIT_BYTES` and redeploy:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments --tail=100 | grep -i "413\|body.*too large"
```

8. **(Optional)** If you enabled `TRUSTED_PROXIES`, verify that the application correctly logs client IP addresses from the `X-Forwarded-For` header. Check application access logs or metrics to confirm the proxy configuration is working as expected.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.5.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.5.0
```
<!-- {% endraw %} -->
