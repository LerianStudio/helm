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

Version 3.2.3 is a **patch release** that adds pod-template checksums of the chart-rendered ConfigMap and Secret templates. Changes to those rendered templates during `helm upgrade` trigger a rollout; changes to an externally managed Secret are not detected. No values file modifications are required to enable the annotations.

## What Changed

### Automatic Pod Restart on Configuration Changes

**What changed:**  
The Deployment template now includes checksum annotations for the ConfigMap and Secret resources. When the rendered chart-managed content changes during a Helm upgrade, the pod-template checksum changes and triggers a rollout. External resource updates are not watched.

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

The annotations trigger a rollout when Helm renders changed chart-managed configuration. They do not detect out-of-band changes or external Secret updates.

**How it works:**  
- The `checksum/config` annotation contains a SHA256 hash of the rendered ConfigMap template
- The `checksum/secret` annotation contains a SHA256 hash of the rendered Secret template
- When rendered template output changes, the corresponding checksum changes; unused values do not affect that output
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
- Future `helm upgrade` commands restart pods when they change a rendered ConfigMap or chart-managed Secret template; a value that does not affect these templates does not change their checksums
- With `bankTransfer.useExistingSecret=true`, the Secret template is empty: changing data in the external Secret does not change the checksum. Arrange an explicit, controlled restart when those changes must reach running pods. The same applies to out-of-band configuration changes not rendered by Helm
- A rolling update is not a zero-downtime guarantee, even with multiple replicas. Check readiness, capacity, dependency availability and graceful shutdown for your environment; observe the rollout before considering it complete

**Custom pod annotations:**  
If you set `bankTransfer.podAnnotations` in your values file, those annotations are preserved and merged with the new checksum annotations. The checksum annotations are rendered first, followed by custom annotations. Reserve `checksum/config` and `checksum/secret`: do not redefine them in custom annotations, because duplicate keys can replace the generated checksums.

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
No values changes are needed to enable these annotations. Keep explicit restart procedures for externally managed Secrets and out-of-band configuration updates. Chart versions 3.2.2 and 3.2.3 both ship application 3.6.0; this checksum-only change does not update the application or its database schema.

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
