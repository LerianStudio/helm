<!-- {% raw %} -->
# Helm Upgrade from v9.7.2 to v9.7.3

## Topics

- **[Fixes](#fixes)**
  - [1. Ledger: Configurable termination grace period](#1-ledger-configurable-termination-grace-period)
  - [2. Tracer: Configurable termination grace period](#2-tracer-configurable-termination-grace-period)

## Fixes

### 1. Ledger: Configurable termination grace period

The ledger service now supports a configurable `terminationGracePeriodSeconds` to ensure graceful shutdown of in-flight operations.

#### What changed

A new Helm value has been introduced to control how long Kubernetes waits after sending SIGTERM before forcefully killing the ledger pod:

| Setting | v9.7.2 | v9.7.3 |
|---------|--------|--------|
| `ledger.terminationGracePeriodSeconds` | Not configurable (Kubernetes default: 30s) | `60` (configurable) |

#### Why it matters

The ledger service may handle:
- In-flight HTTP requests
- Streaming events
- Message producer flush operations (e.g., Kafka, RabbitMQ)

A termination grace period of 60 seconds ensures these operations complete cleanly before the pod is killed, preventing data loss or incomplete transactions during rolling updates or pod evictions.

#### Configuration

The new value is set in `values.yaml`:

```yaml
ledger:
  # -- Seconds Kubernetes waits after SIGTERM before killing the pod. Must cover the
  # shutdown drain: in-flight HTTP requests, in-flight streaming events, producer flush.
  terminationGracePeriodSeconds: 60
```

This value is applied in the ledger Deployment template:

**Before (v9.7.2):**

```yaml
spec:
  template:
    spec:
      serviceAccountName: {{ include "midaz-ledger.serviceAccountName" . }}
      # terminationGracePeriodSeconds not set (defaults to 30)
```

**After (v9.7.3):**

```yaml
spec:
  template:
    spec:
      serviceAccountName: {{ include "midaz-ledger.serviceAccountName" . }}
      terminationGracePeriodSeconds: {{ .Values.ledger.terminationGracePeriodSeconds }}
```

#### Migration steps

No action is required. The default value of `60` seconds is applied automatically during upgrade.

If your ledger workload requires a different grace period (e.g., longer for high-throughput environments or shorter for faster rollouts), override the value:

```yaml
ledger:
  terminationGracePeriodSeconds: 90
```

> **Note:** Ensure the grace period is long enough to cover your longest-running request or producer flush timeout. Monitor pod termination logs during the first rollout after upgrade to verify graceful shutdown.

### 2. Tracer: Configurable termination grace period

The tracer service now supports a configurable `terminationGracePeriodSeconds` to ensure graceful shutdown of in-flight operations.

#### What changed

A new Helm value has been introduced to control how long Kubernetes waits after sending SIGTERM before forcefully killing the tracer pod:

| Setting | v9.7.2 | v9.7.3 |
|---------|--------|--------|
| `tracer.terminationGracePeriodSeconds` | Not configurable (Kubernetes default: 30s) | `45` (configurable) |

#### Why it matters

The tracer service may handle:
- In-flight HTTP requests
- Streaming events
- Message producer flush operations (e.g., Kafka, RabbitMQ)

A termination grace period of 45 seconds ensures these operations complete cleanly before the pod is killed, preventing data loss or incomplete trace events during rolling updates or pod evictions.

#### Configuration

The new value is set in `values.yaml`:

```yaml
tracer:
  # -- Seconds Kubernetes waits after SIGTERM before killing the pod. Must cover the
  # shutdown drain: in-flight HTTP requests, in-flight streaming events, producer flush.
  terminationGracePeriodSeconds: 45
```

This value is applied in the tracer Deployment template:

**Before (v9.7.2):**

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
    {{- end }}
      # terminationGracePeriodSeconds not set (defaults to 30)
      {{- with .Values.tracer.podSecurityContext }}
```

**After (v9.7.3):**

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
    {{- end }}
      terminationGracePeriodSeconds: {{ .Values.tracer.terminationGracePeriodSeconds }}
      {{- with .Values.tracer.podSecurityContext }}
```

#### Migration steps

No action is required. The default value of `45` seconds is applied automatically during upgrade.

If your tracer workload requires a different grace period, override the value:

```yaml
tracer:
  terminationGracePeriodSeconds: 60
```

> **Note:** The tracer default (45s) is shorter than ledger (60s) because tracer workloads typically have lighter shutdown requirements. Adjust based on your observability pipeline's flush timeouts.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.3 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.3 -n midaz
```
<!-- {% endraw %} -->
