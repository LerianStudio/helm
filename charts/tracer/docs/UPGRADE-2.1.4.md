# Helm Upgrade from v2.1.3 to v2.1.4

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. ConfigMap checksum annotation added to deployment](#1-configmap-checksum-annotation-added-to-deployment)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `2.1.3` to `2.1.4`. This patch version introduces a ConfigMap checksum annotation to the deployment pod template, ensuring pods are automatically restarted when ConfigMap values change. The application version remains unchanged at `1.0.0`.

| Field | v2.1.3 | v2.1.4 |
|-------|--------|--------|
| Chart version | `2.1.3` | `2.1.4` |
| App version | `1.0.0` | `1.0.0` |

## Fixes

### 1. ConfigMap checksum annotation added to deployment

The deployment pod template now includes a `checksum/config` annotation that tracks changes to the ConfigMap. This ensures pods are automatically rolled when ConfigMap values are updated during a Helm upgrade.

**Before (v2.1.3):**

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
        {{- with .Values.tracer.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
```

**After (v2.1.4):**

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.tracer.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
```

**Operational impact:**

Prior to this change, modifying ConfigMap values (e.g., `SERVER_PORT`, `ENV_NAME`, `ALLOW_INSECURE_TLS`) in a Helm upgrade would update the ConfigMap resource but would not trigger a pod restart. Running pods would continue using the old configuration until manually restarted or naturally rescheduled.

With the `checksum/config` annotation, any change to ConfigMap values will automatically trigger a rolling restart of the deployment, ensuring the new configuration is applied immediately.

> **Note:** The existing `checksum/secret` annotation already provided this behavior for secret changes. This fix extends the same mechanism to ConfigMap changes for consistency.

**Example scenario:**

If you upgrade from v2.1.3 to v2.1.4 and simultaneously change a ConfigMap value:

```yaml
tracer:
  configmap:
    ALLOW_INSECURE_TLS: "false"  # Changed from "true"
```

The deployment will perform a rolling restart automatically because the `checksum/config` annotation value will change, even if no other deployment fields are modified.

## Migration Steps

This upgrade does not require any configuration changes or manual intervention. The ConfigMap checksum annotation is added automatically by the chart template.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Apply the upgrade in a non-production environment first to observe the rolling restart behavior.

3. Run the upgrade command (see [Command to upgrade](#command-to-upgrade)).

4. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n tracer
   ```

5. Check the pod annotations to confirm the `checksum/config` annotation is present:

   ```bash
   kubectl get pod -n tracer -l app.kubernetes.io/name=tracer-helm -o jsonpath='{.items[0].metadata.annotations}' | jq
   ```

6. Verify service logs for any startup issues:

   ```bash
   kubectl logs -n tracer -l app.kubernetes.io/name=tracer-helm --tail=50
   ```

> **Note:** If you are upgrading without changing any ConfigMap or Secret values, the pods will still perform a rolling restart because the `checksum/config` annotation is being added for the first time. Subsequent upgrades will only trigger restarts when ConfigMap or Secret content actually changes.

## Preview changes before upgrading

```bash
helm diff upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.4 -n tracer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.4 -n tracer
```
