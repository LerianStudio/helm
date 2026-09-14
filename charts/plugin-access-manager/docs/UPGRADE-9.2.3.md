# Helm Upgrade from v9.2.2 to v9.2.3

# Topics

- **[Fixes](#fixes)**
  - [1. HTTP Client Connection Pool Tuning](#1-http-client-connection-pool-tuning)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. HTTP Client Connection Pool Tuning

This release adjusts the default HTTP client connection pool settings for both the auth and identity services to improve resource utilization and prevent connection exhaustion.

**What changed:**

The default value for `HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST` has been reduced from 100 to 10 connections per host.

| Service | Setting | v9.2.2 | v9.2.3 |
|---------|---------|--------|--------|
| Auth | `HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST` | `100` | `10` |
| Identity | `HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST` | `100` | `10` |

**Why this matters:**

The previous default of 100 idle connections per host was unnecessarily high for most deployments and could lead to:

- Excessive memory consumption from maintaining too many idle connections
- Port exhaustion on systems with many backend hosts
- Inefficient resource usage when traffic patterns don't require high connection reuse

The new default of 10 connections per host provides a better balance between connection reuse and resource efficiency for typical workloads.

**Template changes:**

**Before (v9.2.2):**

```yaml
# auth/configmap.yaml
HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: {{ .Values.auth.configmap.HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST | default "100" | quote }}
```

```yaml
# identity/configmap.yaml
HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: {{ .Values.identity.configmap.HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST | default "100" | quote }}
```

**After (v9.2.3):**

```yaml
# auth/configmap.yaml
HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: {{ .Values.auth.configmap.HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST | default "10" | quote }}
```

```yaml
# identity/configmap.yaml
HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: {{ .Values.identity.configmap.HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST | default "10" | quote }}
```

**Operational impact:**

For most deployments, this change will be transparent and beneficial:

- **Standard workloads:** The new default of 10 connections per host is sufficient for typical traffic patterns
- **Resource usage:** You may observe a slight reduction in memory usage and open file descriptors
- **Performance:** No performance degradation is expected for normal workloads

**When you might need to override:**

If your deployment handles very high request volumes to specific backend services, you may want to increase this value:

```yaml
auth:
  configmap:
    HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: "50"

identity:
  configmap:
    HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: "50"
```

> **Note:** This setting works in conjunction with `HTTP_CLIENT_MAX_IDLE_CONNS` (default: 100), which controls the total number of idle connections across all hosts. The per-host limit cannot exceed the global limit.

**Related HTTP client settings:**

For reference, here are all the HTTP client connection pool settings and their defaults:

| Setting | Default | Description |
|---------|---------|-------------|
| `HTTP_CLIENT_TIMEOUT_SEC` | `30` | Maximum time to wait for a complete HTTP response |
| `HTTP_CLIENT_MAX_IDLE_CONNS` | `100` | Maximum total idle connections across all hosts |
| `HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST` | `10` | Maximum idle connections to keep per host |
| `HTTP_CLIENT_IDLE_CONN_TIMEOUT_SEC` | `90` | How long an idle connection remains in the pool |

**Example: High-throughput configuration**

If you're running a high-traffic deployment with many concurrent requests to backend services:

```yaml
auth:
  configmap:
    HTTP_CLIENT_MAX_IDLE_CONNS: "200"
    HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: "50"
    HTTP_CLIENT_IDLE_CONN_TIMEOUT_SEC: "120"

identity:
  configmap:
    HTTP_CLIENT_MAX_IDLE_CONNS: "200"
    HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: "50"
    HTTP_CLIENT_IDLE_CONN_TIMEOUT_SEC: "120"
```

**Example: Resource-constrained configuration**

If you're running in a resource-constrained environment and want to minimize connection overhead:

```yaml
auth:
  configmap:
    HTTP_CLIENT_MAX_IDLE_CONNS: "50"
    HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: "5"
    HTTP_CLIENT_IDLE_CONN_TIMEOUT_SEC: "60"

identity:
  configmap:
    HTTP_CLIENT_MAX_IDLE_CONNS: "50"
    HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST: "5"
    HTTP_CLIENT_IDLE_CONN_TIMEOUT_SEC: "60"
```

> **Important:** If you have explicitly set `HTTP_CLIENT_MAX_IDLE_CONNS_PER_HOST` to `100` in your `values.yaml`, that override will continue to be respected. This change only affects deployments using the default value.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.3 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.3 -n plugin-access-manager
```
