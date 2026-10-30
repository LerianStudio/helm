<!-- {% raw %} -->
# Helm Upgrade from v9.8.2 to v10.0.0

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. Boolean flag handling for default-true values](#1-boolean-flag-handling-for-default-true-values)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Option 1: No action required (recommended)](#option-1-no-action-required-recommended)
  - [Option 2: Explicitly set boolean values](#option-2-explicitly-set-boolean-values)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### 1. Boolean flag handling for default-true values

The chart now uses a new template helper `midaz.flagDefaultTrue` to handle boolean flags that default to `true`. This change affects how explicit `false` values are processed for several configuration flags across the `ledger`, `crm`, and `tracer` services.

#### What changed

Previously, the chart used Sprig's `default` function to set default values for boolean flags. This approach had a critical flaw: when an operator explicitly set a flag to `false`, Sprig treated it as an empty value and replaced it with the default `true`, making it impossible to disable these features.

**Before (v9.8.2):**

```yaml
ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "true" | quote }}
BULK_RECORDER_ENABLED: {{ $cm.BULK_RECORDER_ENABLED | default "true" | quote }}
RATE_LIMIT_ENABLED: {{ $cm.RATE_LIMIT_ENABLED | default "true" | quote }}
```

**After (v10.0.0):**

```yaml
ALLOW_INSECURE_TLS: {{ include "midaz.flagDefaultTrue" $cm.ALLOW_INSECURE_TLS | quote }}
BULK_RECORDER_ENABLED: {{ include "midaz.flagDefaultTrue" $cm.BULK_RECORDER_ENABLED | quote }}
RATE_LIMIT_ENABLED: {{ include "midaz.flagDefaultTrue" $cm.RATE_LIMIT_ENABLED | quote }}
```

The new `midaz.flagDefaultTrue` helper is defined in `_helpers.tpl`:

```yaml
{{- define "midaz.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

#### Affected configuration flags

| Service | Flag | Default | Impact |
|---------|------|---------|--------|
| `ledger` | `ALLOW_INSECURE_TLS` | `true` | Allows plaintext (non-TLS) connections to Postgres, MongoDB, Valkey and RabbitMQ |
| `ledger` | `BULK_RECORDER_ENABLED` | `true` | Controls bulk transaction recording |
| `ledger` | `RATE_LIMIT_ENABLED` | `true` | Controls API rate limiting |
| `crm` | `ALLOW_INSECURE_TLS` | `true` | Allows plaintext (non-TLS) connections to its datastores |
| `tracer` | `ALLOW_INSECURE_TLS` | `true` | Allows plaintext (non-TLS) connections to its datastores |

#### Why this is a breaking change

If you previously attempted to disable any of these features by setting them to an unquoted `false` in your `values.yaml`, the setting was silently ignored in v9.8.2 and rendered `"true"`. In v10.0.0, the unquoted `false` is respected and renders `"false"`.

A quoted `"false"` is not affected: it rendered `"false"` in v9.8.2 and still does in v10.0.0.

**Example scenario:**

You have the following in your `values.yaml`:

```yaml
ledger:
  configmap:
    RATE_LIMIT_ENABLED: false
```

- **v9.8.2 behavior:** Rate limiting remained **enabled** (the `false` was ignored)
- **v10.0.0 behavior:** Rate limiting is now **disabled** (the `false` is respected)

> **Warning:** If you have any of these flags explicitly set to `false` in your values overrides, review whether you actually want them disabled. The upgrade will honor your configuration for the first time.

#### What this means for operators

1. **If you never overrode these flags:** No action required. All flags will continue to default to `true` and behave identically to v9.8.2.

2. **If you explicitly set any flag to `true`:** No action required. The behavior is unchanged.

3. **If you explicitly set any flag to an unquoted `false`:** The flag will now actually be disabled. Review your configuration to ensure this is the intended behavior:
   - Setting `ALLOW_INSECURE_TLS` to `false` makes the service require TLS on its Postgres, MongoDB, Valkey and RabbitMQ connections. If any of them has no TLS, the service refuses to boot. It has nothing to do with HTTPS certificate validation
   - Disabling `BULK_RECORDER_ENABLED` will disable bulk transaction recording in the ledger
   - Disabling `RATE_LIMIT_ENABLED` will remove API rate limiting (requires `ALLOW_RATELIMIT_DISABLED` in strict tier)

4. **If you set a flag to a quoted string** (`"false"` or `"true"`): No action required. Quoted values render as written in both v9.8.2 and v10.0.0.

## Configuration Reference

The following configuration flags now use the `midaz.flagDefaultTrue` helper and will correctly respect explicit `false` values:

### Ledger service flags

```yaml
ledger:
  configmap:
    # Allows plaintext (non-TLS) connections to Postgres, MongoDB, Valkey and RabbitMQ
    # Set to false to require TLS (the service refuses to boot if a dependency has no TLS)
    ALLOW_INSECURE_TLS: true
    
    # Controls bulk transaction recording feature
    # Set to false to disable bulk recording and use individual inserts
    BULK_RECORDER_ENABLED: true
    
    # Controls API rate limiting
    # Set to false to disable rate limiting (requires ALLOW_RATELIMIT_DISABLED in strict tier)
    RATE_LIMIT_ENABLED: true
```

### CRM service flags

```yaml
crm:
  configmap:
    # Allows plaintext (non-TLS) connections to Postgres, MongoDB, Valkey and RabbitMQ
    # Set to false to require TLS (the service refuses to boot if a dependency has no TLS)
    ALLOW_INSECURE_TLS: true
```

### Tracer service flags

```yaml
tracer:
  configmap:
    # Allows plaintext (non-TLS) connections to Postgres, MongoDB, Valkey and RabbitMQ
    # Set to false to require TLS (the service refuses to boot if a dependency has no TLS)
    ALLOW_INSECURE_TLS: true
```

| Flag | Default | Description |
|------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `true` | When `true`, lets the service connect to Postgres, MongoDB, Valkey and RabbitMQ without TLS. When `false`, those connections must use TLS, and the service refuses to boot if a dependency has no TLS. It does not control HTTPS certificate validation. |
| `BULK_RECORDER_ENABLED` | `true` | When `true`, enables bulk transaction recording for improved performance. When `false`, uses individual database inserts for each transaction. |
| `RATE_LIMIT_ENABLED` | `true` | When `true`, enables API rate limiting with the configured limits. When `false`, disables rate limiting entirely (requires `ALLOW_RATELIMIT_DISABLED` environment variable in strict tier). |

> **Important:** Booleans (`true`, `false`) and quoted strings (`"true"`, `"false"`) both render correctly in v10.0.0. Only an unquoted `false` changes behavior from v9.8.2.

## Migration Steps

### Option 1: No action required (recommended)

If you have not explicitly overridden any of the affected flags in your `values.yaml`, no action is required. The upgrade will maintain the default behavior (all flags enabled).

**Step 1:** Verify your current `values.yaml` does not contain overrides for these flags:

```bash
grep -E "(ALLOW_INSECURE_TLS|BULK_RECORDER_ENABLED|RATE_LIMIT_ENABLED)" values.yaml
```

**Step 2:** If the command returns no results, proceed with the upgrade using the standard command.

### Option 2: Explicitly set boolean values

If you have overridden any of the affected flags, look for unquoted `false` values: those are the only ones whose effect changes.

**Step 1:** Review your current `values.yaml` for any of these flags:

```bash
grep -A 5 "configmap:" values.yaml | grep -E "(ALLOW_INSECURE_TLS|BULK_RECORDER_ENABLED|RATE_LIMIT_ENABLED)"
```

**Step 2:** Quoted values need no change. `"false"` and `"true"` render as written in both versions:

```yaml
ledger:
  configmap:
    RATE_LIMIT_ENABLED: "false"   # "false" in v9.8.2 and in v10.0.0
    ALLOW_INSECURE_TLS: "true"    # "true" in v9.8.2 and in v10.0.0
```

An unquoted `false` is the one that changes:

```yaml
ledger:
  configmap:
    RATE_LIMIT_ENABLED: false     # "true" in v9.8.2, "false" in v10.0.0
```

**Step 3:** If you previously set any flag to `false` expecting it to be disabled, verify this is still your intent:

```yaml
ledger:
  configmap:
    # This will now actually disable rate limiting in v10.0.0
    RATE_LIMIT_ENABLED: false
    # Ensure you have ALLOW_RATELIMIT_DISABLED set if running in strict tier
    ALLOW_RATELIMIT_DISABLED: "Service processes batch jobs only, no user-facing API endpoints"
```

**Step 4:** If you want to re-enable a feature that was previously set to `false`, either remove the override or set it to `true`:

```yaml
ledger:
  configmap:
    # Explicitly enable rate limiting
    RATE_LIMIT_ENABLED: true
```

Or remove the override entirely to use the default:

```yaml
ledger:
  configmap:
    # RATE_LIMIT_ENABLED removed - will default to true
```

> **Note:** If you are unsure whether a flag was previously being ignored, check your running pods' environment variables before upgrading:

```bash
kubectl exec -n midaz deployment/midaz-ledger -- env | grep -E "(ALLOW_INSECURE_TLS|BULK_RECORDER_ENABLED|RATE_LIMIT_ENABLED)"
```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.0 -n midaz
```
<!-- {% endraw %} -->
