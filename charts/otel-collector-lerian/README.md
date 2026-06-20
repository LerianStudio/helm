# OpenTelemetry Collector Lerian Helm Chart

## Chart Contract

- Chart type: `dependency-wrapper`
- Required secrets: `OTEL_API_KEY` must be supplied by the referenced `otel-api-key` Kubernetes Secret for telemetry export.
- Dependency notes: Wraps the upstream OpenTelemetry Collector chart and intentionally has no local application templates.
- Production overrides: Override collector endpoints, resource limits, RBAC scope, and the Secret referenced by `extraEnvs` for the target cluster.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

This Helm chart installs the [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) configured for Lerian's observability stack. It collects traces, logs, and metrics from Kubernetes workloads and exports them to Lerian's central telemetry backend.

This chart is intentionally a `dependency-wrapper`: it configures the upstream `opentelemetry-collector` chart and does not carry local Kubernetes templates. Application-chart requirements such as `templates/_helpers.tpl` and `values-template.yaml` do not apply unless local templates are added later. A `values.schema.json` is committed to keep the subchart configuration block validated, and `Chart.lock` is committed so dependency resolution is reproducible.

---

## Install OpenTelemetry Collector Lerian Helm Chart

To install the OpenTelemetry Collector using Helm, run the following command:

```console
$ helm install otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version <version> -n midaz --create-namespace
```

This will create a new namespace called `midaz` if it doesn't already exist and deploy the OpenTelemetry Collector Helm chart.

After installation, you can verify that the release was successful by listing the Helm releases in the midaz namespace:

```console
$ helm list -n midaz
```

---

## Prerequisites

Before installing this chart, you need to create a Kubernetes secret containing the API key for authenticating with the central collector:

```console
$ kubectl create secret generic otel-api-key --from-literal=api-key=<your-api-key> -n midaz
```

---

## Features

This chart provides a pre-configured OpenTelemetry Collector with the following capabilities:

### Receivers
- **OTLP**: Receives traces, logs, and metrics from instrumented applications via gRPC (port 4317) and HTTP (port 4318)
- **k8s_cluster**: Collects cluster-level state information (pod status, deployments, HPA replicas, container status, node conditions)
- **kubeletstats**: Collects pod/container performance metrics (CPU, memory) from the node's Kubelet
- **k8sobjects**: Watches Kubernetes events (pod scheduling, image pulls, OOMKills, etc.) for the namespaces in `k8sobjects.objects[0].namespaces` (default: `midaz` and `midaz-plugins`)

### Processors
- **memory_limiter**: Prevents out-of-memory situations (`check_interval: 1s`, `limit_percentage: 80`)
- **batch**: Batches telemetry data for efficient export (last in every pipeline, after enrichment)
- **k8sattributes**: Enriches telemetry with Kubernetes metadata (pod name, namespace, deployment). Uses a two-tier `pod_association` strategy: primary resolves identity from the `k8s.pod.ip` resource attribute (set by `lib-observability`-based apps via `OTEL_RESOURCE_ATTRIBUTES`); fallback uses the connection source IP (requires `hostNetwork: true` on the collector pod).
- **resource/add_client_id**: Adds `client.id` for multi-tenancy support
- **transform/remove_sensitive_attributes**: Removes sensitive payload data from spans (`app.request.payload`)
- **transform/normalize_http_semconv**: Bidirectional mirror between legacy HTTP attrs (`http.method`, `http.status_code`) and OTel stable (`http.request.method`, `http.response.status_code`). Keeps both forms populated on every span/log during the lib-observability migration window. Skips when the new method attr is `_OTHER` (cardinality protection sentinel).
- **transform/mask_body_sensitive_data**: Masks PII data in logs (documents, names, emails, addresses, phone numbers, PIX keys)
- **filter/drop_node_metrics**: Excludes node-level metrics
- **filter/include_midaz_namespaces**: BYOC privacy filter — restricts **metrics, logs and traces** to the `midaz` and `midaz-plugins` namespaces only. Telemetry from any other namespace is dropped at the collector before being exported.

### Connectors
- **spanmetrics**: Generates RED metrics (Rate, Errors, Duration) from trace spans

### Exporters
- **otlphttp/server**: Exports telemetry to Lerian's central telemetry endpoint (`https://telemetry.lerian.io`)

---

## Configuration Parameters

### Global Settings

| Parameter | Description | Default |
| --- | --- | --- |
| `opentelemetry-collector.mode` | Deployment mode (daemonset required for kubeletstats) | `daemonset` |
| `opentelemetry-collector.image.repository` | Container image repository | `otel/opentelemetry-collector-contrib` |
| `opentelemetry-collector.image.tag` | Container image tag | `0.142.0` |

### Resource Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `opentelemetry-collector.resources.limits.cpu` | CPU limit | `650m` |
| `opentelemetry-collector.resources.limits.memory` | Memory limit | `512Mi` |
| `opentelemetry-collector.resources.requests.cpu` | CPU request | `250m` |
| `opentelemetry-collector.resources.requests.memory` | Memory request | `256Mi` |

### Environment Variables

| Parameter | Description | Default |
| --- | --- | --- |
| `opentelemetry-collector.extraEnvs[0].name` | API key environment variable name | `OTEL_API_KEY` |
| `opentelemetry-collector.extraEnvs[0].valueFrom.secretKeyRef.name` | Secret name for API key | `otel-api-key` |
| `opentelemetry-collector.extraEnvs[0].valueFrom.secretKeyRef.key` | Secret key for API key | `api-key` |
| `GOMEMLIMIT` | Go memory limit | `200MiB` |
| `GOGC` | Go garbage collection percentage | `80` |
| `GOMAXPROCS` | Maximum number of Go processes | `2` |

### Receiver Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `config.receivers.otlp.protocols.grpc.endpoint` | OTLP gRPC endpoint | `0.0.0.0:4317` |
| `config.receivers.otlp.protocols.http.endpoint` | OTLP HTTP endpoint | `0.0.0.0:4318` |
| `config.receivers.k8s_cluster.collection_interval` | Cluster metrics collection interval | `60s` |
| `config.receivers.kubeletstats.collection_interval` | Kubelet stats collection interval | `10s` |

### Processor Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `config.processors.memory_limiter.limit_percentage` | Memory limit percentage | `80` |
| `config.processors.memory_limiter.spike_limit_percentage` | Spike limit percentage | `20` |
| `config.processors.batch.timeout` | Batch timeout | `200ms` |
| `config.processors.batch.send_batch_size` | Batch size | `512` |
| `config.processors.batch.send_batch_max_size` | Maximum batch size | `1024` |

### Exporter Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `config.exporters.otlphttp/server.endpoint` | Central telemetry endpoint | `https://telemetry.lerian.io:443` |

### Client Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `config.processors.resource/add_client_id.attributes[0].value` | Client ID for multi-tenancy | `Firmino` |

---

## Telemetry Pipelines

The chart configures the following pipelines. All pipelines follow the same processor ordering: `memory_limiter` first, `k8sattributes` before `batch` (batch drops the connection context that pod_association relies on), and `batch` last so all enrichment runs on individual records.

### Traces Pipeline
1. Receives traces via OTLP
2. `memory_limiter` (admission control)
3. `k8sattributes` (pod identity via k8s.pod.ip resource attribute or connection IP fallback)
4. `resource/add_client_id` (multi-tenancy)
5. `filter/include_midaz_namespaces` (BYOC privacy — drop spans from non-midaz namespaces)
6. `transform/remove_sensitive_attributes` (strip `app.request.payload`)
7. `transform/normalize_http_semconv` (mirror legacy ↔ OTel-stable HTTP attrs)
8. `batch`
9. Exports to central backend AND feeds the `spanmetrics` connector

### Metrics Pipeline (OTLP-pushed application metrics)
Accepts OTLP-pushed metrics from applications. Required so apps using `lib-observability` (which emits `http.server.request.duration` and other OTel-native metrics directly via the OTel SDK) deliver those to the central backend.

1. Receives metrics via OTLP
2. `memory_limiter` → `k8sattributes` → `resource/add_client_id` → `filter/include_midaz_namespaces` → `batch`
3. Exports to central backend

### Metrics/Spanmetrics Pipeline
Carries the RED metrics derived from spans by the `spanmetrics` connector.

1. Receives metrics from the `spanmetrics` connector
2. `memory_limiter` → `k8sattributes` → `resource/add_client_id` → `batch`
3. Exports to central backend

(No `filter/include_midaz_namespaces` here because spans were already filtered upstream in the `traces` pipeline.)

### Metrics/Cluster Pipeline
1. Receives metrics from `k8s_cluster` and `kubeletstats` receivers (OTLP is **not** in this pipeline — application OTLP metrics flow through the `Metrics` pipeline above to avoid double export)
2. `memory_limiter` → `k8sattributes` → `resource/add_client_id` → `filter/include_midaz_namespaces` → `filter/drop_node_metrics` → `batch`
3. Exports to central backend

### Logs Pipeline
1. Receives logs via OTLP and Kubernetes events via `k8sobjects`
2. `memory_limiter` → `k8sattributes` → `resource/add_client_id` → `filter/include_midaz_namespaces` (drops logs from non-midaz namespaces before masking) → 10 `transform/mask_body_sensitive_data_replace_*` (PII masking) → `batch`
3. Exports to central backend

## Pod identity (hostNetwork + pod_association)

The chart deploys the collector as a DaemonSet with `hostNetwork: true` and `dnsPolicy: ClusterFirstWithHostNet`. `hostPort` mappings are set to `0` (since hostNetwork binds the container directly to the node's network stack, hostPort would be redundant and could fight for ports during rolling updates).

This is required so the `k8sattributes` processor can resolve pod identity from the connection source IP — without `hostNetwork`, hostPort hairpin NAT would rewrite the source IP to the node IP and `k8sattributes` couldn't match telemetry to its originating pod.

Two-tier `pod_association`:
1. **Primary**: `from: resource_attribute, name: k8s.pod.ip` — works for any pod, no hostNetwork required. Apps need to emit `OTEL_RESOURCE_ATTRIBUTES=k8s.pod.ip=$(POD_IP)` (the `midaz` chart's `ledger`/`crm` templates set this automatically when `otel-collector-lerian.enabled=true`).
2. **Fallback**: `from: connection` — kicks in for apps that don't emit `k8s.pod.ip` (e.g. apps still on `lib-commons v2`). Requires the collector's `hostNetwork: true` to be honored by the cluster's Pod Security policy.

If your cluster's Pod Security Standards forbid `hostNetwork: true` you can still run the chart in a restricted mode by setting `hostNetwork: false` and ensuring **every** application emits the `k8s.pod.ip` resource attribute — the primary path is enough on its own.

---

## Sensitive Data Masking

The chart includes comprehensive PII masking for logs, including:

- **Documents**: CPF, CNPJ, tax IDs, national registration numbers
- **Names**: Customer names, sender/recipient names
- **Emails**: All email addresses
- **Addresses**: Street addresses, shipping/billing addresses
- **Phone numbers**: Cell phones, landlines, contact numbers
- **PIX keys**: EVP, dict values, UUIDs

---

## RBAC Configuration

The chart automatically creates the necessary ClusterRole with permissions to:

- Read events, namespaces, nodes, pods, services, and resource quotas
- Read deployments, daemonsets, replicasets, and statefulsets
- Read jobs and cronjobs
- Read horizontal pod autoscalers
- Access kubelet stats and metrics (nodes/proxy, nodes/stats, nodes/metrics)

---

## Dependencies

| Dependency | Version | Repository |
| --- | --- | --- |
| opentelemetry-collector | 0.142.0 | https://open-telemetry.github.io/opentelemetry-helm-charts |

---

## Customizing the Client ID

To customize the client ID for multi-tenancy, update the `values.yaml`:

```yaml
opentelemetry-collector:
  config:
    processors:
      resource/add_client_id:
        attributes:
          - key: client.id
            value: "your-client-id"
            action: upsert
```

---

## Troubleshooting

### Viewing Collector Logs

```console
$ kubectl logs -l app.kubernetes.io/name=otel-collector-lerian -n midaz
```

### Checking Collector Metrics

The collector exposes internal metrics on port 8887:

```console
$ kubectl port-forward svc/otel-collector-lerian 8887:8887 -n midaz
$ curl http://localhost:8887/metrics
```

### Verifying RBAC Permissions

```console
$ kubectl auth can-i list pods --as=system:serviceaccount:midaz:otel-collector-lerian -n midaz
```
