<!-- {% raw %} -->
# Helm Upgrade from v11.2.3 to v11.2.4

# Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Dependency Update: lerian-common-helm](#1-dependency-update-lerian-common-helm)
  - [2. OpenTelemetry Plaintext Connection Control](#2-opentelemetry-plaintext-connection-control)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a patch release that increments the chart version from 11.2.3 to 11.2.4. The application version remains `3.19.0` and no container images change.

**What changed:**

- The `lerian-common-helm` dependency was upgraded from `2.6.0` to `2.7.0`
- New configuration support for `ALLOW_INSECURE_OTEL` environment variable across auth, identity, and caradhras components
- Documentation and default values added for the `global.observability.allowInsecureOtel` field

**Action required:**

None for most deployments. If you have enabled the node-local OpenTelemetry collector (`otel-collector-lerian.enabled: true`) and run in production mode, the chart now automatically sets `ALLOW_INSECURE_OTEL` to allow the plaintext connection from each pod to its node-local collector. If you have disabled the node-local collector and point directly at a plaintext OTEL endpoint, you may need to set `ALLOW_INSECURE_OTEL` explicitly (see [section 2](#2-opentelemetry-plaintext-connection-control)).

| Component | v11.2.3 | v11.2.4 |
|-----------|---------|---------|
| Chart version | 11.2.3 | 11.2.4 |
| App version | 3.19.0 | 3.19.0 |
| lerian-common-helm | 2.6.0 | 2.7.0 |

# Changes

## 1. Dependency Update: lerian-common-helm

**What changed:**

The `lerian-common-helm` subchart dependency was updated from version `2.6.0` to `2.7.0`.

| Dependency | v11.2.3 | v11.2.4 |
|------------|---------|---------|
| lerian-common-helm | 2.6.0 | 2.7.0 |

**Why this matters:**

The `lerian-common-helm` chart provides shared templates and utilities used throughout the plugin-access-manager chart. Version `2.7.0` introduces the `lerian-common.otel.allowInsecure` template helper that resolves the `ALLOW_INSECURE_OTEL` setting for OpenTelemetry connections.

**Operational impact:**

This dependency update is transparent. The upgrade pulls the new subchart version automatically. No configuration changes are required.

## 2. OpenTelemetry Plaintext Connection Control

**What changed:**

The chart now supports and documents the `ALLOW_INSECURE_OTEL` environment variable for the auth, identity, and caradhras components. This variable controls whether the application accepts plaintext (non-TLS) OpenTelemetry connections in production mode.

When the node-local OpenTelemetry collector is enabled (`otel-collector-lerian.enabled: true`), each pod ships telemetry to `$(HOST_IP):4317` in plaintext. The `lib-observability` library used by these applications refuses plaintext connections in production unless `ALLOW_INSECURE_OTEL` carries a reason string explaining why the connection is safe.

**New configuration hierarchy:**

The chart resolves `ALLOW_INSECURE_OTEL` in the following order:

1. Component-specific setting: `<component>.configmap.ALLOW_INSECURE_OTEL`
2. Global setting: `global.observability.allowInsecureOtel`
3. Default for node-local collector: `"node-local collector on the pod's own node"`

The default is applied automatically when `otel-collector-lerian.enabled: true`. If you have disabled the node-local collector and point at an explicit plaintext endpoint, you must set one of the above fields yourself.

**New values.yaml fields:**

```yaml
global:
  observability:
    enabled: true
    # New field in v11.2.4:
    allowInsecureOtel: "node-local collector on the pod's own node"
```

```yaml
auth:
  configmap:
    # New field in v11.2.4:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

```yaml
identity:
  configmap:
    # New field in v11.2.4:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

```yaml
caradhras:
  configmap:
    # New field in v11.2.4:
    ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

**Template changes:**

The chart adds two new template helpers in `_helpers.tpl`:

- `plugin-access-manager.allowInsecureOtelEnv`: Renders the environment variable for the Deployment when the node-local collector is enabled
- `plugin-access-manager.allowInsecureOtelConfigmap`: Renders the ConfigMap entry when an explicit plaintext endpoint is configured

**Before (v11.2.3):**

The auth Deployment template set only `OTEL_EXPORTER_OTLP_ENDPOINT` when the node-local collector was enabled:

```yaml
# templates/auth/deployment.yaml
{{- if .Values.global.otelCollectorLerian.enabled }}
- name: "HOST_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
{{- end }}
```

**After (v11.2.4):**

The template now also sets `ALLOW_INSECURE_OTEL`:

```yaml
# templates/auth/deployment.yaml
{{- if .Values.global.otelCollectorLerian.enabled }}
- name: "HOST_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
{{- with (include "plugin-access-manager.allowInsecureOtelEnv" (dict "context" $ "component" "auth") | trim) }}{{ . | nindent 12 }}{{ end }}
{{- end }}
```

The same pattern applies to the identity and caradhras Deployments.

**Before (v11.2.3):**

The auth ConfigMap did not include `ALLOW_INSECURE_OTEL`:

```yaml
# templates/auth/configmap.yaml
data:
  ENABLE_TELEMETRY: {{ include "lerian-common.globalValue" ... | quote }}
```

**After (v11.2.4):**

The ConfigMap now conditionally includes `ALLOW_INSECURE_OTEL`:

```yaml
# templates/auth/configmap.yaml
data:
  ENABLE_TELEMETRY: {{ include "lerian-common.globalValue" ... | quote }}
  {{- with (include "plugin-access-manager.allowInsecureOtelConfigmap" (dict "context" $ "component" "auth") | trim) }}{{ . | nindent 2 }}{{ end }}
```

The same pattern applies to the identity and caradhras ConfigMaps.

**Why this matters:**

The `lib-observability` library enforces TLS for OpenTelemetry connections in production mode unless `ALLOW_INSECURE_OTEL` is set. Without this variable, applications refuse to start when configured with a plaintext endpoint in production.

The node-local collector runs as a DaemonSet on each node and receives telemetry from pods on the same node over the loopback or pod network. This connection does not traverse untrusted networks, so plaintext is acceptable. The chart now documents this and sets the variable automatically.

**Operational impact:**

| Scenario | v11.2.3 | v11.2.4 | Action Required |
|----------|---------|---------|-----------------|
| Node-local collector enabled (`otel-collector-lerian.enabled: true`) | Plaintext connection worked in dev mode; may have failed in production | Plaintext connection works; `ALLOW_INSECURE_OTEL` set automatically | None |
| Node-local collector disabled, explicit plaintext endpoint | Plaintext connection may have failed in production | Plaintext connection requires explicit `ALLOW_INSECURE_OTEL` | Set `global.observability.allowInsecureOtel` or component-specific `configmap.ALLOW_INSECURE_OTEL` |
| Node-local collector disabled, TLS endpoint | No change | No change | None |

**When you need to set ALLOW_INSECURE_OTEL manually:**

If you have disabled the node-local collector and configured an explicit plaintext OTEL endpoint (e.g., `identity.configmap.OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector.monitoring:4317"`), you must now set `ALLOW_INSECURE_OTEL` to allow the connection in production:

```yaml
global:
  observability:
    enabled: true
    allowInsecureOtel: "internal collector on trusted network"
```

Or per-component:

```yaml
identity:
  configmap:
    OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector.monitoring:4317"
    ALLOW_INSECURE_OTEL: "internal collector on trusted network"
```

The value must be a non-empty string that explains why the plaintext connection is safe. Setting it to `""` or `"false"` explicitly refuses the connection.

> **Important:** If your applications fail to start after the upgrade with an error about refusing insecure OTEL connections, check whether you have configured a plaintext endpoint without setting `ALLOW_INSECURE_OTEL`. Add the variable with a reason string to resolve the issue.

**Legacy override via extraEnvVars:**

If you have already set `ALLOW_INSECURE_OTEL` via `<component>.extraEnvVars`, the chart respects that and does not add its own entry. The environment variable from `extraEnvVars` takes precedence.

**What operators need to do:**

For most deployments, no action is required. The chart sets the variable automatically when the node-local collector is enabled.

If you use an explicit plaintext OTEL endpoint and run in production mode, add `global.observability.allowInsecureOtel` or the component-specific `configmap.ALLOW_INSECURE_OTEL` field to your values:

```yaml
global:
  observability:
    enabled: true
    allowInsecureOtel: "internal collector on trusted network"
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.4
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.4
```
<!-- {% endraw %} -->
