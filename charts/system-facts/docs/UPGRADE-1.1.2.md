# Helm Upgrade from v1.1.1 to v1.1.2

This guide covers the upgrade of the `system-facts` Helm chart from version **1.1.1** to **1.1.2**. This is a patch release that introduces graceful shutdown configuration for the System Facts service.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Configuration Changes](#configuration-changes)**
  - [Graceful Shutdown Configuration](#graceful-shutdown-configuration)
  - [Termination Grace Period](#termination-grace-period)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.1.2** introduces graceful shutdown configuration for the System Facts service to ensure clean pod termination during rolling updates and scale-down operations. The changes include:

- A new environment variable `SHUTDOWN_DRAIN_DELAY` in the ConfigMap
- A new `terminationGracePeriodSeconds` field in the Deployment spec

These changes ensure that the service has sufficient time to:
1. Complete in-flight requests (shutdown timeout)
2. Flush telemetry and close connections cleanly

There are no changes to:
- Application version (`appVersion` remains `1.1.0`)
- Image tags or container specifications
- Service, Ingress, or networking configuration
- Dependencies or subcharts

The upgrade will trigger a rolling restart of the System Facts pods because the ConfigMap and Deployment templates have changed.

---

## Breaking Changes

**None.** This is a patch release with no breaking changes. All existing configurations remain valid, and the new fields have sensible defaults.

---

## Configuration Changes

### Graceful Shutdown Configuration

A new environment variable `SHUTDOWN_DRAIN_DELAY` (default `"15s"`) has been added to the ConfigMap.

**ConfigMap change:**

The new variable is added to the `system-facts` ConfigMap using the standard `lerian-common.cfgValue` helper pattern.

**Before (v1.1.1):**

```yaml
data:
  ENV_NAME: "production"
  LOG_LEVEL: "info"
  SERVER_ADDRESS: ":8080"
  HTTP_BODY_LIMIT_BYTES: "104857600"
  # ... other variables
```

**After (v1.1.2):**

```yaml
data:
  ENV_NAME: "production"
  LOG_LEVEL: "info"
  SERVER_ADDRESS: ":8080"
  SHUTDOWN_DRAIN_DELAY: "15s"
  HTTP_BODY_LIMIT_BYTES: "104857600"
  # ... other variables
```

**Customization:**

You can set `SHUTDOWN_DRAIN_DELAY` via values:

```yaml
system-facts:
  shutdownDrainDelay: "20s"
```

Or via the ConfigMap override pattern:

```yaml
system-facts:
  configmap:
    SHUTDOWN_DRAIN_DELAY: "20s"
```

### Termination Grace Period

A new `terminationGracePeriodSeconds` field has been added to the Deployment spec to give the pod sufficient time to complete its graceful shutdown sequence.

**Value added:**

| Setting | v1.1.1 | v1.1.2 |
|---------|--------|--------|
| `system-facts.terminationGracePeriodSeconds` | (Kubernetes default: 30) | `55` |

**Deployment change:**

The `terminationGracePeriodSeconds` field is now explicitly set on the pod spec.

**Before (v1.1.1):**

```yaml
spec:
  template:
    spec:
      serviceAccountName: system-facts
      securityContext:
        # ... security context
      containers:
        - name: system-facts
          # ... container spec
```

**After (v1.1.2):**

```yaml
spec:
  template:
    spec:
      serviceAccountName: system-facts
      terminationGracePeriodSeconds: 55
      securityContext:
        # ... security context
      containers:
        - name: system-facts
          # ... container spec
```

**Operational impact:**

The 55-second grace period is calculated as:
- 15s drain delay (`SHUTDOWN_DRAIN_DELAY`)
- 30s shutdown budget (lib-commons `SHUTDOWN_TIMEOUT` default)
- 10s margin for telemetry flush and connection cleanup

This ensures Kubernetes waits long enough for the application to shut down cleanly before sending SIGKILL.

**Customization:**

You can override the termination grace period via values:

```yaml
system-facts:
  terminationGracePeriodSeconds: 70
```

---

## Migration Steps

No values changes are required. The new defaults provide safe graceful shutdown behavior. Apply the upgrade as shown in Step 2.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.1.1` and `APP VERSION` should show `1.1.0`.

### Step 2: Apply the upgrade

Upgrade to version `1.1.2`, keeping your existing values:

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.1.2 \
  --namespace system-facts \
  --reuse-values
```

> **Note:** The `--reuse-values` flag preserves your existing configuration. The new fields have sensible defaults and do not require explicit configuration.

> **Note:** An anonymous pull from `registry-1.docker.io` is refused with `401`. Without Docker Hub access, use `oci://ghcr.io/lerianstudio/system-facts-helm`.

### Step 3: Monitor the upgrade

Watch the rollout status for the System Facts service:

```bash
kubectl rollout status deployment/system-facts -n system-facts
```

The upgrade triggers a rolling update because the ConfigMap and Deployment templates have changed. With the default single replica and `maxUnavailable: 1`, expect a brief service interruption as the old pod terminates and the new pod starts.

> **Note:** To avoid downtime during upgrades, run two or more replicas (`system-facts.autoscaling.minReplicas: 2`).

### Step 4: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.1.2` and `APP VERSION` should show `1.1.0`.

Verify that the new ConfigMap variable is present:

```bash
kubectl get configmap system-facts -n system-facts -o jsonpath='{.data.SHUTDOWN_DRAIN_DELAY}'
```

Expected output: `15s`

Verify that the termination grace period is set:

```bash
kubectl get deployment system-facts -n system-facts -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}'
```

Expected output: `55`

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.2 -n system-facts
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.2 -n system-facts
```
