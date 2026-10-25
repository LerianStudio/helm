<!-- {% raw %} -->
# Helm Upgrade from v2.x to v3.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. PodDisruptionBudget minAvailable field removed](#1-poddisruptionbudget-minavailable-field-removed)
- **[Features](#features)**
  - [1. Improved boolean flag handling for TLS settings](#1-improved-boolean-flag-handling-for-tls-settings)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `2.1.4` to `3.0.0`. This major version bump removes the `minAvailable` field from the PodDisruptionBudget configuration and introduces improved boolean flag handling for TLS-related settings. The application version remains unchanged at `1.0.0`.

| Field | v2.1.4 | v3.0.0 |
|-------|--------|--------|
| Chart version | `2.1.4` | `3.0.0` |
| App version | `1.0.0` | `1.0.0` |

> **Important:** This release removes the `tracer.pdb.minAvailable` field. Operators who have explicitly set this value must migrate to `maxUnavailable` or remove the override before upgrading.

## Breaking Changes

### 1. PodDisruptionBudget minAvailable field removed

The `minAvailable` field has been removed from the PodDisruptionBudget configuration. The chart now uses only `maxUnavailable` to control pod disruption behavior.

| Setting | v2.1.4 | v3.0.0 |
|---------|--------|--------|
| `tracer.pdb.minAvailable` | `1` | removed |
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

The chart now prioritizes `maxUnavailable` as the primary disruption control mechanism. The template logic has been updated to:

1. Use `minAvailable` if explicitly set (for backward compatibility during migration)
2. Fall back to `maxUnavailable: 1` if `maxUnavailable` is not set or invalid
3. Use the configured `maxUnavailable` value otherwise

> **Warning:** If you have explicitly set `tracer.pdb.minAvailable` in your values file, you must migrate to `maxUnavailable` before upgrading. The `minAvailable` field is deprecated and will be completely removed in a future release.

**Migration scenarios:**

#### Option 1: Keep existing behavior with maxUnavailable

If your current configuration uses `minAvailable: 1` with a single replica or small replica count, the equivalent configuration is:

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
  replicas: 3
  pdb:
    enabled: true
    maxUnavailable: 1
```

This ensures at least 2 pods remain available during disruptions.

#### Option 3: Remove minAvailable override

If you have not customized the PDB configuration, no action is required. The chart will use the default `maxUnavailable: 1`.

> **Note:** The PodDisruptionBudget only affects voluntary disruptions (e.g., `kubectl drain`, cluster autoscaler). It does not prevent pod evictions due to node failures or resource pressure.

## Features

### 1. Improved boolean flag handling for TLS settings

The chart introduces a new helper template `tracer.flagDefaultTrue` to correctly handle boolean flags that default to `true`. This fixes an issue where explicitly setting a flag to `false` would be treated as empty and fall back to the default `true` value.

**Affected configuration keys:**

| Setting | v2.1.4 | v3.0.0 |
|---------|--------|--------|
| `tracer.configmap.ALLOW_INSECURE_TLS` | uses `default "true"` | uses `tracer.flagDefaultTrue` helper |
| `tracer.configmap.MULTI_TENANT_REDIS_TLS` | uses `default "true"` | uses `tracer.flagDefaultTrue` helper |

**Template change:**

**Before (v2.1.4):**

```yaml
data:
  ALLOW_INSECURE_TLS: {{ .Values.tracer.configmap.ALLOW_INSECURE_TLS | default "true" | quote }}
  # ... other fields ...
  MULTI_TENANT_REDIS_TLS: {{ .Values.tracer.configmap.MULTI_TENANT_REDIS_TLS | default "true" | quote }}
```

**After (v3.0.0):**

```yaml
data:
  ALLOW_INSECURE_TLS: {{ include "tracer.flagDefaultTrue" .Values.tracer.configmap.ALLOW_INSECURE_TLS | quote }}
  # ... other fields ...
  MULTI_TENANT_REDIS_TLS: {{ include "tracer.flagDefaultTrue" .Values.tracer.configmap.MULTI_TENANT_REDIS_TLS | quote }}
```

**New helper template:**

```yaml
{{/*
A flag that defaults to "true". Sprig `default` treats an explicit boolean false
as empty, so a bool is rendered as-is. Input: the value.
*/}}
{{- define "tracer.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

**Operational impact:**

This change fixes a bug where setting `ALLOW_INSECURE_TLS: false` or `MULTI_TENANT_REDIS_TLS: false` in your values file would be ignored and the flag would default to `"true"`. With v3.0.0, boolean `false` values are now correctly rendered.

**Before (v2.1.4) - bug:**

```yaml
tracer:
  configmap:
    ALLOW_INSECURE_TLS: false  # Incorrectly rendered as "true"
```

**After (v3.0.0) - fixed:**

```yaml
tracer:
  configmap:
    ALLOW_INSECURE_TLS: false  # Correctly rendered as "false"
```

> **Note:** If you have been working around this bug by setting the value as a string `"false"`, you can now use a boolean `false` directly. Both forms will work correctly in v3.0.0.

**Production configuration example:**

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
| `ALLOW_INSECURE_TLS` | `true` | When `false`, enforces TLS certificate validation for all outbound connections. Set to `false` in production. |
| `MULTI_TENANT_REDIS_TLS` | `true` | When `true`, uses TLS for Redis connections in multi-tenant mode. Set to `false` only for local development. |

**Example configuration:**

```yaml
tracer:
  configmap:
    ALLOW_INSECURE_TLS: false
    MULTI_TENANT_REDIS_TLS: true
```

## Migration Steps

This upgrade requires manual changes if you have customized the PodDisruptionBudget configuration.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Check your current values file for `tracer.pdb.minAvailable`:

   ```bash
   grep -A 5 "pdb:" your-values.yaml
   ```

3. If `minAvailable` is present, migrate to `maxUnavailable`:

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

4. If you have been working around the boolean flag bug by using string values, you can now use boolean values:

   **Before (workaround):**
   
   ```yaml
   tracer:
     configmap:
       ALLOW_INSECURE_TLS: "false"
   ```

   **After (native boolean):**
   
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

> **Important:** The removal of `minAvailable` is a breaking change. Ensure you have migrated to `maxUnavailable` before upgrading to avoid unexpected PDB behavior.

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
