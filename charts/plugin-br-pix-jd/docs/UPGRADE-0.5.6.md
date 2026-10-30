# Helm Upgrade from v0.5.5 to v0.5.6

## Overview

This is a patch version bump with no changes to the chart templates, `values.yaml` keys, or defaults. The only chart source change is the version in `Chart.yaml`. The release also adds documentation (the v0.5.5 upgrade guide and fixes to older upgrade guides) and changelog entries.

The version bump is not invisible to the cluster. Every rendered resource carries the label `helm.sh/chart: plugin-br-pix-jd-helm-<version>`, so the label changes from `0.5.5` to `0.5.6`. This label is also part of the API Deployment pod template, so the upgrade rolls the API pods (and the worker pods, if `worker.enabled` is `true`) even though nothing else changed. The `app.kubernetes.io/version` label stays at `1.3.0`: the app version and all image tags are unchanged.

| Setting | v0.5.5 | v0.5.6 |
|---------|--------|--------|
| Chart Version | 0.5.5 | 0.5.6 |

## What Changed

The upgrade from v0.5.5 to v0.5.6 contains only a chart version bump in `Chart.yaml`, outside documentation and the changelog. There are:

- No changes to `values.yaml`
- No changes to template files
- No changes to default configuration
- No new or removed values, and no breaking changes

Rendering both tags with the repository CI values shows the same resources with the same content, except for the `helm.sh/chart` label on every resource and the `checksum/config` and `checksum/secret` pod annotations, which change because the ConfigMap and Secret now carry the new label.

## Migration Impact

**No values change required.** This upgrade can be applied to existing installations without configuration changes.

> **Note:** Helm updates the labels on the existing resources and replaces the pod template of the API Deployment (and the worker Deployment, if enabled), so the pods roll once. The API Deployment uses `RollingUpdate` with `maxUnavailable: 0`; the worker uses `Recreate`. The migrations Job, a pre-upgrade hook on the default external PostgreSQL path, runs on every upgrade; no image tag changes in this release. Plan the upgrade as you would any rollout.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.6 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.6 -n plugin-br-pix-jd
```
