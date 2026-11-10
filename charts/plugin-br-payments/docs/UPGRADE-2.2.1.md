# Helm Upgrade from v2.2.0 to v2.2.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.2.0` to `2.2.1`. This is a patch release that updates the application version from `1.2.0-beta.1` to `1.2.0`, marking the transition from beta to stable release. The chart itself contains no template, values, or configuration changes.

No operator action is required beyond the upgrade command. The image tag follows `appVersion` unless `app.image.tag` is set in your values overlay. If you pinned `app.image.tag: "1.2.0-beta.1"`, change it to `"1.2.0"` to run the stable release.

## Application Version Update

The `appVersion` field in `Chart.yaml` has been updated from `1.2.0-beta.1` to `1.2.0`, indicating that the application has graduated from beta to stable release.

| Setting | v2.2.0 | v2.2.1 |
|---------|--------|--------|
| `appVersion` | `1.2.0-beta.1` | `1.2.0` |

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --version 2.2.1 -n plugin-br-payments -f <your-values>.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --version 2.2.1 -n plugin-br-payments -f <your-values>.yaml
```
