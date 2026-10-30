# Helm Upgrade from v10.0.1 to v10.0.2

# Topics

- **[Fixes](#fixes)**
  - [1. Database Connection Timeout Configuration](#1-database-connection-timeout-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Database Connection Timeout Configuration

**What changed:**

The Caradhras server start command now adds `connect_timeout=5` to the PostgreSQL connection string. Each new connection to the database must be established within 5 seconds. The limit covers the TCP connect and the PostgreSQL startup and authentication handshake. It does not limit queries, and it does not affect connections that are already open.

Nothing else changes in this release. The application version stays `3.11.1`, no image tag changes, and the `migrate` init container is not touched.

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

Without `connect_timeout`, the PostgreSQL driver sets no time limit of its own on connection setup. A database that accepts the TCP connection but does not finish the handshake can block the connection attempt for as long as the server holds it. This can cause:

- Delayed pod startup and readiness probe failures
- Resource exhaustion from accumulating blocked connection attempts
- Unclear failure modes during database outages or network issues

With the limit, a connection attempt that takes longer than 5 seconds fails and returns an error.

**Pods restart during the upgrade:**

The start command is part of the Caradhras pod template. `helm upgrade` therefore replaces the Caradhras pods even though the image and your values do not change. The `identity` and `auth` pods are not replaced.

The Caradhras Deployment uses a rolling update with `maxSurge: 1` and `maxUnavailable: 0`. These values are fixed in the template. A new pod must pass its readiness check before an old pod stops, so a healthy database means no downtime, including with `replicaCount: 1`.

**Operational impact:**

For most deployments, this change is transparent:

- **Normal operations:** If your database is healthy and reachable, you will not notice a difference.
- **Startup behavior:** If the database is unavailable, a pod fails its connection attempt after at most 5 seconds instead of waiting on it.
- **Runtime behavior:** The limit applies to every new connection the pool opens, not only at pod start.

**When this might surface issues:**

If your database has intermittent slowness or network latency spikes that make connection setup take longer than 5 seconds, connections that used to succeed slowly now fail.

In that case, investigate the database or network problem. Do not look for a way to raise the timeout: slow connection setup usually points to a problem that needs attention.

**What operators need to do:**

No change to your values is required. The connection timeout is hardcoded in the deployment template and cannot be overridden through `values.yaml`. Expect the Caradhras pods to restart once during the upgrade.

> **Important:** If you see connection timeout errors after the upgrade, the database connectivity or performance issue was already there. Before this release, nothing bounded the wait, so the problem stayed hidden. Check database health, network latency, and connection pool settings.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.2 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.2 -n plugin-access-manager
```
