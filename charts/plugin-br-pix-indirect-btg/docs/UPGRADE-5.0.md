<!-- {% raw %} -->
# Helm Upgrade from v4.x to v5.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [Boolean flag handling for feature toggles](#boolean-flag-handling-for-feature-toggles)
- **[Template Changes](#template-changes)**
  - [New helper template for boolean defaults](#new-helper-template-for-boolean-defaults)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a major release that fixes boolean flag handling for feature toggles and telemetry configuration across the `inbound` and `outbound` services. The application version remains `1.11.0`, but the template logic for processing boolean values has changed to correctly handle explicit `false` values.

**Key changes:**

- New helper template `plugin-br-pix-indirect-btg.flagDefaultTrue` ensures boolean flags default to `true` while respecting explicit `false` values
- All feature toggle environment variables now use the new helper instead of the standard `default` function
- No values are removed or renamed, but the runtime behavior changes when you explicitly set a flag to `false`

**Expected upgrade path:** In-place Helm upgrade after reviewing which feature flags you have explicitly disabled.

## Breaking Changes

### Boolean flag handling for feature toggles

**What changed:**

In v4.2.0, the Helm template used the standard Sprig `default` function to set boolean flags. This function treats an explicit boolean `false` as an empty value and replaces it with the default (`"true"`), making it impossible to disable features by setting them to `false` in values.yaml.

In v5.0.0, a new helper template `plugin-br-pix-indirect-btg.flagDefaultTrue` correctly distinguishes between:
- **Undefined/empty** → defaults to `"true"`
- **Explicit `false`** → renders as `"false"`
- **Explicit `true`** → renders as `"true"`

**Affected configuration flags:**

The following environment variables in both `inbound` and `outbound` services now use the new boolean handling:

**Inbound service:**
- `ENABLE_TELEMETRY`
- `WEBHOOK_ENTITY_DICT_CLAIM_ENABLED`
- `WEBHOOK_ENTITY_INFRACTION_REPORT_V2_ENABLED`
- `WEBHOOK_ENTITY_DICT_REFUND_ENABLED`
- `WEBHOOK_ENTITY_DICT_CID_FILE_ENABLED`
- `WEBHOOK_ENTITY_PIX_DOWNLOAD_ENABLED`
- `WEBHOOK_ENTITY_PIX_PAYMENT_ENABLED`
- `WEBHOOK_ENTITY_PIX_PAYMENT_INBOUND_ENABLED`
- `WEBHOOK_ENTITY_PIX_REVERSAL_ENABLED`
- `WEBHOOK_ENTITY_PIX_REVERSAL_INBOUND_ENABLED`
- `WEBHOOK_ENTITY_FUNDS_RECOVERY_ENABLED`
- `WEBHOOK_ENTITY_FUNDS_RECOVERY_EVENTS_ENABLED`
- `WEBHOOK_ENTITY_PAYMENT_INTRA_PSP_REFUND_ENABLED`
- `WEBHOOK_ENTITY_PAYMENT_INTRA_PSP_REPORT_ENABLED`
- `WEBHOOK_ENTITY_PAYMENT_INTRA_PSP_TRANSFER_ENABLED`
- `WEBHOOK_ENTITY_PIX_INTERNAL_TRANSACTIONS_REPORT_ENABLED`
- `WEBHOOK_ENTITY_PIX_RECURRENCE_PAYER_ENABLED`
- `WEBHOOK_ENTITY_PIX_RECURRENCE_COLLECTION_ENABLED`
- `WEBHOOK_ENTITY_SCHEDULE_TERMINAL_EVENT_ENABLED`
- `WEBHOOK_ENTITY_CASHOUT_TERMINAL_EVENT_ENABLED`
- `ALLOW_INSECURE_TLS`
- `RATE_LIMIT_ENABLED`

**Outbound service:**
- `ENABLE_TELEMETRY`
- `WEBHOOK_CIRCUIT_BREAKER_ENABLED`
- `WEBHOOK_DICT_CLAIM_ENABLED`
- `WEBHOOK_DICT_INFRACTION_REPORT_ENABLED`
- `WEBHOOK_DICT_REFUND_ENABLED`
- `WEBHOOK_TRANSFER_CASHIN_ENABLED`
- `WEBHOOK_TRANSFER_CASHOUT_ENABLED`
- `WEBHOOK_REFUND_CASHIN_ENABLED`
- `WEBHOOK_REFUND_CASHOUT_ENABLED`

**Why it matters:**

In v4.2.0, if you set any of these flags to `false` in your values file, the chart would silently ignore your configuration and enable the feature anyway. In v5.0.0, setting a flag to `false` will correctly disable the feature.

**Operational impact:**

| Scenario | v4.2.0 behavior | v5.0.0 behavior |
|----------|-----------------|-----------------|
| Flag not set in values | Defaults to `"true"` | Defaults to `"true"` (no change) |
| Flag set to `true` | Renders as `"true"` | Renders as `"true"` (no change) |
| Flag set to `false` | **Incorrectly renders as `"true"`** | **Correctly renders as `"false"`** |

> **Warning:** If you previously attempted to disable features by setting flags to `false` in your values file, those settings were ignored in v4.2.0. After upgrading to v5.0.0, those flags will take effect and the features will be disabled. Review your values file before upgrading.

**Example configuration change:**

**Before (v4.2.0):**

```yaml
inbound:
  configmap:
    ENABLE_TELEMETRY: false  # This was IGNORED - telemetry stayed enabled
    WEBHOOK_ENTITY_PIX_PAYMENT_ENABLED: false  # This was IGNORED - webhook stayed enabled
```

**After (v5.0.0):**

```yaml
inbound:
  configmap:
    ENABLE_TELEMETRY: false  # Now correctly disables telemetry
    WEBHOOK_ENTITY_PIX_PAYMENT_ENABLED: false  # Now correctly disables webhook
```

## Template Changes

### New helper template for boolean defaults

**What changed:**

A new helper template `plugin-br-pix-indirect-btg.flagDefaultTrue` was added to `templates/_helpers.tpl`:

```yaml
{{/*
A flag that defaults to "true". Sprig `default` treats an explicit boolean false
as empty, so a bool is rendered as-is. Input: the value.
*/}}
{{- define "plugin-br-pix-indirect-btg.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

This helper checks if the input is a boolean type. If it is, it renders the boolean value as-is. If it's not a boolean (empty, string, etc.), it applies the default value of `"true"`.

**Template usage change:**

**Before (v4.2.0):**

```yaml
ENABLE_TELEMETRY: {{ .Values.inbound.configmap.ENABLE_TELEMETRY | default "true" | quote }}
WEBHOOK_ENTITY_PIX_PAYMENT_ENABLED: {{ .Values.inbound.configmap.WEBHOOK_ENTITY_PIX_PAYMENT_ENABLED | default "true" | quote }}
```

**After (v5.0.0):**

```yaml
ENABLE_TELEMETRY: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.inbound.configmap.ENABLE_TELEMETRY | quote }}
WEBHOOK_ENTITY_PIX_PAYMENT_ENABLED: {{ include "plugin-br-pix-indirect-btg.flagDefaultTrue" .Values.inbound.configmap.WEBHOOK_ENTITY_PIX_PAYMENT_ENABLED | quote }}
```

**Operational impact:**

This change affects how the ConfigMap is rendered. If you have been setting boolean flags to `false` expecting them to be honored, they will now work correctly. If you have been relying on the broken behavior (where `false` was ignored), you need to remove those flags from your values file or set them to `true`.

## Configuration Reference

All affected flags continue to accept boolean values (`true` or `false`) or can be left undefined to use the default (`true`). No new configuration keys were added.

**Flag behavior reference:**

| Flag | Default | Description |
|------|---------|-------------|
| `inbound.configmap.ENABLE_TELEMETRY` | `true` | Enable OpenTelemetry instrumentation for the inbound service |
| `inbound.configmap.WEBHOOK_ENTITY_*_ENABLED` | `true` | Enable webhook processing for specific entity types (20 different entity flags) |
| `inbound.configmap.ALLOW_INSECURE_TLS` | `true` | Allow insecure TLS connections (development/testing only) |
| `inbound.configmap.RATE_LIMIT_ENABLED` | `true` | Enable rate limiting for inbound requests |
| `outbound.configmap.ENABLE_TELEMETRY` | `true` | Enable OpenTelemetry instrumentation for the outbound service |
| `outbound.configmap.WEBHOOK_CIRCUIT_BREAKER_ENABLED` | `true` | Enable circuit breaker for outbound webhook delivery |
| `outbound.configmap.WEBHOOK_*_ENABLED` | `true` | Enable webhook delivery for specific entity types (8 different entity flags) |

**Example values configuration:**

```yaml
inbound:
  configmap:
    # Telemetry configuration
    ENABLE_TELEMETRY: true  # Default - can be omitted

    # Disable specific webhook entities
    WEBHOOK_ENTITY_PIX_DOWNLOAD_ENABLED: false
    WEBHOOK_ENTITY_DICT_CID_FILE_ENABLED: false

    # Security configuration
    ALLOW_INSECURE_TLS: false  # Recommended for production
    RATE_LIMIT_ENABLED: true   # Default - can be omitted

outbound:
  configmap:
    # Telemetry configuration
    ENABLE_TELEMETRY: true  # Default - can be omitted

    # Disable specific outbound webhooks
    WEBHOOK_DICT_CLAIM_ENABLED: false
    WEBHOOK_TRANSFER_CASHIN_ENABLED: false

    # Circuit breaker configuration
    WEBHOOK_CIRCUIT_BREAKER_ENABLED: true  # Default - can be omitted
```

## Migration Steps

This upgrade requires reviewing your current values configuration to identify any boolean flags set to `false` that were previously ignored.

**Recommended migration process:**

1. **Audit your current values file:**

   ```bash
   grep -E "(ENABLED|TELEMETRY|INSECURE|RATE_LIMIT).*false" values.yaml
   ```

   This will show all flags you've set to `false` that will now take effect.

2. **Review the list of affected flags** in the [Breaking Changes](#boolean-flag-handling-for-feature-toggles) section.

3. **For each flag set to `false`, decide:**
   - **Keep disabled:** The flag was intentionally set to `false` and should remain disabled after upgrade
   - **Re-enable:** The flag was set to `false` expecting it to be ignored; remove it from values.yaml or set to `true`

4. **Preview the changes** using helm-diff (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

5. **Run the upgrade** during a maintenance window:

   ```bash
   helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.0.0 -n plugin-br-pix-indirect-btg -f values.yaml
   ```

6. **Verify all pods are running:**

   ```bash
   kubectl get pods -n plugin-br-pix-indirect-btg
   ```

7. **Check ConfigMap values to confirm flags are set correctly:**

   ```bash
   kubectl get configmap plugin-br-pix-indirect-btg-inbound -n plugin-br-pix-indirect-btg -o yaml | grep -E "(ENABLED|TELEMETRY)"
   kubectl get configmap plugin-br-pix-indirect-btg-outbound -n plugin-br-pix-indirect-btg -o yaml | grep -E "(ENABLED|TELEMETRY)"
   ```

8. **Monitor service logs for any unexpected behavior:**

   ```bash
   kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=inbound --tail=100
   kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=outbound --tail=100
   ```

> **Important:** The upgrade triggers a rolling restart of the `inbound` and `outbound` deployments because the ConfigMap content changes. Depending on your replica count and readiness probe timing, this may cause brief service interruptions.

> **Note:** If you have no boolean flags set to `false` in your values file, this upgrade will have no runtime impact. The default behavior (all features enabled) remains unchanged.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.0.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.0.0 -n plugin-br-pix-indirect-btg
```
<!-- {% endraw %} -->
