# Helm Upgrade from v4.2.6 to v4.2.7

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `2.4.1` to `2.5.0`. No configuration changes, template modifications, or breaking changes are introduced. The upgrade only updates the container image tag.

| Field | v4.2.6 | v4.2.7 |
|-------|--------|--------|
| Chart version | `4.2.6` | `4.2.7` |
| App version | `2.4.1` | `2.5.0` |
| Image tag | `2.4.1` | `2.5.0` |

## Application Version Update

The default container image tag has been updated to match the new application version. This change affects the `image.tag` value in `values.yaml`.

| Setting | v4.2.6 | v4.2.7 |
|---------|--------|--------|
| `image.tag` | `"2.4.1"` | `"2.5.0"` |
| `appVersion` | `"2.4.1"` | `"2.5.0"` |

**Impact:**

- The upgrade will trigger a rolling restart of the `product-console` deployment with the new image version
- No configuration changes are required unless you have explicitly overridden `image.tag` in your values
- If you have pinned `image.tag` to a specific version in your values file, you may choose to keep your override or update it to `"2.5.0"`

> **Note:** If you are using a custom `image.tag` override in your values, the upgrade will respect your override and will not automatically update to `2.5.0`. Review your values file to determine if you want to adopt the new default version.

**Verification steps:**

After upgrading, verify the new image version is running:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console -o jsonpath='{.items[*].spec.containers[*].image}'
```

Check that all pods are running and healthy:

```bash
kubectl get pods -n product-console
```

Monitor the rollout status:

```bash
kubectl rollout status deployment/product-console -n product-console
```

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.7 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.7 -n product-console
```
