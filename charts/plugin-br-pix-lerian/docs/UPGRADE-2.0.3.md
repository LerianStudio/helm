<!-- {% raw %} -->
# Helm Upgrade from v2.0.2 to v2.0.3

## Topics

- **[Fixes](#fixes)**
  - [1. Health Probe Timeout Increased](#1-health-probe-timeout-increased)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Health Probe Timeout Increased

**What changed:**

The default `timeoutSeconds` for both `readinessProbe` and `livenessProbe` has been increased from `1` to `3` seconds across all component Deployments.

| Setting | v2.0.2 | v2.0.3 |
|---------|--------|--------|
| `readinessProbe.timeoutSeconds` (default) | `1` | `3` |
| `livenessProbe.timeoutSeconds` (default) | `1` | `3` |

**Why it matters:**

A 1-second probe timeout is aggressive and can cause false negatives in environments with network latency, CPU contention, or slow-starting containers. Pods may be marked unready or restarted unnecessarily, leading to service disruption during normal operation or deployment rollouts.

The new 3-second default provides a more realistic timeout window while still detecting genuine health issues quickly. This change reduces the risk of probe-induced restarts in production environments.

**How to handle it:**

#### Option 1: Accept the new default (recommended)

No action is required. The new 3-second timeout will be applied automatically on upgrade. This is the recommended configuration for production environments.

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.3 -n plugin-br-pix-lerian
```

#### Option 2: Keep the 1-second timeout

If your environment requires the stricter 1-second timeout (e.g., for low-latency SLA requirements), explicitly set it for each component before upgrading:

```yaml
adapterLerian:
  readinessProbe:
    timeoutSeconds: 1
  livenessProbe:
    timeoutSeconds: 1

adapterLerianSystemplane:
  readinessProbe:
    timeoutSeconds: 1
  livenessProbe:
    timeoutSeconds: 1

# Repeat for all components as needed
```

> **Warning:** A 1-second timeout may cause false negatives in environments with network latency or resource contention. Monitor probe failures closely if you choose to keep this value.

#### Option 3: Use a custom timeout

You can set any timeout value per component to match your specific requirements:

```yaml
cobHub:
  readinessProbe:
    timeoutSeconds: 5
  livenessProbe:
    timeoutSeconds: 5
```

**Affected components:**

All component Deployments in the chart:

- `adapter-lerian`
- `adapter-lerian-systemplane`
- `adapter-provider-mock`
- `cob-hub`
- `cob-proxy`
- `cob-systemplane`
- `dict-hub`
- `dict-hub-vsync`
- `dict-proxy`
- `dict-systemplane`
- `pixauto`
- `pixauto-systemplane`
- `spi`
- `spi-systemplane`

**Before (v2.0.2) deployment.yaml:**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  initialDelaySeconds: {{ include "plugin-br-pix-lerian.probeInitialDelay" (dict "probe" $values.readinessProbe "default" 10) }}
  periodSeconds: {{ $values.readinessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ $values.readinessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ $values.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ $values.readinessProbe.failureThreshold | default 3 }}
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: {{ include "plugin-br-pix-lerian.probeInitialDelay" (dict "probe" $values.livenessProbe "default" 5) }}
  periodSeconds: {{ $values.livenessProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ $values.livenessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ $values.livenessProbe.successThreshold | default 1 }}
  failureThreshold: {{ $values.livenessProbe.failureThreshold | default 3 }}
```

**After (v2.0.3) deployment.yaml:**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  initialDelaySeconds: {{ include "plugin-br-pix-lerian.probeInitialDelay" (dict "probe" $values.readinessProbe "default" 10) }}
  periodSeconds: {{ $values.readinessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ $values.readinessProbe.timeoutSeconds | default 3 }}
  successThreshold: {{ $values.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ $values.readinessProbe.failureThreshold | default 3 }}
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: {{ include "plugin-br-pix-lerian.probeInitialDelay" (dict "probe" $values.livenessProbe "default" 5) }}
  periodSeconds: {{ $values.livenessProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ $values.livenessProbe.timeoutSeconds | default 3 }}
  successThreshold: {{ $values.livenessProbe.successThreshold | default 1 }}
  failureThreshold: {{ $values.livenessProbe.failureThreshold | default 3 }}
```

**Operational impact:**

- **Reduced false negatives:** Pods are less likely to be marked unready or restarted due to transient network delays or CPU contention
- **Improved stability:** Fewer unnecessary pod restarts during normal operation and deployment rollouts
- **Slightly longer failure detection:** Genuine health check failures will take up to 2 seconds longer to detect (3s timeout vs 1s timeout)

> **Note:** The probe `periodSeconds` and `failureThreshold` remain unchanged, so the total time to detect a failing pod is still reasonable (e.g., readiness: 3 failures × 5s period = 15s; liveness: 3 failures × 10s period = 30s).

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.3 -n plugin-br-pix-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.3 -n plugin-br-pix-lerian
```
<!-- {% endraw %} -->
