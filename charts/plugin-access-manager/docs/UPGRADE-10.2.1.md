<!-- {% raw %} -->
# Helm Upgrade from v10.2.0 to v10.2.1

# Topics

- **[Fixes](#fixes)**
  - [1. Health Probe Timeout Adjustments](#1-health-probe-timeout-adjustments)
  - [2. Caradhras Graceful Shutdown Configuration](#2-caradhras-graceful-shutdown-configuration)

# Fixes

### 1. Health Probe Timeout Adjustments

Chart **10.2.1** increases the default timeout values for readiness and liveness probes across all components to prevent premature probe failures under load or slow network conditions.

**What changed:**

The default `timeoutSeconds` values for health probes have been increased across the auth, identity, caradhras, and caradhras-ui deployments. These changes affect both the hardcoded defaults in deployment templates and the helper template defaults.

| Component | Probe Type | v10.2.0 Default | v10.2.1 Default |
|-----------|------------|-----------------|-----------------|
| Auth | Readiness | 1s | 8s |
| Auth | Liveness | 1s | 3s |
| Identity | Readiness | 1s | 8s |
| Identity | Liveness | 1s | 3s |
| Caradhras (helper default) | Readiness | 1s | 3s |
| Caradhras (helper default) | Liveness | 1s | 3s |
| Caradhras UI | Readiness | (unset, defaulted to 1s) | 3s |
| Caradhras UI | Liveness | (unset, defaulted to 1s) | 3s |

**Why this matters:**

- **Prevents false positives:** The 1-second default was too aggressive for production environments, especially when pods experience temporary CPU throttling, network latency, or are under load
- **Reduces restart churn:** Pods that were flapping into `CrashLoopBackOff` due to probe timeout failures alone will now remain stable
- **Aligns with best practices:** Kubernetes probes should allow sufficient time for the application to respond, particularly for readiness checks that may involve database or external service health verification

**Before (v10.2.0):**

```yaml
# templates/auth/deployment.yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: 8080
  initialDelaySeconds: 25
  periodSeconds: 5
  timeoutSeconds: 1  # too aggressive
  successThreshold: 1
  failureThreshold: 3
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
  timeoutSeconds: 1  # too aggressive
  successThreshold: 1
  failureThreshold: 3
```

```yaml
# templates/_helpers.tpl
{{- define "caradhras.readinessProbeTimeoutSeconds" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.readinessProbe.timeoutSeconds "oldVal" (dig "backend" "readinessProbe" "timeoutSeconds" "" .Values.auth) "default" 1) -}}
{{- end }}
```

**After (v10.2.1):**

```yaml
# templates/auth/deployment.yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: 8080
  initialDelaySeconds: 25
  periodSeconds: 5
  timeoutSeconds: 8  # increased for readiness
  successThreshold: 1
  failureThreshold: 3
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
  timeoutSeconds: 3  # increased for liveness
  successThreshold: 1
  failureThreshold: 3
```

```yaml
# templates/_helpers.tpl
{{- define "caradhras.readinessProbeTimeoutSeconds" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.readinessProbe.timeoutSeconds "oldVal" (dig "backend" "readinessProbe" "timeoutSeconds" "" .Values.auth) "default" 3) -}}
{{- end }}
```

**Operational impact:**

- **No action required:** The new defaults apply automatically on upgrade unless you have explicitly overridden `timeoutSeconds` in your values
- **Existing overrides still win:** If you've set explicit timeout values in your values.yaml, they remain unchanged
- **Probe behavior change:** Pods will wait longer for health check responses before marking the probe as failed. This means:
  - A pod under load may take up to 8 seconds to respond to readiness checks before being marked unready (previously 1 second)
  - A pod under load may take up to 3 seconds to respond to liveness checks before being restarted (previously 1 second)
- **Failure detection time:** With `failureThreshold: 3` and `periodSeconds: 5`, a truly unhealthy pod will be detected within 15 seconds for readiness (unchanged) and liveness (unchanged), but transient slowness is now tolerated

**Example: Keeping custom timeout values**

If you have specific timeout requirements, continue to override them in your values:

```yaml
auth:
  readinessProbe:
    timeoutSeconds: 5
  livenessProbe:
    timeoutSeconds: 2

identity:
  readinessProbe:
    timeoutSeconds: 5
  livenessProbe:
    timeoutSeconds: 2

caradhras:
  readinessProbe:
    timeoutSeconds: 5
  livenessProbe:
    timeoutSeconds: 2
```

> **Note:** The identity and auth components perform database health checks in their readiness probes, which is why their readiness timeout (8s) is higher than their liveness timeout (3s). The liveness probe is a simpler health check that should respond faster.

### 2. Caradhras Graceful Shutdown Configuration

Chart **10.2.1** adds graceful shutdown handling to the caradhras deployment to prevent connection errors during pod termination.

**What changed:**

The caradhras deployment now includes:
- A `preStop` lifecycle hook that delays SIGTERM by 15 seconds
- A `terminationGracePeriodSeconds` of 55 seconds (previously used the Kubernetes default of 30 seconds)

**Before (v10.2.0):**

```yaml
# templates/caradhras/deployment.yaml
spec:
  template:
    spec:
      # terminationGracePeriodSeconds not set (defaults to 30s)
      containers:
      - name: caradhras
        # no lifecycle hooks
        resources:
          {{- toYaml .Values.caradhras.resources | nindent 12 }}
        readinessProbe:
          # ...
```

**After (v10.2.1):**

```yaml
# templates/caradhras/deployment.yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 55
      containers:
      - name: caradhras
        resources:
          {{- toYaml .Values.caradhras.resources | nindent 12 }}
        lifecycle:
          preStop:
            exec:
              command: ["sleep", "15"]
        readinessProbe:
          # ...
```

**Why this matters:**

- **Prevents connection errors during rolling updates:** When a caradhras pod is terminated, Kubernetes immediately removes it from service endpoints. However, kube-proxy and ingress controllers may take several seconds to update their routing tables. Without the preStop delay, in-flight requests can be routed to a pod that has already started shutting down.
- **Allows clean connection draining:** The 15-second sleep gives:
  - Kubernetes time to deregister the pod from endpoints
  - Load balancers and ingress controllers time to stop routing new traffic
  - Existing connections time to complete before the application receives SIGTERM
- **Coordinates with application shutdown timeout:** The caradhras application has a `SHUTDOWN_TIMEOUT_SEC` of 30 seconds (configurable via environment variable). The total grace period (55s) accounts for:
  - 15s preStop delay (endpoint deregistration)
  - 30s application shutdown timeout (drain existing requests)
  - 10s buffer for cleanup and final termination

**Operational impact:**

- **No action required:** The graceful shutdown configuration is applied automatically on upgrade
- **Rolling update behavior:** During a rolling update, caradhras pods will take up to 55 seconds to fully terminate instead of the previous 30 seconds. This is expected and ensures zero-downtime deployments.
- **Pod eviction timing:** If you manually drain nodes or scale down, be aware that caradhras pods will take up to 55 seconds to terminate gracefully

**Shutdown sequence:**

1. Kubernetes sends SIGTERM to the pod
2. Kubernetes removes the pod from service endpoints
3. The preStop hook executes: `sleep 15` (allows endpoint deregistration to propagate)
4. After 15 seconds, SIGTERM is delivered to the caradhras process
5. Caradhras begins graceful shutdown: stops accepting new requests, drains existing connections (up to 30s)
6. After 45 seconds total (15s + 30s), caradhras should have exited cleanly
7. If the process is still running after 55 seconds, Kubernetes sends SIGKILL

> **Important:** If you have customized the `SHUTDOWN_TIMEOUT_SEC` environment variable for caradhras (via `caradhras.extraEnvVars`), ensure that `terminationGracePeriodSeconds` is at least `15 + SHUTDOWN_TIMEOUT_SEC + 10`. The chart does not automatically adjust this value based on your custom shutdown timeout.

**Example: Customizing shutdown timing**

If you need a longer application shutdown timeout:

```yaml
caradhras:
  extraEnvVars:
    - name: SHUTDOWN_TIMEOUT_SEC
      value: "60"
  
  # You must also increase terminationGracePeriodSeconds
  # This requires patching the deployment template, which is not directly supported via values
  # Contact support or use a post-renderer if you need this customization
```

> **Note:** The chart does not currently expose `terminationGracePeriodSeconds` as a configurable value. If you need to adjust it, you must use a Helm post-renderer or Kustomize overlay.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.1 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.1 -n plugin-access-manager
```
<!-- {% endraw %} -->
