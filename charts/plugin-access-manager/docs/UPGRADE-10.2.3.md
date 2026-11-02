<!-- {% raw %} -->
# Helm Upgrade from v10.2.2 to v10.2.3

# Topics

- **[Fixes](#fixes)**
  - [1. Graceful Shutdown Timing for Caradhras](#1-graceful-shutdown-timing-for-caradhras)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Graceful Shutdown Timing for Caradhras

Version 10.2.3 introduces a configurable shutdown drain delay for the caradhras component to improve graceful termination behavior during pod shutdown.

**What changed:**

A new environment variable `SHUTDOWN_DRAIN_DELAY` has been added to the caradhras deployment, and the termination grace period comment has been updated to reflect the new shutdown sequence.

| Setting | v10.2.2 | v10.2.3 |
|---------|---------|---------|
| `SHUTDOWN_DRAIN_DELAY` environment variable | Not present | `"5s"` |
| Termination grace period calculation | `15 + SHUTDOWN_TIMEOUT_SEC (30) + 10` | `15 + SHUTDOWN_DRAIN_DELAY (5) + SHUTDOWN_TIMEOUT_SEC (30) + 5` |

**Why this matters:**

During pod termination, Kubernetes sends a SIGTERM signal to the container and simultaneously removes the pod from service endpoints. This creates a race condition where:

1. The pod receives SIGTERM and begins shutdown
2. Endpoint controllers deregister the pod from Services/Ingresses
3. In-flight requests may still arrive at the pod during deregistration

The new `SHUTDOWN_DRAIN_DELAY` parameter configures how long the caradhras `/readyz` endpoint returns HTTP 503 (Service Unavailable) after receiving SIGTERM, while the main listener continues serving existing connections. This ensures:

- Load balancers and ingress controllers have time to deregister the pod
- New requests are rejected with 503 during the drain period
- Existing connections continue to be served gracefully
- The application only begins final shutdown after the drain delay expires

**Shutdown sequence:**

**Before (v10.2.2):**

1. Pod receives SIGTERM
2. PreStop hook sleeps for 15 seconds (allows endpoint deregistration)
3. Application begins shutdown with `SHUTDOWN_TIMEOUT_SEC` (30s) for graceful connection draining
4. Termination grace period: 15 + 30 + 10 = 55 seconds

**After (v10.2.3):**

1. Pod receives SIGTERM
2. PreStop hook sleeps for 15 seconds (allows endpoint deregistration)
3. `/readyz` returns 503 for `SHUTDOWN_DRAIN_DELAY` (5s) while listener still serves
4. Application begins shutdown with `SHUTDOWN_TIMEOUT_SEC` (30s) for graceful connection draining
5. Termination grace period: 15 + 5 + 30 + 5 = 55 seconds

**Template changes:**

**Before (v10.2.2):**

```yaml
# templates/caradhras/deployment.yaml
env:
  {{- if include "plugin-caradhras.redisPasswordEnabled" . }}
  {{- include "plugin-caradhras.redisPasswordEnv" . | nindent 10 }}
  {{- end }}
  {{ if (index .Values "otel-collector-lerian").enabled }}
  - name: "HOST_IP"
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://$(HOST_IP):4317"
  {{ end }}
resources:
  {{- toYaml .Values.caradhras.resources | nindent 12 }}
# Serve 15s before SIGTERM while endpoints deregister; grace = 15 + SHUTDOWN_TIMEOUT_SEC (30) + 10.
lifecycle:
  preStop:
    exec:
```

**After (v10.2.3):**

```yaml
# templates/caradhras/deployment.yaml
env:
  {{- if include "plugin-caradhras.redisPasswordEnabled" . }}
  {{- include "plugin-caradhras.redisPasswordEnv" . | nindent 10 }}
  {{- end }}
  # Readyz answers 503 for this long after SIGTERM while the listener still serves.
  - name: SHUTDOWN_DRAIN_DELAY
    value: "5s"
  {{ if (index .Values "otel-collector-lerian").enabled }}
  - name: "HOST_IP"
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://$(HOST_IP):4317"
  {{ end }}
resources:
  {{- toYaml .Values.caradhras.resources | nindent 12 }}
# Serve 15s before SIGTERM while endpoints deregister; grace = 15 + SHUTDOWN_DRAIN_DELAY (5) + SHUTDOWN_TIMEOUT_SEC (30) + 5.
lifecycle:
  preStop:
    exec:
```

**Operational impact:**

- The caradhras pod will handle termination more gracefully, reducing the likelihood of connection errors during rolling updates or pod evictions
- The total termination grace period remains 55 seconds (unchanged)
- No configuration changes are required; the new environment variable is hardcoded to `"5s"`
- Existing deployments will automatically adopt the new shutdown behavior on upgrade
- No pod restarts are required beyond the normal rolling update triggered by the deployment change

**Default behavior:**

The `SHUTDOWN_DRAIN_DELAY` is hardcoded to `"5s"` and is not configurable via `values.yaml`. This value has been chosen to balance:

- Sufficient time for endpoint deregistration in most Kubernetes environments
- Minimal delay before final shutdown begins
- Maintaining the same total termination grace period as v10.2.2

> **Note:** If you have customized `terminationGracePeriodSeconds` for the caradhras deployment, ensure it accounts for the new shutdown sequence: `preStop sleep (15s) + SHUTDOWN_DRAIN_DELAY (5s) + SHUTDOWN_TIMEOUT_SEC (30s) + buffer (5s)`.

### New Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `"5s"` | Duration that `/readyz` returns 503 after SIGTERM while the listener continues serving existing connections. Not configurable via values.yaml. |

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.3 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.3 -n plugin-access-manager
```
<!-- {% endraw %} -->
