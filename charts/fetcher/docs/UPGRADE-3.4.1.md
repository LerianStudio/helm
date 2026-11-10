# Helm Upgrade from v3.4.0 to v3.4.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.4.0` to `3.4.1`. This is a **patch** release that contains only a version bump with no functional changes, configuration modifications, or template updates.

The application version (`appVersion: 3.1.0`) remains unchanged. No breaking changes, no required `values.yaml` modifications, and no data migration are needed.

| Setting | v3.4.0 | v3.4.1 |
|---------|--------|--------|
| Chart version | `3.4.0` | `3.4.1` |
| Application version | `3.1.0` | `3.1.0` (unchanged) |

> **Note:** This release contains no changes to values, templates, or application behavior. The upgrade can be performed without any preparation or configuration changes.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.1 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.1 -n fetcher
```
