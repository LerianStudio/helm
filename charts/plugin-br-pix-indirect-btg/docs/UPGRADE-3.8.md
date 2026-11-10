# Helm Upgrade from v3.7.0 to v3.8.0

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that updates the application version from `1.9.0` to `1.9.1` for the `pix` component. The chart version increments from `3.7.0` to `3.8.0`. No configuration values are added, removed, or renamed, and no template changes are included in this release.

The expected upgrade path is a straightforward in-place Helm upgrade with no migration steps required.

## Application Version Update

The `pix` component image tag has been updated to align with the new application version.

| Component | v3.7.0 | v3.8.0 |
|-----------|--------|--------|
| Chart version | `3.7.0` | `3.8.0` |
| App version | `1.9.0` | `1.9.1` |
| `pix.image.tag` | `1.9.0` | `1.9.1` |

**What changed:**

The `pix` service will now pull and run the `1.9.1` application image instead of `1.9.0`. This is a patch-level application update that typically includes bug fixes or minor improvements.

**Why it matters:**

The upgrade will trigger a rolling restart of the `pix` deployment to pull and deploy the new image version. Depending on your replica count and rolling update strategy, this may cause brief service interruptions during the pod replacement cycle.

**Operational impact:**

- The `pix` pods will be recreated with the new image tag
- Existing custom values for `pix.image.tag` will be overridden unless explicitly set during upgrade
- No changes to other components (`inbound`, `outbound`, `reconciliation`) — they remain at their current versions

**Example configuration (v3.8.0):**

```yaml
pix:
  image:
    repository: lerianstudio/pix
    pullPolicy: Always
    tag: "1.9.1"
```

> **Note:** If you have pinned `pix.image.tag` to `1.9.0` in your custom values file, you should either remove that override to adopt the chart default or explicitly update it to `1.9.1`.

## Configuration Changes

No configuration values were added, removed, or renamed in this release. The only change is the default value for `pix.image.tag`.

| Setting | v3.7.0 | v3.8.0 |
|---------|--------|--------|
| `pix.image.tag` | `"1.9.0"` | `"1.9.1"` |

All existing custom values will continue to work without modification.

## Migration Steps

This upgrade requires no migration steps. The application version update is backward-compatible and does not introduce breaking changes.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command during a maintenance window to minimize impact from the rolling restart.

3. Verify all `pix` pods are running with the new image version:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=pix -o jsonpath='{.items[*].spec.containers[*].image}'
```

4. Check that all pods are healthy and ready:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg
```

5. Monitor service logs for any unexpected behavior after the upgrade:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=pix --tail=50
```

> **Note:** The upgrade will only affect the `pix` deployment. The `inbound`, `outbound`, and `reconciliation` components will not be restarted unless their configuration has changed in your custom values.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.8.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.8.0 -n plugin-br-pix-indirect-btg
```
