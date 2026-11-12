<!-- {% raw %} -->
# Helm Upgrade from v5.3.3 to v5.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Optional signed license file support](#1-optional-signed-license-file-support)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Option 1: Continue using LICENSE_KEY environment variable (no action required)](#option-1-continue-using-license_key-environment-variable-no-action-required)
  - [Option 2: Migrate to signed license file](#option-2-migrate-to-signed-license-file)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This minor chart release adds optional signed-license Secret mounts and `LICENSE_FILE_PATH` injection. It still ships application `1.14.0` across all five components. Those images use `lib-license-go/v4` and require nonempty `LICENSE_KEY`; they do not read `LICENSE_FILE_PATH`. The chart plumbing is not a working file-only licensing alternative for the shipped images. Keep the existing key configuration.

The expected upgrade path is an in-place Helm upgrade with no downtime beyond the normal rolling restart window.

| Component | v5.3.3 | v5.4.0 |
|-----------|--------|--------|
| Chart version | `5.3.3` | `5.4.0` |
| App version | `1.14.0` | `1.14.0` |
| Components | 5 (pix, inbound, outbound, reconciliation, schedule) | 5 (pix, inbound, outbound, reconciliation, schedule) |

## Features

### 1. Optional signed license file support

This release adds chart-level mounting of a signed license file from a Kubernetes Secret on all five components. The shipped application images remain key-only; the mount is preparation for separately validated compatible images, not an alternative to their required `LICENSE_KEY`.

**What changed:**

A new top-level `licenseFile` configuration block was added to `values.yaml`, along with helper templates that mount the license file Secret as a directory on all five components. The validation logic in `_helpers.tpl` was updated to allow either `pix.secrets.LICENSE_KEY` or `licenseFile.existingSecret` to satisfy the license requirement.

**Why it matters:**

The chart can deliver file content without placing it in environment variables. Kubernetes propagation to a mounted volume alone establishes neither application consumption nor reload. Application `1.14.0` does not consume this file.

**Operational impact:**

Existing key-based deployments can retain their licensing configuration. Keep `LICENSE_KEY` for the API and all workers. Setting `licenseFile.existingSecret` does not make their shipped images file-compatible.

**New configuration block:**

| Setting | Default | Description |
|---------|---------|-------------|
| `licenseFile.existingSecret` | `""` | Name of an existing Secret containing the signed license file (key: `license`) |

**New environment variable:**

When `licenseFile.existingSecret` is set, the following environment variable is added to all components:

| Variable | Value | Description |
|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `/etc/lerian/license/license` | Path to the mounted license file |

**Template changes:**

Four new helper templates were added to `_helpers.tpl`:

1. `plugin-br-pix-indirect-btg.licenseSecret` — Returns the Secret name if configured
2. `plugin-br-pix-indirect-btg.licenseFileEnv` — Renders the `LICENSE_FILE_PATH` environment variable
3. `plugin-br-pix-indirect-btg.licenseFileMount` — Renders the volume mount for the license file
4. `plugin-br-pix-indirect-btg.licenseFileVolume` — Renders the Secret volume definition

**Validation logic change:**

**Before (v5.3.3):**

```yaml
{{/* License - Required */}}
{{- if not .Values.pix.secrets.LICENSE_KEY }}
{{- fail "\n\nERROR: pix.secrets.LICENSE_KEY is required. Set your license key in secrets section.\n" }}
{{- end }}
```

**After (v5.4.0):**

```yaml
{{/* License - Required unless a signed licence file is mounted (licenseFile.existingSecret) */}}
{{- if not (or .Values.pix.secrets.LICENSE_KEY (include "plugin-br-pix-indirect-btg.licenseSecret" .)) }}
{{- fail "\n\nERROR: pix.secrets.LICENSE_KEY is required unless licenseFile.existingSecret is set. Set your license key in secrets section.\n" }}
{{- end }}
```

**Example deployment template change (pix component):**

**Before (v5.3.3):**

```yaml
env:
{{- toYaml $h.env | nindent 10 }}
{{- with $infraEnv }}{{ . | nindent 10 }}{{- end }}
{{- if $otelEnabled }}
- name: "HOST_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
{{- end }}
```

**After (v5.4.0):**

```yaml
env:
{{- toYaml $h.env | nindent 10 }}
{{- with (include "plugin-br-pix-indirect-btg.licenseFileEnv" . | trim) }}{{ . | nindent 10 }}{{- end }}
{{- with $infraEnv }}{{ . | nindent 10 }}{{- end }}
{{- if $otelEnabled }}
- name: "HOST_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
{{- end }}
```

The `LICENSE_FILE_PATH` environment variable is conditionally added when `licenseFile.existingSecret` is set.

**Volume mount changes (pix and reconciliation components):**

The `pix` and `reconciliation` components already had conditional volume mounts for mTLS certificates. The license file mount is added alongside the existing mTLS mount.

**Before (v5.3.3):**

```yaml
{{- if .Values.mtls.enabled }}
volumeMounts:
  {{- include "plugin-br-pix-indirect-btg.mtlsVolumeMount" . | nindent 12 }}
{{- end }}
```

**After (v5.4.0):**

```yaml
{{- $licMount := include "plugin-br-pix-indirect-btg.licenseFileMount" . | trim }}
{{- if or .Values.mtls.enabled $licMount }}
volumeMounts:
  {{- if .Values.mtls.enabled }}
  {{- include "plugin-br-pix-indirect-btg.mtlsVolumeMount" . | nindent 12 }}
  {{- end }}
  {{- with $licMount }}
  {{- . | nindent 12 }}
  {{- end }}
{{- end }}
```

**Volume definition changes (pix and reconciliation components):**

**Before (v5.3.3):**

```yaml
{{- if .Values.mtls.enabled }}
volumes:
  {{- include "plugin-br-pix-indirect-btg.mtlsVolume" . | nindent 8 }}
{{- end }}
```

**After (v5.4.0):**

```yaml
{{- $licVolume := include "plugin-br-pix-indirect-btg.licenseFileVolume" . | trim }}
{{- if or .Values.mtls.enabled $licVolume }}
volumes:
  {{- if .Values.mtls.enabled }}
  {{- include "plugin-br-pix-indirect-btg.mtlsVolume" . | nindent 8 }}
  {{- end }}
  {{- with $licVolume }}
  {{- . | nindent 8 }}
  {{- end }}
{{- end }}
```

**Volume mount changes (inbound, outbound, and schedule components):**

These components did not previously have volume mounts. The license file mount is conditionally added when configured.

**Before (v5.3.3):**

```yaml
startupProbe: {{- toYaml $h.startupProbe | nindent 12 }}
livenessProbe: {{- toYaml $h.livenessProbe | nindent 12 }}
readinessProbe: {{- toYaml $h.readinessProbe | nindent 12 }}
```

**After (v5.4.0):**

```yaml
startupProbe: {{- toYaml $h.startupProbe | nindent 12 }}
livenessProbe: {{- toYaml $h.livenessProbe | nindent 12 }}
readinessProbe: {{- toYaml $h.readinessProbe | nindent 12 }}
{{- with (include "plugin-br-pix-indirect-btg.licenseFileMount" . | trim) }}
volumeMounts:
  {{- . | nindent 12 }}
{{- end }}
```

**Volume definition changes (inbound, outbound, and schedule components):**

**Before (v5.3.3):**

```yaml
{{- with .Values.inbound.tolerations }}
tolerations:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

**After (v5.4.0):**

```yaml
{{- with .Values.inbound.tolerations }}
tolerations:
  {{- toYaml . | nindent 8 }}
{{- end }}
{{- with (include "plugin-br-pix-indirect-btg.licenseFileVolume" . | trim) }}
volumes:
  {{- . | nindent 8 }}
{{- end }}
```

> **Important:** The license file Secret must contain a key named `license` with the signed license file content. The Secret is mounted as a directory (not using `subPath`) to ensure that Secret updates propagate to running pods without requiring a restart.

> **Note:** The application requires an image based on `lib-license-go` v5 or later to support file mode permissions when using the signed license file feature.

## Configuration Reference

**New top-level configuration block:**

```yaml
# -- Optional signed licence file, an alternative to pix.secrets.LICENSE_KEY. The Secret is mounted
# read-only as the directory /etc/lerian/license (key `license`) on every component. File mode needs
# an image on lib-license-go v5.
licenseFile:
  existingSecret: ""
```

**Configuration comparison:**

| Setting | v5.3.3 | v5.4.0 |
|---------|--------|--------|
| Chart version | `5.3.3` | `5.4.0` |
| App version | `1.14.0` | `1.14.0` |
| `licenseFile.existingSecret` | (not present) | `""` (optional) |

## Migration Steps

No licensing-value migration is required for the default images. Continue with Option 1; Option 2 explains why file-only migration is unavailable for this release.

### Option 1: Continue using LICENSE_KEY environment variable (no action required)

If you are currently using `pix.secrets.LICENSE_KEY` and do not need to migrate to the signed license file, no configuration changes are required. The existing license key configuration continues to work as before.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.4.0 -n midaz-plugins
```

3. Verify all pods are running and healthy:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg
```

> **Note:** Rendering both releases with identical key-based values changes the ConfigMap/Secret checksums in all five application pod templates, even with file mounting disabled. Expect a rolling restart; single-replica workloads may be interrupted.

### Option 2: Migrate to signed license file

**Not supported by the default `1.14.0` images in chart `5.4.0`.** Do not remove `LICENSE_KEY`: the API and all four workers reject an empty key before initializing the v4 license client. Keeping the key while mounting a file does not enable file licensing either; this application version does not read `LICENSE_FILE_PATH`.

The chart prepares a read-only directory mount at `/etc/lerian/license` from an existing Secret with key `license`, and injects the file path on all five components. Its relaxed render-time validation is not proof that an application image can consume the file. This guide does not prescribe a compatible replacement image set; no such set has been validated here. A later file-mode adoption needs a separately verified application release, consistent pins for every component, reviewed file/key precedence, and a tested upgrade plan.

A projected Secret update only changes mounted file content. It does not prove application reload or key fallback. No file-only migration or restart-free license rotation is supported by the shipped `1.14.0` images.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.4.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.4.0
```
<!-- {% endraw %} -->
