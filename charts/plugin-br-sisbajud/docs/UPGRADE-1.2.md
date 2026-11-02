<!-- {% raw %} -->
# Helm Upgrade from v1.1.1 to v1.2.0

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.1.1** to **1.2.0**. This minor release introduces graceful shutdown improvements and removes the deprecated `IS_DEVELOPMENT` license configuration flag.

## Table of Contents

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Graceful Shutdown Configuration](#1-graceful-shutdown-configuration)
  - [2. Deprecated License Development Flag Removal](#2-deprecated-license-development-flag-removal)
- **[Configuration Reference](#configuration-reference)**
  - [Termination Grace Period](#termination-grace-period)
  - [Shutdown Drain Delay](#shutdown-drain-delay)
  - [Removed Configuration](#removed-configuration)
  - [Environment Variables](#environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.2.0 introduces graceful shutdown improvements to the `plugin-br-sisbajud` chart, ensuring the application has sufficient time to drain in-flight requests and complete shutdown stages before Kubernetes terminates the pod. This release also removes the deprecated `IS_DEVELOPMENT` license flag, which is no longer supported by the underlying license library.

**Key changes:**

- **Termination grace period increased** from 30 seconds to 105 seconds to accommodate shutdown stages
- **Shutdown drain delay** of 15 seconds added to allow load balancers to deregister the pod
- **`IS_DEVELOPMENT` license flag removed** from values schema and templates

> **Note:** This upgrade is backward-compatible and requires no configuration changes. The new termination grace period and shutdown drain delay are applied automatically.

## Features

### 1. Graceful Shutdown Configuration

The chart now configures a longer termination grace period and introduces a shutdown drain delay to ensure graceful pod termination.

**Shutdown stages:**

The application performs the following shutdown stages when receiving a SIGTERM signal:

1. **Drain delay** (15 seconds): Wait for load balancers to deregister the pod
2. **HTTP drain** (~30 seconds): Stop accepting new requests, drain existing connections
3. **Close resources** (~30 seconds): Close database connections, Redis clients, KMS sessions
4. **Telemetry flush** (~30 seconds): Flush OpenTelemetry spans and metrics

**Total shutdown time:** 15s (drain delay) + 90s (shutdown stages) = **105 seconds**

**Configuration changes:**

| Setting | v1.1.1 | v1.2.0 |
|---------|--------|--------|
| `sisbajud.terminationGracePeriodSeconds` | `30` | `105` |
| `SHUTDOWN_DRAIN_DELAY` environment variable | Not set | `15s` |

**Before (v1.1.1):**

```yaml
sisbajud:
  terminationGracePeriodSeconds: 30
```

**After (v1.2.0):**

```yaml
sisbajud:
  # SHUTDOWN_DRAIN_DELAY 15s + 90s of shutdown stages (HTTP drain, closeResources, telemetry flush).
  terminationGracePeriodSeconds: 105
```

**Template changes (Deployment):**

**Before (v1.1.1):**

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: {{ $s.terminationGracePeriodSeconds }}
      containers:
        - name: {{ include "plugin-br-sisbajud.name" . }}
          {{- if or $pgRef $vkRef (and $telemetry (not $explicitEndpoint)) $raOn $extra }}
          env:
            {{- if $pgRef }}
            {{- include "lerian-common.infraSecretRef" (dict "context" . "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") | nindent 12 }}
            {{- end }}
          {{- end }}
```

**After (v1.2.0):**

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: {{ $s.terminationGracePeriodSeconds }}
      containers:
        - name: {{ include "plugin-br-sisbajud.name" . }}
          env:
            - name: SHUTDOWN_DRAIN_DELAY
              value: "15s"
            {{- if $pgRef }}
            {{- include "lerian-common.infraSecretRef" (dict "context" . "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") | nindent 12 }}
            {{- end }}
```

**Operational impact:**

- The `terminationGracePeriodSeconds` is increased from 30 to 105 seconds, giving the application more time to complete shutdown stages
- The `SHUTDOWN_DRAIN_DELAY` environment variable is set to `15s`, instructing the application to wait 15 seconds before starting the HTTP drain stage
- The `env` block is now unconditionally rendered (previously conditional on `$pgRef`, `$vkRef`, `$telemetry`, `$raOn`, or `$extra`)
- Pods will take up to 105 seconds to terminate gracefully during rolling updates or scale-down operations
- Load balancers (Ingress controllers, AWS ALB, etc.) should deregister the pod within the 15-second drain delay window

> **Important:** If your deployment uses a custom `terminationGracePeriodSeconds` value, ensure it is at least 105 seconds to accommodate the new shutdown stages. Values below 105 seconds may cause the pod to be forcefully terminated before completing graceful shutdown.

### 2. Deprecated License Development Flag Removal

The `IS_DEVELOPMENT` license flag has been removed from the chart. This flag was used to route the license library to a development gateway for dev-issued license keys, but is no longer supported by the underlying `lib-license-go` library.

**Configuration changes:**

| Setting | v1.1.1 | v1.2.0 |
|---------|--------|--------|
| `sisbajud.license.isDevelopment` | `""` (optional) | Removed from schema |
| `IS_DEVELOPMENT` environment variable | Rendered if set | Never rendered |

**Before (v1.1.1):**

```yaml
sisbajud:
  license:
    organizationIds: "global"
    isDevelopment: ""  # Optional: "true" routes to dev gateway
```

**After (v1.2.0):**

```yaml
sisbajud:
  license:
    organizationIds: "global"
    # isDevelopment field removed
```

**Template changes (_env.tpl):**

**Before (v1.1.1):**

```yaml
# --- License (LICENSE_KEY lives in the Secret) ---------------------------------
{{- include $kv (dict "cm" $cm "p" $s.license "f" "organizationIds" "k" "ORGANIZATION_IDS" "d" "global") }}
{{- include $kv (dict "cm" $cm "p" $s.license "f" "isDevelopment" "k" "IS_DEVELOPMENT" "opt" true) }}
```

**After (v1.2.0):**

```yaml
# --- License (LICENSE_KEY lives in the Secret) ---------------------------------
{{- include $kv (dict "cm" $cm "p" $s.license "f" "organizationIds" "k" "ORGANIZATION_IDS" "d" "global") }}
```

**Template changes (configmap.yaml):**

**Before (v1.1.1):**

```yaml
{{- range $k, $v := (.Values.sisbajud.configmap | default dict) }}
{{- if not (hasKey $emitted $k) }}
{{- $extra = append $extra $k }}
{{- end }}
{{- end }}
```

**After (v1.2.0):**

```yaml
{{- range $k, $v := (.Values.sisbajud.configmap | default dict) }}
{{- /* IS_DEVELOPMENT is deprecated and ignored: accepted by the schema, never emitted. */ -}}
{{- if and (ne $k "IS_DEVELOPMENT") (not (hasKey $emitted $k)) }}
{{- $extra = append $extra $k }}
{{- end }}
{{- end }}
```

**Operational impact:**

- The `sisbajud.license.isDevelopment` field is removed from the values schema
- The `IS_DEVELOPMENT` environment variable is never rendered in the ConfigMap
- If `IS_DEVELOPMENT` is set via `sisbajud.configmap.IS_DEVELOPMENT`, it is silently ignored (accepted by the schema but never emitted)
- Development license keys are no longer supported; all deployments must use production license keys

> **Note:** If your deployment previously set `sisbajud.license.isDevelopment: "true"` or `sisbajud.configmap.IS_DEVELOPMENT: "true"`, you must obtain a production license key from Lerian Studio. The chart will render successfully but the application will reject development keys.

## Configuration Reference

### Termination Grace Period

| Flag | Default | Description |
|------|---------|-------------|
| `sisbajud.terminationGracePeriodSeconds` | `105` | Pod termination grace period in seconds (increased from 30 in v1.1.1) |

**Configuration example:**

```yaml
sisbajud:
  terminationGracePeriodSeconds: 105  # Default in v1.2.0
```

> **Warning:** Do not set this value below 105 seconds. The application requires 15 seconds for drain delay plus 90 seconds for shutdown stages (HTTP drain, resource cleanup, telemetry flush). Values below 105 may cause forceful termination and incomplete shutdown.

### Shutdown Drain Delay

The `SHUTDOWN_DRAIN_DELAY` environment variable is automatically set to `15s` in v1.2.0. This value is not configurable via the values schema.

**Environment variable:**

```yaml
env:
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
```

> **Note:** The drain delay allows load balancers to deregister the pod before the application stops accepting new requests. This prevents connection errors during rolling updates.

### Removed Configuration

The following configuration fields have been removed in v1.2.0:

| Field | Removed From | Replacement |
|-------|--------------|-------------|
| `sisbajud.license.isDevelopment` | `values.yaml` schema | None (use production license keys) |
| `IS_DEVELOPMENT` | ConfigMap environment variables | None (no longer supported by license library) |

**Migration:**

If your deployment previously used development license keys with `isDevelopment: "true"`, you must obtain a production license key from Lerian Studio and update your secrets:

```yaml
sisbajud:
  secrets:
    LICENSE_KEY: "production-license-key-here"
```

### Environment Variables

The following environment variable is added in v1.2.0:

| Variable | Source | Default | Description |
|----------|--------|---------|-------------|
| `SHUTDOWN_DRAIN_DELAY` | Hardcoded in Deployment template | `15s` | Duration to wait before starting HTTP drain stage during shutdown |

The following environment variable is removed in v1.2.0:

| Variable | Removed From | Reason |
|----------|--------------|--------|
| `IS_DEVELOPMENT` | ConfigMap | No longer supported by `lib-license-go` library |

## Migration Steps

### For all deployments

No action required. The new termination grace period and shutdown drain delay are applied automatically during the upgrade.

**Upgrade command:**

```bash
helm upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n plugin-br-sisbajud
```

**Post-upgrade verification:**

1. Verify the pod has the new termination grace period:

```bash
kubectl get pod -n plugin-br-sisbajud -l app.kubernetes.io/name=plugin-br-sisbajud -o jsonpath='{.items[0].spec.terminationGracePeriodSeconds}'
```

Expected output: `105`

2. Verify the `SHUTDOWN_DRAIN_DELAY` environment variable is set:

```bash
kubectl get pod -n plugin-br-sisbajud -l app.kubernetes.io/name=plugin-br-sisbajud -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="SHUTDOWN_DRAIN_DELAY")].value}'
```

Expected output: `15s`

### For deployments using development license keys

If your deployment previously set `sisbajud.license.isDevelopment: "true"` or `sisbajud.configmap.IS_DEVELOPMENT: "true"`, you must obtain a production license key from Lerian Studio.

**Migration steps:**

1. Obtain a production license key from Lerian Studio support.

2. Update your values file to remove the `isDevelopment` field and set the production license key:

**Before (v1.1.1):**

```yaml
sisbajud:
  license:
    organizationIds: "global"
    isDevelopment: "true"
  
  secrets:
    LICENSE_KEY: "dev-license-key"
```

**After (v1.2.0):**

```yaml
sisbajud:
  license:
    organizationIds: "global"
  
  secrets:
    LICENSE_KEY: "production-license-key-here"
```

3. Upgrade the chart with the updated values:

```bash
helm upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n plugin-br-sisbajud -f values.yaml
```

> **Important:** The application will fail to start if the license key is invalid or expired. Verify the license key with Lerian Studio support before upgrading.

### For deployments with custom termination grace period

If your deployment overrides `sisbajud.terminationGracePeriodSeconds` with a value below 105 seconds, you must increase it to at least 105 seconds.

**Migration steps:**

1. Update your values file to set the termination grace period to at least 105 seconds:

**Before (v1.1.1):**

```yaml
sisbajud:
  terminationGracePeriodSeconds: 60  # Custom value
```

**After (v1.2.0):**

```yaml
sisbajud:
  terminationGracePeriodSeconds: 105  # Minimum required for graceful shutdown
```

2. Upgrade the chart with the updated values:

```bash
helm upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n plugin-br-sisbajud -f values.yaml
```

> **Warning:** Values below 105 seconds may cause the pod to be forcefully terminated before completing graceful shutdown, resulting in incomplete telemetry flush, unclosed database connections, or lost in-flight requests.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n plugin-br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.2.0 -n plugin-br-sisbajud
```
<!-- {% endraw %} -->
