# Helm Upgrade from v2.x to v3.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Configurable liveness and readiness probes](#1-configurable-liveness-and-readiness-probes)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a major version release that exposes the deployment liveness and readiness probes through `values.yaml`, allowing operators to customize probe behavior without modifying templates. The application version remains unchanged.

| Field | v2.3.0 | v3.0.0 |
|-------|--------|--------|
| Chart version | `2.3.0` | `3.0.0` |
| App version | `1.6.0` | `1.6.0` |

## Features

### 1. Configurable liveness and readiness probes

The deployment template now reads all probe settings from `values.yaml` instead of using hardcoded values. Two new top-level configuration blocks have been introduced:

| Key | v2.3.0 | v3.0.0 |
|-----|--------|--------|
| `livenessProbe` | not present (hardcoded in template) | `{}` (overridable) |
| `readinessProbe` | not present (hardcoded in template) | `{}` (overridable) |

Both blocks default to `{}`, which preserves the existing hardcoded behavior. When fields are omitted, the chart applies built-in defaults that match the previous template values.

**Built-in defaults (applied when fields are not specified):**

```yaml
livenessProbe:
  path: /
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3

readinessProbe:
  path: /
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
```

**Supported probe fields:**

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | HTTP path for the probe endpoint |
| `initialDelaySeconds` | integer | Seconds after container start before probe is initiated |
| `periodSeconds` | integer | How often (in seconds) to perform the probe |
| `timeoutSeconds` | integer | Seconds after which the probe times out |
| `successThreshold` | integer | Minimum consecutive successes for the probe to be considered successful |
| `failureThreshold` | integer | Minimum consecutive failures for the probe to be considered failed |

**Template changes:**

**Before (v2.3.0):**

```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**After (v3.0.0):**

```yaml
livenessProbe:
  httpGet:
    path: {{ .Values.livenessProbe.path | default "/" }}
    port: http
  initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds | default 30 }}
  periodSeconds: {{ .Values.livenessProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds | default 5 }}
  successThreshold: {{ .Values.livenessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.livenessProbe.failureThreshold | default 3 }}
readinessProbe:
  httpGet:
    path: {{ .Values.readinessProbe.path | default "/" }}
    port: http
  initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.readinessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds | default 3 }}
  successThreshold: {{ .Values.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.readinessProbe.failureThreshold | default 3 }}
```

**Operational impact:**

- All probe parameters can now be tuned via `values.yaml` without template modifications
- The `successThreshold` field is now explicitly rendered for both probes (previously omitted, defaulted to 1 by Kubernetes)
- Existing deployments will continue to use the same probe settings unless explicitly overridden

**Example customization:**

```yaml
livenessProbe:
  initialDelaySeconds: 45
  failureThreshold: 5
  path: /health

readinessProbe:
  path: /ready
  periodSeconds: 10
  timeoutSeconds: 5
```

## Configuration Changes

No existing keys were removed or renamed. The `livenessProbe` and `readinessProbe` blocks are additive and fully optional.

| Setting | v2.3.0 | v3.0.0 | Notes |
|---------|--------|--------|-------|
| `livenessProbe` | absent | `{}` | New, optional, overrides built-in defaults |
| `readinessProbe` | absent | `{}` | New, optional, overrides built-in defaults |

**Configuration reference:**

```yaml
# -- Readiness probe configuration. All fields override chart defaults.
readinessProbe: {}
  # path: /
  # initialDelaySeconds: 10
  # periodSeconds: 5
  # timeoutSeconds: 3
  # successThreshold: 1
  # failureThreshold: 3

# -- Liveness probe configuration. All fields override chart defaults.
livenessProbe: {}
  # path: /
  # initialDelaySeconds: 30
  # periodSeconds: 10
  # timeoutSeconds: 5
  # successThreshold: 1
  # failureThreshold: 3
```

## Migration Steps

This upgrade requires no mandatory values changes. The Helm upgrade will roll the deployment with the same probe behavior unless you choose to customize probe settings.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. (Optional) If you want to customize probe behavior, prepare your values override file:

```yaml
# custom-values.yaml
readinessProbe:
  initialDelaySeconds: 15
  periodSeconds: 10

livenessProbe:
  initialDelaySeconds: 45
  failureThreshold: 5
```

3. Run the upgrade command during a maintenance window.

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n product-console
```

5. Check probe configuration in the running pods:

```bash
kubectl describe pod -n product-console -l app.kubernetes.io/name=product-console | grep -A10 "Liveness\|Readiness"
```

6. Monitor service logs for any startup or probe failures:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

> **Note:** The upgrade triggers a rolling restart of the `product-console` deployment. Pods will be replaced one at a time according to the deployment strategy.

> **Important:** If you customize probe paths (e.g., `readinessProbe.path: /healthz`), ensure your application image exposes those endpoints. If the probe returns non-2xx status codes, pods will not become Ready and the rollout will pause.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 3.0.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 3.0.0 -n product-console
```

**With custom probe configuration:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 3.0.0 \
  --set readinessProbe.initialDelaySeconds=15 \
  --set livenessProbe.failureThreshold=5 \
  -n product-console
```
