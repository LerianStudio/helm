# Helm Upgrade to v2.0.0

## Topics

- **[Versions](#versions)**
- **[License (breaking)](#license-breaking)**
- **[Image pull secrets](#image-pull-secrets)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Versions

| Setting | Before | v2.0.0 |
|---------|--------|--------|
| Chart version | `1.1.1` | `2.0.0` |
| App version | `1.7.0` | `3.0.0` |

Upgrading from `1.1.1` (app `1.7.0`) crosses the app 2.x line. Read [Requirements of the 2.x line](../README.md#requirements-of-the-2x-line) before upgrading: `STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY` becomes mandatory, hardened staging and production expect a certificate-verifying database connection, and rate limiting needs a Redis/Valkey address to be enforced.

## License (breaking)

App `3.0.0` is license-gated (lib-license-go, global mode). It refuses to boot without a license.

| Key | Where | Value |
|-----|-------|-------|
| `LICENSE_KEY` | `streamingHub.secrets.LICENSE_KEY`, or the Secret named by `streamingHub.existingSecretName` | your Lerian license key |
| `ORGANIZATION_IDS` | ConfigMap (chart default) | must stay exactly `global` |
| `STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY` | `streamingHub.secrets.STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY`, or the Secret named by `streamingHub.existingSecretName` | 32 bytes, base64 |

With `streamingHub.useExistingSecret: true`, the existing Secret must carry `LICENSE_KEY` (and the HMAC key) before the upgrade, or the pods fail with `CreateContainerConfigError`. Never commit the key to a values file in git.

## Image pull secrets

The images are public. `streamingHub.imagePullSecrets` now defaults to `[]`; remove any registry credential you only kept to pull them.

## Command to upgrade

```bash
helm upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm \
  --version 2.0.0 -n <namespace> -f <your-values>.yaml
```
