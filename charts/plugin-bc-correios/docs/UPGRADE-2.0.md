# Helm Upgrade from v1.x to v2.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Health probe configuration now customizable](#1-health-probe-configuration-now-customizable)
- **[Features](#features)**
  - [1. Application version bump to 1.2.0](#1-application-version-bump-to-120)
  - [2. br-spb-bc-correios sibling image tag pinned](#2-br-spb-bc-correios-sibling-image-tag-pinned)
  - [3. Configurable health probes](#3-configurable-health-probes)
- **[Configuration Reference](#configuration-reference)**
  - [Health Probe Settings](#health-probe-settings)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a major release that updates the application version of the BC Correios plugin to 1.2.0 and introduces configurable health probe settings. The chart version moves from 1.0.1 to 2.0.0. While the upgrade introduces new configuration options for health probes, the default behavior remains backward-compatible with v1.0.1. Operators who have not customized probe settings can upgrade without changes to their values files.

## Breaking Changes

### 1. Health probe configuration now customizable

The deployment template now renders health probe settings from `values.yaml` instead of using hardcoded values. While the defaults match the previous hardcoded behavior, this is a breaking change because:

- The template structure has changed to read probe configuration from values
- Operators who previously relied on the hardcoded probe timings must now ensure their values file includes the new probe configuration blocks if they want to customize them
- The `successThreshold` field is now explicitly configurable (previously implicitly 1)

**Before (v1.0.1):**

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 15
  periodSeconds: 20
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
startupProbe:
  httpGet:
    path: /health/live
    port: http
  failureThreshold: 30
  periodSeconds: 10
```

**After (v2.0.0):**

```yaml
livenessProbe:
  httpGet:
    path: {{ $component.livenessProbe.path | default "/health/live" }}
    port: http
  initialDelaySeconds: {{ $component.livenessProbe.initialDelaySeconds | default 15 }}
  periodSeconds: {{ $component.livenessProbe.periodSeconds | default 20 }}
  timeoutSeconds: {{ $component.livenessProbe.timeoutSeconds | default 5 }}
  successThreshold: {{ $component.livenessProbe.successThreshold | default 1 }}
  failureThreshold: {{ $component.livenessProbe.failureThreshold | default 3 }}
readinessProbe:
  httpGet:
    path: {{ $component.readinessProbe.path | default "/health/ready" }}
    port: http
  initialDelaySeconds: {{ $component.readinessProbe.initialDelaySeconds | default 5 }}
  periodSeconds: {{ $component.readinessProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ $component.readinessProbe.timeoutSeconds | default 5 }}
  successThreshold: {{ $component.readinessProbe.successThreshold | default 1 }}
  failureThreshold: {{ $component.readinessProbe.failureThreshold | default 3 }}
startupProbe:
  httpGet:
    path: {{ $component.startupProbe.path | default "/health/live" }}
    port: http
  initialDelaySeconds: {{ $component.startupProbe.initialDelaySeconds | default 0 }}
  periodSeconds: {{ $component.startupProbe.periodSeconds | default 10 }}
  timeoutSeconds: {{ $component.startupProbe.timeoutSeconds | default 1 }}
  successThreshold: {{ $component.startupProbe.successThreshold | default 1 }}
  failureThreshold: {{ $component.startupProbe.failureThreshold | default 30 }}
```

**Operational impact:**

- Pods will be recreated during the upgrade with the new probe configuration
- If you do not override probe settings in your values file, the rendered probes will use the defaults shown in the [Configuration Reference](#configuration-reference) section, which match the v1.0.1 hardcoded values
- If you need custom probe timings (e.g., longer startup windows for slow-starting environments), you can now configure them via values instead of forking the chart

> **Important:** The startup probe now includes an explicit `initialDelaySeconds: 0` and `timeoutSeconds: 1` in the defaults. In v1.0.1, these fields were omitted and Kubernetes used its own defaults (initialDelaySeconds: 0, timeoutSeconds: 1). The behavior is unchanged, but the values are now explicit.

## Features

### 1. Application version bump to 1.2.0

The chart now ships with `appVersion` `1.2.0`, replacing the previous `1.0.0`. The chart version itself moves from `1.0.1` to `2.0.0`.

| Component   | v1.0.1  | v2.0.0   |
|-------------|---------|----------|
| version     | 1.0.1   | 2.0.0    |
| appVersion  | 1.0.0   | 1.2.0    |

The `bc-correios.image.tag` value in `values.yaml` still defaults to the value rendered by the CI/CD pipeline through the existing `helm_values_key_mappings` declared in `values.yaml`:

```yaml
# helm_values_key_mappings: '{"plugin-bc-correios": "bc-correios"}'
```

If you set `bc-correios.image.tag` explicitly in your overrides, align it with the new `appVersion`:

```yaml
bc-correios:
  image:
    repository: lerianstudio/plugin-bc-correios
    tag: "1.2.0"
```

> **Note:** For application-level changes included in version 1.2.0, refer to the [plugin-bc-correios changelog](https://github.com/LerianStudio/plugin-bc-correios).

### 2. br-spb-bc-correios sibling image tag pinned

A new top-level `br-spb-bc-correios` block is added to `values.yaml`, pinning the image tag of the sibling SPB BC Correios component to `1.2.0`.

| Component                      | v1.0.1  | v2.0.0 |
|--------------------------------|---------|--------|
| br-spb-bc-correios.image.tag   | _unset_ | 1.2.0  |

```yaml
br-spb-bc-correios:
  image:
    tag: 1.2.0
```

If you already override this value, review your override against the new chart default. No other keys are introduced in this block.

### 3. Configurable health probes

Version 2.0.0 introduces full configurability for liveness, readiness, and startup probes. Previously, probe settings were hardcoded in the deployment template. Now, operators can customize probe paths, timings, and thresholds via `values.yaml`.

**New configuration blocks:**

```yaml
bc-correios:
  livenessProbe:
    path: "/health/live"
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  readinessProbe:
    path: "/health/ready"
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  startupProbe:
    path: "/health/live"
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 30
```

**Use cases:**

- **Slow-starting environments:** Increase `startupProbe.failureThreshold` or `periodSeconds` to allow more time for the application to become ready
- **Custom health endpoints:** Change `path` if your application exposes health checks at non-standard paths
- **Aggressive health checking:** Decrease `periodSeconds` or `failureThreshold` for faster detection of unhealthy pods

> **Note:** All probe settings include sensible defaults that match the v1.0.1 hardcoded behavior. You only need to override the specific fields you want to change.

## Configuration Reference

### Health Probe Settings

The following table describes all configurable health probe fields. Each probe type (liveness, readiness, startup) supports the same set of fields.

| Flag                  | Default (Liveness) | Default (Readiness) | Default (Startup) | Description |
|-----------------------|--------------------|---------------------|-------------------|-------------|
| `path`                | `/health/live`     | `/health/ready`     | `/health/live`    | HTTP path for the health check endpoint |
| `initialDelaySeconds` | `15`               | `5`                 | `0`               | Number of seconds after the container starts before the probe is initiated |
| `periodSeconds`       | `20`               | `10`                | `10`              | How often (in seconds) to perform the probe |
| `timeoutSeconds`      | `5`                | `5`                 | `1`               | Number of seconds after which the probe times out |
| `successThreshold`    | `1`                | `1`                 | `1`               | Minimum consecutive successes for the probe to be considered successful |
| `failureThreshold`    | `3`                | `3`                 | `30`              | Number of consecutive failures before the probe is considered failed |

**Complete YAML example with all probe settings:**

```yaml
bc-correios:
  livenessProbe:
    path: "/health/live"
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  readinessProbe:
    path: "/health/ready"
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  startupProbe:
    path: "/health/live"
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 30
```

**Example: Increase startup probe timeout for slow environments:**

```yaml
bc-correios:
  startupProbe:
    failureThreshold: 60
    periodSeconds: 10
```

This configuration allows up to 10 minutes (60 failures × 10 seconds) for the application to start before Kubernetes marks the pod as failed.

## Migration Steps

This upgrade requires no mandatory manual migration steps if you are using default probe settings. The Helm upgrade will roll the pods with the new image tags and probe configuration.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))

2. If you have custom probe requirements (e.g., longer startup windows, custom health endpoints), add the appropriate probe configuration to your values file before upgrading:

```yaml
bc-correios:
  startupProbe:
    failureThreshold: 60  # Example: allow 10 minutes for startup
```

3. Ensure you have a recent backup of your data (if using chart-managed databases)

4. Run the upgrade command during a maintenance window

5. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

6. Check service logs for any startup issues:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-bc-correios-helm --tail=50
```

7. Verify health probe endpoints are responding correctly:

```bash
kubectl exec -n <namespace> -it <pod-name> -- wget -qO- http://localhost:8080/health/live
kubectl exec -n <namespace> -it <pod-name> -- wget -qO- http://localhost:8080/health/ready
```

> **Warning:** The upgrade will trigger a rolling restart of the BC Correios pods. Depending on your replica count and readiness probe configuration, this may cause brief service interruptions. Plan the upgrade during a maintenance window if you run a single replica.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 2.0.0 -n plugin-bc-correios
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 2.0.0 -n plugin-bc-correios
```
