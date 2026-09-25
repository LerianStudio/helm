# Helm Upgrade from v3.2.0 to v3.3.0

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that increments the chart version from 3.2.0 to 3.3.0. The application version remains unchanged at `1.10.0`.

| Field | v3.2.0 | v3.3.0 |
|-------|--------|--------|
| Chart version | `3.2.0` | `3.3.0` |
| App version | `1.10.0` | `1.10.0` |

**Summary:**

No configuration changes, template modifications, or value updates are included in this release. The chart version bump is administrative only. Existing installations can upgrade without any values changes or migration steps.

**Impact:**

- No breaking changes
- No new features or configuration options
- No deployment restart required (unless forced by Helm)
- No values.yaml modifications needed

This upgrade is safe to apply in production without a maintenance window. All existing configurations remain valid.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 3.3.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 3.3.0 -n product-console
```
