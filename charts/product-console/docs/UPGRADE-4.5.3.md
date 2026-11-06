# Helm Upgrade from v4.5.2 to v4.5.3

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `3.0.0` to `3.2.0`. No Helm chart configuration changes are required.

| Field | v4.5.2 | v4.5.3 |
|-------|--------|--------|
| Chart version | `4.5.2` | `4.5.3` |
| App version | `3.0.0` | `3.2.0` |
| Default image tag | `3.0.0` | `3.2.0` |

## Application Version Update

The chart now deploys application version `3.2.0` by default. The image tag in `values.yaml` has been updated accordingly.

| Setting | v4.5.2 | v4.5.3 |
|---------|--------|--------|
| `appVersion` | `3.0.0` | `3.2.0` |
| `image.tag` | `3.0.0` | `3.2.0` |

**What changed:**

The default container image tag has been bumped from `3.0.0` to `3.2.0`. If you have not explicitly overridden `image.tag` in your `values.yaml`, the upgrade will automatically pull and deploy the new application version.

**If you have pinned the image tag:**

If your `values.yaml` explicitly sets `image.tag`, you must update it to `3.2.0` to receive the application updates:

```yaml
image:
  tag: "3.2.0"
```

> **Note:** If you are using a custom image repository or tag strategy, ensure the `3.2.0` image is available in your registry before upgrading.

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will trigger a rolling restart of the deployment with the new application version.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Verify that the `3.2.0` application image is available in your container registry.
3. Run the upgrade command during a maintenance window.
4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n product-console
```

5. Check service logs for any startup issues:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

> **Important:** The upgrade triggers a rolling restart of the `product-console` deployment. Ensure you have appropriate pod disruption budgets and replica counts configured for zero-downtime upgrades.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.3
```
