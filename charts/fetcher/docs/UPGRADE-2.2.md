# Helm Upgrade from v2.1.x to v2.2.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Configurable liveness and readiness probe paths](#1-configurable-liveness-and-readiness-probe-paths)
  - [2. New `successThreshold` knob on manager probes](#2-new-successthreshold-knob-on-manager-probes)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `2.1.1` to `2.2.0-beta.4`. It is a minor maintenance release that makes the `manager` Deployment probes more flexible without changing existing behavior for users who do not override the new knobs.

The application image (`appVersion: 1.3.0`) is unchanged. No breaking changes, no required `values.yaml` modifications, and no data migration are needed.

## Features

### 1. Configurable liveness and readiness probe paths

The `manager` Deployment previously hard-coded `/health` for both liveness and readiness probes. Both paths are now configurable via values, with backwards-compatible defaults:

| Probe | v2.1.1 path | v2.2.0-beta.4 default | Override key |
|-------|-------------|------------------------|--------------|
| Liveness | `/health` | `/health` | `manager.livenessProbe.path` |
| Readiness | `/health` | `/readyz` | `manager.readinessProbe.path` |

> **Note:** The readiness probe default changed from `/health` to `/readyz`. If your `fetcher-manager` image still serves readiness on `/health`, set `manager.readinessProbe.path: /health` explicitly before upgrading.

```yaml
manager:
  livenessProbe:
    path: /health
  readinessProbe:
    path: /readyz
```

### 2. New `successThreshold` knob on manager probes

Both probes now honor a `successThreshold` value. If omitted, it defaults to `1`, matching the previous implicit behavior.

```yaml
manager:
  livenessProbe:
    successThreshold: 1
  readinessProbe:
    successThreshold: 1
```

## Configuration Changes

No `values.yaml` keys were added or removed. All new knobs are optional and fall back to safe defaults.

| Setting | v2.1.1 | v2.2.0-beta.4 |
|---------|--------|---------------|
| `manager.livenessProbe.path` | (hard-coded `/health`) | optional, defaults to `/health` |
| `manager.readinessProbe.path` | (hard-coded `/health`) | optional, defaults to `/readyz` |
| `manager.livenessProbe.successThreshold` | (not exposed) | optional, defaults to `1` |
| `manager.readinessProbe.successThreshold` | (not exposed) | optional, defaults to `1` |

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will roll the `manager` Deployment with the new probe template.

**Recommended upgrade process:**

1. Confirm which path your `fetcher-manager` image serves readiness on. If it is `/health`, pin it explicitly: `manager.readinessProbe.path: /health`.
2. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
3. Run the upgrade command during a maintenance window.
4. Verify the manager pods are healthy after the upgrade:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager
```

5. Check manager logs for probe-related restarts:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
```

> **Note:** A readiness probe pointing at a path the application does not serve will keep pods out of the Service endpoints. Verify the readiness path before upgrading in production.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 2.2.0-beta.4 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 2.2.0-beta.4 -n fetcher
```
