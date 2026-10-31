# Helm Upgrade from v4.3.0 to v4.3.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Chart description updated](#1-chart-description-updated)
  - [2. Values.yaml documentation improved](#2-valuesyaml-documentation-improved)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `otel-collector-lerian` chart upgrade from `4.3.0` to `4.3.1`. This is a patch release that updates chart metadata and improves inline documentation. The application version (`appVersion: 0.1.0`) and all rendered manifests remain unchanged.

There are no breaking changes, no new values, no removed values, and no template changes. Existing `values.yaml` overrides remain fully compatible.

## Fixes

### 1. Chart description updated

The chart description in `Chart.yaml` has been expanded from a generic placeholder to a detailed description of the chart's purpose and functionality.

| Field | v4.3.0 | v4.3.1 |
|-------|--------|--------|
| Chart version | `4.3.0` | `4.3.1` |
| App version | `0.1.0` | `0.1.0` |
| Description | `A Helm chart for Kubernetes` | `OpenTelemetry Collector (contrib) DaemonSet that collects Kubernetes traces, logs and metrics and exports them over OTLP/HTTP to the Lerian telemetry backend` |

**Before (v4.3.0):**

```yaml
apiVersion: v2
name: otel-collector-lerian
description: A Helm chart for Kubernetes
type: application
```

**After (v4.3.1):**

```yaml
apiVersion: v2
name: otel-collector-lerian
description: OpenTelemetry Collector (contrib) DaemonSet that collects
  Kubernetes traces, logs and metrics and exports them over OTLP/HTTP to the
  Lerian telemetry backend
type: application
```

> **Note:** This change affects only chart metadata visible in `helm search` and chart repositories. It does not modify any deployed Kubernetes resources.

### 2. Values.yaml documentation improved

The top-level comment block in `values.yaml` has been rewritten to provide a comprehensive summary of the collector's configuration, including all receivers, processors, connectors, and exporters.

**Before (v4.3.0):**

```yaml
# Configuration rebuilt based on user request:
# - Mode: daemonset (for kubeletstats)
# - Receivers: OTLP, k8scluster, kubeletstats
# - Processors: k8sattributes, transform/uuid, resource/client_id
# - Exporters: OTLP/HTTP
```

**After (v4.3.1):**

```yaml
# Configuration summary:
# - Mode: daemonset (for kubeletstats)
# - Receivers: otlp, k8s_cluster, kubeletstats, k8sobjects (events). The upstream
#   subchart also defines jaeger and zipkin receivers; no pipeline uses them.
# - Processors: memory_limiter, k8sattributes, resource/add_client_id,
#   filter/include_midaz_namespaces, filter/drop_node_metrics,
#   transform/remove_sensitive_attributes, transform/normalize_http_semconv,
#   transform/mask_body_sensitive_data_replace_* (log PII masking), batch
# - Connectors: spanmetrics
# - Exporters: otlphttp/server (OTLP/HTTP)
# - client.id: `resource/add_client_id` ships the placeholder `Firmino`. Set your
#   own value; the chart does not validate it.
```

The updated documentation now accurately reflects:

- All active receivers, including `k8sobjects` for Kubernetes events
- The complete processor chain, including memory limiter, filtering, attribute transformation, and PII masking
- The `spanmetrics` connector used for generating metrics from spans
- A reminder that the `client.id` placeholder value (`Firmino`) should be replaced with your organization's identifier

> **Important:** The documentation now explicitly notes that the chart ships with a placeholder `client.id` value. Operators should verify their `values.yaml` overrides include a meaningful `client.id` for proper telemetry attribution in the Lerian backend.

Files modified between `4.3.0` and `4.3.1`:

- `charts/otel-collector-lerian/Chart.yaml`
- `charts/otel-collector-lerian/values.yaml`

## Configuration Changes

No configuration changes are required. All existing `values.yaml` settings remain compatible with `4.3.1`.

| Setting | v4.3.0 | v4.3.1 |
|---------|--------|--------|
| `values.yaml` keys | (unchanged) | (unchanged) |
| Templates | (unchanged) | (unchanged) |
| Image references | (unchanged) | (unchanged) |
| Default values | (unchanged) | (unchanged) |

The changes in this release are limited to:

- Chart metadata (description field in `Chart.yaml`)
- Inline documentation comments in `values.yaml`

No functional configuration keys, default values, or template logic have been modified.

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will produce no changes to rendered manifests, so no rollout should occur.

**Recommended upgrade process:**

1. Review the rendered diff using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)). Expect an empty diff.
2. Run the upgrade command during a normal change window.
3. Verify pod state is unchanged after the upgrade:

```bash
kubectl get pods -n otel-collector-lerian
```

> **Note:** Because no manifest fields change, Kubernetes should not perform a rollout. If a rollout occurs, capture the diff and report it before proceeding in production.

**Optional: Review client.id configuration**

While not required for this upgrade, the improved documentation in `4.3.1` highlights that the chart ships with a placeholder `client.id` value. If you have not already customized this value, consider setting it to your organization's identifier:

```yaml
opentelemetry-collector:
  config:
    processors:
      resource/add_client_id:
        attributes:
          - key: client.id
            value: "your-organization-id"
            action: upsert
```

> **Note:** This is an existing configuration option, not a new requirement introduced in `4.3.1`. The documentation update simply makes this configuration more visible to operators.

## Preview changes before upgrading

```bash
helm diff upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 4.3.1 -n otel-collector-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 4.3.1 -n otel-collector-lerian
```
