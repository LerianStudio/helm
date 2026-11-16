<!-- {% raw %} -->
# Helm Upgrade from v2.x to v3.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. PodDisruptionBudget default no longer sets minAvailable](#1-poddisruptionbudget-default-no-longer-sets-minavailable)
- **[Features](#features)**
  - [1. Boolean flag handling for TLS settings](#1-boolean-flag-handling-for-tls-settings)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `2.1.4` to `3.0.0`. This major version bump changes the default PodDisruptionBudget values (the chart no longer sets `minAvailable` by default) and accepts boolean values for TLS-related settings. The application version remains unchanged at `1.0.0`.

| Field | v2.1.4 | v3.0.0 |
|-------|--------|--------|
| Chart version | `2.1.4` | `3.0.0` |
| App version | `1.0.0` | `1.0.0` |

> **Important:** The chart default for `tracer.pdb.minAvailable` is removed. `minAvailable` is still honored when you set it, and takes precedence over `maxUnavailable`. If you set it explicitly, no migration is required.

## Breaking Changes

### 1. PodDisruptionBudget default no longer sets minAvailable

The chart default values no longer include `minAvailable`. By default the PodDisruptionBudget now uses only `maxUnavailable`. If you set `tracer.pdb.minAvailable` in your values file, the chart still renders it.

| Setting | v2.1.4 default | v3.0.0 default |
|---------|----------------|----------------|
| `tracer.pdb.minAvailable` | `1` | not set |
| `tracer.pdb.maxUnavailable` | `1` | `1` |

**Before (v2.1.4):**

```yaml
tracer:
  pdb:
    enabled: true
    # -- Minimum number of available pods
    minAvailable: 1
    # -- Maximum number of unavailable pods
    maxUnavailable: 1
    annotations: {}
```

**After (v3.0.0):**

```yaml
tracer:
  pdb:
    enabled: true
    # -- Maximum number of unavailable pods; ignored when minAvailable is set.
    maxUnavailable: 1
    annotations: {}
```

**Template change:**

**Before (v2.1.4):**

```yaml
spec:
  {{- if .Values.tracer.pdb.minAvailable }}
  minAvailable: {{ .Values.tracer.pdb.minAvailable }}
  {{- end }}
  {{- if .Values.tracer.pdb.maxUnavailable }}
  maxUnavailable: {{ .Values.tracer.pdb.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "tracer.selectorLabels" (dict "context" . "name" .Values.tracer.name) | nindent 6 }}
```

**After (v3.0.0):**

```yaml
spec:
  {{- if .Values.tracer.pdb.minAvailable }}
  minAvailable: {{ .Values.tracer.pdb.minAvailable }}
  {{- else if kindIs "invalid" .Values.tracer.pdb.maxUnavailable }}
  maxUnavailable: 1
  {{- else }}
  maxUnavailable: {{ .Values.tracer.pdb.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "tracer.selectorLabels" (dict "context" . "name" .Values.tracer.name) | nindent 6 }}
```

**Operational impact:**

The template logic is:

1. Use `minAvailable` if it is set.
2. Otherwise, use `maxUnavailable: 1` if `maxUnavailable` is not set.
3. Otherwise, use the configured `maxUnavailable` value.

> **Note:** Because `minAvailable` takes precedence, a values file that still sets it keeps its current PodDisruptionBudget. To use `maxUnavailable` instead, remove `minAvailable` from your values file.

**Options:**

#### Option 1: Use maxUnavailable instead of minAvailable

To switch from `minAvailable` to `maxUnavailable`, remove `minAvailable` from your values file and set:

```yaml
tracer:
  pdb:
    enabled: true
    maxUnavailable: 1
```

This allows one pod to be unavailable during disruptions (e.g., node drains, upgrades).

#### Option 2: Tighter disruption control for high-availability deployments

For deployments with multiple replicas where you want to ensure a minimum number of pods remain available:

```yaml
tracer:
  replicaCount: 3
  pdb:
    enabled: true
    maxUnavailable: 1
```

This ensures at least 2 pods remain available during disruptions.

#### Option 3: Keep the chart default

If you have not customized the PDB configuration, no action is required. The chart will use the default `maxUnavailable: 1`.

> **Note:** The PodDisruptionBudget only affects voluntary disruptions (e.g., `kubectl drain`, cluster autoscaler). It does not prevent pod evictions due to node failures or resource pressure.

## Features

### 1. Boolean flag handling for TLS settings

The chart renders both flags with the `tracer.flagDefaultTrue` helper. Each defaults to `true`; an explicit boolean `false` in your values file renders as `"false"`.

**Affected configuration keys:**

| Setting | v3.0.0 |
|---------|--------|
| `tracer.configmap.ALLOW_INSECURE_TLS` | uses `tracer.flagDefaultTrue` helper |
| `tracer.configmap.MULTI_TENANT_REDIS_TLS` | uses `tracer.flagDefaultTrue` helper |

**Operational impact:**

To set either flag to `false`, use boolean `false` or the string `"false"`. Both forms render `"false"`.

**Example configuration:**

```yaml
tracer:
  configmap:
    ALLOW_INSECURE_TLS: false
    MULTI_TENANT_REDIS_TLS: true
```

## Configuration Reference

### PodDisruptionBudget Configuration

| Field | Default | Description |
|-------|---------|-------------|
| `tracer.pdb.enabled` | `true` | Enable or disable PodDisruptionBudget. |
| `tracer.pdb.maxUnavailable` | `1` | Maximum number of unavailable pods during voluntary disruptions. |
| `tracer.pdb.annotations` | `{}` | Annotations for the PodDisruptionBudget resource. |

**Example configuration:**

```yaml
tracer:
  pdb:
    enabled: true
    maxUnavailable: 1
    annotations:
      description: "Tracer service disruption budget"
```

### Boolean Flag Configuration

| Flag | Default | Description |
|------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `true` | Passed to the application as `ALLOW_INSECURE_TLS`. |
| `MULTI_TENANT_REDIS_TLS` | `true` | When `true`, uses TLS for Redis connections in multi-tenant mode. Set to `false` only for local development. |

**Example configuration:**

```yaml
tracer:
  configmap:
    ALLOW_INSECURE_TLS: false
    MULTI_TENANT_REDIS_TLS: true
```

## Migration Steps

This upgrade needs no mandatory changes. Review your PodDisruptionBudget configuration if you want to use `maxUnavailable` instead of `minAvailable`.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Check your current values file for `tracer.pdb.minAvailable`:

   ```bash
   grep -A 5 "pdb:" your-values.yaml
   ```

3. If `minAvailable` is present and you want `maxUnavailable` instead, migrate. `minAvailable` takes precedence while it is set:

   **Remove:**
   
   ```yaml
   tracer:
     pdb:
       minAvailable: 1
       maxUnavailable: 1
   ```

   **Replace with:**
   
   ```yaml
   tracer:
     pdb:
       maxUnavailable: 1
   ```

4. To set a TLS flag to `false`, use boolean `false` or the string `"false"`:

   ```yaml
   tracer:
     configmap:
       ALLOW_INSECURE_TLS: false
   ```

5. Render the chart locally with your production values and review the manifest diff:

   ```bash
   helm template tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 3.0.0 -n tracer -f your-values.yaml > /tmp/tracer-3.0.0.yaml
   ```

6. Apply the upgrade in a non-production environment first to validate the configuration.

7. Verify the PodDisruptionBudget is correctly configured after upgrade:

   ```bash
   kubectl get pdb -n tracer -o yaml
   ```

8. Verify all pods are running and healthy:

   ```bash
   kubectl get pods -n tracer
   ```

9. Check service logs for any startup issues:

   ```bash
   kubectl logs -n tracer -l app.kubernetes.io/name=tracer-helm --tail=50
   ```

## Preview changes before upgrading

```bash
helm diff upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 3.0.0 -n tracer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 3.0.0 -n tracer
```
<!-- {% endraw %} -->
