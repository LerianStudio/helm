# Helm Upgrade from v2.x to v3.x

## Table of Contents

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [Readiness Probe Path Changed](#readiness-probe-path-changed)
- **[Features](#features)**
  - [1. Configurable Health and Readiness Probes](#1-configurable-health-and-readiness-probes)
  - [2. Application Version Update](#2-application-version-update)
- **[Configuration Reference](#configuration-reference)**
  - [Probe Configuration Fields](#probe-configuration-fields)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Current Probe Behavior](#step-1-review-current-probe-behavior)
  - [Step 2: Verify Application Endpoints](#step-2-verify-application-endpoints)
  - [Step 3: Update Values (Optional)](#step-3-update-values-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the upgrade from `plugin-br-pix-indirect-btg` chart version **2.3.0** to **3.0.0**. This is a **major version bump** that introduces a breaking change to readiness probe endpoints and adds full configurability for health check probes across all components.

**Key changes:**
- Default readiness probe path changed from `/health` to `/readyz`
- All probe parameters (timeouts, thresholds, periods) are now configurable
- Application version updated from 1.5.2 to 1.6.0

## Breaking Changes

### Readiness Probe Path Changed

**What changed:**

The default readiness probe endpoint has been changed from `/health` to `/readyz` for all four components: `pix`, `inbound`, `outbound`, and `reconciliation`.

| Component | Probe Type | v2.3.0 Path | v3.0.0 Path |
|-----------|------------|-------------|-------------|
| pix | readinessProbe | `/health` | `/readyz` |
| inbound | readinessProbe | `/health` | `/readyz` |
| outbound | readinessProbe | `/health` | `/readyz` |
| reconciliation | readinessProbe | `/health` | `/readyz` |

**Before (v2.3.0):**

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: {{ .Values.pix.service.port }}
  initialDelaySeconds: 10
  periodSeconds: 5
```

**After (v3.0.0):**

```yaml
readinessProbe:
  httpGet:
    path: {{ .Values.pix.readinessProbe.path | default "/readyz" }}
    port: {{ .Values.pix.service.port }}
  initialDelaySeconds: {{ .Values.pix.readinessProbe.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.pix.readinessProbe.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.pix.readinessProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ .Values.pix.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ .Values.pix.readinessProbe.failureThreshold | default 3 }}
```

**Why it matters:**

The `/readyz` endpoint is a Kubernetes best practice that separates readiness checks (is the service ready to accept traffic?) from liveness checks (is the service alive?). This change assumes that application version 1.6.0 implements the `/readyz` endpoint.

> **Warning:** If your application version 1.6.0 does not expose a `/readyz` endpoint, pods will fail readiness checks and will not receive traffic. You must either ensure the application supports this endpoint or override the probe path back to `/health`.

**Operational impact:**

- During upgrade, pods will be recreated with the new probe configuration
- If the `/readyz` endpoint is not available, new pods will remain in a non-ready state
- Kubernetes will not route traffic to pods that fail readiness checks
- Rollout will block if readiness probes fail continuously

**Liveness probe paths remain unchanged:**

All liveness probes continue to use `/health` as the default endpoint.

## Features

### 1. Configurable Health and Readiness Probes

**What changed:**

All four components (`pix`, `inbound`, `outbound`, `reconciliation`) now support full customization of both readiness and liveness probes through values.yaml. Previously, probe parameters were hardcoded in the templates.

**New configuration blocks added:**

```yaml
pix:
  readinessProbe: {}
  livenessProbe: {}

inbound:
  readinessProbe: {}
  livenessProbe: {}

outbound:
  readinessProbe: {}
  livenessProbe: {}

reconciliation:
  readinessProbe: {}
  livenessProbe: {}
```

**Why it matters:**

Operators can now tune probe behavior for their specific environment without modifying chart templates. This is critical for:
- Adjusting timeouts for slow-starting applications
- Increasing failure thresholds in high-latency networks
- Customizing probe paths if the application uses non-standard endpoints
- Fine-tuning probe frequency to balance responsiveness vs. resource usage

**Configurable parameters:**

Each probe now supports the following parameters (see Configuration Reference for defaults):

- `path` - HTTP endpoint to check
- `initialDelaySeconds` - Delay before first probe
- `periodSeconds` - How often to perform the probe
- `timeoutSeconds` - Probe timeout duration
- `successThreshold` - Consecutive successes required
- `failureThreshold` - Consecutive failures before action

**Example customization:**

```yaml
pix:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 15
    periodSeconds: 10
    timeoutSeconds: 3
    failureThreshold: 5
  livenessProbe:
    path: /health
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
```

### 2. Application Version Update

**What changed:**

The application version (appVersion) has been updated from **1.5.2** to **1.6.0**, and all component image tags have been updated accordingly.

| Component | v2.3.0 Tag | v3.0.0 Tag |
|-----------|------------|------------|
| pix | 1.5.2 | 1.6.0 |
| inbound | 1.5.2 | 1.6.0 |
| outbound | 1.5.2 | 1.6.0 |
| reconciliation | 1.5.2 | 1.6.0 |

**Why it matters:**

Application version 1.6.0 is expected to include the new `/readyz` endpoint and may contain other functional changes, bug fixes, or improvements. Review the application's release notes for version 1.6.0 to understand all changes.

## Configuration Reference

### Probe Configuration Fields

The following table describes all configurable probe parameters. These apply to both `readinessProbe` and `livenessProbe` for all components (`pix`, `inbound`, `outbound`, `reconciliation`).

| Flag | Default (Readiness) | Default (Liveness) | Description |
|------|---------------------|-------------------|-------------|
| `path` | `/readyz` | `/health` | HTTP endpoint path for the probe |
| `initialDelaySeconds` | `10` (pix, inbound, outbound)<br>`5` (reconciliation) | `5` (pix, inbound, outbound)<br>`10` (reconciliation) | Number of seconds after container start before probe is initiated |
| `periodSeconds` | `5` | `5` | How often (in seconds) to perform the probe |
| `timeoutSeconds` | `1` | `1` | Number of seconds after which the probe times out |
| `successThreshold` | `1` | `1` | Minimum consecutive successes for the probe to be considered successful |
| `failureThreshold` | `3` | `3` | Minimum consecutive failures for the probe to be considered failed |

**Complete configuration example for all components:**

```yaml
pix:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: /health
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3

inbound:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: /health
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3

outbound:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: /health
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3

reconciliation:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  livenessProbe:
    path: /health
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
```

> **Note:** You only need to specify the parameters you want to override. Unspecified parameters will use the defaults shown above.

## Migration Steps

### Step 1: Review Current Probe Behavior

Before upgrading, verify that your current deployment is healthy and that all pods are passing their health checks.

```bash
kubectl get pods -n plugin-br-pix-indirect-btg
kubectl describe pod <pod-name> -n plugin-br-pix-indirect-btg
```

Check the "Readiness" and "Liveness" sections in the pod description to confirm current probe status.

### Step 2: Verify Application Endpoints

Confirm that application version 1.6.0 exposes the `/readyz` endpoint. You can test this by port-forwarding to a running pod (if you have a test environment with 1.6.0) or by reviewing the application's documentation.

```bash
kubectl port-forward -n plugin-br-pix-indirect-btg deployment/plugin-br-pix-indirect-btg 8080:8080
curl http://localhost:8080/readyz
```

> **Important:** If the `/readyz` endpoint is not available in version 1.6.0, you must override the readiness probe path to continue using `/health`.

### Step 3: Update Values (Optional)

#### Option 1: Use Default Configuration

If your application supports the `/readyz` endpoint and the default probe timings are acceptable, no values changes are required. Proceed directly to the upgrade command.

#### Option 2: Override Readiness Probe Path

If the `/readyz` endpoint is not available, override the readiness probe path for all components:

```yaml
pix:
  readinessProbe:
    path: /health

inbound:
  readinessProbe:
    path: /health

outbound:
  readinessProbe:
    path: /health

reconciliation:
  readinessProbe:
    path: /health
```

Save this to your `values.yaml` or pass via `--set` flags:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm \
  --version 3.0.0 \
  -n plugin-br-pix-indirect-btg \
  --set pix.readinessProbe.path=/health \
  --set inbound.readinessProbe.path=/health \
  --set outbound.readinessProbe.path=/health \
  --set reconciliation.readinessProbe.path=/health
```

#### Option 3: Customize Probe Timings

If your environment requires adjusted probe timings (e.g., longer startup times, higher failure tolerance), customize the probe parameters:

```yaml
pix:
  readinessProbe:
    initialDelaySeconds: 20
    periodSeconds: 10
    failureThreshold: 5
  livenessProbe:
    initialDelaySeconds: 30
    failureThreshold: 5

inbound:
  readinessProbe:
    initialDelaySeconds: 20
    periodSeconds: 10
    failureThreshold: 5
  livenessProbe:
    initialDelaySeconds: 30
    failureThreshold: 5

outbound:
  readinessProbe:
    initialDelaySeconds: 20
    periodSeconds: 10
    failureThreshold: 5
  livenessProbe:
    initialDelaySeconds: 30
    failureThreshold: 5

reconciliation:
  readinessProbe:
    initialDelaySeconds: 20
    periodSeconds: 10
    failureThreshold: 5
  livenessProbe:
    initialDelaySeconds: 30
    failureThreshold: 5
```

> **Note:** Increasing `failureThreshold` and `initialDelaySeconds` gives pods more time to become ready but may delay detection of actual failures.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.0.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.0.0 -n plugin-br-pix-indirect-btg
```
