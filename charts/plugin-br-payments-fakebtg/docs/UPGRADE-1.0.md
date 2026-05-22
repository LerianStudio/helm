# Helm Upgrade from v0.x to v1.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [Chart Name Mismatch](#chart-name-mismatch)
  - [New Chart Structure](#new-chart-structure)
- **[Features](#features)**
  - [1. Complete Chart Implementation](#1-complete-chart-implementation)
  - [2. Security Hardening](#2-security-hardening)
  - [3. Chaos Engineering Support](#3-chaos-engineering-support)
  - [4. Health Probes](#4-health-probes)
  - [5. Ingress Support](#5-ingress-support)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.0.0 is the **initial production release** of the `plugin-br-payments-fakebtg` Helm chart. Version 0.0.0 was a placeholder with no functional templates or configuration. This upgrade introduces a complete, production-ready chart for deploying the fakebtg mock BTG provider API server.

**What is fakebtg?**  
A test double HTTP service that mocks the BTG provider API surface for use in dev/staging environments. It provides runtime chaos injection endpoints (`/admin/*`) and request inspection (`/inspect/*`) for integration testing without access to the real BTG sandbox.

> **Warning:** This chart is intended **only for dev/staging environments**. Do NOT deploy fakebtg in production. Production deployments of plugin-br-payments must point to the real BTG provider endpoints.

## Breaking Changes

### Chart Name Mismatch

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Chart name in `Chart.yaml` | N/A (no chart existed) | `plugin-br-payments-fakebtg-helm` |
| Default resource name | N/A | `plugin-br-payments-fakebtg` |

**Why it matters:**  
The chart name in `Chart.yaml` is `plugin-br-payments-fakebtg-helm`, but all generated Kubernetes resource names default to `plugin-br-payments-fakebtg` (controlled by `nameOverride` and `fullnameOverride`). This is intentional to keep resource names concise.

**Action required:**  
None. The chart will create new resources with the `plugin-br-payments-fakebtg` prefix. If you had any manual resources from v0.0.0, they must be removed before installing v1.0.0.

### New Chart Structure

| Component | v0.0.0 | v1.0.0 |
|-----------|--------|--------|
| Templates | None | Deployment, Service, Ingress, ServiceAccount, NOTES.txt |
| Values schema | Empty | Full configuration tree under `fakebtg.*` |
| Helpers | None | `_helpers.tpl` with name, label, and namespace functions |

**Why it matters:**  
v0.0.0 was a non-functional placeholder. v1.0.0 is a complete chart. There is no upgrade path from v0.0.0 because no resources existed.

**Action required:**  
Treat this as a **fresh installation**, not an upgrade. If you have a v0.0.0 release installed, uninstall it first:

```bash
helm uninstall plugin-br-payments-fakebtg -n plugin-br-payments-fakebtg
```

Then proceed with a clean install of v1.0.0.

## Features

### 1. Complete Chart Implementation

v1.0.0 introduces a fully functional Helm chart with:

- **Deployment**: Single replica running the fakebtg binary on a distroless nonroot image
- **Service**: ClusterIP service exposing port 8090
- **ServiceAccount**: Dedicated service account with optional annotations
- **Ingress**: Optional ingress for external access to `/admin/*` and `/inspect/*` endpoints
- **Probes**: Readiness and liveness probes against `GET /health`

**Default deployment:**

```yaml
fakebtg:
  name: "plugin-br-payments-fakebtg"
  replicaCount: 1
  image:
    repository: ghcr.io/lerianstudio/plugin-br-payments-fakebtg
    pullPolicy: IfNotPresent
    tag: ""  # Defaults to Chart.appVersion (1.0.0-beta.22)
  service:
    type: ClusterIP
    port: 8090
    targetPort: 8090
```

**In-cluster service endpoint:**

```
http://plugin-br-payments-fakebtg.<namespace>.svc.cluster.local:8090
```

### 2. Security Hardening

v1.0.0 enforces security best practices:

**Container security context:**

```yaml
fakebtg:
  securityContext:
    runAsGroup: 65532
    runAsUser: 65532
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
```

| Security Control | Default | Description |
|------------------|---------|-------------|
| `runAsUser` | `65532` | Distroless nonroot UID |
| `runAsGroup` | `65532` | Distroless nonroot GID |
| `runAsNonRoot` | `true` | Enforces non-root execution |
| `allowPrivilegeEscalation` | `false` | Prevents privilege escalation |
| `capabilities.drop` | `ALL` | Drops all Linux capabilities |
| `readOnlyRootFilesystem` | `true` | Mounts root filesystem read-only |

**Why it matters:**  
The fakebtg binary does not require filesystem writes or elevated privileges. The read-only root filesystem and dropped capabilities minimize the attack surface.

**Action required:**  
None. These defaults are applied automatically. Override `fakebtg.securityContext` only if your cluster security policies require different settings.

### 3. Chaos Engineering Support

fakebtg exposes runtime chaos injection endpoints for integration testing:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/admin/set-error` | POST | Inject a specific error response for a route |
| `/admin/set-latency` | POST | Inject artificial latency |
| `/admin/clear-error` | POST | Clear an injected error |
| `/admin/clear-latency` | POST | Clear injected latency |
| `/admin/reset` | POST | Reset all injected scenarios |
| `/inspect/calls` | GET | List recorded inbound requests |
| `/inspect/calls` | DELETE | Clear the request log |

**Why it matters:**  
External integrators can use these endpoints to simulate BTG provider failures, timeouts, and edge cases without modifying the fakebtg deployment.

**Action required:**  
If you need external access to these endpoints, enable the Ingress:

```yaml
fakebtg:
  ingress:
    enabled: true
    className: "nginx"
    hosts:
      - host: "fakebtg.example.com"
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: fakebtg-tls
        hosts:
          - fakebtg.example.com
```

> **Important:** The `/admin/*` endpoints allow arbitrary error injection. Only expose the Ingress in controlled dev/staging environments. Never expose fakebtg publicly.

### 4. Health Probes

v1.0.0 configures readiness and liveness probes against `GET /health`:

**Readiness probe (default):**

```yaml
fakebtg:
  readinessProbe:
    initialDelaySeconds: 2
    periodSeconds: 5
    timeoutSeconds: 2
    successThreshold: 1
    failureThreshold: 2
```

**Liveness probe (default):**

```yaml
fakebtg:
  livenessProbe:
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 2
    successThreshold: 1
    failureThreshold: 3
```

| Probe | Initial Delay | Period | Timeout | Failure Threshold |
|-------|---------------|--------|---------|-------------------|
| Readiness | 2s | 5s | 2s | 2 |
| Liveness | 10s | 10s | 2s | 3 |

**Why it matters:**  
The readiness probe ensures the pod only receives traffic after the HTTP server is listening. The liveness probe restarts the pod if the server becomes unresponsive.

**Action required:**  
None. Override `fakebtg.readinessProbe` or `fakebtg.livenessProbe` only if you need custom timings.

### 5. Ingress Support

v1.0.0 includes an optional Ingress resource for external access:

**Disabled by default:**

```yaml
fakebtg:
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts: []
    tls: []
```

**Example with TLS:**

```yaml
fakebtg:
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - host: "fakebtg.dev.example.com"
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: fakebtg-tls
        hosts:
          - fakebtg.dev.example.com
```

**Why it matters:**  
Ingress allows external integrators (e.g., CI pipelines, manual testers) to reach the `/admin/*` and `/inspect/*` endpoints without port-forwarding.

**Action required:**  
Enable Ingress only if you need external access. For in-cluster access, use the ClusterIP service.

## Configuration Reference

### Full Values Schema

```yaml
# Override the chart top-level name
nameOverride: "plugin-br-payments-fakebtg"
# Override the fully generated name
fullnameOverride: ""
# Override the namespace used by templates
namespaceOverride: ""

fakebtg:
  # Service name
  name: "plugin-br-payments-fakebtg"
  # Number of replicas (keep at 1; fakebtg holds in-memory state)
  replicaCount: 1
  # Number of old ReplicaSets to retain for rollback
  revisionHistoryLimit: 5

  # Container image
  image:
    repository: ghcr.io/lerianstudio/plugin-br-payments-fakebtg
    pullPolicy: IfNotPresent
    tag: ""  # Defaults to Chart.appVersion

  # Image pull secrets for private registries
  imagePullSecrets: []

  # Annotations applied to the Deployment resource
  annotations: {}
  # Annotations applied to the pods
  podAnnotations: {}

  # Termination grace period (seconds)
  terminationGracePeriodSeconds: 10

  # Pod-level securityContext
  podSecurityContext: {}

  # Container-level securityContext
  securityContext:
    runAsGroup: 65532
    runAsUser: 65532
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true

  # Rolling update strategy
  deploymentStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0

  # Service configuration
  service:
    type: ClusterIP
    port: 8090
    targetPort: 8090
    annotations: {}

  # Optional Ingress
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts:
      - host: ""
        paths:
          - path: /
            pathType: Prefix
    tls: []

  # Container resource requests/limits
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi

  # Readiness probe
  readinessProbe:
    initialDelaySeconds: 2
    periodSeconds: 5
    timeoutSeconds: 2
    successThreshold: 1
    failureThreshold: 2

  # Liveness probe
  livenessProbe:
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 2
    successThreshold: 1
    failureThreshold: 3

  # Pod nodeSelector
  nodeSelector: {}
  # Pod tolerations
  tolerations: []
  # Pod affinity rules
  affinity: {}

  # Extra environment variables
  # Example: FAKEBTG_PORT to override the default :8090
  extraEnvVars: {}

  # ServiceAccount
  serviceAccount:
    create: true
    annotations: {}
    name: ""

# Tag block for image-update tooling
plugin-br-payments-fakebtg:
  image:
    tag: 1.0.0-beta.20
```

### Key Configuration Fields

| Field | Default | Description |
|-------|---------|-------------|
| `fakebtg.replicaCount` | `1` | Number of replicas. **Must remain 1** because fakebtg holds in-memory scenario state. |
| `fakebtg.image.repository` | `ghcr.io/lerianstudio/plugin-br-payments-fakebtg` | Container image repository |
| `fakebtg.image.tag` | `""` (uses `Chart.appVersion`) | Container image tag |
| `fakebtg.service.type` | `ClusterIP` | Service type (ClusterIP, NodePort, LoadBalancer) |
| `fakebtg.service.port` | `8090` | Service port |
| `fakebtg.ingress.enabled` | `false` | Enable Ingress for external access |
| `fakebtg.resources.requests.cpu` | `50m` | CPU request |
| `fakebtg.resources.requests.memory` | `64Mi` | Memory request |
| `fakebtg.resources.limits.cpu` | `200m` | CPU limit |
| `fakebtg.resources.limits.memory` | `128Mi` | Memory limit |
| `fakebtg.extraEnvVars` | `{}` | Additional environment variables (e.g., `FAKEBTG_PORT`) |
| `fakebtg.serviceAccount.create` | `true` | Create a dedicated ServiceAccount |

### Environment Variables

The fakebtg binary supports the following environment variables (set via `fakebtg.extraEnvVars`):

| Variable | Default | Description |
|----------|---------|-------------|
| `FAKEBTG_PORT` | `:8090` | HTTP server listen address |

**Example override:**

```yaml
fakebtg:
  extraEnvVars:
    FAKEBTG_PORT: ":9090"
  service:
    port: 9090
    targetPort: 9090
```

## Migration Steps

Because v0.0.0 was a non-functional placeholder, there is no data or configuration to migrate. Follow these steps for a clean installation:

### Step 1: Remove v0.0.0 (if installed)

If you have a v0.0.0 release installed, uninstall it:

```bash
helm uninstall plugin-br-payments-fakebtg -n plugin-br-payments-fakebtg
```

### Step 2: Create namespace (if needed)

```bash
kubectl create namespace plugin-br-payments-fakebtg
```

### Step 3: Prepare values file

Create a `values.yaml` file with your environment-specific overrides. Minimal example:

```yaml
fakebtg:
  replicaCount: 1
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi
```

### Step 4: Install v1.0.0

```bash
helm install plugin-br-payments-fakebtg oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm \
  --version 1.0.0 \
  -n plugin-br-payments-fakebtg \
  -f values.yaml
```

### Step 5: Verify deployment

```bash
kubectl get pods -n plugin-br-payments-fakebtg
kubectl get svc -n plugin-br-payments-fakebtg
```

Expected output:

```
NAME                                          READY   STATUS    RESTARTS   AGE
plugin-br-payments-fakebtg-xxxxxxxxxx-xxxxx   1/1     Running   0          30s

NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
plugin-br-payments-fakebtg       ClusterIP   10.96.xxx.xxx   <none>        8090/TCP   30s
```

### Step 6: Test health endpoint

```bash
kubectl port-forward -n plugin-br-payments-fakebtg svc/plugin-br-payments-fakebtg 8090:8090
curl http://localhost:8090/health
```

Expected response:

```json
{"status":"ok"}
```

### Step 7: Configure plugin-br-payments (if applicable)

If you are using this chart with the `plugin-br-payments` chart, configure the plugin to point to the fakebtg service:

```yaml
# In plugin-br-payments values.yaml
env:
  PROVIDER_API_BASE_URL: "http://plugin-br-payments-fakebtg.plugin-br-payments-fakebtg.svc.cluster.local:8090"
```

> **Note:** Replace the namespace in the URL if you deployed fakebtg to a different namespace.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments-fakebtg oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm --version 1.0.0 -n plugin-br-payments-fakebtg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments-fakebtg oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm --version 1.0.0 -n plugin-br-payments-fakebtg
```
