# Helm Upgrade from v1.0.0 to v1.0.1

This is a patch release with no functional changes. The upgrade only increments the chart version number.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://registry-1.docker.io/lerianstudio/br-sta-helm --version 1.0.1 -n br-sta
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://registry-1.docker.io/lerianstudio/br-sta-helm --version 1.0.1 -n br-sta
```
