<!-- {% raw %} -->
# Helm Upgrade from v3.x to v4.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. ALLOW_INSECURE_TLS default behavior change](#1-allow_insecure_tls-default-behavior-change)
- **[Configuration Reference](#configuration-reference)**
  - [ALLOW_INSECURE_TLS flag handling](#allow_insecure_tls-flag-handling)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review TLS configuration](#step-1-review-tls-configuration)
  - [Step 2: Test connectivity with new default](#step-2-test-connectivity-with-new-default)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.4.4` to `4.0.0`. This is a **major** release that introduces a breaking change in how the `ALLOW_INSECURE_TLS` configuration flag is handled.

The application version (`appVersion: 3.1.1`) is unchanged. The primary change is the introduction of a new template helper function that modifies the default behavior of the `ALLOW_INSECURE_TLS` flag to correctly handle explicit boolean `false` values.

> **Warning:** If you have explicitly set `configmap.ALLOW_INSECURE_TLS: false` in your values and expect the application to enforce TLS verification, this upgrade fixes a bug where that setting was previously ignored. Review your TLS configuration before upgrading.

## Breaking Changes

### 1. ALLOW_INSECURE_TLS default behavior change

The `ALLOW_INSECURE_TLS` environment variable controls whether the `fetcher` application accepts insecure TLS connections to MongoDB, RabbitMQ, and Redis. Previously, the chart used Helm's `default` function, which treats an explicit boolean `false` as an empty value and falls back to the default `"true"`.

This meant that operators who set `configmap.ALLOW_INSECURE_TLS: false` expecting to enforce TLS verification would find their setting ignored, and the application would still allow insecure connections.

**Before (v3.4.4):**

The template used:

```yaml
ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "true" | quote }}
```

With this logic:
- `configmap.ALLOW_INSECURE_TLS: true` → `"true"` ✓
- `configmap.ALLOW_INSECURE_TLS: false` → `"true"` (bug: false treated as empty) ✗
- `configmap.ALLOW_INSECURE_TLS: "false"` → `"false"` ✓
- `configmap.ALLOW_INSECURE_TLS` not set → `"true"` ✓

**After (v4.0.0):**

The template now uses a new helper function:

```yaml
ALLOW_INSECURE_TLS: {{ include "fetcher.flagDefaultTrue" $cm.ALLOW_INSECURE_TLS | quote }}
```

With this logic:
- `configmap.ALLOW_INSECURE_TLS: true` → `"true"` ✓
- `configmap.ALLOW_INSECURE_TLS: false` → `"false"` ✓ (fixed)
- `configmap.ALLOW_INSECURE_TLS: "false"` → `"false"` ✓
- `configmap.ALLOW_INSECURE_TLS` not set → `"true"` ✓

| Setting | v3.4.4 behavior | v4.0.0 behavior |
|---------|-----------------|-----------------|
| `configmap.ALLOW_INSECURE_TLS: true` | `"true"` | `"true"` (unchanged) |
| `configmap.ALLOW_INSECURE_TLS: false` | `"true"` (bug) | `"false"` (fixed) |
| `configmap.ALLOW_INSECURE_TLS: "false"` | `"false"` | `"false"` (unchanged) |
| `configmap.ALLOW_INSECURE_TLS` not set | `"true"` | `"true"` (unchanged) |

> **Important:** If you have explicitly set `configmap.ALLOW_INSECURE_TLS: false` in your `values.yaml`, this upgrade will **finally enforce** that setting. The application will reject insecure TLS connections. Ensure your MongoDB, RabbitMQ, and Redis instances have valid TLS certificates configured, or the application will fail to connect.

> **Warning:** If you are using the bundled development MongoDB, RabbitMQ, or Redis (which do not have TLS enabled), and you have set `configmap.ALLOW_INSECURE_TLS: false`, the application will fail to start after upgrading. Either configure TLS on your data stores or remove the `false` setting to use the default `"true"`.

## Configuration Reference

### ALLOW_INSECURE_TLS flag handling

The new `fetcher.flagDefaultTrue` helper function correctly handles boolean values while maintaining backwards compatibility with string values and empty/unset values.

**Helper function definition:**

```yaml
{{- define "fetcher.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

| Input type | Input value | Output |
|------------|-------------|--------|
| Boolean | `true` | `"true"` |
| Boolean | `false` | `"false"` |
| String | `"true"` | `"true"` |
| String | `"false"` | `"false"` |
| Empty/unset | (none) | `"true"` |

**Configuration example:**

```yaml
configmap:
  # Enforce TLS verification (requires valid certificates on data stores)
  ALLOW_INSECURE_TLS: false
```

```yaml
configmap:
  # Allow insecure TLS connections (default, suitable for dev/bundled dependencies)
  ALLOW_INSECURE_TLS: true
```

```yaml
configmap:
  # Omit to use default (allows insecure TLS)
  # ALLOW_INSECURE_TLS: ...
```

> **Note:** The `ALLOW_INSECURE_TLS` flag affects connections to MongoDB, RabbitMQ, and Redis. When set to `false`, the application will verify TLS certificates and reject connections with invalid or self-signed certificates.

## Migration Steps

### Step 1: Review TLS configuration

Before upgrading, check your current `values.yaml` or Helm values for the `configmap.ALLOW_INSECURE_TLS` setting:

```bash
helm get values fetcher -n fetcher
```

Identify which scenario applies to your deployment:

#### Scenario 1: ALLOW_INSECURE_TLS not set (most common)

If you have not explicitly set `configmap.ALLOW_INSECURE_TLS`, no action is required. The default behavior remains `"true"`, allowing insecure TLS connections.

#### Scenario 2: ALLOW_INSECURE_TLS set to true or "true"

If you have explicitly set `configmap.ALLOW_INSECURE_TLS: true` or `configmap.ALLOW_INSECURE_TLS: "true"`, no action is required. The behavior is unchanged.

#### Scenario 3: ALLOW_INSECURE_TLS set to false (action required)

If you have set `configmap.ALLOW_INSECURE_TLS: false` expecting to enforce TLS verification, this upgrade will **finally honor that setting**. You must ensure:

1. **MongoDB** has TLS enabled with a valid certificate
2. **RabbitMQ** has TLS enabled with a valid certificate
3. **Redis** has TLS enabled with a valid certificate

If you are using the bundled development dependencies (MongoDB, RabbitMQ, Redis subchart), they do **not** have TLS configured by default. You have two options:

**Option 1: Remove the false setting (recommended for dev/test environments)**

Remove or comment out the `ALLOW_INSECURE_TLS: false` setting to use the default `"true"`:

```yaml
configmap:
  # ALLOW_INSECURE_TLS: false  # Remove this line
```

**Option 2: Configure TLS on data stores (recommended for production)**

Configure TLS certificates for your MongoDB, RabbitMQ, and Redis instances. Consult the respective subchart documentation:

- MongoDB: [bitnami/mongodb TLS configuration](https://github.com/bitnami/charts/tree/main/bitnami/mongodb#enabling-tls)
- RabbitMQ: [bitnami/rabbitmq TLS configuration](https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq#enabling-tls-support)
- Redis: [bitnami/redis TLS configuration](https://github.com/bitnami/charts/tree/main/bitnami/redis#enabling-tls-support)

Example `values.yaml` snippet for enabling TLS on bundled MongoDB:

```yaml
mongodb:
  tls:
    enabled: true
    mode: requireTLS
    certificatesSecret: mongodb-tls-certs
    certFilename: tls.crt
    certKeyFilename: tls.key
    certCAFilename: ca.crt
```

> **Important:** Configuring TLS on bundled dependencies requires creating Kubernetes secrets with valid certificates before upgrading. This is beyond the scope of this upgrade guide.

#### Scenario 4: ALLOW_INSECURE_TLS set to "false" (string)

If you have set `configmap.ALLOW_INSECURE_TLS: "false"` (as a string), the behavior is unchanged. The application already enforces TLS verification. Ensure your data stores have valid TLS certificates.

### Step 2: Test connectivity with new default

After determining your scenario and making any necessary configuration changes, test the upgrade in a non-production environment:

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm \
  --version 4.0.0 \
  -n fetcher \
  --dry-run --debug
```

Review the rendered ConfigMap to verify the `ALLOW_INSECURE_TLS` value:

```bash
helm template fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm \
  --version 4.0.0 \
  -n fetcher \
  | grep -A 2 "ALLOW_INSECURE_TLS"
```

After upgrading, monitor the manager and worker logs for TLS-related connection errors:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50 | grep -i tls
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50 | grep -i tls
```

Common error messages if TLS verification fails:

- `x509: certificate signed by unknown authority`
- `tls: failed to verify certificate`
- `connection refused` (if TLS port is not exposed)

> **Note:** If you encounter TLS errors after upgrading and need to temporarily revert to insecure mode, you can perform a rollback or set `configmap.ALLOW_INSECURE_TLS: true` and upgrade again.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.0.0 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.0.0 -n fetcher
```

After the upgrade completes, verify all pods are running:

```bash
kubectl get pods -n fetcher
```

Check manager and worker logs for successful startup and data store connectivity:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50
```
<!-- {% endraw %} -->
