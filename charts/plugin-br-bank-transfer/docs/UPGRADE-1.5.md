# Helm Upgrade from v1.4.x to v1.5.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Parameterized liveness and readiness probes](#1-parameterized-liveness-and-readiness-probes)
  - [2. Default readiness probe path moved to /readyz](#2-default-readiness-probe-path-moved-to-readyz)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This release moves the bank-transfer pod probes from hardcoded values to fully configurable Helm values, and aligns the default readiness probe path with the `/readyz` convention used by other Lerian charts. The application image is unchanged.

## Features

### 1. Parameterized liveness and readiness probes

The `bankTransfer` deployment template now reads every probe field from `values.yaml` instead of hardcoding them. Two new top-level keys are added with empty defaults so existing installations behave the same unless explicitly overridden:

```yaml
bankTransfer:
  # -- Readiness probe configuration. All fields override chart defaults.
  readinessProbe: {}
  # -- Liveness probe configuration. All fields override chart defaults.
  livenessProbe: {}
```

The following fields are now overridable on both probes:

| Field                 | Liveness default | Readiness default |
|-----------------------|------------------|-------------------|
| `path`                | `/health/live`   | `/readyz`         |
| `initialDelaySeconds` | 15               | 5                 |
| `periodSeconds`       | 20               | 10                |
| `timeoutSeconds`      | 5                | 5                 |
| `successThreshold`    | 1                | 1                 |
| `failureThreshold`    | 3                | 3                 |

Example override:

```yaml
bankTransfer:
  livenessProbe:
    path: /health/live
    initialDelaySeconds: 30
    failureThreshold: 5
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 10
```

### 2. Default readiness probe path moved to /readyz

The hardcoded readiness probe path `/health/ready` is replaced by a configurable value whose default is now `/readyz`.

| Component                       | v1.4.0          | v1.5.0-beta.1 |
|---------------------------------|-----------------|---------------|
| readiness probe path (default)  | /health/ready   | /readyz       |
| liveness probe path (default)   | /health/live    | /health/live  |

If your application image already exposes `/readyz`, no action is required. If it only exposes `/health/ready`, set the readiness path back explicitly so the existing endpoint keeps being probed:

```yaml
bankTransfer:
  readinessProbe:
    path: /health/ready
```

> **Note:** This change only affects how Kubernetes probes the pod. It does not change the application binary, ports, or any environment variable.

## Configuration Changes

The following table summarizes the value changes:

| Setting                                          | v1.4.0          | v1.5.0-beta.1 |
|--------------------------------------------------|-----------------|---------------|
| Chart `version`                                  | 1.4.0           | 1.5.0-beta.1  |
| Chart `appVersion`                               | 2.4.0           | 2.4.0         |
| `bankTransfer.livenessProbe`                     | _hardcoded_     | `{}` (overridable) |
| `bankTransfer.readinessProbe`                    | _hardcoded_     | `{}` (overridable) |
| readiness probe path (default)                   | `/health/ready` | `/readyz`     |
| liveness probe path (default)                    | `/health/live`  | `/health/live` |

No keys are removed or renamed. All previous `values.yaml` overrides remain valid; the new probe blocks are additive and default to empty.

## Migration Steps

This upgrade requires no manual migration of persistent data. The Helm upgrade will trigger a rolling restart of the bank-transfer deployment with the new probe configuration.

**Recommended upgrade process:**

1. Confirm whether your application image exposes `/readyz`. If it does not, plan to set `bankTransfer.readinessProbe.path` to `/health/ready` (or whatever your image actually serves) in your overrides before upgrading.
2. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))
3. Ensure you have a recent backup of your data (if using chart-managed databases)
4. Run the upgrade command during a maintenance window
5. Verify all pods are running and healthy after the upgrade

```bash
kubectl get pods -n <namespace>
```

6. Check service logs for any startup or probe failures

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-br-bank-transfer-helm --tail=50
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=plugin-br-bank-transfer-helm | grep -E "Liveness|Readiness"
```

> **Note:** The upgrade will trigger a rolling restart of the bank-transfer pods. Depending on your replica count and readiness probe configuration, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.5.0-beta.1 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.5.0-beta.1 -n <namespace>
```
