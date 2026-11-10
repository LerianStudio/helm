# Helm Upgrade from v0.5.0 to v0.5.1

## Overview

This is a patch version bump with no functional changes to the chart templates, values, or configuration. The version increment updates the chart metadata only.

| Setting | v0.5.0 | v0.5.1 |
|---------|--------|--------|
| Chart Version | 0.5.0 | 0.5.1 |

## What Changed

The upgrade from v0.5.0 to v0.5.1 contains only a chart version bump in `Chart.yaml`. There are:

- No changes to `values.yaml`
- No changes to template files
- No changes to default configuration
- No new features or deprecations
- No breaking changes

This release maintains full compatibility with existing v0.5.0 deployments.

## Migration Impact

**No action required.** This upgrade can be applied directly to existing installations without configuration changes or manual intervention.

> **Note:** Since no templates or values have changed, the upgrade will not modify any deployed Kubernetes resources unless you are also changing values during the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.1 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.1 -n plugin-br-pix-jd
```
