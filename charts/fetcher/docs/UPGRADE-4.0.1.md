# Helm Upgrade from v4.0.0 to v4.0.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `4.0.0` to `4.0.1`. This is a **patch** release with no functional changes, no template modifications, and no values schema updates.

The application version (`appVersion: 3.1.1`) is unchanged. The chart version was bumped from `4.0.0` to `4.0.1` in `Chart.yaml`, but no other files were modified.

**No action is required from operators.** This upgrade is safe to apply without configuration changes, migration steps, or testing beyond standard deployment verification.

| Aspect | Status |
|--------|--------|
| Breaking changes | None |
| New features | None |
| Configuration changes | None |
| Template changes | None |
| Migration required | No |

> **Note:** This release contains only a version bump in `Chart.yaml`. All templates, values, and application behavior remain identical to v4.0.0.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.0.1 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.0.1 -n fetcher
```
