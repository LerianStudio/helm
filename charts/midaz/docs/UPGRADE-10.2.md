<!-- {% raw %} -->
# Helm Upgrade from v10.1.1 to v10.2.0

## Topics

- **[Features](#features)**
  - [1. Graceful shutdown drain delay for ledger service](#1-graceful-shutdown-drain-delay-for-ledger-service)
  - [2. Graceful shutdown drain delay for tracer service](#2-graceful-shutdown-drain-delay-for-tracer-service)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Graceful shutdown drain delay for ledger service

The ledger service now includes a configurable shutdown drain delay to ensure graceful termination of in-flight requests, streaming events, and message producer flushes.

#### What changed

A new environment variable `SHUTDOWN_DRAIN_DELAY` has been added to the ledger deployment, and the `terminationGracePeriodSeconds` has been increased to accommodate the shutdown sequence.

**Before (v10.1.1):**

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 60
      containers:
        - name: ledger
          envFrom:
            - configMapRef:
                name: {{ include "midaz-ledger.fullname" . }}
          env:
            # No SHUTDOWN_DRAIN_DELAY
```

**After (v10.2.0):**

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 72
      containers:
        - name: ledger
          envFrom:
            - configMapRef:
                name: {{ include "midaz-ledger.fullname" . }}
          env:
            - name: SHUTDOWN_DRAIN_DELAY
              value: "15s"
```

#### Termination grace period changes

| Setting | v10.1.1 | v10.2.0 |
|---------|---------|---------|
| `ledger.terminationGracePeriodSeconds` | `60` | `72` |

The new grace period is calculated as:

```
72 seconds = 15s SHUTDOWN_DRAIN_DELAY + ~47s ledger shutdown + 10s margin
```

#### Why this matters

When Kubernetes sends a SIGTERM signal to terminate a pod:

1. The ledger service enters a drain phase for **15 seconds** (`SHUTDOWN_DRAIN_DELAY`)
2. During this drain phase:
   - New HTTP requests are rejected with 503 Service Unavailable
   - Existing in-flight HTTP requests are allowed to complete
   - Streaming event consumers finish processing current batches
   - Message producers flush pending messages to RabbitMQ
3. After the drain phase, the service begins its internal shutdown sequence (~47 seconds)
4. Kubernetes waits up to 72 seconds total before sending SIGKILL

This prevents:
- Abrupt termination of in-flight transactions
- Loss of uncommitted events in streaming pipelines
- Message loss due to unflushed producer buffers

#### Configuration

The `SHUTDOWN_DRAIN_DELAY` is hardcoded to `15s` in the deployment template. If you need to customize this value, you can override it using an environment variable patch:

```yaml
ledger:
  env:
    - name: SHUTDOWN_DRAIN_DELAY
      value: "20s"
```

> **Note:** If you increase `SHUTDOWN_DRAIN_DELAY`, you should also increase `terminationGracePeriodSeconds` accordingly. The grace period must be greater than the drain delay plus the expected shutdown time.

**Example with custom drain delay:**

```yaml
ledger:
  terminationGracePeriodSeconds: 80  # 20s drain + 47s shutdown + 13s margin
  env:
    - name: SHUTDOWN_DRAIN_DELAY
      value: "20s"
```

> **Warning:** Setting `terminationGracePeriodSeconds` too low may result in Kubernetes forcefully killing the pod before the ledger service completes its shutdown sequence, potentially causing data loss or inconsistencies.

### 2. Graceful shutdown drain delay for tracer service

The tracer service now includes the same graceful shutdown mechanism as the ledger service.

#### What changed

A new environment variable `SHUTDOWN_DRAIN_DELAY` has been added to the tracer deployment, and the `terminationGracePeriodSeconds` has been increased.

**Before (v10.1.1):**

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 45
      containers:
        - name: tracer
          envFrom:
            - configMapRef:
                name: {{ include "midaz-tracer.fullname" . }}
          env:
            # No SHUTDOWN_DRAIN_DELAY
```

**After (v10.2.0):**

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 55
      containers:
        - name: tracer
          envFrom:
            - configMapRef:
                name: {{ include "midaz-tracer.fullname" . }}
          env:
            - name: SHUTDOWN_DRAIN_DELAY
              value: "15s"
```

#### Termination grace period changes

| Setting | v10.1.1 | v10.2.0 |
|---------|---------|---------|
| `tracer.terminationGracePeriodSeconds` | `45` | `55` |

#### Why this matters

The tracer service handles event streaming and tracing data ingestion. The shutdown drain delay ensures:

- In-flight trace spans are flushed to storage
- Event consumers complete processing current batches
- No trace data is lost during pod termination

#### Configuration

Similar to the ledger service, the `SHUTDOWN_DRAIN_DELAY` is hardcoded to `15s`. You can override it if needed:

```yaml
tracer:
  terminationGracePeriodSeconds: 65  # 20s drain + shutdown time + margin
  env:
    - name: SHUTDOWN_DRAIN_DELAY
      value: "20s"
```

> **Important:** Both ledger and tracer services now require additional time for graceful shutdown. If you have custom pod disruption budgets (PDBs) or deployment strategies, ensure they account for the increased termination grace periods.

## Configuration Reference

### New environment variables

#### Ledger service

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `15s` | Duration to wait before starting shutdown, allowing in-flight requests to complete |

#### Tracer service

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `15s` | Duration to wait before starting shutdown, allowing in-flight trace spans to flush |

### Termination grace period settings

| Service | Setting | v10.1.1 | v10.2.0 | Calculation |
|---------|---------|---------|---------|-------------|
| Ledger | `terminationGracePeriodSeconds` | `60` | `72` | 15s drain + ~47s shutdown + 10s margin |
| Tracer | `terminationGracePeriodSeconds` | `45` | `55` | 15s drain + shutdown time + margin |

### Example configuration

**Default behavior (no changes required):**

```yaml
ledger:
  terminationGracePeriodSeconds: 72  # Default in v10.2.0

tracer:
  terminationGracePeriodSeconds: 55  # Default in v10.2.0
```

**Custom drain delay:**

```yaml
ledger:
  terminationGracePeriodSeconds: 90
  env:
    - name: SHUTDOWN_DRAIN_DELAY
      value: "30s"

tracer:
  terminationGracePeriodSeconds: 70
  env:
    - name: SHUTDOWN_DRAIN_DELAY
      value: "25s"
```

> **Note:** The `SHUTDOWN_DRAIN_DELAY` environment variable is not exposed in `values.yaml` by default. It is hardcoded in the deployment templates. To override it, you must use the `env` array as shown above.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.2.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.2.0 -n midaz
```
<!-- {% endraw %} -->
