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

This is a minor release that adds support for an optional signed license file as an alternative to the `LICENSE_KEY` environment variable. The application version remains at `1.14.0` across all components. No configuration changes are required — the existing `pix.secrets.LICENSE_KEY` configuration continues to work as before.

The expected upgrade path is an in-place Helm upgrade with no downtime beyond the normal rolling restart window.

| Component | v5.3.3 | v5.4.0 |
|-----------|--------|--------|
| Chart version | `5.3.3` | `5.4.0` |
| App version | `1.14.0` | `1.14.0` |
| Components | 5 (pix, inbound, outbound, reconciliation, schedule) | 5 (pix, inbound, outbound, reconciliation, schedule) |

## Features

### 1. Optional signed license file support

This release adds support for mounting a signed license file as an alternative to providing the license key via the `LICENSE_KEY` environment variable. The license file is mounted read-only from a Kubernetes Secret and made available to all components.

**What changed:**

A new top-level `licenseFile` configuration block was added to `values.yaml`, along with helper templates that mount the license file Secret as a directory on all five components. The validation logic in `_helpers.tpl` was updated to allow either `pix.secrets.LICENSE_KEY` or `licenseFile.existingSecret` to satisfy the license requirement.

**Why it matters:**

Signed license files provide an alternative licensing mechanism that may be required for certain deployment scenarios or compliance requirements. The file-based approach allows license rotation without modifying environment variables, as Kubernetes automatically propagates Secret updates to mounted volumes.

**Operational impact:**

This change is fully backward-compatible. Existing deployments using `pix.secrets.LICENSE_KEY` continue to work without modification. Operators who wish to use the signed license file feature must create a Secret containing the license file and reference it via `licenseFile.existingSecret`.

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

This upgrade is fully backward-compatible and requires no immediate action. Choose one of the following options based on your licensing requirements.

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

> **Note:** The upgrade triggers a rolling restart of all deployments because the template changes add conditional logic for the license file mount. Depending on your replica count, this may cause brief service interruptions.

### Option 2: Migrate to signed license file

If you wish to use the signed license file feature, follow these steps to create the required Secret and update your Helm values.

**Prerequisites:**

- You must have a signed license file provided by Lerian Studio
- The application image must be based on `lib-license-go` v5 or later

**Migration steps:**

1. Create a Kubernetes Secret containing your signed license file:

```bash
kubectl create secret generic plugin-br-pix-indirect-btg-license \
  --from-file=license=/path/to/your/license-file \
  -n midaz-plugins
```

> **Important:** The Secret key must be named `license` exactly as shown above. The chart expects this specific key name.

2. Update your `values.yaml` to reference the license file Secret:

```yaml
licenseFile:
  existingSecret: "plugin-br-pix-indirect-btg-license"
```

3. (Optional) Remove the `LICENSE_KEY` environment variable from your configuration:

```yaml
pix:
  secrets:
    LICENSE_KEY: ""  # Can be removed when using licenseFile
```

> **Note:** You can keep both `LICENSE_KEY` and `licenseFile.existingSecret` configured. The application will use the license file when `LICENSE_FILE_PATH` is set, falling back to `LICENSE_KEY` if the file is not available.

4. Review the changes using the helm-diff plugin:

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.4.0 -n midaz-plugins -f values.yaml
```

5. Run the upgrade command with your updated values:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.4.0 -n midaz-plugins -f values.yaml
```

6. Verify the license file is mounted correctly on all pods:

```bash
kubectl exec -n midaz-plugins deployment/plugin-br-pix-indirect-btg -- ls -la /etc/lerian/license/
```

You should see the `license` file with read-only permissions.

7. Verify the `LICENSE_FILE_PATH` environment variable is set:

```bash
kubectl exec -n midaz-plugins deployment/plugin-br-pix-indirect-btg -- env | grep LICENSE_FILE_PATH
```

Expected output:

```
LICENSE_FILE_PATH=/etc/lerian/license/license
```

**License file rotation:**

When using the signed license file, you can rotate the license without restarting pods:

1. Update the Secret with the new license file:

```bash
kubectl create secret generic plugin-br-pix-indirect-btg-license \
  --from-file=license=/path/to/new/license-file \
  --dry-run=client -o yaml | kubectl apply -n midaz-plugins -f -
```

2. Wait for Kubernetes to propagate the Secret update to the mounted volumes (typically 60-90 seconds).

3. The application will automatically detect and reload the updated license file.

> **Note:** Secret propagation delay depends on your cluster's kubelet sync period. If you need immediate license updates, you can trigger a rolling restart after updating the Secret.

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
