# Helm Upgrade from v10.0.1 to v10.0.2

# Topics

- **[Fixes](#fixes)**
  - [1. Database Connection Timeout Configuration](#1-database-connection-timeout-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Database Connection Timeout Configuration

**What changed:**

The Caradhras deployment now includes a `connect_timeout=5` parameter in the PostgreSQL connection string. This adds a 5-second timeout when establishing new database connections.

**Before (v10.0.1):**

```yaml
# templates/caradhras/deployment.yaml
export dataSourceName="user=${DB_USER} password=${DB_PASSWORD} host=${DB_HOST} port=${DB_PORT} sslmode=${DB_SSLMODE} dbname=${DB_NAME}"
```

**After (v10.0.2):**

```yaml
# templates/caradhras/deployment.yaml
export dataSourceName="user=${DB_USER} password=${DB_PASSWORD} host=${DB_HOST} port=${DB_PORT} sslmode=${DB_SSLMODE} connect_timeout=5 dbname=${DB_NAME}"
```

**Why this matters:**

Without an explicit connection timeout, the Caradhras service could hang indefinitely when attempting to connect to an unreachable or slow-responding database. This can cause:

- Delayed pod startup and readiness probe failures
- Resource exhaustion from accumulating blocked connection attempts
- Unclear failure modes during database outages or network issues

The 5-second timeout ensures that connection attempts fail fast, allowing Kubernetes to restart the pod or surface the error more quickly.

**Operational impact:**

For most deployments, this change will be transparent and beneficial:

- **Normal operations:** If your database is healthy and reachable, you won't notice any difference
- **Startup behavior:** Pods will fail faster during startup if the database is unavailable, making issues more visible
- **Resilience:** The service will recover more quickly when database connectivity is restored after an outage

**When this might surface issues:**

If your database is experiencing intermittent slowness or network latency spikes that cause connection establishment to take longer than 5 seconds, you may see connection failures that previously succeeded (albeit slowly).

In such cases, you should investigate and resolve the underlying database or network performance issue rather than increasing the timeout, as slow connection establishment typically indicates a problem that needs attention.

**What operators need to do:**

No action required. The connection timeout is hardcoded in the deployment template and cannot be overridden via values.yaml. This is intentional — a 5-second connection timeout is appropriate for production PostgreSQL deployments.

> **Note:** This timeout only applies to the initial TCP connection establishment to the database. It does not affect query execution time or other database operations.

> **Important:** If you observe connection timeout errors after upgrading, this indicates a pre-existing database connectivity or performance issue that was previously masked by the lack of a timeout. Investigate database health, network latency, and connection pooling configuration.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.2 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.2 -n plugin-access-manager
```
