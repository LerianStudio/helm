<!-- {% raw %} -->
# Helm Upgrade from v9.x to v10.x

# Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. Boolean Flag Handling for Default-True Values](#1-boolean-flag-handling-for-default-true-values)
- **[Configuration Reference](#configuration-reference)**
  - [Auth Service Flags](#auth-service-flags)
  - [Identity Service Flags](#identity-service-flags)
  - [Caradhras Service Flags](#caradhras-service-flags)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Your Current Boolean Overrides](#step-1-review-your-current-boolean-overrides)
  - [Step 2: Update Values for Explicit False](#step-2-update-values-for-explicit-false)
  - [Step 3: Test in Non-Production](#step-3-test-in-non-production)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Breaking Changes

### 1. Boolean Flag Handling for Default-True Values

Version 10.0.0 introduces a new template helper function `plugin-access-manager.flagDefaultTrue` that changes how boolean configuration flags are processed when they default to `"true"`.

**What changed:**

Previously, the chart used Sprig's `default` function directly to set default values for boolean flags. This caused an issue: when you explicitly set a flag to `false` in your `values.yaml`, Sprig would treat the boolean `false` as an "empty" value and replace it with the default `"true"` string.

The new helper function correctly distinguishes between:
- An explicit boolean `false` (which is preserved as `false`)
- An omitted/null value (which defaults to `"true"`)
- An explicit string value like `"false"` or `"0"` (which is preserved)

**Why this matters:**

If you have **explicitly set any of the affected flags to `false`** in your `values.yaml`, your configuration was silently ignored in v9.8.2 and the flag was treated as `"true"`. In v10.0.0, your explicit `false` will now be honored.

This means:
- **If you intended to disable a feature** but it was still enabled due to the bug, it will now correctly be disabled after upgrade
- **If you relied on the buggy behavior** (setting `false` but expecting `true`), your deployment will break

**Affected configuration flags:**

| Service | Flag | Default | Impact if Previously Set to `false` |
|---------|------|---------|--------------------------------------|
| Auth | `ALLOW_INSECURE_TLS` | `"true"` | TLS verification will now be enforced |
| Auth | `RUNNING_IN_DOCKER` | `"true"` | Container runtime detection changes |
| Auth | `RATE_LIMIT_ENABLED` | `"true"` | Rate limiting will be disabled |
| Auth | `CIRCUIT_BREAKER_ENABLED` | `"true"` | Circuit breaker will be disabled |
| Auth | `SWAGGER_ENABLED` | `"true"` | Swagger UI will be disabled |
| Auth | `AUTH_ENABLED` (used in helper check) | `"true"` | Authentication will be disabled |
| Identity | `ALLOW_INSECURE_TLS` | `"true"` | TLS verification will now be enforced |
| Identity | `AUTH_ENABLED` | `"true"` | Plugin auth integration will be disabled |
| Identity | `RATE_LIMIT_ENABLED` | `"true"` | Rate limiting will be disabled |
| Identity | `CIRCUIT_BREAKER_ENABLED` | `"true"` | Circuit breaker will be disabled |
| Caradhras | `allowInsecureTLS` | `"true"` | TLS verification will now be enforced |

**Before (v9.8.2):**

```yaml
# Template code - buggy behavior
ALLOW_INSECURE_TLS: {{ .Values.auth.configmap.ALLOW_INSECURE_TLS | default "true" | quote }}
```

If you set:

```yaml
auth:
  configmap:
    ALLOW_INSECURE_TLS: false
```

The result was `ALLOW_INSECURE_TLS: "true"` (your `false` was ignored).

**After (v10.0.0):**

```yaml
# Template code - correct behavior
ALLOW_INSECURE_TLS: {{ include "plugin-access-manager.flagDefaultTrue" .Values.auth.configmap.ALLOW_INSECURE_TLS | quote }}
```

With the same values:

```yaml
auth:
  configmap:
    ALLOW_INSECURE_TLS: false
```

The result is now correctly `ALLOW_INSECURE_TLS: "false"`.

> **Warning:** If you have any of the affected flags explicitly set to `false` in your values, review the [Migration Steps](#migration-steps) section carefully before upgrading. The behavior change may impact your deployment.

> **Important:** This is a **bug fix**, not a feature change. The intended behavior was always to respect explicit `false` values. However, because the bug may have masked configuration errors, this fix is released as a major version to ensure operators review their configurations.

# Configuration Reference

### Auth Service Flags

The following auth service flags now correctly handle explicit `false` values:

```yaml
auth:
  configmap:
    ALLOW_INSECURE_TLS: true
    RUNNING_IN_DOCKER: true
    RATE_LIMIT_ENABLED: true
    CIRCUIT_BREAKER_ENABLED: true
    SWAGGER_ENABLED: true
    AUTH_ENABLED: true
```

| Flag | Default | Description |
|------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `"true"` | Allow connections to services without TLS certificate verification |
| `RUNNING_IN_DOCKER` | `"true"` | Indicates the service is running in a containerized environment |
| `RATE_LIMIT_ENABLED` | `"true"` | Enable rate limiting for API requests |
| `CIRCUIT_BREAKER_ENABLED` | `"true"` | Enable circuit breaker pattern for external service calls |
| `SWAGGER_ENABLED` | `"true"` | Enable Swagger UI for API documentation |
| `AUTH_ENABLED` | `"true"` | Enable authentication checks (used in template helper logic) |

### Identity Service Flags

The following identity service flags now correctly handle explicit `false` values:

```yaml
identity:
  configmap:
    ALLOW_INSECURE_TLS: true
    AUTH_ENABLED: true
    RATE_LIMIT_ENABLED: true
    CIRCUIT_BREAKER_ENABLED: true
```

| Flag | Default | Description |
|------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `"true"` | Allow connections to services without TLS certificate verification |
| `AUTH_ENABLED` | `"true"` | Enable integration with plugin-auth service |
| `RATE_LIMIT_ENABLED` | `"true"` | Enable rate limiting for API requests |
| `CIRCUIT_BREAKER_ENABLED` | `"true"` | Enable circuit breaker pattern for external service calls |

### Caradhras Service Flags

The following caradhras service flag now correctly handles explicit `false` values:

```yaml
caradhras:
  allowInsecureTLS: true
```

| Flag | Default | Description |
|------|---------|-------------|
| `allowInsecureTLS` | `"true"` | Allow connections to PostgreSQL without TLS certificate verification |

> **Note:** All flags accept boolean values (`true`/`false`) or string values (`"true"`/`"false"`/`"1"`/`"0"`/`"t"`/`"T"`/`"TRUE"`/`"True"`). The new helper function handles all formats correctly.

# Migration Steps

### Step 1: Review Your Current Boolean Overrides

Check your `values.yaml` or Helm command-line overrides for any of the affected flags set to `false`:

```bash
# Review your current values
helm get values plugin-access-manager -n plugin-access-manager
```

Look for any of these patterns:

```yaml
auth:
  configmap:
    ALLOW_INSECURE_TLS: false
    RUNNING_IN_DOCKER: false
    RATE_LIMIT_ENABLED: false
    CIRCUIT_BREAKER_ENABLED: false
    SWAGGER_ENABLED: false
    AUTH_ENABLED: false

identity:
  configmap:
    ALLOW_INSECURE_TLS: false
    AUTH_ENABLED: false
    RATE_LIMIT_ENABLED: false
    CIRCUIT_BREAKER_ENABLED: false

caradhras:
  allowInsecureTLS: false
```

### Step 2: Update Values for Explicit False

For each flag you find set to `false`, determine if this was intentional:

#### Option 1: You Intended to Disable the Feature

If you wanted the feature disabled but it was running anyway due to the bug, **no action is required**. After upgrading to v10.0.0, your configuration will work as intended.

**Example:** You set `RATE_LIMIT_ENABLED: false` because your environment has external rate limiting, but rate limiting was still active. After upgrade, it will correctly be disabled.

#### Option 2: You Expected the Feature to Be Enabled

If you set `false` but expected the default `true` behavior (perhaps due to confusion or testing), you must update your values:

**Before (v9.8.2 values that relied on the bug):**

```yaml
auth:
  configmap:
    RATE_LIMIT_ENABLED: false  # This was ignored, rate limiting was still on
```

**After (v10.0.0 - remove the override to use default):**

```yaml
auth:
  configmap: {}
    # RATE_LIMIT_ENABLED omitted - defaults to "true"
```

Or explicitly set to `true`:

```yaml
auth:
  configmap:
    RATE_LIMIT_ENABLED: true
```

#### Option 3: You're Unsure

If you're not sure whether a `false` value was intentional, check your running pods to see the current effective configuration:

```bash
# Check auth service environment variables
kubectl exec -n plugin-access-manager deployment/plugin-access-manager-auth -- env | grep -E 'RATE_LIMIT_ENABLED|CIRCUIT_BREAKER_ENABLED|SWAGGER_ENABLED|ALLOW_INSECURE_TLS'

# Check identity service environment variables
kubectl exec -n plugin-access-manager deployment/plugin-access-manager-identity -- env | grep -E 'AUTH_ENABLED|RATE_LIMIT_ENABLED|CIRCUIT_BREAKER_ENABLED|ALLOW_INSECURE_TLS'
```

If the value is `"true"` in the running pod but `false` in your values, the bug was masking your configuration.

### Step 3: Test in Non-Production

Before upgrading production, test the upgrade in a non-production environment:

```bash
# Deploy to staging/dev with your current values
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 10.0.0 \
  -n plugin-access-manager-staging \
  -f values.yaml
```

Verify that:
- Services start successfully
- Features you intended to disable are actually disabled
- Features you intended to enable are still enabled
- No unexpected behavior changes occur

> **Important:** Pay special attention to `ALLOW_INSECURE_TLS` flags. If you set these to `false` expecting TLS verification to be enforced, but your certificates are not properly configured, pods may fail to start or lose connectivity to dependencies after upgrade.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.0 -n plugin-access-manager
```
<!-- {% endraw %} -->
