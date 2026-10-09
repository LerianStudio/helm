# Helm Upgrade from v0.4.8 to v0.5.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Payment Order Signing Support](#1-payment-order-signing-support)
  - [2. Application Version Bump](#2-application-version-bump)
- **[Configuration Reference](#configuration-reference)**
  - [Payment Signing Configuration](#payment-signing-configuration)
  - [Environment Variables](#environment-variables)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Signing Requirements](#step-1-review-signing-requirements)
  - [Step 2: Configure Signing Credentials (If Required)](#step-2-configure-signing-credentials-if-required)
  - [Step 3: Update Image Tags](#step-3-update-image-tags)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **minor version bump** from v0.4.8 to v0.5.0, introducing support for **signed JDPI payment orders** and bumping the application version to 1.1.1. The chart now allows operators to configure a private key and certificate for signing payment orders when required by the JD (Jurisdição de Dados) provider.

| Setting | v0.4.8 | v0.5.0 |
|---------|---------|---------|
| Chart Version | 0.4.8 | 0.5.0 |
| App Version | 1.1.0 | 1.1.1 |
| Payment Signing | Not supported | Optional via new secrets |
| Migrations Image Tag | 1.1.0 | 1.1.1 |

## Features

### 1. Payment Order Signing Support

The chart now supports **optional cryptographic signing** of JDPI payment orders. This feature is required when the JD provider enforces signed orders (e.g., when running HashAtivo). When signing is not configured, payment orders are sent unsigned, which is acceptable for JD providers that do not enforce signature validation.

**Key characteristics:**

- **Optional by design**: With neither PEM configured, the application sends unsigned orders
- **Both or neither**: The chart enforces that either both the private key and certificate are provided, or neither — providing only one will fail the render
- **Multi-tenant incompatibility**: Payment signing configuration is ignored when `MULTI_TENANT_ENABLED=true`, as the Tenant Manager owns credential resolution
- **Algorithm selection**: Operators can choose between `ECDSA_P256_SHA256` (default), `ECDSA_P384_SHA384`, or `RSA_PKCS1_SHA256`

**New configuration fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY` | PEM string | No | Private key used to sign payment orders |
| `api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE` | PEM string | No | Certificate registered in JDPI Cabine for the signing key |
| `api.configmap.JD_PAYMENT_SIGNING_ALGORITHM` | String | No | Signature algorithm: `ECDSA_P256_SHA256`, `ECDSA_P384_SHA384`, or `RSA_PKCS1_SHA256` |

**Validation rules:**

The chart performs the following validations at render time:

1. **Both or neither**: If only one of `JD_PAYMENT_SIGNING_PRIVATE_KEY` or `JD_PAYMENT_SIGNING_CERTIFICATE` is set, the render fails with a descriptive error
2. **PEM format**: Both values must contain a PEM header (`-----BEGIN ...-----`) unless using ArgoCD Vault Plugin placeholders (`<path:...>`)
3. **Algorithm validation**: If `JD_PAYMENT_SIGNING_ALGORITHM` is set, it must be one of the three supported values
4. **Multi-tenant bypass**: When `MULTI_TENANT_ENABLED=true`, signing configuration is not rendered or validated

**Template changes:**

The chart adds three new template helpers in `_helpers.tpl`:

1. `plugin-br-pix-jd.paymentSigningApplies` — determines if signing configuration should be rendered (false when multi-tenant is enabled)
2. `plugin-br-pix-jd.paymentSigningEnv` — renders the `JD_PAYMENT_SIGNING_ALGORITHM` environment variable into the ConfigMap (only when explicitly set)
3. `plugin-br-pix-jd.paymentSigningSecrets` — renders the two PEM values as base64-encoded Secret data

**Before (v0.4.8):**

```yaml
# api/secrets.yaml
data:
  LICENSE_KEY: {{ .Values.api.secrets.LICENSE_KEY | b64enc | quote }}
  REDIS_PASSWORD: {{ .Values.api.secrets.REDIS_PASSWORD | b64enc | quote }}
```

**After (v0.5.0):**

```yaml
# api/secrets.yaml
data:
  LICENSE_KEY: {{ .Values.api.secrets.LICENSE_KEY | b64enc | quote }}
  REDIS_PASSWORD: {{ .Values.api.secrets.REDIS_PASSWORD | b64enc | quote }}
  {{- with (include "plugin-br-pix-jd.paymentSigningSecrets" $) }}
  {{- . | nindent 2 }}
  {{- end }}
```

The ConfigMap merge order is updated to include signing configuration:

**Before (v0.4.8):**

```yaml
{{- $data := mergeOverwrite $platform $domain $qrcode $mt $streaming $rateLimit $corsEnv $http (.Values.api.extraConfigmap | default dict) -}}
```

**After (v0.5.0):**

```yaml
{{- $data := mergeOverwrite $platform $domain $qrcode $signing $mt $streaming $rateLimit $corsEnv $http (.Values.api.extraConfigmap | default dict) -}}
```

### 2. Application Version Bump

The application version has been bumped from **1.1.0** to **1.1.1** across all components:

| Component | v0.4.8 | v0.5.0 |
|-----------|---------|---------|
| API (`appVersion`) | 1.1.0 | 1.1.1 |
| Migrations (`migrations.image.tag`) | 1.1.0 | 1.1.1 |

This version bump includes the payment signing feature implementation in the application itself. Operators who pin image tags explicitly in their values files should update them to match.

## Configuration Reference

### Payment Signing Configuration

The payment signing feature is configured through three new values:

```yaml
api:
  configmap:
    # Optional: signature algorithm selection
    # Default: ECDSA_P256_SHA256 (when signing is enabled)
    # Valid values: ECDSA_P256_SHA256, ECDSA_P384_SHA384, RSA_PKCS1_SHA256
    JD_PAYMENT_SIGNING_ALGORITHM: ""
  
  secrets:
    # Optional: PEM-encoded private key for signing payment orders
    # Must be provided together with JD_PAYMENT_SIGNING_CERTIFICATE
    JD_PAYMENT_SIGNING_PRIVATE_KEY: ""
    
    # Optional: PEM-encoded certificate registered in JDPI Cabine
    # Must be provided together with JD_PAYMENT_SIGNING_PRIVATE_KEY
    JD_PAYMENT_SIGNING_CERTIFICATE: ""
```

**Loading PEM files:**

The recommended approach is to use `--set-file` to load PEM files directly:

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm \
  --version 0.5.0 \
  --set-file api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=./signing-key.pem \
  --set-file api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE=./signing-cert.pem \
  -n plugin-br-pix-jd
```

Alternatively, use YAML block scalars in your values file:

```yaml
api:
  secrets:
    JD_PAYMENT_SIGNING_PRIVATE_KEY: |
      -----BEGIN PRIVATE KEY-----
      MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
      -----END PRIVATE KEY-----
    
    JD_PAYMENT_SIGNING_CERTIFICATE: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKZ5Z5Z5Z5Z5MA0GCSqGSIb3DQEBBQUA...
      -----END CERTIFICATE-----
```

### Environment Variables

The following new environment variable is added to the API ConfigMap:

| Variable | Default | Description |
|----------|---------|-------------|
| `JD_PAYMENT_SIGNING_ALGORITHM` | `ECDSA_P256_SHA256` (app default) | Signature algorithm for payment orders. Only rendered when explicitly set in values. Must match the key type in `JD_PAYMENT_SIGNING_PRIVATE_KEY`. |

The following new Secret keys are added to the API Secret:

| Key | Required | Description |
|-----|----------|-------------|
| `JD_PAYMENT_SIGNING_PRIVATE_KEY` | No | PEM-encoded private key for signing payment orders. Must be provided with `JD_PAYMENT_SIGNING_CERTIFICATE` or omitted entirely. |
| `JD_PAYMENT_SIGNING_CERTIFICATE` | No | PEM-encoded certificate registered in JDPI Cabine. Must be provided with `JD_PAYMENT_SIGNING_PRIVATE_KEY` or omitted entirely. |

## Migration Steps

### Step 1: Review Signing Requirements

Determine whether your JD provider requires signed payment orders:

- **HashAtivo enabled**: Signing is **required**. Proceed to Step 2.
- **HashAtivo disabled**: Signing is **optional**. You can upgrade without configuring signing credentials.

> **Note:** If you are unsure whether your JD provider enforces signed orders, consult your JD provider documentation or contact their support. The application will send unsigned orders by default, which will be rejected by JD providers that enforce signature validation.

### Step 2: Configure Signing Credentials (If Required)

If your JD provider requires signed payment orders, you must provide both the private key and certificate.

#### Option 1: Use `--set-file` (Recommended)

Load PEM files directly during upgrade:

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm \
  --version 0.5.0 \
  --set-file api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=./signing-key.pem \
  --set-file api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE=./signing-cert.pem \
  -n plugin-br-pix-jd
```

#### Option 2: Add to `values.yaml`

Add the PEM content to your values file using YAML block scalars:

```yaml
api:
  secrets:
    JD_PAYMENT_SIGNING_PRIVATE_KEY: |
      -----BEGIN PRIVATE KEY-----
      MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
      -----END PRIVATE KEY-----
    
    JD_PAYMENT_SIGNING_CERTIFICATE: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKZ5Z5Z5Z5Z5MA0GCSqGSIb3DQEBBQUA...
      -----END CERTIFICATE-----
```

#### Option 3: Use an Existing Secret

If you manage secrets externally (e.g., via External Secrets Operator), ensure your existing Secret includes the two new keys:

```yaml
api:
  existingSecret:
    name: plugin-pix-credentials
```

The Secret must contain:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: plugin-pix-credentials
type: Opaque
data:
  LICENSE_KEY: <base64>
  REDIS_PASSWORD: <base64>
  JD_PAYMENT_SIGNING_PRIVATE_KEY: <base64-encoded-pem>
  JD_PAYMENT_SIGNING_CERTIFICATE: <base64-encoded-pem>
```

**Algorithm selection:**

If your key is not ECDSA P-256, set the algorithm explicitly:

```yaml
api:
  configmap:
    JD_PAYMENT_SIGNING_ALGORITHM: "ECDSA_P384_SHA384"  # or RSA_PKCS1_SHA256
```

> **Important:** The algorithm must match the key type in `JD_PAYMENT_SIGNING_PRIVATE_KEY`. The chart validates the algorithm value but cannot verify it matches the key — a mismatch will cause runtime signature failures.

### Step 3: Update Image Tags

If you pin image tags explicitly in your values file, update them to the new application version:

```yaml
api:
  image:
    tag: "1.1.1"

migrations:
  image:
    tag: "1.1.1"
```

> **Note:** If you rely on the chart's `appVersion` default (recommended), no action is required — the chart will automatically use `1.1.1`.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.0 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.0 -n plugin-br-pix-jd
```
