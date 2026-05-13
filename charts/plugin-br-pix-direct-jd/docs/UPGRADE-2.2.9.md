# Helm Upgrade from v2.2.8 to v2.2.9

## Table of Contents
- [Overview](#overview)
- [Application Version Updates](#application-version-updates)
- [Resource Allocation Changes](#resource-allocation-changes)
  - [PIX Service Memory Increase](#pix-service-memory-increase)
- [Autoscaling Configuration Updates](#autoscaling-configuration-updates)
  - [CPU Utilization Threshold Adjustment](#cpu-utilization-threshold-adjustment)
- [Configuration Changes](#configuration-changes)
  - [PIX Service ConfigMap Updates](#pix-service-configmap-updates)
  - [Job ConfigMap Updates](#job-configmap-updates)
  - [Default Value Updates](#default-value-updates)
- [Health Check Configuration Changes](#health-check-configuration-changes)
  - [Liveness Probe Timing Adjustment](#liveness-probe-timing-adjustment)
- [Preview changes before upgrading](#preview-changes-before-upgrading)
- [Command to upgrade](#command-to-upgrade)

## Overview

This patch release updates the plugin-br-pix-direct-jd chart from v2.2.8 to v2.2.9, introducing resource optimization changes and configuration refinements. The primary focus is on increasing memory allocation for the PIX service, adjusting autoscaling behavior, and updating logging and environment configurations.

**Key changes:**
- Application image update to beta.12
- Doubled memory limits for the PIX service
- Adjusted CPU autoscaling threshold for earlier scaling
- Modified logging defaults and environment configuration
- New environment variable added to PIX service
- Faster liveness probe initialization
- Updated default values for MIDAZ configuration

## Application Version Updates

This release updates the container image for the PIX component:

| Component | v2.2.8 | v2.2.9 |
|-----------|--------|--------|
| pix.image.tag | 1.2.1-beta.11 | 1.2.1-beta.12 |
| Chart appVersion | 1.2.1-beta.11 | 1.2.1-beta.12 |

> **Note:** This is a minor beta version increment, indicating bug fixes or small improvements in the application code.

## Resource Allocation Changes

### PIX Service Memory Increase

The PIX service memory limit has been doubled to accommodate increased workload demands:

| Setting | v2.2.8 | v2.2.9 |
|---------|--------|--------|
| pix.resources.limits.memory | 256Mi | 512Mi |

**Why this matters:** This 100% increase in memory limits suggests that the previous allocation was insufficient for optimal operation. The service will have more headroom to handle transaction processing and prevent OOMKilled events under load.

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

> **Warning:** This memory increase will double the maximum memory consumption for the PIX service. Ensure your cluster nodes have sufficient available memory, especially considering the autoscaling configuration (up to 9 replicas × 512Mi = 4.5Gi maximum).

### Operational Impact

**Before upgrade (v2.2.8):**
- Memory per pod limit: 256Mi
- Maximum memory consumption (9 replicas): 2304Mi (2.25Gi)

**After upgrade (v2.2.9):**
- Memory per pod limit: 512Mi
- Maximum memory consumption (9 replicas): 4608Mi (4.5Gi)

**Resource calculation:**
- Baseline memory requirement (3 pods): increases from 768Mi to 1536Mi
- Maximum memory requirement: increases from 2304Mi to 4608Mi (100% increase)

## Autoscaling Configuration Updates

### CPU Utilization Threshold Adjustment

The CPU autoscaling threshold has been increased to allow pods to run at higher utilization before triggering scale-out:

| Setting | v2.2.8 | v2.2.9 |
|---------|--------|--------|
| pix.autoscaling.targetCPUUtilizationPercentage | 70 | 75 |

**Why this matters:** Increasing the threshold from 70% to 75% means pods will tolerate higher CPU usage before new replicas are created. This reduces scaling churn and takes advantage of the increased memory allocation, allowing pods to handle more work before scaling.

**Complete autoscaling configuration:**

```yaml
pix:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 9
    targetCPUUtilizationPercentage: 75
    targetMemoryUtilizationPercentage: 85
```

> **Note:** The higher CPU threshold (75%) combined with doubled memory (512Mi) suggests the application is being tuned to handle more load per pod before scaling horizontally. Monitor CPU and memory metrics after upgrade to ensure pods are not experiencing resource pressure.

## Configuration Changes

### PIX Service ConfigMap Updates

The PIX service configuration has been modified with changes to default environment values and the addition of a new variable:

**Before (v2.2.8):**

```yaml
data:
  NODE_ENV: "production"
  DEBUG: "true"
  ENVIRONMENT: "production"
  LOG_LEVEL: "debug"
```

**After (v2.2.9):**

```yaml
data:
  NODE_ENV: "development"
  DEBUG: "true"
  LOG_LEVEL: "info"
  NEW_VAR: "default_value"
```

**Changes:**

| Setting | v2.2.8 | v2.2.9 |
|---------|--------|--------|
| pix.configmap.NODE_ENV (default) | production | development |
| pix.configmap.LOG_LEVEL (default) | debug | info |
| pix.configmap.ENVIRONMENT | production | (removed) |
| pix.configmap.NEW_VAR | (not present) | default_value |

**Why this matters:**
- **NODE_ENV change to "development"**: The default environment has been changed from production to development. This is unusual for a production-ready chart and likely indicates this is intended for development/testing deployments by default.
- **LOG_LEVEL change to "info"**: Reduces log verbosity from debug to info, which will decrease log volume and improve performance.
- **ENVIRONMENT removal**: This field was redundant with NODE_ENV and has been eliminated to simplify configuration.
- **NEW_VAR addition**: A new environment variable has been introduced with a placeholder default value.

**New environment variables:**
- **NEW_VAR**: A new configuration variable with default value `default_value`. The purpose is not specified in the template, so consult your application documentation for its intended use.

> **Warning:** The default NODE_ENV of "development" may not be appropriate for production deployments. For production environments, explicitly override this value:

```yaml
pix:
  configmap:
    NODE_ENV: "production"
    LOG_LEVEL: "warn"  # Consider using warn or error in production
    NEW_VAR: "your-actual-value"  # Replace placeholder if needed
```

### Job ConfigMap Updates

The job component's logging configuration has been modified:

**Before (v2.2.8):**

```yaml
data:
  LOG_LEVEL: "info"
```

**After (v2.2.9):**

```yaml
data:
  LOG_LEVEL: "debug"
```

**Changes:**

| Setting | v2.2.8 | v2.2.9 |
|---------|--------|--------|
| job.configmap.LOG_LEVEL (default) | info | debug |

**Why this matters:** The job component now defaults to debug-level logging, which will increase log verbosity for job executions. This is useful for troubleshooting but may generate significant log volume.

> **Note:** For production deployments where job execution is stable, consider overriding this back to info or warn level:

```yaml
job:
  configmap:
    LOG_LEVEL: "info"
```

### Default Value Updates

The MIDAZ ledger ID configuration now has a non-empty default value:

| Setting | v2.2.8 | v2.2.9 |
|---------|--------|--------|
| pix.configmap.MIDAZ_LEDGER_ID (default) | "" | "your_ledger" |

**Why this matters:** Previously, the ledger ID defaulted to an empty string, which would likely cause runtime errors. The new default provides a placeholder value that makes the misconfiguration more obvious.

> **Important:** The default value "your_ledger" is a placeholder and must be replaced with your actual MIDAZ ledger ID:

```yaml
pix:
  configmap:
    MIDAZ_LEDGER_ID: "your-actual-ledger-id"
```

**Migration steps:**

1. **Before upgrading**, ensure you have your MIDAZ ledger ID available.

2. **Add the ledger ID to your values file:**

```yaml
pix:
  configmap:
    MIDAZ_ORGANIZATION_ID: "your-organization"
    MIDAZ_LEDGER_ID: "your-actual-ledger-id"
    MIDAZ_ASSET_ID: "your-asset-id"
```

3. **Verify the configuration** after upgrade by checking the pod environment:

```bash
kubectl get configmap plugin-br-pix-direct-jd-configmap -n plugin-br-pix-direct-jd -o yaml
```

## Health Check Configuration Changes

### Liveness Probe Timing Adjustment

The liveness probe initialization delay has been reduced for faster failure detection:

| Setting | v2.2.8 | v2.2.9 |
|---------|--------|--------|
| pix deployment livenessProbe.initialDelaySeconds | 10 | 5 |

**Why this matters:** Reducing the initial delay from 10 to 5 seconds means Kubernetes will start checking pod health sooner after startup. This enables faster detection of startup failures but requires the application to be ready for health checks within 5 seconds.

**Complete probe configuration:**

```yaml
livenessProbe:
  initialDelaySeconds: 5
  periodSeconds: 5
  httpGet:
    path: /v1/health
    port: http
```

> **Note:** The readiness probe still uses a 10-second initial delay, so pods won't receive traffic until they pass readiness checks. The faster liveness probe only affects failure detection and restart behavior.

> **Warning:** If your PIX service takes longer than 5 seconds to initialize, you may experience unnecessary pod restarts. Monitor pod restart counts after upgrade. If you see CrashLoopBackOff or frequent restarts, override this value:

```yaml
pix:
  # Add custom deployment configuration if needed
  # This would require chart support for overriding probe settings
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.9 -n plugin-br-pix-direct-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.9 -n plugin-br-pix-direct-jd
```
