# Helm Upgrade from v5.1.1 to v5.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Graceful shutdown configuration for manager](#1-graceful-shutdown-configuration-for-manager)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that changes the manager Deployment only. The chart now sets `SHUTDOWN_DRAIN_DELAY=15s` on the manager container and sets the manager pod `terminationGracePeriodSeconds` to `55`.

| Field | v5.1.1 | v5.2.0 |
|-------|--------|--------|
| Chart version | `5.1.1` | `5.2.0` |
| App version | `4.6.0` | `4.6.0` |

## Features

### 1. Graceful shutdown configuration for manager

The manager deployment now includes a `SHUTDOWN_DRAIN_DELAY` environment variable and an extended `terminationGracePeriodSeconds`.

**What changed:**

- A new environment variable `SHUTDOWN_DRAIN_DELAY` is set to `15s` in the manager container
- The pod `terminationGracePeriodSeconds` is set to `55` seconds (calculated as: 15s drain delay + 30s application shutdown budget + 10s buffer)

| Setting | v5.1.1 | v5.2.0 |
|---------|--------|--------|
| Manager `SHUTDOWN_DRAIN_DELAY` environment variable | not present | `"15s"` |
| Manager pod `terminationGracePeriodSeconds` | Kubernetes default (30s) | `55` |

**Before (v5.1.1):**

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: 65532
      initContainers:
        - name: wait-for-dependencies
          # ...
      containers:
        - name: reporter-manager
          envFrom:
          - configMapRef:
              name: reporter-manager
          env:
          - name: MONGO_PASSWORD
            # ...
```

**After (v5.2.0):**

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: 65532
      # SHUTDOWN_DRAIN_DELAY 15s + the app's 30s shutdown budget + 10s.
      terminationGracePeriodSeconds: 55
      initContainers:
        - name: wait-for-dependencies
          # ...
      containers:
        - name: reporter-manager
          envFrom:
          - configMapRef:
              name: reporter-manager
          env:
          - name: SHUTDOWN_DRAIN_DELAY
            value: "15s"
          - name: MONGO_PASSWORD
            # ...
```

**Operational impact:**

- During rolling updates, manager pods will take up to 55 seconds to terminate gracefully instead of the default 30 seconds
- No configuration changes are required — the new behavior is applied automatically on upgrade

> **Note:** The chart hardcodes `SHUTDOWN_DRAIN_DELAY` and `terminationGracePeriodSeconds`. A `SHUTDOWN_DRAIN_DELAY` set in `manager.extraEnvVars` no longer takes effect, because the container `env` entry overrides the ConfigMap. The values schema already rejects the key in `manager.configmap`.

## Configuration Reference

### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `"15s"` | Set by the chart on the manager container. The default manager image (`4.6.0`) does not read it. |

### Pod lifecycle settings

| Setting | Default | Description |
|---------|---------|-------------|
| Manager pod `terminationGracePeriodSeconds` | `55` | Maximum time Kubernetes waits for graceful shutdown before sending SIGKILL |

> **Note:** The `terminationGracePeriodSeconds` value is hardcoded in the template and is not currently exposed as a configurable field in `values.yaml`.

## Migration Steps

This upgrade requires no values changes. The new pod settings are applied when the manager deployment is rolled.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. Monitor the rolling update of the manager deployment:

```bash
kubectl rollout status deployment/reporter-manager -n <namespace>
```

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

> **Important:** The upgrade triggers a rolling restart of the manager deployment.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.2.0 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.2.0 -n reporter
```
