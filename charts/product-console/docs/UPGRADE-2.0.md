# Helm Upgrade from v1.x to v2.0

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [OpenTelemetry configuration refactored](#opentelemetry-configuration-refactored)
- **[Features](#features)**
  - [1. Dynamic OTEL endpoint injection](#1-dynamic-otel-endpoint-injection)
  - [2. MongoDB connection parameters](#2-mongodb-connection-parameters)
  - [3. Validation for telemetry configuration](#3-validation-for-telemetry-configuration)
- **[Migration Guide](#migration-guide)**
  - [Scenario 1: Not using OpenTelemetry](#scenario-1-not-using-opentelemetry)
  - [Scenario 2: Using external OTEL collector (DaemonSet)](#scenario-2-using-external-otel-collector-daemonset)
  - [Scenario 3: Using static OTEL host](#scenario-3-using-static-otel-host)
- **[Configuration Reference](#configuration-reference)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### OpenTelemetry configuration refactored

Starting from version 2.0, the OpenTelemetry configuration has been completely refactored. The chart now supports dynamic injection of OTEL endpoints, making it easier to integrate with DaemonSet-based OTEL collectors.

**Default values:**

| Setting | v1.x (before) | v2.0 (after) |
|---------|---------------|--------------|
| `otel.enabled` | N/A | `false` |
| `otel.external` | N/A | `false` |
| `otel.host` | N/A | `""` |
| `otel.port` | N/A | `4318` |
| `configmap.OTEL_URL_METRICS` | Manual | Auto-injected |
| `configmap.OTEL_URL_TRACES` | Manual | Auto-injected |
| `configmap.OTEL_URL_LOGS` | Manual | Auto-injected |

**Impact:**

- If you were manually setting `OTEL_URL_*` environment variables in `configmap`, you should now use the new `otel` configuration block
- The chart now validates that when `ENABLE_TELEMETRY=true`, either `otel.enabled` or `otel.external` must be set

## Features

### 1. Dynamic OTEL endpoint injection

The chart now automatically injects OTEL endpoint environment variables when telemetry is enabled. This supports two modes:

**External mode (recommended for DaemonSet collectors):**

When `otel.external=true` and no static host is provided, the chart injects the pod's host IP dynamically:

```yaml
otel:
  external: true
  port: 4318
```

This results in the following environment variables being injected:

```yaml
- name: HOST_IP
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: OTEL_HOST
  value: "$(HOST_IP)"
- name: OTEL_URL_METRICS
  value: "http://$(HOST_IP):4318/v1/metrics"
- name: OTEL_URL_TRACES
  value: "http://$(HOST_IP):4318/v1/traces"
- name: OTEL_URL_LOGS
  value: "http://$(HOST_IP):4318/v1/logs"
```

**Static host mode:**

When a specific OTEL collector host is known:

```yaml
otel:
  external: true
  host: "otel-collector.observability.svc.cluster.local"
  port: 4318
```

### 2. MongoDB connection parameters

A new `MONGO_PARAMETERS` configuration option has been added to support additional MongoDB connection string parameters. This is particularly useful for connecting to managed MongoDB services like AWS DocumentDB that require TLS.

**Example for AWS DocumentDB:**

```yaml
configmap:
  MONGO_PARAMETERS: "tls=true&tlsInsecure=true&directConnection=true&retryWrites=false"
```

**Default value:**

```yaml
configmap:
  MONGO_PARAMETERS: ""
```

### 3. Validation for telemetry configuration

The chart now includes validation to prevent misconfiguration. If `ENABLE_TELEMETRY` is set to `"true"` but no OTEL exporter is configured, the chart will fail with a clear error message:

```
ENABLE_TELEMETRY is 'true' but no OTEL exporter is configured. 
Set either otel.enabled=true or otel.external=true to configure OTEL endpoints.
```

## Migration Guide

### Scenario 1: Not using OpenTelemetry

If you are not using OpenTelemetry, no changes are required. The default configuration keeps telemetry disabled:

```yaml
configmap:
  ENABLE_TELEMETRY: "false"

otel:
  enabled: false
  external: false
```

### Scenario 2: Using external OTEL collector (DaemonSet)

If you have an OTEL collector deployed as a DaemonSet with hostPort (recommended for Kubernetes environments):

**Before (v1.x):**

```yaml
configmap:
  ENABLE_TELEMETRY: "true"
  OTEL_URL_METRICS: "http://$(HOST_IP):4318/v1/metrics"
  OTEL_URL_TRACES: "http://$(HOST_IP):4318/v1/traces"
  OTEL_URL_LOGS: "http://$(HOST_IP):4318/v1/logs"
```

**After (v2.0):**

```yaml
configmap:
  ENABLE_TELEMETRY: "true"

otel:
  external: true
  port: 4318
```

The `HOST_IP` and `OTEL_URL_*` variables are now automatically injected by the chart.

### Scenario 3: Using static OTEL host

If you have a centralized OTEL collector service:

**Before (v1.x):**

```yaml
configmap:
  ENABLE_TELEMETRY: "true"
  OTEL_URL_METRICS: "http://otel-collector:4318/v1/metrics"
  OTEL_URL_TRACES: "http://otel-collector:4318/v1/traces"
  OTEL_URL_LOGS: "http://otel-collector:4318/v1/logs"
```

**After (v2.0):**

```yaml
configmap:
  ENABLE_TELEMETRY: "true"

otel:
  external: true
  host: "otel-collector"
  port: 4318
```

## Configuration Reference

### OTEL configuration block

```yaml
otel:
  # Enable OTEL collector subchart installation (if applicable)
  enabled: false
  
  # Use externally installed OTEL collector
  # When true, deployment will inject OTEL_URL_* environment variables
  external: false
  
  # OTEL collector host (optional)
  # If set, uses this static host
  # If empty, injects HOST_IP from pod's node (for DaemonSet with hostPort)
  host: ""
  
  # OTEL collector HTTP port (OTLP/HTTP protocol)
  port: 4318
```

### New environment variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MONGO_PARAMETERS` | Additional MongoDB connection string parameters | `""` |
| `OTEL_RECEIVER_HTTP_PORT` | OTEL receiver HTTP port | `"4318"` |

### Injected environment variables (when otel.external=true)

| Variable | Description |
|----------|-------------|
| `HOST_IP` | Pod's host IP (only when `otel.host` is empty) |
| `OTEL_HOST` | OTEL collector host |
| `OTEL_URL_METRICS` | Full URL for metrics endpoint |
| `OTEL_URL_TRACES` | Full URL for traces endpoint |
| `OTEL_URL_LOGS` | Full URL for logs endpoint |

## Command to upgrade

```bash
helm upgrade product-console oci://ghcr.io/lerianstudio/product-console-helm \
  --version 2.0.0 \
  -n product-console
```

**With OTEL enabled:**

```bash
helm upgrade product-console oci://ghcr.io/lerianstudio/product-console-helm \
  --version 2.0.0 \
  --set configmap.ENABLE_TELEMETRY="true" \
  --set otel.external=true \
  -n product-console
```
