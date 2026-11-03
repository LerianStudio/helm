<!-- {% raw %} -->
# Helm Upgrade from v2.0.1 to v2.0.2

## Topics

- **[License Configuration Changes](#license-configuration-changes)**
  - [IS_DEVELOPMENT deprecation](#is_development-deprecation)
  - [License validation behavior](#license-validation-behavior)
  - [Template guard simplification](#template-guard-simplification)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## License Configuration Changes

### IS_DEVELOPMENT deprecation

The `streamingHub.configmap.IS_DEVELOPMENT` value is deprecated and ignored.

| Setting | v2.0.1 | v2.0.2 |
|---------|--------|--------|
| `IS_DEVELOPMENT` behavior | Selects dev license server when `"true"` | Deprecated: accepted but ignored |
| Validation with `STREAMING_HUB_ENV=production` | Fails render if `IS_DEVELOPMENT="true"` | No validation (field ignored) |

**Before (v2.0.1):**

```yaml
streamingHub:
  configmap:
    IS_DEVELOPMENT: "true"
    STREAMING_HUB_ENV: "staging"  # Required when IS_DEVELOPMENT="true"
```

**After (v2.0.2):**

```yaml
streamingHub:
  configmap:
    # IS_DEVELOPMENT is deprecated and ignored
```

**Impact:** 

- The `IS_DEVELOPMENT` field is still accepted in `streamingHub.configmap` to ensure existing values files validate during upgrade, but it is never rendered to the ConfigMap and has no effect on application behavior

**Configuration:**

The field remains documented in `values.yaml` with updated comments:

```yaml
streamingHub:
  configmap:
    # IS_DEVELOPMENT — deprecated: still accepted so upgrades keep validating,
    #   never rendered, no effect. Products validate only on the production
    #   license server.
```

> **Important:** If you previously set `IS_DEVELOPMENT: "true"` to use development license keys, you must obtain a production license key before upgrading. Development license keys will fail validation against the production license server.

### License validation behavior

| Setting | v2.0.1 | v2.0.2 |
|---------|--------|--------|
| Required license config | `ORGANIZATION_IDS="global"` | `ORGANIZATION_IDS="global"` |
| `IS_DEVELOPMENT` + `STREAMING_HUB_ENV=production` | Fails render (ErrLicenseDevServerInProduction) | No validation (field ignored) |

**Removed validation:**

The chart no longer fails the render when `IS_DEVELOPMENT="true"` is set alongside `STREAMING_HUB_ENV=production`. This validation was removed because `IS_DEVELOPMENT` is now ignored.

**Remaining validation:**

The `ORGANIZATION_IDS` guard remains active and unchanged:

```yaml
streamingHub:
  configmap:
    ORGANIZATION_IDS: "global"  # Must be exactly "global" (case-sensitive)
```

> **Warning:** Setting `ORGANIZATION_IDS` to any value other than exactly `"global"` (e.g., `"GLOBAL"`, `"global,org-123"`) will cause both the Helm render and application boot to fail with `ErrLicenseOrganizationIDsInvalid`.

### Template guard simplification

The `streaming-hub.licenseGuard` helper in `templates/_helpers.tpl` has been simplified to remove the `IS_DEVELOPMENT` + `STREAMING_HUB_ENV` cross-validation.

**Before (v2.0.1):**

```yaml
{{- $isDev := toString (ternary (get $x "IS_DEVELOPMENT") (get $cm "IS_DEVELOPMENT" | default "") (hasKey $x "IS_DEVELOPMENT")) -}}
{{- $env := trim (toString (ternary (get $x "STREAMING_HUB_ENV") (get $cm "STREAMING_HUB_ENV" | default "production") (hasKey $x "STREAMING_HUB_ENV"))) -}}
{{- if and (eq $isDev "true") (eq $env "production") -}}
{{- fail "\n\nERROR: IS_DEVELOPMENT=\"true\" points license validation at the DEVELOPMENT license server, which the app refuses when STREAMING_HUB_ENV=production (ErrLicenseDevServerInProduction). Unset streamingHub.configmap.IS_DEVELOPMENT, or set STREAMING_HUB_ENV to a non-production environment." -}}
{{- end -}}
```

**After (v2.0.2):**

```yaml
# IS_DEVELOPMENT validation block removed entirely
```

**Impact:** 

- Helm renders that previously failed with `ErrLicenseDevServerInProduction` will now succeed
- The `IS_DEVELOPMENT` field is silently ignored during rendering

**ConfigMap rendering:**

The `IS_DEVELOPMENT` field is no longer rendered to the ConfigMap, even when present in `streamingHub.configmap`:

**Before (v2.0.1):**

```yaml
data:
  ORGANIZATION_IDS: "global"
  IS_DEVELOPMENT: "true"  # Rendered when set
```

**After (v2.0.2):**

```yaml
data:
  ORGANIZATION_IDS: "global"
  # IS_DEVELOPMENT is never rendered
```

> **Note:** The `IS_DEVELOPMENT` key remains in the `$enumerated` list with a comment explaining it is deprecated and ignored. This ensures operators who set it via `streamingHub.configmap` do not accidentally have it rendered through the catch-all mechanism.

---

## Migration Steps

### Step 1: Review license key type

If you currently set `IS_DEVELOPMENT: "true"` in your values, verify your license key type:

```bash
# Check current configuration
helm get values streaming-hub -n streaming-hub | grep IS_DEVELOPMENT
```

**If `IS_DEVELOPMENT: "true"` is present:**

1. Confirm you have a **production license key** that validates against the production license server
2. If you only have a development license key, contact your Lerian Studio account representative to obtain a production key before upgrading

### Step 2: Update values.yaml

Remove or comment out the `IS_DEVELOPMENT` field from your values file:

```yaml
streamingHub:
  configmap:
    # IS_DEVELOPMENT: "true"  # Deprecated in v2.0.2, no longer needed
    ORGANIZATION_IDS: "global"
```

> **Note:** Leaving `IS_DEVELOPMENT` in your values file will not cause the upgrade to fail, but it has no effect and should be removed for clarity.

### Step 3: Verify ORGANIZATION_IDS

Ensure `ORGANIZATION_IDS` is set to exactly `"global"` (or left unset to use the chart default):

```yaml
streamingHub:
  configmap:
    ORGANIZATION_IDS: "global"  # Must be exactly "global"
```

### Step 4: Upgrade the chart

Proceed with the Helm upgrade using the updated values:

```bash
helm upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm \
  --version 2.0.2 \
  -n streaming-hub \
  -f values.yaml
```

### Step 5: Verify application startup

After the upgrade, confirm the application starts successfully and validates its license:

```bash
kubectl logs -n streaming-hub deployment/streaming-hub-all --tail=50 | grep -i license
```

Expected output should show successful license validation with no errors.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 2.0.2 -n streaming-hub
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 2.0.2 -n streaming-hub
```
<!-- {% endraw %} -->
