# Helm Upgrade from v2.3.x to v2.4.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Parametrized readiness and liveness probes](#1-parametrized-readiness-and-liveness-probes)
  - [2. Default readiness path moved to /readyz](#2-default-readiness-path-moved-to-readyz)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that parametrizes the readiness and liveness probes for every component in the `plugin-br-pix-indirect-btg` chart (`pix`, `inbound`, `outbound`, `reconciliation`). The application version remains `1.5.2` and no values are removed or renamed, so existing custom values keep working without changes.

The expected upgrade path is an in-place Helm upgrade after reviewing the new probe defaults.

## Features

### 1. Parametrized readiness and liveness probes

Each component deployment now reads probe configuration from values, with fallbacks that match the previous hardcoded behavior. All four components gained `readinessProbe` and `livenessProbe` blocks under their root key.

| Component | Values block added |
|-----------|--------------------|
| `pix` | `pix.readinessProbe`, `pix.livenessProbe` |
| `inbound` | `inbound.readinessProbe`, `inbound.livenessProbe` |
| `outbound` | `outbound.readinessProbe`, `outbound.livenessProbe` |
| `reconciliation` | `reconciliation.readinessProbe`, `reconciliation.livenessProbe` |

Each probe block accepts the standard fields and falls back to the chart defaults when left empty:

```yaml
pix:
  readinessProbe: {}
  # path:                "/readyz"
  # initialDelaySeconds: 10
  # periodSeconds:       5
  # timeoutSeconds:      1
  # successThreshold:    1
  # failureThreshold:    3
  livenessProbe: {}
  # path:                "/health"
  # initialDelaySeconds: 5
  # periodSeconds:       5
  # timeoutSeconds:      1
  # successThreshold:    1
  # failureThreshold:    3
```

Operators can now tune `timeoutSeconds`, `successThreshold`, and `failureThreshold` per component without forking the chart.

### 2. Default readiness path moved to /readyz

The default readiness probe path changed from `/health` to `/readyz` to align with the platform-wide health endpoint convention. The default liveness probe path stays at `/health`.

| Component | v2.3.x readiness | v2.4.x readiness | v2.3.x liveness | v2.4.x liveness |
|-----------|------------------|------------------|-----------------|-----------------|
| `pix` | `/health` | `/readyz` | `/health` | `/health` |
| `inbound` | `/health` | `/readyz` | `/health` | `/health` |
| `outbound` | `/health` | `/readyz` | `/health` | `/health` |
| `reconciliation` | `/health` | `/readyz` | `/health` | `/health` |

If your application image still serves only `/health`, override the readiness path back to `/health` per component:

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

> **Note:** The application image tag (`appVersion`) is unchanged at `1.5.2`. If your image already serves `/readyz`, no override is needed.

## Configuration Changes

No values are removed or renamed. The new probe blocks are additive and default to `{}`, which preserves the previous timing behavior.

The following table summarizes what changed:

| Setting | v2.3.x | v2.4.x |
|---------|--------|--------|
| Chart version | `2.3.0` | `2.4.0-beta.1` |
| App version | `1.5.2` | `1.5.2` |
| `<component>.readinessProbe` | (hardcoded `/health`, 10s/5s) | configurable, defaults to `/readyz`, 10s/5s/1s/1/3 |
| `<component>.livenessProbe` | (hardcoded `/health`, 5s/5s) | configurable, defaults to `/health`, 5s/5s/1s/1/3 |

## Migration Steps

This upgrade requires no destructive migration steps. The new probe defaults assume the application image serves `/readyz` for readiness; if it does not, override the readiness path back to `/health` for each component before upgrading.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Confirm whether your `1.5.2` application image serves `/readyz`. If it serves only `/health`, add per-component readiness overrides as shown in [Feature 2](#2-default-readiness-path-moved-to-readyz).
3. Run the upgrade command during a maintenance window.
4. Verify all pods are running and healthy after the upgrade.

```bash
kubectl get pods -n <namespace>
```

5. Check service logs for any readiness probe failures.

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
```

> **Note:** The upgrade triggers a rolling restart of the `pix`, `inbound`, `outbound`, and `reconciliation` deployments because the probe spec changes. Depending on your replica count and probe timing, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 2.4.0-beta.1 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 2.4.0-beta.1 -n <namespace>
```
