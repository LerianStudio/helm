<!-- {% raw %} -->
# Helm Upgrade from v2.1.0 to v2.2.0

## Topics

- **[Features](#features)**
  - [1. Antifraud Partner Integration](#1-antifraud-partner-integration)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Antifraud Partner Integration

**What changed:**

A new top-level `antifraud` configuration block has been added to `values.yaml`, introducing two settings that control antifraud partner integration for the SPI workloads (`spi` and `spiSystemplane`):

- `antifraud.allowedPrivateHosts` — Comma-separated list of private hosts the antifraud partner route may target
- `antifraud.secretsBackend` — Secrets backend type (`"aws"` or `"vault"`)

These settings are propagated to the `spi` and `spi-systemplane` ConfigMaps as environment variables:

- `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` — Sent to both `spi` and `spiSystemplane` to ensure they never disagree on allowed hosts
- `ANTIFRAUD_SECRETS_BACKEND` — Sent to `spi` only (the process that reads the credential)

| Setting | v2.1.0 | v2.2.0 |
|---------|--------|--------|
| `antifraud.allowedPrivateHosts` | (not present) | `""` |
| `antifraud.secretsBackend` | (not present) | `""` |

**Why it matters:**

The antifraud partner integration allows the SPI to route transaction validation requests to an external antifraud service. The `allowedPrivateHosts` setting acts as a security control: it restricts which private (non-public) hosts the antifraud partner route may target, preventing accidental or malicious routing to internal services.

The `secretsBackend` setting determines where the SPI reads the antifraud partner's M2M credentials from (`"aws"` for AWS Secrets Manager, `"vault"` for HashiCorp Vault). **If `secretsBackend` is empty or invalid, every antifraud-enabled transaction flow will be denied.**

**How to handle it:**

#### If you do not use antifraud partner integration

No action is required. Both settings default to empty strings, and the antifraud integration remains disabled. The SPI will not attempt to route to an antifraud partner.

#### If you use antifraud partner integration

Provide both settings before upgrading:

```yaml
antifraud:
  allowedPrivateHosts: "antifraud.internal.example.com,antifraud-backup.internal.example.com"
  secretsBackend: "aws"
```

> **Important:** On Lerian Cloud, leave `allowedPrivateHosts` empty — Lerian Cloud sets this value through GitOps. Lerian Cloud also sets `secretsBackend` to `"aws"` through GitOps.

> **Warning:** If `secretsBackend` is empty or set to an invalid value (anything other than `"aws"` or `"vault"`), every antifraud-enabled transaction flow will be denied. Ensure the value matches your secrets infrastructure.

**After (v2.2.0) values.yaml:**

```yaml
# -- Antifraud partner settings shared by the SPI workloads. Leave allowedPrivateHosts
# empty on Lerian Cloud; Lerian Cloud sets secretsBackend to aws through GitOps.
# A component's own configmap.<KEY> wins over this block.
antifraud:
  # -- ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: comma-separated private hosts the partner
  # route may target. Sent to spi (checks it on every call) and spiSystemplane
  # (checks it when a route is written) so the two never disagree. Empty renders nothing.
  allowedPrivateHosts: ""
  # -- ANTIFRAUD_SECRETS_BACKEND: "aws" or "vault". Sent to spi only, the one process
  # that reads the credential. Empty renders nothing and every enabled flow denies.
  secretsBackend: ""
```

**Template changes:**

The `spi` and `spi-systemplane` ConfigMap templates now include logic to emit the antifraud environment variables when the `antifraud` block is set:

**Before (v2.1.0) spi/configmap.yaml:**

```yaml
{{- range $k := (list
    "ADAPTER_BASE_URL" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    "CRM_BASE_URL" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "CRM_ORGANIZATION_ID" "DATABASE_URL"
    # ...
  )}}
```

**After (v2.2.0) spi/configmap.yaml:**

```yaml
{{- with include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "params" $.Values.antifraud "field" "allowedPrivateHosts" "default" "") }}
ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: {{ . | quote }}
{{- end }}
{{- with include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ANTIFRAUD_SECRETS_BACKEND" "params" $.Values.antifraud "field" "secretsBackend" "default" "") }}
ANTIFRAUD_SECRETS_BACKEND: {{ . | quote }}
{{- end }}
# ...
{{- range $k := (list
    "ADAPTER_BASE_URL" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "ANTIFRAUD_SECRETS_BACKEND" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    "CRM_BASE_URL" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "CRM_ORGANIZATION_ID" "DATABASE_URL"
    # ...
  )}}
```

**Before (v2.1.0) spi-systemplane/configmap.yaml:**

```yaml
{{- range $k := (list
    "ADAPTER_BASE_URL" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    "CRM_BASE_URL" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "DATABASE_URL" "DB_REPLICA_SSL_MODE"
    # ...
  )}}
```

**After (v2.2.0) spi-systemplane/configmap.yaml:**

```yaml
{{- with include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "params" $.Values.antifraud "field" "allowedPrivateHosts" "default" "") }}
ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: {{ . | quote }}
{{- end }}
# ...
{{- range $k := (list
    "ADAPTER_BASE_URL" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    "CRM_BASE_URL" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "DATABASE_URL" "DB_REPLICA_SSL_MODE"
    # ...
  )}}
```

**Operational impact:**

- The `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` variable is emitted to both `spi` and `spi-systemplane` ConfigMaps only when `antifraud.allowedPrivateHosts` is non-empty. If empty, the variable is not rendered.
- The `ANTIFRAUD_SECRETS_BACKEND` variable is emitted to the `spi` ConfigMap only when `antifraud.secretsBackend` is non-empty. If empty, the variable is not rendered.
- A component's own `configmap.<KEY>` always wins over the `antifraud` block. For example, if you set `spi.configmap.ANTIFRAUD_SECRETS_BACKEND`, it will override `antifraud.secretsBackend`.

**Override behavior:**

If you need to override the antifraud settings for a specific component, use the component's `configmap` block:

```yaml
spi:
  configmap:
    ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: "custom-host.example.com"
    ANTIFRAUD_SECRETS_BACKEND: "vault"
```

This will override the values from the `antifraud` block for the `spi` component only.

## Configuration Reference

### Antifraud Settings

| Flag | Default | Description |
|------|---------|-------------|
| `antifraud.allowedPrivateHosts` | `""` | Comma-separated list of private hosts the antifraud partner route may target. Sent to `spi` (checks on every call) and `spiSystemplane` (checks when a route is written). Empty renders nothing. Leave empty on Lerian Cloud. |
| `antifraud.secretsBackend` | `""` | Secrets backend type: `"aws"` or `"vault"`. Sent to `spi` only (the process that reads the credential). Empty renders nothing and every enabled flow denies. Lerian Cloud sets this to `"aws"` through GitOps. |

### Environment Variables

The following environment variables are added to the `spi` and `spi-systemplane` ConfigMaps:

| Variable | Component | Description |
|----------|-----------|-------------|
| `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` | `spi`, `spiSystemplane` | Comma-separated list of private hosts the antifraud partner route may target. Emitted only when `antifraud.allowedPrivateHosts` is non-empty. |
| `ANTIFRAUD_SECRETS_BACKEND` | `spi` | Secrets backend type: `"aws"` or `"vault"`. Emitted only when `antifraud.secretsBackend` is non-empty. |

## Preview changes before upgrading

```bash
helm diff upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.2.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.2.0
```
<!-- {% endraw %} -->
