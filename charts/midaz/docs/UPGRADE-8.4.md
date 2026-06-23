# Helm Upgrade from v8.3.0 to v8.4.0

## Topics

- **[Features](#features)**
  - [1. Removal of otel-collector-lerian subchart dependency](#1-removal-of-otel-collector-lerian-subchart-dependency)
  - [2. Simplified OTEL configuration model](#2-simplified-otel-configuration-model)
  - [3. Enhanced OTEL environment variables](#3-enhanced-otel-environment-variables)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Option 1: Migrate to external OTEL collector (recommended)](#option-1-migrate-to-external-otel-collector-recommended)
  - [Option 2: Disable OTEL integration](#option-2-disable-otel-integration)
  - [Option 3: Configure custom OTEL endpoint via configmap](#option-3-configure-custom-otel-endpoint-via-configmap)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Removal of otel-collector-lerian subchart dependency

The `otel-collector-lerian` subchart has been completely removed from the chart dependencies. This subchart previously installed an OpenTelemetry collector as part of the Midaz deployment.

**Before (v8.3.0):**

```yaml
dependencies:
  - name: otel-collector-lerian
    version: 2.1.0
    repository: "oci://registry-1.docker.io/lerianstudio"
    condition: otel-collector-lerian.enabled
```

**After (v8.4.0):**

The dependency is no longer present in `Chart.yaml`.

> **Important:** If you were using `otel-collector-lerian.enabled: true` in v8.3.0, the collector will no longer be installed by this chart. You must deploy an external OTEL collector separately.

### 2. Simplified OTEL configuration model

The OTEL configuration has been simplified from a full subchart with collector configuration to a simple boolean flag that controls environment variable injection.

| Setting | v8.3.0 | v8.4.0 |
|---------|--------|--------|
| `otel-collector-lerian.enabled` | Installs subchart + injects env vars | Only injects env vars (default: `true`) |
| `otel-collector-lerian.external` | Uses external collector without subchart | Removed |
| `otel-collector-lerian.opentelemetry-collector` | Full collector config | Removed |
| `otel-collector-lerian.extraEnvs` | Collector environment variables | Removed |
| `otel-collector-lerian.exporters` | Collector exporters config | Removed |

**Before (v8.3.0):**

```yaml
otel-collector-lerian:
  enabled: false
  external: false
  opentelemetry-collector:
    config:
      processors:
        resource/add_client_id:
          attributes:
            - key: client.id
              value: "Lerian"
              action: upsert
  extraEnvs:
    - name: OTEL_API_KEY
      valueFrom:
        secretKeyRef:
          name: otel-api-key
          key: api-key
  exporters:
    otlphttp/server:
      endpoint: "https://telemetry.lerian.io:443"
      headers:
        x-api-key: "${OTEL_API_KEY}"
```

**After (v8.4.0):**

```yaml
# -- OTEL exporter configuration for midaz services.
# When enabled, HOST_IP, POD_IP, OTEL_EXPORTER_OTLP_ENDPOINT and OTEL_RESOURCE_ATTRIBUTES
# are injected into the `ledger` and `crm` deployments only. Port is fixed at 4317.
# If you need a different collector endpoint, leave enabled=false and configure
# OTEL env vars directly in the application configmap (ledger.configmap / crm.configmap).
otel-collector-lerian:
  enabled: true
```

> **Note:** The new model assumes you have an external OTEL collector running as a DaemonSet with `hostPort: 4317` on each node. The chart only injects the necessary environment variables to connect to it.

### 3. Enhanced OTEL environment variables

The OTEL environment variable injection has been enhanced to include pod-level resource attributes for better observability.

**Before (v8.3.0):**

```yaml
- name: "HOST_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
```

**After (v8.4.0):**

```yaml
- name: "POD_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: "HOST_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
- name: "OTEL_RESOURCE_ATTRIBUTES"
  value: "k8s.pod.ip=$(POD_IP)"
```

#### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POD_IP` | `status.podIP` | The pod's IP address, sourced from the Kubernetes downward API |
| `OTEL_RESOURCE_ATTRIBUTES` | `k8s.pod.ip=$(POD_IP)` | OpenTelemetry resource attributes for pod-level identification |

These variables are injected into both `ledger` and `crm` deployments when `otel-collector-lerian.enabled: true`.

## Configuration Reference

The `otel-collector-lerian` section now supports only one configuration option:

| Flag | Default | Description |
|------|---------|-------------|
| `otel-collector-lerian.enabled` | `true` | Inject OTEL environment variables (`HOST_IP`, `POD_IP`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_RESOURCE_ATTRIBUTES`) into `ledger` and `crm` deployments. Assumes an external OTEL collector is available at `$(HOST_IP):4317`. |

> **Warning:** Setting `enabled: true` without an external OTEL collector running on each node will cause the `ledger` and `crm` services to fail when attempting to export telemetry data.

## Migration Steps

### Option 1: Migrate to external OTEL collector (recommended)

If you were using the embedded `otel-collector-lerian` subchart in v8.3.0, you must deploy an external OTEL collector before upgrading.

**Step 1:** Deploy an OTEL collector DaemonSet with `hostPort: 4317` in your cluster. Example using the official OpenTelemetry Helm chart:

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

```bash
helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace otel-system \
  --create-namespace \
  --set mode=daemonset \
  --set ports.otlp.enabled=true \
  --set ports.otlp.containerPort=4317 \
  --set ports.otlp.hostPort=4317 \
  --set ports.otlp.protocol=TCP
```

**Step 2:** Configure the collector to export to your telemetry backend. Create a `values.yaml` for the collector:

```yaml
mode: daemonset
ports:
  otlp:
    enabled: true
    containerPort: 4317
    hostPort: 4317
    protocol: TCP
config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
  processors:
    batch: {}
    resource:
      attributes:
        - key: client.id
          value: "YourCompanyName"
          action: upsert
  exporters:
    otlphttp:
      endpoint: "https://your-telemetry-backend.example.com:443"
      headers:
        x-api-key: "${OTEL_API_KEY}"
  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [batch, resource]
        exporters: [otlphttp]
```

**Step 3:** Upgrade the Midaz chart with OTEL enabled:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm \
  --version 8.4.0 \
  --namespace midaz \
  --set otel-collector-lerian.enabled=true
```

### Option 2: Disable OTEL integration

If you do not need OpenTelemetry integration, disable the environment variable injection:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm \
  --version 8.4.0 \
  --namespace midaz \
  --set otel-collector-lerian.enabled=false
```

Or in your `values.yaml`:

```yaml
otel-collector-lerian:
  enabled: false
```

### Option 3: Configure custom OTEL endpoint via configmap

If you need to use a different OTEL collector endpoint (not `$(HOST_IP):4317`), disable the automatic injection and configure the environment variables directly in the application configmaps:

**Step 1:** Disable automatic injection:

```yaml
otel-collector-lerian:
  enabled: false
```

**Step 2:** Override the `ledger` and `crm` configmaps with your custom OTEL endpoint:

```yaml
ledger:
  configmap:
    OTEL_EXPORTER_OTLP_ENDPOINT: "http://my-otel-collector.otel-system.svc.cluster.local:4317"
    OTEL_RESOURCE_ATTRIBUTES: "service.name=midaz-ledger,k8s.namespace.name=midaz"

crm:
  configmap:
    OTEL_EXPORTER_OTLP_ENDPOINT: "http://my-otel-collector.otel-system.svc.cluster.local:4317"
    OTEL_RESOURCE_ATTRIBUTES: "service.name=midaz-crm,k8s.namespace.name=midaz"
```

> **Note:** See the [ledger configmap](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/ledger/configmap.yaml) and [crm configmap](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/crm/configmap.yaml) templates for all available configuration options.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.4.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.4.0 -n midaz
```
