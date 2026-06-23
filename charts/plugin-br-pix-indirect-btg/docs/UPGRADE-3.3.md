# Helm Upgrade from v3.2.0 to v3.3.0

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that updates the application version from `1.7.3` to `1.7.4` across all four service components in the `plugin-br-pix-indirect-btg` chart. No configuration values are added, removed, or renamed, making this a straightforward upgrade that requires no changes to existing custom values files.

The expected upgrade path is an in-place Helm upgrade with no manual migration steps.

## Application Version Update

All four service components have been updated to use application version `1.7.4`:

| Component | v3.2.0 Image Tag | v3.3.0 Image Tag |
|-----------|------------------|------------------|
| `pix` | `1.7.3` | `1.7.4` |
| `inbound` | `1.7.3` | `1.7.4` |
| `outbound` | `1.7.3` | `1.7.4` |
| `reconciliation` | `1.7.3` | `1.7.4` |

**What changed:**

The image tag for each service component has been updated in the default values:

```yaml
pix:
  image:
    tag: "1.7.4"

inbound:
  image:
    tag: "1.7.4"

outbound:
  image:
    tag: "1.7.4"

reconciliation:
  image:
    tag: "1.7.4"
```

**Why it matters:**

This update delivers bug fixes, performance improvements, or new features included in application version `1.7.4`. The upgrade will trigger a rolling restart of all four service deployments to pull and run the new image version.

**Operational impact:**

- All four deployments (`pix`, `inbound`, `outbound`, `reconciliation`) will perform a rolling update
- Depending on your replica count and `maxUnavailable` settings, you may experience brief service interruptions during the pod replacement
- The new pods will pull the `1.7.4` image from the configured registry

> **Note:** If you have pinned a specific image tag in your custom values file, your override will take precedence and the upgrade will not change your image version. Review your custom values to ensure you want to adopt the new `1.7.4` version.

## Configuration Changes

No configuration values were added, removed, or renamed in this release. The only change is the default image tag for each service component.

| Setting | v3.2.0 | v3.3.0 |
|---------|--------|--------|
| Chart version | `3.2.0` | `3.3.0` |
| App version | `1.7.3` | `1.7.4` |
| `pix.image.tag` | `"1.7.3"` | `"1.7.4"` |
| `inbound.image.tag` | `"1.7.3"` | `"1.7.4"` |
| `outbound.image.tag` | `"1.7.3"` | `"1.7.4"` |
| `reconciliation.image.tag` | `"1.7.3"` | `"1.7.4"` |

Additionally, a trailing blank line was removed from the end of `values.yaml` and a no-op comment was updated. These are cosmetic changes with no operational impact.

## Migration Steps

This upgrade requires no manual migration steps. Your existing custom values files will continue to work without modification.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify that the new `1.7.4` application image is available in your container registry.

3. Run the upgrade command during a maintenance window to minimize impact from the rolling restart.

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg
```

5. Check service logs to confirm the new version is running correctly:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
```

6. Monitor application metrics and health endpoints to ensure the new version is functioning as expected.

> **Note:** If you need to roll back, use the previous chart version with `helm rollback plugin-br-pix-indirect-btg` or explicitly upgrade to version `3.2.0`.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.3.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.3.0 -n plugin-br-pix-indirect-btg
```
