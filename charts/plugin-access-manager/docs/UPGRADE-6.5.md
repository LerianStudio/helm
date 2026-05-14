# Helm Upgrade from v6.4.1 to v6.5.0

# Topics

- **[Features](#features)**
  - [1. Application Version Updates](#1-application-version-updates)
  - [2. Configurable Health Probes](#2-configurable-health-probes)
  - [3. Enhanced Readiness Probe Endpoints](#3-enhanced-readiness-probe-endpoints)
- **[Configuration Reference](#configuration-reference)**
  - [Identity Service Probes](#identity-service-probes)
  - [Auth Service Probes](#auth-service-probes)
  - [Auth Backend Service Probes](#auth-backend-service-probes)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Application Version Updates

This release updates the application versions for all three services in the plugin-access-manager chart.

| Service | v6.4.1 | v6.5.0 |
|---------|--------|--------|
| Identity | 2.4.2 | 2.4.4 |
| Auth | 2.6.3 | 2.6.5 |
| Auth Backend | 2.6.2 | 2.6.5 |
| Chart appVersion | 2.6.3 | 2.6.5 |

**What this means for operators:**

These are patch version updates that include bug fixes and improvements. The upgrade should be seamless with no configuration changes required for version bumps alone.

### 2. Configurable Health Probes

All three services (identity, auth, and auth-backend) now support fully configurable readiness and liveness probes. Previously, probe settings were hardcoded in the templates.

**What changed:**

New configuration blocks have been added to `values.yaml` that allow you to customize all probe parameters:

```yaml
identity:
  readinessProbe: {}
  livenessProbe: {}

auth:
  readinessProbe: {}
  livenessProbe: {}

auth:
  backend:
    readinessProbe: {}
    livenessProbe: {}
```

**Why this matters:**

- You can now tune probe timing to match your environment's startup characteristics
- Adjust failure thresholds for more or less aggressive pod restart behavior
- Customize timeout values for slower network environments
- Override probe paths if your deployment uses custom health check endpoints

**Default behavior:**

If you don't specify any probe configuration, the chart uses sensible defaults that maintain backward compatibility with v6.4.1 behavior (with the exception of readiness probe paths, see next section).

### 3. Enhanced Readiness Probe Endpoints

The default readiness probe path has changed from generic health endpoints to dedicated readiness endpoints.

| Service | Probe Type | v6.4.1 Path | v6.5.0 Path |
|---------|-----------|-------------|-------------|
| Identity | Readiness | *(no probe)* | `/readyz` |
| Identity | Liveness | *(no probe)* | `/health` |
| Auth | Readiness | `/health` | `/readyz` |
| Auth | Liveness | `/health` | `/health` |
| Auth Backend | Readiness | `/api/health` | `/readyz` |
| Auth Backend | Liveness | `/api/health` | `/api/health` |

**What this means for operators:**

The new `/readyz` endpoint is specifically designed for readiness checks and may have different behavior than the general `/health` endpoint. This provides better pod lifecycle management:

- **Readiness probes** now use `/readyz` to determine if the pod is ready to receive traffic
- **Liveness probes** continue using existing health endpoints to determine if the pod should be restarted

> **Important:** If your monitoring or external health checks depend on specific probe paths, you may need to update them or override the probe paths in your values.

**Before (v6.4.1):**

```yaml
# auth deployment - hardcoded probes
readinessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 25
  periodSeconds: 5
```

**After (v6.5.0):**

```yaml
# auth deployment - configurable probes with new default path
readinessProbe:
  httpGet:
    path: {{ .Values.auth.readinessProbe.path | default "/readyz" }}
    port: {{ .Values.auth.service.port }}
  initialDelaySeconds: {{ .Values.auth.readinessProbe.initialDelaySeconds | default 25 }}
  periodSeconds: {{ .Values.auth.readinessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.auth.readinessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ .Values.auth.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.auth.readinessProbe.failureThreshold | default 3 }}
```

> **Note:** The identity service now includes health probes for the first time in v6.5.0. Previously, this deployment had no health checks configured.

# Configuration Reference

### Identity Service Probes

The identity service now supports health probes. Configure them in your `values.yaml`:

```yaml
identity:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 25
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: /health
    initialDelaySeconds: 30
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `path` | `/readyz` (readiness), `/health` (liveness) | HTTP endpoint to check |
| `initialDelaySeconds` | `25` (readiness), `30` (liveness) | Seconds to wait before first probe |
| `periodSeconds` | `5` | How often to perform the probe |
| `timeoutSeconds` | `1` | Seconds before probe times out |
| `successThreshold` | `1` | Minimum consecutive successes to be considered healthy |
| `failureThreshold` | `3` | Consecutive failures before pod is marked unhealthy |

### Auth Service Probes

Configure auth service probes:

```yaml
auth:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 25
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: /health
    initialDelaySeconds: 30
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `path` | `/readyz` (readiness), `/health` (liveness) | HTTP endpoint to check |
| `initialDelaySeconds` | `25` (readiness), `30` (liveness) | Seconds to wait before first probe |
| `periodSeconds` | `5` | How often to perform the probe |
| `timeoutSeconds` | `1` | Seconds before probe times out |
| `successThreshold` | `1` | Minimum consecutive successes to be considered healthy |
| `failureThreshold` | `3` | Consecutive failures before pod is marked unhealthy |

### Auth Backend Service Probes

Configure auth backend service probes:

```yaml
auth:
  backend:
    readinessProbe:
      path: /readyz
      initialDelaySeconds: 15
      periodSeconds: 5
      timeoutSeconds: 1
      successThreshold: 1
      failureThreshold: 3
    livenessProbe:
      path: /api/health
      initialDelaySeconds: 20
      periodSeconds: 10
      timeoutSeconds: 1
      successThreshold: 1
      failureThreshold: 3
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `path` | `/readyz` (readiness), `/api/health` (liveness) | HTTP endpoint to check |
| `initialDelaySeconds` | `15` (readiness), `20` (liveness) | Seconds to wait before first probe |
| `periodSeconds` | `5` (readiness), `10` (liveness) | How often to perform the probe |
| `timeoutSeconds` | `1` | Seconds before probe times out |
| `successThreshold` | `1` | Minimum consecutive successes to be considered healthy |
| `failureThreshold` | `3` | Consecutive failures before pod is marked unhealthy |

**Example: Adjusting probes for slower environments**

If your pods take longer to start or your network has higher latency, you can increase the timing values:

```yaml
auth:
  readinessProbe:
    initialDelaySeconds: 45
    periodSeconds: 10
    timeoutSeconds: 3
    failureThreshold: 5
  livenessProbe:
    initialDelaySeconds: 60
    periodSeconds: 15
    timeoutSeconds: 3
```

**Example: Reverting to v6.4.1 probe paths**

If you need to maintain the old health check paths for compatibility:

```yaml
auth:
  readinessProbe:
    path: /health

auth:
  backend:
    readinessProbe:
      path: /api/health
```

> **Note:** You only need to specify the values you want to override. Any omitted values will use the defaults shown in the tables above.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 6.5.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 6.5.0 -n plugin-access-manager
```
