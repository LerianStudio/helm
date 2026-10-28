# Helm Upgrade from v4.4.4 to v4.4.5

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application version updated to 2.16.2](#1-application-version-updated-to-2162)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the product-console application from version 2.13.1 to 2.16.2. No chart configuration changes are required.

| Field | v4.4.4 | v4.4.5 |
|-------|--------|--------|
| Chart version | `4.4.4` | `4.4.5` |
| App version | `2.13.1` | `2.16.2` |

## Changes

### 1. Application version updated to 2.16.2

The chart now deploys product-console application version 2.16.2, up from 2.13.1. The container image tag has been updated accordingly.

| Setting | v4.4.4 | v4.4.5 |
|---------|--------|--------|
| `appVersion` | `2.13.1` | `2.16.2` |
| `image.tag` (default) | `2.13.1` | `2.16.2` |

**What changed:**

The default image tag in `values.yaml` has been updated to match the new application version. If you have not overridden `image.tag` in your values, the upgrade will pull and deploy the new image version.

**Impact:**

- Deployments using the default `image.tag` will automatically upgrade to version 2.16.2
- The upgrade will trigger a rolling restart of console pods to deploy the new image
- If you have pinned `image.tag` to a specific version in your values file, that override will continue to take precedence and no image change will occur

> **Note:** Review the product-console application release notes for versions 2.13.2 through 2.16.2 to understand application-level changes, new features, and bug fixes included in this update.

## Migration Steps

This upgrade requires no configuration changes. The application version update is the only change.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify your current image tag setting:

```bash
helm get values product-console -n product-console | grep -A2 "^image:"
```

If `image.tag` is not set or is set to `2.13.1`, the upgrade will deploy version 2.16.2.

3. Run the upgrade command.

4. Monitor the rolling restart:

```bash
kubectl rollout status deployment/product-console -n product-console
```

5. Verify the new version is running:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console -o jsonpath='{.items[0].spec.containers[0].image}'
```

Expected output: `lerianstudio/product-console:2.16.2`

6. Check application logs for any startup issues:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=100
```

> **Note:** The rolling restart ensures zero-downtime deployment. Existing pods continue serving traffic until new pods pass readiness checks.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.5 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.5 -n product-console
```
