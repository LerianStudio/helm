# Helm Upgrade from v2.x to v1.x

This guide helps operators upgrade the `plugin-br-pix-direct-jd` Helm chart from version **2.2.11** to **1.2.7**. This is a **major version downgrade** (chart version) but includes an **application version upgrade** from `1.2.1-beta.11` to `1.10.6`.

## Table of Contents

- **[Breaking Changes](#breaking-changes)**
  - [Application Version Upgrade](#application-version-upgrade)
  - [Resource Allocation Changes](#resource-allocation-changes)
  - [Autoscaling Configuration Changes](#autoscaling-configuration-changes)
  - [Health Check Endpoint Change](#health-check-endpoint-change)
  - [Removed Configuration Variables](#removed-configuration-variables)
  - [Removed Secret Fields](#removed-secret-fields)
  - [Default Environment Changes](#default-environment-changes)
  - [Version Configuration Changes](#version-configuration-changes)
  - [Job Image Tag Downgrade](#job-image-tag-downgrade)
  - [QR Code Service Tag Cleared](#qr-code-service-tag-cleared)
  - [Cron Schedule Adjustment](#cron-schedule-adjustment)
- **[Configuration Reference](#configuration-reference)**
  - [Resource Limits and Requests](#resource-limits-and-requests)
  - [Autoscaling Settings](#autoscaling-settings)
  - [Environment Defaults](#environment-defaults)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### Application Version Upgrade

The application version has been upgraded significantly from a beta release to a stable production release.

| Component | v2.2.11 | v1.2.7 |
|-----------|---------|--------|
| Chart appVersion | 1.2.1-beta.11 | 1.10.6 |
| PIX service image tag | 1.2.1-beta.11 | 1.10.6 |
| Job image tag | 1.2.1-beta.12 | 1.2.1-beta.7 |
| QR Code image tag | 1.2.1-beta.11 | "" (empty) |

> **Warning:** The application version jump from `1.2.1-beta.11` to `1.10.6` represents a significant upgrade. Review application-level release notes for any breaking API or behavioral changes before upgrading.

> **Important:** The QR Code service image tag is now empty by default. You **must** explicitly set `qrcode.image.tag` in your values or the deployment will fail.

**Before (v2.2.11):**
```yaml
pix:
  image:
    tag: "1.2.1-beta.11"

qrcode:
  image:
    tag: "1.2.1-beta.11"

job:
  image:
    tag: "1.2.1-beta.12"
```

**After (v1.2.7):**
```yaml
pix:
  image:
    tag: "1.10.6"

qrcode:
  image:
    tag: ""  # Must be set explicitly

job:
  image:
    tag: "1.2.1-beta.7"
```

### Resource Allocation Changes

Memory limits and requests have been reduced by 50% for the PIX service.

| Setting | v2.2.11 | v1.2.7 |
|---------|---------|--------|
| CPU limits | 200m | 200m (unchanged) |
| Memory limits | 512Mi | 256Mi |
| CPU requests | 100m | 100m (unchanged) |
| Memory requests | 256Mi | 128Mi |

**Before (v2.2.11):**
```yaml
pix:
  resources:
    limits:
      cpu: 200m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
```

**After (v1.2.7):**
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

> **Warning:** If your workload currently uses more than 256Mi of memory, pods will be OOMKilled after upgrade. Monitor memory usage before upgrading and override these values if needed.

### Autoscaling Configuration Changes

Horizontal Pod Autoscaler settings have been significantly reduced for both PIX and QR Code services.

#### PIX Service Autoscaling

| Setting | v2.2.11 | v1.2.7 |
|---------|---------|--------|
| minReplicas | 3 | 1 |
| maxReplicas | 12 | 3 |
| targetCPUUtilizationPercentage | 70 | 80 |
| targetMemoryUtilizationPercentage | 85 | 80 |

**Before (v2.2.11):**
```yaml
pix:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 12
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 85
```

**After (v1.2.7):**
```yaml
pix:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilizationPercentage: 80
    targetMemoryUtilizationPercentage: 80
```

#### QR Code Service Autoscaling

| Setting | v2.2.11 | v1.2.7 |
|---------|---------|--------|
| minReplicas | 3 | 1 |
| maxReplicas | 9 | 9 (unchanged) |

**Before (v2.2.11):**
```yaml
qrcode:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 9
```

**After (v1.2.7):**
```yaml
qrcode:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 9
```

> **Warning:** The minimum replica count drops from 3 to 1 for both services. This reduces high availability during normal operation. For production environments, consider overriding `minReplicas` to maintain at least 2-3 replicas.

> **Important:** CPU and memory utilization thresholds have increased to 80%. Pods will scale out later under load, potentially causing temporary performance degradation during traffic spikes.

### Health Check Endpoint Change

The readiness probe endpoint for the PIX service has changed.

| Setting | v2.2.11 | v1.2.7 |
|---------|---------|--------|
| Readiness probe path | /readyz | /v1/health |

**Before (v2.2.11):**
```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: {{ .Values.pix.service.port }}
  initialDelaySeconds: 10
  periodSeconds: 5
```

**After (v1.2.7):**
```yaml
readinessProbe:
  httpGet:
    path: /v1/health
    port: {{ .Values.pix.service.port }}
  initialDelaySeconds: 10
  periodSeconds: 5
```

> **Important:** Ensure your application version `1.10.6` exposes the `/v1/health` endpoint. If the endpoint is not available, pods will fail readiness checks and remain out of service rotation.

### Removed Configuration Variables

Several configuration variables have been removed from the PIX service ConfigMap.

#### Removed from PIX ConfigMap

**Before (v2.2.11):**
```yaml
data:
  LOG_LEVEL: "debug"
  NEW_VAR: "value"
  NEW_TAG: "1.2.1-beta.11"
```

**After (v1.2.7):**
```yaml
data:
  # LOG_LEVEL removed
  # NEW_VAR removed
  # NEW_TAG removed
```

The following environment variables are no longer set:
- `LOG_LEVEL` - Previously defaulted to `"debug"`
- `NEW_VAR` - Previously defaulted to `"value"`
- `NEW_TAG` - Previously set to image tag

> **Note:** If your application relies on `LOG_LEVEL` being set via environment variable, you must add it explicitly to `pix.configmap` in your values override.

#### Removed from Job ConfigMap

**Before (v2.2.11):**
```yaml
data:
  LOG_LEVEL: "debug"
```

**After (v1.2.7):**
```yaml
data:
  # LOG_LEVEL removed
```

#### Removed from QR Code ConfigMap

**Before (v2.2.11):**
```yaml
data:
  LOG_LEVEL: "info"
```

**After (v1.2.7):**
```yaml
data:
  # LOG_LEVEL removed
```

### Removed Secret Fields

The `SECRET_KEY_BASE` secret has been removed from both PIX and Job secrets.

**Before (v2.2.11):**
```yaml
data:
  SENDGRID_API_KEY: {{ .Values.pix.secrets.SENDGRID_API_KEY | default "your-sendgrid-api-key" | b64enc | quote }}
  SECRET_KEY_BASE: {{ .Values.pix.secrets.SECRET_KEY_BASE | default "your-secret-key-base" | b64enc | quote }}
```

**After (v1.2.7):**
```yaml
data:
  SENDGRID_API_KEY: {{ .Values.pix.secrets.SENDGRID_API_KEY | default "your-sendgrid-api-key" | b64enc | quote }}
```

> **Warning:** If your application requires `SECRET_KEY_BASE`, you must provide it through an external secret or alternative mechanism. This field is no longer managed by the Helm chart.

#### Removed from QR Code Secrets

**Before (v2.2.11):**
```yaml
data:
  KEY: {{ .Values.qrcode.secrets.PRIVATE_KEY | default "" | b64enc | quote }}
  CERTIFICATE: {{ .Values.qrcode.secrets.CERTIFICATE | default "lerian" | b64enc | quote }}
  NEW_KEY: {{ .Values.qrcode.secrets.NEW_PRIVATE_KEY | default "" | b64enc | quote }}
```

**After (v1.2.7):**
```yaml
data:
  KEY: {{ .Values.qrcode.secrets.PRIVATE_KEY | default "" | b64enc | quote }}
  CERTIFICATE: {{ .Values.qrcode.secrets.CERTIFICATE | default "lerian" | b64enc | quote }}
```

The `NEW_KEY` (mapped from `NEW_PRIVATE_KEY` value) has been removed from QR Code secrets.

### Default Environment Changes

Default values for `NODE_ENV` and `DEBUG` have changed across all services.

| Service | Variable | v2.2.11 | v1.2.7 |
|---------|----------|---------|--------|
| PIX | NODE_ENV | production | development |
| PIX | DEBUG | true | false |
| Job | NODE_ENV | production | development |
| Job | DEBUG | true | false |

**Before (v2.2.11):**
```yaml
data:
  NODE_ENV: "production"
  DEBUG: "true"
  LOG_LEVEL: "debug"
```

**After (v1.2.7):**
```yaml
data:
  NODE_ENV: "development"
  DEBUG: "false"
```

> **Warning:** The default environment has changed from `production` to `development`. For production deployments, you **must** override these values:

```yaml
pix:
  configmap:
    NODE_ENV: "production"
    DEBUG: "false"

job:
  configmap:
    NODE_ENV: "production"
    DEBUG: "false"
```

### Version Configuration Changes

Version information is no longer derived from image tags but set explicitly via configuration.

#### PIX Service

**Before (v2.2.11):**
```yaml
data:
  API_VERSION: {{ .Values.pix.image.tag | default .Chart.AppVersion | quote }}
  OTEL_RESOURCE_SERVICE_VERSION: {{ .Values.pix.image.tag | default .Chart.AppVersion | quote }}
```

**After (v1.2.7):**
```yaml
data:
  API_VERSION: {{ .Values.pix.configmap.API_VERSION | default "1.0.0" | quote }}
  OTEL_RESOURCE_SERVICE_VERSION: {{ .Values.pix.configmap.OTEL_RESOURCE_SERVICE_VERSION | default "1.0.0" | quote }}
```

#### Job Service

**Before (v2.2.11):**
```yaml
data:
  API_VERSION: {{ .Values.job.image.tag | default .Chart.AppVersion | quote }}
  OTEL_RESOURCE_SERVICE_VERSION: {{ .Values.job.image.tag | default .Chart.AppVersion | quote }}
```

**After (v1.2.7):**
```yaml
data:
  API_VERSION: {{ .Values.job.configmap.API_VERSION | default "1.0.0" | quote }}
  OTEL_RESOURCE_SERVICE_VERSION: {{ .Values.job.configmap.OTEL_RESOURCE_SERVICE_VERSION | default "1.0.0" | quote }}
```

#### QR Code Service

**Before (v2.2.11):**
```yaml
data:
  VERSION: {{ .Values.qrcode.image.tag | default .Chart.AppVersion | quote }}
```

**After (v1.2.7):**
```yaml
data:
  VERSION: "v1.0.0"
```

> **Note:** Version strings are now hardcoded or configurable independently of image tags. If you need to track deployed versions in telemetry or APIs, set these explicitly:

```yaml
pix:
  configmap:
    API_VERSION: "1.10.6"
    OTEL_RESOURCE_SERVICE_VERSION: "1.10.6"

job:
  configmap:
    API_VERSION: "1.2.1-beta.7"
    OTEL_RESOURCE_SERVICE_VERSION: "1.2.1-beta.7"
```

### Job Image Tag Downgrade

The Job component image tag has been downgraded from `1.2.1-beta.12` to `1.2.1-beta.7`.

| Component | v2.2.11 | v1.2.7 |
|-----------|---------|--------|
| Job image tag | 1.2.1-beta.12 | 1.2.1-beta.7 |

> **Warning:** This is a downgrade of the Job component. Ensure that version `1.2.1-beta.7` is compatible with the upgraded PIX service version `1.10.6` and does not reintroduce bugs fixed in beta.12.

### QR Code Service Tag Cleared

The QR Code service image tag default has been removed.

| Component | v2.2.11 | v1.2.7 |
|-----------|---------|--------|
| QR Code image tag | 1.2.1-beta.11 | "" (empty) |

> **Important:** You **must** explicitly set the QR Code image tag in your values override or the deployment will fail:

```yaml
qrcode:
  image:
    tag: "1.10.6"  # or appropriate version
```

### Cron Schedule Adjustment

The transaction processing cron schedule has been adjusted.

| Setting | v2.2.11 | v1.2.7 |
|---------|---------|--------|
| JOBS_CRON_TRANSACTIONS | */11 * * * * | */10 * * * * |

**Before (v2.2.11):**
```yaml
data:
  JOBS_CRON_TRANSACTIONS: "*/11 * * * *"
```

**After (v1.2.7):**
```yaml
data:
  JOBS_CRON_TRANSACTIONS: "*/10 * * * *"
```

> **Note:** Transaction processing jobs will now run every 10 minutes instead of every 11 minutes, resulting in slightly more frequent execution.

### Revision History Limit Change

The default revision history limit has been increased.

| Setting | v2.2.11 | v1.2.7 |
|---------|---------|--------|
| revisionHistoryLimit | 5 | 10 |

**Before (v2.2.11):**
```yaml
pix:
  revisionHistoryLimit: 5
```

**After (v1.2.7):**
```yaml
pix:
  revisionHistoryLimit: 10
```

> **Note:** Kubernetes will now retain 10 old ReplicaSets instead of 5, allowing for more rollback history at the cost of slightly more etcd storage.

### Default Organization ID Cleared

The default value for `MIDAZ_ORGANIZATION_ID` has been cleared.

| Setting | v2.2.11 | v1.2.7 |
|---------|---------|--------|
| MIDAZ_ORGANIZATION_ID | "your-organization" | "" (empty) |

**Before (v2.2.11):**
```yaml
pix:
  configmap:
    MIDAZ_ORGANIZATION_ID: "your-organization"
```

**After (v1.2.7):**
```yaml
pix:
  configmap:
    MIDAZ_ORGANIZATION_ID: ""
```

> **Important:** If your deployment requires `MIDAZ_ORGANIZATION_ID`, you must set it explicitly in your values override:

```yaml
pix:
  configmap:
    MIDAZ_ORGANIZATION_ID: "your-actual-organization-id"
```

## Configuration Reference

### Resource Limits and Requests

| Flag | Default (v1.2.7) | Description |
|------|------------------|-------------|
| `pix.resources.limits.cpu` | 200m | Maximum CPU allocation for PIX pods |
| `pix.resources.limits.memory` | 256Mi | Maximum memory allocation for PIX pods (reduced from 512Mi) |
| `pix.resources.requests.cpu` | 100m | Guaranteed CPU allocation for PIX pods |
| `pix.resources.requests.memory` | 128Mi | Guaranteed memory allocation for PIX pods (reduced from 256Mi) |

**Example override for production:**
```yaml
pix:
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
```

### Autoscaling Settings

| Flag | Default (v1.2.7) | Description |
|------|------------------|-------------|
| `pix.autoscaling.enabled` | true | Enable horizontal pod autoscaling |
| `pix.autoscaling.minReplicas` | 1 | Minimum number of PIX replicas (reduced from 3) |
| `pix.autoscaling.maxReplicas` | 3 | Maximum number of PIX replicas (reduced from 12) |
| `pix.autoscaling.targetCPUUtilizationPercentage` | 80 | CPU threshold for scaling (increased from 70) |
| `pix.autoscaling.targetMemoryUtilizationPercentage` | 80 | Memory threshold for scaling (reduced from 85) |
| `qrcode.autoscaling.minReplicas` | 1 | Minimum number of QR Code replicas (reduced from 3) |

**Example override for high availability:**
```yaml
pix:
  autoscaling:
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 75

qrcode:
  autoscaling:
    minReplicas: 2
    maxReplicas: 9
```

### Environment Defaults

| Flag | Default (v1.2.7) | Description |
|------|------------------|-------------|
| `pix.configmap.NODE_ENV` | development | Node.js environment mode (changed from production) |
| `pix.configmap.DEBUG` | false | Enable debug logging (changed from true) |
| `pix.configmap.API_VERSION` | 1.0.0 | API version reported by service |
| `pix.configmap.OTEL_RESOURCE_SERVICE_VERSION` | 1.0.0 | Service version reported to OpenTelemetry |
| `pix.configmap.MIDAZ_ORGANIZATION_ID` | "" | Midaz organization identifier (cleared from "your-organization") |
| `pix.configmap.JOBS_CRON_TRANSACTIONS` | */10 * * * * | Cron schedule for transaction processing (changed from */11) |

**Example override for production:**
```yaml
pix:
  configmap:
    NODE_ENV: "production"
    DEBUG: "false"
    API_VERSION: "1.10.6"
    OTEL_RESOURCE_SERVICE_VERSION: "1.10.6"
    MIDAZ_ORGANIZATION_ID: "prod-org-12345"

job:
  configmap:
    NODE_ENV: "production"
    DEBUG: "false"
    API_VERSION: "1.2.1-beta.7"
    OTEL_RESOURCE_SERVICE_VERSION: "1.2.1-beta.7"
```

## Migration Steps

Follow these steps to safely migrate from v2.2.11 to v1.2.7:

### 1. Review Application Compatibility

Verify that application version `1.10.6` is compatible with your infrastructure and dependencies.

```bash
# Check current running version
kubectl get deployment plugin-br-pix-direct-jd -n plugin-br-pix-direct-jd -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### 2. Prepare Values Override File

Create a values override file to maintain production-appropriate settings:

```yaml
# values-override.yaml
pix:
  image:
    tag: "1.10.6"
  
  configmap:
    NODE_ENV: "production"
    DEBUG: "false"
    API_VERSION: "1.10.6"
    OTEL_RESOURCE_SERVICE_VERSION: "1.10.6"
    MIDAZ_ORGANIZATION_ID: "your-actual-org-id"
  
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  
  autoscaling:
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 75

qrcode:
  image:
    tag: "1.10.6"  # Must be set explicitly
  
  autoscaling:
    minReplicas: 2

job:
  image:
    tag: "1.2.1-beta.7"
  
  configmap:
    NODE_ENV: "production"
    DEBUG: "false"
    API_VERSION: "1.2.1-beta.7"
    OTEL_RESOURCE_SERVICE_VERSION: "1.2.1-beta.7"
```

### 3. Verify Health Check Endpoint

Ensure the new application version exposes `/v1/health`:

```bash
# If you have a test environment, verify the endpoint first
kubectl port-forward -n plugin-br-pix-direct-jd deployment/plugin-br-pix-direct-jd 4011:4011
curl http://localhost:4011/v1/health
```

### 4. Handle Removed Secrets

If your application uses `SECRET_KEY_BASE`, create an external secret or add it to your values:

```yaml
# If using external secrets, create before upgrade
# If adding to values (not recommended for production):
pix:
  env:
    - name: SECRET_KEY_BASE
      valueFrom:
        secretKeyRef:
          name: your-external-secret
          key: secret-key-base
```

> **Note:** The chart no longer manages `SECRET_KEY_BASE`. Use an external secret management solution like Sealed Secrets, External Secrets Operator, or Vault.

### 5. Review and Adjust Autoscaling

If your current workload requires the previous autoscaling settings, ensure they are in your override file:

```yaml
pix:
  autoscaling:
    minReplicas: 3  # Maintain high availability
    maxReplicas: 12  # Maintain previous scale capacity
```

### 6. Test in Non-Production Environment

Apply the upgrade to a staging or development environment first:

```bash
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm \
  --version 1.2.7 \
  -n plugin-br-pix-direct-jd-staging \
  -f values-override.yaml
```

### 7. Monitor Resource Usage

After upgrade, monitor memory usage closely due to reduced limits:

```bash
# Watch pod memory usage
kubectl top pods -n plugin-br-pix-direct-jd -l app.kubernetes.io/name=plugin-br-pix-direct-jd

# Check for OOMKilled events
kubectl get events -n plugin-br-pix-direct-jd --field-selector reason=OOMKilled
```

### 8. Verify All Services Are Healthy

After upgrade, confirm all components are running:

```bash
# Check PIX service
kubectl get deployment plugin-br-pix-direct-jd -n plugin-br-pix-direct-jd

# Check QR Code service
kubectl get deployment plugin-br-pix-direct-jd-qr-code -n plugin-br-pix-direct-jd

# Check Job
kubectl get job -n plugin-br-pix-direct-jd

# Verify readiness
kubectl get pods -n plugin-br-pix-direct-jd -l app.kubernetes.io/name=plugin-br-pix-direct-jd
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 1.2.7 -n plugin-br-pix-direct-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 1.2.7 -n plugin-br-pix-direct-jd
```
