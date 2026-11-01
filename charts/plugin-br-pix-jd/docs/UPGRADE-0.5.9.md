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

This is a **patch release** that removes support for the `IS_DEVELOPMENT` environment variable from the chart's configuration model and validation gates. The variable was previously used as a local development bypass but is no longer supported as a first-class configuration option.

| Setting | v0.5.8 | v0.5.9 |
|---------|--------|--------|
| Chart Version | 0.5.8 | 0.5.9 |
| App Version | 1.5.0 | 1.5.0 |
| `IS_DEVELOPMENT` support | Documented in helpers | Removed from documentation and validation |

## Fixes

### 1. IS_DEVELOPMENT Environment Variable Removed

The `IS_DEVELOPMENT` environment variable has been removed from the chart's configuration model, validation gates, and documentation. This variable was previously used as a development-only bypass that swapped the production license gateway for a development one.

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

3. **Secret template documentation** — The `LICENSE_KEY` required field error message in both `api/secrets.yaml` and `worker/secrets.yaml` previously mentioned that `IS_DEVELOPMENT` only selects the development license gateway. This reference has been removed:

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

**Why this matters:**

The `IS_DEVELOPMENT` variable was a local development bypass that was never intended for production use. By removing it from the chart's validation and documentation, the chart now correctly reflects that:

1. License validation runs in **all modes** — there is no development bypass
2. The production validation gate only needs to check the two remaining security bypasses (`ALLOW_CORS_WILDCARD` and `ALLOW_RATELIMIT_FAIL_OPEN`)
3. Operators cannot accidentally set `IS_DEVELOPMENT` via `api.configmap` or `api.extraConfigmap` and expect it to be a supported configuration option

> **Important:** If you were previously setting `IS_DEVELOPMENT` via `api.extraConfigmap` or `worker.extraConfigmap`, this variable is no longer documented or validated by the chart. The application may still read it from the environment, but the chart treats it as an unsupported bypass. Remove it from your values:

```yaml
# Remove this from your values.yaml
api:
  extraConfigmap:
    IS_DEVELOPMENT: "true"  # No longer supported
```

## Migration Impact

**No action required** for standard deployments. This change only affects:

1. **Documentation and comments** — Internal helper documentation has been updated to remove references to `IS_DEVELOPMENT`
2. **Production validation** — The production environment gate now validates two bypass variables instead of three
3. **Error messages** — License key requirement messages no longer mention `IS_DEVELOPMENT`

> **Note:** If you were using `IS_DEVELOPMENT` as a local development bypass via `api.extraConfigmap` or `worker.extraConfigmap`, you should remove it from your values file. The chart no longer documents or validates this variable, and its presence may cause confusion in production environments.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.9 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.9 -n plugin-br-pix-jd
```
<!-- {% endraw %} -->
