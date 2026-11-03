# Helm Upgrade from v1.1.0 to v1.1.1

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.1.0** to **1.1.1**. This is a patch release with no functional changes, template modifications, or configuration updates.

## Table of Contents

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.1.1 is a patch release. There are no changes to:

- Values schema or default values
- Kubernetes resource templates
- Environment variables or configuration
- Dependencies or subcharts

This upgrade is a drop-in replacement for v1.1.0 with no breaking changes, new features, or required configuration updates.

**What changed:**

| File | Change |
|------|--------|
| `Chart.yaml` | Chart version bumped from `1.1.0` to `1.1.1` |
| `README.md` | Chart license line changes from Apache-2.0 to Elastic License 2.0 |

**Migration impact:**

- **No action required** for any deployment scenario
- All existing `values.yaml` configurations remain valid

> **Note:** This release does not modify the application image version (`Chart.appVersion` remains unchanged).

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm --version 1.1.1 -n sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm --version 1.1.1 -n sisbajud
```
