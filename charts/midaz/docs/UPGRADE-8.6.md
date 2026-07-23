# Helm Upgrade from v8.5.0 to v8.6.0

## Topics

- **[Features](#features)**
  - [1. Streaming SASL/TLS Secrets Support for Ledger and CRM](#1-streaming-sasltls-secrets-support-for-ledger-and-crm)
- **[Configuration Reference](#configuration-reference)**
  - [Ledger Streaming Secrets](#ledger-streaming-secrets)
  - [CRM Streaming Secrets](#crm-streaming-secrets)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Streaming SASL/TLS Secrets Support for Ledger and CRM

Version 8.6.0 introduces support for streaming backend authentication and TLS configuration in both the **ledger** and **crm** services. This feature enables operators to securely connect to streaming platforms (e.g., Kafka, Pulsar) that require SASL authentication and/or custom TLS certificate authorities.

Two new secret fields have been added to each service:

- `STREAMING_SASL_PASSWORD`: The SASL password for authenticating with the streaming backend
- `STREAMING_TLS_CA_CERT`: The PEM-encoded TLS CA certificate for verifying the streaming backend's TLS connection

These fields are **operator-provided** and **optional**. They should only be set when your streaming backend requires SASL authentication or uses a private/self-signed TLS CA. When set, they are rendered into the service's Kubernetes Secret (never the ConfigMap), ensuring sensitive material remains protected.

#### Why this matters

- **Security**: Credentials and certificates are stored as Kubernetes Secrets, not ConfigMaps
- **Flexibility**: Supports enterprise streaming platforms with strict authentication and TLS requirements
- **Compatibility**: Works with both internal (chart-managed) and external streaming backends

#### When to use

Set these values if:
- Your streaming backend (Kafka, Pulsar, etc.) requires SASL authentication
- Your streaming backend uses a private or self-signed TLS CA certificate
- You are connecting to a managed streaming service (e.g., Confluent Cloud, AWS MSK with IAM/SASL)

Leave these values empty (default) if:
- Your streaming backend does not require authentication
- Your streaming backend uses publicly trusted TLS certificates
- You are using the chart's default RabbitMQ dependency

## Configuration Reference

### Ledger Streaming Secrets

The following secret fields have been added to the `ledger.secrets` section in `values.yaml`:

| Field | Default | Description |
|-------|---------|-------------|
| `STREAMING_SASL_PASSWORD` | `""` | SASL password for streaming backend authentication. Only set when using SASL auth. |
| `STREAMING_TLS_CA_CERT` | `""` | PEM-encoded TLS CA certificate for streaming backend. Only set when using a private CA. |

**Example configuration:**

```yaml
ledger:
  secrets:
    # Existing secrets...
    POSTGRES_PASSWORD: ""
    REDIS_PASSWORD: ""
    RABBITMQ_DEFAULT_PASS: ""
    RABBITMQ_CONSUMER_PASS: ""
    
    # New streaming secrets (operator-provided)
    STREAMING_SASL_PASSWORD: "your-sasl-password-here"
    STREAMING_TLS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKJ... (your CA cert)
      -----END CERTIFICATE-----
```

> **Important:** These values are base64-encoded automatically by the chart. Provide them as plain text in `values.yaml`.

### CRM Streaming Secrets

The following secret fields have been added to the `crm.secrets` section in `values.yaml`:

| Field | Default | Description |
|-------|---------|-------------|
| `STREAMING_SASL_PASSWORD` | `""` | SASL password for streaming backend authentication. Only set when using SASL auth. |
| `STREAMING_TLS_CA_CERT` | `""` | PEM-encoded TLS CA certificate for streaming backend. Only set when using a private CA. |

**Example configuration:**

```yaml
crm:
  secrets:
    # Existing secrets...
    MONGO_PASSWORD: ""
    
    # New streaming secrets (operator-provided)
    STREAMING_SASL_PASSWORD: "your-sasl-password-here"
    STREAMING_TLS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKJ... (your CA cert)
      -----END CERTIFICATE-----
```

> **Important:** These values are base64-encoded automatically by the chart. Provide them as plain text in `values.yaml`.

#### Template Changes

**Before (v8.5.0):**

The ledger and CRM secret templates did not include streaming-related fields.

**After (v8.6.0):**

Both `templates/ledger/secrets.yaml` and `templates/crm/secrets.yaml` now include conditional blocks for streaming secrets:

```yaml
# =============================================================================
# STREAMING SECRETS (lib-streaming — SASL password + TLS CA, operator-provided)
# =============================================================================
{{- if .Values.ledger.secrets.STREAMING_SASL_PASSWORD }}
STREAMING_SASL_PASSWORD: {{ .Values.ledger.secrets.STREAMING_SASL_PASSWORD | b64enc | quote }}
{{- end }}
{{- if .Values.ledger.secrets.STREAMING_TLS_CA_CERT }}
STREAMING_TLS_CA_CERT: {{ .Values.ledger.secrets.STREAMING_TLS_CA_CERT | b64enc | quote }}
{{- end }}
```

**Operational impact:**

- If you leave these fields empty (default), no streaming secrets are rendered
- If you set these fields, they are added to the existing Secret resource for the service
- No existing secrets are modified or removed
- The change is backward-compatible: existing deployments continue to work without modification

## Migration Steps

This is a **non-breaking** change. No action is required unless you need to configure streaming authentication or TLS.

#### Option 1: No streaming authentication required (default)

If your streaming backend does not require SASL authentication or custom TLS CA certificates, **no changes are needed**. Simply upgrade the chart:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.6.0 -n midaz
```

#### Option 2: Configure streaming authentication

If your streaming backend requires SASL authentication and/or a custom TLS CA:

1. **Prepare your credentials and certificates:**
   - Obtain the SASL password from your streaming platform
   - Obtain the PEM-encoded CA certificate if using a private CA

2. **Update your `values.yaml`:**

   For ledger:
   ```yaml
   ledger:
     secrets:
       STREAMING_SASL_PASSWORD: "your-sasl-password"
       STREAMING_TLS_CA_CERT: |
         -----BEGIN CERTIFICATE-----
         MIIDXTCCAkWgAwIBAgIJAKJ...
         -----END CERTIFICATE-----
   ```

   For CRM:
   ```yaml
   crm:
     secrets:
       STREAMING_SASL_PASSWORD: "your-sasl-password"
       STREAMING_TLS_CA_CERT: |
         -----BEGIN CERTIFICATE-----
         MIIDXTCCAkWgAwIBAgIJAKJ...
         -----END CERTIFICATE-----
   ```

3. **Upgrade the chart:**

   ```bash
   helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm \
     --version 8.6.0 \
     -n midaz \
     -f values.yaml
   ```

4. **Verify the secrets were created:**

   ```bash
   kubectl get secret midaz-ledger-secret -n midaz -o jsonpath='{.data}' | grep STREAMING
   kubectl get secret midaz-crm-secret -n midaz -o jsonpath='{.data}' | grep STREAMING
   ```

> **Note:** If you use `useExistingSecret: true` for ledger or CRM, ensure your external Secret includes the `STREAMING_SASL_PASSWORD` and `STREAMING_TLS_CA_CERT` keys (base64-encoded) if needed.

#### Option 3: Using external secrets

If you manage secrets externally (e.g., via External Secrets Operator, Sealed Secrets):

1. **Add the new keys to your external secret definition:**

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: midaz-ledger-external-secret
     namespace: midaz
   type: Opaque
   data:
     # Existing keys...
     POSTGRES_PASSWORD: <base64-encoded>
     
     # New streaming keys (base64-encoded)
     STREAMING_SASL_PASSWORD: <base64-encoded>
     STREAMING_TLS_CA_CERT: <base64-encoded>
   ```

2. **Reference the external secret in `values.yaml`:**

   ```yaml
   ledger:
     useExistingSecret: true
     existingSecretName: "midaz-ledger-external-secret"
   ```

3. **Upgrade the chart:**

   ```bash
   helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.6.0 -n midaz
   ```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.6.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.6.0 -n midaz
```
