# Helm Upgrade from v4.2.2 to v4.2.3

## Topics

- **[Overview](#overview)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `2.1.0` to `2.2.1` and cleans up redundant configuration in `values.yaml`. No breaking changes are introduced. The chart now ships with a cleaner default configuration that removes a duplicate `product-console.image.tag` override.

| Field | v4.2.2 | v4.2.3 |
|-------|--------|--------|
| Chart version | `4.2.2` | `4.2.3` |
| App version | `2.1.0` | `2.2.1` |
| Default image tag | `2.0.0` | `2.2.1` |

**Key changes:**

- Application version bumped from `2.1.0` to `2.2.1`
- Default `image.tag` updated from `2.0.0` to `2.2.1` to match the new application version
- Removed redundant `product-console.image.tag` override from the bottom of `values.yaml`

> **Important:** This release updates the application version. Review the product-console application release notes for `2.2.1` to understand what changed in the application itself. This guide covers only the Helm chart configuration changes.

## Configuration Changes

The chart removes a redundant image tag override and updates the default image tag to match the new application version.

### Image tag configuration

**Before (v4.2.2):**

The `values.yaml` file contained two conflicting image tag declarations:

```yaml
image:
  repository: lerianstudio/product-console
  pullPolicy: IfNotPresent
  tag: "2.0.0"
```

And at the bottom of the file:

```yaml
product-console:
  image:
    tag: 2.1.0
```

The second declaration overrode the first, making the effective tag `2.1.0` despite `image.tag` being set to `2.0.0`.

**After (v4.2.3):**

The redundant override is removed, and `image.tag` is updated to match the new application version:

```yaml
image:
  repository: lerianstudio/product-console
  pullPolicy: IfNotPresent
  tag: "2.2.1"
```

**Impact:**

- Operators who did not override `image.tag` in their values will automatically receive the new `2.2.1` image
- Operators who explicitly set `image.tag` in their values override file will continue to use their specified version
- The configuration is now clearer: there is only one place where the default image tag is declared

| Setting | v4.2.2 | v4.2.3 | Notes |
|---------|--------|--------|-------|
| `image.tag` | `"2.0.0"` (overridden to `2.1.0`) | `"2.2.1"` | Now matches `appVersion` |
| `product-console.image.tag` | `2.1.0` | Removed | Redundant override eliminated |

## Migration Steps

This upgrade requires no mandatory configuration changes. The chart will automatically use the new `2.2.1` image unless you have explicitly pinned a different version.

**Recommended upgrade process:**

1. **Review your current image tag configuration**:

```bash
helm get values product-console -n product-console | grep -A5 "^image:"
```

2. **If you have explicitly set `image.tag` in your values**, decide whether to:
   - Keep your pinned version (no action required)
   - Upgrade to `2.2.1` by removing your override or updating it to `"2.2.1"`

3. **If you have NOT overridden `image.tag`**, the upgrade will automatically deploy `2.2.1`. Review the application release notes for `2.2.1` to understand what changed in the application.

4. **Preview the changes** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

5. **Run the upgrade command**.

6. **Verify the deployment rolls successfully**:

```bash
kubectl rollout status deployment/product-console -n product-console
```

7. **Confirm the new image is running**:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console -o jsonpath='{.items[0].spec.containers[0].image}'
```

Expected output: `lerianstudio/product-console:2.2.1` (or your pinned version if you overrode `image.tag`)

> **Note:** This upgrade triggers a rolling restart of the product-console deployment because the image tag changes. Plan the upgrade during a maintenance window if your environment requires zero downtime.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.3 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.3 -n product-console
```
