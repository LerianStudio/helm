# Helm Upgrade from v4.1.0 to v4.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. GOMEMLIMIT environment variable removed from explicit configuration](#1-gomemlimit-environment-variable-removed-from-explicit-configuration)
  - [2. Kubeletstats receiver collection interval increased](#2-kubeletstats-receiver-collection-interval-increased)
  - [3. Spanmetrics connector resource key attributes configured](#3-spanmetrics-connector-resource-key-attributes-configured)
  - [4. Spanmetrics connector dimensions reduced](#4-spanmetrics-connector-dimensions-reduced)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `otel-collector-lerian` chart upgrade from `4.1.0` to `4.2.0`. This is a minor version bump that introduces configuration changes to improve metrics cardinality management, reduce data point volume, and fix a server-side apply conflict with the `GOMEMLIMIT` environment variable.

The application version (`appVersion: 0.1.0`) remains unchanged. All changes are configuration adjustments within `values.yaml` that affect the OpenTelemetry Collector's behavior but do not introduce breaking changes to the chart interface.

**Key changes:**

- Removal of explicit `GOMEMLIMIT` environment variable to prevent duplicate entries
- Increased kubeletstats collection interval from 10s to 60s to reduce data point volume
- Addition of `resource_metrics_key_attributes` to spanmetrics connector for stable accumulator identity
- Removal of high-cardinality dimensions from spanmetrics connector

Existing `values.yaml` overrides remain compatible unless they explicitly override the changed sections.

## Features

### 1. GOMEMLIMIT environment variable removed from explicit configuration

The explicit `GOMEMLIMIT` environment variable has been removed from the collector's `extraEnvs` configuration. This change resolves a server-side apply conflict where the upstream subchart automatically injects `GOMEMLIMIT` based on `resources.limits.memory` (via the `useGOMEMLIMIT` flag, enabled by default), causing duplicate environment variable entries.

| Setting | v4.1.0 | v4.2.0 |
|---------|--------|--------|
| `opentelemetry-collector.extraEnvs` (GOMEMLIMIT) | `value: "200MiB"` | (removed) |

**Before (v4.1.0):**

```yaml
extraEnvs:
  - name: K8S_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName    
  - name: GOMEMLIMIT
    value: "200MiB"
  - name: GOGC
    value: "80"
```

**After (v4.2.0):**

```yaml
extraEnvs:
  - name: K8S_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
  # GOMEMLIMIT is NOT set here on purpose. The subchart injects it
  # automatically from `resources.limits.memory` (see `useGOMEMLIMIT`, enabled
  # by default upstream). Declaring it here too renders two `env` entries with
  # the same name, which server-side apply rejects (`duplicate entries for key
  # [name="GOMEMLIMIT"]`). To raise it, raise `resources.limits.memory` — the
  # limit and the GC target must move together, or the collector gets OOMKilled
  # before the GC reacts. Only set it explicitly if you also set
  # `useGOMEMLIMIT: false`.
  - name: GOGC
    value: "80"
```

**Why this matters:**

The upstream OpenTelemetry Collector Helm chart automatically derives `GOMEMLIMIT` from the memory resource limit to ensure the Go garbage collector triggers before the container is OOMKilled. Declaring `GOMEMLIMIT` explicitly in `extraEnvs` creates a duplicate entry, which Kubernetes server-side apply rejects with the error:

```
duplicate entries for key [name="GOMEMLIMIT"]
```

**Operational impact:**

- The collector will continue to have `GOMEMLIMIT` set, but now derived automatically from `resources.limits.memory`
- If you previously overrode `GOMEMLIMIT` to a custom value, you must now adjust `resources.limits.memory` instead
- The memory limit and `GOMEMLIMIT` must remain aligned to prevent OOMKills before garbage collection

> **Important:** If you need a custom `GOMEMLIMIT` value that differs from the memory limit, you must set `useGOMEMLIMIT: false` in your values override and then declare `GOMEMLIMIT` explicitly in `extraEnvs`. This is not recommended unless you have a specific reason to decouple the GC target from the memory limit.

### 2. Kubeletstats receiver collection interval increased

The kubeletstats receiver's `collection_interval` has been increased from `10s` to `60s`. This receiver collects pod and container performance metrics (CPU, memory) from the node's Kubelet.

| Setting | v4.1.0 | v4.2.0 |
|---------|--------|--------|
| `opentelemetry-collector.config.receivers.kubeletstats.collection_interval` | `10s` | `60s` |

**Before (v4.1.0):**

```yaml
receivers:
  kubeletstats:
    collection_interval: 10s
    auth_type: "serviceAccount"
    endpoint: "${env:K8S_NODE_NAME}:10250"
    insecure_skip_verify: true
```

**After (v4.2.0):**

```yaml
receivers:
  # Collects pod/container performance metrics (CPU, memory) from the node's Kubelet.
  # 60s matches the k8s_cluster receiver above and keeps this receiver at
  # 1 data point per minute. At 10s it emitted 6x the samples for the same
  # series, inflating DPM without adding resolution anyone consumes.
  kubeletstats:
    collection_interval: 60s
    auth_type: "serviceAccount"
    endpoint: "${env:K8S_NODE_NAME}:10250"
    insecure_skip_verify: true
```

**Why this matters:**

At a 10-second interval, the kubeletstats receiver emits 6 data points per minute for each metric series. This inflates data point volume (DPM) by 6× without providing additional resolution that downstream consumers (dashboards, alerts) typically use. The new 60-second interval aligns with the `k8s_cluster` receiver and reduces DPM to 1 point per minute per series.

**Operational impact:**

- Metrics volume will decrease by approximately 83% for kubeletstats-sourced metrics
- Dashboards and alerts that query kubeletstats metrics will see 1-minute resolution instead of 10-second resolution
- No data loss occurs; the metrics are still collected, just less frequently
- If you require higher resolution for specific use cases, override this value in your `values.yaml`

> **Note:** This change does not affect trace-derived metrics (spanmetrics) or other receivers. Only pod/container resource metrics from kubeletstats are affected.

### 3. Spanmetrics connector resource key attributes configured

The spanmetrics connector now includes an explicit `resource_metrics_key_attributes` configuration. This setting defines which resource attributes are used to identify a unique cumulative accumulator for spanmetrics.

| Setting | v4.1.0 | v4.2.0 |
|---------|--------|--------|
| `opentelemetry-collector.config.connectors.spanmetrics.resource_metrics_key_attributes` | (not set) | `[service.name, client.id, k8s.namespace.name, k8s.deployment.name]` |

**Before (v4.1.0):**

```yaml
connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [10ms, 50ms, 100ms, 200ms, 500ms, 1s, 5s, 10s]
    namespace: ""
    aggregation_temporality: CUMULATIVE
    dimensions:
      - name: k8s.namespace.name
      - name: k8s.deployment.name
      - name: k8s.pod.name
```

**After (v4.2.0):**

```yaml
connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [10ms, 50ms, 100ms, 200ms, 500ms, 1s, 5s, 10s]
    namespace: ""
    aggregation_temporality: CUMULATIVE
    # Resource attributes that define one cumulative accumulator. Left empty,
    # the connector hashes EVERY resource attribute, and k8sattributes adds
    # `k8s.pod.name` upstream of here — so each pod would get its own
    # accumulator and every rollout would reset the counters, independently
    # of which attributes appear as dimensions below. Pinning the key to
    # stable workload identity keeps one accumulator per workload across pod
    # replacement. Keep `client.id` in the key: it is the multi-tenancy
    # boundary and must never be collapsed across tenants.
    resource_metrics_key_attributes:
      - service.name
      - client.id
      - k8s.namespace.name
      - k8s.deployment.name
    dimensions:
      - name: k8s.namespace.name
      - name: k8s.deployment.name
```

**Why this matters:**

When `resource_metrics_key_attributes` is not set, the spanmetrics connector hashes **all** resource attributes to determine accumulator identity. Because the `k8sattributes` processor adds `k8s.pod.name` upstream, each pod gets its own accumulator. With `CUMULATIVE` aggregation temporality, this means:

- Every pod restart or rollout creates a new accumulator and resets counters to zero
- Old accumulators linger until `metrics_expiration` is reached
- Metrics appear to reset on every deployment, making cumulative counters unreliable

By pinning the accumulator key to stable workload identity attributes (`service.name`, `k8s.deployment.name`, `k8s.namespace.name`, `client.id`), the same accumulator persists across pod replacements, and cumulative counters remain stable through rollouts.

**Operational impact:**

- Spanmetrics counters will no longer reset on pod restarts or deployments
- Cumulative metrics will provide accurate totals across the lifetime of a workload
- Multi-tenancy is preserved via `client.id` in the key
- Existing metrics will continue to be emitted; this change affects accumulator identity, not metric names or labels

> **Important:** This change may cause a one-time discontinuity in cumulative metrics during the upgrade as the connector switches from per-pod to per-workload accumulators. After the upgrade, counters will stabilize and persist across future deployments.

### 4. Spanmetrics connector dimensions reduced

The spanmetrics connector's `dimensions` list has been reduced to remove high-cardinality and unstable attributes. The following dimensions have been removed:

- `k8s.pod.name`
- `k8s.container.ready`
- `k8s.container.uptime`

| Dimension | v4.1.0 | v4.2.0 |
|-----------|--------|--------|
| `k8s.pod.name` | included | removed |
| `k8s.container.ready` | included | removed |
| `k8s.container.uptime` | included | removed |
| `k8s.deployment.name` | included | included |
| `k8s.namespace.name` | included | included |
| `k8s.container.name` | included | included |

**Before (v4.1.0):**

```yaml
dimensions:
  - name: k8s.namespace.name
  - name: k8s.deployment.name
  - name: k8s.pod.name
  - name: k8s.container.name
  - name: k8s.container.ready
  - name: k8s.container.uptime
```

**After (v4.2.0):**

```yaml
dimensions:
  # Only attributes that are stable for the lifetime of a workload
  # belong here. A dimension whose value changes over time mints a new
  # series on every change, and with CUMULATIVE temporality the old one
  # lingers until metrics_expiration. Deliberately NOT dimensions:
  #   k8s.pod.name      — new suffix on every restart/rollout, so every
  #                       deploy retires one series set and creates another
  #   k8s.container.uptime — monotonically increasing, a new value on
  #                       every export: effectively unbounded
  #   k8s.container.ready  — flips with readiness probes
  # k8s.deployment.name carries the workload identity these were used
  # for, without the churn. Per-pod resource data still comes from the
  # kubeletstats metrics (k8s_pod_*), which are not spanmetrics.
  - name: k8s.namespace.name
  - name: k8s.deployment.name
  - name: k8s.container.name
```

**Why this matters:**

With `CUMULATIVE` aggregation temporality, every unique combination of dimension values creates a new metric series. Dimensions whose values change frequently cause:

- **`k8s.pod.name`**: Changes on every pod restart or rollout (new pod suffix). Each deployment creates a new series and retires the old one, which lingers until `metrics_expiration`.
- **`k8s.container.uptime`**: Monotonically increasing value that changes on every export, creating effectively unbounded cardinality.
- **`k8s.container.ready`**: Flips between `true` and `false` with readiness probe state changes, creating new series on every flip.

These dimensions inflate cardinality without adding operational value. The workload identity is already captured by `k8s.deployment.name`, and per-pod resource metrics are available from kubeletstats metrics (`k8s_pod_*`), which are not affected by this change.

**Operational impact:**

- Spanmetrics cardinality will decrease significantly
- Dashboards and alerts that filter or group by `k8s.pod.name`, `k8s.container.ready`, or `k8s.container.uptime` will need to be updated to use `k8s.deployment.name` instead
- Per-pod resource metrics (CPU, memory) remain available via kubeletstats metrics
- Existing series with the removed dimensions will expire according to `metrics_expiration` settings

> **Warning:** If you have dashboards, alerts, or queries that rely on `k8s.pod.name`, `k8s.container.ready`, or `k8s.container.uptime` as dimensions in spanmetrics, you must update them to use `k8s.deployment.name` or query kubeletstats metrics for per-pod data.

## Configuration Changes

All changes are within the `opentelemetry-collector` subchart configuration in `values.yaml`. No new top-level keys or chart parameters were added.

| Section | Change Summary |
|---------|----------------|
| `opentelemetry-collector.extraEnvs` | Removed explicit `GOMEMLIMIT` entry |
| `opentelemetry-collector.config.receivers.kubeletstats` | Increased `collection_interval` from `10s` to `60s` |
| `opentelemetry-collector.config.connectors.spanmetrics` | Added `resource_metrics_key_attributes` list |
| `opentelemetry-collector.config.connectors.spanmetrics.dimensions` | Removed `k8s.pod.name`, `k8s.container.ready`, `k8s.container.uptime` |

**If you have overridden any of these sections in your `values.yaml`:**

- **`extraEnvs`**: Remove any explicit `GOMEMLIMIT` entry. If you need a custom value, adjust `resources.limits.memory` instead.
- **`receivers.kubeletstats.collection_interval`**: Your override will take precedence. Consider adopting the new `60s` default unless you have a specific need for higher resolution.
- **`connectors.spanmetrics.resource_metrics_key_attributes`**: Your override will take precedence. Ensure your key attributes are stable across pod restarts to avoid accumulator churn.
- **`connectors.spanmetrics.dimensions`**: Your override will take precedence. Review your dimensions for high-cardinality attributes and consider removing unstable dimensions.

> **Note:** If you do not override these sections, the upgrade will apply the new defaults automatically.

## Migration Steps

This upgrade requires no manual migration steps for most deployments. The changes are configuration adjustments that take effect when the collector pods restart during the Helm upgrade.

**Recommended upgrade process:**

1. **Review your current `values.yaml` overrides** to identify any conflicts with the changed sections:

   ```bash
   helm get values otel-collector-lerian -n otel-collector-lerian
   ```

   Check for overrides in:
   - `opentelemetry-collector.extraEnvs` (especially `GOMEMLIMIT`)
   - `opentelemetry-collector.config.receivers.kubeletstats.collection_interval`
   - `opentelemetry-collector.config.connectors.spanmetrics`

2. **If you have overridden `GOMEMLIMIT` in `extraEnvs`**, remove it from your values override. If you need a custom memory limit, adjust `opentelemetry-collector.resources.limits.memory` instead:

   ```yaml
   opentelemetry-collector:
     resources:
       limits:
         memory: 512Mi  # GOMEMLIMIT will be derived from this
   ```

3. **Preview the changes** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)). Expect:
   - Environment variable changes (removal of explicit `GOMEMLIMIT`)
   - ConfigMap changes (receiver interval, spanmetrics configuration)
   - Pod restart due to ConfigMap update

4. **Run the upgrade** during a normal change window. The collector pods will restart to pick up the new configuration.

5. **Verify the upgrade**:

   ```bash
   kubectl get pods -n otel-collector-lerian
   kubectl logs -n otel-collector-lerian -l app.kubernetes.io/name=opentelemetry-collector --tail=50
   ```

   Check for:
   - Pods are running and ready
   - No errors in logs related to duplicate environment variables
   - Metrics are being exported successfully

6. **Update dashboards and alerts** if you rely on the removed spanmetrics dimensions (`k8s.pod.name`, `k8s.container.ready`, `k8s.container.uptime`). Replace queries that filter or group by these dimensions with `k8s.deployment.name` or switch to kubeletstats metrics for per-pod data.

> **Important:** The spanmetrics accumulator change may cause a one-time discontinuity in cumulative counters during the upgrade. Counters will reset to zero and begin accumulating from the new per-workload accumulators. This is expected and will stabilize after the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 4.2.0 -n otel-collector-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 4.2.0 -n otel-collector-lerian
```
