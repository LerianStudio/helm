<!-- {% raw %} -->
# Helm Upgrade from v4.4.8 to v4.5.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. License key secret](#1-license-key-secret)
- **[Configuration Changes](#configuration-changes)**
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This release adds one optional secret key, `secrets.LICENSE_KEY`. The image tag stays at `3.0.0`, and this upgrade needs no values change. The pods roll once, because the chart version is part of the `helm.sh/chart` label in the pod template.

| Field | v4.4.8 | v4.5.0 |
|-------|--------|--------|
| Chart version | `4.4.8` | `4.5.0` |
| App version | `3.0.0` | `3.0.0` |

## Features

### 1. License key secret

A new `LICENSE_KEY` secret field has been added to support Lerian licensing.

| Setting | v4.4.8 | v4.5.0 |
|---------|--------|--------|
| `secrets.LICENSE_KEY` | not present | `""` |

The license key is rendered into the Secret only when non-empty. With `useExistingSecret=true`, the chart renders no Secret, so a `LICENSE_KEY` you set goes in your own Secret.

**Template behavior change:**

The secrets template now conditionally renders the `LICENSE_KEY` field. All other secret fields are always rendered (even when empty), but `LICENSE_KEY` is only included when a value is provided.

**Before (v4.4.8):**

```yaml
type: Opaque
data:
  {{- range $key, $value := .Values.secrets }}
  {{ $key }}: {{ $value | b64enc | quote }}
  {{- end }}
```

**After (v4.5.0):**

```yaml
type: Opaque
data:
  {{- range $key, $value := .Values.secrets }}
  {{- if or $value (ne $key "LICENSE_KEY") }}
  {{ $key }}: {{ $value | b64enc | quote }}
  {{- end }}
  {{- end }}
```

**Impact:**

- Existing secrets (e.g., `MONGODB_PASS`) continue to be rendered even when empty
- `LICENSE_KEY` is only rendered when a non-empty value is provided

## Configuration Changes

One new secret field has been added. No existing fields were removed or renamed.

| Setting | v4.4.8 | v4.5.0 | Notes |
|---------|--------|--------|-------|
| `secrets.LICENSE_KEY` | absent | `""` | Written into the chart Secret only when non-empty |

## Configuration Reference

### New secret fields

| Field | Default | Description |
|-------|---------|-------------|
| `secrets.LICENSE_KEY` | `""` | Lerian license key. Only rendered into Secret when non-empty. With `useExistingSecret=true`, it goes in your own Secret. |

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.5.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.5.0 \
  -f values.yaml \
  -n product-console
```
<!-- {% endraw %} -->
