<!-- {% raw %} -->
# Helm Upgrade from v1.4.1 to v1.4.2

## Topics

- **[Fixes](#fixes)**
  - [Graceful shutdown configuration](#graceful-shutdown-configuration)

## Fixes

### Graceful shutdown configuration

The chart now explicitly sets `terminationGracePeriodSeconds` on the br-sisbajud deployment to ensure graceful shutdown of Kafka producers and other streaming resources. Previously, the chart relied on Kubernetes' default 30-second termination grace period, which could be insufficient for draining in-flight messages.

| Setting | v1.4.1 | v1.4.2 |
|---------|--------|--------|
| `brSisbajud.terminationGracePeriodSeconds` | Not set (Kubernetes default: 30s) | `55` (15s drain delay + 30s shutdown budget + 10s margin) |
| `SHUTDOWN_DRAIN_DELAY` environment variable | Not set | `"15s"` (default) |

**Before (v1.4.1):**

The deployment template did not set `terminationGracePeriodSeconds`, relying on Kubernetes' default 30-second grace period. The application's `STREAMING_CLOSE_TIMEOUT_S` (default `"20"`) was validated to be below 30 seconds, but there was no explicit delay before shutdown began.

```yaml
spec:
  template:
    spec:
      serviceAccountName: {{ include "br-sisbajud.serviceAccountName" . }}
      automountServiceAccountToken: false
      # terminationGracePeriodSeconds not set (Kubernetes default: 30s)
      containers:
        - name: br-sisbajud
          env:
            - name: STREAMING_CLOSE_TIMEOUT_S
              value: "20"
```

**After (v1.4.2):**

The deployment now sets `terminationGracePeriodSeconds: 55` and injects a new `SHUTDOWN_DRAIN_DELAY` environment variable (default `"15s"`). This ensures the application waits 15 seconds after receiving SIGTERM before starting the shutdown sequence, allowing load balancers and service meshes to remove the pod from rotation.

```yaml
spec:
  template:
    spec:
      serviceAccountName: {{ include "br-sisbajud.serviceAccountName" . }}
      automountServiceAccountToken: false
      terminationGracePeriodSeconds: 55
      containers:
        - name: br-sisbajud
          env:
            - name: SHUTDOWN_DRAIN_DELAY
              value: "15s"
            - name: STREAMING_CLOSE_TIMEOUT_S
              value: "20"
```

#### Why this matters

When Kubernetes sends SIGTERM to a pod, the following happens in parallel:

1. The pod is removed from service endpoints
2. The application receives SIGTERM and begins shutdown

Without a drain delay, the application may start rejecting requests before load balancers have removed it from rotation, causing 502/503 errors for in-flight requests.

The new shutdown timeline is:

1. **0s**: SIGTERM received
2. **0-15s**: `SHUTDOWN_DRAIN_DELAY` — application continues serving requests while endpoints are updated
3. **15-45s**: Shutdown sequence (30s budget) — application stops accepting new requests, drains Kafka producers (up to `STREAMING_CLOSE_TIMEOUT_S` = 20s), closes database connections
4. **45-55s**: 10s safety margin before SIGKILL

> **Important:** The `terminationGracePeriodSeconds` value (55s) must always be greater than `SHUTDOWN_DRAIN_DELAY` (15s) + `STREAMING_CLOSE_TIMEOUT_S` (20s) + a safety margin. The chart enforces that `STREAMING_CLOSE_TIMEOUT_S` stays below 30s (the shutdown budget), not the full grace period.

#### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `"15s"` | Time to wait after SIGTERM before starting shutdown sequence, allowing load balancers to remove the pod from rotation |

#### New configuration flags

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.terminationGracePeriodSeconds` | `55` | Kubernetes termination grace period (must be ≥ drain delay + shutdown budget + margin) |

#### Customizing shutdown timing

To override the default shutdown timing, add the following to your `values.yaml`:

```yaml
brSisbajud:
  # Increase grace period for slower Kafka clusters
  terminationGracePeriodSeconds: 75
  configmap:
    # Wait longer for endpoint updates
    SHUTDOWN_DRAIN_DELAY: "20s"
  streaming:
    # Allow more time for producer drain/flush
    closeTimeoutS: "30"
```

> **Warning:** Never set `terminationGracePeriodSeconds` lower than 55 seconds. The chart comment states: "never lower it." If you increase `SHUTDOWN_DRAIN_DELAY` or `closeTimeoutS`, you must increase `terminationGracePeriodSeconds` proportionally.

#### Validation changes

The chart's validation logic has been updated to reflect the new shutdown budget:

**Before (v1.4.1):**

```yaml
{{- if or (not (regexMatch "^[0-9]+$" $closeS)) (ge (atoi $closeS) 30) -}}
{{- fail (printf "\n\nERROR: br-sisbajud: STREAMING_CLOSE_TIMEOUT_S must be a whole number of seconds below the pod terminationGracePeriodSeconds (Kubernetes default 30; this chart does not override it), got %q.\n  set: brSisbajud.streaming.closeTimeoutS (default \"20\")\n" $closeS) -}}
{{- end -}}
```

**After (v1.4.2):**

```yaml
{{- if or (not (regexMatch "^[0-9]+$" $closeS)) (ge (atoi $closeS) 30) -}}
{{- fail (printf "\n\nERROR: br-sisbajud: STREAMING_CLOSE_TIMEOUT_S must be a whole number of seconds below the 30s shutdown budget that runs inside terminationGracePeriodSeconds, got %q.\n  set: brSisbajud.streaming.closeTimeoutS (default \"20\")\n" $closeS) -}}
{{- end -}}
```

The validation now clarifies that `STREAMING_CLOSE_TIMEOUT_S` must stay below the 30-second shutdown budget (which runs after the drain delay), not the full `terminationGracePeriodSeconds`.

#### Migration steps

No action is required. The chart automatically applies the new defaults:

1. `terminationGracePeriodSeconds: 55` is set on the deployment
2. `SHUTDOWN_DRAIN_DELAY: "15s"` is injected into the ConfigMap

Existing deployments will be updated with these values on the next `helm upgrade`.

> **Note:** If you previously customized `STREAMING_CLOSE_TIMEOUT_S` to a value close to 30 seconds, verify that your total shutdown time (drain delay + close timeout) fits within the 55-second grace period. For example, with `SHUTDOWN_DRAIN_DELAY: "15s"` and `closeTimeoutS: "25"`, the total is 40 seconds, leaving a 15-second margin before SIGKILL.

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.4.2 -n br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.4.2 -n br-sisbajud
```
<!-- {% endraw %} -->
