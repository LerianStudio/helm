<!-- {% raw %} -->
# Helm Upgrade from v0.5.8 to v0.5.9

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. IS_DEVELOPMENT Environment Variable Removed](#1-is_development-environment-variable-removed)
- **[Migration Impact](#migration-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** that removes `IS_DEVELOPMENT` from the chart's production validation gate and from its comments and error messages.

| Setting | v0.5.8 | v0.5.9 |
|---------|--------|--------|
| Chart Version | 0.5.8 | 0.5.9 |
| App Version | 1.5.0 | 1.5.0 |
| `IS_DEVELOPMENT` support | Documented in helpers | Removed from documentation and validation |

## Fixes

### 1. IS_DEVELOPMENT Environment Variable Removed

The `IS_DEVELOPMENT` environment variable has been removed from the chart's production validation gate and documentation.

**What changed:**

1. **Helper template documentation** — The `effectiveConfig` helper in `_helpers.tpl` previously documented `IS_DEVELOPMENT` as deliberately not modeled but still validated by production gates. This documentation has been removed.

2. **Production validation gate** — The production environment validation that previously rejected three bypass variables (`ALLOW_CORS_WILDCARD`, `ALLOW_RATELIMIT_FAIL_OPEN`, `IS_DEVELOPMENT`) now only validates two:

**Before (v0.5.8):**

```yaml
# From templates/_helpers.tpl
{{- $bypasses := dict
      "ALLOW_CORS_WILDCARD" (index $cfg "ALLOW_CORS_WILDCARD" | default "")
      "ALLOW_RATELIMIT_FAIL_OPEN" ($rl.allowFailOpen | default (index $cfg "ALLOW_RATELIMIT_FAIL_OPEN" | default ""))
      "IS_DEVELOPMENT" (index $cfg "IS_DEVELOPMENT" | default "") -}}
```

**After (v0.5.9):**

```yaml
# From templates/_helpers.tpl
{{- $bypasses := dict
      "ALLOW_CORS_WILDCARD" (index $cfg "ALLOW_CORS_WILDCARD" | default "")
      "ALLOW_RATELIMIT_FAIL_OPEN" ($rl.allowFailOpen | default (index $cfg "ALLOW_RATELIMIT_FAIL_OPEN" | default "")) -}}
```

3. **Secret template documentation** — The `LICENSE_KEY` required-field error message in `api/secrets.yaml`, and a comment in `worker/secrets.yaml`, previously mentioned that `IS_DEVELOPMENT` only selects the development license gateway. This reference has been removed:

**Before (v0.5.8):**

```yaml
LICENSE_KEY: {{ required "\n\nERROR: api.secrets.LICENSE_KEY is required.\nThe api and the worker validate the license at boot in every mode and do not start\nwithout it; IS_DEVELOPMENT only selects the development license gateway.\n" ...
```

**After (v0.5.9):**

```yaml
LICENSE_KEY: {{ required "\n\nERROR: api.secrets.LICENSE_KEY is required.\nThe api and the worker validate the license at boot in every mode and do not start\nwithout it.\n" ...
```

4. **ConfigMap template documentation** — The `ENVIRONMENT_NAME` variable comment in `_helpers.tpl` previously mentioned `IS_DEVELOPMENT=true` as one of the rejected bypasses. This reference has been simplified:

**Before (v0.5.8):**

```yaml
{{- /* Runtime + server. ENVIRONMENT_NAME=production arms the app's security gates
   (auth forced on, Postgres password + SSL required, every ALLOW_* bypass and
   IS_DEVELOPMENT=true rejected at boot). */ -}}
```

**After (v0.5.9):**

```yaml
{{- /* Runtime + server. ENVIRONMENT_NAME=production arms the app's security gates
   (auth forced on, Postgres password + SSL required, every ALLOW_* bypass
   rejected at boot). */ -}}
```

> **Note:** This release does not change the application image (1.5.0), and the application still reads `IS_DEVELOPMENT`. No values change is needed.

## Migration Impact

**No action required** for standard deployments. This change only affects:

1. **Documentation and comments** — Internal helper documentation has been updated to remove references to `IS_DEVELOPMENT`
2. **Production validation** — The chart's render gate now checks two bypass variables instead of three. Application 1.5.0, the default image, still refuses to boot with `IS_DEVELOPMENT` set to `true` under `ENVIRONMENT_NAME=production`, so that setting now renders and the pods fail to start.
3. **Error messages** — License key requirement messages no longer mention `IS_DEVELOPMENT`

## Preview changes before upgrading

```bash
helm diff upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.9 -n midaz-plugins -f my-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.9 -n midaz-plugins -f my-values.yaml
```
<!-- {% endraw %} -->
