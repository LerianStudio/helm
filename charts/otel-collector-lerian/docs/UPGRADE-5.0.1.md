# Helm Upgrade from v5.0.0 to v5.0.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Chart metadata URLs updated](#1-chart-metadata-urls-updated)
  - [2. Default client.id placeholder changed](#2-default-clientid-placeholder-changed)
  - [3. Dependency documentation comment removed](#3-dependency-documentation-comment-removed)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `otel-collector-lerian` chart upgrade from `5.0.0` to `5.0.1`. This is a patch release that updates chart metadata URLs, changes the default `client.id` placeholder value, and removes an inline documentation comment. The application version (`appVersion: 0.1.0`) and all rendered manifests remain unchanged unless you are using the default `client.id` value.

There are no breaking changes, no new values, no removed values, and no template changes. Existing `values.yaml` overrides remain fully compatible.

## Fixes

### 1. Chart metadata URLs updated

The chart's `home` and `sources` URLs have been updated to point to the correct repository location within the Lerian Studio Helm monorepo.

| Field | v5.0.0 | v5.0.1 |
|-------|--------|--------|
| `home` | `https://github.com/LerianStudio/otel-collector-lerian` | `https://github.com/LerianStudio/helm/tree/main/charts/otel-collector-lerian` |
| `sources[0]` | `https://github.com/LerianStudio/otel-collector-lerian/tree/main/charts/otel-collector-lerian` | `https://github.com/LerianStudio/helm/tree/main/charts/otel-collector-lerian` |

**Chart.yaml change:**

**Before (v5.0.0):**

```yaml
home: https://github.com/LerianStudio/otel-collector-lerian

sources:
  - https://github.com/LerianStudio/otel-collector-lerian/tree/main/charts/otel-collector-lerian
```

**After (v5.0.1):**

```yaml
home: https://github.com/LerianStudio/helm/tree/main/charts/otel-collector-lerian

sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/otel-collector-lerian
```

> **Note:** This change affects only chart metadata and does not modify any deployed Kubernetes resources.

### 2. Default client.id placeholder changed

The default placeholder value for `client.id` in the `resource/add_client_id` processor has been changed from `"Firmino"` to `"change-me"` to make it more obvious that this value should be customized.

| Setting | v5.0.0 | v5.0.1 |
|---------|--------|--------|
| `opentelemetry-collector.config.processors.resource/add_client_id.attributes[0].value` | `"Firmino"` | `"change-me"` |

**values.yaml change:**

**Before (v5.0.0):**

```yaml
opentelemetry-collector:
  config:
    processors:
      resource/add_client_id:
        attributes:
          - key: client.id
            value: "Firmino"
            action: upsert
```

**After (v5.0.1):**

```yaml
opentelemetry-collector:
  config:
    processors:
      resource/add_client_id:
        attributes:
          - key: client.id
            value: "change-me"
            action: upsert
```

**Operational impact:**

- If you have **not** overridden `opentelemetry-collector.config.processors.resource/add_client_id.attributes[0].value` in your `values.yaml`, the deployed collector will now use `"change-me"` instead of `"Firmino"` as the `client.id` attribute value. This will affect all telemetry data exported by the collector.
- If you have **already** overridden this value in your `values.yaml`, your custom value will continue to be used and no change will occur.

> **Important:** The `client.id` attribute is added to all telemetry resources by the `resource/add_client_id` processor. If you are relying on the default value for filtering, routing, or correlation, you must update your downstream systems or override this value before upgrading.

### 3. Dependency documentation comment removed

An inline comment referencing the Lerian Studio documentation for chart dependencies has been removed from `Chart.yaml`. This change does not affect chart functionality or deployed resources.

**Chart.yaml change:**

**Before (v5.0.0):**

```yaml
# This Helm chart includes multiple dependencies required for the application.
# To understand the purpose and configuration of each dependency, visit:
# https://docs.lerian.studio/docs/midaz-components
dependencies:
  - name: opentelemetry-collector
    version: 0.178.1
```

**After (v5.0.1):**

```yaml
# This Helm chart includes multiple dependencies required for the application.
dependencies:
  - name: opentelemetry-collector
    version: 0.178.1
```

> **Note:** This is a documentation-only change and has no runtime impact.

## Configuration Changes

No configuration changes are required unless you are using the default `client.id` value and need to preserve the previous behavior.

| Setting | v5.0.0 | v5.0.1 | Action Required |
|---------|--------|--------|-----------------|
| `opentelemetry-collector.config.processors.resource/add_client_id.attributes[0].value` | `"Firmino"` | `"change-me"` | Optional: override if you need to preserve `"Firmino"` or set your own value |
| Chart metadata URLs | Old repository paths | New monorepo paths | None |
| Dependency comment | Present | Removed | None |

## Migration Steps

### If you are using the default client.id value

If you have **not** overridden the `client.id` value in your `values.yaml` and you need to preserve the previous default value (`"Firmino"`), follow these steps:

1. Add the following override to your `values.yaml`:

```yaml
opentelemetry-collector:
  config:
    processors:
      resource/add_client_id:
        attributes:
          - key: client.id
            value: "Firmino"
            action: upsert
```

2. Proceed with the upgrade using the updated `values.yaml`.

> **Recommendation:** Instead of preserving `"Firmino"`, set a meaningful `client.id` value that identifies your organization or environment (e.g., `"my-org"`, `"production"`, `"team-alpha"`). The chart does not validate this value, so choose a string that makes sense for your telemetry correlation and filtering needs.

### If you have already overridden client.id

No action is required. Your custom value will continue to be used.

### If you want to use the new default

No action is required. The new default `"change-me"` will be applied automatically.

> **Warning:** Using `"change-me"` in production is not recommended. This placeholder is intended to signal that the value should be customized. Set a meaningful `client.id` value in your `values.yaml` before deploying to production.

## Preview changes before upgrading

```bash
helm diff upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 5.0.1 -n otel-collector-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 5.0.1 -n otel-collector-lerian
```
