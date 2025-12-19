# OpenTelemetry Collector Lerian Helm Chart

This Helm chart installs the [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) configured for Lerian's observability stack. It collects traces, logs, and metrics from Kubernetes workloads and exports them to Lerian's central telemetry backend.

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
- **k8s_cluster**: Collects cluster-level state information (pod status, deployments, etc.)
- **kubeletstats**: Collects pod/container performance metrics (CPU, memory) from the node's Kubelet

### Processors
- **memory_limiter**: Prevents out-of-memory situations
- **batch**: Batches telemetry data for efficient export
- **k8sattributes**: Enriches telemetry with Kubernetes metadata (pod name, namespace, deployment)
- **resource/add_client_id**: Adds client ID for multi-tenancy support
- **transform/remove_sensitive_attributes**: Removes sensitive payload data from spans
- **transform/mask_body_sensitive_data**: Masks PII data in logs (documents, names, emails, addresses, phone numbers, PIX keys)
- **filter/drop_node_metrics**: Excludes node-level metrics
- **filter/include_midaz_namespaces**: Filters metrics to include only `midaz` and `midaz-plugins` namespaces

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
| `opentelemetry-collector.image.tag` | Container image tag | `0.131.0` |

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

The chart configures the following pipelines:

### Traces Pipeline
1. Receives traces via OTLP
2. Applies memory limiter and batching
3. Enriches with Kubernetes metadata
4. Adds client ID
5. Removes sensitive attributes
6. Exports to central backend and spanmetrics connector

### Metrics/Spanmetrics Pipeline
1. Receives span-derived metrics from the spanmetrics connector
2. Applies memory limiter and batching
3. Enriches with Kubernetes metadata
4. Adds client ID
5. Exports to central backend

### Metrics/Cluster Pipeline
1. Receives metrics from OTLP, k8s_cluster, and kubeletstats receivers
2. Applies memory limiter and batching
3. Adds client ID and Kubernetes metadata
4. Filters to include only midaz namespaces
5. Drops node-level metrics
6. Exports to central backend

### Logs Pipeline
1. Receives logs via OTLP
2. Applies memory limiter and batching
3. Enriches with Kubernetes metadata
4. Adds client ID
5. Masks sensitive data (PII) in log bodies
6. Exports to central backend

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
| opentelemetry-collector | 0.131.0 | https://open-telemetry.github.io/opentelemetry-helm-charts |

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