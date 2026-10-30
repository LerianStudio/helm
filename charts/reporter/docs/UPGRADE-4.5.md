<!-- {% raw %} -->
# Helm Upgrade from v4.4.3 to v4.5.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Access Manager permission declaration support for manager](#1-access-manager-permission-declaration-support-for-manager)
  - [2. IDP environment variables added to manager ConfigMap](#2-idp-environment-variables-added-to-manager-configmap)
  - [3. IDP client credentials added to manager Secret](#3-idp-client-credentials-added-to-manager-secret)
  - [4. Common library dependency bump to 2.4.0](#4-common-library-dependency-bump-to-240)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that adds support for Access Manager permission declaration (Resource Identifier pattern) in the manager component. The manager can now publish its permission manifest at boot when configured with IDP (Identity Provider) settings. The application version is bumped to `4.5.0`, and the `lerian-common-helm` dependency is upgraded from `2.3.0` to `2.4.0`.

| Field | v4.4.3 | v4.5.0 |
|-------|--------|--------|
| Chart version | `4.4.3` | `4.5.0` |
| App version | `4.4.3` | `4.5.0` |
| lerian-common-helm dependency | `2.3.0` | `2.4.0` |

## Features

### 1. Access Manager permission declaration support for manager

The manager component now supports Access Manager permission declaration via the Resource Identifier (RI) pattern. When `IDP_DECLARATION_ENABLED` is set to `"true"`, the manager will publish its permission manifest at boot and refuse to start without a valid IDP host and client credentials.

This feature is controlled by two new environment variables (`IDP_DECLARATION_ENABLED` and `IDP_HOST`) and two new secret keys (`IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET`). The worker component does not participate in permission declaration and does not receive these credentials.

| Component | v4.4.3 | v4.5.0 |
|-----------|--------|--------|
| Manager IDP declaration support | not present | enabled via `IDP_DECLARATION_ENABLED` |
| Worker IDP declaration support | not present | not present (manager-only feature) |

**Configuration cascade:**

The IDP environment variables (`IDP_DECLARATION_ENABLED` and `IDP_HOST`) are resolved in the following order of precedence:

1. `manager.configmap.IDP_DECLARATION_ENABLED` / `manager.configmap.IDP_HOST`
2. `manager.extraEnvVars.IDP_DECLARATION_ENABLED` / `manager.extraEnvVars.IDP_HOST`
3. `common.configmap.IDP_DECLARATION_ENABLED` / `common.configmap.IDP_HOST`
4. `global.idp.declarationEnabled` / `global.idp.host`

The IDP client credentials (`IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET`) are set via the top-level `secrets` block and are rendered only into the manager Secret.

**Default behavior (v4.5.0):**

```yaml
manager:
  configmap:
    IDP_DECLARATION_ENABLED: "false"  # Default: declaration disabled
    # IDP_HOST: ""  # Not set by default
```

### 2. IDP environment variables added to manager ConfigMap

Two new environment variables have been added to the manager ConfigMap to control Access Manager permission declaration:

| Variable | Default | Description |
|----------|---------|-------------|
| `IDP_DECLARATION_ENABLED` | `"false"` | Enable permission manifest publication at boot |
| `IDP_HOST` | `""` | IDP service endpoint (e.g., `http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001`) |

These variables are rendered by the `lerian-common.idp.env` template helper and follow the configuration cascade described in [Feature 1](#1-access-manager-permission-declaration-support-for-manager).

**Rendered ConfigMap (v4.5.0, default values):**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: reporter-manager
data:
  # ... existing keys ...
  IDP_DECLARATION_ENABLED: "false"
  # IDP_HOST not rendered when empty
```

**Rendered ConfigMap (v4.5.0, declaration enabled):**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: reporter-manager
data:
  # ... existing keys ...
  IDP_DECLARATION_ENABLED: "true"
  IDP_HOST: "http://plugin-access-manager-identity.reporter.svc.cluster.local:4001"
```

> **Note:** The `IDP_HOST` key is only rendered when the value is non-empty. If `IDP_DECLARATION_ENABLED` is `"true"` but `IDP_HOST` is empty, the manager will fail to start.

### 3. IDP client credentials added to manager Secret

Two new secret keys have been added to support machine-to-machine authentication with the IDP service:

| Key | Description |
|-----|-------------|
| `IDP_M2M_CLIENT_ID` | OAuth2 client ID for permission declaration |
| `IDP_M2M_CLIENT_SECRET` | OAuth2 client secret for permission declaration |

These credentials are set via the top-level `secrets` block and are rendered only into the manager Secret (`reporter-manager`). The worker Secret (`reporter-worker`) explicitly excludes these keys.

**Before (v4.4.3):**

```yaml
secrets:
  RABBITMQ_DEFAULT_USER: "plugin"
  RABBITMQ_DEFAULT_PASS: "your-password"
  # ... other secrets ...
```

**After (v4.5.0):**

```yaml
secrets:
  RABBITMQ_DEFAULT_USER: "plugin"
  RABBITMQ_DEFAULT_PASS: "your-password"
  # ... other secrets ...
  IDP_M2M_CLIENT_ID: "your-client-id"  # Optional: only required when IDP_DECLARATION_ENABLED="true"
  IDP_M2M_CLIENT_SECRET: "your-client-secret"  # Optional: only required when IDP_DECLARATION_ENABLED="true"
```

> **Important:** These credentials are only required when `IDP_DECLARATION_ENABLED` is set to `"true"`. If declaration is disabled (the default), these keys can be omitted. The manager will fail to start if declaration is enabled but the credentials are missing.

**Rendered manager Secret (v4.5.0, credentials provided):**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: reporter-manager
type: Opaque
data:
  # ... existing keys ...
  IDP_M2M_CLIENT_ID: eW91ci1jbGllbnQtaWQ=
  IDP_M2M_CLIENT_SECRET: eW91ci1jbGllbnQtc2VjcmV0
```

**Rendered worker Secret (v4.5.0):**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: reporter-worker
type: Opaque
data:
  # ... existing keys ...
  # IDP_M2M_CLIENT_ID and IDP_M2M_CLIENT_SECRET are NOT present
```

### 4. Common library dependency bump to 2.4.0

The `lerian-common-helm` dependency has been upgraded from `2.3.0` to `2.4.0`. This version introduces the `lerian-common.idp.env` and `lerian-common.idp.secret` template helpers used to render the IDP configuration.

| Dependency | v4.4.3 | v4.5.0 |
|------------|--------|--------|
| `lerian-common-helm` | `2.3.0` | `2.4.0` |

> **Note:** This dependency upgrade does not introduce breaking changes. The new template helpers are additive and only affect the manager component when IDP declaration is explicitly enabled.

## Configuration Reference

### Global IDP configuration

A new `global.idp` block has been added to support environment-wide IDP configuration. This block is consumed by the `lerian-common.idp.env` template helper.

| Field | Default | Description |
|-------|---------|-------------|
| `global.idp.declarationEnabled` | not set | Enable permission declaration across all components (boolean, converted to string) |
| `global.idp.host` | not set | IDP service endpoint (string) |

**Example configuration:**

```yaml
global:
  idp:
    declarationEnabled: true
    host: "http://plugin-access-manager-identity.reporter.svc.cluster.local:4001"
```

> **Note:** The `global.idp` block is optional. If not set, IDP configuration must be provided via component-specific settings (`manager.configmap`, `manager.extraEnvVars`, or `common.configmap`).

### Manager IDP configuration

The manager component now accepts IDP configuration via three mechanisms, in order of precedence:

| Field | Default | Description |
|-------|---------|-------------|
| `manager.configmap.IDP_DECLARATION_ENABLED` | not set | Enable permission declaration for manager (string: `"true"` or `"false"`) |
| `manager.configmap.IDP_HOST` | not set | IDP service endpoint for manager (string) |
| `manager.extraEnvVars.IDP_DECLARATION_ENABLED` | not set | Legacy override for declaration flag (string) |
| `manager.extraEnvVars.IDP_HOST` | not set | Legacy override for IDP host (string) |

**Example configuration (via manager.configmap):**

```yaml
manager:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://plugin-access-manager-identity.reporter.svc.cluster.local:4001"
```

**Example configuration (via manager.extraEnvVars, legacy):**

```yaml
manager:
  extraEnvVars:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://plugin-access-manager-identity.reporter.svc.cluster.local:4001"
```

> **Important:** If IDP variables are set in `manager.extraEnvVars`, they will be omitted from the final `extraEnvVars` block in the rendered ConfigMap to avoid duplication. The `lerian-common.idp.env` helper consumes these values and renders them separately.

### IDP client credentials

The IDP client credentials are set via the top-level `secrets` block and are rendered only into the manager Secret.

| Field | Default | Description |
|-------|---------|-------------|
| `secrets.IDP_M2M_CLIENT_ID` | not set | OAuth2 client ID for permission declaration (string) |
| `secrets.IDP_M2M_CLIENT_SECRET` | not set | OAuth2 client secret for permission declaration (string) |

**Example configuration:**

```yaml
secrets:
  IDP_M2M_CLIENT_ID: "reporter-manager-client"
  IDP_M2M_CLIENT_SECRET: "your-secure-client-secret"
```

> **Warning:** These credentials are only required when `IDP_DECLARATION_ENABLED` is `"true"`. The manager will fail to start if declaration is enabled but the credentials are missing or empty.

### Manager ConfigMap template changes

The manager ConfigMap template now includes the `lerian-common.idp.env` helper to render IDP environment variables. The helper resolves values from the configuration cascade and ensures `IDP_DECLARATION_ENABLED` is always present (defaulting to `"false"`).

**Before (v4.4.3):**

```yaml
data:
  {{- include "reporter.commonConfigmapData" . | nindent 2 }}
  {{- range $key, $value := .Values.manager.configmap }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  VERSION: {{ .Values.manager.image.tag | quote }}
  OTEL_RESOURCE_SERVICE_VERSION: {{ .Values.manager.image.tag | quote }}
  {{- with .Values.manager.extraEnvVars }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
```

**After (v4.5.0):**

```yaml
data:
  {{- include "reporter.commonConfigmapData" . | nindent 2 }}
  {{- $idpEnvKeys := include "lerian-common.idp.keys" (dict "kind" "env") | fromJsonArray }}
  {{- range $key, $value := .Values.manager.configmap }}
  {{- if not (has $key $idpEnvKeys) }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
  {{- $idpSrc := deepCopy (.Values.manager.configmap | default dict) }}
  {{- range $k := $idpEnvKeys }}
  {{- range $src := list ($.Values.manager.extraEnvVars | default dict) ($.Values.common.configmap | default dict) }}
  {{- if and (hasKey $src $k) (not (hasKey $idpSrc $k)) }}{{- $_ := set $idpSrc $k (index $src $k) }}{{- end }}
  {{- end }}
  {{- end }}
  {{- include "lerian-common.idp.env" (dict "context" $ "configmap" $idpSrc) | nindent 2 }}
  VERSION: {{ .Values.manager.image.tag | quote }}
  OTEL_RESOURCE_SERVICE_VERSION: {{ .Values.manager.image.tag | quote }}
  {{- with (omit (.Values.manager.extraEnvVars | default dict) "IDP_DECLARATION_ENABLED" "IDP_HOST") }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
```

**Operational impact:**

- IDP environment variables are now rendered separately via the `lerian-common.idp.env` helper
- If `IDP_DECLARATION_ENABLED` or `IDP_HOST` are set in `manager.extraEnvVars`, they are consumed by the helper and omitted from the final `extraEnvVars` block to avoid duplication
- The `IDP_DECLARATION_ENABLED` key is always rendered (defaulting to `"false"` if not set)
- The `IDP_HOST` key is only rendered when the value is non-empty

### Manager Secret template changes

The manager Secret template now includes the `lerian-common.idp.secret` helper to render IDP client credentials.

**Before (v4.4.3):**

```yaml
data:
  {{- include "reporter.mongoExternalSecretData" . | nindent 2 }}
  {{- range $key, $value := .Values.secrets }}
  {{- if ne $key "MONGO_PASSWORD" }}
  {{ $key }}: {{ $value | toString | b64enc | quote }}
  {{- end }}
  {{- end }}
```

**After (v4.5.0):**

```yaml
data:
  {{- include "reporter.mongoExternalSecretData" . | nindent 2 }}
  {{- $idpSecretKeys := include "lerian-common.idp.keys" (dict "kind" "secret") | fromJsonArray }}
  {{- range $key, $value := .Values.secrets }}
  {{- if not (or (eq $key "MONGO_PASSWORD") (has $key $idpSecretKeys)) }}
  {{ $key }}: {{ $value | toString | b64enc | quote }}
  {{- end }}
  {{- end }}
  {{- with (include "lerian-common.idp.secret" (dict "secrets" .Values.secrets "mode" "data")) }}
  {{- . | nindent 2 }}
  {{- end }}
```

**Operational impact:**

- IDP client credentials (`IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET`) are now rendered separately via the `lerian-common.idp.secret` helper
- Each credential key is only rendered when the value is non-empty
- The worker Secret explicitly excludes these keys (see [Worker Secret template changes](#worker-secret-template-changes))

### Worker Secret template changes

The worker Secret template now explicitly excludes IDP client credentials, as the worker does not participate in permission declaration.

**Before (v4.4.3):**

```yaml
data:
  {{- include "reporter.mongoExternalSecretData" . | nindent 2 }}
  {{- range $key, $value := .Values.secrets }}
  {{- if ne $key "MONGO_PASSWORD" }}
  {{ $key }}: {{ $value | toString | b64enc | quote }}
  {{- end }}
  {{- end }}
```

**After (v4.5.0):**

```yaml
data:
  {{- include "reporter.mongoExternalSecretData" . | nindent 2 }}
  {{- $idpSecretKeys := include "lerian-common.idp.keys" (dict "kind" "secret") | fromJsonArray }}
  {{- range $key, $value := .Values.secrets }}
  {{- if not (or (eq $key "MONGO_PASSWORD") (has $key $idpSecretKeys)) }}
  {{ $key }}: {{ $value | toString | b64enc | quote }}
  {{- end }}
  {{- end }}
```

**Operational impact:**

- IDP client credentials (`IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET`) are excluded from the worker Secret
- The worker continues to receive all other secrets from the top-level `secrets` block

### Helper template changes

The `reporter.managerEnvVarKeys` helper template now includes the two new IDP environment variable keys in its list of recognized manager ConfigMap keys.

**Before (v4.4.3):**

```go
"PLUGIN_AUTH_ENABLED" "PLUGIN_AUTH_ADDRESS"
"SD_ENABLED" "SD_ADDRESS" "SD_ADVERTISE_ADDRESS" "SD_ADVERTISE_PORT" "SD_WORKLOAD"
```

**After (v4.5.0):**

```go
"PLUGIN_AUTH_ENABLED" "PLUGIN_AUTH_ADDRESS"
"IDP_DECLARATION_ENABLED" "IDP_HOST"
"SD_ENABLED" "SD_ADDRESS" "SD_ADVERTISE_ADDRESS" "SD_ADVERTISE_PORT" "SD_WORKLOAD"
```

**Operational impact:**

- This change ensures that `IDP_DECLARATION_ENABLED` and `IDP_HOST` are recognized as valid manager ConfigMap keys
- The helper is used internally by the chart templates and does not affect operator configuration

## Migration Steps

This upgrade requires no mandatory configuration changes. The IDP declaration feature is disabled by default (`IDP_DECLARATION_ENABLED="false"`), and the upgrade will roll the manager and worker deployments without changing runtime behavior.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. If you do not plan to enable IDP declaration, proceed directly to step 5.
3. If you plan to enable IDP declaration, prepare the required configuration:

   ```yaml
   manager:
     configmap:
       IDP_DECLARATION_ENABLED: "true"
       IDP_HOST: "http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001"
   
   secrets:
     IDP_M2M_CLIENT_ID: "reporter-manager-client"
     IDP_M2M_CLIENT_SECRET: "your-secure-client-secret"
   ```

4. Verify that the IDP service is deployed and accessible at the configured `IDP_HOST` endpoint.
5. Run the upgrade command during a maintenance window.
6. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n <namespace>
   ```

7. Check manager logs to confirm IDP declaration behavior:

   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
   ```

   If `IDP_DECLARATION_ENABLED="true"`, you should see log entries indicating permission manifest publication. If `IDP_DECLARATION_ENABLED="false"` (the default), no IDP-related log entries will appear.

8. Verify worker logs to confirm normal operation:

   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
   ```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. If IDP declaration is enabled and the manager cannot reach the IDP service or authenticate with the provided credentials, the manager pods will fail to start and the rollout will pause.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.5.0 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.5.0 -n reporter
```
<!-- {% endraw %} -->
