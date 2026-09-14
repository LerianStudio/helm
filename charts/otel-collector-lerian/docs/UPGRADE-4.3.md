# Helm Upgrade from v4.2.0 to v4.3.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Argo Rollouts pod template hash extraction](#1-argo-rollouts-pod-template-hash-extraction)
  - [2. Canary-isolated RED metrics dimension](#2-canary-isolated-red-metrics-dimension)
- **[Configuration Changes](#configuration-changes)**
  - [K8s attributes processor label extraction](#k8s-attributes-processor-label-extraction)
  - [Metrics transform processor dimension addition](#metrics-transform-processor-dimension-addition)
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

The `metricstransform` processor now includes `rollouts_pod_template_hash` as a dimension on all transformed metrics. This allows metrics backends and AnalysisTemplates to filter RED metrics (rate, errors, duration) by canary vs. stable pods.

| Field | v4.2.0 | v4.3.0 |
|-------|--------|--------|
| Metric dimensions | 11 dimensions | 12 dimensions (added `rollouts_pod_template_hash`) |
| Default value | N/A | `""` (empty string for non-Rollout pods) |
| Aggregation cardinality limit | 50000 | 50000 (unchanged) |

**Before (v4.2.0):**

```yaml
metricstransform:
  transforms:
    - include: ^.*$
      match_type: regexp
      action: update
      operations:
        - action: aggregate_labels
          label_set:
            - name: service.name
            - name: service.namespace
            - name: service.instance.id
            - name: k8s.pod.name
            - name: k8s.deployment.name
            - name: k8s.namespace.name
            - name: client_id
            - name: http.method
            - name: http.target
            - name: http.route
            - name: http.status_code
            - name: http.response.status_code
          aggregation_cardinality_limit: 50000
```

**After (v4.3.0):**

```yaml
metricstransform:
  transforms:
    - include: ^.*$
      match_type: regexp
      action: update
      operations:
        - action: aggregate_labels
          label_set:
            - name: service.name
            - name: service.namespace
            - name: service.instance.id
            - name: k8s.pod.name
            - name: k8s.deployment.name
            - name: k8s.namespace.name
            - name: client_id
            - name: http.method
            - name: http.target
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

**Why this matters:**

- AnalysisTemplates can now query metrics with a filter like `rollouts_pod_template_hash="abc123"` to isolate canary pod metrics.
- This enables automated rollback decisions based on canary-specific SLIs (e.g., error rate > 1% for canary pods only).
- Without this dimension, metrics are aggregated across all pods, making it impossible to detect canary-specific regressions.

**Operational impact:**

- All existing metrics will now include the `rollouts_pod_template_hash` dimension with a default value of `""`.
- Metrics from Rollout-managed pods will have the hash value populated during rollouts.
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

### Metrics transform processor dimension addition

The `opentelemetry-collector.config.processors.metricstransform.transforms[0].operations[0].label_set` array has been extended with the `rollouts_pod_template_hash` dimension.

| Setting | v4.2.0 | v4.3.0 |
|---------|--------|--------|
| Number of dimensions | 11 | 12 |
| New dimension name | N/A | `rollouts_pod_template_hash` |
| Default value | N/A | `""` |

**New dimension entry:**

```yaml
opentelemetry-collector:
  config:
    processors:
      metricstransform:
        transforms:
          - operations:
              - label_set:
                  - name: rollouts_pod_template_hash
                    default: ""
```

> **Note:** The `default: ""` ensures that metrics from pods without the label still include the dimension with an empty string value, preventing metric schema mismatches.

## Migration Steps

This upgrade requires no manual migration steps. The new configuration is additive and backward-compatible.

**Recommended upgrade process:**

1. Review the rendered diff using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Verify that the diff shows only the two new configuration blocks described above.
3. Run the upgrade command during a normal change window.
4. Verify that the OpenTelemetry Collector pods restart successfully:

```bash
kubectl get pods -n otel-collector-lerian -l app.kubernetes.io/name=opentelemetry-collector
```

5. Validate that metrics now include the `rollouts_pod_template_hash` dimension:

```bash
kubectl logs -n otel-collector-lerian -l app.kubernetes.io/name=opentelemetry-collector --tail=100 | grep rollouts_pod_template_hash
```

6. If you use Argo Rollouts, verify that canary pods have the hash value populated during a test rollout.

> **Important:** If you have custom `values.yaml` overrides for `opentelemetry-collector.config.processors.k8sattributes.extract.labels` or `opentelemetry-collector.config.processors.metricstransform.transforms`, you must merge the new entries manually. Helm will not deep-merge arrays, so your overrides will replace the default configuration entirely.

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

**Example: Merging with existing metric dimensions**

If your current `values.yaml` contains custom `label_set` entries, append the new dimension:

```yaml
opentelemetry-collector:
  config:
    processors:
      metricstransform:
        transforms:
          - operations:
              - label_set:
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
