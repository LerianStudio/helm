# Helm Upgrade from v2.2.10 to v2.2.11

## Table of Contents
- [Overview](#overview)
- [Resource Allocation Changes](#resource-allocation-changes)
  - [PIX Service Memory Increase](#pix-service-memory-increase)
- [Autoscaling Configuration Updates](#autoscaling-configuration-updates)
  - [Increased Maximum Replicas](#increased-maximum-replicas)
- [Configuration Changes](#configuration-changes)
  - [PIX ConfigMap Updates](#pix-configmap-updates)
  - [QR Code Image Tag](#qr-code-image-tag)
  - [MIDAZ Ledger ID Default Value](#midaz-ledger-id-default-value)
- [Secret Management Updates](#secret-management-updates)
  - [New Secret Key for QR Code Service](#new-secret-key-for-qr-code-service)
- [Deployment Configuration Changes](#deployment-configuration-changes)
  - [Liveness Probe Timing Adjustment](#liveness-probe-timing-adjustment)
- [Preview changes before upgrading](#preview-changes-before-upgrading)
- [Command to upgrade](#command-to-upgrade)

## Overview

This patch release updates the plugin-br-pix-direct-jd chart from v2.2.10 to v2.2.11, introducing resource optimization changes and configuration refinements. The primary focus is on increasing memory allocation for the PIX service, expanding autoscaling capacity, and improving observability through enhanced logging configuration.

**Key changes:**
- Doubled memory limits for the pix service
- Increased maximum autoscaling replicas from 9 to 12
- Enhanced logging configuration with new environment variables
- New secret key for QR code service
- Faster liveness probe initialization
- Updated default values for MIDAZ configuration

## Resource Allocation Changes

### PIX Service Memory Increase

The PIX service memory limit has been doubled to accommodate higher workload demands:

| Setting | v2.2.10 | v2.2.11 |
|---------|---------|---------|
| pix.resources.limits.memory | 256Mi | 512Mi |

**Why this matters:** This increase ensures the PIX service has adequate resources to handle transaction processing without memory pressure or OOMKilled events under load. This change restores the memory limit to the same level as v2.2.5, suggesting that the reduction in v2.2.6 was insufficient for production workloads.

**Example configuration:**

```yaml
pix:
  resources:
    limits:
      cpu: 200m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
```

> **Note:** Monitor memory usage after upgrade to ensure the increased limit meets your workload requirements. If you experience memory pressure, you may need to increase the request value as well.

## Autoscaling Configuration Updates

### Increased Maximum Replicas

The maximum autoscaling replica count has been increased to handle higher peak loads:

| Setting | v2.2.10 | v2.2.11 |
|---------|---------|---------|
| pix.autoscaling.maxReplicas | 9 | 12 |

**Why this matters:** The system can now scale to 33% more replicas (12 vs 9), providing better horizontal scaling capability for traffic spikes while maintaining the same minimum baseline of 3 replicas.

**Complete autoscaling configuration:**

```yaml
pix:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 12
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 85
```

### Operational Impact

**Before upgrade (v2.2.10):**
- Minimum pods: 3
- Maximum pods: 9
- Memory per pod limit: 256Mi
- Maximum memory consumption: 2304Mi (2.25Gi)

**After upgrade (v2.2.11):**
- Minimum pods: 3
- Maximum pods: 12
- Memory per pod limit: 512Mi
- Maximum memory consumption: 6144Mi (6Gi)

**Resource calculation:**
- Baseline memory requirement increases from 768Mi to 1536Mi (2x increase)
- Maximum memory requirement increases from 2304Mi to 6144Mi (2.67x increase)
- Maximum pod count increases by 33% (9 to 12 pods)

> **Warning:** These changes significantly increase your cluster's maximum resource requirements. Ensure your nodes have sufficient available memory (at least 6Gi) to accommodate peak scaling before upgrading.

## Configuration Changes

### PIX ConfigMap Updates

The PIX service logging configuration has been enhanced with new environment variables:

**Before (v2.2.10):**

```yaml
data:
  NODE_ENV: "production"
  DEBUG: "true"
  LOG_LEVEL: "info"
  NEW_VAR: "value"
```

**After (v2.2.11):**

```yaml
data:
  NODE_ENV: "production"
  DEBUG: "true"
  LOG_LEVEL: "debug"
  NEW_VAR: "value"
  NEW_TAG: "1.2.1-beta.11"
```

**Changes:**

| Setting | v2.2.10 | v2.2.11 |
|---------|---------|---------|
| pix.configmap.LOG_LEVEL (default) | info | debug |

**New environment variables:**
- **NEW_TAG**: References the application image tag from `pix.image.tag` or falls back to `Chart.AppVersion`. Default: `1.2.1-beta.11`. This provides version information to the application runtime for logging and monitoring purposes.

**Why this matters:**
- **LOG_LEVEL change to "debug"**: Provides more verbose logging by default, which is useful for troubleshooting but will increase log volume. Consider overriding this to "info" or "warn" in production environments.
- **NEW_TAG addition**: Enables the application to report its version in logs and metrics, improving observability and debugging capabilities.

> **Warning:** The default LOG_LEVEL of "debug" will significantly increase log output. For production deployments, consider overriding this value:

```yaml
pix:
  configmap:
    LOG_LEVEL: "info"
```

### QR Code Image Tag

The QR code service now has an explicit image tag defined:

| Setting | v2.2.10 | v2.2.11 |
|---------|---------|---------|
| qrcode.image.tag | "" (empty, uses appVersion) | 1.2.1-beta.11 |

**Why this matters:** Previously, the QR code service would use the Chart's appVersion by default. Now it explicitly pins to version `1.2.1-beta.11`, ensuring consistent deployment regardless of the Chart's appVersion value.

**Example configuration:**

```yaml
qrcode:
  image:
    repository: your-registry/qrcode-service
    pullPolicy: Always
    tag: "1.2.1-beta.11"
```

> **Note:** If you need to override this version, you can specify a different tag in your values file. The explicit tag provides better version control and predictability.

### MIDAZ Ledger ID Default Value

The MIDAZ ledger ID configuration has been updated:

| Setting | v2.2.10 | v2.2.11 |
|---------|---------|---------|
| pix.configmap.MIDAZ_LEDGER_ID | "your_ledger" | "" (empty string) |

**Why this matters:** The default value has changed from a placeholder string to an empty string, making it clearer that this value must be explicitly configured for your environment.

**Migration steps:**

1. **Before upgrading**, ensure you have set the MIDAZ_LEDGER_ID in your values file:

```yaml
pix:
  configmap:
    MIDAZ_LEDGER_ID: "your-actual-ledger-id"
```

2. **Verify your current configuration** to ensure you're not relying on the old default:

```bash
helm get values plugin-br-pix-direct-jd -n plugin-br-pix-direct-jd
```

> **Important:** If you were using the default value "your_ledger", you must now explicitly set this value in your configuration. An empty MIDAZ_LEDGER_ID may cause the application to fail to connect to the MIDAZ service.

## Secret Management Updates

### New Secret Key for QR Code Service

A new secret has been added to the QR code service secrets configuration:

**Before (v2.2.10):**

```yaml
data:
  KEY: {{ .Values.qrcode.secrets.PRIVATE_KEY | default "" | b64enc | quote }}
  CERTIFICATE: {{ .Values.qrcode.secrets.CERTIFICATE | default "lerian" | b64enc | quote }}
```

**After (v2.2.11):**

```yaml
data:
  KEY: {{ .Values.qrcode.secrets.PRIVATE_KEY | default "" | b64enc | quote }}
  CERTIFICATE: {{ .Values.qrcode.secrets.CERTIFICATE | default "lerian" | b64enc | quote }}
  NEW_KEY: {{ .Values.qrcode.secrets.NEW_PRIVATE_KEY | default "" | b64enc | quote }}
```

**New secret:**
- **NEW_KEY**: Additional private key for QR code service cryptographic operations. Default: `""` (empty string). The secret is sourced from `qrcode.secrets.NEW_PRIVATE_KEY` in your values file.

**Migration steps:**

1. **Determine if your application requires this new key**. Check your application documentation or with your development team to understand the purpose of NEW_KEY.

2. **If required**, add the new secret to your values file before upgrading:

```yaml
qrcode:
  secrets:
    NEW_PRIVATE_KEY: "your-new-private-key-value"
```

3. **For production environments**, use external secret management:

```bash
# Example: Update your existing secret management configuration
# to include the NEW_PRIVATE_KEY value
```

> **Note:** The default empty string may be acceptable if your application doesn't require this key. However, verify with your application requirements before upgrading to production.

## Deployment Configuration Changes

### Liveness Probe Timing Adjustment

The PIX service liveness probe initialization has been optimized:

| Setting | v2.2.10 | v2.2.11 |
|---------|---------|---------|
| pix.livenessProbe.initialDelaySeconds | 10 | 5 |

**Why this matters:** Reducing the initial delay from 10 to 5 seconds allows Kubernetes to detect unhealthy pods faster, improving recovery time during deployments or failures. This change assumes the application starts quickly enough to respond to health checks within 5 seconds.

**Complete probe configuration:**

```yaml
livenessProbe:
  initialDelaySeconds: 5
  periodSeconds: 5
  httpGet:
    path: /v1/health
    port: http
```

> **Note:** If your application takes longer than 5 seconds to start and respond to health checks, you may see pods being killed prematurely. Monitor pod restarts after upgrade and adjust this value if needed:

```yaml
pix:
  livenessProbe:
    initialDelaySeconds: 10
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.11 -n plugin-br-pix-direct-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.11 -n plugin-br-pix-direct-jd
```
