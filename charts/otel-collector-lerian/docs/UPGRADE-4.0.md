# Helm Upgrade from v3.x to v4.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Chart type annotation added](#1-chart-type-annotation-added)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `otel-collector-lerian` chart upgrade from `3.0.0` to `4.0.0`. This is a major version bump that introduces a new chart annotation to classify the chart as a dependency wrapper. The application version (`appVersion: 0.1.0`) and all rendered manifests remain unchanged.

There are no breaking changes to configuration, no new values, no removed values, and no template changes. Existing `values.yaml` overrides remain fully compatible.

## Features

### 1. Chart type annotation added

The chart now includes a metadata annotation that identifies it as a dependency wrapper chart. This annotation is used for chart classification and tooling purposes but does not affect runtime behavior or deployed resources.

| Field | v3.0.0 | v4.0.0 |
|-------|--------|--------|
| Chart version | `3.0.0` | `4.0.0` |
| App version | `0.1.0` | `0.1.0` |
| Annotations | (none) | `lerian.studio/chart-type: dependency-wrapper` |

**Chart.yaml change:**

**Before (v3.0.0):**

```yaml
apiVersion: v2
name: otel-collector-lerian
description: A Helm chart for Kubernetes
type: application

home: https://github.com/LerianStudio/otel-collector-lerian
```

**After (v4.0.0):**

```yaml
apiVersion: v2
name: otel-collector-lerian
description: A Helm chart for Kubernetes
type: application
annotations:
  lerian.studio/chart-type: dependency-wrapper

home: https://github.com/LerianStudio/otel-collector-lerian
```

> **Note:** This annotation is metadata only and does not modify any Kubernetes resources. It may be consumed by Lerian Studio tooling or chart repositories for categorization purposes.

Files modified between `3.0.0` and `4.0.0`:

- `charts/otel-collector-lerian/Chart.yaml`

## Configuration Changes

No configuration changes are required. All existing `values.yaml` settings remain compatible with `4.0.0`.

| Setting | v3.0.0 | v4.0.0 |
|---------|--------|--------|
| `values.yaml` keys | (unchanged) | (unchanged) |
| Templates | (unchanged) | (unchanged) |
| Image references | (unchanged) | (unchanged) |

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will produce no changes to rendered manifests, so no rollout should occur.

**Recommended upgrade process:**

1. Review the rendered diff using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)). Expect an empty diff.
2. Run the upgrade command during a normal change window.
3. Verify pod state is unchanged after the upgrade:

```bash
kubectl get pods -n otel-collector-lerian
```

> **Note:** Because no manifest fields change, Kubernetes should not perform a rollout. If a rollout occurs, capture the diff and report it before proceeding in production.

## Preview changes before upgrading

```bash
helm diff upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 4.0.0 -n otel-collector-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian --version 4.0.0 -n otel-collector-lerian
```
