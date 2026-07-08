# Helm Upgrade from v8.2.0 to v8.3.0

# Topics

- **[Features](#features)**
  - [1. Startup Probe Support](#1-startup-probe-support)
- **[Configuration Reference](#configuration-reference)**
  - [Identity Service Startup Probe](#identity-service-startup-probe)
  - [Auth Service Startup Probe](#auth-service-startup-probe)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Startup Probe Support

Both the identity and auth services now support optional startup probes. Startup probes are designed to handle slow-starting containers by delaying the enforcement of liveness and readiness probes until the application has fully initialized.

**What changed:**

New configuration blocks have been added to `values.yaml` for both services:

```yaml
identity:
  startupProbe:
    enabled: false
    failureThreshold: 5
    periodSeconds: 10
    timeoutSeconds: 10

auth:
  startupProbe:
    enabled: false
    failureThreshold: 5
    periodSeconds: 10
    timeoutSeconds: 10
```

The corresponding deployment templates now include conditional startup probe definitions that activate when `enabled: true`.

**Why this matters:**

- **Prevents premature restarts**: Pods with long initialization times (database migrations, cache warming, dependency checks) won't be killed by liveness probes before they're ready
- **Configurable grace period**: With default settings (`failureThreshold: 5`, `periodSeconds: 10`), pods get up to 50 seconds to start before liveness/readiness probes begin
- **Better production stability**: Reduces CrashLoopBackOff scenarios during deployments or cluster scaling events

**Default behavior:**

Startup probes are **disabled by default** (`enabled: false`). This maintains backward compatibility with v8.2.0 behavior. Existing deployments will continue to rely solely on readiness and liveness probes.

**When to enable startup probes:**

Consider enabling startup probes if you experience:
- Pods being restarted during initialization due to liveness probe failures
- Long application startup times (>30 seconds)
- Database migration or schema initialization delays
- Cold start performance issues in resource-constrained environments

**Before (v8.2.0):**

No startup probe configuration existed. Liveness and readiness probes would begin immediately based on their `initialDelaySeconds` settings, potentially causing restarts during slow application startup.

**After (v8.3.0):**

```yaml
# identity deployment - conditional startup probe
{{- if .Values.identity.startupProbe.enabled }}
startupProbe:
  httpGet:
    path: {{ .Values.identity.startupProbe.path | default "/health" }}
    port: {{ .Values.identity.service.port }}
  initialDelaySeconds: {{ .Values.identity.startupProbe.initialDelaySeconds | default 0 }}
  periodSeconds: {{ .Values.identity.startupProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ .Values.identity.startupProbe.timeoutSeconds | default 10 }}
  successThreshold: {{ .Values.identity.startupProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.identity.startupProbe.failureThreshold | default 5 }}
{{- end }}
```

The same pattern applies to the auth service deployment.

> **Important:** When a startup probe is enabled and configured, Kubernetes will not execute liveness or readiness probes until the startup probe succeeds. This means your total startup time allowance is `failureThreshold × periodSeconds` before the pod is considered failed.

# Configuration Reference

### Identity Service Startup Probe

Configure the identity service startup probe in your `values.yaml`:

```yaml
identity:
  startupProbe:
    enabled: true
    path: /health
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 10
    successThreshold: 1
    failureThreshold: 5
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `enabled` | `false` | Whether to enable the startup probe |
| `path` | `/health` | HTTP endpoint to check for startup completion |
| `initialDelaySeconds` | `0` | Seconds to wait before first startup probe |
| `periodSeconds` | `10` | How often to perform the startup probe |
| `timeoutSeconds` | `10` | Seconds before startup probe times out |
| `successThreshold` | `1` | Minimum consecutive successes for startup to be considered complete |
| `failureThreshold` | `5` | Consecutive failures before pod is marked as failed (50 seconds with default periodSeconds) |

### Auth Service Startup Probe

Configure the auth service startup probe in your `values.yaml`:

```yaml
auth:
  startupProbe:
    enabled: true
    path: /health
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 10
    successThreshold: 1
    failureThreshold: 5
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `enabled` | `false` | Whether to enable the startup probe |
| `path` | `/health` | HTTP endpoint to check for startup completion |
| `initialDelaySeconds` | `0` | Seconds to wait before first startup probe |
| `periodSeconds` | `10` | How often to perform the startup probe |
| `timeoutSeconds` | `10` | Seconds before startup probe times out |
| `successThreshold` | `1` | Minimum consecutive successes for startup to be considered complete |
| `failureThreshold` | `5` | Consecutive failures before pod is marked as failed (50 seconds with default periodSeconds) |

**Example: Enabling startup probes for slow-starting environments**

If your pods consistently take 60-90 seconds to initialize:

```yaml
identity:
  startupProbe:
    enabled: true
    failureThreshold: 12
    periodSeconds: 10
    timeoutSeconds: 5

auth:
  startupProbe:
    enabled: true
    failureThreshold: 12
    periodSeconds: 10
    timeoutSeconds: 5
```

This configuration allows up to 120 seconds (12 × 10) for startup before the pod is considered failed.

**Example: Using a custom startup health endpoint**

If your application exposes a dedicated startup endpoint:

```yaml
identity:
  startupProbe:
    enabled: true
    path: /startup
    failureThreshold: 10
    periodSeconds: 5
```

> **Note:** The startup probe uses the same service port as readiness and liveness probes. Ensure your application's startup endpoint is accessible on the configured service port.

> **Warning:** Setting `failureThreshold` too low may cause pods to restart before they finish initializing. Setting it too high may delay the detection of genuinely failed pods. Monitor your application's typical startup time and adjust accordingly.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.3.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.3.0 -n plugin-access-manager
```
