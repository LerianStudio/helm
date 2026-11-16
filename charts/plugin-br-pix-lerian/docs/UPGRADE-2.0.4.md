<!-- {% raw %} -->
# Helm Upgrade from v2.0.3 to v2.0.4

## Topics

- **[Fixes](#fixes)**
  - [1. Chart Documentation Link Update](#1-chart-documentation-link-update)
  - [2. Pixauto Authentication Check Now Respects Global Auth Flag](#2-pixauto-authentication-check-now-respects-global-auth-flag)
  - [3. SPI Service Port Resolution Fix](#3-spi-service-port-resolution-fix)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Chart Documentation Link Update

**What changed:**

The dependency documentation comment in `Chart.yaml` has been simplified. The previous version pointed to an external documentation URL; the new version states that each dependency is documented in its own chart.

| Setting | v2.0.3 | v2.0.4 |
|---------|--------|--------|
| Dependencies documentation comment | `To understand the purpose and configuration of each dependency, visit: https://docs.lerian.studio/docs/midaz-components` | `The purpose and configuration of each dependency is documented in its own chart.` |

**Why it matters:**

This is a documentation-only change. It does not affect the runtime behavior of the chart or require any action from operators. The change clarifies that dependency documentation is self-contained within each dependency chart rather than centralized in external documentation.

**How to handle it:**

No action is required. This change does not affect your deployment.

**Before (v2.0.3) Chart.yaml:**

```yaml
# This Helm chart includes multiple dependencies required for the application.
# To understand the purpose and configuration of each dependency, visit:
# https://docs.lerian.studio/docs/midaz-components
dependencies:
  # ...
```

**After (v2.0.4) Chart.yaml:**

```yaml
# This Helm chart includes multiple dependencies required for the application.
# The purpose and configuration of each dependency is documented in its own chart.
dependencies:
  # ...
```

### 2. Pixauto Authentication Check Now Respects Global Auth Flag

**What changed:**

The `appsIngress` template now resolves the `PLUGIN_AUTH_ENABLED` default value for the `pixauto` component from `global.auth.enabled` before falling back to `"false"`. Previously, the check always used `"false"` as the default, which meant that if you set `global.auth.enabled=true` but did not explicitly set `pixauto.configmap.PLUGIN_AUTH_ENABLED`, the ingress validation would incorrectly conclude that authentication was disabled.

**Why it matters:**

If you publish the Pix Automático API via `appsIngress` with `global.auth.enabled=true` but without an explicit `pixauto.configmap.PLUGIN_AUTH_ENABLED="true"`, the previous version would fail the upgrade with an error message stating that authentication was not enabled. The new version correctly recognizes that `global.auth.enabled=true` enables authentication for pixauto (unless explicitly overridden), and the validation passes.

**How to handle it:**

#### If you do not publish pixauto via appsIngress

No action is required. This change only affects deployments that include pixauto routes in `appsIngress.routes`.

#### If you publish pixauto via appsIngress

The recommended configuration is to set `global.auth.enabled=true` (which is already the default in `values-template.yaml`). The chart will now correctly recognize this as enabling authentication for pixauto.

**Before (v2.0.3) ingress-apps.yaml:**

```yaml
{{- $authState := include "plugin-br-pix-lerian.envGateState" (dict "componentValues" .Values.pixauto "componentKey" "pixauto" "key" "PLUGIN_AUTH_ENABLED" "default" "false") }}
{{- if eq $authState "off" }}
{{- fail (printf "plugin-br-pix-lerian: appsIngress publishes Pix Automatico but the effective PLUGIN_AUTH_ENABLED for the pixauto component is not a true value. The app appends its authorize middleware only when auth is enabled, so EVERY pixauto route would be served without authentication - including the payer routes under /pixauto/v1 that create, decide and cancel mandates. Fix by setting pixauto.configmap.PLUGIN_AUTH_ENABLED=%q (values-template.yaml already does), or by removing the pixauto route(s) from appsIngress.routes if this environment should not expose Pix Automatico. The value is resolved across pixauto.extraEnvVars, pixauto.secrets and pixauto.configmap in that order of precedence." "true") }}
{{- end }}
```

**After (v2.0.4) ingress-apps.yaml:**

```yaml
{{- $authState := include "plugin-br-pix-lerian.envGateState" (dict "componentValues" .Values.pixauto "componentKey" "pixauto" "key" "PLUGIN_AUTH_ENABLED" "default" (include "lerian-common.globalValue" (dict "context" $ "configmap" dict "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "false"))) }}
{{- if eq $authState "off" }}
{{- fail (printf "plugin-br-pix-lerian: appsIngress publishes Pix Automatico but the effective PLUGIN_AUTH_ENABLED for the pixauto component is not a true value. The app appends its authorize middleware only when auth is enabled, so EVERY pixauto route would be served without authentication - including the payer routes under /pixauto/v1 that create, decide and cancel mandates. Fix by setting global.auth.enabled=true or pixauto.configmap.PLUGIN_AUTH_ENABLED=%q (values-template.yaml does it through global.auth.enabled=true), or by removing the pixauto route(s) from appsIngress.routes if this environment should not expose Pix Automatico. The value is resolved across pixauto.extraEnvVars, pixauto.secrets and pixauto.configmap in that order of precedence." "true") }}
{{- end }}
```

> **Note:** The error message has also been updated to reflect the new resolution order: `global.auth.enabled=true` or `pixauto.configmap.PLUGIN_AUTH_ENABLED="true"`.

**Resolution order:**

The `PLUGIN_AUTH_ENABLED` value for pixauto is now resolved in the following order:

1. `pixauto.extraEnvVars.PLUGIN_AUTH_ENABLED` (highest precedence)
2. `pixauto.secrets.PLUGIN_AUTH_ENABLED`
3. `pixauto.configmap.PLUGIN_AUTH_ENABLED`
4. `global.auth.enabled` (new in v2.0.4)
5. `"false"` (default)

If you have `global.auth.enabled=true` in your values, pixauto authentication is now considered enabled unless you explicitly override it at the component level.

### 3. SPI Service Port Resolution Fix

**What changed:**

The `pixauto` ConfigMap now derives the `SPI_BASE_URL` default from the `spi.service.port` value instead of hardcoding port `4000`. Previously, unless you set `spi.service.port` to `4000` or set `pixauto.configmap.SPI_BASE_URL`, the pixauto component would attempt to connect to the SPI on the wrong port. The default `spi.service.port` is `4101`.

| Setting | v2.0.3 | v2.0.4 |
|---------|--------|--------|
| `SPI_BASE_URL` default | `http://plugin-br-pix-lerian-spi:4000/spi` | `http://plugin-br-pix-lerian-spi:<spi.service.port>/spi` |

**Why it matters:**

If you did not explicitly set `pixauto.configmap.SPI_BASE_URL` and `spi.service.port` was not `4000` (its default is `4101`), the pixauto component would fail to connect to the SPI service, resulting in runtime errors when pixauto attempts to call the SPI.

**How to handle it:**

#### If you use the default SPI service port (4101)

No action is required. The default `SPI_BASE_URL` changes from `http://plugin-br-pix-lerian-spi:4000/spi` to `http://plugin-br-pix-lerian-spi:4101/spi`, which matches the default `spi.service.port`.

#### If you customized spi.service.port

The chart will now automatically use the correct port in the `SPI_BASE_URL` default. If you previously worked around this issue by explicitly setting `pixauto.configmap.SPI_BASE_URL`, you can now remove that override and rely on the chart's default resolution.

**Example:**

If you have:

```yaml
spi:
  service:
    port: 8080
```

The `SPI_BASE_URL` will now default to `http://plugin-br-pix-lerian-spi:8080/spi` without requiring an explicit override in `pixauto.configmap.SPI_BASE_URL`.

**Before (v2.0.3) pixauto/configmap.yaml:**

```yaml
SPI_BASE_URL: {{ $cm.SPI_BASE_URL | default "http://plugin-br-pix-lerian-spi:4000/spi" | quote }}
```

**After (v2.0.4) pixauto/configmap.yaml:**

```yaml
SPI_BASE_URL: {{ $cm.SPI_BASE_URL | default (printf "http://plugin-br-pix-lerian-spi:%v/spi" .Values.spi.service.port) | quote }}
```

> **Note:** If you explicitly set `pixauto.configmap.SPI_BASE_URL` in your values, it will continue to take precedence over the chart's default resolution.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-lerian oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace plugin-br-pix-lerian --version 2.0.4
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-lerian oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace plugin-br-pix-lerian --version 2.0.4
```
<!-- {% endraw %} -->
