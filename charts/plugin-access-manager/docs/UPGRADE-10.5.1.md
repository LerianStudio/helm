<!-- {% raw %} -->
# Helm Upgrade from v10.5.0 to v10.5.1

# Topics

- **[Fixes](#fixes)**
  - [1. License Key Validation](#1-license-key-validation)
- **[Improvements](#improvements)**
  - [1. Ingress Configuration Handling](#1-ingress-configuration-handling)
  - [2. Documentation URL Updates](#2-documentation-url-updates)
  - [3. Comment Cleanup](#3-comment-cleanup)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. License Key Validation

The chart now enforces that `LICENSE_KEY` must be provided for both `auth` and `identity` services at install or upgrade time.

**What changed:**

Previously, the chart would generate Secrets with empty or missing `LICENSE_KEY` values if you didn't explicitly set them, allowing the services to start and then fail at runtime. This patch adds Helm template validation that blocks the upgrade if the license keys are missing.

| Service | Field | v10.5.0 | v10.5.1 |
|---------|-------|---------|---------|
| Auth | `auth.secrets.LICENSE_KEY` | Optional (runtime failure) | Required (template validation) |
| Identity | `identity.secrets.LICENSE_KEY` | Optional (runtime failure) | Required (template validation) |

**Why this matters:**

- **Fail fast:** You'll get a clear error message during `helm upgrade` instead of discovering the problem after pods start crashing
- **Clearer error messages:** The validation message tells you exactly which field is missing and what to do about it
- **Prevents incomplete deployments:** The chart won't render invalid Secrets that would cause the services to fail at boot

**Before (v10.5.0):**

```yaml
# templates/auth/secrets.yaml
data:
  LICENSE_KEY: {{ .Values.auth.secrets.LICENSE_KEY | b64enc | quote }}
```

```yaml
# templates/identity/secrets.yaml
data:
  LICENSE_KEY: {{ .Values.identity.secrets.LICENSE_KEY | b64enc | quote }}
```

If `LICENSE_KEY` was empty or unset, the Secret would be created with an empty value, and the service would fail at runtime.

**After (v10.5.1):**

```yaml
# templates/auth/secrets.yaml
data:
  LICENSE_KEY: {{ required "auth.secrets.LICENSE_KEY is required: auth refuses to boot without a license. Set it, or use auth.useExistingSecret with a Secret that carries LICENSE_KEY." .Values.auth.secrets.LICENSE_KEY | b64enc | quote }}
```

```yaml
# templates/identity/secrets.yaml
data:
  LICENSE_KEY: {{ required "identity.secrets.LICENSE_KEY is required: identity refuses to boot without a license. Set it, or use identity.useExistingSecret with a Secret that carries LICENSE_KEY." .Values.identity.secrets.LICENSE_KEY | b64enc | quote }}
```

If `LICENSE_KEY` is missing, Helm will fail with a clear error message before rendering any resources.

**Migration steps:**

1. **Check your current values file** to ensure both license keys are set:

```yaml
auth:
  secrets:
    LICENSE_KEY: "your-auth-license-key-here"

identity:
  secrets:
    LICENSE_KEY: "your-identity-license-key-here"
```

2. **If you're using existing Secrets** (via `auth.useExistingSecret` or `identity.useExistingSecret`), ensure those Secrets contain a `LICENSE_KEY` field. The validation only applies when the chart generates the Secret.

3. **If you don't have license keys**, contact Lerian Studio support to obtain them before upgrading.

> **Important:** If you attempt to upgrade without setting these values, you'll see an error like:
> ```
> Error: execution error at (plugin-access-manager/templates/auth/secrets.yaml:22:16): auth.secrets.LICENSE_KEY is required: auth refuses to boot without a license. Set it, or use auth.useExistingSecret with a Secret that carries LICENSE_KEY.
> ```

# Improvements

### 1. Ingress Configuration Handling

The chart now includes a new helper template that improves how component-level ingress settings merge with global ingress defaults.

**What changed:**

A new template helper `plugin-access-manager.ingress` was added to handle placeholder values in component ingress configurations. This helper removes an empty `className` and `tls`, and, when `global.ingress.domain` is set, a `hosts` list that names no host, so the global values apply.

**Why this matters:**

- **Cleaner merging:** Empty placeholder values in `auth.ingress` and `identity.ingress` no longer override global settings
- **Consistent behavior:** When you set `global.ingress.domain`, it now applies to components whose `hosts` entries set no `host` (the shipped `host: ""` placeholder)
- **Explicit overrides still work:** If you explicitly set a component's `className`, `tls`, or `hosts`, those values take precedence

**Template changes:**

**Before (v10.5.0):**

```yaml
# templates/auth/ingress.yaml
{{- include "lerian-common.ingress" (dict
      "context" .
      "ingress" .Values.auth.ingress
      "global" (.Values.global).ingress
      # ...
) -}}
```

**After (v10.5.1):**

```yaml
# templates/auth/ingress.yaml
{{- include "lerian-common.ingress" (dict
      "context" .
      "ingress" (include "plugin-access-manager.ingress" (dict "ingress" .Values.auth.ingress "global" (.Values.global).ingress) | fromYaml)
      "global" (.Values.global).ingress
      # ...
) -}}
```

The same change applies to `templates/identity/ingress.yaml`.

**Operational impact:**

- **Check before upgrading:** if `auth.ingress.enabled` or `identity.ingress.enabled` is `true` and that component keeps the shipped empty `className`, `tls` or `hosts`, its Ingress now takes `global.ingress.className` and `global.ingress.tls`, and with `global.ingress.domain` set its host changes from the empty host to `auth.<domain>` or `identity.<domain>`. Set `className`, `tls` and `hosts` on the component to keep the previous Ingress.
- **Improved defaults:** If you were working around empty placeholder values by explicitly setting every component's ingress, you may now be able to simplify your values file

**Example: Global domain now applies correctly**

```yaml
global:
  ingress:
    domain: example.com
    className: nginx
```

With `auth.ingress.enabled` and `identity.ingress.enabled` set to `true`, both ingresses use:
- Host: `auth.example.com` and `identity.example.com` (derived from subdomain + global domain)
- IngressClass: `nginx`

**Example: Explicit component override still works**

```yaml
global:
  ingress:
    domain: example.com

auth:
  ingress:
    hosts:
      - host: custom-auth.example.com
        paths:
          - path: /
            pathType: Prefix
```

The `auth` ingress will use `custom-auth.example.com` instead of the default `auth.example.com`.

### 2. Documentation URL Updates

Documentation links in `Chart.yaml` and `values.yaml` have been updated to point to the new documentation structure.

**What changed:**

| Location | v10.5.0 | v10.5.1 |
|----------|---------|---------|
| Chart.yaml dependencies comment | `https://docs.lerian.studio/docs/midaz-components` | `https://docs.lerian.studio/en/products/midaz/architecture` |
| values.yaml auth-database comment | `https://docs.lerian.studio/docs/midaz-security#identity-management-with-casdoor` | `https://docs.lerian.studio/en/platform/access-manager/am-components` |

**Why this matters:**

- **Accurate references:** The documentation URLs now point to the current structure of the Lerian Studio documentation site
- **Better context:** The new URLs provide more specific information about component architecture and access management

**Operational impact:**

No action required. This change only affects documentation links in comments.

### 3. Comment Cleanup

Several inline comments in `values.yaml` have been updated or removed for clarity.

**What changed:**

1. **Valkey documentation link:** Removed a redundant documentation link from the Valkey section

**Before (v10.5.0):**

```yaml
valkey:
  # Redis is used to handle scenarios where real-time performance and fast data retrieval are essential.
  # This component is responsible for providing an in-memory data store
  # For more details, refer to the documentation:
  # https://docs.lerian.studio/docs/midaz-components#why-redis
  enabled: true
```

**After (v10.5.1):**

```yaml
valkey:
  # Redis is used to handle scenarios where real-time performance and fast data retrieval are essential.
  # This component is responsible for providing an in-memory data store
  enabled: true
```

**Why this matters:**

- **Cleaner documentation:** Removed outdated references and redundant links
- **Easier maintenance:** Comments now focus on current behavior without historical context

**Operational impact:**

No action required. These are documentation-only changes.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 10.5.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 10.5.1
```
<!-- {% endraw %} -->
