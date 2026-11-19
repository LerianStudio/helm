<!-- {% raw %} -->
# Helm Upgrade from v11.1.2 to v11.2.0

## Topics

- **[Features](#features)**
  - [1. Application version upgraded to 4.5.0](#1-application-version-upgraded-to-450)
  - [2. New streaming and transaction configuration flags](#2-new-streaming-and-transaction-configuration-flags)
- **[Configuration Reference](#configuration-reference)**
- **[Operational impact](#operational-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version upgraded to 4.5.0

The chart now deploys Midaz application version `4.5.0` (previously `4.4.3`). This is a stable release that includes the health preset features introduced in the 4.5.0-beta series.

#### What changed

| Component | Setting | v11.1.2 | v11.2.0 |
|-----------|---------|---------|---------|
| Ledger service | `ledger.image.tag` | `4.4.3` | `4.5.0` |
| Tracer service | `tracer.image.tag` | `4.4.3` | `4.5.0` |
| Ledger migrations | `midaz-ledger-migrations.image.tag` | `4.4.3` | `4.5.0` |
| Tracer migrations | `midaz-tracer-migrations.image.tag` | `4.4.3` | `4.5.0` |
| App version | `appVersion` | `4.4.3` | `4.5.0` |

#### Operational impact

- The ledger and tracer pods roll once to pick up the new image tags.
- The ledger migrations Job runs as a `pre-upgrade` hook on every upgrade, including this one.
- The tracer migrations Job runs as a `pre-upgrade` hook on every upgrade, including this one.
- The 4.5.0 release includes the health preset (HEALTH_PORT 8099, preset probes, PDB and rollout strategy) that was previously available only in beta tags.
- No configuration changes are required to use the new version. The health preset is enabled automatically by the chart templates when the image tag is 4.5.0 or higher.

### 2. New streaming and transaction configuration flags

Three new environment variables are now configurable via the chart to control streaming behavior and transaction metadata.

#### What changed

**Ledger ConfigMap additions:**

| Flag | Default | Description |
|------|---------|-------------|
| `STREAMING_TENANT_KAFKA` | `"false"` | Enables tenant-specific Kafka topic routing for streaming events |
| `TRANSACTION_CREATED_BY_ENABLED` | `"false"` | Enables tracking of the user or system that created each transaction |

**Tracer ConfigMap additions:**

| Flag | Default | Description |
|------|---------|-------------|
| `STREAMING_TENANT_KAFKA` | `"false"` | Enables tenant-specific Kafka topic routing for streaming events |

#### Template changes

**Before (v11.1.2):**

```yaml
# ledger/configmap.yaml
data:
  CASDOOR_JWK_ADDRESS: {{ $cm.CASDOOR_JWK_ADDRESS | default "" | quote }}
  TRANSACTION_BATCH_MAX_SIZE: {{ .Values.ledger.configmap.TRANSACTION_BATCH_MAX_SIZE | default "10" | quote }}
  # Extra Env Vars
  {{- with .Values.ledger.extraEnvVars }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
```

```yaml
# tracer/configmap.yaml
data:
  # ... kafka config ...
  # Extra Env Vars
  {{- with .Values.tracer.extraEnvVars }}
  {{- range $key, $value := . }}
```

**After (v11.2.0):**

```yaml
# ledger/configmap.yaml
data:
  CASDOOR_JWK_ADDRESS: {{ $cm.CASDOOR_JWK_ADDRESS | default "" | quote }}
  TRANSACTION_BATCH_MAX_SIZE: {{ .Values.ledger.configmap.TRANSACTION_BATCH_MAX_SIZE | default "10" | quote }}
  STREAMING_TENANT_KAFKA: {{ .Values.ledger.configmap.STREAMING_TENANT_KAFKA | default "false" | quote }}
  TRANSACTION_CREATED_BY_ENABLED: {{ .Values.ledger.configmap.TRANSACTION_CREATED_BY_ENABLED | default "false" | quote }}
  # Extra Env Vars
  {{- with .Values.ledger.extraEnvVars }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
```

```yaml
# tracer/configmap.yaml
data:
  # ... kafka config ...
  STREAMING_TENANT_KAFKA: {{ .Values.tracer.configmap.STREAMING_TENANT_KAFKA | default "false" | quote }}
  # Extra Env Vars
  {{- with .Values.tracer.extraEnvVars }}
  {{- range $key, $value := . }}
```

#### Operational impact

- The ledger and tracer ConfigMaps are updated with the new environment variables set to their default values (`"false"`).
- The ledger and tracer pods roll once to pick up the updated ConfigMaps (in addition to the roll triggered by the image tag change).
- The default behavior does not change. Both features remain disabled unless you explicitly enable them.
- These flags are backward-compatible. Existing deployments continue to work without modification.

## Configuration Reference

The new configuration flags are exposed under the `configmap` key for each service. All three flags default to `"false"` and are optional.

### Ledger configuration

To enable tenant-specific Kafka streaming for the ledger:

```yaml
ledger:
  configmap:
    STREAMING_TENANT_KAFKA: "true"
```

To enable transaction creator tracking:

```yaml
ledger:
  configmap:
    TRANSACTION_CREATED_BY_ENABLED: "true"
```

To enable both:

```yaml
ledger:
  configmap:
    STREAMING_TENANT_KAFKA: "true"
    TRANSACTION_CREATED_BY_ENABLED: "true"
```

### Tracer configuration

To enable tenant-specific Kafka streaming for the tracer:

```yaml
tracer:
  configmap:
    STREAMING_TENANT_KAFKA: "true"
```

### Combined example

A values file that enables all new features:

```yaml
ledger:
  configmap:
    STREAMING_TENANT_KAFKA: "true"
    TRANSACTION_CREATED_BY_ENABLED: "true"

tracer:
  configmap:
    STREAMING_TENANT_KAFKA: "true"
```

> **Note:** The `STREAMING_TENANT_KAFKA` flag must be enabled on both ledger and tracer if you want consistent tenant-based routing across the entire Midaz stack.

> **Important:** Enabling `STREAMING_TENANT_KAFKA` changes the Kafka topic naming convention. Ensure your Kafka consumers are configured to read from the new tenant-specific topics before enabling this flag in production.

## Operational impact

- **Image updates:** The ledger, tracer, and migration containers pull new images. Ensure your cluster has network access to the container registry and sufficient pull quota.
- **Pod restarts:** All ledger and tracer pods roll once. The chart version bump and the ConfigMap changes both trigger a rolling restart. Plan the upgrade during a maintenance window if your workload is sensitive to brief service interruptions.
- **Migration Jobs:** Both the ledger and tracer migration Jobs run as `pre-upgrade` hooks. The upgrade waits for these Jobs to complete successfully before rolling the service pods.
- **Backward compatibility:** The new environment variables default to `"false"`, preserving existing behavior. No action is required unless you want to enable the new features.
- **Kafka topic changes:** If you enable `STREAMING_TENANT_KAFKA`, verify that your Kafka infrastructure and consumers are ready for tenant-specific topic routing.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.0
```
<!-- {% endraw %} -->
