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

> **Important:** product-console `3.0.0` reads Lender's business date from `GET /api/v1/business-date`. If you set `configmap.LENDER_BASE_PATH`, upgrade Lender to a release that serves this endpoint before you upgrade the console. Lender `v3.1.1` does not serve it, and with an older Lender the dated Lender screens show "This Lender is older than this Console".

> **Note:** If you have explicitly set `image.tag` in your `values.yaml` or via `--set`, that override will continue to take precedence. Remove the override to adopt the new default `3.0.0` image.

## Migration Steps

This upgrade requires no mandatory Helm values changes. The chart configuration remains backward-compatible.

If the console connects to Lender, upgrade Lender first (see the note above).

**Recommended upgrade process:**

1. Preview the Helm changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.7 -n product-console
```

3. Monitor the deployment rollout:

```bash
kubectl rollout status deployment/product-console -n product-console
```

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console
```

5. Check application logs for startup issues:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=100
```

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.7 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.7 -n product-console
```
