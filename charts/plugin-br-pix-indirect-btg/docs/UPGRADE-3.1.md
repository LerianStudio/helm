# Helm Upgrade from v3.0.1 to v3.1.0

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that updates the application version from `1.6.0` to `1.7.3` across all four service components in the `plugin-br-pix-indirect-btg` chart: `pix`, `inbound`, `outbound`, and `reconciliation`. No configuration values are added, removed, or renamed, so existing custom values files remain fully compatible.

The expected upgrade path is an in-place Helm upgrade that will trigger a rolling restart of all four deployments to pull the new application images.

## Application Version Update

All four service components now use application version `1.7.3`, which includes bug fixes, performance improvements, and feature enhancements from the upstream application releases between `1.6.0` and `1.7.3`.

| Component | v3.0.1 Image Tag | v3.1.0 Image Tag |
|-----------|------------------|------------------|
| `pix` | `1.6.0` | `1.7.3` |
| `inbound` | `1.6.0` | `1.7.3` |
| `outbound` | `1.6.0` | `1.7.3` |
| `reconciliation` | `1.6.0` | `1.7.3` |

**What changed:**

The `image.tag` field for each service component has been updated in `values.yaml`:

```yaml
pix:
  image:
    tag: "1.7.3"

inbound:
  image:
    tag: "1.7.3"

outbound:
  image:
    tag: "1.7.3"

reconciliation:
  image:
    tag: "1.7.3"
```

**Why it matters:**

The new application version brings the chart in sync with the latest stable release of the plugin-br-pix-indirect-btg application. Operators should review the application's release notes for versions `1.6.1` through `1.7.3` to understand the functional changes, bug fixes, and any new features available in the updated services.

**Operational impact:**

- The upgrade will trigger a rolling restart of all four deployments (`pix`, `inbound`, `outbound`, `reconciliation`)
- Each pod will pull the new `1.7.3` image before becoming ready
- Depending on your replica count, `maxUnavailable`, and readiness probe timing, expect brief traffic shifts during the rolling update
- If you have `imagePullPolicy: Always` (the default), ensure your cluster can reach the image registry during the upgrade window

> **Important:** If you have pinned a specific image tag in your custom values file (e.g., `pix.image.tag: "1.6.0"`), your override will take precedence and prevent the upgrade to `1.7.3`. Review your custom values and remove any image tag overrides unless you have a specific reason to stay on an older version.

## Configuration Changes

No configuration values were added, removed, or renamed in this release. The only changes are the image tag updates shown in the table above.

| Setting | v3.0.1 | v3.1.0 |
|---------|--------|--------|
| Chart version | `3.0.1` | `3.1.0` |
| App version | `1.6.0` | `1.7.3` |
| `pix.image.tag` | `"1.6.0"` | `"1.7.3"` |
| `inbound.image.tag` | `"1.6.0"` | `"1.7.3"` |
| `outbound.image.tag` | `"1.6.0"` | `"1.7.3"` |
| `reconciliation.image.tag` | `"1.6.0"` | `"1.7.3"` |

All other values remain unchanged. Your existing custom values files will continue to work without modification.

## Migration Steps

This upgrade requires no manual migration steps or configuration changes. The new application version is backward-compatible with the existing chart configuration.

**Recommended upgrade process:**

1. Review the application release notes for versions `1.6.1` through `1.7.3` to understand the functional changes in the new images.

2. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

3. Verify that your custom values file does not pin image tags that would prevent the upgrade:

```bash
grep -E "tag:|image:" your-custom-values.yaml
```

4. Schedule the upgrade during a maintenance window if you have low replica counts or strict availability requirements.

5. Run the upgrade command (see [Command to upgrade](#command-to-upgrade)).

6. Monitor the rolling update progress:

```bash
kubectl rollout status deployment/plugin-br-pix-indirect-btg-pix -n plugin-br-pix-indirect-btg
kubectl rollout status deployment/plugin-br-pix-indirect-btg-inbound -n plugin-br-pix-indirect-btg
kubectl rollout status deployment/plugin-br-pix-indirect-btg-outbound -n plugin-br-pix-indirect-btg
kubectl rollout status deployment/plugin-br-pix-indirect-btg-reconciliation -n plugin-br-pix-indirect-btg
```

7. Verify all pods are running the new image version:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

8. Check service logs for any startup errors or warnings:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
```

> **Note:** If you encounter issues during the upgrade, you can roll back to the previous chart version using: `helm rollback plugin-br-pix-indirect-btg -n plugin-br-pix-indirect-btg`

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.1.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.1.0 -n plugin-br-pix-indirect-btg
```
