<!-- {% raw %} -->
# Helm Upgrade from v9.8.0 to v9.8.1

# Topics

- **[Fixes](#fixes)**
  - [1. OpenTelemetry Environment Alignment](#1-opentelemetry-environment-alignment)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. OpenTelemetry Environment Alignment

The `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` variable now correctly derives from the same resolved environment name (`ENV_NAME`) used by the rest of the application, instead of being hardcoded to `"dev"`.

**What changed:**

Previously, the OpenTelemetry deployment environment was hardcoded in the ConfigMap templates, creating a mismatch between the application's environment name and the telemetry metadata. This patch aligns both values to use the same resolution logic.

| Service | Variable | v9.8.0 | v9.8.1 |
|---------|----------|--------|--------|
| Identity | `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `"dev"` (hardcoded) | Resolved from `ENV_NAME` |
| Auth | `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `"dev"` (hardcoded) | Resolved from `ENV_NAME` |

**Why this matters:**

- **Telemetry accuracy:** Your distributed traces and metrics will now correctly reflect the actual deployment environment (production, staging, development, etc.) instead of always showing "dev"
- **Consistency:** The OpenTelemetry resource attributes now match the `ENV_NAME` value used throughout the application
- **Global environment control:** When you set `global.env.name` in your values, it now propagates to both the application environment and telemetry metadata

**How environment resolution works:**

The chart uses a global mask pattern where `global.env.name` controls the environment name for all components. The resolution order is:

1. Explicit override in the service's configmap (e.g., `identity.configmap.ENV_NAME`)
2. Global value (`global.env.name`)
3. Default value (`"development"`)

**Before (v9.8.0):**

```yaml
# templates/identity/configmap.yaml
data:
  ENV_NAME: {{ include "lerian-common.globalValue" (...) | quote }}
  # ... other config ...
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "dev"  # hardcoded
```

```yaml
# templates/auth/configmap.yaml
data:
  ENV_NAME: {{ include "lerian-common.globalValue" (...) | quote }}
  # ... other config ...
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "dev"  # hardcoded
```

**After (v9.8.1):**

```yaml
# templates/identity/configmap.yaml
{{- $envName := include "lerian-common.globalValue" (...) -}}
data:
  ENV_NAME: {{ $envName | quote }}
  # ... other config ...
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: {{ $envName }}  # derived from same source
```

```yaml
# templates/auth/configmap.yaml
{{- $envName := include "lerian-common.globalValue" (...) -}}
data:
  ENV_NAME: {{ $envName | quote }}
  # ... other config ...
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: {{ $envName }}  # derived from same source
```

**Operational impact:**

- **No action required:** If you're already setting `global.env.name` in your values, the telemetry environment will automatically align after upgrade
- **Telemetry data change:** After upgrading, new traces and metrics will show the correct environment name instead of "dev". This may affect dashboards or queries that filter by `deployment.environment`
- **Override capability:** You can still explicitly override `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` if needed by setting it directly in the service configmap

**Example: Setting environment globally**

```yaml
global:
  env:
    name: production
```

After upgrade, both services will have:

```yaml
ENV_NAME: "production"
OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "production"
```

**Example: Explicit override (if needed)**

If you need the telemetry environment to differ from the application environment:

```yaml
identity:
  configmap:
    OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "prod-us-east"

auth:
  configmap:
    OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "prod-us-east"
```

> **Note:** The values.yaml comments have been updated to document this behavior. See the inline comments in `identity.configmap` and `auth.configmap` sections for details.

> **Important:** If you have monitoring dashboards or alerting rules that filter telemetry data by `deployment.environment="dev"`, you may need to update them to use your actual environment name after this upgrade.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.8.1 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.8.1 -n plugin-access-manager
```
<!-- {% endraw %} -->
