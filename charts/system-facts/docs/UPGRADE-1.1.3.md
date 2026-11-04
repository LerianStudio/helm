<!-- {% raw %} -->
# Helm Upgrade from v1.1.2 to v1.1.3

This guide covers the upgrade of the `system-facts` Helm chart from version **1.1.2** to **1.1.3**. This is a patch release that removes unused service-discovery configuration, adds Redis TLS support, and refines documentation and metadata.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Configuration Changes](#configuration-changes)**
  - [Service Discovery Removal](#service-discovery-removal)
  - [Redis TLS Support](#redis-tls-support)
  - [License Key Filtering](#license-key-filtering)
  - [Deployment Template Refinement](#deployment-template-refinement)
- **[Documentation and Metadata Updates](#documentation-and-metadata-updates)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.1.3** removes the unused service-discovery integration from System Facts and adds support for Redis TLS configuration. The changes include:

- **Service discovery removal**: The `boilerplate.serviceDiscovery` section is now accepted for compatibility only; no `SD_*` environment variables are rendered
- **Redis TLS support**: New `REDIS_TLS` configuration key, sourced from `global.datastores.redis.tls` or explicit override
- **License key filtering**: `LICENSE_ENABLED` is now filtered from ConfigMap and Secret rendering (reserved for future use)
- **Deployment template refinement**: `terminationGracePeriodSeconds` now uses `dig` for safer default resolution
- **Documentation updates**: Chart metadata and comments updated to remove environment-specific references and clarify bundled subchart usage

There are no changes to:

- Application version (`appVersion` remains `1.1.0`)
- Image tags or container specifications
- Dependencies or subcharts
- Service, Ingress, or networking configuration

---

## Breaking Changes

**None.** This is a patch release with no breaking changes. All existing configurations remain valid.

The service-discovery fields (`boilerplate.serviceDiscovery.enabled`, `global.serviceDiscovery`) are still accepted but no longer render any environment variables. If you have these fields set, they are silently ignored. System Facts has never used lib-service-discovery, so this change only removes dead code from the templates.

---

## Configuration Changes

### Service Discovery Removal

System Facts does not use the lib-service-discovery client library, so the chart no longer renders `SD_*` environment variables. The `boilerplate.serviceDiscovery.enabled` flag and `global.serviceDiscovery` section are still accepted for compatibility with multi-chart values files, but they have no effect.

**Values schema change:**

| Setting | v1.1.2 | v1.1.3 |
|---------|--------|--------|
| `global.serviceDiscovery` | Rendered `SD_*` keys when `boilerplate.serviceDiscovery.enabled: true` | Accepted for compatibility; no keys rendered |
| `boilerplate.serviceDiscovery.enabled` | Enabled service-discovery integration | Accepted for compatibility; no effect |

**Before (v1.1.2):**

```yaml
global:
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"

system-facts:
  boilerplate:
    serviceDiscovery:
      enabled: true
```

This rendered in the ConfigMap:

```yaml
data:
  SD_ENABLED: "true"
  SD_ADDRESS: "consul.internal:8500"
  SD_TLS: "true"
  # ... other SD_* keys
```

**After (v1.1.3):**

```yaml
global:
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"

system-facts:
  boilerplate:
    serviceDiscovery:
      enabled: true
```

This renders in the ConfigMap:

```yaml
data:
  # No SD_* keys
```

**Operational impact:**

If you have `boilerplate.serviceDiscovery.enabled: true` in your values, the upgrade removes the `SD_*` environment variables from the ConfigMap. Kubernetes performs a rolling update of the System Facts Deployment because the ConfigMap checksum annotation changes. System Facts does not read these variables, so the removal has no runtime effect.

> **Note:** If you share a `global.serviceDiscovery` block across multiple charts in a single values file, you can leave it in place. The system-facts chart ignores it.

### Redis TLS Support

The chart now supports explicit Redis TLS configuration via the `REDIS_TLS` environment variable. This key can be set in three ways (in order of precedence):

1. **Explicit override in `extraEnvVars`** (legacy pattern, still supported)
2. **Explicit override in `system-facts.configmap.REDIS_TLS`** (new, recommended)
3. **Global default from `global.datastores.redis.tls`** (new, recommended for multi-chart deployments)

**New configuration key:**

| Key | Default | Description |
|-----|---------|-------------|
| `system-facts.configmap.REDIS_TLS` | `""` (not set) | Enable TLS for Redis connections; set to `"true"` or `"false"` |
| `global.datastores.redis.tls` | `""` (not set) | Global Redis TLS setting; inherited by all charts that support it |

**Example 1: Set TLS globally**

```yaml
global:
  datastores:
    redis:
      host: "redis.example.com"
      tls: "true"
```

This renders in the ConfigMap:

```yaml
data:
  REDIS_HOST: "redis.example.com"
  REDIS_TLS: "true"
```

**Example 2: Override TLS per-chart**

```yaml
global:
  datastores:
    redis:
      host: "redis.example.com"
      tls: "true"

system-facts:
  configmap:
    REDIS_TLS: "false"
```

This renders in the ConfigMap:

```yaml
data:
  REDIS_HOST: "redis.example.com"
  REDIS_TLS: "false"
```

**Example 3: Legacy pattern via extraEnvVars**

```yaml
system-facts:
  extraEnvVars:
    - name: REDIS_TLS
      value: "true"
```

This renders in the ConfigMap:

```yaml
data:
  REDIS_TLS: "true"
```

> **Note:** If you set `REDIS_TLS` in `extraEnvVars`, the chart does not add a duplicate key. The `extraEnvVars` value is passed through unchanged.

**Operational impact:**

If you are connecting to a Redis instance that requires TLS (e.g., AWS ElastiCache with in-transit encryption enabled), set `global.datastores.redis.tls: "true"` or `system-facts.configmap.REDIS_TLS: "true"`. The upgrade adds the `REDIS_TLS` key to the ConfigMap, which triggers a rolling update of the System Facts Deployment.

> **Important:** The System Facts application must support the `REDIS_TLS` environment variable. Verify that your application version (`appVersion: 1.1.0`) includes this feature before enabling it.

### License Key Filtering

The chart now filters the `LICENSE_ENABLED` key from both the ConfigMap and Secret templates. This key is reserved for future licensing integration and should not be set manually.

**Filtered keys:**

| Key | Location | Reason |
|-----|----------|--------|
| `LICENSE_ENABLED` | `system-facts.configmap` | Reserved for future use; filtered from ConfigMap rendering |
| `LICENSE_ENABLED` | `system-facts.secrets` | Reserved for future use; filtered from Secret rendering |

**Before (v1.1.2):**

If you set `LICENSE_ENABLED` in `extraEnvVars`, it was rendered in the ConfigMap:

```yaml
system-facts:
  extraEnvVars:
    - name: LICENSE_ENABLED
      value: "true"
```

Rendered ConfigMap:

```yaml
data:
  LICENSE_ENABLED: "true"
```

**After (v1.1.3):**

```yaml
system-facts:
  extraEnvVars:
    - name: LICENSE_ENABLED
      value: "true"
```

Rendered ConfigMap:

```yaml
data:
  # LICENSE_ENABLED is filtered out
```

**Operational impact:**

If you have `LICENSE_ENABLED` in your `extraEnvVars`, `configmap`, or `secrets` sections, it is silently removed from the rendered resources. System Facts does not currently use this key, so the removal has no runtime effect.

> **Note:** This change prepares the chart for future licensing integration. Do not set `LICENSE_ENABLED` manually; it will be managed by the chart when the feature is implemented.

### Deployment Template Refinement

The Deployment template now uses the `dig` function to resolve `terminationGracePeriodSeconds`, which provides safer default handling when the value is not set.

**Template change:**

| Setting | v1.1.2 | v1.1.3 |
|---------|--------|--------|
| `terminationGracePeriodSeconds` resolution | `{{ (index .Values "system-facts").terminationGracePeriodSeconds \| default 55 }}` | `{{ dig "terminationGracePeriodSeconds" 55 (index .Values "system-facts") \| int }}` |

**Before (v1.1.2):**

```yaml
terminationGracePeriodSeconds: {{ (index .Values "system-facts").terminationGracePeriodSeconds | default 55 }}
```

**After (v1.1.3):**

```yaml
terminationGracePeriodSeconds: {{ dig "terminationGracePeriodSeconds" 55 (index .Values "system-facts") | int }}
```

**Operational impact:**

This change has no functional impact. The `dig` function is more robust when the `system-facts` section is missing or when `terminationGracePeriodSeconds` is explicitly set to `null`. The default remains `55` seconds.

> **Note:** If you have overridden `system-facts.terminationGracePeriodSeconds` in your values, the behavior is unchanged. The `dig` function returns your override, and the `| int` filter ensures it is rendered as an integer.

---

## Documentation and Metadata Updates

Version **1.1.3** updates chart metadata and documentation comments to remove environment-specific references and clarify the purpose of bundled subcharts.

**Chart.yaml changes:**

| Field | v1.1.2 | v1.1.3 |
|-------|--------|--------|
| `home` | `https://github.com/LerianStudio/helm` | `https://github.com/LerianStudio/helm/tree/main/charts/system-facts` |
| `sources` | Included `https://github.com/LerianStudio/system-facts` | Removed application repository; only chart source remains |

**values.yaml changes:**

- Removed references to "benedita" and "anacleto" environments (internal environment names)
- Updated comments to use generic language: "by default" instead of "on benedita"
- Clarified that bundled Postgres and Valkey subcharts are disabled by default and intended for self-contained installs

**Operational impact:**

These changes are documentation-only and have no effect on rendered resources or runtime behavior.

---

## Migration Steps

No values changes are required. The upgrade can be applied directly with `--reuse-values`.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.1.2`.

### Step 2: Review Redis TLS requirements

If you are connecting to a Redis instance that requires TLS, prepare to set the `REDIS_TLS` configuration:

**Option 1: Set globally (recommended for multi-chart deployments)**

Add to your values file:

```yaml
global:
  datastores:
    redis:
      tls: "true"
```

**Option 2: Set per-chart**

Add to your values file:

```yaml
system-facts:
  configmap:
    REDIS_TLS: "true"
```

> **Note:** If your Redis instance does not require TLS, no action is needed. The `REDIS_TLS` key is optional and defaults to not being set.

### Step 3: Apply the upgrade

Upgrade to version `1.1.3` using your existing values:

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --version 1.1.3 \
  --namespace system-facts \
  --reuse-values
```

If you are adding Redis TLS configuration, include the new values:

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --version 1.1.3 \
  --namespace system-facts \
  --reuse-values \
  --set global.datastores.redis.tls=true
```

Or with a values file:

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --version 1.1.3 \
  --namespace system-facts \
  --reuse-values \
  --values redis-tls.yaml
```

> **Note:** The `--reuse-values` flag preserves your existing configuration. If you are not adding Redis TLS, the upgrade only updates the chart version and removes unused service-discovery keys.

### Step 4: Monitor the upgrade

Watch the rollout status for the System Facts service:

```bash
kubectl rollout status deployment/system-facts -n system-facts
```

The ConfigMap checksum annotation changes (due to service-discovery key removal or Redis TLS addition), so Kubernetes performs a rolling update.

### Step 5: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.1.3`.

Verify that the ConfigMap no longer contains `SD_*` keys:

```bash
kubectl get configmap system-facts -n system-facts -o yaml | grep SD_
```

Expected output: no matches (empty).

If you enabled Redis TLS, verify the `REDIS_TLS` key is present:

```bash
kubectl get configmap system-facts -n system-facts -o jsonpath='{.data.REDIS_TLS}'
```

Expected output: `true` (if you set it).

### Step 6: Test the service

Verify the service is responding correctly:

```bash
kubectl port-forward -n system-facts svc/system-facts 8080:8080
curl http://localhost:8080/health
```

If you enabled Redis TLS, verify that the application connects to Redis successfully by checking the logs:

```bash
kubectl logs -n system-facts deployment/system-facts --tail=50
```

Look for successful Redis connection messages and no TLS-related errors.

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm --namespace system-facts --version 1.1.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm --namespace system-facts --version 1.1.3
```
<!-- {% endraw %} -->
