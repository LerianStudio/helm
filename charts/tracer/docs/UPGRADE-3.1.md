<!-- {% raw %} -->
# Helm Upgrade from v3.0.1 to v3.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Lerian license key support](#1-lerian-license-key-support)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `3.0.1` to `3.1.0`. This minor release introduces support for a Lerian license key. The license key is stored in the tracer Secret and is only rendered when non-empty. The application version remains unchanged at `1.0.0`.

| Field | v3.0.1 | v3.1.0 |
|-------|--------|--------|
| Chart version | `3.0.1` | `3.1.0` |
| App version | `1.0.0` | `1.0.0` |

## Features

### 1. Lerian license key support

The chart now supports a `LICENSE_KEY` secret value. When set, the license key is rendered into the tracer Secret and passed to the application. The tracer `1.0.0` image this chart deploys does not read `LICENSE_KEY`.

**New secret field:**

| Setting | v3.0.1 | v3.1.0 |
|---------|--------|--------|
| `tracer.secrets.LICENSE_KEY` | n/a | added |

```yaml
tracer:
  secrets:
    DB_PASSWORD: ""
    API_KEY: ""
    LICENSE_KEY: ""
```

**Template changes:**

The `secrets.yaml` template now conditionally renders each secret key. The `LICENSE_KEY` is only rendered when non-empty; all other keys are rendered unconditionally (preserving backward compatibility).

**How to set the license key:**

Add the license key to your custom values file, and pass that file with `-f` to the preview and upgrade commands:

```yaml
tracer:
  secrets:
    LICENSE_KEY: "your-lerian-license-key-here"
```

Or pass it via `--set` during upgrade:

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm \
  --version 3.1.0 \
  -n tracer \
  --reset-then-reuse-values \
  --set tracer.secrets.LICENSE_KEY="your-lerian-license-key-here"
```

Without `--reset-then-reuse-values` (Helm 3.14 or later), `--set` alone resets every value you set on the previous release to the chart default.

With `tracer.useExistingSecret: true` the chart renders no Secret and `tracer.secrets.LICENSE_KEY` has no effect. Add the `LICENSE_KEY` key to the existing Secret named in `tracer.existingSecretName` instead.

> **Note:** Store the license key in a secure secret management system (e.g., HashiCorp Vault, AWS Secrets Manager, Azure Key Vault) and inject it into your Helm values at deployment time. Do not commit the license key to version control.

**Validation:**

After upgrading, verify the `LICENSE_KEY` key is present in the Secret. `kubectl describe` lists key names and sizes, not values:

```bash
kubectl describe secret tracer -n tracer
```

## Configuration Changes

The following table summarizes all configuration changes:

| Setting | v3.0.1 | v3.1.0 | Change |
|---------|--------|--------|--------|
| `tracer.secrets.LICENSE_KEY` | n/a | `""` | Added |

## Migration Steps

No action is required. To pass a license key to the application, set `tracer.secrets.LICENSE_KEY`.

## Preview changes before upgrading

```bash
helm diff upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 3.1.0 -n tracer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 3.1.0 -n tracer
```
<!-- {% endraw %} -->
