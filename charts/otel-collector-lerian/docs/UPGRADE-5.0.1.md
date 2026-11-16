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

The chart's `home` and `sources` URLs now point to the Lerian Studio Helm monorepo.

**After (v5.0.1):**

```yaml
home: https://github.com/LerianStudio/helm/tree/main/charts/otel-collector-lerian

sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/otel-collector-lerian
```

> **Note:** This change affects only chart metadata and does not modify any deployed Kubernetes resources.

### 2. Default client.id placeholder changed

The default value for `client.id` in the `resource/add_client_id` processor is now the placeholder `"change-me"`.

| Setting | v5.0.1 default |
|---------|----------------|
| `opentelemetry-collector.config.processors.resource/add_client_id.attributes[0].value` | `"change-me"` |

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

- If you have **not** overridden `opentelemetry-collector.config.processors.resource/add_client_id.attributes[0].value` in your `values.yaml`, the deployed collector will now use `"change-me"` as the `client.id` attribute value instead of the previous placeholder. This will affect all telemetry data exported by the collector.
- If you have **already** overridden this value in your `values.yaml`, your custom value will continue to be used and no change will occur.

> **Important:** The `client.id` attribute is added to all telemetry resources by the `resource/add_client_id` processor. If you are relying on the default value for filtering, routing, or correlation, you must update your downstream systems or override this value before upgrading.

### 3. Dependency documentation comment removed

An inline comment referencing the Lerian Studio documentation for chart dependencies has been removed from `Chart.yaml`. This change does not affect chart functionality or deployed resources.

## Configuration Changes

No configuration changes are required unless you are using the default `client.id` value.

| Setting | v5.0.1 | Action Required |
|---------|--------|-----------------|
| `opentelemetry-collector.config.processors.resource/add_client_id.attributes[0].value` | `"change-me"` | Set your own value |
| Chart metadata URLs | New monorepo paths | None |
| Dependency comment | Removed | None |

## Migration Steps

### If you are using the default client.id value

If you have **not** overridden the `client.id` value in your `values.yaml`, set your own value:

1. Add the following override to your `values.yaml`:

```yaml
opentelemetry-collector:
  config:
    processors:
      resource/add_client_id:
        attributes:
          - key: client.id
            value: "your-client-id"
            action: upsert
```

2. Proceed with the upgrade using the updated `values.yaml`. Add `-f` with your values file to the upgrade command below. Without `-f` or `--set`, Helm reuses the values of the previous release and the new `client.id` is not applied.

> **Recommendation:** Set a meaningful `client.id` value that identifies your organization. The chart does not validate this value, so choose a string that makes sense for your telemetry correlation and filtering needs.

### If you have already overridden client.id

No action is required. Your custom value will continue to be used.

### If you want to use the new default

No action is required. The new default `"change-me"` will be applied automatically.

> **Warning:** Using `"change-me"` in production is not recommended. This placeholder is intended to signal that the value should be customized. Set a meaningful `client.id` value in your `values.yaml` before deploying to production.

## Preview changes before upgrading

```bash
helm diff upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 5.0.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 5.0.1 -n midaz
```
