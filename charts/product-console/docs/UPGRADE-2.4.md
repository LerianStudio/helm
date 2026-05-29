# Helm Upgrade from v2.3.x to v2.4.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Configurable liveness and readiness probes](#1-configurable-liveness-and-readiness-probes)
  - [2. Default readiness path changed to /readyz](#2-default-readiness-path-changed-to-readyz)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor maintenance release that exposes the deployment liveness and readiness probes through `values.yaml` and updates the default readiness path. The application version is unchanged.

| Field | v2.3.x | v2.4.x |
|-------|--------|--------|
| Chart version | `2.3.1-beta.1` | `2.4.0-beta.1` |
| App version | `1.6.0` | `1.6.0` |

## Features

### 1. Configurable liveness and readiness probes

The deployment template now reads probe settings from `values.yaml` instead of using hardcoded values. Two new top-level keys are introduced, both defaulting to `{}` so existing installations keep the same behavior unless overridden.

| Key | v2.3.x | v2.4.x |
|-----|--------|--------|
| `livenessProbe` | not present (hardcoded in template) | `{}` (overridable) |
| `readinessProbe` | not present (hardcoded in template) | `{}` (overridable) |

Each probe block now supports `path`, `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `successThreshold`, and `failureThreshold`. Built-in defaults preserve the prior values for liveness and the prior numeric values for readiness:

```yaml
# Built-in defaults applied when fields are omitted
livenessProbe:
  path: /
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  path: /readyz
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
```

Example override:

```yaml
livenessProbe:
  initialDelaySeconds: 45
  failureThreshold: 5
readinessProbe:
  path: /healthz
  periodSeconds: 10
```

### 2. Default readiness path changed to /readyz

The readiness probe HTTP path default has changed from `/` to `/readyz`. The liveness probe default path remains `/`.

| Probe | v2.3.x default | v2.4.x default |
|-------|----------------|----------------|
| `livenessProbe.path` | `/` | `/` |
| `readinessProbe.path` | `/` | `/readyz` |

If the `product-console` application image you deploy does not yet expose `/readyz`, override the path back to `/` in your values:

```yaml
readinessProbe:
  path: /
```

> **Note:** The previous template also did not set `successThreshold`. With v2.4.x, `successThreshold: 1` is now rendered explicitly for both probes, matching Kubernetes defaults.

## Configuration Changes

No existing keys were removed or renamed. The `livenessProbe` and `readinessProbe` blocks are additive and default to `{}`.

| Setting | v2.3.x | v2.4.x | Notes |
|---------|--------|--------|-------|
| `livenessProbe` | absent | `{}` | New, optional, overrides built-in defaults |
| `readinessProbe` | absent | `{}` | New, optional, overrides built-in defaults |
| `readinessProbe.path` (default) | `/` (hardcoded) | `/readyz` | Override to `/` if your app does not serve `/readyz` |

## Migration Steps

This upgrade requires no mandatory values changes. The Helm upgrade will roll the deployment and update probe paths.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. If your image does not expose `/readyz`, set `readinessProbe.path: /` in your values before upgrading.
3. Run the upgrade command during a maintenance window.
4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

5. Check service logs for any startup or probe failures:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=product-console --tail=50
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=product-console | grep -A2 -E "Liveness|Readiness"
```

> **Note:** The upgrade triggers a rolling restart of the `product-console` deployment. If the new readiness path returns non-2xx, pods will not become Ready and the rollout will pause.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 2.4.0-beta.1 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 2.4.0-beta.1 -n <namespace>
```
