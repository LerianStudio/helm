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
1. Stop accepting new requests (drain delay)
2. Complete in-flight requests (shutdown timeout)
3. Flush telemetry and close connections cleanly

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

A new environment variable `SHUTDOWN_DRAIN_DELAY` has been added to the ConfigMap to control how long the service waits after receiving SIGTERM before starting the shutdown sequence.

**Environment variable added:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | `"15s"` | Duration to wait after SIGTERM before starting shutdown, allowing load balancers and service meshes to remove the pod from rotation |

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

**Operational impact:**

When a pod receives SIGTERM (during rolling updates, scale-down, or node drain), it will:
1. Wait 15 seconds (the drain delay) while continuing to serve existing requests but failing readiness checks
2. Start the shutdown sequence, completing in-flight requests within the lib-commons `SHUTDOWN_TIMEOUT` (default 30s)
3. Exit cleanly

This prevents connection errors during rolling updates by giving Kubernetes time to remove the pod from Service endpoints before the application stops accepting connections.

**Customization:**

You can override the drain delay via values:

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

> **Note:** The drain delay should be shorter than `terminationGracePeriodSeconds` minus the shutdown timeout (default 30s). If you increase the drain delay, also increase `terminationGracePeriodSeconds` accordingly.

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

This ensures Kubernetes waits long enough for the application to shut down cleanly before sending SIGKILL. Without this setting, Kubernetes would use the default 30-second grace period, which is insufficient for the drain delay plus shutdown sequence.

**Customization:**

You can override the termination grace period via values:

```yaml
system-facts:
  terminationGracePeriodSeconds: 70
```

> **Important:** If you customize `shutdownDrainDelay` or if your application has a non-default `SHUTDOWN_TIMEOUT`, adjust `terminationGracePeriodSeconds` to: `drain_delay + shutdown_timeout + 10s margin`. If the grace period is too short, Kubernetes will forcefully kill the pod before it finishes shutting down, potentially causing connection errors or incomplete request handling.

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

> **Note:** To avoid downtime during upgrades, run two or more replicas (`system-facts.replicaCount: 2` or enable autoscaling with `system-facts.autoscaling.minReplicas: 2`). The PodDisruptionBudget allows `maxUnavailable: 1`, so one replica remains available during the rollout.

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

### Step 5: Test graceful shutdown (optional)

To verify graceful shutdown behavior, trigger a rolling restart and observe the pod termination:

```bash
kubectl rollout restart deployment/system-facts -n system-facts
kubectl logs -n system-facts -l app.kubernetes.io/name=system-facts --previous --tail=50
```

You should see log entries indicating the drain delay and clean shutdown sequence.

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
