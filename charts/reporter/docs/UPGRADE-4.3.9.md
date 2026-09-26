# Helm Upgrade from v4.3.8 to v4.3.9

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Manager deployment now auto-restarts on Secret changes](#1-manager-deployment-now-auto-restarts-on-secret-changes)
  - [2. Worker deployment now auto-restarts on Secret changes](#2-worker-deployment-now-auto-restarts-on-secret-changes)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that adds automatic pod restart behavior when manager or worker Secrets are updated. The application version remains unchanged.

| Field | v4.3.8 | v4.3.9 |
|-------|--------|--------|
| Chart version | `4.3.8` | `4.3.9` |
| App version | `4.2.0` | `4.2.0` |

## Fixes

### 1. Manager deployment now auto-restarts on Secret changes

The manager deployment pod template now includes a `checksum/secret` annotation that triggers a rolling restart whenever the manager Secret (`reporter-manager`) is modified. This ensures that pods always run with the latest Secret values without requiring manual intervention.

**Before (v4.3.8):**

```yaml
metadata:
  labels:
    {{- include "plugin-manager.labels" (dict "context" . "name" .Values.manager.name ) | nindent 8 }}
  {{- with .Values.manager.podAnnotations }}
  annotations:
    {{- range $key, $value := . }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
```

**After (v4.3.9):**

```yaml
metadata:
  labels:
    {{- include "plugin-manager.labels" (dict "context" . "name" .Values.manager.name ) | nindent 8 }}
  annotations:
    checksum/secret: {{ include (print $.Template.BasePath "/manager/secrets.yaml") . | sha256sum }}
    {{- range $key, $value := .Values.manager.podAnnotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
```

The `checksum/secret` annotation is computed from the rendered manager Secret template. When the Secret content changes (e.g., via a `helm upgrade` with updated `secrets.*` values), the checksum changes, and Kubernetes triggers a rolling restart of the manager deployment.

| Annotation | v4.3.8 | v4.3.9 |
|------------|--------|--------|
| `checksum/secret` | not present | computed from `/manager/secrets.yaml` template |

> **Note:** Custom annotations defined in `manager.podAnnotations` are preserved and merged with the new checksum annotation. The `{{- with .Values.manager.podAnnotations }}` guard has been removed to ensure the `annotations:` block is always rendered, even when no custom annotations are set.

### 2. Worker deployment now auto-restarts on Secret changes

The worker deployment pod template now includes a `checksum/secret` annotation that triggers a rolling restart whenever the worker Secret (`reporter-worker`) is modified. This ensures that pods always run with the latest Secret values without requiring manual intervention.

**Before (v4.3.8):**

```yaml
metadata:
  labels:
    {{- include "plugin-worker.labels" (dict "context" . "name" .Values.worker.name ) | nindent 8 }}
  {{- with .Values.worker.podAnnotations }}
  annotations:
    {{- range $key, $value := . }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
```

**After (v4.3.9):**

```yaml
metadata:
  labels:
    {{- include "plugin-worker.labels" (dict "context" . "name" .Values.worker.name ) | nindent 8 }}
  annotations:
    checksum/secret: {{ include (print $.Template.BasePath "/worker/secrets.yaml") . | sha256sum }}
    {{- range $key, $value := .Values.worker.podAnnotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
```

The `checksum/secret` annotation is computed from the rendered worker Secret template. When the Secret content changes (e.g., via a `helm upgrade` with updated `secrets.*` values), the checksum changes, and Kubernetes triggers a rolling restart of the worker deployment.

| Annotation | v4.3.8 | v4.3.9 |
|------------|--------|--------|
| `checksum/secret` | not present | computed from `/worker/secrets.yaml` template |

> **Note:** Custom annotations defined in `worker.podAnnotations` are preserved and merged with the new checksum annotation. The `{{- with .Values.worker.podAnnotations }}` guard has been removed to ensure the `annotations:` block is always rendered, even when no custom annotations are set.

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will automatically add the checksum annotations to both manager and worker deployments and trigger a rolling restart.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

4. Verify the checksum annotations are present on both deployments:

```bash
kubectl get deployment -n <namespace> -l app.kubernetes.io/name=reporter-manager -o jsonpath='{.items[0].spec.template.metadata.annotations.checksum/secret}'
kubectl get deployment -n <namespace> -l app.kubernetes.io/name=reporter-worker -o jsonpath='{.items[0].spec.template.metadata.annotations.checksum/secret}'
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments due to the addition of the new checksum annotation. Future upgrades that modify Secret values will also trigger automatic restarts.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.9 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.9 -n reporter
```
