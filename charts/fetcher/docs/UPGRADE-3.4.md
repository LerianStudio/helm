# Helm Upgrade from v3.3.0 to v3.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Access Manager permission declaration (RI) support](#1-access-manager-permission-declaration-ri-support)
  - [2. Enhanced documentation for namespace and TLS configuration](#2-enhanced-documentation-for-namespace-and-tls-configuration)
  - [3. Dependency update: lerian-common-helm 2.4.0](#3-dependency-update-lerian-common-helm-240)
- **[Configuration Reference](#configuration-reference)**
  - [New global.idp fields](#new-globalidp-fields)
  - [New manager.configmap fields](#new-managerconfigmap-fields)
  - [New manager.secrets fields](#new-managersecrets-fields)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.3.0` to `3.4.0`. This is a minor release that adds support for Access Manager permission declaration (Resource Identifier) integration, updates the `lerian-common-helm` dependency from `2.3.0` to `2.4.0`, and improves documentation for namespace and TLS configuration.

The application version (`appVersion: 3.1.0`) is unchanged. No breaking changes are introduced, and no data migration is required. All new configuration fields are optional and default to disabled or empty values, maintaining backward compatibility with existing installations.

## Features

### 1. Access Manager permission declaration (RI) support

The `manager` component now supports integration with the Access Manager identity plugin for permission declaration using machine-to-machine (M2M) authentication. This feature is controlled by new environment variables and secrets, all of which are optional and disabled by default.

**New environment variables (manager ConfigMap):**

| Variable | Default | Description |
|----------|---------|-------------|
| `IDP_DECLARATION_ENABLED` | `"false"` | Enables Access Manager permission declaration; when `"true"`, the manager requires `IDP_HOST` and the M2M client credentials |
| `IDP_HOST` | (empty) | Access Manager identity service endpoint (e.g., `http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001`) |

**New secrets (manager Secret):**

| Key | Description |
|-----|-------------|
| `IDP_M2M_CLIENT_ID` | Machine-to-machine client ID for Access Manager authentication |
| `IDP_M2M_CLIENT_SECRET` | Machine-to-machine client secret for Access Manager authentication |

These values are emitted by the new `lerian-common.idp.env` and `lerian-common.idp.secret` template helpers from the updated `lerian-common-helm` dependency. The resolution order is:

1. `manager.configmap.IDP_DECLARATION_ENABLED` / `IDP_HOST` (highest priority)
2. `manager.extraEnvVars.IDP_DECLARATION_ENABLED` / `IDP_HOST` (legacy fallback)
3. `global.idp.declarationEnabled` / `global.idp.host` (environment-wide default)

**Configuration example:**

To enable Access Manager permission declaration, set the following in your `values.yaml`:

```yaml
global:
  idp:
    declarationEnabled: true
    host: "http://plugin-access-manager-identity.fetcher.svc.cluster.local:4001"

manager:
  secrets:
    IDP_M2M_CLIENT_ID: "your-client-id"
    IDP_M2M_CLIENT_SECRET: "your-client-secret"
```

Alternatively, configure it at the component level:

```yaml
manager:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://plugin-access-manager-identity.fetcher.svc.cluster.local:4001"
  secrets:
    IDP_M2M_CLIENT_ID: "your-client-id"
    IDP_M2M_CLIENT_SECRET: "your-client-secret"
```

> **Note:** When `IDP_DECLARATION_ENABLED` is set to `"true"`, the manager will refuse to start if `IDP_HOST` or the M2M client credentials are missing. Leave the feature disabled (default) if you are not using Access Manager.

> **Important:** The `IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` keys are only rendered in the manager Secret when their values are non-empty. Empty values are skipped to avoid masking shared secrets from the common Secret.

### 2. Enhanced documentation for namespace and TLS configuration

The `values.yaml` file now includes clarifying comments for two existing configuration areas:

**Namespace override clarification:**

The `namespaceOverride` field now documents that it controls the namespace of the MongoDB bootstrap Job **only** (when using `global.externalMongoDefinitions`). All other resources, including the RabbitMQ bootstrap Job, are created in the release namespace.

**Before (v3.3.0):**

```yaml
namespaceOverride: "fetcher"
```

**After (v3.4.0):**

```yaml
# Namespace of the MongoDB bootstrap Job ONLY (global.externalMongoDefinitions). Every other
# object, including the RabbitMQ bootstrap Job, is created in the release namespace.
# Set it to the release namespace when that is not "fetcher".
namespaceOverride: "fetcher"
```

> **Note:** If your release namespace is not `"fetcher"`, set `namespaceOverride` to match your release namespace to ensure the MongoDB bootstrap Job is created in the correct location.

**TLS configuration note:**

The `common` section now includes a reminder that `REDIS_TLS` and `RABBITMQ_TLS` environment variables (read by the application) are not automatically emitted by any datastore mask (`global.datastores.*.tls`, `global.datastores.*.scheme`, or `global.cloud`). Operators must set these variables explicitly in `common.configmap` when the Redis or RabbitMQ endpoints require TLS.

**Before (v3.3.0):**

```yaml
common:
  # -- Shared (common) application config for BOTH the manager and worker
  # surfaces. Defaults for every shared key live in the templates
  # (fetcher.commonConfigmapData): dependency CONNECTIONS resolve through
```

**After (v3.4.0):**

```yaml
common:
  # NOTE: REDIS_TLS and RABBITMQ_TLS (read by the app) are not emitted by any datastore mask
  # (global.datastores.*.tls/scheme, global.cloud); set them here when the endpoint needs TLS.
  # -- Shared (common) application config for BOTH the manager and worker
  # surfaces. Defaults for every shared key live in the templates
  # (fetcher.commonConfigmapData): dependency CONNECTIONS resolve through
```

**Configuration example:**

To enable TLS for Redis and RabbitMQ connections, set the following in your `values.yaml`:

```yaml
common:
  configmap:
    REDIS_TLS: "true"
    RABBITMQ_TLS: "true"
```

**KEDA installation clarification:**

The `keda` section now includes a note explaining that enabling the KEDA dependency installs the KEDA operator only. The chart does not include a `ScaledObject` template, so it does not autoscale the manager or worker by default. Operators should use `manager.autoscaling` (HPA) or create their own `ScaledObject` resources.

**Before (v3.3.0):**

```yaml
# KEDA - Kubernetes Event-driven Autoscaling
keda:
  enabled: false
```

**After (v3.4.0):**

```yaml
# KEDA - Kubernetes Event-driven Autoscaling
# NOTE: enabling this installs the KEDA operator only. The chart has no ScaledObject
# template, so it does not autoscale the manager or worker; use manager.autoscaling (HPA)
# or create your own ScaledObject.
keda:
  enabled: false
```

### 3. Dependency update: lerian-common-helm 2.4.0

The `lerian-common-helm` dependency has been updated from version `2.3.0` to `2.4.0`. This update introduces the new `lerian-common.idp.env` and `lerian-common.idp.secret` template helpers used for Access Manager permission declaration support.

| Dependency | v3.3.0 | v3.4.0 |
|------------|--------|--------|
| `lerian-common-helm` | `2.3.0` | `2.4.0` |

> **Note:** The `lerian-common-helm` dependency is pulled automatically during the Helm upgrade. No manual action is required.

## Configuration Reference

### New global.idp fields

The `global.idp` object provides environment-wide defaults for Access Manager permission declaration configuration. These values are consumed by the `lerian-common.idp.env` template helper.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `global.idp.declarationEnabled` | boolean | (not set) | Enables Access Manager permission declaration for the manager; maps to `IDP_DECLARATION_ENABLED` |
| `global.idp.host` | string | (not set) | Access Manager identity service endpoint; maps to `IDP_HOST` |

**Example configuration:**

```yaml
global:
  idp:
    declarationEnabled: true
    host: "http://plugin-access-manager-identity.fetcher.svc.cluster.local:4001"
```

### New manager.configmap fields

The manager ConfigMap now supports two new optional fields for Access Manager permission declaration. These fields override `global.idp` values when set.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `manager.configmap.IDP_DECLARATION_ENABLED` | string | `"false"` | Enables Access Manager permission declaration; set to `"true"` to enable |
| `manager.configmap.IDP_HOST` | string | (empty) | Access Manager identity service endpoint |

**Example configuration:**

```yaml
manager:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://plugin-access-manager-identity.fetcher.svc.cluster.local:4001"
```

> **Note:** The `IDP_DECLARATION_ENABLED` value is always emitted in the ConfigMap (defaults to `"false"`). The `IDP_HOST` value is only emitted when set to a non-empty string.

### New manager.secrets fields

The manager Secret now supports two new optional fields for Access Manager M2M authentication credentials. These secrets are only rendered when their values are non-empty.

| Field | Type | Description |
|-------|------|-------------|
| `manager.secrets.IDP_M2M_CLIENT_ID` | string | Machine-to-machine client ID for Access Manager authentication |
| `manager.secrets.IDP_M2M_CLIENT_SECRET` | string | Machine-to-machine client secret for Access Manager authentication |

**Example configuration:**

```yaml
manager:
  secrets:
    IDP_M2M_CLIENT_ID: "your-client-id"
    IDP_M2M_CLIENT_SECRET: "your-client-secret"
```

> **Important:** These credentials are required when `IDP_DECLARATION_ENABLED` is set to `"true"`. The manager will fail to start if the credentials are missing when the feature is enabled.

## Migration Steps

This upgrade requires no mandatory migration steps. All new configuration fields are optional and default to disabled or empty values.

**Recommended upgrade process:**

1. Review the new Access Manager permission declaration feature. If you are not using Access Manager, no action is required—the feature is disabled by default.

2. If you are using Access Manager and want to enable permission declaration:
   - Obtain M2M client credentials from your Access Manager installation
   - Set `global.idp.declarationEnabled: true` and `global.idp.host` in your `values.yaml`
   - Set `manager.secrets.IDP_M2M_CLIENT_ID` and `manager.secrets.IDP_M2M_CLIENT_SECRET`

3. If your release namespace is not `"fetcher"`, verify that `namespaceOverride` is set to match your release namespace.

4. If you are using Redis or RabbitMQ with TLS, verify that `common.configmap.REDIS_TLS` and `common.configmap.RABBITMQ_TLS` are set to `"true"`.

5. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

6. Run the upgrade command during a maintenance window.

7. Verify the manager pods are healthy after the upgrade:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager
```

8. If you enabled Access Manager permission declaration, check manager logs for successful authentication:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50 | grep -i idp
```

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.0 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.0 -n fetcher
```
