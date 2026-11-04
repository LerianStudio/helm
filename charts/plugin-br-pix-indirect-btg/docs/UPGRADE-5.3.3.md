<!-- {% raw %} -->
# Helm Upgrade from v5.3.2 to v5.3.3

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release. The application version stays at `1.14.0`. No values are added, removed or renamed, and no operator action is needed before or after the upgrade.

| Component | v5.3.2 | v5.3.3 |
|-----------|--------|--------|
| Chart version | `5.3.2` | `5.3.3` |
| App version | `1.14.0` | `1.14.0` |

## Changes

The pod templates of the `pix`, `inbound`, `outbound`, `reconciliation` and `schedule` Deployments no longer carry the `helm.sh/chart` label. The other labels on the pod templates are unchanged, and the Deployment selectors are unchanged.

Because the pod templates change, each of the five Deployments rolls out once during this upgrade and its pods restart once. The chart's other resources keep the `helm.sh/chart` label.

## Configuration Changes

None. Existing custom values files work without edits.

## Migration Steps

1. Review the changes with helm-diff (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command.
3. Verify that the five Deployments finish their rollout and the pods are ready:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg
```

> **Note:** With more than one replica per component, the rolling update keeps the service available. With a single replica, expect a short interruption while the new pod becomes ready.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.3 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.3 -n plugin-br-pix-indirect-btg
```
<!-- {% endraw %} -->
