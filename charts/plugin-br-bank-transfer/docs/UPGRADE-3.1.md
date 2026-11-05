<!-- {% raw %} -->
# Helm Upgrade from v3.0.6 to v3.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. License File Support](#1-license-file-support)
- **[Configuration Reference](#configuration-reference)**
  - [New License File Configuration](#new-license-file-configuration)
  - [New Template Helpers](#new-template-helpers)
  - [New Environment Variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Evaluate License Delivery Method](#step-1-evaluate-license-delivery-method)
  - [Step 2: Create License File Secret (Optional)](#step-2-create-license-file-secret-optional)
  - [Step 3: Update Values Configuration (Optional)](#step-3-update-values-configuration-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.1.0 introduces **optional** support for signed license files as an alternative to the existing `LICENSE_KEY` environment variable. This feature is designed for applications built with `lib-license-go` v5 or later and provides a file-based licensing mechanism that can be rotated without pod restarts. The upgrade is **non-breaking** — existing deployments using `LICENSE_KEY` continue to work without modification.

The chart also adds new template helpers to support license file mounting and introduces a dedicated PreSync hook Secret for migration jobs that need license validation before the application Secret exists.

## Features

### 1. License File Support

**What changed:**  
The chart now supports mounting a signed license file from an existing Kubernetes Secret into the application and migration containers. When configured, the license file is mounted at `/etc/lerian/license/license` and the `LICENSE_FILE_PATH` environment variable is automatically set.

**Why it matters:**  
- **File-based licensing:** Applications using `lib-license-go` v5+ can read license data from a file instead of an environment variable
- **Secret rotation:** License files mounted from Secrets propagate updates automatically (no `subPath` mount) — pods pick up rotated licenses without restart
- **Migration support:** The PreSync migration job receives its own copy of the license (either via the hook Secret or the license file mount) to support license-gated schema migrations

**How it works:**

| Scenario | License Delivery | Configuration |
|----------|------------------|---------------|
| **Existing (v3.0.6)** | `LICENSE_KEY` environment variable from `bankTransfer.secrets.LICENSE_KEY` or `bankTransfer.extraEnvVars.LICENSE_KEY` | No change required |
| **New (v3.1.0)** | Signed license file from an existing Secret | Set `bankTransfer.licenseFile.existingSecret` to the Secret name; the chart mounts it and sets `LICENSE_FILE_PATH` |
| **Hybrid** | Both `LICENSE_KEY` and license file | The application receives both; behavior depends on app logic (typically file takes precedence) |

**Template changes:**

**Before (v3.0.6):**
```yaml
# templates/deployment.yaml (no license file support)
spec:
  containers:
    - name: bank-transfer
      envFrom:
        - secretRef:
            name: {{ include "bank-transfer.fullname" . }}
        - configMapRef:
            name: {{ include "bank-transfer.fullname" . }}
      # No volumeMounts for license file
  # No volumes for license file
```

**After (v3.1.0):**
```yaml
# templates/deployment.yaml (license file mount added conditionally)
spec:
  containers:
    - name: bank-transfer
      envFrom:
        - secretRef:
            name: {{ include "bank-transfer.fullname" . }}
        - configMapRef:
            name: {{ include "bank-transfer.fullname" . }}
      {{- with (include "bank-transfer.licenseFileMount" . | trim) }}
      volumeMounts:
        {{- . | nindent 12 }}
      {{- end }}
  {{- with (include "bank-transfer.licenseFileVolume" . | trim) }}
  volumes:
    {{- . | nindent 8 }}
  {{- end }}
```

**ConfigMap changes:**

**Before (v3.0.6):**
```yaml
# templates/configmap.yaml (no LICENSE_FILE_PATH)
data:
  ORGANIZATION_IDS: {{ .Values.bankTransfer.configmap.ORGANIZATION_IDS | quote }}
  # ... other config
```

**After (v3.1.0):**
```yaml
# templates/configmap.yaml (LICENSE_FILE_PATH added conditionally)
data:
  ORGANIZATION_IDS: {{ .Values.bankTransfer.configmap.ORGANIZATION_IDS | quote }}
  {{- if include "bank-transfer.licenseSecret" $ }}
  LICENSE_FILE_PATH: "/etc/lerian/license/license"
  {{- end }}
  # ... other config
```

**Migration job changes:**

The PreSync migration job (`templates/migrations.yaml`) now receives license configuration in three ways:

1. **License file mount:** If `bankTransfer.licenseFile.existingSecret` is set, the file is mounted at `/etc/lerian/license/license` and `LICENSE_FILE_PATH` is set
2. **LICENSE_KEY from hook Secret:** If `bankTransfer.secrets.LICENSE_KEY` or `bankTransfer.extraEnvVars.LICENSE_KEY` is set and the migration runs as a PreSync Job (external PostgreSQL, non-multi-tenant), a dedicated hook Secret (`<release>-license-hook`) is created with the key and injected via `secretKeyRef`
3. **LICENSE_KEY from app Secret:** If the migration runs as an init container (bundled PostgreSQL) or the operator uses `bankTransfer.useExistingSecret=true`, the key is read from the application Secret

**Before (v3.0.6):**
```yaml
# templates/migrations.yaml (no license support)
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "bank-transfer.fullname" . }}
        key: POSTGRES_PASSWORD
  # No LICENSE_KEY or LICENSE_FILE_PATH
```

**After (v3.1.0):**
```yaml
# templates/migrations.yaml (license support added)
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "bank-transfer.fullname" . }}
        key: POSTGRES_PASSWORD
  {{- if $licSecret }}
  - name: LICENSE_KEY
    valueFrom:
      secretKeyRef:
        name: {{ $licSecret }}
        key: LICENSE_KEY
        optional: true
  {{- else if $licKey }}
  - name: LICENSE_KEY
    value: {{ $licKey | quote }}
  {{- end }}
  {{- if include "bank-transfer.licenseSecret" . }}
  - name: LICENSE_FILE_PATH
    value: "/etc/lerian/license/license"
  {{- end }}
{{- with (include "bank-transfer.licenseFileMount" . | trim) }}
volumeMounts:
  {{- . | nindent 4 }}
{{- end }}
```

**New hook Secret:**

A new template (`templates/license-hook-secret.yaml`) creates a PreSync hook Secret containing `LICENSE_KEY` when:
- Migrations are enabled (`bankTransfer.enabled=true` and `bankTransfer.migrations.enabled=true`)
- A license key is set (`bankTransfer.secrets.LICENSE_KEY` or `bankTransfer.extraEnvVars.LICENSE_KEY`)
- The operator is **not** using `bankTransfer.useExistingSecret=true`
- The deployment uses external PostgreSQL (not the bundled subchart)
- Multi-tenant mode is disabled

**Why this hook Secret exists:**  
PreSync migration Jobs run before the application Secret is created. If the migration requires license validation (e.g., for licensed schema features), it needs its own copy of the `LICENSE_KEY`. The hook Secret is created with `helm.sh/hook: pre-install,pre-upgrade` and `argocd.argoproj.io/hook: PreSync` annotations, ensuring it exists before the migration Job runs.

**Operational impact:**
- **No action required for existing deployments:** If you do not set `bankTransfer.licenseFile.existingSecret`, the chart behaves exactly as in v3.0.6
- **License file rotation:** When using a license file Secret, updates to the Secret propagate to running pods automatically (the mount does not use `subPath`)
- **Migration licensing:** If your migration Job requires license validation, ensure either `LICENSE_KEY` is set (via `bankTransfer.secrets` or `bankTransfer.extraEnvVars`) or a license file Secret is configured

## Configuration Reference

### New License File Configuration

Add the following block to `bankTransfer` to enable license file mounting:

```yaml
bankTransfer:
  licenseFile:
    # Name of an existing Secret containing a signed license file under the key "license"
    existingSecret: ""
```

| Field | Default | Description |
|-------|---------|-------------|
| `bankTransfer.licenseFile.existingSecret` | `""` (empty) | Name of an existing Kubernetes Secret containing a signed license file under the key `license`. When set, the chart mounts the file at `/etc/lerian/license/license` and sets `LICENSE_FILE_PATH=/etc/lerian/license/license` in the ConfigMap. Requires an application image built with `lib-license-go` v5 or later. |

**Secret structure:**

The referenced Secret must contain a key named `license` with the signed license file content:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-license-secret
  namespace: midaz-plugins
type: Opaque
data:
  license: <base64-encoded-license-file-content>
```

### New Template Helpers

The chart introduces four new template helpers to support license file functionality:

| Helper | Purpose |
|--------|---------|
| `bank-transfer.licenseSecret` | Returns the value of `bankTransfer.licenseFile.existingSecret` (or empty string if not set) |
| `bank-transfer.licenseKeyValue` | Returns the `LICENSE_KEY` value from `bankTransfer.secrets.LICENSE_KEY` or `bankTransfer.extraEnvVars.LICENSE_KEY` (used by the hook Secret template) |
| `bank-transfer.licenseHookName` | Returns the name of the PreSync hook Secret (e.g., `<release>-license-hook`) |
| `bank-transfer.licenseFileMount` | Emits a `volumeMounts` entry for the license file (empty if `licenseFile.existingSecret` is not set) |
| `bank-transfer.licenseFileVolume` | Emits a `volumes` entry for the license file Secret (empty if `licenseFile.existingSecret` is not set) |

### New Environment Variables

When `bankTransfer.licenseFile.existingSecret` is set, the chart automatically adds the following environment variable to the ConfigMap:

| Variable | Value | Description |
|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `/etc/lerian/license/license` | Path to the mounted license file. The application reads the signed license from this path instead of (or in addition to) the `LICENSE_KEY` environment variable. |

## Migration Steps

### Step 1: Evaluate License Delivery Method

Determine whether you need to adopt the new license file feature. This step is **optional** — existing deployments using `LICENSE_KEY` continue to work without modification.

**Choose license file delivery if:**
- Your application image is built with `lib-license-go` v5 or later
- You want to rotate licenses without restarting pods
- Your licensing workflow uses signed license files instead of inline keys

**Keep existing `LICENSE_KEY` delivery if:**
- Your application image uses `lib-license-go` v4 or earlier
- You do not need file-based licensing
- You prefer environment variable–based configuration

> **Note:** You can use both methods simultaneously (set both `LICENSE_KEY` and `licenseFile.existingSecret`). Application behavior depends on your app's license validation logic — typically the file takes precedence.

### Step 2: Create License File Secret (Optional)

If you choose to use license file delivery, create a Kubernetes Secret containing your signed license file:

```bash
kubectl create secret generic my-license-secret \
  --from-file=license=/path/to/your/license.lic \
  -n midaz-plugins
```

> **Important:** The Secret **must** contain a key named `license`. The chart mounts this specific key at `/etc/lerian/license/license`.

Verify the Secret was created correctly:

```bash
kubectl get secret my-license-secret -n midaz-plugins -o jsonpath='{.data.license}' | base64 -d
```

### Step 3: Update Values Configuration (Optional)

If you created a license file Secret in Step 2, reference it in your `values-override.yaml`:

```yaml
bankTransfer:
  licenseFile:
    existingSecret: "my-license-secret"
```

**Complete example with both license methods:**

```yaml
bankTransfer:
  # Existing LICENSE_KEY (optional, can coexist with licenseFile)
  secrets:
    LICENSE_KEY: "your-existing-license-key"
  
  # New license file (optional)
  licenseFile:
    existingSecret: "my-license-secret"
```

> **Note:** If you set both `secrets.LICENSE_KEY` and `licenseFile.existingSecret`, the application receives both. Consult your application's documentation to understand which takes precedence.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.1.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.1.0
```
<!-- {% endraw %} -->
