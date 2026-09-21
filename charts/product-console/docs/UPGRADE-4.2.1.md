# Helm Upgrade from v4.2.0 to v4.2.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `1.12.0` to `2.0.0`. No Helm chart configuration changes are required, but the application version bump indicates significant changes in the product-console application itself.

| Field | v4.2.0 | v4.2.1 |
|-------|--------|--------|
| Chart version | `4.2.0` | `4.2.1` |
| App version | `1.12.0` | `2.0.0` |
| Image tag (default) | `1.12.0` | `2.0.0` |

## Application Version Update

The application version has been updated from `1.12.0` to `2.0.0`, indicating a major version change in the product-console application. The default image tag has been updated accordingly.

| Setting | v4.2.0 | v4.2.1 |
|---------|--------|--------|
| `appVersion` | `1.12.0` | `2.0.0` |
| `image.tag` | `1.12.0` | `2.0.0` |

**Impact:**

- The Helm upgrade will pull and deploy the new `2.0.0` application image
- If you have explicitly set `image.tag` in your `values.yaml`, that override will continue to be respected
- The major version bump in the application suggests potential breaking changes or significant new features in the product-console application itself — consult the product-console application release notes for details on application-level changes

> **Important:** This chart upgrade does not modify any Helm configuration or Kubernetes resource definitions. The only change is the container image version. However, the application major version bump (1.x → 2.x) may introduce application-level breaking changes. Review the product-console v2.0.0 application release notes before upgrading.

## Migration Steps

This upgrade requires no changes to your `values.yaml` or Helm configuration. The upgrade will trigger a rolling restart of the deployment with the new application image.

**Recommended upgrade process:**

1. Review the product-console application v2.0.0 release notes to understand application-level changes, new features, or breaking changes.

2. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

3. Run the upgrade command during a maintenance window:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.1 -n product-console
```

4. Monitor the rollout to ensure pods start successfully:

```bash
kubectl rollout status deployment/product-console -n product-console
```

5. Verify all pods are running and healthy:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console
```

6. Check application logs for any startup issues or errors:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=100
```

> **Note:** If you have pinned `image.tag` to a specific version in your `values.yaml`, you will need to update it manually to `2.0.0` or remove the override to use the chart default.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.1 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.1 -n product-console
```
