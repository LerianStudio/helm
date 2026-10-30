<!-- {% raw %} -->
# Helm Upgrade from v2.0.0 to v2.0.1

## Topics

- **[Fixes](#fixes)**
  - [1. ENV_NAME Default Changed to Production](#1-env_name-default-changed-to-production)
  - [2. SWAGGER_ENABLED Removed from pixauto ConfigMap](#2-swagger_enabled-removed-from-pixauto-configmap)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. ENV_NAME Default Changed to Production

**What changed:**

The `ENV_NAME` environment variable default has been changed from `"development"` to `"production"` across all 14 component ConfigMaps. This variable controls the application's runtime environment mode, which affects logging verbosity, error handling behavior, and feature flags.

| Setting | v2.0.0 | v2.0.1 |
|---------|--------|--------|
| `ENV_NAME` default | `"development"` | `"production"` |

**Affected components:**

- `adapter-lerian`
- `adapter-lerian-systemplane`
- `adapter-provider-mock`
- `cob-hub`
- `cob-proxy`
- `cob-systemplane`
- `dict-hub`
- `dict-hub-vsync`
- `dict-proxy`
- `dict-systemplane`
- `pixauto`
- `pixauto-systemplane`
- `spi`
- `spi-systemplane`

**Why it matters:**

The `ENV_NAME` variable controls application behavior that should differ between development and production environments:

- **Logging:** Development mode typically enables debug-level logging and verbose stack traces, while production mode uses structured logging with appropriate log levels
- **Error responses:** Development mode may expose detailed error messages and internal state, while production mode returns sanitized errors
- **Performance:** Development mode may disable certain optimizations for easier debugging

An existing installation that relied on the v2.0.0 default (`"development"`) **will switch to production mode on upgrade**, which may:

- Reduce log verbosity (debug logs may disappear)
- Change error message format in API responses
- Enable production-specific optimizations

**How to handle it:**

#### Option 1: Accept the new default (recommended for production)

If you are running a production deployment, no action is required. The new default aligns with production best practices and ensures that components run in the appropriate mode.

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.1 -n plugin-br-pix-lerian
```

#### Option 2: Keep development mode

If you are running a development, staging, or test environment where development mode is required, explicitly set `ENV_NAME` to `"development"` for each component before upgrading:

```yaml
spi:
  configmap:
    ENV_NAME: "development"

spiSystemplane:
  configmap:
    ENV_NAME: "development"

dictHub:
  configmap:
    ENV_NAME: "development"

dictHubVsync:
  configmap:
    ENV_NAME: "development"

dictProxy:
  configmap:
    ENV_NAME: "development"

dictSystemplane:
  configmap:
    ENV_NAME: "development"

cobHub:
  configmap:
    ENV_NAME: "development"

cobProxy:
  configmap:
    ENV_NAME: "development"

cobSystemplane:
  configmap:
    ENV_NAME: "development"

adapterLerian:
  configmap:
    ENV_NAME: "development"

adapterLerianSystemplane:
  configmap:
    ENV_NAME: "development"

adapterProviderMock:
  configmap:
    ENV_NAME: "development"

pixauto:
  configmap:
    ENV_NAME: "development"

pixautoSystemplane:
  configmap:
    ENV_NAME: "development"
```

> **Note:** You can also set `ENV_NAME` globally if all components should use the same environment mode, but the chart does not provide a global default for this variable. You must set it per component.

**Before (v2.0.0) configmap.yaml:**

```yaml
ENV_NAME: {{ $cm.ENV_NAME | default "development" | quote }}
```

**After (v2.0.1) configmap.yaml:**

```yaml
ENV_NAME: {{ $cm.ENV_NAME | default "production" | quote }}
```

### 2. SWAGGER_ENABLED Removed from pixauto ConfigMap

**What changed:**

The `SWAGGER_ENABLED` environment variable has been removed from the `pixauto` component's ConfigMap enumeration list. This variable controlled whether the Swagger UI documentation endpoint was exposed by the pixauto API.

**Why it matters:**

In v2.0.0, `SWAGGER_ENABLED` was emitted to the pixauto ConfigMap with a default value of `"true"` (via the `flagDefaultTrue` helper), which exposed the Swagger UI in all environments. This was a security concern in production deployments, as the Swagger UI can reveal API structure and internal implementation details.

In v2.0.1, `SWAGGER_ENABLED` is **not emitted by default**, so the application's built-in default applies:

- **Application default:** Swagger UI is enabled only in `local` and `development` environments (controlled by `ENV_NAME`)
- **Production behavior:** With the new `ENV_NAME` default of `"production"`, Swagger UI will be disabled by default

**How to handle it:**

#### Option 1: Accept the new default (recommended for production)

If you are running a production deployment, no action is required. The Swagger UI will be disabled automatically because:

1. `SWAGGER_ENABLED` is not emitted to the ConfigMap
2. `ENV_NAME` defaults to `"production"`
3. The application disables Swagger UI in production mode

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.1 -n plugin-br-pix-lerian
```

#### Option 2: Explicitly enable Swagger UI

If you need the Swagger UI in a non-production environment (development, staging, test), explicitly set `SWAGGER_ENABLED` to `"true"` in the pixauto component's configmap:

```yaml
pixauto:
  configmap:
    SWAGGER_ENABLED: "true"
```

The variable will pass through the escape hatch (the catch-all loop at the end of the ConfigMap template) and be emitted to the ConfigMap.

> **Warning:** Never enable `SWAGGER_ENABLED` in production. The Swagger UI exposes API documentation and can reveal internal implementation details to unauthorized users.

**Before (v2.0.0) configmap.yaml:**

```yaml
SWAGGER_ENABLED: {{ include "plugin-br-pix-lerian.flagDefaultTrue" $cm.SWAGGER_ENABLED | quote }}
```

```yaml
{{- range $k := (list
    "APPLICATION_NAME" "DEPLOYMENT_MODE" "ENV_NAME" "LOG_LEVEL"
    "OTEL_EXPORTER_OTLP_ENDPOINT" "OTEL_LIBRARY_NAME" "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT"
    "OTEL_RESOURCE_SERVICE_NAME" "ORGANIZATION_IDS" "REQUEST_TIMEOUT_SEC"
    "SERVER_ADDRESS" "STREAMING_BROKERS" "STREAMING_ENABLED"
    "STREAMING_GROUP_ID" "STREAMING_IMPORTANT_EMIT_TIMEOUT_MS" "STREAMING_REQUIRED_ACKS"
    "STREAMING_SASL_ALLOW_PLAINTEXT" "STREAMING_SASL_MECHANISM" "STREAMING_SASL_PASSWORD"
    "STREAMING_SASL_USERNAME" "STREAMING_TLS_CA_CERT" "STREAMING_TLS_ENABLED"
    "SWAGGER_ENABLED" "SYSTEMPLANE_POSTGRES_DSN" "TELEMETRY_ENABLED" "VALKEY_URL"
  ) }}
```

**After (v2.0.1) configmap.yaml:**

```yaml
{{- /* SWAGGER_ENABLED is not emitted, so the app default applies (docs only in local/development); a set value passes through the escape hatch below. */}}
```

```yaml
{{- range $k := (list
    "APPLICATION_NAME" "DEPLOYMENT_MODE" "ENV_NAME" "LOG_LEVEL"
    "OTEL_EXPORTER_OTLP_ENDPOINT" "OTEL_LIBRARY_NAME" "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT"
    "OTEL_RESOURCE_SERVICE_NAME" "ORGANIZATION_IDS" "REQUEST_TIMEOUT_SEC"
    "SERVER_ADDRESS" "STREAMING_BROKERS" "STREAMING_ENABLED"
    "STREAMING_GROUP_ID" "STREAMING_IMPORTANT_EMIT_TIMEOUT_MS" "STREAMING_REQUIRED_ACKS"
    "STREAMING_SASL_ALLOW_PLAINTEXT" "STREAMING_SASL_MECHANISM" "STREAMING_SASL_PASSWORD"
    "STREAMING_SASL_USERNAME" "STREAMING_TLS_CA_CERT" "STREAMING_TLS_ENABLED"
    "SYSTEMPLANE_POSTGRES_DSN" "TELEMETRY_ENABLED" "VALKEY_URL"
  ) }}
```

> **Note:** `SWAGGER_ENABLED` is removed from the enumeration list but can still be set via `pixauto.configmap.SWAGGER_ENABLED`. The escape hatch at the end of the ConfigMap template will emit any explicitly set variable that is not in the enumeration list.

**Operational impact:**

- **Existing installations with default values:** Swagger UI will be disabled after upgrade (because `ENV_NAME` defaults to `"production"` and `SWAGGER_ENABLED` is not emitted)
- **Existing installations with `SWAGGER_ENABLED: "true"` in values.yaml:** Swagger UI will remain enabled (the explicit value passes through the escape hatch)
- **Existing installations with `ENV_NAME: "development"` in values.yaml:** Swagger UI will remain enabled (the application enables it in development mode)

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.1 -n plugin-br-pix-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-pix-lerian-helm --version 2.0.1 -n plugin-br-pix-lerian
```
<!-- {% endraw %} -->
