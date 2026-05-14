# Helm Upgrade from v5.x to v6.x

# Topics

- ***[Breaking Changes](#breaking-changes)***
    - [1. Readiness Probe Endpoint Changed](#1-readiness-probe-endpoint-changed)
- ***[Features](#features)***
    - [1. Configurable Health Probes](#1-configurable-health-probes)
    - [2. ServiceAccount Support](#2-serviceaccount-support)
    - [3. New Readiness Configuration Variables](#3-new-readiness-configuration-variables)
    - [4. Multi-Tenant Connection Health Checks](#4-multi-tenant-connection-health-checks)
    - [5. Deployment Mode Configuration](#5-deployment-mode-configuration)
- ***[Configuration Reference](#configuration-reference)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Breaking Changes

### 1. Readiness Probe Endpoint Changed

The readiness probe endpoint has changed from `/health` to `/readyz`. This is a breaking change that affects pod startup and readiness detection.

| Setting | v5.4.0 | v6.0.0 |
|---------|--------|--------|
| Readiness probe path | `/health` | `/readyz` |
| Liveness probe path | `/health` | `/health` (unchanged) |

**Before (v5.4.0):**

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 4002
  initialDelaySeconds: 10
  periodSeconds: 5
```

**After (v6.0.0):**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: 4002
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3
```

**Why this matters:**

The new `/readyz` endpoint provides more comprehensive readiness checks, including dependency health validation (MongoDB, Redis), license validation, and graceful shutdown coordination. This ensures pods only receive traffic when they are truly ready to handle requests.

**Migration impact:**

- Pods will use the new readiness endpoint automatically after upgrade
- The new endpoint includes timeout configurations for dependency checks (see [New Readiness Configuration Variables](#3-new-readiness-configuration-variables))
- If you have external monitoring or health check systems pointing to `/health` for readiness, update them to use `/readyz`
- The `/health` endpoint remains available for liveness checks

> **Important:** If you have customized probe configurations or external health monitoring, review the new probe behavior and update your monitoring accordingly.

# Features

### 1. Configurable Health Probes

Both readiness and liveness probes are now fully configurable via values.yaml, allowing operators to tune probe behavior for their specific deployment environments.

**New configuration options:**

```yaml
fees:
  readinessProbe:
    path: "/readyz"
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: "/health"
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
```

| Flag | Default | Description |
|------|---------|-------------|
| `readinessProbe.path` | `/readyz` | HTTP endpoint for readiness checks |
| `readinessProbe.initialDelaySeconds` | `10` | Delay before first readiness probe |
| `readinessProbe.periodSeconds` | `5` | How often to perform readiness probe |
| `readinessProbe.timeoutSeconds` | `1` | Timeout for readiness probe request |
| `readinessProbe.successThreshold` | `1` | Minimum consecutive successes for ready status |
| `readinessProbe.failureThreshold` | `3` | Minimum consecutive failures to mark unready |
| `livenessProbe.path` | `/health` | HTTP endpoint for liveness checks |
| `livenessProbe.initialDelaySeconds` | `5` | Delay before first liveness probe |
| `livenessProbe.periodSeconds` | `5` | How often to perform liveness probe |
| `livenessProbe.timeoutSeconds` | `1` | Timeout for liveness probe request |
| `livenessProbe.successThreshold` | `1` | Minimum consecutive successes for healthy status |
| `livenessProbe.failureThreshold` | `3` | Minimum consecutive failures to restart pod |

**Example: Adjusting probes for slower startup environments**

```yaml
fees:
  readinessProbe:
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 3
    failureThreshold: 5
  livenessProbe:
    initialDelaySeconds: 15
    periodSeconds: 10
    failureThreshold: 5
```

> **Note:** All probe fields are optional. If not specified, the defaults shown in the table above will be used.

### 2. ServiceAccount Support

The chart now supports creating and using Kubernetes ServiceAccounts, enabling integration with cloud IAM systems (AWS IRSA, GCP Workload Identity, Azure Managed Identity).

**New configuration:**

```yaml
fees:
  serviceAccount:
    create: false
    annotations: {}
    name: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `serviceAccount.create` | `false` | Whether to create a ServiceAccount |
| `serviceAccount.annotations` | `{}` | Annotations to add to the ServiceAccount (e.g., IAM role ARNs) |
| `serviceAccount.name` | `""` | Name of the ServiceAccount (defaults to chart fullname if empty) |

**Example: Enabling ServiceAccount with AWS IRSA**

```yaml
fees:
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/plugin-fees-role"
```

**Example: Enabling ServiceAccount with GCP Workload Identity**

```yaml
fees:
  serviceAccount:
    create: true
    annotations:
      iam.gke.io/gcp-service-account: "plugin-fees@project-id.iam.gserviceaccount.com"
```

> **Note:** When `serviceAccount.create` is `false`, no ServiceAccount is created or referenced in the deployment. Set to `true` only when you need cloud IAM integration or specific RBAC configurations.

### 3. New Readiness Configuration Variables

Three new environment variables control the behavior of the `/readyz` endpoint, allowing fine-tuning of dependency health checks and graceful shutdown.

**New ConfigMap variables:**

```yaml
fees:
  configmap:
    READYZ_DEPENDENCY_TIMEOUT_SECONDS: "1"
    READYZ_LICENSE_TIMEOUT_SECONDS: "5"
    READYZ_DRAIN_GRACE_SECONDS: "10"
```

| Variable | Default | Description |
|----------|---------|-------------|
| `READYZ_DEPENDENCY_TIMEOUT_SECONDS` | `"1"` | Timeout for checking MongoDB and Redis connectivity during readiness probe |
| `READYZ_LICENSE_TIMEOUT_SECONDS` | `"5"` | Timeout for validating license key during readiness probe |
| `READYZ_DRAIN_GRACE_SECONDS` | `"10"` | Grace period for draining connections during pod shutdown before marking unready |

**Why these matter:**

- **READYZ_DEPENDENCY_TIMEOUT_SECONDS**: Controls how long the readiness probe waits for database/cache responses. Lower values fail faster but may cause false negatives under load.
- **READYZ_LICENSE_TIMEOUT_SECONDS**: Prevents slow license validation from blocking pod readiness indefinitely.
- **READYZ_DRAIN_GRACE_SECONDS**: Ensures in-flight requests complete before the pod is removed from service during rolling updates or scale-down.

**Example: Adjusting for high-latency database connections**

```yaml
fees:
  configmap:
    READYZ_DEPENDENCY_TIMEOUT_SECONDS: "3"
    READYZ_LICENSE_TIMEOUT_SECONDS: "10"
```

### 4. Multi-Tenant Connection Health Checks

A new configuration variable enables periodic health checks for multi-tenant database connections.

**New ConfigMap variable:**

```yaml
fees:
  configmap:
    MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "30"
```

| Variable | Default | Description |
|----------|---------|-------------|
| `MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC` | `"30"` | Interval in seconds between multi-tenant connection health checks |

**Why this matters:**

In multi-tenant deployments, this setting ensures that stale or broken connections to tenant-specific databases are detected and recycled automatically, improving reliability and reducing connection-related errors.

**Example: Increasing check frequency for critical deployments**

```yaml
fees:
  configmap:
    MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "15"
```

### 5. Deployment Mode Configuration

A new `DEPLOYMENT_MODE` variable has been added to distinguish between local, development, and production environments.

**New ConfigMap variable:**

```yaml
fees:
  configmap:
    DEPLOYMENT_MODE: "local"
```

| Variable | Default | Description |
|----------|---------|-------------|
| `DEPLOYMENT_MODE` | `"local"` | Deployment environment mode (e.g., `local`, `development`, `production`) |

**Example: Setting deployment mode for production**

```yaml
fees:
  configmap:
    DEPLOYMENT_MODE: "production"
```

> **Note:** This variable may affect logging verbosity, feature flags, or other environment-specific behaviors in the application.

# Configuration Reference

**Complete example with all new v6.0.0 features:**

```yaml
fees:
  # Health probe configuration
  readinessProbe:
    path: "/readyz"
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: "/health"
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3

  # ServiceAccount configuration
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/plugin-fees-role"
    name: ""

  # Application configuration
  configmap:
    DEPLOYMENT_MODE: "production"
    READYZ_DEPENDENCY_TIMEOUT_SECONDS: "1"
    READYZ_LICENSE_TIMEOUT_SECONDS: "5"
    READYZ_DRAIN_GRACE_SECONDS: "10"
    MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: "30"
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 6.0.0 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 6.0.0 -n plugin-fees
```
