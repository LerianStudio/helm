# Helm Upgrade from v0.4.1 to v0.4.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. JD_ISPB Environment Variable Handling](#1-jd_ispb-environment-variable-handling)
- **[Migration Impact](#migration-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** that fixes the handling of the `JD_ISPB` environment variable in the chart templates. The application no longer reads `JD_ISPB` from the environment — it now resolves the plugin's ISPB from the systemplane key `tenancy/jd_integration_binding` and fails the boot with a named error if the value is missing or malformed.

The chart previously enforced an 8-character length check and rejected missing values in single-tenant worker mode to prevent silent MED poller shutdowns. That validation is now redundant (the app gates it at boot), and emitting an empty default would trigger ignored-env warnings on every pod.

| Setting | v0.4.1 | v0.4.2 |
|---------|--------|--------|
| Chart Version | 0.4.1 | 0.4.2 |
| `JD_ISPB` validation | Enforced by chart | Removed (app enforces at boot) |
| `JD_ISPB` emission | Always emitted | Only emitted when explicitly set |

## Fixes

### 1. JD_ISPB Environment Variable Handling

**What changed:**

The chart no longer validates or unconditionally emits the `JD_ISPB` environment variable. The application now reads the plugin's ISPB from the systemplane integration binding and fails the boot if the value is missing or malformed, making the chart-side validation redundant.

**Before (v0.4.1):**

```yaml
{{- $ispb := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_ISPB" "default" "") -}}
{{- $multiTenant := eq (include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "MULTI_TENANT_ENABLED" "default" "false")) "true" -}}
{{- if or (and $ispb (ne (len $ispb) 8)) (and $root.Values.worker.enabled (not $multiTenant) (not $ispb)) -}}
{{- fail (printf "\n\nERROR: JD_ISPB must be exactly 8 characters when the worker runs in single-tenant mode; got %d.\nThe worker gates every MED poller on this length and skips them ALL with one WARN\nwhen it does not match — including med_settlement_reconcile, which commits or cancels\nreserved money. A missing or wrong-length value degrades the money path silently.\n" (len $ispb)) -}}
{{- end }}
JD_BASE_URL: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_BASE_URL" "default" "") | quote }}
JD_ISPB: {{ $ispb | quote }}
```

The chart enforced:
- An 8-character length requirement for `JD_ISPB`
- A presence check when the worker was enabled in single-tenant mode
- Unconditional emission of the variable (even when empty)

**After (v0.4.2):**

```yaml
{{- $ispb := include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_ISPB" "default" "") -}}
JD_BASE_URL: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_BASE_URL" "default" "") | quote }}
{{- if $ispb }}
JD_ISPB: {{ $ispb | quote }}
{{- end }}
```

The chart now:
- Removes all validation logic (length check, presence check, multi-tenant gate)
- Only emits `JD_ISPB` when an operator explicitly sets it in `api.configmap` or `worker.configmap`
- Passes the value through unchanged if present

**Why this matters:**

The application changed how it resolves the ISPB:

| Deployment Mode | v0.4.1 Behavior | v0.4.2 Behavior |
|-----------------|-----------------|-----------------|
| Single-tenant | Read from `JD_ISPB` env var; missing/malformed value silently skipped all MED pollers | Read from systemplane `tenancy/jd_integration_binding`; missing/malformed value **fails the boot** with named error |
| Multi-tenant | Resolved from tenant bindings; `JD_ISPB` ignored | Resolved from tenant bindings; `JD_ISPB` ignored |

The chart's validation existed only to compensate for the silent skip behavior in v0.4.1. Now that the app fails the boot explicitly, duplicating the check in the chart:
- Gives operators two places to be told the same thing (one as a render error, one as a boot failure)
- Creates a false dependency on an environment variable the app no longer reads

**Emission behavior:**

| Scenario | v0.4.1 | v0.4.2 |
|----------|--------|--------|
| Operator sets `JD_ISPB: "12345678"` | Emitted; validated | Emitted; not validated |
| Operator sets `JD_ISPB: ""` | Emitted as empty string; fails validation if worker enabled | **Not emitted** |
| Operator omits `JD_ISPB` | Emitted as empty string; fails validation if worker enabled | **Not emitted** |

**Why conditional emission matters:**

1. **Prevents ignored-env warnings:** The application's ignored-env scanner reports a `WARN` for any environment variable present in the container but not consumed by the app. Emitting an empty default would log a warning on every pod for a value the chart itself invented.

2. **Preserves backward compatibility:** If a chart bumped ahead of the image hands an older app (still reading `JD_ISPB` from the environment) no ISPB at all, it would trigger the silent MED-poller shutdown this change is designed to remove. Passing a set value through costs one startup `WARN` on a current image (ignored-env scanner) and nothing on an old one.

## Migration Impact

**No action required** for most deployments. The chart will continue to pass through any explicitly set `JD_ISPB` value, and the application will resolve the ISPB from the systemplane integration binding.

> **Important:** If you are running the worker in single-tenant mode, ensure the systemplane key `tenancy/jd_integration_binding` contains a valid 8-character ISPB in the `ispb` field. The application will fail the boot if this value is missing or malformed, preventing silent MED poller shutdowns.

> **Note:** If you previously set `JD_ISPB` in `api.configmap` or `worker.configmap`, the chart will continue to emit it. Current application versions will log a `WARN` about the ignored variable but will not fail. You may remove the value from your configuration to eliminate the warning.

**For operators upgrading the chart ahead of the application image:**

If you upgrade to chart v0.4.2 but continue running an older application image (one that still reads `JD_ISPB` from the environment), the chart will only emit the variable if you explicitly set it. If you omit it, older images will not receive an ISPB and will silently skip all MED pollers. To preserve compatibility during a staged rollout:

```yaml
api:
  configmap:
    JD_ISPB: "12345678"  # Keep this until the image is upgraded

worker:
  configmap:
    JD_ISPB: "12345678"  # Keep this until the image is upgraded
```

Once the application image is upgraded to a version that reads from the systemplane, you can remove these values.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.2 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.2 -n plugin-br-pix-jd
```
