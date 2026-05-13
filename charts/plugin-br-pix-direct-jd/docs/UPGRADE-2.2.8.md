# Helm Upgrade from v2.2.7 to v2.2.8

## Table of Contents
- [Overview](#overview)
- [Application Version Updates](#application-version-updates)
- [Resource Allocation Changes](#resource-allocation-changes)
- [Autoscaling Configuration Updates](#autoscaling-configuration-updates)
- [Configuration Changes](#configuration-changes)
  - [PIX Service ConfigMap Updates](#pix-service-configmap-updates)
  - [Job ConfigMap Updates](#job-configmap-updates)
  - [Default Organization ID](#default-organization-id)
- [Health Check Configuration Changes](#health-check-configuration-changes)
- [Preview changes before upgrading](#preview-changes-before-upgrading)
- [Command to upgrade](#command-to-upgrade)

## Overview

This patch release updates the plugin-br-pix-direct-jd chart from v2.2.7 to v2.2.8, introducing a rollback to an earlier application version along with resource optimization and configuration refinements. The primary focus is on reducing memory consumption, adjusting autoscaling thresholds, and modifying logging defaults for better operational visibility.

**Key changes:**
- Application image rollback to earlier beta version
- Reduced memory limits for the pix service
- Adjusted autoscaling CPU threshold
- Modified logging defaults for enhanced debugging
- Updated health check timing
- New default organization ID placeholder

## Application Version Updates

This release rolls back the application to an earlier beta version:

| Component | v2.2.7 | v2.2.8 |
|-----------|--------|--------|
| Chart appVersion | 1.2.1-beta.17 | 1.2.1-beta.11 |
| pix.image.tag | 1.2.1-beta.12 | 1.2.1-beta.11 |

> **Warning:** This is a rollback from beta.17 (Chart appVersion) and beta.12 (pix image) to beta.11. This typically indicates issues discovered in later beta versions that require reverting to a known stable build. Monitor your application logs and metrics closely after upgrade to ensure expected behavior.

## Resource Allocation Changes

### PIX Service Memory Reduction

The PIX service memory limit has been reduced to optimize resource utilization:

| Setting | v2.2.7 | v2.2.8 |
|---------|--------|--------|
| pix.resources.limits.memory | 512Mi | 256Mi |

**Why this matters:** This 50% reduction in memory limits suggests that the previous allocation was over-provisioned. The service should operate efficiently within the new limit based on observed usage patterns from the beta.11 version.

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

> **Note:** Monitor memory usage closely after upgrade. If you see OOMKilled events or memory pressure, you may need to override this value back to 512Mi in your values file.

### Operational Impact

**Before upgrade (v2.2.7):**
- Memory per pod limit: 512Mi
- Minimum memory consumption: 1536Mi (3 pods × 512Mi)
- Maximum memory consumption: 4608Mi (9 pods × 512Mi)

**After upgrade (v2.2.8):**
- Memory per pod limit: 256Mi
- Minimum memory consumption: 768Mi (3 pods × 256Mi)
- Maximum memory consumption: 2304Mi (9 pods × 256Mi)

**Resource calculation:**
- Baseline memory requirement decreases from 1536Mi to 768Mi (50% reduction)
- Maximum memory requirement decreases from 4608Mi to 2304Mi (50% reduction)

## Autoscaling Configuration Updates

### Adjusted CPU Utilization Threshold

The CPU autoscaling threshold has been lowered for more responsive scaling:

| Setting | v2.2.7 | v2.2.8 |
|---------|--------|--------|
| pix.autoscaling.targetCPUUtilizationPercentage | 75 | 70 |

**Why this matters:** The lower CPU threshold (70% vs 75%) triggers scaling earlier, preventing CPU saturation and maintaining better response times under increasing load.

**Complete autoscaling configuration:**

```yaml
pix:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 9
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 85

> **Note:** This change means pods will scale out when CPU reaches 70% instead of 75%, providing a larger buffer before resource exhaustion. Combined with the reduced memory limits, this ensures the service scales horizontally before hitting resource constraints.

## Configuration Changes

### PIX Service ConfigMap Updates

The PIX service logging and environment configuration has been modified for enhanced debugging:

**Before (v2.2.7):**

```yaml
data:
  NODE_ENV: "production"
  DEBUG: "false"
  ENVIRONMENT: "development"
  LOG_LEVEL: "info"

**After (v2.2.8):**

```yaml
data:
  NODE_ENV: "production"
  DEBUG: "true"
  ENVIRONMENT: "production"
  LOG_LEVEL: "debug"

**Changes:**

| Setting | v2.2.7 | v2.2.8 |
|---------|--------|--------|
| pix.configmap.DEBUG (default) | false | true |
| pix.configmap.ENVIRONMENT (default) | development | production |
| pix.configmap.LOG_LEVEL (default) | info | debug |

**Why this matters:**
- **DEBUG enabled**: Activates debug mode by default, providing more detailed application diagnostics
- **ENVIRONMENT changed to "production"**: Aligns the environment setting with NODE_ENV for consistency
- **LOG_LEVEL changed to "debug"**: Provides verbose logging by default, useful for troubleshooting but will increase log volume

> **Warning:** The default LOG_LEVEL of "debug" and DEBUG enabled will significantly increase log output. For production deployments where you don't need verbose logging, consider overriding these values:

```yaml
pix:
  configmap:
    DEBUG: "false"
    LOG_LEVEL: "info"

### Job ConfigMap Updates

The job component's logging configuration has been adjusted:

**Before (v2.2.7):**

```yaml
data:
  LOG_LEVEL: "debug"

**After (v2.2.8):**

```yaml
data:
  LOG_LEVEL: "info"

**Changes:**

| Setting | v2.2.7 | v2.2.8 |
|---------|--------|--------|
| job.configmap.LOG_LEVEL (default) | debug | info |

**Why this matters:** The job component now defaults to "info" level logging instead of "debug", reducing log volume for background job processing while the main PIX service has increased verbosity.

**Example configuration:**

```yaml
job:
  configmap:
    LOG_LEVEL: "info"

> **Note:** This creates a balanced logging approach: the PIX service (which handles real-time requests) has debug logging enabled, while the job component (which handles background tasks) uses info-level logging to reduce noise.

### Default Organization ID

A new default placeholder value has been added for the organization ID:

**Before (v2.2.7):**

```yaml
pix:
  configmap:
    MIDAZ_ORGANIZATION_ID: ""

**After (v2.2.8):**

```yaml
pix:
  configmap:
    MIDAZ_ORGANIZATION_ID: "your-organization"

**Changes:**

| Setting | v2.2.7 | v2.2.8 |
|---------|--------|--------|
| pix.configmap.MIDAZ_ORGANIZATION_ID (default) | "" | "your-organization" |

**Why this matters:** The new default provides a clearer placeholder indicating that this value must be configured. An empty string could be mistaken for a valid configuration.

> **Important:** The value "your-organization" is a placeholder and must be replaced with your actual organization ID before deployment:

```yaml
pix:
  configmap:
    MIDAZ_ORGANIZATION_ID: "your-actual-organization-id"

## Health Check Configuration Changes

### Liveness Probe Timing Adjustment

The liveness probe initial delay has been increased to allow more startup time:

**Before (v2.2.7):**

```yaml
livenessProbe:
  initialDelaySeconds: 5
  periodSeconds: 5
  httpGet:
    path: /v1/health
    port: http

**After (v2.2.8):**

```yaml
livenessProbe:
  initialDelaySeconds: 10
  periodSeconds: 5
  httpGet:
    path: /v1/health
    port: http

**Changes:**

| Setting | v2.2.7 | v2.2.8 |
|---------|--------|--------|
| pix.deployment.livenessProbe.initialDelaySeconds | 5 | 10 |

**Why this matters:** Doubling the initial delay from 5 to 10 seconds gives the application more time to complete initialization before Kubernetes begins liveness checks. This reduces the risk of premature pod restarts during startup, especially important given the version rollback which may have different startup characteristics.

> **Note:** The readiness probe already had a 10-second initial delay in v2.2.7. This change brings the liveness probe timing in line with the readiness probe, creating a more consistent health check configuration.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.8 -n plugin-br-pix-direct-jd

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.8 -n plugin-br-pix-direct-jd
