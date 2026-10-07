# Helm Upgrade from v4.3.5 to v4.3.6

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. MongoDB password Secret now persists across uninstall](#1-mongodb-password-secret-now-persists-across-uninstall)
  - [2. MongoDB data volume now persists across uninstall](#2-mongodb-data-volume-now-persists-across-uninstall)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review existing MongoDB Secret and PVC](#step-1-review-existing-mongodb-secret-and-pvc)
  - [Step 2: Execute the upgrade](#step-2-execute-the-upgrade)
  - [Step 3: Verify Secret and PVC annotations](#step-3-verify-secret-and-pvc-annotations)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that ensures the bundled MongoDB's password Secret and data volume persist across `helm uninstall`, preventing data loss and authentication failures when reinstalling with the same release name. The application version is unchanged.

| Field | v4.3.5 | v4.3.6 |
|-------|--------|--------|
| Chart version | `4.3.5` | `4.3.6` |
| App version | `4.2.0` | `4.2.0` |

## Fixes

### 1. MongoDB password Secret now persists across uninstall

The bundled MongoDB subchart's password Secret is now managed by the reporter chart itself and annotated with `helm.sh/resource-policy: keep`. This ensures the Secret survives `helm uninstall`, allowing a same-name reinstall to reuse the existing password and access the kept MongoDB data volume.

**What changed:**

- A new template `templates/mongodb-secrets.yaml` creates the MongoDB password Secret (`<release>-mongodb`) before the subchart renders
- The Secret contains the same keys as the Bitnami MongoDB subchart's generated Secret: `mongodb-root-password` and (for replicaset architecture) `mongodb-replica-set-key`
- The subchart is configured to use this chart-managed Secret via `mongodb.auth.existingSecret`
- The Secret is annotated with `helm.sh/resource-policy: keep` to persist across uninstall

**Before (v4.3.5):**

The MongoDB subchart generated its own Secret (`<release>-mongodb`) during install. Running `helm uninstall` deleted the Secret, and a subsequent `helm install` with the same release name generated a new password, causing authentication failures against the kept data volume.

**After (v4.3.6):**

```yaml
# templates/mongodb-secrets.yaml (new file)
apiVersion: v1
kind: Secret
metadata:
  name: reporter-mongodb
  annotations:
    helm.sh/resource-policy: keep
type: Opaque
data:
  mongodb-root-password: <base64-encoded-password>
  mongodb-replica-set-key: <base64-encoded-key>  # only for replicaset architecture
```

```yaml
# values.yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

The `existingSecret` template expression evaluates to the Secret name only when rendering inside the MongoDB subchart context, and to an empty string when rendering in the reporter chart context (preventing the reporter's own templates from reading it).

| Setting | v4.3.5 | v4.3.6 |
|---------|--------|--------|
| `mongodb.auth.existingSecret` | not set (subchart generates Secret) | `'{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'` |
| MongoDB Secret resource policy | none (deleted on uninstall) | `keep` (persists across uninstall) |

> **Important:** If you have set `mongodb.auth.existingSecret` to your own Secret name in your values, that configuration takes precedence and the chart will not create `templates/mongodb-secrets.yaml`. The chart validates that `existingSecret` is either unset (default) or contains a non-empty template expression.

**Operational impact:**

- Operators can now safely run `helm uninstall` and `helm install` with the same release name without losing MongoDB access
- The kept Secret and kept PVC (see fix #2) work together to preserve the full MongoDB state across reinstalls
- If you need to reset the MongoDB password, you must manually delete the Secret before reinstalling:

```bash
kubectl delete secret reporter-mongodb -n <namespace>
```

### 2. MongoDB data volume now persists across uninstall

The bundled MongoDB subchart's PersistentVolumeClaim is now annotated with `helm.sh/resource-policy: keep` via the `mongodb.persistence.resourcePolicy` field. This ensures the data volume survives `helm uninstall`, preventing data loss when reinstalling with the same release name.

**What changed:**

- The `mongodb.persistence.resourcePolicy` field is now set to `keep` by default
- The Bitnami MongoDB subchart honors this field and annotates the PVC with `helm.sh/resource-policy: keep`

**Before (v4.3.5):**

```yaml
mongodb:
  persistence:
    size: 8Gi
```

The PVC was deleted on `helm uninstall`, causing data loss.

**After (v4.3.6):**

```yaml
mongodb:
  persistence:
    size: 8Gi
    resourcePolicy: keep
```

| Setting | v4.3.5 | v4.3.6 |
|---------|--------|--------|
| `mongodb.persistence.resourcePolicy` | not set (PVC deleted on uninstall) | `keep` (PVC persists across uninstall) |

> **Note:** The `resourcePolicy: keep` annotation is added to the PVC on upgrade. Existing PVCs from v4.3.5 will be annotated during the upgrade and will persist on future uninstalls.

**Operational impact:**

- MongoDB data now survives `helm uninstall` by default
- To fully remove MongoDB data, you must manually delete the PVC after uninstall:

```bash
kubectl delete pvc data-reporter-mongodb-0 -n <namespace>
```

- The kept PVC and kept Secret (see fix #1) work together to preserve the full MongoDB state across reinstalls

## Configuration Changes

No new top-level keys were added to `values.yaml`. The changes are in default values and template logic only.

| Setting | v4.3.5 | v4.3.6 | Notes |
|---------|--------|--------|-------|
| `mongodb.auth.existingSecret` | not set | `'{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'` | Points subchart at chart-managed Secret; leave unset to use default |
| `mongodb.persistence.resourcePolicy` | not set | `keep` | PVC persists across uninstall; set to `""` to restore prior behavior |

**Comments added to values.yaml:**

```yaml
mongodb:
  auth:
    # -- Secret with the root password. The default points the subchart at the one this chart keeps
    # across uninstall (templates/mongodb-secrets.yaml); reporter's own templates read it as empty. Name yours to replace it.
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
  persistence:
    # -- The data volume outlives the release: helm uninstall keeps it.
    resourcePolicy: keep
```

**Template helper changes:**

The `reporter.infraSecretRef` helper and related functions now use a new `reporter.operatorSecret` helper to determine whether an operator has provided their own `existingSecret`. This helper evaluates the template expression in `mongodb.auth.existingSecret` and returns the Secret name only if it resolves to a non-empty string in the reporter chart context.

**Before (v4.3.5):**

```yaml
{{- define "reporter.infraSecretRef" -}}
{{- $auth := default dict (index $ctx.Values $sub "auth") -}}
{{- $secretName := "" -}}
{{- if $auth.existingSecret -}}
{{- $secretName = $auth.existingSecret -}}
{{- else -}}
{{- $secretName = include "common.names.dependency.fullname" ... -}}
{{- end -}}
```

**After (v4.3.6):**

```yaml
{{- define "reporter.infraSecretRef" -}}
{{- $secretName := include "reporter.operatorSecret" . -}}
{{- if not $secretName -}}
{{- $secretName = include "common.names.dependency.fullname" ... -}}
{{- end -}}
```

```yaml
{{- define "reporter.operatorSecret" -}}
{{- tpl (dig "auth" "existingSecret" "" (index .context.Values .subchart | default dict) | toString) .context -}}
{{- end }}
```

This change ensures the chart correctly detects when an operator has provided their own Secret versus when the default template expression is in use.

## Migration Steps

This upgrade requires no mandatory values changes. The Helm upgrade will add the `helm.sh/resource-policy: keep` annotation to the existing MongoDB Secret and PVC, and create the new `templates/mongodb-secrets.yaml` Secret if it does not already exist.

### Step 1: Review existing MongoDB Secret and PVC

Check the current MongoDB Secret and PVC in your namespace:

```bash
kubectl get secret reporter-mongodb -n <namespace> -o yaml
kubectl get pvc data-reporter-mongodb-0 -n <namespace> -o yaml
```

Verify that the Secret contains the `mongodb-root-password` key and the PVC is bound to a PersistentVolume.

> **Note:** If you have set `mongodb.auth.existingSecret` to your own Secret name in your values, the upgrade will not create `templates/mongodb-secrets.yaml` and will not modify your existing Secret. Your Secret will not be annotated with `helm.sh/resource-policy: keep` unless you add the annotation manually.

### Step 2: Execute the upgrade

Run the upgrade command:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.6 -n <namespace>
```

The upgrade will:

1. Add `helm.sh/resource-policy: keep` annotation to the existing MongoDB Secret (if using the default `existingSecret` template)
2. Add `helm.sh/resource-policy: keep` annotation to the existing MongoDB PVC
3. Create the `templates/mongodb-secrets.yaml` Secret if it does not already exist (it will adopt the existing Secret's password via the `common.secrets.passwords.manage` helper)

> **Important:** The MongoDB pod will not restart during this upgrade unless the Secret data changes. The upgrade only adds annotations to existing resources.

### Step 3: Verify Secret and PVC annotations

After the upgrade completes, verify that the annotations were added:

```bash
kubectl get secret reporter-mongodb -n <namespace> -o jsonpath='{.metadata.annotations.helm\.sh/resource-policy}'
kubectl get pvc data-reporter-mongodb-0 -n <namespace> -o jsonpath='{.metadata.annotations.helm\.sh/resource-policy}'
```

Both commands should output `keep`.

**Test uninstall behavior (optional):**

To verify that the Secret and PVC persist across uninstall, run:

```bash
helm uninstall reporter -n <namespace>
kubectl get secret reporter-mongodb -n <namespace>
kubectl get pvc data-reporter-mongodb-0 -n <namespace>
```

Both resources should still exist after uninstall. Reinstall the chart with the same release name to verify that MongoDB reconnects to the existing data:

```bash
helm install reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.6 -n <namespace>
```

> **Warning:** Do not test uninstall behavior in production. The kept Secret and PVC will remain in the namespace and must be manually deleted if you want to fully remove the release.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.6 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.6 -n reporter
```
