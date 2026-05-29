# Helm Upgrade from v3.0.x to v3.1.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Chart version bump to 3.1.0-beta.2](#1-chart-version-bump-to-310-beta2)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `otel-collector-lerian` chart upgrade from `3.0.0` to `3.1.0-beta.2`. It is a maintenance release that bumps the chart version only. The application version (`appVersion: 0.1.0`) and all rendered manifests are unchanged.

There are no breaking changes, no new values, no removed values, and no template changes. Existing `values.yaml` overrides remain compatible.

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

## Configuration Changes

No configuration changes are required. All existing `values.yaml` settings remain compatible with `3.1.0-beta.2`.

| Setting | v3.0.0 | v3.1.0-beta.2 |
|---------|--------|---------------|
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
helm diff upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian-helm --version 3.1.0-beta.2 -n otel-collector-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian-helm --version 3.1.0-beta.2 -n otel-collector-lerian
```
