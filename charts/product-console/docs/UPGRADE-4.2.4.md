# Helm Upgrade from v4.2.3 to v4.2.4

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. MongoDB password Secret now persists across uninstall](#1-mongodb-password-secret-now-persists-across-uninstall)
  - [2. MongoDB data volume now persists across uninstall](#2-mongodb-data-volume-now-persists-across-uninstall)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
  - [Scenario 1: Using bundled MongoDB with default configuration](#scenario-1-using-bundled-mongodb-with-default-configuration)
  - [Scenario 2: Using bundled MongoDB with custom existingSecret](#scenario-2-using-bundled-mongodb-with-custom-existingsecret)
  - [Scenario 3: Using external MongoDB](#scenario-3-using-external-mongodb)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that fixes MongoDB password and data persistence across `helm uninstall` operations. The bundled MongoDB subchart now uses a Secret and PersistentVolumeClaim that survive release deletion, preventing data loss and authentication failures on reinstall.

| Field | v4.2.3 | v4.2.4 |
|-------|--------|--------|
| Chart version | `4.2.3` | `4.2.4` |
| App version | `2.2.1` | `2.2.1` |

## Fixes

### 1. MongoDB password Secret now persists across uninstall

The bundled MongoDB subchart previously generated a new random root password on each install, stored in a Secret that was deleted by `helm uninstall`. This caused the console to fail authentication when reinstalled with the same release name, because the new password did not match the password stored in the kept data volume.

**What changed:**

- A new template `templates/mongodb-secret.yaml` now creates a Secret with `helm.sh/resource-policy: keep` that survives `helm uninstall`
- The subchart is configured to use this Secret via `mongodb.auth.existingSecret`
- The console deployment reads the password from this Secret, not from the subchart's ephemeral Secret

**Before (v4.2.3):**

```yaml
# values.yaml
mongodb:
  auth:
    enabled: true
    rootUser: midaz
    rootPassword: ""
    # existingSecret not set — subchart generates its own Secret
```

The subchart created a Secret named `product-console-mongodb` (or similar) that was deleted on `helm uninstall`. A reinstall generated a new password, breaking access to the kept volume.

**After (v4.2.4):**

```yaml
# values.yaml
mongodb:
  auth:
    enabled: true
    rootUser: midaz
    rootPassword: ""
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

The parent chart now creates `templates/mongodb-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: product-console-mongodb
  namespace: product-console
  annotations:
    helm.sh/resource-policy: keep
type: Opaque
data:
  mongodb-root-password: <base64-encoded-password>
```

This Secret persists across `helm uninstall` and is reused on reinstall, maintaining password consistency with the kept data volume.

**Impact:**

- Existing installations will adopt the new Secret on upgrade; the password remains unchanged
- New installations will create a kept Secret from the start
- `helm uninstall` no longer deletes the MongoDB root password
- Reinstalling with the same release name reuses the kept Secret and volume, preserving data and authentication

> **Important:** If you have set `mongodb.auth.existingSecret` to a custom value in v4.2.3, you must continue to manage that Secret yourself. The new template only creates a Secret when `mongodb.auth.existingSecret` evaluates to empty after template rendering.

### 2. MongoDB data volume now persists across uninstall

The bundled MongoDB subchart's PersistentVolumeClaim previously had no resource policy, so `helm uninstall` deleted the volume and all data. This release adds `resourcePolicy: keep` to the subchart configuration.

**What changed:**

| Setting | v4.2.3 | v4.2.4 |
|---------|--------|--------|
| `mongodb.persistence.resourcePolicy` | not set (volume deleted on uninstall) | `keep` |

**After (v4.2.4):**

```yaml
# values.yaml
mongodb:
  persistence:
    size: 8Gi
    resourcePolicy: keep
```

**Impact:**

- The PersistentVolumeClaim now survives `helm uninstall`
- Reinstalling with the same release name reuses the kept volume and its data
- Operators must manually delete the PVC if they want to remove the data:

```bash
kubectl delete pvc data-product-console-mongodb-0 -n product-console
```

> **Warning:** The volume and Secret are kept in the namespace where the MongoDB subchart runs. If you change `global.namespaceOverride` or move the subchart to a different namespace, the kept resources will remain in the old namespace and the new install will create empty replacements. Back up and restore data manually when moving namespaces.

## Configuration Changes

| Setting | v4.2.3 | v4.2.4 | Notes |
|---------|--------|--------|-------|
| `mongodb.auth.existingSecret` | not set | `'{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'` | Points subchart at the Secret this chart keeps; renders empty when evaluated by the subchart itself |
| `mongodb.persistence.resourcePolicy` | not set | `keep` | PVC survives `helm uninstall` |

**New template:**

- `templates/mongodb-secret.yaml`: Creates a Secret with `helm.sh/resource-policy: keep` that holds the MongoDB root password

**Template changes:**

The deployment template no longer uses the `lerian-common.infraSecretRef` helper to read the MongoDB password. It now reads directly from the Secret named by the `product-console.mongodb.secretName` helper.

**Before (v4.2.3):**

```yaml
# templates/deployment.yaml
env:
  {{- include "lerian-common.infraSecretRef" (dict "context" . "subchart" "mongodb" "key" "mongodb-root-password" "envName" "MONGODB_PASS") | nindent 12 }}
```

**After (v4.2.4):**

```yaml
# templates/deployment.yaml
env:
  - name: MONGODB_PASS
    valueFrom:
      secretKeyRef:
        name: {{ include "product-console.mongodb.secretName" . }}
        key: mongodb-root-password
```

The `product-console.mongodb.secretName` helper now resolves `mongodb.auth.existingSecret` with `tpl`, falling back to the subchart's fullname if the rendered value is empty.

## Migration Steps

This upgrade requires no mandatory values changes for most installations. The Helm upgrade will create the new Secret and update the subchart configuration.

### Scenario 1: Using bundled MongoDB with default configuration

**Current configuration (v4.2.3):**

```yaml
mongodb:
  enabled: true
  auth:
    enabled: true
    rootUser: midaz
    rootPassword: ""
```

**Action required:**

None. The upgrade will:

1. Create `templates/mongodb-secret.yaml` with the current password read from the subchart's existing Secret
2. Update `mongodb.auth.existingSecret` to point at the new kept Secret
3. Add `mongodb.persistence.resourcePolicy: keep` to preserve the data volume

**After upgrade:**

- The MongoDB password remains unchanged
- The Secret and PVC now survive `helm uninstall`
- Reinstalling with the same release name reuses both resources

### Scenario 2: Using bundled MongoDB with custom existingSecret

**Current configuration (v4.2.3):**

```yaml
mongodb:
  enabled: true
  auth:
    enabled: true
    rootUser: midaz
    existingSecret: my-custom-mongodb-secret
```

**Action required:**

Continue managing your custom Secret. The new template will not create a Secret because `mongodb.auth.existingSecret` is set to a non-empty value.

> **Important:** Add `helm.sh/resource-policy: keep` to your custom Secret if you want it to survive `helm uninstall`:

```bash
kubectl annotate secret my-custom-mongodb-secret helm.sh/resource-policy=keep -n product-console
```

### Scenario 3: Using external MongoDB

**Current configuration (v4.2.3):**

```yaml
mongodb:
  enabled: false

configmap:
  MONGO_HOST: external-mongodb.example.com

secrets:
  MONGODB_PASS: <external-password>
```

**Action required:**

None. The new Secret template only renders when `mongodb.enabled=true`.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.4 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.4 -n product-console
```
