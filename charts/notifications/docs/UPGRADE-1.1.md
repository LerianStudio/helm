<!-- {% raw %} -->
# Helm Upgrade from v1.0.2 to v1.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Optional licence file mounting](#1-optional-licence-file-mounting)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `notifications` chart upgrade from `1.0.2` to `1.1.0`. This is a **minor** release that adds support for mounting a signed licence file as an alternative to the `LICENSE_KEY` environment variable. The application version (`appVersion: "1.1.0"`) remains unchanged.

No configuration change is required if you are already using `secrets.LICENSE_KEY`. The new `licenseFile.existingSecret` field is optional and provides an alternative licensing method.

Every pod of the release restarts once during this upgrade due to template changes.

## Features

### 1. Optional licence file mounting

The chart now supports mounting a signed licence file from an existing Secret as an alternative to providing `secrets.LICENSE_KEY`. When `licenseFile.existingSecret` is set, the chart mounts the Secret as a directory at `/etc/lerian/license` on the API and all worker pods, and sets the `LICENSE_FILE_PATH` environment variable to point to the licence file.

#### Why this matters

- **File-based licensing:** Some deployments prefer to manage licences as files rather than environment variables, especially when using external secret management systems or certificate rotation workflows.
- **Secret rotation:** Mounting the Secret as a directory (not using `subPath`) allows Kubernetes to propagate updates when the Secret is rotated, without requiring pod restarts.
- **Backward compatibility:** The existing `secrets.LICENSE_KEY` method continues to work unchanged. You can choose either method.

#### How it works

The chart adds four new template helpers in `_helpers.tpl`:

- `notifications.licenseFileSecret`: Returns the value of `licenseFile.existingSecret` if set.
- `notifications.licenseFileEnv`: Injects the `LICENSE_FILE_PATH` environment variable when a licence file Secret is configured.
- `notifications.licenseFileVolumeMount`: Adds the volume mount for the licence file directory.
- `notifications.licenseFileVolume`: Adds the Secret volume definition.

These helpers are applied to the API and all three worker Deployments (`worker-email`, `worker-sms`, `worker-webhook`).

**Before (v1.0.2):**

```yaml
# templates/api/deployment.yaml
spec:
  template:
    spec:
      containers:
        - name: api
          envFrom:
            - configMapRef:
                name: {{ include "notifications.configMapName" . }}
            - secretRef:
                name: {{ include "notifications.secretName" . }}
          {{- with .Values.api.extraEnvVars }}
          env:
            {{- range $key, $value := . }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          {{- end }}
```

**After (v1.1.0):**

```yaml
# templates/api/deployment.yaml
spec:
  template:
    spec:
      containers:
        - name: api
          envFrom:
            - configMapRef:
                name: {{ include "notifications.configMapName" . }}
            - secretRef:
                name: {{ include "notifications.secretName" . }}
          {{- $licenseEnv := include "notifications.licenseFileEnv" . }}
          {{- if or $licenseEnv .Values.api.extraEnvVars }}
          env:
            {{- with $licenseEnv }}{{ . | nindent 12 }}{{ end }}
            {{- range $key, $value := .Values.api.extraEnvVars }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          {{- end }}
          {{- with (include "notifications.licenseFileVolumeMount" . | trim) }}{{ . | nindent 10 }}{{ end }}
          # ... probes ...
      {{- with (include "notifications.licenseFileVolume" . | trim) }}{{ . | nindent 6 }}{{ end }}
```

The worker Deployments receive identical changes, with the `LICENSE_FILE_PATH` environment variable injected into their existing `env:` blocks.

#### Secret validation changes

The chart's Secret validation logic in `templates/secrets.yaml` now allows deployments without `secrets.LICENSE_KEY` if `licenseFile.existingSecret` is set:

**Before (v1.0.2):**

```yaml
{{- if not .Values.secretRef.name }}
{{- $_ := required "secrets.LICENSE_KEY is required: the api and every worker refuse to boot without it. Set it, or point secretRef.name at a Secret that carries LICENSE_KEY." .Values.secrets.LICENSE_KEY }}
```

**After (v1.1.0):**

```yaml
{{- if not .Values.secretRef.name }}
{{- if not (include "notifications.licenseFileSecret" .) }}
{{- $_ := required "secrets.LICENSE_KEY is required unless licenseFile.existingSecret is set: the api and every worker refuse to boot without a licence. Set it, point secretRef.name at a Secret that carries LICENSE_KEY, or mount a licence file." .Values.secrets.LICENSE_KEY }}
{{- end }}
```

#### New environment variable

When `licenseFile.existingSecret` is set, the following environment variable is added to the API and all worker containers:

| Variable | Value | Description |
|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `/etc/lerian/license/license` | Path to the mounted licence file; consumed by the application's licensing library |

> **Note:** The application requires lib-license-go v5 or later to support file-based licensing. Ensure your image version is compatible before switching to `licenseFile.existingSecret`.

## Configuration Reference

### New values

The following field has been added to `values.yaml`:

```yaml
#==============================================================================
# Licence file (optional alternative to secrets.LICENSE_KEY)
#==============================================================================
licenseFile:
  # -- Existing Secret with the signed licence file (key `license`), mounted as a directory at
  # /etc/lerian/license on the api and workers; secrets.LICENSE_KEY is then not required.
  # File mode needs an image on lib-license-go v5.
  existingSecret: ""
```

| Field | Default | Description |
|-------|---------|-------------|
| `licenseFile.existingSecret` | `""` | Name of an existing Secret containing the licence file under the key `license`. When set, `secrets.LICENSE_KEY` is no longer required. |

### Changed values

The comment for `secrets.LICENSE_KEY` has been updated to reflect the new optional behaviour:

| Setting | v1.0.2 | v1.1.0 |
|---------|--------|--------|
| `secrets.LICENSE_KEY` comment | `REQUIRED: licence key; the api and every worker refuse to boot without it.` | `REQUIRED unless licenseFile.existingSecret is set: licence key; the api and every worker refuse to boot without a licence.` |

## Migration Steps

### Option 1: Continue using `secrets.LICENSE_KEY` (no action required)

If you are already providing `secrets.LICENSE_KEY` via `values.yaml`, `--set`, or an external Secret referenced by `secretRef.name`, no change is required. The chart continues to work exactly as before.

### Option 2: Migrate to file-based licensing

If you want to switch to file-based licensing:

1. **Verify image compatibility.** Ensure your application image uses lib-license-go v5 or later. Check the release notes or image tags for your deployment.

2. **Create a Secret with your licence file.** The Secret must contain a key named `license` with the signed licence file content:

```bash
kubectl create secret generic notifications-license \
  --from-file=license=/path/to/your/license.lic \
  -n notifications
```

3. **Update your values to reference the Secret:**

```yaml
licenseFile:
  existingSecret: "notifications-license"
```

4. **Remove `secrets.LICENSE_KEY` from your values** (optional). If you set `licenseFile.existingSecret`, the chart no longer requires `secrets.LICENSE_KEY`. However, leaving it set does no harm; the application will use the file if `LICENSE_FILE_PATH` is present.

5. **Run the upgrade** (see [Command to upgrade](#command-to-upgrade)).

6. **Verify the mount:**

```bash
kubectl exec -n notifications deploy/notifications-api -- ls -la /etc/lerian/license
```

You should see the `license` file with read-only permissions.

> **Important:** The licence file Secret is **not** managed by this chart. You must create and maintain it externally. The chart only mounts it. Ensure your Secret exists in the same namespace as the release before upgrading.

> **Note:** The chart mounts the Secret as a directory (not using `subPath`). This allows Kubernetes to propagate updates when you rotate the Secret, without requiring a pod restart. The application will reload the licence file automatically if it supports hot reloading.

## Preview changes before upgrading

```bash
helm diff upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.1.0 -n notifications
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.1.0 -n notifications
```
<!-- {% endraw %} -->
