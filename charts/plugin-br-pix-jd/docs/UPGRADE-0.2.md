# Helm Upgrade from v0.1.0 to v0.2.0

This guide covers the upgrade of the `plugin-br-pix-jd` Helm chart from version 0.1.0 to 0.2.0.

## Overview

This is a minor version bump with no functional changes to the chart templates, values, or configuration. The version increment updates the chart metadata only.

| Setting | v0.1.0 | v0.2.0 |
|---------|--------|--------|
| Chart Version | 0.1.0 | 0.2.0 |

## What Changed

The upgrade from v0.1.0 to v0.2.0 contains only a chart version bump in `Chart.yaml`. There are:

- No changes to `values.yaml`
- No changes to template files
- No changes to default configuration
- No new features or deprecations
- No breaking changes

This release maintains full compatibility with existing v0.1.0 deployments.

## Migration Impact

**No action required.** This upgrade can be applied directly to existing installations without configuration changes or manual intervention.

> **Note:** Since no templates or values have changed, the upgrade will not modify any deployed Kubernetes resources unless you are also changing values during the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.2.0 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.2.0 -n plugin-br-pix-jd
```
