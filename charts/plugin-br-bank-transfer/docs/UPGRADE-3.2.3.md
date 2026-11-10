<!-- {% raw %} -->
# Helm Upgrade from v3.2.2 to v3.2.3

## Topics

- **[Overview](#overview)**
- **[What Changed](#what-changed)**
  - [Automatic Pod Restart on Configuration Changes](#automatic-pod-restart-on-configuration-changes)
- **[Operational Impact](#operational-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.2.3 is a **patch release** that adds automatic pod restart behavior when ConfigMap or Secret data changes. This ensures that configuration updates trigger a rolling restart of the Deployment without requiring manual intervention. The change is **non-breaking** and requires no values file modifications.

## What Changed

### Automatic Pod Restart on Configuration Changes

**What changed:**  
The Deployment template now includes checksum annotations for the ConfigMap and Secret resources. When the content of either resource changes, the checksum annotation on the pod template changes, triggering a rolling restart of the Deployment.

**Template changes:**

**Deployment (templates/deployment.yaml):**

**Before (v3.2.2):**
```yaml
  template:
    metadata:
      {{- with .Values.bankTransfer.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "bank-transfer.labels" (dict "context" . "component" .Values.bankTransfer.name "name" .Values.bankTransfer.name "podTemplate" true) | nindent 8 }}
```

**After (v3.2.3):**
```yaml
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
        {{- with .Values.bankTransfer.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "bank-transfer.labels" (dict "context" . "component" .Values.bankTransfer.name "name" .Values.bankTransfer.name "podTemplate" true) | nindent 8 }}
```

**Why it matters:**  
Previously, when you updated configuration values in `bankTransfer.configmap` or `bankTransfer.secrets` and ran `helm upgrade`, the ConfigMap and Secret resources would update, but the running pods would continue using the old configuration until manually restarted. This created a gap between the desired configuration state and the running state.

With the checksum annotations, Helm automatically triggers a rolling restart whenever the ConfigMap or Secret content changes, ensuring that pods always run with the current configuration.

**How it works:**  
- The `checksum/config` annotation contains a SHA256 hash of the rendered ConfigMap template
- The `checksum/secret` annotation contains a SHA256 hash of the rendered Secret template
- When either template's content changes (because you changed a value in `bankTransfer.configmap` or `bankTransfer.secrets`), the corresponding checksum changes
- Kubernetes detects the pod template annotation change and performs a rolling restart according to the Deployment's `strategy` settings (default: `maxSurge: 25%`, `maxUnavailable: 0`)

**Annotation structure:**

After upgrade, your pods will have these annotations:

```yaml
metadata:
  annotations:
    checksum/config: "a1b2c3d4e5f6..."  # SHA256 of ConfigMap content
    checksum/secret: "f6e5d4c3b2a1..."  # SHA256 of Secret content
    # ... plus any custom annotations from bankTransfer.podAnnotations
```

## Operational Impact

**On upgrade to 3.2.3:**  
- The chart adds the checksum annotations to the Deployment's pod template
- This annotation change triggers a rolling restart of all pods (even if your ConfigMap and Secret content has not changed)
- The restart follows your existing rollout strategy (from v3.2.0+: `maxSurge: 25%`, `maxUnavailable: 0`, grace period 55s)

**After upgrade:**  
- Future `helm upgrade` commands that change any value in `bankTransfer.configmap` or `bankTransfer.secrets` will automatically restart pods
- You no longer need to manually restart pods (via `kubectl rollout restart` or similar) after configuration changes
- The restart is a standard rolling update — no downtime if you run multiple replicas

**Custom pod annotations:**  
If you set `bankTransfer.podAnnotations` in your values file, those annotations are preserved and merged with the new checksum annotations. The checksum annotations are always rendered first, followed by your custom annotations.

**Example:**

```yaml
bankTransfer:
  podAnnotations:
    custom.example.com/annotation: "value"
```

Results in:

```yaml
metadata:
  annotations:
    checksum/config: "a1b2c3d4e5f6..."
    checksum/secret: "f6e5d4c3b2a1..."
    custom.example.com/annotation: "value"
```

**No action required:**  
This change is fully automatic and requires no modifications to your values file or operational procedures. Configuration updates will now trigger pod restarts as expected.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.2.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.2.3
```
<!-- {% endraw %} -->
