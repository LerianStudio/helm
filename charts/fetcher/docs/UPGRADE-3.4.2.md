# Helm Upgrade from v3.4.1 to v3.4.2

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.4.1` to `3.4.2`. This is a **patch** release that contains only a version bump with no functional changes.

The application version (`appVersion: 3.1.0`) remains unchanged. There are no breaking changes, no configuration modifications, no template updates, and no migration steps required. This is a maintenance release that updates the chart version metadata only.

> **Note:** This upgrade is safe to apply without any preparation or configuration changes. All existing `values.yaml` configurations remain fully compatible.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.2 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.2 -n fetcher
```
