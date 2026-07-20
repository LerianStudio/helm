# Helm Upgrade from v3.1.0 to v3.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version updated to 1.10.0](#1-application-version-updated-to-1100)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that updates the product-console application from version 1.6.0 to 1.10.0. The chart version is bumped from 3.1.0 to 3.2.0. No breaking changes or configuration modifications are required.

| Field | v3.1.0 | v3.2.0 |
|-------|--------|--------|
| Chart version | `3.1.0` | `3.2.0` |
| App version | `1.6.0` | `1.10.0` |
| Image tag (default) | `1.6.0` | `1.10.0` |

## Features

### 1. Application version updated to 1.10.0

The product-console application has been updated from version 1.6.0 to 1.10.0. This update includes four minor version increments (1.6.0 → 1.7.0 → 1.8.0 → 1.9.0 → 1.10.0), which may contain bug fixes, performance improvements, and new features from the upstream application.

**Image tag change:**

| Setting | v3.1.0 | v3.2.0 |
|---------|--------|--------|
| `image.tag` | `"1.6.0"` | `"1.10.0"` |
| `appVersion` | `"1.6.0"` | `"1.10.0"` |

The default image tag is automatically set to match the `appVersion` field in Chart.yaml. If you have explicitly overridden `image.tag` in your values, you may want to update it to use the new version:

```yaml
image:
  tag: "1.10.0"
```

> **Note:** If you have pinned `image.tag` to `1.6.0` in your values file, the upgrade will not automatically update the running application version. Remove the explicit tag override to use the chart's default, or update it manually to `1.10.0`.

## Configuration Changes

No configuration keys were added, removed, or renamed in this release. All existing values remain compatible.

| Setting | v3.1.0 | v3.2.0 | Notes |
|---------|--------|--------|-------|
| `image.tag` | `"1.6.0"` | `"1.10.0"` | Default value updated; override preserved if set |

## Migration Steps

This upgrade requires no mandatory configuration changes. The Helm upgrade will update the deployment with the new image version and trigger a rolling restart.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Check the product-console application release notes for versions 1.7.0 through 1.10.0 to understand new features, bug fixes, or behavioral changes that may affect your deployment.

3. Run the upgrade command during a maintenance window.

4. Verify all pods are running with the new image version:

```bash
kubectl get pods -n product-console -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

5. Check service logs for any startup issues or errors:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=100
```

6. Validate application functionality by accessing the product-console service and testing critical workflows.

> **Important:** The upgrade triggers a rolling restart of the product-console deployment. Ensure your deployment has appropriate replica counts and PodDisruptionBudgets configured to maintain availability during the rollout.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 3.2.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 3.2.0 -n product-console
```
