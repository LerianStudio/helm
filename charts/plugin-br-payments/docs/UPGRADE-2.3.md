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

This guide covers the `plugin-br-payments` chart upgrade from `2.2.2` to `2.3.0`. The application version remains `1.2.0`; the chart bump adds optional Secret-file mounting and environment wiring. This is chart-level preparation, not a working file-only licensing migration for the shipped application. Application `1.2.0` uses `lib-license-go/v4 v4.2.2`, requires a non-empty `LICENSE_KEY`, and does not consume `LICENSE_FILE_PATH`. Keep the existing key with this image. No compatible replacement image is identified by this guide.

No licence-related values migration is required for existing key-based deployments. Preserve all existing operator values and the key source. Even with identical values, upgrading from `2.2.2` to `2.3.0` changes the Deployment pod-template checksums and triggers a rolling restart; schedule and monitor it. The application version does not change.

## Features

### 1. Optional signed licence file support

The chart now supports mounting a signed licence file from an existing Kubernetes Secret. This does not replace `LICENSE_KEY` in application `1.2.0`. When `app.licenseFile.existingSecret` is set, the chart mounts the Secret as a read-only directory at `/etc/lerian/license` on the application Deployment and, when rendered, the control-plane migrations Job, and sets the `LICENSE_FILE_PATH` environment variable to `/etc/lerian/license/license`.

**Why this matters:**

- The chart can reference a pre-created Kubernetes Secret for a future, independently verified file-aware image. With application `1.2.0`, continue supplying `LICENSE_KEY`, including through the existing application Secret where configured.
- The Secret is mounted as a directory (not `subPath`), allowing Kubernetes to eventually project Secret updates. Projection is not application consumption or hot reload; neither file-mode licensing nor file hot reload is established for the default image.
- The conditional control-plane migrations Job receives licence environment/mount wiring. The published `1.2.0` `/controlplane-migrate` executable uses `LoadControlPlaneMigrationConfig` and `RunControlPlaneMigrations` without full service licence enforcement. Wiring does not add a licence gate. The Job is conditional on the multi-tenant migration settings, not present in the default single-tenant render.

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

- If `app.licenseFile.existingSecret` is **not** set, keep the existing `LICENSE_KEY` source. The chart requires `app.secrets.LICENSE_KEY` when it manages the app Secret; with `app.useExistingSecret`, the operator-managed app Secret must supply the key. The migration Job also gains optional key wiring in this release, and the application Deployment rolls even without values changes.

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

The post-install notes describe the relaxed chart validation, not the actual licensing support of application `1.2.0`:

**Before (v2.2.2):**

```
- app.secrets.LICENSE_KEY               (required in every environment)
```

**After (v2.3.0):**

```
- app.secrets.LICENSE_KEY               (required in every environment unless app.licenseFile.existingSecret mounts a signed licence file)
```

> **Important:** A successful render with a file Secret and no key is not a successful application startup. The shipped `1.2.0` image requires `LICENSE_KEY`; the historical notes and validation snippets above do not override that requirement. File-only migration is blocked until an exact compatible image and its licensing behavior have been independently verified.
> **Note:** The Secret referenced by `app.licenseFile.existingSecret` must contain a key named `license` with the signed licence file content. The chart does not create this Secret; operators must create it before upgrading.

## Configuration Reference

### New values fields

| Field | Default | Description |
|-------|---------|-------------|
| `app.licenseFile.existingSecret` | `""` | Name of an existing Kubernetes Secret containing a signed licence file (key: `license`). When set, the Secret is mounted at `/etc/lerian/license` and `LICENSE_FILE_PATH` is set to `/etc/lerian/license/license`. Chart wiring only; the default application `1.2.0` cannot use it instead of `LICENSE_KEY`. |

### New environment variables

| Variable | Source | Description |
|----------|--------|-------------|
| `LICENSE_FILE_PATH` | ConfigMap | Path to the signed licence file. Set to `/etc/lerian/license/license` when `app.licenseFile.existingSecret` is configured. Delivered to the app and conditional migration Job; not consumed as a licence source by the shipped `1.2.0` application, and not a migration licence gate. |

### Changed validation logic

| Setting | v2.2.2 | v2.3.0 |
|---------|--------|--------|
| Chart validation, chart-managed app Secret | Required | Required **unless** `app.licenseFile.existingSecret` is set |
| Application `1.2.0` startup | Non-empty `LICENSE_KEY` required | Non-empty `LICENSE_KEY` still required |

## Migration Steps

### Keep existing LICENSE_KEY (supported for application 1.2.0)

No licence-related values changes are required. Do not remove the key. The chart upgrade still triggers a rolling restart through the changed pod-template checksums.

1. Set the following variables to the existing release, namespace and your maintained values file. The file must preserve **all** current operator configuration (including externally managed Secret references, image overrides, datastore and tenant settings), not just the small licence fragment shown in this guide. If you use multiple maintained overlays, pass the same complete ordered `-f` list in both preview and upgrade; do not replace it with a partial overlay. Protect values/render output as it can include secrets.

```bash
RELEASE='my-payments'
NAMESPACE='midaz-plugins'
VALUES_FILE='/path/to/maintained-complete-values.yaml'
```

2. Review the pinned `2.3.0` render/diff using those values. Confirm that the existing key source remains configured and that changes outside licensing are intended. Review any conditional migration Job separately; it is not licence-gated by the default executable.
3. After operational approval, perform the upgrade during your maintenance window using the command below. Preserve your usual backup and recovery process; no live upgrade or restore is demonstrated here.
4. Discover the actual Deployment name (it can be affected by naming overrides), assign it to `DEPLOYMENT`, then monitor rollout and pod readiness:

```bash
kubectl get deployments -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE"
DEPLOYMENT='plugin-br-payments'
kubectl rollout status "deployment/$DEPLOYMENT" -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE"
```

Confirm application readiness and licence validation through your normal application checks, not just a successful Helm command.

### File-only migration: blocked for the shipped default image

Do not remove `LICENSE_KEY` or perform a file-only migration with application `1.2.0`. This guide does not name a compatible replacement image and therefore does not provide an executable file-only migration recipe.

For reference only, the new chart field is:

```yaml
app:
  licenseFile:
    existingSecret: "my-license-file"
```

This is a **partial configuration reference**, not a complete upgrade overlay. The named Secret must already exist in the release namespace and contain the key `license` before any Deployment or hook Job uses it; the chart does not create it. The mount is read-only at `/etc/lerian/license`, and the chart supplies `LICENSE_FILE_PATH=/etc/lerian/license/license`. Kubernetes projection does not prove the binary reads or reloads it. With application `1.2.0`, the key remains mandatory even if both sources are delivered.

If an independently verified compatible image is introduced later, verify file support, licence-source precedence, renewal/reload behavior, and the migration executable separately before designing a migration. Do not infer them from a library major version or from these templates alone.

Inspect wiring without assuming `ls` or a shell exists in the distroless app image:

```bash
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[*].envFrom}{"\n"}{.spec.template.spec.containers[*].volumeMounts}{"\n"}{.spec.template.spec.volumes}{"\n"}'
```

This shows references and mount paths, not file contents, successful licence loading, or application health. Do not dump Secret values for troubleshooting.

## Preview changes before upgrading

```bash
helm diff upgrade "$RELEASE" oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace "$NAMESPACE" --version 2.3.0 -f "$VALUES_FILE"
```

> **Note:** Requires an independently reviewed installation of the [helm-diff plugin](https://github.com/databus23/helm-diff). Diff output can expose sensitive values; review it privately. Preview does not prove that application `1.2.0` can start without `LICENSE_KEY`.

## Command to upgrade

```bash
helm upgrade "$RELEASE" oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace "$NAMESPACE" --version 2.3.0 -f "$VALUES_FILE"
```
<!-- {% endraw %} -->
