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

This guide covers the `tracer` chart upgrade from `3.0.1` to `3.1.0`. This minor release introduces support for a Lerian license key, which the application requires to boot. The license key is stored in the tracer Secret and is only rendered when non-empty. The application version remains unchanged at `1.0.0`.

| Field | v3.0.1 | v3.1.0 |
|-------|--------|--------|
| Chart version | `3.0.1` | `3.1.0` |
| App version | `1.0.0` | `1.0.0` |

> **Important:** The application refuses to boot without a valid license key. If you are upgrading an existing deployment, you must obtain a Lerian license key and set it in your values file before upgrading.

## Features

### 1. Lerian license key support

The chart now supports a `LICENSE_KEY` secret value. When set, the license key is rendered into the tracer Secret and passed to the application. The application reads this key at startup and refuses to boot if the key is missing or invalid.

**New secret field:**

| Setting | v3.0.1 | v3.1.0 |
|---------|--------|--------|
| `tracer.secrets.LICENSE_KEY` | n/a | added |

```yaml
tracer:
  secrets:
    DB_PASSWORD: "lerian"
    API_KEY: ""
    LICENSE_KEY: ""
```

**Template changes:**

The `secrets.yaml` template now conditionally renders each secret key. The `LICENSE_KEY` is only rendered when non-empty; all other keys are rendered unconditionally (preserving backward compatibility).

**Before (v3.0.1):**

```yaml
type: Opaque
stringData:
  {{- range $key, $value := .Values.tracer.secrets }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

**After (v3.1.0):**

```yaml
type: Opaque
stringData:
  {{- range $key, $value := .Values.tracer.secrets }}
  {{- if or $value (ne $key "LICENSE_KEY") }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
```

**Operational impact:**

- **Existing deployments:** The application will fail to start after the upgrade if `LICENSE_KEY` is not set. You must obtain a valid Lerian license key and add it to your values file before upgrading.
- **New deployments:** The `LICENSE_KEY` must be set in `tracer.secrets.LICENSE_KEY` or the application will refuse to boot.
- **Empty license key:** If `LICENSE_KEY` is left empty (the default), the key is not rendered into the Secret. The application will detect the missing key and exit with an error during startup.

> **Warning:** Do not upgrade to v3.1.0 without a valid license key. The application will enter a crash loop if the license key is missing or invalid.

**How to obtain a license key:**

Contact Lerian Studio support at `support@lerian.studio` to obtain a license key for your deployment.

**How to set the license key:**

Add the license key to your custom values file:

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
  --set tracer.secrets.LICENSE_KEY="your-lerian-license-key-here"
```

> **Note:** Store the license key in a secure secret management system (e.g., HashiCorp Vault, AWS Secrets Manager, Azure Key Vault) and inject it into your Helm values at deployment time. Do not commit the license key to version control.

**Validation:**

After upgrading, verify the license key is present in the Secret:

```bash
kubectl get secret tracer-secret -n tracer -o jsonpath='{.data.LICENSE_KEY}' | base64 -d
```

If the command returns an empty string or the key is missing, the application will fail to start. Check the application logs:

```bash
kubectl logs -n tracer -l app.kubernetes.io/name=tracer,app.kubernetes.io/component=tracer --tail=50
```

Look for license-related error messages in the startup logs.

## Configuration Changes

The following table summarizes all configuration changes:

| Setting | v3.0.1 | v3.1.0 | Change |
|---------|--------|--------|--------|
| `tracer.secrets.LICENSE_KEY` | n/a | `""` | Added |

## Migration Steps

This upgrade requires a valid Lerian license key. The application will not start without it.

**Recommended upgrade process:**

1. Obtain a Lerian license key from Lerian Studio support (`support@lerian.studio`).

2. Add the license key to your custom values file:

   ```yaml
   tracer:
     secrets:
       LICENSE_KEY: "your-lerian-license-key-here"
   ```

3. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. Apply the upgrade:

   ```bash
   helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 3.1.0 -n tracer -f your-values.yaml
   ```

5. Verify the license key is present in the Secret:

   ```bash
   kubectl get secret tracer-secret -n tracer -o jsonpath='{.data.LICENSE_KEY}' | base64 -d
   ```

6. Verify all pods are running and healthy:

   ```bash
   kubectl get pods -n tracer
   ```

7. Check application logs for successful startup and license validation:

   ```bash
   kubectl logs -n tracer -l app.kubernetes.io/name=tracer,app.kubernetes.io/component=tracer --tail=50
   ```

> **Important:** If the application fails to start with license-related errors, verify the license key is correct and has not been truncated or modified. Contact Lerian Studio support if the issue persists.

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
