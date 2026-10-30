# Helm Upgrade from v4.4.6 to v4.4.7

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `2.16.4` to `3.0.0`. Despite the major version bump in the application itself, this is a patch-level Helm chart release with no breaking changes to chart configuration or templates.

| Field | v4.4.6 | v4.4.7 |
|-------|--------|--------|
| Chart version | `4.4.6` | `4.4.7` |
| App version | `2.16.4` | `3.0.0` |
| Image tag (default) | `2.16.4` | `3.0.0` |

## Application Version Update

The default container image tag has been updated to align with the new application version.

| Setting | v4.4.6 | v4.4.7 |
|---------|--------|--------|
| `image.tag` | `"2.16.4"` | `"3.0.0"` |
| `appVersion` | `"2.16.4"` | `"3.0.0"` |

**Impact:**

- The upgrade will pull and deploy the `3.0.0` application image
- A rolling restart of the `product-console` deployment will occur
- No Helm chart configuration changes are required

> **Important:** The application version jump from `2.16.4` to `3.0.0` indicates a major version change in the product-console application itself. Review the application's release notes to understand any breaking changes, new features, or migration requirements at the application level (database migrations, API changes, etc.) before proceeding with the upgrade.

> **Note:** If you have explicitly set `image.tag` in your `values.yaml` or via `--set`, that override will continue to take precedence. Remove the override to adopt the new default `3.0.0` image.

## Migration Steps

This upgrade requires no mandatory Helm values changes. The chart configuration remains backward-compatible.

**Recommended upgrade process:**

1. Review the product-console application release notes for version `3.0.0` to understand application-level changes, including:
   - Database schema migrations or data transformations
   - API endpoint changes or deprecations
   - New required environment variables or configuration
   - Breaking changes in application behavior

2. Preview the Helm changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

3. Verify that your environment meets any new requirements introduced by the `3.0.0` application version.

4. Run the upgrade command during a maintenance window:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.7 -n product-console
```

5. Monitor the deployment rollout:

```bash
kubectl rollout status deployment/product-console -n product-console
```

6. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console
```

7. Check application logs for any startup issues or migration errors:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=100
```

> **Warning:** If the `3.0.0` application version introduces database migrations, ensure you have a backup of your data before upgrading. Consult the product-console application documentation for rollback procedures if needed.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.7 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.7 -n product-console
```
