# Helm Upgrade from v1.1.2 to v1.1.3

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `1.1.2` to `1.1.3`. The application version remains `1.0.0-beta.9`; the chart bump to `1.1.3` is a patch release that contains no functional changes, configuration updates, or template modifications.

This upgrade requires no operator action beyond running the upgrade command. Existing deployments will continue to work without values changes. No configuration values were added, removed, or modified. No template files were changed.

> **Note:** This is a metadata-only release. The chart version was incremented without any changes to values, templates, or application behavior. Operators may skip this upgrade if they are satisfied with v1.1.2.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.3 -n plugin-br-payments
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.3 -n plugin-br-payments
```
