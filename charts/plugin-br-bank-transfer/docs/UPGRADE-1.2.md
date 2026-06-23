# Helm Upgrade from v1.1.1 to v1.2.0

This is a minor version release with no configuration changes, template modifications, or new features. The upgrade only increments the chart version from 1.1.1 to 1.2.0.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.2.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.2.0 -n plugin-br-bank-transfer
```
