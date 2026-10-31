# Helm Upgrade from v4.4.4 to v4.4.5

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application version updated to 2.16.2](#1-application-version-updated-to-2162)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This release moves the default product-console application version from 2.13.1 to 2.16.2. The chart changes only `appVersion` and the default `image.tag`. No chart values or templates change, but the jump spans several application minor versions (2.14, 2.15 and 2.16), so read the application release notes before you upgrade.

| Field | v4.4.4 | v4.4.5 |
|-------|--------|--------|
| Chart version | `4.4.4` | `4.4.5` |
| App version | `2.13.1` | `2.16.2` |

## Changes

### 1. Application version updated to 2.16.2

The chart now deploys product-console application version 2.16.2 by default, up from 2.13.1. `image.tag` in `values.yaml` and `appVersion` in `Chart.yaml` both changed.

| Setting | v4.4.4 | v4.4.5 |
|---------|--------|--------|
| `appVersion` | `2.13.1` | `2.16.2` |
| `image.tag` (default) | `2.13.1` | `2.16.2` |

**What changed:**

The default image tag in `values.yaml` is `2.16.2`. The image repository stays `lerianstudio/product-console`. The init container `copy-public-files` uses the same tag as the main container. If you did not set `image.tag` in your values, the upgrade deploys the new image.

**Impact:**

- Deployments using the default `image.tag` will automatically upgrade to version 2.16.2
- The upgrade triggers a rolling restart of the console pods to deploy the new image
- If you pinned `image.tag` in your values file, the pin takes precedence and the image does not change. The pods still roll once, because the chart version is part of the `helm.sh/chart` label in the pod template

> **Note:** Review the product-console application release notes for the versions after 2.13.1 up to 2.16.2. The chart does not describe application-level changes.

## Migration Steps

This upgrade requires no configuration changes. The application version update is the only change.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Check whether your values pin the image tag. `helm get values` shows only the values you supplied:

```bash
helm get values product-console -n product-console | grep -A2 "^image:"
```

If the command prints nothing, `image.tag` is not set and the upgrade deploys 2.16.2. If it prints a tag, that tag stays in use (for example, a pin to `2.13.1` keeps 2.13.1) until you change it.

3. Run the upgrade command.

4. Monitor the rolling restart (this assumes the release and chart name are both `product-console`; adjust the deployment name otherwise):

```bash
kubectl rollout status deployment/product-console -n product-console
```

5. Verify the new version is running:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console -o jsonpath='{.items[0].spec.containers[0].image}'
```

Expected output: `lerianstudio/product-console:2.16.2` (or your pinned tag).

6. Check application logs for any startup issues:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=100
```

> **Note:** The default strategy is `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0`. Existing pods keep serving traffic until the new pods pass their readiness checks.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.5 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.5 -n product-console
```
