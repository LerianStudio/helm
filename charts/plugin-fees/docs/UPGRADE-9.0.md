<!-- {% raw %} -->
# Helm Upgrade from v8.x to v9.x

# Topics

- ***[Breaking Changes](#breaking-changes)***
    - [1. Boolean Flag Handling for Default True Values](#1-boolean-flag-handling-for-default-true-values)
- ***[Configuration Reference](#configuration-reference)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Breaking Changes

### 1. Boolean Flag Handling for Default True Values

The chart now uses a new template helper function `plugin-fees.flagDefaultTrue` to handle boolean flags that default to `true`. This change affects how explicit `false` values are processed in the ConfigMap. The chart has no other change in this release; `appVersion` stays `3.4.0`.

The change affects five `fees.configmap` variables. The table under "Configuration variables affected" lists them with their defaults.

| Setting | v8.0.4 Behavior | v9.0.0 Behavior |
|---------|-----------------|-----------------|
| Explicit `false` value | Treated as empty, defaults to `"true"` | Correctly rendered as `"false"` |
| Explicit `true` value | Rendered as `"true"` | Rendered as `"true"` (unchanged) |
| Omitted/empty value | Defaults to `"true"` | Defaults to `"true"` (unchanged) |

**Why this matters:**

In v8.0.4, if you explicitly set any of these flags to `false` in your values.yaml, the Sprig `default` function would treat the boolean `false` as an empty value and fall back to `"true"`. This made it impossible to disable these features with a YAML boolean. A quoted string `"false"` already worked, because a non-empty string is not empty for `default`.

**Before (v8.0.4):**

```yaml
fees:
  configmap:
    RATE_LIMIT_ENABLED: false
    PACKAGE_CACHE_ENABLED: false
```

The above configuration would incorrectly render as:

```yaml
data:
  RATE_LIMIT_ENABLED: "true"
  PACKAGE_CACHE_ENABLED: "true"
```

**After (v9.0.0):**

```yaml
fees:
  configmap:
    RATE_LIMIT_ENABLED: false
    PACKAGE_CACHE_ENABLED: false
```

The above configuration now correctly renders as:

```yaml
data:
  RATE_LIMIT_ENABLED: "false"
  PACKAGE_CACHE_ENABLED: "false"
```

**Migration impact:**

- If you previously set any of these flags to `false` and expected them to be disabled, they were actually running as `true` in v8.0.4
- After upgrading to v9.0.0, your explicit `false` values will now be honored
- **Review your current configuration** for these five flags before upgrading
- The pods restart on this upgrade in any case: the ConfigMap checksum annotation and the `helm.sh/chart` label in the pod template both change with the chart version
- If you have workarounds in place (e.g., setting values to empty strings or using string `"false"`), remove them and use boolean `false` directly

**Configuration variables affected:**

All five default to `"true"` in `values.yaml` and in the helper.

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `true` | Allow insecure TLS connections |
| `RATE_LIMIT_ENABLED` | `true` | Enable rate limiting for API endpoints |
| `PACKAGE_CACHE_ENABLED` | `true` | Enable caching for package data |
| `BILLING_PACKAGE_CACHE_ENABLED` | `true` | Enable caching for billing package data |
| `ACCOUNT_CACHE_ENABLED` | `true` | Enable caching for account data |

**Example: Disabling features that now work correctly**

```yaml
fees:
  configmap:
    # Disable rate limiting (now works correctly)
    RATE_LIMIT_ENABLED: false
    
    # Disable all caching (now works correctly)
    PACKAGE_CACHE_ENABLED: false
    BILLING_PACKAGE_CACHE_ENABLED: false
    ACCOUNT_CACHE_ENABLED: false
    
    # Enforce strict TLS (now works correctly)
    ALLOW_INSECURE_TLS: false
```

> **Important:** If you have any of these flags explicitly set to `false` in your values.yaml, verify that disabling these features is your intended behavior. After upgrading to v9.0.0, these settings will take effect for the first time.

> **Warning:** If you rely on rate limiting, caching, or insecure TLS being enabled despite setting them to `false`, you must remove those `false` values from your configuration or change them to `true` before upgrading.

> **Warning:** `ALLOW_INSECURE_TLS: false` is the one flag where a change in behavior can break connectivity. A plugin that ran with this flag effectively `true` can fail to connect after the upgrade if any datastore connection does not use TLS. Check this in a non-production environment first.

**Template implementation details:**

The new helper function in `_helpers.tpl`:

```yaml
{{- define "plugin-fees.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

This helper checks if the input is a boolean type. If it is, it renders the boolean value as-is. If it's not a boolean (empty, string, etc.), it applies the default `"true"`.

# Configuration Reference

**Complete example with corrected boolean flag handling:**

```yaml
fees:
  configmap:
    # TLS Configuration
    ALLOW_INSECURE_TLS: false  # Now correctly disables insecure TLS
    
    # Rate Limiting
    RATE_LIMIT_ENABLED: true
    RATE_LIMIT_MAX: "100"
    RATE_LIMIT_WINDOW_SECONDS: "60"
    
    # Cache Configuration
    PACKAGE_CACHE_ENABLED: true
    PACKAGE_CACHE_TTL_SECONDS: "180"
    BILLING_PACKAGE_CACHE_ENABLED: true
    BILLING_PACKAGE_CACHE_TTL_SECONDS: "180"
    ACCOUNT_CACHE_ENABLED: true
    ACCOUNT_CACHE_TTL_SECONDS: "300"
```

**Example: Production configuration with strict security**

```yaml
fees:
  configmap:
    # Enforce strict TLS in production
    ALLOW_INSECURE_TLS: false
    
    # Enable rate limiting for production
    RATE_LIMIT_ENABLED: true
    RATE_LIMIT_MAX: "1000"
    RATE_LIMIT_WINDOW_SECONDS: "60"
    
    # Enable all caching for performance
    PACKAGE_CACHE_ENABLED: true
    BILLING_PACKAGE_CACHE_ENABLED: true
    ACCOUNT_CACHE_ENABLED: true
```

**Example: Development configuration with caching disabled**

```yaml
fees:
  configmap:
    # Allow insecure TLS for local development
    ALLOW_INSECURE_TLS: true
    
    # Disable rate limiting for testing
    RATE_LIMIT_ENABLED: false
    
    # Disable caching to see real-time data changes
    PACKAGE_CACHE_ENABLED: false
    BILLING_PACKAGE_CACHE_ENABLED: false
    ACCOUNT_CACHE_ENABLED: false
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.0 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.0 -n plugin-fees
```
<!-- {% endraw %} -->
