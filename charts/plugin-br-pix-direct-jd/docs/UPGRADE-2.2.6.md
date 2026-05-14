# Helm Upgrade from v2.2.5 to v2.2.6

## Table of Contents
- [Overview](#overview)
- [Application Version Updates](#application-version-updates)
- [Resource Allocation Changes](#resource-allocation-changes)
- [Autoscaling Configuration Updates](#autoscaling-configuration-updates)
- [Configuration Changes](#configuration-changes)
- [Secret Management Updates](#secret-management-updates)
- [Deployment History Changes](#deployment-history-changes)
- [Preview changes before upgrading](#preview-changes-before-upgrading)
- [Command to upgrade](#command-to-upgrade)

## Overview

This patch release updates the plugin-br-pix-direct-jd chart from v2.2.5 to v2.2.6, introducing resource optimization changes and configuration refinements. The primary focus is on reducing memory consumption while increasing autoscaling capacity, along with improved logging configuration and secret management.

**Key changes:**
- Application image rollback for the pix component
- Reduced memory limits for pix and qrcode services
- Increased maximum autoscaling replicas
- Enhanced logging configuration with new environment variables
- New secret key for application security
- Reduced revision history retention

## Application Version Updates

This release rolls back the pix component image to an earlier stable version:

| Component | v2.2.5 | v2.2.6 |
|-----------|--------|--------|
| pix.image.tag | 1.2.1-beta.18 | 1.2.1-beta.11 |

> **Warning:** This is a rollback to an earlier beta version (beta.11 from beta.18). This typically indicates issues discovered in beta.18 that require reverting to a known stable build. Review your application logs after upgrade to ensure expected behavior.

## Resource Allocation Changes

### PIX Service Memory Reduction

The PIX service memory limit has been reduced to optimize resource utilization:

| Setting | v2.2.5 | v2.2.6 |
|---------|--------|--------|
| pix.resources.limits.memory | 512Mi | 256Mi |

**Why this matters:** This 50% reduction in memory limits suggests that the previous allocation was over-provisioned. The service should operate efficiently within the new limit based on observed usage patterns.

**Example configuration:**
pix:
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

> **Note:** Monitor memory usage closely after upgrade. If you see OOMKilled events or memory pressure, you may need to override this value back to 512Mi in your values file.

### QR Code Service Memory Reduction

The QR code generation service memory limit has been halved:

| Setting | v2.2.5 | v2.2.6 |
|---------|--------|--------|
| qrcode.resources.limits.memory | 512Mi | 256Mi |

**Why this matters:** Similar to the PIX service, this optimization reduces the memory footprint while maintaining service functionality based on actual usage patterns.

**Example configuration:**
qrcode:
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

## Autoscaling Configuration Updates

### Increased Maximum Replicas

The maximum autoscaling replica count has been increased to handle higher peak loads:

| Setting | v2.2.5 | v2.2.6 |
|---------|--------|--------|
| pix.autoscaling.maxReplicas | 6 | 9 |

**Why this matters:** While reducing per-pod memory limits, the system can now scale to 50% more replicas (9 vs 6), providing better horizontal scaling capability for traffic spikes.

**Complete autoscaling configuration:**
pix:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 9
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 85

### Operational Impact

**Before upgrade (v2.2.5):**
- Minimum pods: 3
- Maximum pods: 6
- Memory per pod limit: 512Mi
- Maximum memory consumption: 3072Mi (3Gi)

**After upgrade (v2.2.6):**
- Minimum pods: 3
- Maximum pods: 9
- Memory per pod limit: 256Mi
- Maximum memory consumption: 2304Mi (2.25Gi)

**Resource calculation:**
- Baseline memory requirement remains: 768Mi (3 pods × 256Mi)
- Maximum memory requirement decreases from 3072Mi to 2304Mi (25% reduction)
- Maximum pod count increases by 50% (6 to 9 pods)

> **Note:** This change trades individual pod capacity for greater horizontal scaling. Your cluster will need fewer total resources at peak load, but will run more pods to handle the same traffic volume.

## Configuration Changes

### Job ConfigMap Updates

The job component's logging configuration has been modified:

**Before (v2.2.5):**
data:
  NODE_ENV: "development"
  DEBUG: "false"
  LOG_LEVEL: "info"
  ENVIRONMENT: "development"

**After (v2.2.6):**
data:
  NODE_ENV: "development"
  DEBUG: "false"
  LOG_LEVEL: "debug"
  # ENVIRONMENT field removed

**Changes:**

| Setting | v2.2.5 | v2.2.6 |
|---------|--------|--------|
| job.configmap.LOG_LEVEL (default) | info | debug |
| job.configmap.ENVIRONMENT | development | (removed) |

**Why this matters:**
- **LOG_LEVEL change to "debug"**: Provides more verbose logging by default, which is useful for troubleshooting but may increase log volume. Consider overriding this to "info" or "warn" in production environments.
- **ENVIRONMENT removal**: This field was redundant with NODE_ENV and has been eliminated to simplify configuration.

**New environment variables:**
- **LOG_LEVEL**: Controls the verbosity of application logs. Default changed from `info` to `debug`. Valid values typically include: `debug`, `info`, `warn`, `error`.

> **Warning:** The default LOG_LEVEL of "debug" will significantly increase log output. For production deployments, consider overriding this value:

job:
  configmap:
    LOG_LEVEL: "info"

### QR Code ConfigMap Updates

A new logging configuration has been added to the QR code service:

**Before (v2.2.5):**
data:
  VERSION: "1.2.1-beta.17"
  SERVER_PORT: "4009"
  SERVER_ADDRESS: ":4009"

**After (v2.2.6):**
data:
  VERSION: "1.2.1-beta.17"
  SERVER_PORT: "4009"
  SERVER_ADDRESS: ":4009"
  LOG_LEVEL: "info"

**New environment variables:**
- **LOG_LEVEL**: Controls the verbosity of QR code service logs. Default: `info`. This provides consistent logging configuration across all components.

**Example configuration:**
qrcode:
  configmap:
    LOG_LEVEL: "info"

## Secret Management Updates

### New Secret Key Added

A new secret has been added to the job secrets configuration:

**Before (v2.2.5):**
data:
  # ... existing secrets ...
  SENDGRID_API_KEY: {{ .Values.pix.secrets.SENDGRID_API_KEY | default "your-sendgrid-api-key" | b64enc | quote }}

**After (v2.2.6):**
data:
  # ... existing secrets ...
  SENDGRID_API_KEY: {{ .Values.pix.secrets.SENDGRID_API_KEY | default "your-sendgrid-api-key" | b64enc | quote }}

  SeCRET_KEY_BASE: {{ .Values.pix.secrets.SECRET_KEY_BASE | default "your-secret-key-base" | b64enc | quote }}

> **Note:** There is a typo in the secret key name: `SeCRET_KEY_BASE` (mixed case). This appears to be intentional based on the template, but verify this matches your application's expected environment variable name.

**New secret:**
- **SeCRET_KEY_BASE**: Base secret key for application cryptographic operations. Default: `your-secret-key-base` (placeholder value).

**Migration steps:**

1. **Before upgrading**, add the new secret to your values file or secret management system:

pix:
  secrets:
    SECRET_KEY_BASE: "your-actual-secret-key-base-value"

2. **Generate a secure secret key** if you don't have one:

openssl rand -base64 32

3. **For production environments**, use external secret management:

# Example using kubectl to create/update the secret directly
kubectl create secret generic plugin-br-pix-direct-jd-job-secrets \
  --from-literal=SeCRET_KEY_BASE="your-generated-secret-key" \
  --dry-run=client -o yaml | kubectl apply -f -

> **Warning:** The default value "your-secret-key-base" is a placeholder and should never be used in production. Ensure you set a strong, randomly generated value before deploying to production environments.

## Deployment History Changes

The revision history limit has been reduced to conserve cluster resources:

| Setting | v2.2.5 | v2.2.6 |
|---------|--------|--------|
| pix.revisionHistoryLimit | 10 | 5 |

**Why this matters:** This reduces the number of old ReplicaSets retained for rollback purposes from 10 to 5. This saves cluster resources (etcd storage and API server memory) while still maintaining reasonable rollback capability.

**Example configuration:**
pix:
  revisionHistoryLimit: 5

> **Note:** You can still roll back up to 5 previous revisions. If you require longer rollback history, override this value in your values file.

## Preview changes before upgrading
helm diff upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.6 -n plugin-br-pix-direct-jd
> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.2.6 -n plugin-br-pix-direct-jd
