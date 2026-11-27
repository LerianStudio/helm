<!-- {% raw %} -->
# Helm Upgrade from v5.6.0 to v5.7.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Antifraud partner destination allowlist](#1-antifraud-partner-destination-allowlist)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that introduces two new environment variables for controlling antifraud partner destinations in the `pix` component. The application version remains `1.15.0` and no existing values are removed or renamed, so current deployments will continue to work without changes.

The new configuration allows operators to explicitly approve antifraud partner hosts and token URLs, adding a security layer to outbound antifraud integrations. By default, these variables are commented out in `values.yaml`; if left unset, the application will deny antifraud flows that require partner communication.

## Features

### 1. Antifraud partner destination allowlist

Two new environment variables have been added to the `pix` component's ConfigMap to control which external antifraud partner endpoints the service is allowed to contact:

- `ANTIFRAUD_PARTNER_HOSTS`: Comma-separated list of approved antifraud partner hostnames
- `ANTIFRAUD_PARTNER_TOKEN_URLS`: Comma-separated list of approved token endpoint URLs

**What changed:**

The `pix.configmap` section in `values.yaml` now includes two new commented configuration keys:

| Setting | v5.6.0 | v5.7.0 |
|---------|--------|--------|
| `pix.configmap.ANTIFRAUD_PARTNER_HOSTS` | (not present) | `""` (commented, empty by default) |
| `pix.configmap.ANTIFRAUD_PARTNER_TOKEN_URLS` | (not present) | `""` (commented, empty by default) |

**Why it matters:**

These variables implement an allowlist security model for antifraud partner integrations. When the antifraud flow is enabled (`ANTIFRAUD_HOOK_PREWARM_ENABLED: "true"`), the application needs explicit approval of destination hosts and token URLs. An empty or unset value means **no destinations are approved**, which will cause antifraud partner calls to be denied.

This prevents the service from making unexpected outbound connections and gives operators explicit control over third-party integrations.

**How it works:**

The template logic in `templates/pix/configmap.yaml` now includes these variables in the ConfigMap data block only if they are defined in `pix.configmap` and not already overridden in `pix.extraEnvVars`:

**Before (v5.6.0):**

```yaml
# templates/pix/configmap.yaml (excerpt)
  {{- with .Values.pix.configmap.ANTIFRAUD_SECRETS_BACKEND }}
  {{- if . }}
  ANTIFRAUD_SECRETS_BACKEND: {{ . | quote }}
  {{- end }}
  {{- end }}

  SWAGGER_ENABLED: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.pix.configmap.SWAGGER_ENABLED | quote }}
```

**After (v5.7.0):**

```yaml
# templates/pix/configmap.yaml (excerpt)
  {{- with .Values.pix.configmap.ANTIFRAUD_SECRETS_BACKEND }}
  {{- if . }}
  ANTIFRAUD_SECRETS_BACKEND: {{ . | quote }}
  {{- end }}
  {{- end }}
  {{- /* Approved antifraud destinations, deploy-owned; empty approves none (a key in extraEnvVars wins). */}}
  {{- range $k := list "ANTIFRAUD_PARTNER_HOSTS" "ANTIFRAUD_PARTNER_TOKEN_URLS" }}
  {{- with index $.Values.pix.configmap $k }}
  {{- if not (hasKey ($.Values.pix.extraEnvVars | default dict) $k) }}
  {{ $k }}: {{ . | quote }}
  {{- end }}
  {{- end }}
  {{- end }}

  SWAGGER_ENABLED: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.pix.configmap.SWAGGER_ENABLED | quote }}
```

The template iterates over both variable names and adds them to the ConfigMap only if:
1. The key is defined in `pix.configmap`
2. The key is **not** already present in `pix.extraEnvVars` (which takes precedence)

**Default behavior:**

In `values.yaml`, both variables are commented out:

```yaml
pix:
  configmap:
    ANTIFRAUD_HOOK_PREWARM_ENABLED: "true"
    # Partner antifraud credential store, "aws" or "vault"; not set by default, and an enabled flow then denies.
    # ANTIFRAUD_SECRETS_BACKEND: ""
    # Approved antifraud destinations, comma-separated, set before the image; empty approves none.
    # ANTIFRAUD_PARTNER_HOSTS: ""
    # ANTIFRAUD_PARTNER_TOKEN_URLS: ""
```

Because they are commented, they will **not** appear in the ConfigMap, and the application will treat them as unset (denying antifraud partner flows).

## Configuration Reference

### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTIFRAUD_PARTNER_HOSTS` | `""` (unset) | Comma-separated list of approved antifraud partner hostnames. Empty or unset denies all partner hosts. |
| `ANTIFRAUD_PARTNER_TOKEN_URLS` | `""` (unset) | Comma-separated list of approved token endpoint URLs for antifraud partners. Empty or unset denies all token URLs. |

### Configuration examples

#### Option 1: Keep existing behavior (no partner destinations approved)

If you do not use antifraud partner integrations or want to explicitly deny them, leave the variables commented or unset:

```yaml
pix:
  configmap:
    ANTIFRAUD_HOOK_PREWARM_ENABLED: "true"
    # ANTIFRAUD_PARTNER_HOSTS: ""
    # ANTIFRAUD_PARTNER_TOKEN_URLS: ""
```

No ConfigMap entries will be created, and the application will deny partner calls.

#### Option 2: Approve specific partner destinations

If you integrate with antifraud partners, uncomment and populate both variables with the approved destinations:

```yaml
pix:
  configmap:
    ANTIFRAUD_HOOK_PREWARM_ENABLED: "true"
    ANTIFRAUD_SECRETS_BACKEND: "aws"
    ANTIFRAUD_PARTNER_HOSTS: "partner1.example.com,partner2.example.com"
    ANTIFRAUD_PARTNER_TOKEN_URLS: "https://partner1.example.com/oauth/token,https://partner2.example.com/token"
```

The ConfigMap will include both variables, and the application will allow outbound calls only to the listed hosts and token URLs.

#### Option 3: Override via extraEnvVars

If you manage these variables through a separate secret or external configuration, set them in `pix.extraEnvVars` instead. The template logic will skip adding them from `pix.configmap`:

```yaml
pix:
  extraEnvVars:
    ANTIFRAUD_PARTNER_HOSTS: "partner.example.com"
    ANTIFRAUD_PARTNER_TOKEN_URLS: "https://partner.example.com/token"
```

> **Note:** Values in `pix.extraEnvVars` always take precedence over `pix.configmap`.

## Migration Steps

This upgrade requires no destructive migration steps. The new variables are optional and default to unset (denying partner destinations).

**Recommended upgrade process:**

1. Review your current antifraud configuration. Check whether `ANTIFRAUD_HOOK_PREWARM_ENABLED` is set to `"true"` and whether your deployment integrates with external antifraud partners.

2. If you **do not** use antifraud partner integrations, proceed with the upgrade without changes. The default behavior (denying partner calls) will remain.

3. If you **do** use antifraud partner integrations, identify the partner hostnames and token URLs your application needs to contact, then add them to your custom values file:

```yaml
pix:
  configmap:
    ANTIFRAUD_PARTNER_HOSTS: "partner.example.com"
    ANTIFRAUD_PARTNER_TOKEN_URLS: "https://partner.example.com/oauth/token"
```

4. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

5. Run the upgrade command during a maintenance window.

6. Verify the `pix` deployment rolled out successfully:

```bash
kubectl rollout status deployment/plugin-br-pix-indirect-btg-pix -n midaz-plugins
```

7. Check the ConfigMap to confirm the new variables are present (if you set them):

```bash
kubectl get configmap plugin-br-pix-indirect-btg-pix -n midaz-plugins -o yaml | grep ANTIFRAUD_PARTNER
```

8. Monitor application logs for any antifraud partner connection errors:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/component=pix --tail=100 | grep -i antifraud
```

> **Warning:** If your application currently makes antifraud partner calls and you upgrade without setting the new allowlist variables, those calls will be **denied** by the application. Ensure you configure the approved destinations before upgrading if you rely on partner integrations.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.7.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.7.0
```
<!-- {% endraw %} -->
