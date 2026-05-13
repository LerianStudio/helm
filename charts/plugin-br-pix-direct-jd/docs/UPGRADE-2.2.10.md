# Helm Upgrade from v2.2.9 to v2.2.10

## Table of Contents
- [Overview](#overview)
- [Application Version Updates](#application-version-updates)
- [Resource Allocation Changes](#resource-allocation-changes)
- [Autoscaling Configuration Updates](#autoscaling-configuration-updates)
- [Configuration Changes](#configuration-changes)
- [Health Check Configuration Updates](#health-check-configuration-updates)
- [Preview changes before upgrading](#preview-changes-before-upgrading)
- [Command to upgrade](#command-to-upgrade)

## Overview

This patch release updates the plugin-br-pix-direct-jd chart from v2.2.9 to v2.2.10, introducing resource optimization and configuration refinements. The primary focus is on rolling back to a more stable application version, reducing memory consumption, and adjusting autoscaling and health check parameters for improved reliability.

**Key changes:**
- Application image rollback to an earlier beta version
- Reduced memory limits for the pix service
- Adjusted autoscaling CPU threshold
- Modified default environment configuration
- Updated health check timing

## Application Version Updates

This release rolls back the pix component image to an earlier stable version:

| Component | v2.2.9 | v2.2.10 |
|-----------|--------|--------|
| pix.image.tag | 1.2.1-beta.12 | 1.2.1-beta.11 |

> **Warning:** This is a rollback to an earlier beta version (beta.11 from beta.12). This typically indicates issues discovered in beta.12 that require reverting to a known stable build. Review your application logs after upgrade to ensure expected behavior.

## Resource Allocation Changes

### PIX Service Memory Reduction

The PIX service memory limit has been reduced to optimize resource utilization:

| Setting | v2.2.9 | v2.2.10 |
|---------|--------|--------|
| pix.resources.limits.memory | 512Mi | 256Mi |

**Why this matters:** This 50% reduction in memory limits suggests that the previous allocation was over-provisioned. The service should operate efficiently within the new limit based on observed usage patterns.

**Example configuration:**

```yaml
pix:
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
```

> **Note:** Monitor memory usage closely after upgrade. If you see OOMKilled events or memory pressure, you may need to override this value back to 512Mi in your values file.

### Operational Impact

**Before upgrade (v2.2.9):**
- Memory per pod limit: 512Mi
- Minimum memory consumption: 1536Mi (3 pods × 512Mi)
- Maximum memory consumption: 4608Mi (9 pods × 512Mi)

**After upgrade (v2.2.10):**
- Memory per pod limit: 256Mi
- Minimum memory consumption: 768Mi (3 pods × 256Mi)
- Maximum memory consumption: 2304Mi (9 pods × 256Mi)

**Resource calculation:**
- Baseline memory requirement decreases from 1536Mi to 768Mi (50% reduction)
- Maximum memory requirement decreases from 4608Mi to 2304Mi (50% reduction)

> **Important:** This change significantly reduces cluster resource requirements. Ensure you monitor pod memory usage after upgrade to confirm the service operates within the new limits.

## Autoscaling Configuration Updates

### Adjusted CPU Utilization Threshold

The CPU autoscaling threshold has been lowered for more responsive scaling:

| Setting | v2.2.9 | v2.2.10 |
|---------|--------|--------|
| pix.autoscaling.targetCPUUtilizationPercentage | 75 | 70 |

**Why this matters:** The lower CPU threshold (70% vs 75%) triggers scaling earlier, preventing CPU saturation and improving response times during traffic increases.

**Complete autoscaling configuration:**

```yaml
pix:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 9
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 85
```

> **Note:** This change makes autoscaling more aggressive. Pods will scale out when CPU reaches 70% instead of 75%, providing better headroom during traffic spikes.

## Configuration Changes

### PIX ConfigMap Updates

The default environment configuration has been modified:

**Before (v2.2.9):**

```yaml
data:
  NODE_ENV: "development"
  DEBUG: "true"
  LOG_LEVEL: "info"
  NEW_VAR: "default_value"
```

**After (v2.2.10):**

```yaml
data:
  NODE_ENV: "production"
  DEBUG: "true"
  LOG_LEVEL: "info"
  NEW_VAR: "value"
```

**Changes:**

| Setting | v2.2.9 | v2.2.10 |
|---------|--------|--------|
| pix.configmap.NODE_ENV (default) | development | production |
| pix.configmap.NEW_VAR (default) | default_value | value |

**Why this matters:**
- **NODE_ENV change to "production"**: The default environment is now production instead of development. This affects application behavior, logging verbosity, and error handling. Development environments should explicitly override this value.
- **NEW_VAR default change**: The default value has been simplified from "default_value" to "value". If you rely on the previous default, you must override it in your values file.

**Migration steps:**

1. **For development environments**, override the NODE_ENV value:

```yaml
pix:
  configmap:
    NODE_ENV: "development"
```

2. **If you depend on the previous NEW_VAR default**, override it explicitly:

```yaml
pix:
  configmap:
    NEW_VAR: "default_value"
```

> **Warning:** The NODE_ENV default change from "development" to "production" may affect application behavior. Ensure your environment-specific configurations are properly set before upgrading.

## Health Check Configuration Updates

### Liveness Probe Timing Adjustment

The liveness probe initial delay has been increased to allow more startup time:

**Before (v2.2.9):**

```yaml
livenessProbe:
  initialDelaySeconds: 5
  periodSeconds: 5
  httpGet:
    path: /v1/health
```

**After (v2.2.10):**

```yaml
livenessProbe:
  initialDelaySeconds: 10
  periodSeconds: 5
  httpGet:
    path: /v1/health
```

**Changes:**

| Setting | v2.2.9 | v2.2.10 |
|---------|--------|--------|
| livenessProbe.initialDelaySeconds | 5 | 10 |

**Why this matters:** Doubling the initial delay from 5 to 10 seconds gives the application more time to complete startup before the first liveness check. This reduces the risk of premature pod restarts during initialization, especially with the reduced memory limits.

> **Note:** The readiness probe already uses initialDelaySeconds: 10, so this change aligns the liveness probe timing with the readiness probe for consistency.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.10 -n plugin-br-pix-direct-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.10 -n plugin-br-pix-direct-jd
```
