# Helm Upgrade from v3.0.5 to v3.0.6

Version 3.0.6 is a patch release. `appVersion` and the default `bankTransfer.image.tag` stay at `3.5.0`. No values change is required and no step is needed before or after the upgrade.

## What changes

- **Pod labels:** pod templates no longer carry the `helm.sh/chart` label. Selectors do not change. The `bank-transfer` pods restart once during the upgrade.
- **ConfigMap and Secret:** the chart no longer renders the `SYSTEM_FACTS_*` settings (`SYSTEM_FACTS_ENABLED` and the related keys, and the `SYSTEM_FACTS_CLIENT_ID` and `SYSTEM_FACTS_CLIENT_SECRET` pair). No released application image reads them. If your values file sets any of them, they are ignored. You can remove them.
- **`bankTransfer.extraEnvVars`:** the chart no longer rejects the System Facts keys listed above in `bankTransfer.extraEnvVars`.
- **Values:** `valkey.auth.username` is removed from `values.yaml`. No template read it. If your values file sets it, you can remove it.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.6 -n midaz-plugins
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.6 -n midaz-plugins
```

## Verify

```bash
kubectl rollout status deployment -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-bank-transfer
```
