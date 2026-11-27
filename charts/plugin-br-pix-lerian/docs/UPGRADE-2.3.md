<!-- {% raw %} -->
# Helm Upgrade from v2.2.2 to v2.3.0

## Topics

- **[Features](#features)**
  - [1. Partner Host and Token URL Validation](#1-partner-host-and-token-url-validation)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Partner Host and Token URL Validation

**What changed:**

The `antifraud` configuration block now includes two new fields for validating partner endpoints and token URLs:

- `antifraud.partnerHosts` — Comma-separated hosts (or host:port) that a route's `endpoint` and `feedbackEndpoint` may target
- `antifraud.partnerTokenUrls` — Comma-separated absolute token URLs, matched exactly

These values are sent to both `spi` and `spiSystemplane` components and are used to validate partner integrations.

| Setting | v2.2.2 | v2.3.0 |
|---------|--------|--------|
| `antifraud.partnerHosts` | (not present) | `""` |
| `antifraud.partnerTokenUrls` | (not present) | `""` |

**Why it matters:**

The antifraud system now enforces explicit allow-lists for partner endpoints and token URLs. When a route is created or updated with a partner integration:

- The `endpoint` and `feedbackEndpoint` hosts must match one of the hosts in `ANTIFRAUD_PARTNER_HOSTS`
- The token URL must match one of the URLs in `ANTIFRAUD_PARTNER_TOKEN_URLS`

**Empty values approve none**: If these fields are left empty (the default), no partner endpoints or token URLs will be approved, and route creation/updates with partner integrations will fail validation.

**How to handle it:**

#### If you do not use partner integrations

No action is required. Leave both fields empty (the default), and the validation will reject any partner endpoints.

#### If you use partner integrations

Provide the allow-lists for partner hosts and token URLs before upgrading:

```yaml
antifraud:
  partnerHosts: "partner1.example.com,partner2.example.com:8443"
  partnerTokenUrls: "https://partner1.example.com/oauth/token,https://partner2.example.com:8443/token"
```

> **Important:** The `partnerHosts` field accepts hosts or host:port pairs (e.g., `partner.example.com` or `partner.example.com:8443`). The `partnerTokenUrls` field requires absolute URLs that are matched exactly (e.g., `https://partner.example.com/oauth/token`).

> **Warning:** If you have existing routes with partner integrations and do not set these fields before upgrading, route updates will fail validation. Set the allow-lists to match your existing partner endpoints.

**After (v2.3.0) values.yaml:**

```yaml
antifraud:
  # -- ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: comma-separated hosts (or host:port) a
  # route may target. Sent to spi (checks it on every call) and spiSystemplane
  # (checks it when a route is written) so the two never disagree. Empty renders nothing.
  allowedPrivateHosts: ""
  # -- ANTIFRAUD_PARTNER_HOSTS: comma-separated hosts (or host:port) a route's endpoint
  # and feedbackEndpoint may target. Sent to spi and spiSystemplane. Empty approves none.
  partnerHosts: ""
  # -- ANTIFRAUD_PARTNER_TOKEN_URLS: comma-separated absolute token URLs, matched exactly.
  # Sent to spi and spiSystemplane. Empty approves none.
  partnerTokenUrls: ""
  # -- ANTIFRAUD_SECRETS_BACKEND: "aws" or "vault". Sent to spi only, the one process
  # that reads the credential. Empty renders nothing and every enabled flow denies.
  secretsBackend: ""
```

**Template changes:**

The `spi` and `spiSystemplane` ConfigMap templates now iterate over all three antifraud fields using a `range` loop instead of emitting `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` individually.

**Before (v2.2.2) configmap.yaml:**

```yaml
{{- with include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "params" $.Values.antifraud "field" "allowedPrivateHosts" "default" "") }}
ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: {{ . | quote }}
{{- end }}
```

**After (v2.3.0) configmap.yaml:**

```yaml
{{- range $k, $f := dict "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "allowedPrivateHosts" "ANTIFRAUD_PARTNER_HOSTS" "partnerHosts" "ANTIFRAUD_PARTNER_TOKEN_URLS" "partnerTokenUrls" }}
{{- with include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" $k "params" $.Values.antifraud "field" $f "default" "") }}
{{ $k }}: {{ . | quote }}
{{- end }}
{{- end }}
```

The enumerated ConfigMap keys list (used for pass-through validation) has also been updated to include the new variables:

**Before (v2.2.2) configmap.yaml:**

```yaml
{{- range $k := (list
    "ADAPTER_BASE_URL" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    # ...
  )}}
```

**After (v2.3.0) configmap.yaml:**

```yaml
{{- range $k := (list
    "ADAPTER_BASE_URL" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "ANTIFRAUD_PARTNER_HOSTS" "ANTIFRAUD_PARTNER_TOKEN_URLS" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    # ...
  )}}
```

**Affected components:**

- `spi`
- `spi-systemplane`

## Configuration Reference

| Flag | Default | Description |
|------|---------|-------------|
| `antifraud.allowedPrivateHosts` | `""` | Comma-separated hosts (or host:port) a route may target. Sent to spi and spiSystemplane. Empty renders nothing. |
| `antifraud.partnerHosts` | `""` | Comma-separated hosts (or host:port) a route's endpoint and feedbackEndpoint may target. Sent to spi and spiSystemplane. Empty approves none. |
| `antifraud.partnerTokenUrls` | `""` | Comma-separated absolute token URLs, matched exactly. Sent to spi and spiSystemplane. Empty approves none. |
| `antifraud.secretsBackend` | `""` | "aws" or "vault". Sent to spi only. Empty renders nothing and every enabled flow denies. |

**Environment variables added:**

- `ANTIFRAUD_PARTNER_HOSTS` — Emitted to `spi` and `spiSystemplane` ConfigMaps when `antifraud.partnerHosts` is set
- `ANTIFRAUD_PARTNER_TOKEN_URLS` — Emitted to `spi` and `spiSystemplane` ConfigMaps when `antifraud.partnerTokenUrls` is set

**Example configuration:**

```yaml
antifraud:
  allowedPrivateHosts: "internal-service.default.svc.cluster.local:8080"
  partnerHosts: "partner1.example.com,partner2.example.com:8443"
  partnerTokenUrls: "https://partner1.example.com/oauth/token,https://partner2.example.com:8443/token"
  secretsBackend: "vault"
```

## Preview changes before upgrading

```bash
helm diff upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.3.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.3.0
```
<!-- {% endraw %} -->
