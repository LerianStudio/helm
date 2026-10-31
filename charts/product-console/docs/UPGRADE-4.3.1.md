# Helm Upgrade from v4.3.0 to v4.3.1

## Topics

- **[Overview](#overview)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from 2.5.0 to 2.6.0. No chart configuration changes, template modifications, or breaking changes are introduced. The upgrade only updates the container image tag.

| Field | v4.3.0 | v4.3.1 |
|-------|--------|--------|
| Chart version | `4.3.0` | `4.3.1` |
| App version | `2.5.0` | `2.6.0` |

**Key changes:**

- Application version bumped to 2.6.0
- Container image tag updated to 2.6.0
- No values schema changes
- No template logic changes

> **Note:** This upgrade will trigger a rolling restart of the product-console deployment to pull the new image version.

## Configuration Changes

No values keys were added, removed, or renamed. The only change is the default image tag, which follows the application version.

| Setting | v4.3.0 | v4.3.1 | Notes |
|---------|--------|--------|-------|
| `image.tag` | `"2.5.0"` | `"2.6.0"` | Default image tag updated to match new app version |

**Impact:**

- Deployments using the default `image.tag` (or omitting it entirely) will automatically pull version 2.6.0
- Deployments with an explicit `image.tag` override in values will continue using the pinned version until the override is updated or removed

## Migration Steps

This upgrade requires no configuration changes. The new image version will be pulled automatically during the rolling restart.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify your current image tag configuration:

```bash
helm get values product-console -n product-console | grep -A2 "^image:"
```

If you have explicitly pinned `image.tag` to `2.5.0` and want to adopt the new version, either remove the override or update it to `2.6.0`:

```yaml
image:
  tag: "2.6.0"
```

3. Run the upgrade command.

4. Monitor the rolling restart:

```bash
kubectl rollout status deployment/product-console -n product-console
```

5. Verify the new image version is running:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console -o jsonpath='{.items[0].spec.containers[0].image}'
```

Expected output:

```
lerianstudio/product-console:2.6.0
```

6. Check application logs for any startup issues:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

> **Note:** If you have pinned `image.tag` in your values and do not update it, the deployment will continue running version 2.5.0. The chart respects explicit image tag overrides.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.3.1 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.3.1 -n product-console
```
