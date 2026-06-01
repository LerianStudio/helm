# Helm Upgrade from v3.0.x to v3.1.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Chart version bump to 3.1.0-beta.2](#1-chart-version-bump-to-310-beta2)
  - [2. HTTP status code attribute normalization — temporary workaround (3.1.0-beta.3)](#2-http-status-code-attribute-normalization--temporary-workaround-310-beta3)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `otel-collector-lerian` chart upgrade from `3.0.0` to `3.1.0-beta.3`. `3.1.0-beta.2` was a maintenance version bump only; `3.1.0-beta.3` adds a **temporary** span attribute normalization step to keep `calls_total` status labels working while services migrate to the new OTel semantic convention (`http.response.status_code`). The permanent fix belongs in `lib-observability` and will replace this workaround once released and rolled out.

There are no breaking changes, no new values, and no removed values. Existing `values.yaml` overrides remain compatible.

## Features

### 1. Chart version bump to 3.1.0-beta.2

The chart version has been bumped from `3.0.0` to `3.1.0-beta.2`. No other chart files (templates, values, dependencies) were changed between these releases.

| Field | v3.0.0 | v3.1.0-beta.2 |
|-------|--------|---------------|
| Chart version | `3.0.0` | `3.1.0-beta.2` |
| App version | `0.1.0` | `0.1.0` |

Files modified between `3.0.0` and `3.1.0-beta.2`:

- `charts/otel-collector-lerian/Chart.yaml`
- `charts/otel-collector-lerian/CHANGELOG.md`

> **Note:** `3.1.0-beta.2` is a pre-release. Pin the exact version when upgrading and validate in a non-production environment before promoting.

### 2. HTTP status code attribute normalization — temporary workaround (3.1.0-beta.3)

> **Temporary palliative.** The real fix belongs in `lib-observability` (emit `http.status_code` alongside `http.response.status_code` at source). This collector-side normalization exists only to keep dashboards/alerts working until that library fix is released and adopted, and will be removed afterwards.

`lib-observability` v1.1.0-beta.3 emits the OTel semantic convention span attribute `http.response.status_code` instead of the legacy `http.status_code`. The collector's `spanmetrics` connector still has `http.status_code` as a dimension, so without normalization the `calls_total` metric loses its status label for any service using the new lib.

As a compatibility shim, `3.1.0-beta.3` adds a `transform/normalize_http_status_code` processor in the `traces` pipeline (before the `spanmetrics` and `otlphttp/server` exporters) that:

- Copies `http.response.status_code` into `http.status_code` when only the new attribute is present.
- Mirrors `http.status_code` into `http.response.status_code` when only the legacy attribute is present.

Both attributes are preserved on the trace, and the existing `spanmetrics` dimension keeps working unchanged. No dashboards or alerts need to be updated.

| Field | v3.1.0-beta.2 | v3.1.0-beta.3 |
|-------|---------------|---------------|
| Chart version | `3.1.0-beta.2` | `3.1.0-beta.3` |
| Traces pipeline processors | k8sattributes, resource/add_client_id, transform/remove_sensitive_attributes | + transform/normalize_http_status_code (last, before exporters) |

Files modified between `3.1.0-beta.2` and `3.1.0-beta.3`:

- `charts/otel-collector-lerian/Chart.yaml`
- `charts/otel-collector-lerian/values.yaml`
- `charts/otel-collector-lerian/docs/UPGRADE-3.1.md`

## Configuration Changes

No configuration changes are required. All existing `values.yaml` overrides remain compatible with `3.1.0-beta.3`. The new `transform/normalize_http_status_code` processor is added under `opentelemetry-collector.config.processors` and referenced in `service.pipelines.traces.processors`.

| Setting | v3.0.0 | v3.1.0-beta.3 |
|---------|--------|---------------|
| `values.yaml` processors | (existing set) | + `transform/normalize_http_status_code` |
| Templates | (unchanged) | (unchanged) |
| Image references | (unchanged) | (unchanged) |

## Migration Steps

This upgrade requires no manual migration steps. The collector ConfigMap will change to include the new processor, so the collector pods will be rolled.

**Recommended upgrade process:**

1. Review the rendered diff using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)). Expect changes only to the collector ConfigMap.
2. Run the upgrade command during a normal change window.
3. Verify pod state after the upgrade:

```bash
kubectl get pods -n otel-collector-lerian
```

4. Verify that `calls_total` continues to carry `http_status_code` labels after services upgrade to `lib-observability` v1.1.0-beta.3 or newer.

## Preview changes before upgrading

```bash
helm diff upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian-helm --version 3.1.0-beta.3 -n otel-collector-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian-helm --version 3.1.0-beta.3 -n otel-collector-lerian
```
