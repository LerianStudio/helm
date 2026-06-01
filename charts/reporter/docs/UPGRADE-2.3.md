# Helm Upgrade from v2.2.x to v2.3.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Manager readiness path now defaults to /readyz](#1-manager-readiness-path-now-defaults-to-readyz)
  - [2. Worker readiness path now defaults to /readyz](#2-worker-readiness-path-now-defaults-to-readyz)
  - [3. Manager and worker probe paths are now configurable](#3-manager-and-worker-probe-paths-are-now-configurable)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor maintenance release that aligns the `manager` and `worker` readiness probes with the platform-wide `/readyz` convention and exposes both probe paths through `values.yaml`. The application version is unchanged.

| Field | v2.2.x | v2.3.x |
|-------|--------|--------|
| Chart version | `2.2.1-beta.1` | `2.3.0-beta.1` |
| App version | `1.2.0` | `1.2.0` |

## Features

### 1. Manager readiness path now defaults to /readyz

The `manager` deployment readiness probe HTTP path default has changed from `/health` to `/readyz`. The liveness probe default path remains `/health`.

| Probe | v2.2.x default | v2.3.x default |
|-------|----------------|----------------|
| `manager.readinessProbe.path` | `/health` (hardcoded) | `/readyz` |
| `manager.livenessProbe.path` | `/health` (hardcoded) | `/health` |

Rendered probe block in v2.3.x:

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: <manager.service.port>
livenessProbe:
  httpGet:
    path: /health
    port: <manager.service.port>
```

### 2. Worker readiness path now defaults to /readyz

The `worker` deployment readiness probe HTTP path default has changed from `/ready` to `/readyz`. The liveness probe default path remains `/health`.

| Probe | v2.2.x default | v2.3.x default |
|-------|----------------|----------------|
| `worker.readinessProbe.path` | `/ready` (hardcoded) | `/readyz` |
| `worker.livenessProbe.path` | `/health` (hardcoded) | `/health` |

Rendered probe block in v2.3.x:

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: <worker.configmap.HEALTH_PORT | default 4006>
livenessProbe:
  httpGet:
    path: /health
    port: <worker.configmap.HEALTH_PORT | default 4006>
```

### 3. Manager and worker probe paths are now configurable

Both manager and worker deployments now read the probe `path` from `values.yaml`, alongside the timing fields that were already configurable. No new top-level keys are introduced; the existing `manager.readinessProbe`, `manager.livenessProbe`, `worker.readinessProbe`, and `worker.livenessProbe` blocks now also accept `path`.

| Key | v2.2.x | v2.3.x |
|-----|--------|--------|
| `manager.readinessProbe.path` | not honored (hardcoded `/health`) | overridable, defaults to `/readyz` |
| `manager.livenessProbe.path` | not honored (hardcoded `/health`) | overridable, defaults to `/health` |
| `worker.readinessProbe.path` | not honored (hardcoded `/ready`) | overridable, defaults to `/readyz` |
| `worker.livenessProbe.path` | not honored (hardcoded `/health`) | overridable, defaults to `/health` |

Example override to keep prior behavior:

```yaml
manager:
  readinessProbe:
    path: /health
worker:
  readinessProbe:
    path: /ready
```

## Configuration Changes

No `values.yaml` keys were added, removed, or renamed. The change is in template defaults only. If your `values.yaml` does not pin probe paths, the readiness path will switch to `/readyz` automatically on upgrade.

| Setting | v2.2.x | v2.3.x | Notes |
|---------|--------|--------|-------|
| `manager.readinessProbe.path` (default) | `/health` (hardcoded) | `/readyz` | Override to `/health` if your image does not serve `/readyz` |
| `manager.livenessProbe.path` (default) | `/health` (hardcoded) | `/health` | Now overridable via values |
| `worker.readinessProbe.path` (default) | `/ready` (hardcoded) | `/readyz` | Override to `/ready` if your image does not serve `/readyz` |
| `worker.livenessProbe.path` (default) | `/health` (hardcoded) | `/health` | Now overridable via values |

## Migration Steps

This upgrade requires no mandatory values changes. The Helm upgrade will roll the manager and worker deployments and update probe paths.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Confirm that the deployed `reporter-manager` and `reporter-worker` images expose `/readyz`. If they do not, pin the prior paths in your values:

   ```yaml
   manager:
     readinessProbe:
       path: /health
   worker:
     readinessProbe:
       path: /ready
   ```

3. Run the upgrade command during a maintenance window.
4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

5. Check probe behavior for both components:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-manager | grep -A2 -E "Liveness|Readiness"
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-worker | grep -A2 -E "Liveness|Readiness"
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. If a new readiness path returns non-2xx, pods will not become Ready and the rollout will pause.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 2.3.0-beta.1 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 2.3.0-beta.1 -n <namespace>
```
