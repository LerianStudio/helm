# Helm Upgrade from v9.2.4 to v9.3.0

# Topics

- **[Features](#features)**
  - [1. Shared Session Store for Caradhras](#1-shared-session-store-for-caradhras)
  - [2. Multi-Replica Session Store Validation](#2-multi-replica-session-store-validation)
  - [3. External Secret Support for Caradhras](#3-external-secret-support-for-caradhras)
- **[Configuration Reference](#configuration-reference)**
  - [Session Store Without Authentication](#session-store-without-authentication)
  - [Session Store With Authentication](#session-store-with-authentication)
  - [Using External Secrets](#using-external-secrets)
  - [TLS Configuration](#tls-configuration)
- **[Migration Scenarios](#migration-scenarios)**
  - [Scenario 1: Single Replica (No Action Required)](#scenario-1-single-replica-no-action-required)
  - [Scenario 2: Multiple Replicas Without Session Store](#scenario-2-multiple-replicas-without-session-store)
  - [Scenario 3: HPA Enabled With maxReplicas > 1](#scenario-3-hpa-enabled-with-maxreplicas--1)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Shared Session Store for Caradhras

The caradhras component now supports configuring a shared Redis/Valkey session store. Previously, login sessions were stored on each pod's local filesystem, which only works correctly with a single replica.

**What changed:**

New configuration blocks have been added to `values.yaml` for session store configuration:

```yaml
caradhras:
  configmap:
    redisEndpoint: ""
    redisTls: ""
  secrets:
    redisEndpoint: ""
  useExistingSecret: false
  existingSecretName: ""
```

**Why this matters:**

- **Multi-replica deployments**: When caradhras runs with more than one pod (either fixed replicas > 1 or HPA with maxReplicas > 1), login sessions must be shared across all pods
- **Session persistence**: Without a shared store, a login that starts on one pod and finishes on another fails with "unknown authentication type"
- **Horizontal scaling**: Enables safe horizontal scaling of the caradhras component with HPA

**Default behavior:**

If you don't configure a session store, caradhras continues to use local filesystem sessions. This works correctly for single-replica deployments but will cause login failures in multi-replica scenarios.

### 2. Multi-Replica Session Store Validation

The chart now includes render-time validation that prevents deploying caradhras with multiple replicas when no shared session store is configured.

**What this means for operators:**

| Scenario | v9.2.4 Behavior | v9.3.0 Behavior |
|----------|-----------------|-----------------|
| Single replica, no session store | Deploys successfully | Deploys successfully (no change) |
| Multiple replicas, no session store | Deploys but logins fail | **Render fails with error message** |
| Multiple replicas, session store configured | Deploys but logins fail | Deploys successfully |
| HPA with maxReplicas > 1, no session store | Deploys but logins fail when scaled | **Render fails with error message** |
| HPA with maxReplicas > 1, session store configured | Deploys but logins fail when scaled | Deploys successfully |

**Validation rules:**

1. **Mutual exclusivity**: You cannot configure both `caradhras.configmap.redisEndpoint` and `caradhras.secrets.redisEndpoint` — the chart will fail to render
2. **Password protection**: `caradhras.configmap.redisEndpoint` must not contain a password (the third field in beego's positional format) — use the secrets path instead
3. **Multi-replica requirement**: When `caradhras.replicaCount > 1` (autoscaling disabled) or `caradhras.autoscaling.minReplicas > 1`, a session store must be configured

**Error messages you may encounter:**

If you attempt to deploy with multiple replicas and no session store:

```
Error: caradhras is pinned to more than one replica but has no shared session store. 
Beego keeps login sessions on the pod's own filesystem when redisEndpoint is unset, 
so a login that starts on one pod and finishes on another fails with "unknown 
authentication type". Set caradhras.configmap.redisEndpoint to the host:port of a 
Redis/Valkey both pods reach when it needs no AUTH; when it does need AUTH, set the 
full connection string in caradhras.secrets.redisEndpoint instead (it is delivered 
by Secret, never by ConfigMap). Or scale caradhras back to a single replica.
```

**New NOTES.txt warning:**

When HPA is enabled with `maxReplicas > 1` but no session store is configured, the chart now displays a warning after installation:

```
WARNING: caradhras has no shared session store while its HPA may scale it to
3 pods. Login sessions live on each pod's own filesystem, so the moment the
HPA adds a second pod, a login that starts on one and finishes on another fails
with "unknown authentication type".

Point caradhras at a Redis/Valkey every pod can reach (the Valkey bundled with
this release is plugin-access-manager-valkey-master:6379):

  - no AUTH: set caradhras.configmap.redisEndpoint to its host:port
  - with AUTH: set caradhras.secrets.redisEndpoint to the full connection
    string (host:port,poolsize,password) — it is delivered by Secret, never by
    ConfigMap

Or set caradhras.autoscaling.maxReplicas=1.
```

### 3. External Secret Support for Caradhras

Similar to the auth and identity components, caradhras now supports using an operator-managed Secret for sensitive configuration.

**What changed:**

New fields allow you to provide your own Secret instead of having the chart create one:

```yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "my-caradhras-secret"
```

**Why this matters:**

- **Secret management**: Integrate with external secret management systems (Vault, AWS Secrets Manager, etc.)
- **GitOps workflows**: Keep sensitive values out of your values.yaml files
- **Consistency**: Matches the pattern already established for auth and identity components

**Required Secret structure:**

When `useExistingSecret: true`, your Secret must contain the key `redisEndpoint` with the full connection string:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-caradhras-secret
type: Opaque
stringData:
  redisEndpoint: "redis-host:6379,10,mypassword,0"
```

> **Important:** If you set `caradhras.useExistingSecret: true` but leave `caradhras.existingSecretName` empty, the chart will fail to render with an error message.

# Configuration Reference

### Session Store Without Authentication

For a Redis/Valkey instance that does **not** require authentication, configure the endpoint in the ConfigMap:

```yaml
caradhras:
  configmap:
    redisEndpoint: "redis-host:6379"
    redisTls: "false"
```

| Field | Format | Description |
|-------|--------|-------------|
| `redisEndpoint` | `host:port` | Redis/Valkey endpoint with no password |
| `redisTls` | `"true"` or `"false"` | Whether to connect over TLS |

**Example with bundled Valkey:**

If you have `valkey.enabled: true` in your chart, the bundled Valkey is available at `<release-name>-valkey-master:6379`:

```yaml
caradhras:
  configmap:
    redisEndpoint: "plugin-access-manager-valkey-master:6379"
    redisTls: "false"
```

> **Note:** The `redisEndpoint` value is rendered into a ConfigMap and is readable by any principal with get permissions on that ConfigMap. Never include a password in this field.

### Session Store With Authentication

For a Redis/Valkey instance that **requires** authentication, configure the full connection string in the secrets block:

```yaml
caradhras:
  secrets:
    redisEndpoint: "redis-host:6379,10,mypassword,0"
  configmap:
    redisTls: "false"
```

| Field | Format | Description |
|-------|--------|-------------|
| `secrets.redisEndpoint` | `host:port,poolsize,password[,dbnum]` | Full beego connection string with password |
| `configmap.redisTls` | `"true"` or `"false"` | Whether to connect over TLS |

**Connection string format (beego positional):**

```
host:port,poolsize,password,dbnum
```

- **host:port**: Redis endpoint (required)
- **poolsize**: Connection pool size, e.g. `10` (required)
- **password**: Redis AUTH password (required for authenticated Redis)
- **dbnum**: Redis database number, e.g. `0` (optional, defaults to 0)

**Example:**

```yaml
caradhras:
  secrets:
    redisEndpoint: "my-redis.example.com:6379,20,s3cr3tp@ssw0rd,1"
  configmap:
    redisTls: "true"
```

> **Important:** The `secrets.redisEndpoint` value is base64-encoded and stored in a Secret, then injected into the caradhras pod via `secretKeyRef`. It never appears in a ConfigMap.

### Using External Secrets

To manage the caradhras Secret yourself (e.g., with External Secrets Operator, Vault, or AWS Secrets Manager):

```yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "my-caradhras-secret"
```

**Your Secret must contain:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-caradhras-secret
  namespace: plugin-access-manager
type: Opaque
stringData:
  redisEndpoint: "redis-host:6379,10,mypassword,0"
```

| Key | Required | Description |
|-----|----------|-------------|
| `redisEndpoint` | Yes | Full beego connection string (host:port,poolsize,password,dbnum) |

> **Warning:** If `useExistingSecret: true` but `existingSecretName` is empty, the chart will fail to render with: "caradhras.useExistingSecret is true but caradhras.existingSecretName is empty."

### TLS Configuration

The `redisTls` setting controls whether caradhras connects to Redis over TLS. It is resolved through the same datastore mask used by the auth component.

**Precedence (highest to lowest):**

1. `caradhras.configmap.redisTls` (native value)
2. `caradhras.datastores.redis.tls` (component-level override)
3. `global.datastores.redis.tls` (global default)
4. Cloud preset (if using a managed cloud profile)
5. `"false"` (hardcoded default)

**Example: Global TLS for all Redis connections**

```yaml
global:
  datastores:
    redis:
      tls: "true"
```

**Example: TLS only for caradhras**

```yaml
caradhras:
  configmap:
    redisTls: "true"
```

> **Note:** The `redisTls` value is emitted into the ConfigMap only when a session store is configured (either channel). If no `redisEndpoint` is set, `redisTls` is omitted.

# Migration Scenarios

### Scenario 1: Single Replica (No Action Required)

**Current state:**

```yaml
caradhras:
  replicaCount: 1
  autoscaling:
    enabled: false
```

**Action required:** None

**Explanation:** Single-replica deployments continue to work with local filesystem sessions. No session store configuration is needed.

### Scenario 2: Multiple Replicas Without Session Store

**Current state (v9.2.4):**

```yaml
caradhras:
  replicaCount: 3
  autoscaling:
    enabled: false
```

**Problem:** Login sessions fail intermittently when users are routed to different pods.

**Solution:** Configure a shared session store before upgrading to v9.3.0.

#### Option 1: Use the bundled Valkey

If `valkey.enabled: true` in your chart:

```yaml
caradhras:
  replicaCount: 3
  configmap:
    redisEndpoint: "plugin-access-manager-valkey-master:6379"
    redisTls: "false"
```

#### Option 2: Use an external Redis without AUTH

```yaml
caradhras:
  replicaCount: 3
  configmap:
    redisEndpoint: "my-redis.example.com:6379"
    redisTls: "false"
```

#### Option 3: Use an external Redis with AUTH

```yaml
caradhras:
  replicaCount: 3
  secrets:
    redisEndpoint: "my-redis.example.com:6379,10,mypassword,0"
  configmap:
    redisTls: "true"
```

#### Option 4: Scale back to single replica

If you don't need multiple replicas:

```yaml
caradhras:
  replicaCount: 1
```

> **Warning:** If you attempt to upgrade with `replicaCount > 1` and no session store configured, the chart will fail to render with an error message.

### Scenario 3: HPA Enabled With maxReplicas > 1

**Current state (v9.2.4):**

```yaml
caradhras:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 5
```

**Problem:** When HPA scales caradhras beyond 1 pod, login sessions fail intermittently.

**Solution:** Configure a shared session store before upgrading to v9.3.0.

#### Option 1: Use the bundled Valkey

```yaml
caradhras:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 5
  configmap:
    redisEndpoint: "plugin-access-manager-valkey-master:6379"
    redisTls: "false"
```

#### Option 2: Use an external Redis with AUTH

```yaml
caradhras:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 5
  secrets:
    redisEndpoint: "my-redis.example.com:6379,10,mypassword,0"
  configmap:
    redisTls: "true"
```

#### Option 3: Limit HPA to single replica

If you don't need horizontal scaling:

```yaml
caradhras:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 1
```

> **Note:** With HPA enabled and `maxReplicas > 1`, the chart will display a warning in NOTES.txt if no session store is configured, but it will not fail to render (since the deployment starts at `minReplicas`, which may be 1). However, login failures will occur the moment HPA scales up.

**Migration steps:**

1. Identify your current caradhras replica configuration:

```bash
helm get values plugin-access-manager -n plugin-access-manager | grep -A 10 "^caradhras:"
```

2. If `replicaCount > 1` or `autoscaling.maxReplicas > 1`, prepare a session store configuration in your values file

3. Test the configuration with helm diff:

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.3.0 -n plugin-access-manager -f my-values.yaml
```

4. Proceed with the upgrade once validation passes

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.3.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.3.0 -n plugin-access-manager
```
