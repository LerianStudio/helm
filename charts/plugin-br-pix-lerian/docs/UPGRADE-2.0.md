<!-- {% raw %} -->
# Helm Upgrade from v1.0.2 to v2.0.0

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. Boolean Flag Handling for Default-True Values](#1-boolean-flag-handling-for-default-true-values)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### 1. Boolean Flag Handling for Default-True Values

**What changed:**

The chart now uses a new template helper `plugin-br-pix-lerian.flagDefaultTrue` to handle boolean environment variables that default to `"true"`. This affects four configuration keys across three components:

- `dictHubVsync.configmap.VSYNC_ENABLED`
- `dictHubVsync.configmap.RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK`
- `dictHubVsync.configmap.ALLOW_INSECURE_TLS`
- `dictSystemplane.configmap.VSYNC_ENABLED`
- `dictSystemplane.configmap.VSYNC_FILE_RECON_ENABLED`
- `pixauto.configmap.SWAGGER_ENABLED`

| Setting | v1.0.2 | v2.0.0 |
|---------|--------|--------|
| `dictHubVsync.configmap.VSYNC_ENABLED` | `{{ $cm.VSYNC_ENABLED \| default "true" \| quote }}` | `{{ include "plugin-br-pix-lerian.flagDefaultTrue" $cm.VSYNC_ENABLED \| quote }}` |
| `dictHubVsync.configmap.RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK` | `{{ $cm.RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK \| default "true" \| quote }}` | `{{ include "plugin-br-pix-lerian.flagDefaultTrue" $cm.RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK \| quote }}` |
| `dictHubVsync.configmap.ALLOW_INSECURE_TLS` | `{{ $cm.ALLOW_INSECURE_TLS \| default "true" \| quote }}` | `{{ include "plugin-br-pix-lerian.flagDefaultTrue" $cm.ALLOW_INSECURE_TLS \| quote }}` |
| `dictSystemplane.configmap.VSYNC_ENABLED` | `{{ $cm.VSYNC_ENABLED \| default "true" \| quote }}` | `{{ include "plugin-br-pix-lerian.flagDefaultTrue" $cm.VSYNC_ENABLED \| quote }}` |
| `dictSystemplane.configmap.VSYNC_FILE_RECON_ENABLED` | `{{ $cm.VSYNC_FILE_RECON_ENABLED \| default "true" \| quote }}` | `{{ include "plugin-br-pix-lerian.flagDefaultTrue" $cm.VSYNC_FILE_RECON_ENABLED \| quote }}` |
| `pixauto.configmap.SWAGGER_ENABLED` | `{{ $cm.SWAGGER_ENABLED \| default "true" \| quote }}` | `{{ include "plugin-br-pix-lerian.flagDefaultTrue" $cm.SWAGGER_ENABLED \| quote }}` |

**Why it matters:**

The Sprig `default` function treats an explicit boolean `false` as an empty value, which causes `default "true"` to replace it with `"true"`. This means that in v1.0.2, if you explicitly set a flag to `false` in `values.yaml`, the chart would ignore your setting and emit `"true"` anyway.

**Example of the v1.0.2 bug:**

```yaml
dictHubVsync:
  configmap:
    VSYNC_ENABLED: false  # Intended to disable VSync
```

In v1.0.2, the rendered ConfigMap would contain:

```yaml
VSYNC_ENABLED: "true"  # Bug: explicit false was ignored
```

The new `flagDefaultTrue` helper correctly handles explicit boolean `false` values:

- If the value is a boolean (true or false), it renders as-is: `true` or `false`
- If the value is a non-empty string, it renders as-is: `"custom-value"`
- If the value is empty/unset, it defaults to `"true"`

**How to handle it:**

#### Option 1: Accept the fix (recommended)

If you have not explicitly set any of the affected flags to `false` in your `values.yaml`, no action is required. The upgrade will preserve the existing behavior (all flags default to `"true"`).

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.0 -n plugin-br-pix-lerian
```

#### Option 2: Verify explicit false values

If you **have** explicitly set any of the affected flags to `false` in your `values.yaml`, verify that your deployment is ready for the flag to actually be disabled. In v1.0.2, the flag was silently forced to `"true"` despite your configuration, so the application has been running with the feature enabled.

**Example: Disabling VSync in dict-hub-vsync**

If your `values.yaml` contains:

```yaml
dictHubVsync:
  configmap:
    VSYNC_ENABLED: false
```

In v1.0.2, `VSYNC_ENABLED` was rendered as `"true"` (bug), so VSync was running. In v2.0.0, `VSYNC_ENABLED` will be rendered as `"false"` (correct), and VSync will actually be disabled.

**Before upgrading, confirm:**

1. The application is ready for the feature to be disabled
2. Dependent services or workflows will not break when the feature is turned off
3. Monitoring and alerting are configured to detect the state change

If you are unsure, **remove the explicit `false` setting** from your `values.yaml` before upgrading to preserve the current behavior (feature enabled):

```yaml
dictHubVsync:
  configmap:
    # VSYNC_ENABLED: false  # Remove this line to keep VSync enabled
```

**Affected flags and their defaults:**

| Component | Flag | Default | Description |
|-----------|------|---------|-------------|
| `dictHubVsync` | `VSYNC_ENABLED` | `"true"` | Enable VSync reconciliation worker |
| `dictHubVsync` | `RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK` | `"true"` | Allow insecure RabbitMQ health checks |
| `dictHubVsync` | `ALLOW_INSECURE_TLS` | `"true"` | Allow insecure TLS connections |
| `dictSystemplane` | `VSYNC_ENABLED` | `"true"` | Enable VSync in dict-systemplane |
| `dictSystemplane` | `VSYNC_FILE_RECON_ENABLED` | `"true"` | Enable file reconciliation in VSync |
| `pixauto` | `SWAGGER_ENABLED` | `"true"` | Enable Swagger UI for Pix Automático |

> **Warning:** If you have explicitly set any of these flags to `false` in your `values.yaml`, the v2.0.0 upgrade will **actually disable the feature** for the first time. In v1.0.2, the flag was silently ignored and the feature remained enabled. Review your configuration and confirm that disabling the feature is safe before upgrading.

**Before (v1.0.2) template logic:**

```yaml
VSYNC_ENABLED: {{ $cm.VSYNC_ENABLED | default "true" | quote }}
```

**After (v2.0.0) template logic:**

```yaml
VSYNC_ENABLED: {{ include "plugin-br-pix-lerian.flagDefaultTrue" $cm.VSYNC_ENABLED | quote }}
```

**New helper definition in `_helpers.tpl`:**

```yaml
{{/*
A flag that defaults to "true". Sprig `default` treats an explicit boolean false
as empty, so a bool is rendered as-is. Input: the value.
*/}}
{{- define "plugin-br-pix-lerian.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

**Migration steps:**

1. **Audit your `values.yaml`** for explicit `false` settings on the affected flags:

```bash
grep -E "(VSYNC_ENABLED|RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK|ALLOW_INSECURE_TLS|VSYNC_FILE_RECON_ENABLED|SWAGGER_ENABLED).*false" values.yaml
```

2. **For each match**, decide whether to:
   - **Keep the `false` setting** (the feature will be disabled for the first time in v2.0.0)
   - **Remove the setting** (the feature will remain enabled with the default `"true"`)

3. **Test the configuration** in a non-production environment before upgrading production:

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.0 -n plugin-br-pix-lerian-staging
```

4. **Monitor the affected components** after upgrade to confirm the flags are rendered correctly:

```bash
kubectl get configmap dict-hub-vsync -n plugin-br-pix-lerian -o yaml | grep VSYNC_ENABLED
kubectl get configmap dict-systemplane -n plugin-br-pix-lerian -o yaml | grep VSYNC_ENABLED
kubectl get configmap pixauto -n plugin-br-pix-lerian -o yaml | grep SWAGGER_ENABLED
```

> **Note:** This is a **bug fix**, not a breaking change in the traditional sense. The chart now correctly respects explicit `false` values, which it silently ignored in v1.0.2. If you have not set any of the affected flags to `false`, the upgrade is a no-op.

## Configuration Reference

### New Template Helper

The chart introduces a new template helper in `templates/_helpers.tpl`:

```yaml
{{/*
A flag that defaults to "true". Sprig `default` treats an explicit boolean false
as empty, so a bool is rendered as-is. Input: the value.
*/}}
{{- define "plugin-br-pix-lerian.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

| Helper | Input | Output | Description |
|--------|-------|--------|-------------|
| `plugin-br-pix-lerian.flagDefaultTrue` | boolean `true` | `"true"` | Renders boolean true as string "true" |
| `plugin-br-pix-lerian.flagDefaultTrue` | boolean `false` | `"false"` | Renders boolean false as string "false" (fix for Sprig `default` bug) |
| `plugin-br-pix-lerian.flagDefaultTrue` | string `"custom"` | `"custom"` | Passes through non-empty strings as-is |
| `plugin-br-pix-lerian.flagDefaultTrue` | empty/unset | `"true"` | Defaults to "true" when value is not provided |

**Usage example:**

```yaml
dictHubVsync:
  configmap:
    VSYNC_ENABLED: false  # Explicit boolean false
```

**Rendered ConfigMap (v2.0.0):**

```yaml
data:
  VSYNC_ENABLED: "false"  # Correctly rendered as "false"
```

**Rendered ConfigMap (v1.0.2 — bug):**

```yaml
data:
  VSYNC_ENABLED: "true"  # Incorrectly forced to "true"
```

### Affected Configuration Keys

| Component | ConfigMap Key | Default | Description |
|-----------|---------------|---------|-------------|
| `dictHubVsync` | `VSYNC_ENABLED` | `"true"` | Enable VSync reconciliation worker for DICT hub |
| `dictHubVsync` | `RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK` | `"true"` | Allow insecure health checks for RabbitMQ (dev/staging only) |
| `dictHubVsync` | `ALLOW_INSECURE_TLS` | `"true"` | Allow insecure TLS connections (dev/staging only) |
| `dictSystemplane` | `VSYNC_ENABLED` | `"true"` | Enable VSync in dict-systemplane |
| `dictSystemplane` | `VSYNC_FILE_RECON_ENABLED` | `"true"` | Enable file reconciliation in VSync for dict-systemplane |
| `pixauto` | `SWAGGER_ENABLED` | `"true"` | Enable Swagger UI for Pix Automático API documentation |

**Example values.yaml override:**

```yaml
dictHubVsync:
  configmap:
    VSYNC_ENABLED: true  # Explicit true (optional, this is the default)
    RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK: false  # Disable insecure health checks
    ALLOW_INSECURE_TLS: false  # Require secure TLS

dictSystemplane:
  configmap:
    VSYNC_ENABLED: true
    VSYNC_FILE_RECON_ENABLED: false  # Disable file reconciliation

pixauto:
  configmap:
    SWAGGER_ENABLED: false  # Disable Swagger UI in production
```

> **Important:** In v1.0.2, setting any of these flags to `false` had no effect — the chart always rendered `"true"`. In v2.0.0, `false` values are correctly respected.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.0 -n plugin-br-pix-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.0 -n plugin-br-pix-lerian
```
<!-- {% endraw %} -->
