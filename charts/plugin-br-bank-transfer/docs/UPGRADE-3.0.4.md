# Helm Upgrade from v3.0.3 to v3.0.4

Version 3.0.4 changes no values, templates or images. `appVersion` and the default `bankTransfer.image.tag` stay at `3.4.0`. The chart is now licensed under Elastic License 2.0 (previously Apache-2.0). No values change is required.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.4 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.4 -n plugin-br-bank-transfer
```
