# Helm Upgrade from v0.x to v1.x

This guide covers the upgrade of the `br-spi-mock-bacen` Helm chart from version **0.0.0** to **1.0.0**. This is the initial production release of the chart, introducing a complete deployment configuration for the BACEN simulator used in the BR SFN SPI rail.

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[New Features](#new-features)**
  - [1. Complete Deployment Configuration](#1-complete-deployment-configuration)
  - [2. Environment Validation](#2-environment-validation)
  - [3. Security Hardening](#3-security-hardening)
  - [4. Health Probes](#4-health-probes)
  - [5. ConfigMap-Based Configuration](#5-configmap-based-configuration)
- **[Configuration Reference](#configuration-reference)**
  - [Core Settings](#core-settings)
  - [Application Configuration](#application-configuration)
  - [Environment Variables](#environment-variables)
  - [Service Configuration](#service-configuration)
  - [Resource Limits](#resource-limits)
  - [Health Probes](#health-probes)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.0.0 is the **first release** of the `br-spi-mock-bacen` chart. This chart deploys a non-production BACEN simulator for the BR SFN SPI rail (PIX). 

> **Warning:** This is a **simulator with unauthenticated `/control/*` endpoints**. It must **never** be deployed to production or production-adjacent environments. The chart enforces this restriction through environment validation.

| Aspect | v0.0.0 | v1.0.0 |
|--------|--------|--------|
| Chart exists | No | Yes |
| Deployment support | None | Full Kubernetes deployment |
| Environment restrictions | N/A | Enforced: local, development, test, ci only |
| Service exposure | N/A | ClusterIP only (enforced) |
| Security context | N/A | Hardened (non-root, read-only filesystem) |

## Breaking Changes

Since this is the initial release (v0.0.0 → v1.0.0), there are no breaking changes from a previous version. However, operators must be aware of the following **enforced restrictions**:

### Environment Restriction

The chart will **fail to render** if `environment` is set to any value other than:
- `local`
- `development`
- `test`
- `ci`

**Before (v0.0.0):**
```yaml
# No chart existed
```

**After (v1.0.0):**
```yaml
environment: development  # REQUIRED - must be one of: local, development, test, ci
```

> **Important:** Any attempt to set `environment: production` or `environment: staging` will cause the Helm render to fail with an explicit error message. This is a safety feature to prevent accidental deployment of the unauthenticated mock to production environments.

### Service Type Restriction

The chart will **fail to render** if `app.service.type` is set to anything other than `ClusterIP`.

**After (v1.0.0):**
```yaml
app:
  service:
    type: ClusterIP  # REQUIRED - LoadBalancer and NodePort are explicitly blocked
```

> **Warning:** Setting `type: LoadBalancer` or `type: NodePort` will cause the render to fail. The mock exposes unauthenticated `/control/*` endpoints and must remain internal to the cluster.

## New Features

### 1. Complete Deployment Configuration

The chart now provides a full Kubernetes deployment with Deployment, Service, ConfigMap, and ServiceAccount resources.

**Key components:**

```yaml
app:
  enabled: true
  replicaCount: 1
  
  image:
    repository: ghcr.io/lerianstudio/br-spi-mock-bacen
    tag: ""  # Defaults to Chart.appVersion (1.0.0-beta.1)
    pullPolicy: IfNotPresent
  
  updateStrategy:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 0
  
  revisionHistoryLimit: 3
```

The deployment can be disabled entirely by setting:

```yaml
app:
  enabled: false
```

### 2. Environment Validation

The chart introduces a mandatory `environment` field that controls the `ENV_NAME` environment variable in the container. This value is validated at render time and must match one of the allowed non-production environments.

**Configuration:**

```yaml
environment: development  # Options: local, development, test, ci
```

| Flag | Default | Description |
|------|---------|-------------|
| `environment` | `development` | Runtime environment name. Rendered as `ENV_NAME` in ConfigMap. Must be one of: local, development, test, ci. |

The validation occurs in the `_helpers.tpl` template:

```yaml
{{- define "br-spi-mock-bacen.validateEnvironment" -}}
{{- $allowed := list "local" "development" "test" "ci" -}}
{{- $env := toString (.Values.environment | default "") -}}
{{- if not (has $env $allowed) -}}
{{- fail (printf "ERROR: environment=%q is not allowed...") -}}
{{- end -}}
{{- end }}
```

### 3. Security Hardening

The chart implements Kubernetes security best practices with a hardened security context.

**Pod Security Context:**

```yaml
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

**Container Security Context:**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

| Setting | Value | Description |
|---------|-------|-------------|
| `runAsNonRoot` | `true` | Container must run as non-root user |
| `runAsUser` | `65532` | UID for the container process (non-root) |
| `runAsGroup` | `65532` | GID for the container process |
| `allowPrivilegeEscalation` | `false` | Prevents privilege escalation |
| `readOnlyRootFilesystem` | `true` | Root filesystem is read-only |
| `capabilities.drop` | `ALL` | All Linux capabilities dropped |

### 4. Health Probes

The chart configures liveness, readiness, and startup probes for robust health monitoring.

**Liveness Probe:**

```yaml
app:
  livenessProbe:
    enabled: true
    path: /health
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 3
    failureThreshold: 3
```

**Readiness Probe:**

```yaml
app:
  readinessProbe:
    enabled: true
    path: /readyz
    initialDelaySeconds: 2
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3
```

**Startup Probe:**

```yaml
app:
  startupProbe:
    enabled: true
    path: /readyz
    periodSeconds: 2
    timeoutSeconds: 3
    failureThreshold: 30
```

| Probe | Path | Initial Delay | Period | Timeout | Failure Threshold |
|-------|------|---------------|--------|---------|-------------------|
| Liveness | `/health` | 5s | 10s | 3s | 3 |
| Readiness | `/readyz` | 2s | 5s | 3s | 3 |
| Startup | `/readyz` | 0s | 2s | 3s | 30 (60s total) |

All probes can be disabled individually:

```yaml
app:
  livenessProbe:
    enabled: false
  readinessProbe:
    enabled: false
  startupProbe:
    enabled: false
```

### 5. ConfigMap-Based Configuration

The chart renders a ConfigMap with application configuration. The `ENV_NAME` key is **reserved** and always populated from the top-level `environment` value.

**Default ConfigMap data:**

```yaml
app:
  configmap:
    LOG_LEVEL: info
    MOCK_BACEN_PORT: ":9900"
    MOCK_PIX_SETTLEMENT_DELAY_MS: "500"
```

> **Note:** The `ENV_NAME` key is reserved and cannot be set in `app.configmap`. It is automatically rendered from the `environment` value. The `values.schema.json` will reject any attempt to set `ENV_NAME` here.

The ConfigMap is mounted as environment variables in the container. Operators can add additional configuration keys:

```yaml
app:
  configmap:
    LOG_LEVEL: debug
    MOCK_BACEN_PORT: ":9900"
    MOCK_PIX_SETTLEMENT_DELAY_MS: "1000"
    CUSTOM_KEY: "custom-value"
```

## Configuration Reference

### Core Settings

```yaml
nameOverride: ""
fullnameOverride: ""
namespaceOverride: ""

environment: development  # REQUIRED: local, development, test, or ci
```

| Flag | Default | Description |
|------|---------|-------------|
| `nameOverride` | `""` | Override the chart name (truncated at 63 chars) |
| `fullnameOverride` | `""` | Override the full resource name |
| `namespaceOverride` | `""` | Override the release namespace |
| `environment` | `development` | Runtime environment (enforced: local, development, test, ci) |

### Application Configuration

```yaml
app:
  enabled: true
  replicaCount: 1

  image:
    repository: ghcr.io/lerianstudio/br-spi-mock-bacen
    tag: ""  # Defaults to Chart.appVersion
    pullPolicy: IfNotPresent

  imagePullSecrets: []

  updateStrategy:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 0

  revisionHistoryLimit: 3

  terminationGracePeriodSeconds: 10

  nodeSelector: {}
  tolerations: []
  affinity: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `app.enabled` | `true` | Enable/disable the entire deployment |
| `app.replicaCount` | `1` | Number of pod replicas |
| `app.image.repository` | `ghcr.io/lerianstudio/br-spi-mock-bacen` | Container image repository |
| `app.image.tag` | `""` (uses `Chart.appVersion`) | Container image tag |
| `app.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `app.revisionHistoryLimit` | `3` | Number of ReplicaSets to retain |
| `app.terminationGracePeriodSeconds` | `10` | Grace period for pod termination |

### Environment Variables

The following environment variables are rendered into the ConfigMap and injected into the container:

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV_NAME` | (from `environment`) | **Reserved.** Runtime environment name. Always set from top-level `environment` value. |
| `LOG_LEVEL` | `info` | Logging level (e.g., debug, info, warn, error) |
| `MOCK_BACEN_PORT` | `:9900` | Listener address for the mock service (must be in `:port` format) |
| `MOCK_PIX_SETTLEMENT_DELAY_MS` | `500` | Simulated PIX settlement delay in milliseconds |

**Example custom configuration:**

```yaml
app:
  configmap:
    LOG_LEVEL: debug
    MOCK_BACEN_PORT: ":9900"
    MOCK_PIX_SETTLEMENT_DELAY_MS: "1000"
```

> **Important:** `MOCK_BACEN_PORT` must be in the format `:<port>` (e.g., `:9900`). The chart validates this format and will fail if a bare port number (e.g., `9900`) is provided.

### Service Configuration

```yaml
app:
  service:
    type: ClusterIP  # ENFORCED - cannot be changed
    port: 9900
    targetPort: http
    annotations: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `app.service.type` | `ClusterIP` | **Enforced.** Service type (LoadBalancer and NodePort are blocked) |
| `app.service.port` | `9900` | Service port |
| `app.service.targetPort` | `http` | Target port name (references container port) |
| `app.service.annotations` | `{}` | Additional service annotations |

The service exposes the mock at:

```
http://<fullname>.<namespace>.svc.cluster.local:9900
```

For manual access, use port-forward:

```bash
kubectl port-forward -n <namespace> svc/<fullname> 9900:9900
```

### Resource Limits

```yaml
app:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 256Mi
```

| Resource | Request | Limit | Description |
|----------|---------|-------|-------------|
| `cpu` | `50m` | (none) | CPU request (no limit set) |
| `memory` | `64Mi` | `256Mi` | Memory request and limit |

### Health Probes

See [4. Health Probes](#4-health-probes) for full configuration details.

### Global Settings

```yaml
global:
  imageRegistry: ""
  imagePullSecrets: []
  commonLabels: {}
  commonAnnotations: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `global.imageRegistry` | `""` | Override image registry for all images (e.g., for air-gapped environments) |
| `global.imagePullSecrets` | `[]` | Image pull secrets applied to all pods |
| `global.commonLabels` | `{}` | Labels applied to all resources (reserved keys are filtered) |
| `global.commonAnnotations` | `{}` | Annotations applied to all resources |

### ServiceAccount

```yaml
serviceAccount:
  create: true
  annotations: {}
  name: ""
  automountServiceAccountToken: false
```

| Flag | Default | Description |
|------|---------|-------------|
| `serviceAccount.create` | `true` | Create a ServiceAccount for the deployment |
| `serviceAccount.annotations` | `{}` | Annotations for the ServiceAccount |
| `serviceAccount.name` | `""` | ServiceAccount name (defaults to fullname) |
| `serviceAccount.automountServiceAccountToken` | `false` | Disable automatic token mounting |

### Pod Annotations and Labels

```yaml
podAnnotations: {}
podLabels: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `podAnnotations` | `{}` | Additional annotations for pods |
| `podLabels` | `{}` | Additional labels for pods |

## Migration Steps

Since this is the initial release, there is no migration from a previous version. Follow these steps to deploy the chart for the first time:

### Step 1: Create namespace

```bash
kubectl create namespace br-spi-mock-bacen
```

### Step 2: Prepare values file

Create a `values.yaml` file with your environment-specific configuration:

```yaml
environment: development  # REQUIRED: local, development, test, or ci

app:
  replicaCount: 1
  
  image:
    tag: "1.0.0-beta.1"  # Or leave empty to use Chart.appVersion
  
  configmap:
    LOG_LEVEL: info
    MOCK_BACEN_PORT: ":9900"
    MOCK_PIX_SETTLEMENT_DELAY_MS: "500"
  
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 256Mi
```

### Step 3: Install the chart

```bash
helm install br-spi-mock-bacen oci://registry-1.docker.io/lerianstudio/br-spi-mock-bacen-helm \
  --version 1.0.0 \
  -n br-spi-mock-bacen \
  -f values.yaml
```

### Step 4: Verify deployment

```bash
kubectl get pods -n br-spi-mock-bacen
kubectl get svc -n br-spi-mock-bacen
```

### Step 5: Access the mock (optional)

For manual testing, use port-forward:

```bash
kubectl port-forward -n br-spi-mock-bacen svc/br-spi-mock-bacen 9900:9900
```

Then access the mock at `http://127.0.0.1:9900`.

> **Note:** The mock is intended for in-cluster access by other services. The documented service name is:
> ```
> http://br-spi-mock-bacen.br-spi-mock-bacen.svc.cluster.local:9900
> ```

## Preview changes before upgrading

```bash
helm diff upgrade br-spi-mock-bacen oci://registry-1.docker.io/lerianstudio/br-spi-mock-bacen-helm --version 1.0.0 -n br-spi-mock-bacen
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-spi-mock-bacen oci://registry-1.docker.io/lerianstudio/br-spi-mock-bacen-helm --version 1.0.0 -n br-spi-mock-bacen
```
