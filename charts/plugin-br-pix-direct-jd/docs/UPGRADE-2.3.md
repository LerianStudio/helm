# Helm Upgrade from v2.2.x to v2.3.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Configurable readiness and liveness probes](#1-configurable-readiness-and-liveness-probes)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-pix-direct-jd` chart upgrade from `2.2.11` to `2.3.0-beta.1`. The application version remains `1.2.1-beta.11`. The chart minor bump exposes the previously hard-coded readiness and liveness probe settings on the deployment as values overrides. All existing defaults are preserved, so deployments that do not set `pix.readinessProbe` or `pix.livenessProbe` get the same probe behavior as v2.2.x.

No breaking changes. The expected path is an in-place Helm upgrade.

## Features

### 1. Configurable readiness and liveness probes

The deployment template now reads probe configuration from `pix.readinessProbe` and `pix.livenessProbe`. Every probe field (`path`, `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `successThreshold`, `failureThreshold`) falls back to the previous hard-coded default when not provided, so existing values files remain valid.

| Probe | Field | Previous (hard-coded, v2.2.x) | Default in v2.3.0-beta.1 |
|-------|-------|-------------------------------|--------------------------|
| readiness | `path` | `/readyz` | `/readyz` |
| readiness | `initialDelaySeconds` | `10` | `10` |
| readiness | `periodSeconds` | `5` | `5` |
| readiness | `timeoutSeconds` | (k8s default `1`) | `1` |
| readiness | `successThreshold` | (k8s default `1`) | `1` |
| readiness | `failureThreshold` | (k8s default `3`) | `3` |
| liveness | `path` | `/v1/health` | `/v1/health` |
| liveness | `initialDelaySeconds` | `5` | `5` |
| liveness | `periodSeconds` | `5` | `5` |
| liveness | `timeoutSeconds` | (k8s default `1`) | `1` |
| liveness | `successThreshold` | (k8s default `1`) | `1` |
| liveness | `failureThreshold` | (k8s default `3`) | `3` |

`values.yaml` now exposes the two empty maps:

```yaml
pix:
  # -- Readiness probe configuration. All fields override chart defaults.
  readinessProbe: {}
  # -- Liveness probe configuration. All fields override chart defaults.
  livenessProbe: {}
```

Override example:

```yaml
pix:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 15
    periodSeconds: 10
    failureThreshold: 5
  livenessProbe:
    path: /v1/health
    initialDelaySeconds: 20
    periodSeconds: 10
```

The deployment template now references each field with a default, so partial overrides are safe:

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

## Configuration Changes

| Setting | v2.2.x | v2.3.0-beta.1 |
|---------|--------|---------------|
| `pix.readinessProbe` | n/a (hard-coded) | `{}` (overrides chart defaults) |
| `pix.livenessProbe` | n/a (hard-coded) | `{}` (overrides chart defaults) |
| Image tag (`appVersion`) | `1.2.1-beta.11` | `1.2.1-beta.11` |

No other values were added, removed, or renamed. No image, env, secret, ingress, service, port, replica, or autoscaling defaults were modified.

## Migration Steps

1. Read this guide and confirm your values overlay does not already define `pix.readinessProbe` or `pix.livenessProbe` with conflicting types. If you previously used a forked or patched chart that exposed these keys with a different shape, reconcile them to the structure in the snippet above.
2. (Optional) Add `pix.readinessProbe` and/or `pix.livenessProbe` overrides if your environment needs different timing than the defaults.
3. Render the chart locally with your production values and review the manifest diff to confirm probe behavior is unchanged when no overrides are set.
4. Preview the rendered diff with the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
5. Apply the upgrade. Because the default probe behavior is preserved, no pod restarts beyond the routine rolling update are expected.

```bash
kubectl get pods -n <namespace>
```

6. Verify probes are healthy after the rollout:

```bash
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=plugin-br-pix-direct-jd-helm | grep -E "Liveness|Readiness"
```

> **Note:** The upgrade triggers a rolling restart of the plugin pods. With the default probe timings, pod readiness should be reached within seconds.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.3.0-beta.1 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-direct-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-direct-jd-helm --version 2.3.0-beta.1 -n <namespace>
```
