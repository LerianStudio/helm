# Helm Upgrade from v4.0.1 to v4.0.2

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `1.10.0` to `1.12.0`. No configuration changes, breaking changes, or template modifications are included in this release.

| Field | v4.0.1 | v4.0.2 |
|-------|--------|--------|
| Chart version | `4.0.1` | `4.0.2` |
| App version | `1.10.0` | `1.12.0` |
| Image tag (default) | `1.10.0` | `1.12.0` |

## Application Version Update

The default container image tag has been updated to match the new application version. This change affects the `image.tag` value in `values.yaml`.

| Setting | v4.0.1 | v4.0.2 |
|---------|--------|--------|
| `image.tag` | `"1.10.0"` | `"1.12.0"` |

**Impact:**

- The upgrade will trigger a rolling restart of the `product-console` deployment with the new image version
- If you have explicitly set `image.tag` in your values override file, your custom tag will be preserved and the default change will not affect your deployment
- No configuration changes are required; the new image version is backward-compatible with existing configurations

> **Note:** This upgrade only changes the application image version. All Helm chart templates, configuration options, and default values remain unchanged from v4.0.1.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.2 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.2 -n product-console
```
