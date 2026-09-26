# Helm Upgrade from v2.1.1 to v2.1.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Pod restart on secret changes](#1-pod-restart-on-secret-changes)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `2.1.1` to `2.1.2`. This patch release adds automatic pod restart detection when secrets change. The application version remains unchanged at `1.0.0`.

| Field | v2.1.1 | v2.1.2 |
|-------|--------|--------|
| Chart version | `2.1.1` | `2.1.2` |
| App version | `1.0.0` | `1.0.0` |

## Fixes

### 1. Pod restart on secret changes

A checksum annotation has been added to the pod template to ensure pods are automatically restarted when the `secrets.yaml` content changes. Previously, updating secret values required manual pod deletion or rollout restart.

**Before (v2.1.1):**

```yaml
template:
  metadata:
    {{- with .Values.tracer.podAnnotations }}
    annotations:
      {{- toYaml . | nindent 8 }}
    {{- end }}
    labels:
      {{- include "tracer.labels" (dict "context" . "component" .Values.tracer.name "name" .Values.tracer.name) | nindent 8 }}
```

**After (v2.1.2):**

```yaml
template:
  metadata:
    annotations:
      checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
      {{- with .Values.tracer.podAnnotations }}
      {{- toYaml . | nindent 8 }}
      {{- end }}
    labels:
      {{- include "tracer.labels" (dict "context" . "component" .Values.tracer.name "name" .Values.tracer.name) | nindent 8 }}
```

**Operational impact:**

The `checksum/secret` annotation computes a SHA256 hash of the rendered `secrets.yaml` template. When any value under `tracer.secrets` changes (e.g., `DB_PASSWORD`, `API_KEY`, `MULTI_TENANT_SERVICE_API_KEY`), the checksum changes and Kubernetes triggers a rolling restart of the tracer pods.

**Behavior change:**

| Scenario | v2.1.1 | v2.1.2 |
|----------|--------|--------|
| Update `tracer.secrets.DB_PASSWORD` via `helm upgrade` | Pods continue running with old secret values | Pods automatically restart and pick up new secret values |
| Manual intervention required after secret change | Yes (kubectl rollout restart) | No (automatic) |

> **Note:** The annotation block is now always present, even if `tracer.podAnnotations` is empty. Custom annotations defined in `tracer.podAnnotations` are merged below the checksum annotation.

**Example scenario:**

If you update a secret value in your values file:

```yaml
tracer:
  secrets:
    DB_PASSWORD: "new-secure-password"
```

And run:

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.2 -n tracer -f your-values.yaml
```

The pods will automatically restart to load the new password. In v2.1.1, you would need to manually restart the pods after the upgrade:

```bash
kubectl rollout restart deployment/tracer -n tracer
```

This manual step is no longer required in v2.1.2.

## Migration Steps

This upgrade is fully backward-compatible and requires no configuration changes.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Apply the upgrade in a non-production environment first to observe the automatic restart behavior.

3. Run the upgrade command (see [Command to upgrade](#command-to-upgrade)).

4. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n tracer
   ```

5. Check service logs for any startup issues:

   ```bash
   kubectl logs -n tracer -l app.kubernetes.io/name=tracer-helm --tail=50
   ```

> **Note:** The first upgrade to v2.1.2 will trigger a rolling restart of all tracer pods due to the new checksum annotation being added. Subsequent upgrades will only restart pods if secret values actually change.

## Preview changes before upgrading

```bash
helm diff upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.2 -n tracer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.2 -n tracer
```
