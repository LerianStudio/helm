# Helm Upgrade from v4.4.5 to v4.4.6

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `2.16.2` to `2.16.4`. No configuration changes, breaking changes, or new features are introduced at the chart level.

| Field | v4.4.5 | v4.4.6 |
|-------|--------|--------|
| Chart version | `4.4.5` | `4.4.6` |
| App version | `2.16.2` | `2.16.4` |
| Image tag | `2.16.2` | `2.16.4` |

## Application Version Update

The chart now deploys application version `2.16.4` instead of `2.16.2`. This is a patch-level application update that includes bug fixes or minor improvements in the product-console application itself.

| Setting | v4.4.5 | v4.4.6 |
|---------|--------|--------|
| `appVersion` | `2.16.2` | `2.16.4` |
| `image.tag` | `2.16.2` | `2.16.4` |

**Impact:**

- The upgrade will trigger a rolling restart of the `product-console` deployment with the new image tag
- No changes to Helm values, environment variables, or Kubernetes resources are required
- Existing configuration and customizations remain compatible

> **Note:** Review the product-console application release notes for version `2.16.4` to understand what application-level fixes or improvements are included in this update.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.6 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.6 -n product-console
```
