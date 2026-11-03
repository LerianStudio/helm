# Helm Upgrade from v3.0.0 to v3.0.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `3.0.0` to `3.0.1`. This is a patch release with no configuration changes, template modifications, or application version updates. The upgrade is a simple version bump with no breaking changes.

| Field | v3.0.0 | v3.0.1 |
|-------|--------|--------|
| Chart version | `3.0.0` | `3.0.1` |
| App version | `1.0.0` | `1.0.0` |

**What changed:**

- Chart version bumped from `3.0.0` to `3.0.1`
- No changes to `values.yaml`, templates, or application configuration
- No changes to default values or behavior

**Migration impact:**

This upgrade requires no configuration changes or manual intervention. All existing values files and configurations remain valid.

> **Note:** This is a metadata-only release. You can safely upgrade without reviewing configuration or preparing migration steps.

## Preview changes before upgrading

```bash
helm diff upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 3.0.1 -n tracer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 3.0.1 -n tracer
```
