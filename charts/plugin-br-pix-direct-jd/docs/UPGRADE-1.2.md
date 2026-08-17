# Helm Upgrade from v2.x to v1.x

This guide helps operators upgrade the `plugin-br-pix-direct-jd` Helm chart from version **2.2.11** to **1.2.10**. Despite the version number appearing to decrease, this is a **major version bump** with breaking changes, new configuration requirements, and significant operational improvements.

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Required Secrets](#required-secrets)
  - [Database Password Handling](#database-password-handling)
  - [Removed Configuration Fields](#removed-configuration-fields)
  - [Health Check Endpoint Change](#health-check-endpoint-change)
  - [Template File Rename](#template-file-rename)
- **[Features](#features)**
  - [1. Chart Type Annotation](#1-chart-type-annotation)
  - [2. Application Version Update](#2-application-version-update)
  - [3. Resource Optimization](#3-resource-optimization)
  - [4. Autoscaling Configuration Changes](#4-autoscaling-configuration-changes)
  - [5. Configuration Defaults Update](#5-configuration-defaults-update)
  - [6. API Version Decoupling](#6-api-version-decoupling)
  - [7. Environment Variable Changes](#7-environment-variable-changes)
  - [8. Job Image Tag Update](#8-job-image-tag-update)
  - [9. QR Code Service Configuration](#9-qr-code-service-configuration)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### Required Secrets

Two secrets that previously had default values are now **required** and will cause the Helm installation to fail if not provided.

**Before (v2.2.11):**

```yaml
pix:
  secrets:
    JD_SECRET: ""
    JD_PIX_CLIENT_SECRET: "jd_mock_secret"
```

**After (v1.2.10):**

```yaml
pix:
  secrets:
    JD_SECRET: ""  # Now required - installation fails if empty
    JD_PIX_CLIENT_SECRET: ""  # Now required - installation fails if empty
```

> **Warning:** The chart will fail to install if `pix.secrets.JD_SECRET` or `pix.secrets.JD_PIX_CLIENT_SECRET` are not set. The templates now use `required` function to enforce this.

**Migration Steps:**

1. Obtain the actual JD PIX credentials from your JD account or secrets management system
2. Create a `values-override.yaml` file with the required secrets:

```yaml
pix:
  secrets:
    JD_SECRET: "your-actual-jd-secret"
    JD_PIX_CLIENT_SECRET: "your-actual-jd-pix-client-secret"
```

3. Use this file during upgrade:

```bash
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm \
  --version 1.2.10 \
  -n plugin-br-pix-direct-jd \
  -f values-override.yaml
```

### Database Password Handling

The database password behavior has changed significantly. Previously, an empty password would be base64-encoded and added to the Secret, causing runtime authentication failures. Now, the Secret key is **conditionally emitted**.

**Before (v2.2.11):**

```yaml
# templates/plugin-br-pix-direct-jd/secrets.yaml
data:
  DATABASE_PASSWORD: {{ .Values.pix.secrets.DATABASE_PASSWORD | default "lerian" | b64enc | quote }}
  POSTGRES_PASSWORD: {{ .Values.pix.secrets.POSTGRES_PASSWORD | default "lerian" | b64enc | quote }}
```

**After (v1.2.10):**

```yaml
# templates/plugin-br-pix-direct-jd/secrets.yaml
data:
  {{- if .Values.pix.secrets.DATABASE_PASSWORD }}
  DATABASE_PASSWORD: {{ .Values.pix.secrets.DATABASE_PASSWORD | b64enc | quote }}
  {{- end }}
  {{- if .Values.pix.secrets.POSTGRES_PASSWORD }}
  POSTGRES_PASSWORD: {{ .Values.pix.secrets.POSTGRES_PASSWORD | b64enc | quote }}
  {{- end }}
```

**Default Value Changes:**

| Setting | v2.2.11 | v1.2.10 |
|---------|---------|---------|
| `pix.secrets.DATABASE_PASSWORD` | `"lerian"` | `""` (empty) |
| `postgresql.auth.password` | `"lerian"` | `""` (empty) |

> **Important:** If you are using the embedded PostgreSQL subchart (`postgresql.enabled: true`), you **must** set `postgresql.auth.password` explicitly. An empty password will cause the PostgreSQL pod to fail to start.

**Migration Steps:**

#### Option 1: Using Embedded PostgreSQL

Set the password explicitly in your values override:

```yaml
postgresql:
  auth:
    password: "your-secure-password"

pix:
  secrets:
    DATABASE_PASSWORD: "your-secure-password"
```

#### Option 2: Using External PostgreSQL

If you are using an external PostgreSQL instance, ensure the connection string or password is set:

```yaml
pix:
  secrets:
    DATABASE_PASSWORD: "your-external-db-password"
  configmap:
    DATABASE_HOST: "external-postgres.example.com"
    DATABASE_PORT: "5432"
    DATABASE_NAME: "pix"
    DATABASE_USER: "pix"
```

### Removed Configuration Fields

Several configuration fields have been removed from ConfigMaps and Secrets.

**Removed from `pix` ConfigMap:**

- `NEW_VAR`
- `NEW_TAG`
- `LOG_LEVEL`

**Removed from `job` ConfigMap:**

- `LOG_LEVEL`

**Removed from `qrcode` ConfigMap:**

- `LOG_LEVEL`

**Removed from Secrets:**

- `SECRET_KEY_BASE` (both `pix` and `job` secrets)
- `NEW_KEY` (from `qrcode` secrets)
- `JD_CLIENT_SECRET` (from `pix` secrets, but retained in `job` secrets)

> **Note:** If your application code or external monitoring relied on these environment variables, you will need to adjust accordingly. The `LOG_LEVEL` variable has been removed in favor of the `DEBUG` flag.

### Health Check Endpoint Change

The readiness probe endpoint for the main `pix` deployment has changed.

**Before (v2.2.11):**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: {{ .Values.pix.service.port }}
```

**After (v1.2.10):**

```yaml
readinessProbe:
  httpGet:
    path: /v1/health
    port: {{ .Values.pix.service.port }}
```

> **Warning:** Ensure your application version `1.10.7` (or the tag you deploy) exposes the `/v1/health` endpoint. If the endpoint does not exist, pods will fail readiness checks and will not receive traffic.

**Operational Impact:**

- During the upgrade, new pods will not become ready until they pass the `/v1/health` check
- If the new image does not expose this endpoint, the deployment will hang with pods in a non-ready state
- Verify the endpoint is available before upgrading:

```bash
kubectl port-forward -n plugin-br-pix-direct-jd deployment/plugin-br-pix-direct-jd 4011:4011
curl http://localhost:4011/v1/health
```

### Template File Rename

The helpers template file has been renamed to follow Helm best practices.

**Before (v2.2.11):**

```
templates/helpers.tpl
```

**After (v1.2.10):**

```
templates/_helpers.tpl
```

> **Note:** This is a cosmetic change and does not affect functionality. The underscore prefix is a Helm convention to indicate partial templates that are not rendered directly.

## Features

### 1. Chart Type Annotation

The chart now includes a `lerian.studio/chart-type` annotation to indicate it is a multi-component chart.

**Added to `Chart.yaml`:**

```yaml
annotations:
  lerian.studio/chart-type: multi-component
```

This annotation helps with chart discovery and categorization in Helm repositories and internal tooling.

### 2. Application Version Update

The application version has been updated from `1.2.1-beta.11` to `1.10.0`, and the default image tags have changed accordingly.

| Component | v2.2.11 Tag | v1.2.10 Tag |
|-----------|-------------|-------------|
| `pix` | `1.2.1-beta.11` | `1.10.7` |
| `qrcode` | `1.2.1-beta.11` | `""` (empty, must be set) |
| `job` | `1.2.1-beta.12` | `1.2.1-beta.7` |

> **Important:** The `qrcode.image.tag` is now empty by default. You must set it explicitly in your values override.

**Migration Steps:**

Set the QR code image tag in your values override:

```yaml
qrcode:
  image:
    tag: "1.10.7"  # Or the appropriate version for your deployment
```

### 3. Resource Optimization

Memory limits and requests have been optimized for the `pix` component.

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

**After (v1.2.10):**

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

| Resource | v2.2.11 | v1.2.10 | Change |
|----------|---------|---------|--------|
| Memory Limit | 512Mi | 256Mi | -50% |
| Memory Request | 256Mi | 128Mi | -50% |

> **Note:** This change reflects improved memory efficiency in the application. Monitor your pods after upgrade to ensure they do not experience OOMKilled events. If your workload requires more memory, override these values.

### 4. Autoscaling Configuration Changes

Autoscaling parameters have been adjusted for both `pix` and `qrcode` components.

**PIX Component:**

| Setting | v2.2.11 | v1.2.10 |
|---------|---------|---------|
| `minReplicas` | 3 | 1 |
| `maxReplicas` | 12 | 3 |
| `targetCPUUtilizationPercentage` | 70 | 80 |
| `targetMemoryUtilizationPercentage` | 85 | 80 |

**QR Code Component:**

| Setting | v2.2.11 | v1.2.10 |
|---------|---------|---------|
| `minReplicas` | 3 | 1 |

**Before (v2.2.11):**

```yaml
pix:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 12
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 85

qrcode:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 9
```

**After (v1.2.10):**

```yaml
pix:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilizationPercentage: 80
    targetMemoryUtilizationPercentage: 80

qrcode:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 9
```

> **Warning:** The minimum replica count drops from 3 to 1. This reduces baseline resource consumption but may impact availability during pod restarts or node failures. For production environments, consider overriding `minReplicas` to at least 2.

**Production Override Example:**

```yaml
pix:
  autoscaling:
    minReplicas: 2
    maxReplicas: 6

qrcode:
  autoscaling:
    minReplicas: 2
```

### 5. Configuration Defaults Update

Several configuration defaults have changed to reflect best practices for different environments.

**Environment and Debug Settings:**

| Component | Setting | v2.2.11 | v1.2.10 |
|-----------|---------|---------|---------|
| `pix` | `NODE_ENV` | `"production"` | `"development"` |
| `pix` | `DEBUG` | `"true"` | `"false"` |
| `job` | `NODE_ENV` | `"production"` | `"development"` |
| `job` | `DEBUG` | `"true"` | `"false"` |

**Before (v2.2.11):**

```yaml
pix:
  configmap:
    NODE_ENV: "production"
    DEBUG: "true"
    LOG_LEVEL: "debug"

job:
  configmap:
    NODE_ENV: "production"
    DEBUG: "true"
    LOG_LEVEL: "debug"
```

**After (v1.2.10):**

```yaml
pix:
  configmap:
    NODE_ENV: "development"
    DEBUG: "false"

job:
  configmap:
    NODE_ENV: "development"
    DEBUG: "false"
```

> **Important:** For production deployments, you **must** override these values to use production settings.

**Production Values Override:**

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

**Other Configuration Changes:**

| Setting | v2.2.11 | v1.2.10 |
|---------|---------|---------|
| `pix.revisionHistoryLimit` | 5 | 10 |
| `pix.configmap.MIDAZ_ORGANIZATION_ID` | `"your-organization"` | `""` (empty) |
| `pix.configmap.JOBS_CRON_TRANSACTIONS` | `"*/11 * * * *"` | `"*/10 * * * *"` |

### 6. API Version Decoupling

The `API_VERSION` and `OTEL_RESOURCE_SERVICE_VERSION` environment variables are no longer derived from the image tag. They now have independent default values.

**Before (v2.2.11):**

```yaml
# ConfigMap template
API_VERSION: {{ .Values.pix.image.tag | default .Chart.AppVersion | quote }}
OTEL_RESOURCE_SERVICE_VERSION: {{ .Values.pix.image.tag | default .Chart.AppVersion | quote }}
```

**After (v1.2.10):**

```yaml
# ConfigMap template
API_VERSION: {{ .Values.pix.configmap.API_VERSION | default "1.0.0" | quote }}
OTEL_RESOURCE_SERVICE_VERSION: {{ .Values.pix.configmap.OTEL_RESOURCE_SERVICE_VERSION | default "1.0.0" | quote }}
```

**Operational Impact:**

- The API version reported by the application and in telemetry is now independent of the Docker image tag
- If you need to set a specific version for monitoring or API documentation, override these values:

```yaml
pix:
  configmap:
    API_VERSION: "1.10.0"
    OTEL_RESOURCE_SERVICE_VERSION: "1.10.0"

job:
  configmap:
    API_VERSION: "1.10.0"
    OTEL_RESOURCE_SERVICE_VERSION: "1.10.0"
```

### 7. Environment Variable Changes

**QR Code Service:**

The `VERSION` environment variable is now hardcoded to `"v1.0.0"` instead of being derived from the image tag.

**Before (v2.2.11):**

```yaml
# templates/plugin-br-pix-direct-jd-qr-code/configmap.yaml
data:
  VERSION: {{ .Values.qrcode.image.tag | default .Chart.AppVersion | quote }}
  LOG_LEVEL: {{ .Values.qrcode.configmap.LOG_LEVEL | default "info" | quote }}
```

**After (v1.2.10):**

```yaml
# templates/plugin-br-pix-direct-jd-qr-code/configmap.yaml
data:
  VERSION: "v1.0.0"
```

> **Note:** The `LOG_LEVEL` variable has been removed. If your QR code service requires a version override, you will need to patch the ConfigMap manually or request a chart update.

### 8. Job Image Tag Update

The `job` component image tag has been rolled back from `1.2.1-beta.12` to `1.2.1-beta.7`.

| Component | v2.2.11 | v1.2.10 |
|-----------|---------|---------|
| `job.image.tag` | `1.2.1-beta.12` | `1.2.1-beta.7` |

> **Warning:** This is a rollback to an earlier beta version. Ensure this version is compatible with your deployment and does not reintroduce bugs that were fixed in beta.12.

### 9. QR Code Service Configuration

The QR code service secrets have been simplified.

**Before (v2.2.11):**

```yaml
# templates/plugin-br-pix-direct-jd-qr-code/secrets.yaml
data:
  KEY: {{ .Values.qrcode.secrets.PRIVATE_KEY | default "" | b64enc | quote }}
  CERTIFICATE: {{ .Values.qrcode.secrets.CERTIFICATE | default "lerian" | b64enc | quote }}
  NEW_KEY: {{ .Values.qrcode.secrets.NEW_PRIVATE_KEY | default "" | b64enc | quote }}
```

**After (v1.2.10):**

```yaml
# templates/plugin-br-pix-direct-jd-qr-code/secrets.yaml
data:
  KEY: {{ .Values.qrcode.secrets.PRIVATE_KEY | default "" | b64enc | quote }}
  CERTIFICATE: {{ .Values.qrcode.secrets.CERTIFICATE | default "lerian" | b64enc | quote }}
```

The `NEW_KEY` secret has been removed. If your QR code service was using this value, you will need to adjust your configuration.

## Configuration Reference

Below is a complete reference for new and changed configuration fields in v1.2.10.

### Chart Annotations

| Field | Default | Description |
|-------|---------|-------------|
| `annotations.lerian.studio/chart-type` | `multi-component` | Indicates this chart deploys multiple related components |

### PIX Component

| Field | Default | Description |
|-------|---------|-------------|
| `pix.revisionHistoryLimit` | `10` | Number of old ReplicaSets to retain (increased from 5) |
| `pix.image.tag` | `"1.10.7"` | Docker image tag for the PIX service |
| `pix.resources.limits.memory` | `256Mi` | Maximum memory allocation (reduced from 512Mi) |
| `pix.resources.requests.memory` | `128Mi` | Minimum memory request (reduced from 256Mi) |
| `pix.autoscaling.minReplicas` | `1` | Minimum number of replicas (reduced from 3) |
| `pix.autoscaling.maxReplicas` | `3` | Maximum number of replicas (reduced from 12) |
| `pix.autoscaling.targetCPUUtilizationPercentage` | `80` | CPU threshold for scaling (increased from 70) |
| `pix.autoscaling.targetMemoryUtilizationPercentage` | `80` | Memory threshold for scaling (decreased from 85) |
| `pix.configmap.NODE_ENV` | `"development"` | Node.js environment (changed from "production") |
| `pix.configmap.DEBUG` | `"false"` | Enable debug logging (changed from "true") |
| `pix.configmap.API_VERSION` | `"1.0.0"` | API version reported by the service (decoupled from image tag) |
| `pix.configmap.OTEL_RESOURCE_SERVICE_VERSION` | `"1.0.0"` | Service version for OpenTelemetry (decoupled from image tag) |
| `pix.configmap.MIDAZ_ORGANIZATION_ID` | `""` | Midaz organization identifier (changed from "your-organization") |
| `pix.configmap.JOBS_CRON_TRANSACTIONS` | `"*/10 * * * *"` | Cron schedule for transaction jobs (changed from "*/11 * * * *") |
| `pix.secrets.JD_SECRET` | `""` | **Required** - JD authentication secret |
| `pix.secrets.JD_PIX_CLIENT_SECRET` | `""` | **Required** - JD PIX client secret |
| `pix.secrets.DATABASE_PASSWORD` | `""` | Database password (conditionally emitted if set) |
| `pix.secrets.POSTGRES_PASSWORD` | `""` | PostgreSQL password (conditionally emitted if set) |

### QR Code Component

| Field | Default | Description |
|-------|---------|-------------|
| `qrcode.image.tag` | `""` | **Must be set** - Docker image tag for QR code service |
| `qrcode.autoscaling.minReplicas` | `1` | Minimum number of replicas (reduced from 3) |

### Job Component

| Field | Default | Description |
|-------|---------|-------------|
| `job.image.tag` | `"1.2.1-beta.7"` | Docker image tag for job component (rolled back from beta.12) |
| `job.configmap.NODE_ENV` | `"development"` | Node.js environment (changed from "production") |
| `job.configmap.DEBUG` | `"false"` | Enable debug logging (changed from "true") |
| `job.configmap.API_VERSION` | `"1.0.0"` | API version (decoupled from image tag) |
| `job.configmap.OTEL_RESOURCE_SERVICE_VERSION` | `"1.0.0"` | Service version for OpenTelemetry (decoupled from image tag) |

### PostgreSQL Subchart

| Field | Default | Description |
|-------|---------|-------------|
| `postgresql.auth.password` | `""` | **Must be set if using embedded PostgreSQL** - Database password |

### Complete Values Override Example

```yaml
# Production-ready values override for v1.2.10
pix:
  image:
    tag: "1.10.7"
  
  resources:
    limits:
      memory: 512Mi  # Override if needed
    requests:
      memory: 256Mi  # Override if needed
  
  autoscaling:
    minReplicas: 2  # Recommended for production
    maxReplicas: 6
  
  configmap:
    NODE_ENV: "production"
    DEBUG: "false"
    API_VERSION: "1.10.0"
    OTEL_RESOURCE_SERVICE_VERSION: "1.10.0"
    MIDAZ_ORGANIZATION_ID: "your-org-id"
  
  secrets:
    JD_SECRET: "your-actual-jd-secret"
    JD_PIX_CLIENT_SECRET: "your-actual-pix-client-secret"
    DATABASE_PASSWORD: "your-secure-db-password"

qrcode:
  image:
    tag: "1.10.7"
  
  autoscaling:
    minReplicas: 2

job:
  image:
    tag: "1.2.1-beta.7"
  
  configmap:
    NODE_ENV: "production"
    DEBUG: "false"
    API_VERSION: "1.10.0"
    OTEL_RESOURCE_SERVICE_VERSION: "1.10.0"

postgresql:
  auth:
    password: "your-secure-db-password"
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 1.2.10 -n plugin-br-pix-direct-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 1.2.10 -n plugin-br-pix-direct-jd
```
