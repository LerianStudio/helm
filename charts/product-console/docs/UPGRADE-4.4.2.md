# Helm Upgrade from v4.4.1 to v4.4.2

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the product-console application from version 2.9.0 to 2.12.0. The chart version increments from 4.4.1 to 4.4.2. No breaking changes or configuration modifications are required.

| Field | v4.4.1 | v4.4.2 |
|-------|--------|--------|
| Chart version | `4.4.1` | `4.4.2` |
| App version | `2.9.0` | `2.12.0` |
| Image tag (default) | `2.9.0` | `2.12.0` |

## Application Version Update

The application has been updated from version 2.9.0 to 2.12.0, spanning three minor releases (2.10.0, 2.11.0, and 2.12.0). This update brings bug fixes, performance improvements, and new features from the upstream product-console application.

**Image tag change:**

| Setting | v4.4.1 | v4.4.2 |
|---------|--------|--------|
| `image.tag` | `"2.9.0"` | `"2.12.0"` |
| `appVersion` | `"2.9.0"` | `"2.12.0"` |

The default image tag is automatically set to match the chart's `appVersion`. If you have explicitly overridden `image.tag` in your values, you may want to update it to use the new version:

```yaml
image:
  tag: "2.12.0"
```

> **Note:** If you have pinned `image.tag` to a specific version in your values file, the upgrade will not automatically change your image version. Review your values to determine if you need to update the tag manually.

## Configuration Changes

No configuration changes are required for this upgrade. All existing values remain compatible with version 4.4.2.

The following settings are unchanged:

- All `configmap` entries
- All `otel` configuration
- All probe configurations
- All resource limits and requests
- All service and ingress settings

## Migration Steps

This upgrade requires no mandatory configuration changes. The Helm upgrade will perform a rolling update of the deployment with the new application version.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify your current image tag setting:

```bash
helm get values product-console -n product-console
```

3. Run the upgrade command during a maintenance window.

4. Monitor the rollout status:

```bash
kubectl rollout status deployment/product-console -n product-console
```

5. Verify all pods are running with the new version:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console
kubectl describe pod -n product-console -l app.kubernetes.io/name=product-console | grep "Image:"
```

6. Check application logs for any startup issues:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

> **Note:** The upgrade triggers a rolling restart of the product-console deployment. Existing connections will be gracefully terminated according to your configured `terminationGracePeriodSeconds`.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.2 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.2 -n product-console
```
