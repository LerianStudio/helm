# Helm Upgrade from v4.4.3 to v4.4.4

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version updated to 2.13.1](#1-application-version-updated-to-2131)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `2.13.0` to `2.13.1`. The chart version is incremented from `4.4.3` to `4.4.4`. No configuration changes, template modifications, or breaking changes are included.

| Field | v4.4.3 | v4.4.4 |
|-------|--------|--------|
| Chart version | `4.4.3` | `4.4.4` |
| App version | `2.13.0` | `2.13.1` |
| Image tag (default) | `2.13.0` | `2.13.1` |

## Fixes

### 1. Application version updated to 2.13.1

The application image tag has been updated to `2.13.1`. This patch release includes bug fixes and minor improvements in the product-console application.

| Setting | v4.4.3 | v4.4.4 |
|---------|--------|--------|
| `appVersion` | `2.13.0` | `2.13.1` |
| `image.tag` | `2.13.0` | `2.13.1` |

**Impact:**

- The deployment will pull the new `2.13.1` image during the upgrade
- A rolling restart of all product-console pods will occur
- No configuration changes are required unless you have explicitly pinned `image.tag` in your values

> **Note:** If you have overridden `image.tag` in your custom values file, you may want to update it to `2.13.1` or remove the override to use the chart default.

## Migration Steps

This upgrade requires no configuration changes. The Helm upgrade will automatically update the image tag and perform a rolling restart.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running with the new image version:

```bash
kubectl get pods -n product-console -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

4. Check service logs for any startup issues:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

> **Note:** The upgrade triggers a rolling restart of the `product-console` deployment. Existing connections may be briefly interrupted during the pod rollover.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.4 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.4 -n product-console
```
