# Helm Upgrade from v4.4.5 to v4.4.6

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This release moves the default product-console application version from `2.16.2` to `2.16.4`. The chart changes only `appVersion` and the default `image.tag`. No chart values or templates change.

| Field | v4.4.5 | v4.4.6 |
|-------|--------|--------|
| Chart version | `4.4.5` | `4.4.6` |
| App version | `2.16.2` | `2.16.4` |
| Image tag | `2.16.2` | `2.16.4` |

## Application Version Update

The chart now deploys application version `2.16.4` by default instead of `2.16.2`. The image repository stays `lerianstudio/product-console`.

| Setting | v4.4.5 | v4.4.6 |
|---------|--------|--------|
| `appVersion` | `2.16.2` | `2.16.4` |
| `image.tag` | `2.16.2` | `2.16.4` |

**Impact:**

- The upgrade triggers a rolling restart of the `product-console` deployment with the new image tag
- If you pinned `image.tag` in your values, the pin takes precedence and the image does not change. The pods still roll once, because the chart version is part of the `helm.sh/chart` label in the pod template
- No changes to Helm values or environment variables are required

> **Note:** The chart does not describe application-level changes. Read the product-console application release notes for versions `2.16.3` and `2.16.4`.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.6 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.6 -n product-console
```
