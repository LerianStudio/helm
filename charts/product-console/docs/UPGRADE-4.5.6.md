<!-- {% raw %} -->
# Helm Upgrade from v4.5.5 to v4.5.6

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `3.5.0` to `3.6.0`. The chart includes a minor formatting change to the MongoDB configuration but no functional configuration changes are required.

| Field | v4.5.5 | v4.5.6 |
|-------|--------|--------|
| Chart version | `4.5.5` | `4.5.6` |
| App version | `3.5.0` | `3.6.0` |
| Image tag (default) | `3.5.0` | `3.6.0` |

## Application Version Update

The default container image tag has been updated to match the new application version.

| Setting | v4.5.5 | v4.5.6 |
|---------|--------|--------|
| `image.tag` | `"3.5.0"` | `"3.6.0"` |
| `appVersion` | `"3.5.0"` | `"3.6.0"` |

**What changed:**

The chart now deploys `product-console:3.6.0` by default. If you have explicitly set `image.tag` in your values override file, you may want to update it to `3.6.0` or remove the override to use the chart default.

**Example override (if you want to pin the version explicitly):**

```yaml
image:
  tag: "3.6.0"
```

> **Note:** The upgrade triggers a rolling restart of the `product-console` deployment. Ensure the `3.6.0` application image is available in your configured registry before upgrading.

**MongoDB configuration formatting:**

A cosmetic formatting change was applied to the `mongodb.auth.existingSecret` field. The YAML string was reformatted across multiple lines for readability, but the rendered template output remains identical. No action is required.

**Before (v4.5.5):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

**After (v4.5.6):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname"
      . }}{{ end }}'
```

This change has no operational impact and does not affect the MongoDB secret configuration.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.6
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.6
```
<!-- {% endraw %} -->
