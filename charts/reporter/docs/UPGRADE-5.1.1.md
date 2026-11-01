# Helm Upgrade from v5.1.0 to v5.1.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release with no functional changes. The chart version has been incremented from `5.1.0` to `5.1.1` with no modifications to templates, values, or application version.

| Field | v5.1.0 | v5.1.1 |
|-------|--------|--------|
| Chart version | `5.1.0` | `5.1.1` |
| App version | `4.6.0` | `4.6.0` |

No configuration changes, template updates, or migration steps are required. The upgrade will not trigger any pod restarts or resource modifications.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.1.1 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.1.1 -n reporter
```
