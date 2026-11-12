# Helm Upgrade from v1.5.0 to v1.5.1

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.5.0** to **1.5.1**. This is a patch release that updates the application version from a release candidate to a stable release.

## Table of Contents

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.5.1 is a patch release that promotes the application from a release candidate to a stable version. There are no changes to:

- Values schema or default values
- Kubernetes resource templates
- Environment variables or configuration
- Dependencies or subcharts

This upgrade is a drop-in replacement for v1.5.0 with no breaking changes, new features, or required configuration updates.

**What changed:**

| File | Change |
|------|--------|
| `Chart.yaml` | Chart version bumped from `1.5.0` to `1.5.1` |
| `Chart.yaml` | Application version updated from `1.3.0-rc.1` to `1.3.0` |

**Migration impact:**

- **No action required** for any deployment scenario
- All existing `values.yaml` configurations remain valid
- The application container image will be updated to the stable `1.3.0` release

## Application Version Update

The default application version (`Chart.appVersion`) has been updated to promote from release candidate to stable release.

| Setting | v1.5.0 | v1.5.1 |
|---------|--------|--------|
| `Chart.appVersion` | `1.3.0-rc.1` | `1.3.0` |

**What this means:**

- If you are using the default image tag (not overriding `sisbajud.image.tag`), the executor pod will be updated to use the `1.3.0` image
- The `1.3.0` image is the stable release of the `1.3.0-rc.1` release candidate with no functional changes
- If you have explicitly set `sisbajud.image.tag` in your values, that override will continue to take precedence

**Default behavior:**

```yaml
sisbajud:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-sisbajud
    tag: ""  # Defaults to Chart.appVersion (1.3.0 in v1.5.1)
    pullPolicy: IfNotPresent
```

**To keep using the release candidate (not recommended):**

```yaml
sisbajud:
  image:
    tag: "1.3.0-rc.1"
```

> **Note:** The stable `1.3.0` release is recommended for all deployments. The release candidate should only be used for testing purposes.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.5.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.5.1
```
