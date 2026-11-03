<!-- {% raw %} -->
# Helm Upgrade from v10.1.0 to v10.1.1

## Topics

- **[Fixes](#fixes)**
  - [1. CRM probe timeout adjustments](#1-crm-probe-timeout-adjustments)
  - [2. Ledger probe timeout adjustments](#2-ledger-probe-timeout-adjustments)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. CRM probe timeout adjustments

The default timeout values for CRM readiness and liveness probes have been increased from 1 second to 3 seconds.

| Setting | v10.1.0 | v10.1.1 |
|---------|---------|---------|
| `crm.readinessProbe.timeoutSeconds` (default) | `1` | `3` |
| `crm.livenessProbe.timeoutSeconds` (default) | `1` | `3` |

**Why this matters:**

With a 1-second timeout, Kubernetes would mark the probe as failed even when the CRM service was healthy but simply took slightly longer to respond. This could lead to unnecessary pod restarts (liveness probe) or premature removal from service endpoints (readiness probe), causing service disruptions.

**Before (v10.1.0):**

```yaml
readinessProbe:
  httpGet:
    path: {{ .Values.crm.readinessProbe.path | default "/readyz" }}
    port: {{ .Values.crm.service.port }}
  initialDelaySeconds: {{ .Values.crm.readinessProbe.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.crm.readinessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.crm.readinessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ .Values.crm.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.crm.readinessProbe.failureThreshold | default 3 }}
livenessProbe:
  httpGet:
    path: {{ .Values.crm.livenessProbe.path | default "/health" }}
    port: {{ .Values.crm.service.port }}
  initialDelaySeconds: {{ .Values.crm.livenessProbe.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.crm.livenessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.crm.livenessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ .Values.crm.livenessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.crm.livenessProbe.failureThreshold | default 3 }}
```

**After (v10.1.1):**

```yaml
readinessProbe:
  httpGet:
    path: {{ .Values.crm.readinessProbe.path | default "/readyz" }}
    port: {{ .Values.crm.service.port }}
  initialDelaySeconds: {{ .Values.crm.readinessProbe.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.crm.readinessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.crm.readinessProbe.timeoutSeconds | default 3 }}
  successThreshold: {{ .Values.crm.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.crm.readinessProbe.failureThreshold | default 3 }}
livenessProbe:
  httpGet:
    path: {{ .Values.crm.livenessProbe.path | default "/health" }}
    port: {{ .Values.crm.service.port }}
  initialDelaySeconds: {{ .Values.crm.livenessProbe.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.crm.livenessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.crm.livenessProbe.timeoutSeconds | default 3 }}
  successThreshold: {{ .Values.crm.livenessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.crm.livenessProbe.failureThreshold | default 3 }}
```

> **Note:** This change only affects the **default** timeout value. If you have explicitly set `crm.readinessProbe.timeoutSeconds` or `crm.livenessProbe.timeoutSeconds` in your values overrides, your custom values will continue to be used.

### 2. Ledger probe timeout adjustments

The default timeout values for ledger readiness and liveness probes have been increased to provide more tolerance for slower health check responses.

| Setting | v10.1.0 | v10.1.1 |
|---------|---------|---------|
| `ledger.livenessProbe.timeoutSeconds` (default) | `1` | `3` |
| `ledger.readinessProbe.timeoutSeconds` (default) | `1` | `16` |

**Why this matters:**

The ledger service has more complex health check requirements than other components:
- The readiness probe timeout increase from 1 to **16 seconds** is significantly larger because the ledger readiness check performs more extensive validation, including:
  - Database connectivity checks to multiple datastores (MongoDB for CRM/Fees, PostgreSQL for ledger data)
  - Message broker connectivity verification
  - Dependency health validation

**Before (v10.1.0):**

```yaml
livenessProbe:
  httpGet:
    path: {{ .Values.ledger.livenessProbe.path | default "/health" }}
    port: http
  initialDelaySeconds: {{ .Values.ledger.livenessProbe.initialDelaySeconds | default 0 }}
  periodSeconds: {{ .Values.ledger.livenessProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ .Values.ledger.livenessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ .Values.ledger.livenessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.ledger.livenessProbe.failureThreshold | default 3 }}
readinessProbe:
  httpGet:
    path: {{ .Values.ledger.readinessProbe.path | default "/readyz" }}
    port: http
  initialDelaySeconds: {{ .Values.ledger.readinessProbe.initialDelaySeconds | default 0 }}
  periodSeconds: {{ .Values.ledger.readinessProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ .Values.ledger.readinessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ .Values.ledger.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.ledger.readinessProbe.failureThreshold | default 3 }}
```

**After (v10.1.1):**

```yaml
livenessProbe:
  httpGet:
    path: {{ .Values.ledger.livenessProbe.path | default "/health" }}
    port: http
  initialDelaySeconds: {{ .Values.ledger.livenessProbe.initialDelaySeconds | default 0 }}
  periodSeconds: {{ .Values.ledger.livenessProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ .Values.ledger.livenessProbe.timeoutSeconds | default 3 }}
  successThreshold: {{ .Values.ledger.livenessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.ledger.livenessProbe.failureThreshold | default 3 }}
readinessProbe:
  httpGet:
    path: {{ .Values.ledger.readinessProbe.path | default "/readyz" }}
    port: http
  initialDelaySeconds: {{ .Values.ledger.readinessProbe.initialDelaySeconds | default 0 }}
  periodSeconds: {{ .Values.ledger.readinessProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ .Values.ledger.readinessProbe.timeoutSeconds | default 16 }}
  successThreshold: {{ .Values.ledger.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.ledger.readinessProbe.failureThreshold | default 3 }}
```

> **Note:** The 16-second readiness probe timeout is intentionally much higher than the liveness probe timeout. Readiness probes determine when a pod can receive traffic, so a longer timeout prevents premature removal from service endpoints. Liveness probes determine when to restart a pod, so a shorter timeout allows faster recovery from true failures.

> **Warning:** If you have explicitly set `ledger.readinessProbe.timeoutSeconds` to a value lower than 16 seconds and are experiencing intermittent readiness probe failures, consider removing your override to adopt the new default.

## Configuration Reference

### Updated probe timeout defaults

| Field | Previous Default | New Default | Description |
|-------|------------------|-------------|-------------|
| `crm.readinessProbe.timeoutSeconds` | `1` | `3` | Seconds before the CRM readiness probe times out. |
| `crm.livenessProbe.timeoutSeconds` | `1` | `3` | Seconds before the CRM liveness probe times out. |
| `ledger.livenessProbe.timeoutSeconds` | `1` | `3` | Seconds before the ledger liveness probe times out. |
| `ledger.readinessProbe.timeoutSeconds` | `1` | `16` | Seconds before the ledger readiness probe times out. Significantly increased to accommodate complex multi-datastore health checks. |

## Migration Steps

### For all operators

No action is required. The new probe timeout defaults will be applied automatically during the upgrade.

The upgrade will trigger rolling restarts of CRM and ledger pods due to the Deployment template changes. This is expected behavior and the restarts will follow the standard Kubernetes rolling update strategy:
- New pods will wait for readiness probes to pass before receiving traffic
- Old pods will continue serving traffic until new pods are ready

### For operators with custom probe timeout overrides

If you have explicitly set probe timeout values in your values overrides, review whether your custom values are still appropriate:

1. **If you set timeouts lower than the new defaults** (e.g., `timeoutSeconds: 1`) and have experienced probe failures, consider removing your override to adopt the new defaults.

2. **If you set timeouts higher than the new defaults** (e.g., `timeoutSeconds: 5` or `timeoutSeconds: 20`), keep your overrides. Your custom values will continue to be used and may be appropriate for your specific environment.

3. **If you are unsure**, perform a dry-run upgrade and check the rendered probe configurations:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm \
  --version 10.1.1 \
  -n midaz \
  --dry-run \
  --debug | grep -A 10 "readinessProbe:\|livenessProbe:"
```

### For operators experiencing probe failures

If you have been experiencing intermittent probe failures (visible in pod events as `Readiness probe failed` or `Liveness probe failed`), check them after upgrading:

1. Monitor pod events after the upgrade:

```bash
kubectl get events -n midaz --sort-by='.lastTimestamp' | grep -i probe
```

2. If probe failures persist after the upgrade, the issue may be related to actual service health rather than timeout configuration. Check service logs:

```bash
kubectl logs -n midaz -l app.kubernetes.io/name=midaz-crm --tail=100
kubectl logs -n midaz -l app.kubernetes.io/name=midaz-ledger --tail=100
```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.1 -n midaz
```
<!-- {% endraw %} -->
