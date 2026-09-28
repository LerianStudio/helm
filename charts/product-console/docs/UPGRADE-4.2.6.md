# Helm Upgrade from v4.2.5 to v4.2.6

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version updated to 2.4.1](#1-application-version-updated-to-241)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the product-console application from version 2.2.1 to 2.4.1. The chart version is bumped from 4.2.5 to 4.2.6. No breaking changes or configuration modifications are required.

| Field | v4.2.5 | v4.2.6 |
|-------|--------|--------|
| Chart version | `4.2.5` | `4.2.6` |
| App version | `2.2.1` | `2.4.1` |
| Image tag (default) | `2.2.1` | `2.4.1` |

## Features

### 1. Application version updated to 2.4.1

The product-console application has been updated from version 2.2.1 to 2.4.1. This update includes two minor version increments (2.2.1 → 2.3.x → 2.4.1), which may contain bug fixes, performance improvements, and new features from the upstream application.

**Image tag change:**

| Setting | v4.2.5 | v4.2.6 |
|---------|--------|--------|
| `image.tag` | `"2.2.1"` | `"2.4.1"` |
| `appVersion` | `"2.2.1"` | `"2.4.1"` |

The default image tag is automatically set to match the `appVersion` field in Chart.yaml. If you have explicitly overridden `image.tag` in your values, you may want to update it to use the new version:

```yaml
image:
  tag: "2.4.1"
```

> **Note:** If you have pinned `image.tag` to `2.2.1` in your values file, the upgrade will not automatically update the running application version. Remove the explicit tag override to use the chart's default, or update it manually to `2.4.1`.

## Configuration Changes

No configuration keys were added, removed, or renamed in this release. All existing values remain compatible.

| Setting | v4.2.5 | v4.2.6 | Notes |
|---------|--------|--------|-------|
| `image.tag` | `"2.2.1"` | `"2.4.1"` | Default value updated; override preserved if set |

## Migration Steps

This upgrade requires no mandatory configuration changes. The Helm upgrade will update the deployment with the new image version and trigger a rolling restart.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Check the product-console application release notes for versions 2.3.x through 2.4.1 to understand new features, bug fixes, or behavioral changes that may affect your deployment.

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
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.6 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.6 -n product-console
```
