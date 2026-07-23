# Helm Upgrade from v7.1.0 to v7.2.0

# Topics

- ***[Features](#features)***
    - [1. Streaming Backend Authentication Support](#1-streaming-backend-authentication-support)
- ***[Configuration Reference](#configuration-reference)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Features

### 1. Streaming Backend Authentication Support

The chart now supports SASL authentication and custom TLS CA certificates for streaming backends (lib-streaming), enabling secure connections to Kafka, Pulsar, or other message brokers that require authentication and private certificate authorities.

**New secret variables:**

```yaml
fees:
  secrets:
    STREAMING_SASL_PASSWORD: ""
    STREAMING_TLS_CA_CERT: ""
```

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAMING_SASL_PASSWORD` | `""` | SASL password for authenticating to the streaming backend (e.g., Kafka SASL/PLAIN or SASL/SCRAM) |
| `STREAMING_TLS_CA_CERT` | `""` | PEM-encoded TLS CA certificate for verifying the streaming backend's TLS certificate (required when using private CAs) |

**Why this matters:**

- **STREAMING_SASL_PASSWORD**: Enables secure authentication to production message brokers that require SASL credentials, preventing unauthorized access to streaming topics.
- **STREAMING_TLS_CA_CERT**: Allows connection to streaming backends using private or self-signed TLS certificates, common in enterprise and air-gapped environments.

**Template changes:**

**Before (v7.1.0):**

```yaml
stringData:
  # ... existing secrets ...
  {{- if .Values.fees.secrets.MULTI_TENANT_REDIS_PASSWORD }}
  MULTI_TENANT_REDIS_PASSWORD: {{ .Values.fees.secrets.MULTI_TENANT_REDIS_PASSWORD | quote }}
  {{- end }}
  {{- end }}
```

**After (v7.2.0):**

```yaml
stringData:
  # ... existing secrets ...
  {{- if .Values.fees.secrets.MULTI_TENANT_REDIS_PASSWORD }}
  MULTI_TENANT_REDIS_PASSWORD: {{ .Values.fees.secrets.MULTI_TENANT_REDIS_PASSWORD | quote }}
  {{- end }}
  {{- end }}
  # STREAMING SECRETS (lib-streaming — SASL password + TLS CA, operator-provided)
  {{- if .Values.fees.secrets.STREAMING_SASL_PASSWORD }}
  STREAMING_SASL_PASSWORD: {{ .Values.fees.secrets.STREAMING_SASL_PASSWORD | quote }}
  {{- end }}
  {{- if .Values.fees.secrets.STREAMING_TLS_CA_CERT }}
  STREAMING_TLS_CA_CERT: {{ .Values.fees.secrets.STREAMING_TLS_CA_CERT | quote }}
  {{- end }}
```

**Operational impact:**

These secrets are optional and only required when your streaming backend uses SASL authentication or a private TLS CA. If you are using a streaming backend without authentication or with publicly-trusted certificates, no action is required.

**Example: Configuring SASL authentication for Kafka**

```yaml
fees:
  secrets:
    STREAMING_SASL_PASSWORD: "your-kafka-sasl-password"
```

**Example: Configuring custom TLS CA certificate**

```yaml
fees:
  secrets:
    STREAMING_TLS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKJ... (your CA certificate)
      -----END CERTIFICATE-----
```

**Example: Configuring both SASL and TLS CA**

```yaml
fees:
  secrets:
    STREAMING_SASL_PASSWORD: "your-kafka-sasl-password"
    STREAMING_TLS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKJ... (your CA certificate)
      -----END CERTIFICATE-----
```

> **Note:** These secrets are rendered into the plugin-fees Secret resource and are never exposed in ConfigMaps. Ensure your values.yaml file is stored securely or use external secret management (e.g., sealed-secrets, external-secrets-operator) for production deployments.

> **Important:** If you are using an external secret via `fees.useExistingSecret`, ensure your existing secret includes the `STREAMING_SASL_PASSWORD` and `STREAMING_TLS_CA_CERT` keys if your streaming backend requires them. See the [secrets template](https://github.com/LerianStudio/helm/blob/main/charts/plugin-fees/templates/fees/secrets.yaml) for the complete list of secret keys.

# Configuration Reference

**Complete example with streaming authentication:**

```yaml
fees:
  secrets:
    # Existing secrets
    LICENSE_KEY: "your-license-key"
    ORGANIZATION_ID: "your-organization-id"
    
    # New streaming secrets (optional, only set when required by your streaming backend)
    STREAMING_SASL_PASSWORD: "your-kafka-sasl-password"
    STREAMING_TLS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKJ...
      -----END CERTIFICATE-----
```

**Using external secrets:**

```yaml
fees:
  useExistingSecret: true
  existingSecretName: "plugin-fees-external-secret"
```

Ensure your external secret includes the following keys if streaming authentication is required:

- `STREAMING_SASL_PASSWORD`
- `STREAMING_TLS_CA_CERT`

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 7.2.0 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 7.2.0 -n plugin-fees
```
