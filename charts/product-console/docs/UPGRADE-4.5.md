<!-- {% raw %} -->
# Helm Upgrade from v4.4.8 to v4.5.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. License key requirement](#1-license-key-requirement)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that introduces a new mandatory license key requirement for the product-console application. The application will refuse to boot without a valid license key starting from this version.

| Field | v4.4.8 | v4.5.0 |
|-------|--------|--------|
| Chart version | `4.4.8` | `4.5.0` |
| App version | `3.0.0` | `3.0.0` |

## Features

### 1. License key requirement

A new `LICENSE_KEY` secret field has been added to support Lerian licensing. The product-console application now requires a valid license key to start. Without it, the application will refuse to boot.

| Setting | v4.4.8 | v4.5.0 |
|---------|--------|--------|
| `secrets.LICENSE_KEY` | not present | `""` (required) |

The license key is rendered into the Secret only when non-empty. When using `useExistingSecret=true`, operators must include `LICENSE_KEY` in their own Secret.

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
- The application will fail to start if `LICENSE_KEY` is missing or invalid

> **Warning:** The product-console application will refuse to boot without a valid `LICENSE_KEY`. Ensure you have obtained a license key from Lerian Studio before upgrading.

## Configuration Changes

One new secret field has been added. No existing fields were removed or renamed.

| Setting | v4.4.8 | v4.5.0 | Notes |
|---------|--------|--------|-------|
| `secrets.LICENSE_KEY` | absent | `""` | Required; application refuses to boot without valid license |

## Migration Steps

This upgrade requires setting a valid license key before or during the upgrade. The application will not start without it.

**Required migration process:**

1. **Obtain a license key** from Lerian Studio support (support@lerian.studio) before upgrading.

2. **Choose your secret management approach:**

   #### Option 1: Set license key in values.yaml

   Add the license key to your `values.yaml`:

   ```yaml
   secrets:
     LICENSE_KEY: "your-license-key-here"
   ```

   #### Option 2: Use --set flag during upgrade

   Pass the license key directly during the upgrade command:

   ```bash
   helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
     --version 4.5.0 \
     --set secrets.LICENSE_KEY="your-license-key-here" \
     -n product-console
   ```

   #### Option 3: Use existing Secret

   If you manage secrets externally (`useExistingSecret=true`), add `LICENSE_KEY` to your existing Secret:

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: product-console-secrets
   type: Opaque
   data:
     LICENSE_KEY: <base64-encoded-license-key>
     MONGODB_PASS: <base64-encoded-password>
     # ... other secrets
   ```

   Then reference it in your values:

   ```yaml
   useExistingSecret: true
   existingSecretName: "product-console-secrets"
   ```

3. **Preview the changes** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. **Run the upgrade command** with the license key configured (see [Command to upgrade](#command-to-upgrade)).

5. **Verify the deployment** after upgrade:

   ```bash
   kubectl get pods -n product-console
   ```

6. **Check application logs** to confirm successful startup with license validation:

   ```bash
   kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
   ```

> **Important:** If the license key is missing, invalid, or expired, the application will log an error and exit. Pods will enter `CrashLoopBackOff` state. Ensure you have a valid license key before upgrading.

> **Note:** The upgrade triggers a rolling restart of the `product-console` deployment. Pods will not become Ready until the license key is successfully validated.

## Configuration Reference

### New secret fields

| Field | Default | Description |
|-------|---------|-------------|
| `secrets.LICENSE_KEY` | `""` | Lerian license key. Required for application startup. Only rendered into Secret when non-empty. With `useExistingSecret=true`, include this key in your own Secret. |

### Secret management options

**Option 1: Chart-managed Secret (default)**

```yaml
useExistingSecret: false
secrets:
  LICENSE_KEY: "your-license-key-here"
  MONGODB_PASS: "your-mongodb-password"
  # ... other secrets
```

**Option 2: External Secret**

```yaml
useExistingSecret: true
existingSecretName: "product-console-secrets"
```

Ensure your external Secret includes the `LICENSE_KEY` field:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: product-console-secrets
type: Opaque
data:
  LICENSE_KEY: <base64-encoded-license-key>
  MONGODB_PASS: <base64-encoded-password>
```

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.5.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

**With license key in values.yaml:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.5.0 \
  -f values.yaml \
  -n product-console
```

**With license key via --set flag:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.5.0 \
  --set secrets.LICENSE_KEY="your-license-key-here" \
  -n product-console
```

**With existing Secret:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.5.0 \
  --set useExistingSecret=true \
  --set existingSecretName="product-console-secrets" \
  -n product-console
```
<!-- {% endraw %} -->
