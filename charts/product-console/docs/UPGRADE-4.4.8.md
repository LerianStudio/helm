# Helm Upgrade from v4.4.7 to v4.4.8

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that increments the chart version with no changes to templates, values, or application version. No configuration changes or operator action is required.

| Field | v4.4.7 | v4.4.8 |
|-------|--------|--------|
| Chart version | `4.4.7` | `4.4.8` |
| App version | `3.0.0` | `3.0.0` |

The upgrade is safe to apply without a maintenance window. No pod restarts or configuration drift will occur.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.8 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.8 -n product-console
```
