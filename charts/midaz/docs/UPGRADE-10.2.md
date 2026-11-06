<!-- {% raw %} -->
# Helm Upgrade from v10.1.1 to v10.2.0

## Topics

- **[Features](#features)**
  - [1. Graceful shutdown drain delay for ledger service](#1-graceful-shutdown-drain-delay-for-ledger-service)
  - [2. Grace period and environment variable changes for tracer service](#2-grace-period-and-environment-variable-changes-for-tracer-service)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Graceful shutdown drain delay for ledger service

#### What changed

A new environment variable `SHUTDOWN_DRAIN_DELAY` has been added to the ledger deployment, and the `terminationGracePeriodSeconds` has been increased to accommodate the shutdown sequence.

#### Termination grace period changes

| Setting | v10.1.1 | v10.2.0 |
|---------|---------|---------|
| `ledger.terminationGracePeriodSeconds` | `60` | `72` |

#### Why this matters

When Kubernetes sends a SIGTERM signal to terminate a pod:

1. The ledger service enters a drain phase for **15 seconds** (`SHUTDOWN_DRAIN_DELAY`)
2. Kubernetes waits up to 72 seconds total before sending SIGKILL

#### Configuration

The `SHUTDOWN_DRAIN_DELAY` is hardcoded to `15s` in the deployment template. A `SHUTDOWN_DRAIN_DELAY` you set in `ledger.extraEnvVars` no longer takes effect: the container `env` entry (`15s`) takes precedence over the ConfigMap.

> **Warning:** Setting `terminationGracePeriodSeconds` too low may result in Kubernetes forcefully killing the pod before the ledger service completes its shutdown sequence, potentially causing data loss or inconsistencies.

### 2. Grace period and environment variable changes for tracer service

#### What changed

A new environment variable `SHUTDOWN_DRAIN_DELAY` has been added to the tracer deployment, and the `terminationGracePeriodSeconds` has been increased.

#### Termination grace period changes

| Setting | v10.1.1 | v10.2.0 |
|---------|---------|---------|
| `tracer.terminationGracePeriodSeconds` | `45` | `55` |

#### Configuration

Similar to the ledger service, the `SHUTDOWN_DRAIN_DELAY` is hardcoded to `15s`. The tracer image this chart deploys (`4.4.0`) does not read it: its shutdown drain is still `READYZ_DRAIN_GRACE_SECONDS` (default `12`) from the tracer ConfigMap.

## Configuration Reference

### New environment variables

#### Ledger service

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `15s` | Duration to wait before starting shutdown, allowing in-flight requests to complete |

### Termination grace period settings

| Service | Setting | v10.1.1 | v10.2.0 |
|---------|---------|---------|---------|
| Ledger | `terminationGracePeriodSeconds` | `60` | `72` |
| Tracer | `terminationGracePeriodSeconds` | `45` | `55` |

### Example configuration

**Default behavior (no changes required):**

```yaml
ledger:
  terminationGracePeriodSeconds: 72  # Default in v10.2.0

tracer:
  terminationGracePeriodSeconds: 55  # Default in v10.2.0
```

> **Note:** The `SHUTDOWN_DRAIN_DELAY` environment variable is not exposed in `values.yaml`. It is hardcoded in the deployment templates.

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
