# Helm Upgrade from v1.0.2 to v1.0.3

This is a patch release with no functional changes: templates, values and the default image tag (appVersion 1.0.0) are unchanged. The chart is now licensed under the Elastic License 2.0 (previously Apache-2.0).

The manager and worker pods still restart on upgrade: `checksum/config` hashes the shared ConfigMap, whose chart-version label changes on upgrade. The `checksum/secret` annotation hashes the chart-managed shared Secret only when `common.useExistingSecret` is false; it is omitted when that setting is true because the Secret is operator-managed.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version 1.0.3 -n br-sta
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version 1.0.3 -n br-sta
```
