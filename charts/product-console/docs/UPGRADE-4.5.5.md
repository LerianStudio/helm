# Helm Upgrade from v4.5.4 to v4.5.5

## Topics

- **[Overview](#overview)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `3.4.0` to `3.5.0`. No breaking changes are introduced. The chart updates the default image tag to match the new application version.

| Field | v4.5.4 | v4.5.5 |
|-------|--------|--------|
| Chart version | `4.5.4` | `4.5.5` |
| App version | `3.4.0` | `3.5.0` |
| Default image tag | `3.4.0` | `3.5.0` |

**Key changes:**

- Application version bumped from `3.4.0` to `3.5.0`
- Default `image.tag` updated from `3.4.0` to `3.5.0` to match the new application version

> **Important:** This release updates the application version. Review the product-console application release notes for `3.5.0` to understand what changed in the application itself. This guide covers only the Helm chart configuration changes.

## Configuration Changes

The chart updates the default image tag to match the new application version.

### Image tag configuration

**Before (v4.5.4):**

```yaml
image:
  repository: lerianstudio/product-console
  pullPolicy: IfNotPresent
  tag: "3.4.0"
```

**After (v4.5.5):**

```yaml
image:
  repository: lerianstudio/product-console
  pullPolicy: IfNotPresent
  tag: "3.5.0"
```

**Impact:**

- Operators who did not override `image.tag` in their values will automatically receive the new `3.5.0` image
- Operators who explicitly set `image.tag` in their values override file will continue to use their specified version

| Setting | v4.5.4 | v4.5.5 | Notes |
|---------|--------|--------|-------|
| `image.tag` | `"3.4.0"` | `"3.5.0"` | Now matches `appVersion` |

## Migration Steps

This upgrade requires no mandatory configuration changes. The chart will automatically use the new `3.5.0` image unless you have explicitly pinned a different version.

**Recommended upgrade process:**

1. **Review your current image tag configuration**:

```bash
helm get values product-console -n product-console | grep -A5 "^image:"
```

2. **If you have explicitly set `image.tag` in your values**, decide whether to:
   - Keep your pinned version (no action required)
   - Upgrade to `3.5.0` by removing your override or updating it to `"3.5.0"`

3. **If you have NOT overridden `image.tag`**, the upgrade will automatically deploy `3.5.0`. Review the application release notes for `3.5.0` to understand what changed in the application.

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

Expected output: `lerianstudio/product-console:3.5.0` (or your pinned version if you overrode `image.tag`)

> **Note:** This upgrade triggers a rolling restart of the product-console deployment because the image tag changes. Plan the upgrade during a maintenance window if your environment requires zero downtime.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.5
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.5
```
