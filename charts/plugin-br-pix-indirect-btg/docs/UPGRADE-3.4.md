# Helm Upgrade from v3.3.1 to v3.4.0

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that updates the application version from `1.7.5` to `1.7.6` across all four service components in the `plugin-br-pix-indirect-btg` chart: `pix`, `inbound`, `outbound`, and `reconciliation`. No configuration values are added, removed, or renamed, so existing custom values files remain fully compatible.

The expected upgrade path is a standard in-place Helm upgrade. The new application version will trigger a rolling restart of all four deployments.

## Application Version Update

All four service components now use application version `1.7.6`. The container image tags have been updated accordingly.

| Component | v3.3.1 Image Tag | v3.4.0 Image Tag |
|-----------|------------------|------------------|
| `pix` | `1.7.5` | `1.7.6` |
| `inbound` | `1.7.5` | `1.7.6` |
| `outbound` | `1.7.5` | `1.7.6` |
| `reconciliation` | `1.7.5` | `1.7.6` |

**What changed:**

The `image.tag` field for each service component has been updated to reference the new application version:

```yaml
pix:
  image:
    tag: "1.7.6"

inbound:
  image:
    tag: "1.7.6"

outbound:
  image:
    tag: "1.7.6"

reconciliation:
  image:
    tag: "1.7.6"
```

**Why it matters:**

This update delivers bug fixes, performance improvements, or new features included in application version `1.7.6`. Consult the application release notes for `1.7.6` to understand the specific changes in the service binaries.

**Operational impact:**

The upgrade will trigger a rolling restart of all four deployments (`pix`, `inbound`, `outbound`, `reconciliation`). Depending on your replica count and pod disruption budgets, you may experience brief service interruptions during the rollout. Ensure your readiness and liveness probes are properly configured to minimize downtime.

> **Note:** If you have pinned image tags in your custom values file, your overrides will take precedence. Review your custom values to ensure you want to adopt the new `1.7.6` image tags.

## Configuration Changes

No configuration values were added, removed, or renamed in this release. The only changes are the image tag updates for each service component.

| Setting | v3.3.1 | v3.4.0 |
|---------|--------|--------|
| Chart version | `3.3.1` | `3.4.0` |
| App version | `1.7.5` | `1.7.6` |
| `pix.image.tag` | `"1.7.5"` | `"1.7.6"` |
| `inbound.image.tag` | `"1.7.5"` | `"1.7.6"` |
| `outbound.image.tag` | `"1.7.5"` | `"1.7.6"` |
| `reconciliation.image.tag` | `"1.7.5"` | `"1.7.6"` |

All other configuration fields remain unchanged. Your existing custom values files are fully compatible with this release.

## Migration Steps

This upgrade requires no manual migration steps or configuration changes. The new image tags will be applied automatically during the Helm upgrade.

**Recommended upgrade process:**

1. Review the application release notes for version `1.7.6` to understand what changed in the service binaries.

2. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

3. Schedule the upgrade during a maintenance window if you have low replica counts or strict availability requirements.

4. Run the upgrade command.

5. Monitor the rollout to ensure all pods are updated successfully:

```bash
kubectl rollout status deployment/plugin-br-pix-indirect-btg-pix -n plugin-br-pix-indirect-btg
kubectl rollout status deployment/plugin-br-pix-indirect-btg-inbound -n plugin-br-pix-indirect-btg
kubectl rollout status deployment/plugin-br-pix-indirect-btg-outbound -n plugin-br-pix-indirect-btg
kubectl rollout status deployment/plugin-br-pix-indirect-btg-reconciliation -n plugin-br-pix-indirect-btg
```

6. Verify all pods are running and healthy:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg
```

7. Check service logs for any startup errors or warnings:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
```

> **Note:** The rolling restart behavior is controlled by your deployment strategy settings. If you have customized `strategy.type` or `strategy.rollingUpdate` for any component, those settings will continue to apply during the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.4.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.4.0 -n plugin-br-pix-indirect-btg
```
