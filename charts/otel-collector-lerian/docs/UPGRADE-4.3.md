# Helm Upgrade from v4.2.0 to v4.3.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Argo Rollouts pod template hash extraction](#1-argo-rollouts-pod-template-hash-extraction)
  - [2. Canary-isolated RED metrics dimension](#2-canary-isolated-red-metrics-dimension)
- **[Configuration Changes](#configuration-changes)**
  - [K8s attributes processor label extraction](#k8s-attributes-processor-label-extraction)
  - [Spanmetrics connector dimension addition](#spanmetrics-connector-dimension-addition)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `otel-collector-lerian` chart upgrade from `4.2.0` to `4.3.0`. This is a minor version bump that adds support for Argo Rollouts progressive delivery analysis by extracting the `rollouts-pod-template-hash` pod label and exposing it as a metric dimension.

The application version (`appVersion: 0.1.0`) remains unchanged. All existing configurations remain compatible, and the new fields are additive only.

There are no breaking changes. Existing `values.yaml` overrides remain fully compatible. The new configuration enables canary vs. stable pod isolation for RED metrics analysis in Argo Rollouts AnalysisTemplates.

## Features

### 1. Argo Rollouts pod template hash extraction

The `k8sattributes` processor now extracts the `rollouts-pod-template-hash` label from pods and maps it to a resource attribute. This label is automatically stamped by Argo Rollouts on each ReplicaSet's pods to distinguish canary from stable deployments during progressive rollouts.

| Field | v4.2.0 | v4.3.0 |
|-------|--------|--------|
| K8s label extraction | Not configured | `rollouts-pod-template-hash` → `rollouts_pod_template_hash` |
| Cardinality impact | N/A | Low: empty string for non-Rollout pods, plus stable + canary hashes during rollout |

**Before (v4.2.0):**

```yaml
k8sattributes:
  passthrough: false
  extract:
    metadata:
      - k8s.pod.name
      - k8s.deployment.name
      - k8s.namespace.name
```

**After (v4.3.0):**

```yaml
k8sattributes:
  passthrough: false
  extract:
    metadata:
      - k8s.pod.name
      - k8s.deployment.name
      - k8s.namespace.name
    # Pod labels -> resource attributes. `rollouts-pod-template-hash` is the
    # label Argo Rollouts stamps on each ReplicaSet's pods (canary vs stable).
    # Exposing it lets progressive-delivery analysis (AnalysisTemplate) isolate
    # the canary's RED metrics from the stable's. Empty for pods that are not
    # managed by a Rollout.
    labels:
      - tag_name: rollouts_pod_template_hash
        key: rollouts-pod-template-hash
        from: pod
```

**Why this matters:**

- Argo Rollouts uses the `rollouts-pod-template-hash` label to differentiate canary and stable ReplicaSets during progressive delivery.
- Extracting this label as a resource attribute enables AnalysisTemplates to query metrics scoped to only the canary pods or only the stable pods.
- This is critical for automated rollout decisions based on canary-specific error rates, latency, or throughput.

**Operational impact:**

- Pods not managed by Argo Rollouts will have an empty string (`""`) for this attribute.
- Pods managed by Rollouts will have the hash value only while a rollout is in progress.
- Cardinality increase is minimal: typically 0-2 additional values per service during a rollout window.

### 2. Canary-isolated RED metrics dimension

The `spanmetrics` connector (`opentelemetry-collector.config.connectors.spanmetrics`) now includes `rollouts_pod_template_hash` in its `dimensions` list. The RED metrics (rate, errors, duration) it derives from spans can therefore be filtered by canary vs. stable pods. The chart has no `metricstransform` processor; the change is only in `connectors.spanmetrics.dimensions`.

| Field | v4.2.0 | v4.3.0 |
|-------|--------|--------|
| Spanmetrics dimensions | 8 dimensions | 9 dimensions (added `rollouts_pod_template_hash`) |
| Default value | N/A | `""` (empty string for non-Rollout pods) |
| `aggregation_cardinality_limit` | 50000 | 50000 (unchanged) |

**Before (v4.2.0):**

```yaml
connectors:
  spanmetrics:
    dimensions:
      - name: k8s.namespace.name
      - name: k8s.deployment.name
      - name: k8s.container.name
      - name: http.method
      - name: http.request.method
      - name: http.route
      - name: http.status_code
      - name: http.response.status_code
    aggregation_cardinality_limit: 50000
```

**After (v4.3.0):**

```yaml
connectors:
  spanmetrics:
    dimensions:
      - name: k8s.namespace.name
      - name: k8s.deployment.name
      - name: k8s.container.name
      - name: http.method
      - name: http.request.method
      - name: http.route
      - name: http.status_code
      - name: http.response.status_code
      # Argo Rollouts canary/stable pod-template hash (from the k8sattributes
      # pod-label extraction above). Low cardinality: "" for non-Rollout pods,
      # plus the stable + canary hashes only while a rollout is in progress.
      # Enables canary-isolated RED analysis for progressive delivery.
      - name: rollouts_pod_template_hash
        default: ""
    aggregation_cardinality_limit: 50000
```

`resource_metrics_key_attributes` (added in 4.2.0) is unchanged.

**Why this matters:**

- AnalysisTemplates can query the span-derived metrics with a filter like `rollouts_pod_template_hash="abc123"` to isolate canary pod metrics.
- This enables automated rollback decisions based on canary-specific SLIs (e.g., error rate > 1% for canary pods only).
- Without this dimension, span-derived metrics are aggregated across all pods of a workload, making it impossible to detect canary-specific regressions.

**Operational impact:**

- All span-derived metrics (`calls_total`, duration histogram) now carry the `rollouts_pod_template_hash` dimension with a default value of `""`.
- Series from Rollout-managed pods have the hash value populated during rollouts.
- No changes to existing queries are required unless you want to filter by this new dimension.
- Cardinality impact is low because the dimension has only 1-3 unique values per service at any given time.

## Configuration Changes

### K8s attributes processor label extraction

The `opentelemetry-collector.config.processors.k8sattributes.extract.labels` section has been added to extract the `rollouts-pod-template-hash` pod label.

| Setting | v4.2.0 | v4.3.0 |
|---------|--------|--------|
| `opentelemetry-collector.config.processors.k8sattributes.extract.labels` | Not present | Array with 1 label mapping |
| Label key | N/A | `rollouts-pod-template-hash` |
| Target attribute | N/A | `rollouts_pod_template_hash` |
| Source | N/A | `pod` |

**New configuration block:**

```yaml
opentelemetry-collector:
  config:
    processors:
      k8sattributes:
        extract:
          labels:
            - tag_name: rollouts_pod_template_hash
              key: rollouts-pod-template-hash
              from: pod
```

> **Note:** This configuration is additive. If you have existing label extractions in your `values.yaml` overrides, merge this new entry into your existing `labels` array rather than replacing it.

### Spanmetrics connector dimension addition

The `opentelemetry-collector.config.connectors.spanmetrics.dimensions` list has been extended with the `rollouts_pod_template_hash` dimension.

| Setting | v4.2.0 | v4.3.0 |
|---------|--------|--------|
| Number of dimensions | 8 | 9 |
| New dimension name | N/A | `rollouts_pod_template_hash` |
| Default value | N/A | `""` |

**New dimension entry:**

```yaml
opentelemetry-collector:
  config:
    connectors:
      spanmetrics:
        dimensions:
          - name: rollouts_pod_template_hash
            default: ""
```

> **Note:** The `default: ""` ensures that series from pods without the label still include the dimension with an empty string value, preventing metric schema mismatches. Because Helm replaces lists instead of merging them, an override of `dimensions` must contain the full list (see below).

## Migration Steps

This upgrade requires no manual migration steps. The new configuration is additive and backward-compatible.

**Recommended upgrade process:**

1. Review the rendered diff using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Verify that the diff shows only the two new configuration blocks described above (the `k8sattributes` label extraction and the `spanmetrics` dimension).
3. Run the upgrade command during a normal change window.
4. Verify that the OpenTelemetry Collector pods restart successfully:

```bash
kubectl get pods -n otel-collector-lerian -l app.kubernetes.io/name=opentelemetry-collector
```

5. Validate that the collector configuration carries the new dimension and label extraction (the default configuration has no debug exporter, so the pod logs do not print metric attributes):

```bash
kubectl get configmap -n otel-collector-lerian -l app.kubernetes.io/name=opentelemetry-collector -o yaml | grep rollouts_pod_template_hash
```

Then query the `calls_total` series in your metrics backend and check for the `rollouts_pod_template_hash` label.

6. If you use Argo Rollouts, verify that canary pods have the hash value populated during a test rollout.

> **Important:** If you have custom `values.yaml` overrides for `opentelemetry-collector.config.processors.k8sattributes.extract.labels` or `opentelemetry-collector.config.connectors.spanmetrics.dimensions`, you must merge the new entries manually. Helm will not deep-merge arrays, so your overrides will replace the default configuration entirely.

**Example: Merging with existing label extractions**

If your current `values.yaml` contains:

```yaml
opentelemetry-collector:
  config:
    processors:
      k8sattributes:
        extract:
          labels:
            - tag_name: custom_label
              key: my-custom-label
              from: pod
```

Update it to:

```yaml
opentelemetry-collector:
  config:
    processors:
      k8sattributes:
        extract:
          labels:
            - tag_name: custom_label
              key: my-custom-label
              from: pod
            - tag_name: rollouts_pod_template_hash
              key: rollouts-pod-template-hash
              from: pod
```

**Example: Merging with existing spanmetrics dimensions**

If your current `values.yaml` overrides `dimensions`, append the new dimension to your full list:

```yaml
opentelemetry-collector:
  config:
    connectors:
      spanmetrics:
        dimensions:
          # ... your existing dimensions ...
          - name: rollouts_pod_template_hash
            default: ""
```

## Preview changes before upgrading

```bash
helm diff upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 4.3.0 -n otel-collector-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 4.3.0 -n otel-collector-lerian
```
