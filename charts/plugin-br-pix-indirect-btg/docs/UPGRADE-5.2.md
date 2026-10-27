<!-- {% raw %} -->
# Helm Upgrade from v5.1.0 to v5.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Event streaming support](#1-event-streaming-support)
- **[Configuration Reference](#configuration-reference)**
  - [Streaming configuration flags](#streaming-configuration-flags)
  - [Streaming credentials](#streaming-credentials)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that upgrades the application version from `1.11.0` to `1.12.0` and introduces optional event streaming support for the `pix` component. The streaming feature is disabled by default, so existing deployments will continue to work without any configuration changes.

The expected upgrade path is an in-place Helm upgrade. If you want to enable the new streaming feature, you must provide broker connection details and credentials before upgrading.

## Features

### 1. Event streaming support

The `pix` component now supports publishing CloudEvents to a streaming broker (e.g., Kafka, Redpanda). This feature is **disabled by default** and requires explicit configuration to activate.

**What changed:**

Four new configuration flags were added to the `pix` ConfigMap, and two new optional secrets were added for broker authentication:

| Setting | v5.1.0 | v5.2.0 |
|---------|--------|--------|
| `pix.configmap.STREAMING_ENABLED` | (not present) | `"false"` (default) |
| `pix.configmap.STREAMING_BROKERS` | (not present) | `""` (default) |
| `pix.configmap.STREAMING_CLOUDEVENTS_SOURCE` | (not present) | `"plugin-br-pix-indirect-btg"` (default) |
| `pix.configmap.STREAMING_TENANT_ID` | (not present) | `"default"` (default) |
| `pix.secrets.STREAMING_SASL_PASSWORD` | (not present) | `""` (default, optional) |
| `pix.secrets.STREAMING_TLS_CA_CERT` | (not present) | `""` (default, optional) |

**Why it matters:**

Event streaming enables real-time integration with downstream systems by publishing PIX transaction events to a message broker. This allows operators to build event-driven workflows, audit trails, and analytics pipelines without polling the PIX API.

**Operational impact:**

- If you **do not set** `STREAMING_ENABLED` to `"true"`, the upgrade has **no runtime impact** — the `pix` service will continue to operate exactly as before.
- If you **enable streaming**, you must provide valid broker connection details (`STREAMING_BROKERS`) and, if your broker requires SASL authentication, the `STREAMING_SASL_PASSWORD` secret.

**Template changes:**

The `pix` ConfigMap template now includes four new environment variables:

**Before (v5.1.0):**

```yaml
data:
  SWAGGER_ENABLED: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.pix.configmap.SWAGGER_ENABLED | quote }}
  # Extra Env Vars
  {{- with .Values.pix.extraEnvVars }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
```

**After (v5.2.0):**

```yaml
data:
  SWAGGER_ENABLED: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.pix.configmap.SWAGGER_ENABLED | quote }}
  STREAMING_BROKERS: {{ .Values.pix.configmap.STREAMING_BROKERS | default "" | quote }}
  STREAMING_CLOUDEVENTS_SOURCE: {{ .Values.pix.configmap.STREAMING_CLOUDEVENTS_SOURCE | default "plugin-br-pix-indirect-btg" | quote }}
  STREAMING_ENABLED: {{ .Values.pix.configmap.STREAMING_ENABLED | default "false" | quote }}
  STREAMING_TENANT_ID: {{ .Values.pix.configmap.STREAMING_TENANT_ID | default "default" | quote }}
  # Extra Env Vars
  {{- with .Values.pix.extraEnvVars }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
```

The `pix` Secret template now conditionally includes two new fields when set:

**Before (v5.1.0):**

```yaml
data:
  ANTIFRAUD_HOOK_HMAC_SECRET: {{ .Values.pix.secrets.ANTIFRAUD_HOOK_HMAC_SECRET | default "" | b64enc | quote }}
  ANTIFRAUD_HOOK_AUTH_HEADER_VALUE: {{ .Values.pix.secrets.ANTIFRAUD_HOOK_AUTH_HEADER_VALUE | default "" | b64enc | quote }}
```

**After (v5.2.0):**

```yaml
data:
  ANTIFRAUD_HOOK_HMAC_SECRET: {{ .Values.pix.secrets.ANTIFRAUD_HOOK_HMAC_SECRET | default "" | b64enc | quote }}
  ANTIFRAUD_HOOK_AUTH_HEADER_VALUE: {{ .Values.pix.secrets.ANTIFRAUD_HOOK_AUTH_HEADER_VALUE | default "" | b64enc | quote }}

  # Streaming broker credentials (only rendered when set; SASL password and CA bundle, base64 PEM)
  {{- if .Values.pix.secrets.STREAMING_SASL_PASSWORD }}
  STREAMING_SASL_PASSWORD: {{ .Values.pix.secrets.STREAMING_SASL_PASSWORD | b64enc | quote }}
  {{- end }}
  {{- if .Values.pix.secrets.STREAMING_TLS_CA_CERT }}
  STREAMING_TLS_CA_CERT: {{ .Values.pix.secrets.STREAMING_TLS_CA_CERT | b64enc | quote }}
  {{- end }}
```

## Configuration Reference

### Streaming configuration flags

The following flags control the streaming feature in the `pix` component:

| Flag | Default | Description |
|------|---------|-------------|
| `pix.configmap.STREAMING_ENABLED` | `"false"` | Enables event streaming when set to `"true"` |
| `pix.configmap.STREAMING_BROKERS` | `""` | Comma-separated list of broker addresses (e.g., `"kafka-1:9092,kafka-2:9092"`) |
| `pix.configmap.STREAMING_CLOUDEVENTS_SOURCE` | `"plugin-br-pix-indirect-btg"` | CloudEvents `source` attribute for published events |
| `pix.configmap.STREAMING_TENANT_ID` | `"default"` | Tenant identifier included in event metadata |

**Example configuration to enable streaming:**

```yaml
pix:
  configmap:
    STREAMING_ENABLED: "true"
    STREAMING_BROKERS: "kafka-1.example.com:9092,kafka-2.example.com:9092"
    STREAMING_CLOUDEVENTS_SOURCE: "pix-production"
    STREAMING_TENANT_ID: "tenant-123"
```

> **Important:** `STREAMING_BROKERS` must be set when `STREAMING_ENABLED` is `"true"`, or the `pix` service will fail to start.

### Streaming credentials

The following secrets are **optional** and only required when your broker enforces SASL authentication or TLS with a custom CA certificate:

| Secret | Format | Description |
|--------|--------|-------------|
| `pix.secrets.STREAMING_SASL_PASSWORD` | Plain text | SASL password for broker authentication (automatically base64-encoded by Helm) |
| `pix.secrets.STREAMING_TLS_CA_CERT` | Base64-encoded PEM | Custom CA certificate bundle for TLS verification (automatically base64-encoded by Helm) |

**Example configuration with SASL authentication:**

```yaml
pix:
  configmap:
    STREAMING_ENABLED: "true"
    STREAMING_BROKERS: "kafka.example.com:9093"
  secrets:
    STREAMING_SASL_PASSWORD: "my-sasl-password"
```

**Example configuration with custom TLS CA certificate:**

```yaml
pix:
  configmap:
    STREAMING_ENABLED: "true"
    STREAMING_BROKERS: "kafka.example.com:9093"
  secrets:
    STREAMING_TLS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKJ...
      -----END CERTIFICATE-----
```

> **Note:** Both `STREAMING_SASL_PASSWORD` and `STREAMING_TLS_CA_CERT` are automatically base64-encoded by the Helm template. Provide the plain-text password and PEM-formatted certificate in your values file.

> **Warning:** If `STREAMING_SASL_PASSWORD` or `STREAMING_TLS_CA_CERT` are left empty, the corresponding secret keys will **not be rendered** in the Kubernetes Secret. This is intentional to avoid creating empty secret entries.

## Migration Steps

This upgrade requires no destructive migration steps. The streaming feature is disabled by default, so existing deployments will continue to work without changes.

**Recommended upgrade process:**

### Option 1: Upgrade without enabling streaming (default)

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -l app.kubernetes.io/name=plugin-br-pix-indirect-btg
```

4. Check the `pix` service logs to confirm the upgrade was successful:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=pix --tail=50
```

### Option 2: Upgrade and enable streaming

1. Prepare a custom values file with streaming configuration:

```yaml
pix:
  configmap:
    STREAMING_ENABLED: "true"
    STREAMING_BROKERS: "kafka-1.example.com:9092,kafka-2.example.com:9092"
    STREAMING_CLOUDEVENTS_SOURCE: "pix-production"
    STREAMING_TENANT_ID: "tenant-123"
  secrets:
    STREAMING_SASL_PASSWORD: "my-sasl-password"  # Optional, only if SASL is enabled
    STREAMING_TLS_CA_CERT: |                     # Optional, only if custom CA is required
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKJ...
      -----END CERTIFICATE-----
```

2. Review the changes using the helm-diff plugin:

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.0 -n plugin-br-pix-indirect-btg -f custom-values.yaml
```

3. Run the upgrade command with your custom values file:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.0 -n plugin-br-pix-indirect-btg -f custom-values.yaml
```

4. Verify the `pix` pods are running and connected to the broker:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=pix
```

5. Check the `pix` service logs for streaming connection messages:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=pix --tail=100 | grep -i streaming
```

> **Note:** The upgrade triggers a rolling restart of all five deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) because the image tag changes from `1.11.0` to `1.12.0`. Depending on your replica count and readiness probe timing, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.0 -n plugin-br-pix-indirect-btg
```
<!-- {% endraw %} -->
