# Helm Upgrade from v4.5.1 to v4.5.2

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Overview

This is a patch release. No configuration changes or operator action is required before or after the upgrade. Your values files work unchanged.

| Field | v4.5.1 | v4.5.2 |
|-------|--------|--------|
| Chart version | `4.5.1` | `4.5.2` |
| App version | `3.0.0` | `3.0.0` |

The Deployment's pods restart once on this upgrade, because the pod template labels change. The selectors do not change, so the Deployment is updated in place with a normal rolling update.

## Changes

1. **Pod template labels.** The pod template no longer carries the `helm.sh/chart` label. Later chart releases no longer restart the pods only because the chart version changed.
2. **Checksum annotations.** `checksum/config` and `checksum/secret` now hash only the `data` of the rendered ConfigMap and Secret. The pods restart when the configuration or the secrets change, and not when other metadata of those objects changes.
3. **Chart metadata.** The `sources` list in `Chart.yaml` no longer lists a repository that is not publicly reachable.

## Preview changes before upgrading

The release name and namespace below are examples. Replace them with the values you used at install time.

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.5.2 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.5.2 -n product-console
```

## Verify

```bash
kubectl rollout status deployment/product-console -n product-console
kubectl get pods -n product-console -l app.kubernetes.io/instance=product-console
```
