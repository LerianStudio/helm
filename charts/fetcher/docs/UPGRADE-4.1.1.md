# Helm Upgrade from v4.1.0 to v4.1.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version promoted from beta to stable](#1-application-version-promoted-from-beta-to-stable)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `4.1.0` to `4.1.1`. This is a **patch** release that promotes the application version from beta (`4.1.0-beta.1`) to stable (`4.1.0`) for both `manager` and `worker` components.

No breaking changes, no required `values.yaml` modifications, and no data migration are needed. This upgrade simply updates the container image tags to the stable release.

## Fixes

### 1. Application version promoted from beta to stable

The `appVersion` in `Chart.yaml` and the default image tags for both `manager` and `worker` components have been updated from `4.1.0-beta.1` to `4.1.0`, marking the stable release of the application.

**Before (v4.1.0):**

```yaml
# Chart.yaml
appVersion: "4.1.0-beta.1"

# values.yaml
manager:
  image:
    tag: "4.1.0-beta.1"

worker:
  image:
    tag: "4.1.0-beta.1"
```

**After (v4.1.1):**

```yaml
# Chart.yaml
appVersion: "4.1.0"

# values.yaml
manager:
  image:
    tag: "4.1.0"

worker:
  image:
    tag: "4.1.0"
```

| Setting | v4.1.0 | v4.1.1 |
|---------|--------|--------|
| `appVersion` | `"4.1.0-beta.1"` | `"4.1.0"` |
| `manager.image.tag` | `"4.1.0-beta.1"` | `"4.1.0"` |
| `worker.image.tag` | `"4.1.0-beta.1"` | `"4.1.0"` |

> **Note:** If you have explicitly overridden `manager.image.tag` or `worker.image.tag` in your `values.yaml` to pin to `4.1.0-beta.1`, you can remove those overrides to adopt the new stable default, or update them to `"4.1.0"` explicitly. Then pass the edited values file with `-f` in the upgrade command: without `-f` or `--set`, Helm reuses the values of the previous release and keeps the beta pin.

## Configuration Changes

No `values.yaml` keys were added, removed, or changed. The only modification is the default value for `manager.image.tag` and `worker.image.tag`, which now point to the stable `4.1.0` image instead of the beta release.

| Setting | v4.1.0 default | v4.1.1 default |
|---------|----------------|----------------|
| `manager.image.tag` | `"4.1.0-beta.1"` | `"4.1.0"` |
| `worker.image.tag` | `"4.1.0-beta.1"` | `"4.1.0"` |

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will roll both the `manager` and `worker` Deployments with the new stable image tags.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify the manager and worker pods are running with the new image version:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager -o jsonpath='{.items[*].spec.containers[*].image}'
kubectl get pods -n fetcher -l app.kubernetes.io/component=worker -o jsonpath='{.items[*].spec.containers[*].image}'
```

4. Check manager and worker logs for any startup issues:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50
```

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.1 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.1 -n fetcher
```
