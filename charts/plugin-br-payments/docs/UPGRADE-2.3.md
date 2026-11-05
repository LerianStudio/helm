<!-- {% raw %} -->
# Helm Upgrade from v2.2.2 to v2.3.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Optional signed licence file support](#1-optional-signed-licence-file-support)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.2.2` to `2.3.0`. The application version remains `1.2.0`; the chart bump to `2.3.0` is a minor release that introduces an optional signed licence file mechanism as an alternative to the existing `app.secrets.LICENSE_KEY` environment variable. This feature requires the application binary to support file-mode licensing (lib-license-go v5 or later).

Existing deployments will continue to work without values changes. The `LICENSE_KEY` secret remains the default licensing method; the new `app.licenseFile.existingSecret` field is an opt-in alternative for operators who manage signed licence files externally.

## Features

### 1. Optional signed licence file support

The chart now supports mounting a signed licence file from an existing Kubernetes Secret as an alternative to the `LICENSE_KEY` environment variable. When `app.licenseFile.existingSecret` is set, the chart mounts the Secret as a read-only directory at `/etc/lerian/license` on both the application Deployment and the control-plane migrations Job, and sets the `LICENSE_FILE_PATH` environment variable to `/etc/lerian/license/license`.

**Why this matters:**

- Operators who manage signed licence files in external secret stores (e.g., Vault, AWS Secrets Manager) can now reference a pre-created Kubernetes Secret instead of embedding the licence key in Helm values.
- The Secret is mounted as a directory (not `subPath`), so licence rotations propagate to running pods without requiring a restart.
- The control-plane migrations Job is now licence-gated: it will read the licence from either `LICENSE_KEY` or `LICENSE_FILE_PATH` before running schema migrations.

**New values field:**

```yaml
app:
  licenseFile:
    # -- Optional signed licence file, an alternative to secrets.LICENSE_KEY. The Secret
    # is mounted read-only as a directory on the app and the control-plane migrations
    # Job at /etc/lerian/license (key `license`). File mode needs lib-license-go v5.
    existingSecret: ""
```

**Operational impact:**

- If `app.licenseFile.existingSecret` is set, the chart will:
  1. Mount the Secret as a volume at `/etc/lerian/license` on the application Deployment and the control-plane migrations Job.
  2. Set the `LICENSE_FILE_PATH` environment variable to `/etc/lerian/license/license` in the ConfigMap.
  3. Relax the `LICENSE_KEY` requirement in the chart's validation logic (the `fail` hook in `templates/_helpers.tpl` now allows `LICENSE_KEY` to be empty if `app.licenseFile.existingSecret` is set).

- If `app.licenseFile.existingSecret` is **not** set, the chart behaves exactly as in v2.2.2: `LICENSE_KEY` is required and must be set in `app.secrets.LICENSE_KEY`.

**Template changes:**

Three new helper templates were added to `templates/_helpers.tpl`:

**Before (v2.2.2):**

The chart had no licence file mounting logic. The `LICENSE_KEY` validation was:

```yaml
{{- if and $ownSecret (not .Values.app.secrets.LICENSE_KEY) }}
{{- fail "\n\nERROR: app.secrets.LICENSE_KEY is REQUIRED.\n   The app refuses to boot without a license in every environment.\n" }}
{{- end }}
```

**After (v2.3.0):**

The validation now checks both `LICENSE_KEY` and `app.licenseFile.existingSecret`:

```yaml
{{- if and $ownSecret (not .Values.app.secrets.LICENSE_KEY) (not (include "plugin-br-payments.licenseSecret" .)) }}
{{- fail "\n\nERROR: app.secrets.LICENSE_KEY is REQUIRED unless app.licenseFile.existingSecret is set.\n   The app refuses to boot without a license in every environment.\n" }}
{{- end }}
```

New helper templates:

```yaml
{{- define "plugin-br-payments.licenseSecret" -}}
{{- (.Values.app.licenseFile | default dict).existingSecret | default "" -}}
{{- end -}}

{{- define "plugin-br-payments.licenseFileMount" -}}
{{- with include "plugin-br-payments.licenseSecret" . }}
volumeMounts:
  - name: license-file
    mountPath: /etc/lerian/license
    readOnly: true
{{- end }}
{{- end -}}

{{- define "plugin-br-payments.licenseFileVolume" -}}
{{- with include "plugin-br-payments.licenseSecret" . }}
- name: license-file
  secret:
    secretName: {{ . | quote }}
    items:
      - key: license
        path: license
{{- end }}
{{- end -}}
```

**Deployment changes:**

The application Deployment (`templates/deployment.yaml`) now includes the licence file volume mount and volume when `app.licenseFile.existingSecret` is set:

```yaml
# In the app container's volumeMounts section:
{{- with (include "plugin-br-payments.licenseFileMount" . | trim) }}{{ . | nindent 10 }}{{- end }}

# In the volumes section:
{{- $licVolume := include "plugin-br-payments.licenseFileVolume" . | trim }}
{{- $raOn := and .Values.aws .Values.aws.rolesAnywhere .Values.aws.rolesAnywhere.enabled }}
{{- if or $raOn $licVolume }}
volumes:
  {{- with $licVolume }}
  {{- . | nindent 8 }}
  {{- end }}
  {{- if $raOn }}
  - name: iam-certs
    secret:
      secretName: {{ .Values.aws.rolesAnywhere.certificateSecretName | default "plugin-br-payments-iam-tls" }}
      items:
        - key: ca.crt
          path: ca.crt
        - key: tls.crt
          path: tls.crt
        - key: tls.key
          path: tls.key
  {{- end }}
{{- end }}
```

**Control-plane migrations Job changes:**

The control-plane migrations Job (`templates/controlplane-migrations.yaml`) now includes:

1. The `LICENSE_KEY` environment variable (optional, sourced from the app Secret):

```yaml
{{- if or .Values.app.useExistingSecret .Values.app.secrets.LICENSE_KEY }}
- name: LICENSE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ if .Values.app.useExistingSecret }}{{ .Values.app.existingSecretName }}{{ else }}{{ include "plugin-br-payments.fullname" . }}{{ end }}
      key: LICENSE_KEY
      optional: true
{{- end }}
```

2. The `LICENSE_FILE_PATH` environment variable (when `app.licenseFile.existingSecret` is set):

```yaml
{{- if include "plugin-br-payments.licenseSecret" . }}
- name: LICENSE_FILE_PATH
  value: "/etc/lerian/license/license"
{{- end }}
```

3. The licence file volume mount and volume:

```yaml
{{- with (include "plugin-br-payments.licenseFileMount" . | trim) }}{{ . | nindent 10 }}{{- end }}

# In the volumes section:
{{- with (include "plugin-br-payments.licenseFileVolume" . | trim) }}
volumes:
  {{- . | nindent 8 }}
{{- end }}
```

**ConfigMap changes:**

The ConfigMap (`templates/configmap.yaml`) now includes the `LICENSE_FILE_PATH` environment variable when `app.licenseFile.existingSecret` is set:

```yaml
{{- if include "plugin-br-payments.licenseSecret" . }}
LICENSE_FILE_PATH: "/etc/lerian/license/license"
{{- end }}
```

**NOTES.txt changes:**

The post-install notes were updated to reflect the new licensing options:

**Before (v2.2.2):**

```
- app.secrets.LICENSE_KEY               (required in every environment)
```

**After (v2.3.0):**

```
- app.secrets.LICENSE_KEY               (required in every environment unless app.licenseFile.existingSecret mounts a signed licence file)
```

> **Important:** The application binary must support file-mode licensing (lib-license-go v5 or later) for this feature to work. If you are running an older application version that does not recognize `LICENSE_FILE_PATH`, the pods will fail to start. Verify your application version supports file-mode licensing before enabling this feature.

> **Note:** The Secret referenced by `app.licenseFile.existingSecret` must contain a key named `license` with the signed licence file content. The chart does not create this Secret; operators must create it before upgrading.

## Configuration Reference

### New values fields

| Field | Default | Description |
|-------|---------|-------------|
| `app.licenseFile.existingSecret` | `""` | Name of an existing Kubernetes Secret containing a signed licence file (key: `license`). When set, the Secret is mounted at `/etc/lerian/license` and `LICENSE_FILE_PATH` is set to `/etc/lerian/license/license`. Requires lib-license-go v5 or later. |

### New environment variables

| Variable | Source | Description |
|----------|--------|-------------|
| `LICENSE_FILE_PATH` | ConfigMap | Path to the signed licence file. Set to `/etc/lerian/license/license` when `app.licenseFile.existingSecret` is configured. Read by the application binary and the control-plane migrations Job. |

### Changed validation logic

| Setting | v2.2.2 | v2.3.0 |
|---------|--------|--------|
| `app.secrets.LICENSE_KEY` requirement | Always required | Required **unless** `app.licenseFile.existingSecret` is set |

## Migration Steps

### Option 1: Keep existing LICENSE_KEY (no action required)

If you are satisfied with the current `LICENSE_KEY` environment variable approach, no changes are required. The chart will continue to work exactly as in v2.2.2.

1. Run the upgrade command (see [Command to upgrade](#command-to-upgrade)).
2. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

### Option 2: Migrate to signed licence file

If you want to use the new signed licence file mechanism:

1. Create a Kubernetes Secret containing your signed licence file with the key `license`:

```bash
kubectl create secret generic my-license-file \
  --from-file=license=/path/to/your/license.lic \
  -n <namespace>
```

2. Update your values overlay to reference the Secret:

```yaml
app:
  licenseFile:
    existingSecret: "my-license-file"
```

3. **(Optional)** Remove `app.secrets.LICENSE_KEY` from your values overlay if you no longer need it. The chart will use the licence file instead.

4. Preview the rendered diff with the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

5. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

6. Verify the licence file is mounted correctly:

```bash
kubectl exec -n <namespace> -it deployment/plugin-br-payments -- ls -la /etc/lerian/license
```

Expected output:

```
total 0
drwxrwxrwt 3 root root  100 Jan  1 00:00 .
drwxr-xr-x 3 root root 4096 Jan  1 00:00 ..
drwxr-xr-x 2 root root   60 Jan  1 00:00 ..2024_01_01_00_00_00.123456789
lrwxrwxrwx 1 root root   31 Jan  1 00:00 ..data -> ..2024_01_01_00_00_00.123456789
lrwxrwxrwx 1 root root   14 Jan  1 00:00 license -> ..data/license
```

7. Verify the application logs confirm the licence was loaded from the file:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-br-payments --tail=50 | grep -i license
```

> **Warning:** If you set both `app.secrets.LICENSE_KEY` and `app.licenseFile.existingSecret`, the application binary's behavior depends on its internal precedence logic. Consult the application documentation to understand which licence source takes priority. The chart will render both the environment variable and the file mount.

> **Note:** The Secret mount is read-only and uses Kubernetes' atomic symlink mechanism. When you update the Secret, Kubernetes will update the symlink, and the application will see the new licence file content without a pod restart (if the application supports hot-reloading of licence files). Consult the application documentation to confirm hot-reload support.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.3.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.3.0
```
<!-- {% endraw %} -->
