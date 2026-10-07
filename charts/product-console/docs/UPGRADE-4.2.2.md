# Helm Upgrade from v4.2.1 to v4.2.2

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application version updated to 2.1.0](#1-application-version-updated-to-210)
  - [2. Chart.yaml formatting cleanup](#2-chartyaml-formatting-cleanup)
  - [3. Values.yaml whitespace normalization](#3-valuesyaml-whitespace-normalization)
  - [4. New product-console image tag override](#4-new-product-console-image-tag-override)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from 2.0.0 to 2.1.0 and performs chart maintenance. No breaking changes or configuration migrations are required.

| Field | v4.2.1 | v4.2.2 |
|-------|--------|--------|
| Chart version | `4.2.1` | `4.2.2` |
| App version | `2.0.0` | `2.1.0` |
| Default image tag | `2.0.0` | `2.0.0` |

## Changes

### 1. Application version updated to 2.1.0

The `appVersion` field in `Chart.yaml` has been updated from `2.0.0` to `2.1.0`. This reflects the new version of the product-console application being deployed.

| Setting | v4.2.1 | v4.2.2 |
|---------|--------|--------|
| `appVersion` | `2.0.0` | `2.1.0` |

> **Note:** The default `image.tag` in `values.yaml` remains `2.0.0` for backward compatibility. A new override block has been added at the end of `values.yaml` to explicitly set the image tag to `2.1.0` (see [section 4](#4-new-product-console-image-tag-override)).

### 2. Chart.yaml formatting cleanup

Multiple blank lines have been removed from `Chart.yaml`. This is a cosmetic change with no functional impact on the chart behavior.

**Before (v4.2.1):**

```yaml
type: application
annotations:
  lerian.studio/chart-type: single-service

home: https://github.com/LerianStudio/helm

sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/product-console
```

**After (v4.2.2):**

```yaml
type: application
annotations:
  lerian.studio/chart-type: single-service
home: https://github.com/LerianStudio/helm
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/product-console
```

### 3. Values.yaml whitespace normalization

Excessive blank lines between configuration blocks in `values.yaml` have been removed. This is a formatting change that does not affect any configuration values or chart behavior.

**Examples of normalized sections:**

```yaml
# Before (v4.2.1)
replicaCount: 1

revisionHistoryLimit: 10

readinessProbe: {}

# After (v4.2.2)
replicaCount: 1
revisionHistoryLimit: 10
readinessProbe: {}
```

### 4. New product-console image tag override

A new configuration block has been added at the end of `values.yaml` to explicitly override the image tag to `2.1.0`:

```yaml
product-console:
  image:
    tag: 2.1.0
```

This override ensures that deployments using the default values will pull the `2.1.0` image, matching the chart's `appVersion`.

| Setting | v4.2.1 | v4.2.2 |
|---------|--------|--------|
| `product-console.image.tag` | not present | `2.1.0` |

> **Important:** If you have explicitly set `image.tag` in your custom values file, that value will take precedence over this new override. Review your values to ensure you are deploying the intended image version.

## Migration Steps

This upgrade requires no mandatory configuration changes. The Helm upgrade will update the deployment to use the new application version.

**Recommended upgrade process:**

1. Review your current values file to check if `image.tag` is explicitly set:

```bash
helm get values product-console -n product-console
```

2. If you have set `image.tag` to `2.0.0` explicitly, you may want to remove that override to use the chart's default (`2.1.0`), or update it to `2.1.0`:

```yaml
image:
  tag: "2.1.0"
```

3. Preview the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. Run the upgrade command during a maintenance window.

5. Verify all pods are running the new version:

```bash
kubectl get pods -n product-console -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

6. Check service logs for any startup issues:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

> **Note:** The upgrade triggers a rolling restart of the `product-console` deployment. Ensure your `deploymentStrategy` settings allow for zero-downtime updates if required.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.2 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.2 -n product-console
```
