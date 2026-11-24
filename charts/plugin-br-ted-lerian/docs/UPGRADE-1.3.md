<!-- {% raw %} -->
# Helm Upgrade from v1.2.1 to v1.3.0

## Topics

- **[Features](#features)**
  - [1. Anti-Fraud Secrets Backend Configuration](#1-anti-fraud-secrets-backend-configuration)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Features

### 1. Anti-Fraud Secrets Backend Configuration

This release adds support for configuring the anti-fraud secrets backend provider through the ConfigMap.

| Setting | v1.2.1 | v1.3.0 |
|---------|--------|--------|
| `ANTIFRAUD_SECRETS_BACKEND` environment variable | Not available | Optional (rendered when set in `configmap`) |

**What changed:**

The chart now supports an optional `ANTIFRAUD_SECRETS_BACKEND` configuration key that can be set in the `plugin-br-ted-lerian.configmap` values block. When set, the ConfigMap template renders this environment variable for the application container.

**Why it matters:**

The application can integrate with external secrets management systems for anti-fraud configuration. This release allows operators to specify which backend provider to use (`aws` for AWS Secrets Manager or `vault` for HashiCorp Vault) without requiring custom environment variable overrides.

The application does not have a built-in default for this setting — it must be explicitly configured if anti-fraud secrets integration is required.

**Configuration:**

**After (v1.3.0):**

```yaml
plugin-br-ted-lerian:
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

or

```yaml
plugin-br-ted-lerian:
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "vault"
```

**New environment variable:**
- `ANTIFRAUD_SECRETS_BACKEND`: Specifies the secrets backend provider (`aws` or `vault`). No default value; only rendered when explicitly set in `configmap`.

**Template behavior:**

The ConfigMap template includes conditional rendering logic:

**Before (v1.2.1):**

The `ANTIFRAUD_SECRETS_BACKEND` key was not supported.

**After (v1.3.0):**

```yaml
{{- $afBackend := index ((index .Values "plugin-br-ted-lerian").configmap | default dict) "ANTIFRAUD_SECRETS_BACKEND" }}
{{- if and $afBackend (not (has "ANTIFRAUD_SECRETS_BACKEND" $extraNames)) }}
ANTIFRAUD_SECRETS_BACKEND: {{ $afBackend | quote }}
{{- end }}
```

The template only renders `ANTIFRAUD_SECRETS_BACKEND` when:
1. The key is set in `plugin-br-ted-lerian.configmap`
2. The key is not already present in `plugin-br-ted-lerian.extraEnvVars`

> **Note:** If you set `ANTIFRAUD_SECRETS_BACKEND` in both `configmap` and `extraEnvVars`, the `extraEnvVars` value takes precedence and the `configmap` value is ignored.

**Impact:**

- Operators can now configure anti-fraud secrets backend integration through standard values configuration
- No impact on existing deployments — this is an opt-in feature
- The application behavior is unchanged if `ANTIFRAUD_SECRETS_BACKEND` is not set

**Migration:**

No action required unless you need anti-fraud secrets integration.

#### Enabling anti-fraud secrets integration

If your deployment requires anti-fraud secrets from AWS Secrets Manager:

```yaml
plugin-br-ted-lerian:
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

If your deployment requires anti-fraud secrets from HashiCorp Vault:

```yaml
plugin-br-ted-lerian:
  configmap:
    ANTIFRAUD_SECRETS_BACKEND: "vault"
```

> **Important:** Setting `ANTIFRAUD_SECRETS_BACKEND` alone is not sufficient for a working integration. You must also configure the appropriate IAM roles, service account annotations, or Vault authentication mechanisms required by your chosen backend. Refer to your secrets management system's documentation for complete setup instructions.

#### Using extraEnvVars instead

If you prefer to set this variable through `extraEnvVars`:

```yaml
plugin-br-ted-lerian:
  extraEnvVars:
    - name: ANTIFRAUD_SECRETS_BACKEND
      value: "aws"
```

This approach takes precedence over the `configmap` setting and is useful when you need to source the value from a Secret or ConfigMap reference:

```yaml
plugin-br-ted-lerian:
  extraEnvVars:
    - name: ANTIFRAUD_SECRETS_BACKEND
      valueFrom:
        secretKeyRef:
          name: antifraud-config
          key: backend
```

---

## Configuration Reference

### New ConfigMap Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `plugin-br-ted-lerian.configmap.ANTIFRAUD_SECRETS_BACKEND` | string | `""` (not rendered) | Anti-fraud secrets backend provider: `aws` or `vault` |

**Example:**

```yaml
plugin-br-ted-lerian:
  configmap:
    # Anti-fraud secrets backend configuration
    ANTIFRAUD_SECRETS_BACKEND: "aws"
    
    # Other existing configmap keys remain unchanged
    ENV_NAME: "production"
    LOG_LEVEL: "info"
```

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.3.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.3.0
```
<!-- {% endraw %} -->
