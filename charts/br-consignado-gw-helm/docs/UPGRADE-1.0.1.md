# Helm Upgrade from v1.0.0 to v1.0.1

## Topics

- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

This patch release updates the application version bundled with the chart.

| Setting | v1.0.0 | v1.0.1 |
|---------|---------|---------|
| `appVersion` | 1.3.0-beta.33 | 1.3.0-beta.36 |

The application has been updated from beta.33 to beta.36, which includes three incremental beta releases. This update brings bug fixes and improvements to the br-consignado-gw application itself.

> **Note:** No changes were made to chart templates, values.yaml defaults, or configuration structure. This is a straightforward application version bump.

### What this means for operators

- The container image tag will be updated to `1.3.0-beta.36` (unless you have explicitly overridden `image.tag` in your values)
- Existing configurations and customizations remain fully compatible
- No manual intervention or configuration changes are required

### Rollout behavior

When you upgrade, Kubernetes will perform a rolling update of your pods with the new application version according to your deployment strategy settings.

## Preview changes before upgrading

```bash
helm diff upgrade br-consignado-gw-helm oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm-helm --version 1.0.1 -n br-consignado-gw-helm
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-consignado-gw-helm oci://registry-1.docker.io/lerianstudio/br-consignado-gw-helm-helm --version 1.0.1 -n br-consignado-gw-helm
```
