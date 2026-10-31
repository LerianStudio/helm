# Helm Upgrade from v4.4.0 to v4.4.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `2.8.0` to `2.9.0`. No configuration changes, breaking changes, or template modifications are included. The upgrade only updates the container image tag.

| Field | v4.4.0 | v4.4.1 |
|-------|--------|--------|
| Chart version | `4.4.0` | `4.4.1` |
| App version | `2.8.0` | `2.9.0` |
| Image tag | `2.8.0` | `2.9.0` |

## Application Version Update

The default container image tag has been updated to match the new application version. If you are using the default `image.tag` value, the upgrade will automatically pull and deploy version `2.9.0` of the product-console application.

| Setting | v4.4.0 | v4.4.1 |
|---------|--------|--------|
| `image.tag` | `"2.8.0"` | `"2.9.0"` |

**Impact:**

- The upgrade triggers a rolling restart of the `product-console` deployment with the new image version
- If you have explicitly set `image.tag` in your `values.yaml` or via `--set`, your override will continue to be used and the default change will not affect your deployment
- No configuration changes are required unless you want to adopt the new default version

**To verify your current image tag override:**

```bash
helm get values product-console -n product-console
```

**To explicitly set the new version:**

```yaml
image:
  tag: "2.9.0"
```

> **Note:** Review the product-console application release notes for version 2.9.0 to understand application-level changes, bug fixes, or new features included in this image.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.1 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.1 -n product-console
```
