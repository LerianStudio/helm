# Helm Upgrade from v2.2.x to v2.3.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Configurable liveness and readiness probes](#1-configurable-liveness-and-readiness-probes)
  - [2. Readiness probe default path changes to `/readyz`](#2-readiness-probe-default-path-changes-to-readyz)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `matcher` chart upgrade from `2.2.0` to `2.3.0-beta.2`. It is a minor maintenance release that promotes the previously hard-coded liveness/readiness probe fields to configurable values. The application image (`appVersion: 1.0.0`) is unchanged.

The only behavioral change for users who do not override probe values is the readiness probe path, which moves from `/health` to `/readyz`. See [Migration Steps](#migration-steps) before upgrading.

## Features

### 1. Configurable liveness and readiness probes

`matcher.livenessProbe` and `matcher.readinessProbe` are now empty maps in `values.yaml`, ready to receive overrides for any probe field. Every field on the probe is now templated with a default that matches the previous hard-coded value, except for the readiness path (see next feature).

```yaml
matcher:
  livenessProbe: {}     # all fields fall back to chart defaults
  readinessProbe: {}    # all fields fall back to chart defaults
```

Defaults applied when unset:

| Probe | Field | Default |
|-------|-------|---------|
| Liveness | `path` | `/health` |
| Liveness | `initialDelaySeconds` | `15` |
| Liveness | `periodSeconds` | `20` |
| Liveness | `timeoutSeconds` | `5` |
| Liveness | `successThreshold` | `1` |
| Liveness | `failureThreshold` | `3` |
| Readiness | `path` | `/readyz` |
| Readiness | `initialDelaySeconds` | `5` |
| Readiness | `periodSeconds` | `10` |
| Readiness | `timeoutSeconds` | `5` |
| Readiness | `successThreshold` | `1` |
| Readiness | `failureThreshold` | `3` |

`successThreshold` is newly exposed; v2.2.0 inherited the Kubernetes implicit default (`1`), so behavior is unchanged when the value is omitted.

### 2. Readiness probe default path changes to `/readyz`

| Probe | v2.2.0 path | v2.3.0-beta.2 default |
|-------|-------------|------------------------|
| Liveness | `/health` | `/health` |
| Readiness | `/health` | `/readyz` |

> **Note:** If your `matcher` image still serves readiness on `/health`, pin it explicitly before upgrading:
>
> ```yaml
> matcher:
>   readinessProbe:
>     path: /health
> ```

## Configuration Changes

| Setting | v2.2.0 | v2.3.0-beta.2 |
|---------|--------|---------------|
| `matcher.livenessProbe` | (not exposed; hard-coded in template) | `{}` (override any field) |
| `matcher.readinessProbe` | (not exposed; hard-coded in template) | `{}` (override any field) |
| Readiness probe default path | `/health` | `/readyz` |

Files modified between `2.2.0` and `2.3.0-beta.2`:

- `charts/matcher/Chart.yaml`
- `charts/matcher/values.yaml`
- `charts/matcher/templates/deployment.yaml`

## Migration Steps

1. **Confirm which path your `matcher` image serves readiness on.** If it is `/health`, pin `matcher.readinessProbe.path: /health` in your values. If your image already supports `/readyz`, no action is needed.
2. Review the rendered diff using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
3. Run the upgrade and verify the rollout:

```bash
kubectl rollout status -n matcher deploy/matcher
kubectl get pods -n matcher
```

4. Watch for readiness flapping after rollout:

```bash
kubectl describe pod -n matcher -l app.kubernetes.io/name=matcher | grep -A2 Readiness
```

> **Note:** A readiness probe pointing at a path the application does not serve will keep pods out of the Service endpoints. Verify the readiness path before upgrading in production.

## Preview changes before upgrading

```bash
helm diff upgrade matcher oci://registry-1.docker.io/lerianstudio/matcher-helm --version 2.3.0-beta.2 -n matcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade matcher oci://registry-1.docker.io/lerianstudio/matcher-helm --version 2.3.0-beta.2 -n matcher
```
