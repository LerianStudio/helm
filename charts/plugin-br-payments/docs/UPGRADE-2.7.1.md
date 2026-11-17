# Helm Upgrade from v2.7.0 to v2.7.1

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application version bump](#1-application-version-bump)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.7.0` to `2.7.1`. This is a patch release that updates the application version from `1.5.0` to `1.5.1`. The chart contains no breaking changes, no new configuration values, and no template modifications. The upgrade requires no operator action beyond running the upgrade command.

## Changes

### 1. Application version bump

The application version was incremented from `1.5.0` to `1.5.1`. The chart's `appVersion` field and the default `app.image.tag` value were both updated to reflect this change.

**Before (v2.7.0):**

```yaml
# Chart.yaml
appVersion: "1.5.0"

# values.yaml
app:
  image:
    tag: "1.5.0"
```

**After (v2.7.1):**

```yaml
# Chart.yaml
appVersion: "1.5.1"

# values.yaml
app:
  image:
    tag: "1.5.1"
```

**Operational impact:**

The upgrade will trigger a rolling restart of the plugin pods to deploy the new application image. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions. If you override `app.image.tag` in your values overlay, the chart will use your pinned version instead of the new default `1.5.1`.

> **Note:** The application version bump from `1.5.0` to `1.5.1` is a patch release. Consult the `plugin-br-payments` application changelog for details on bug fixes or minor improvements included in this version.

## Configuration Changes

| Setting | v2.7.0 | v2.7.1 |
|---------|--------|--------|
| `app.image.tag` | `"1.5.0"` | `"1.5.1"` |

No configuration values were added, removed, or changed beyond the default image tag. All existing values overlays remain compatible with v2.7.1.

## Migration Steps

1. **(Optional)** If you override `app.image.tag` in your values overlay and want to adopt the new application version, update your override to `"1.5.1"` or remove the override to use the chart default.

2. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n midaz-plugins
```

4. Confirm the new image tag is deployed:

```bash
kubectl get deployment -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments-helm -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
```

Expected output (if not overridden):

```
lerianstudio/plugin-br-payments:1.5.1
```

5. Check service logs to confirm the application started successfully:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments-helm --tail=50
```

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.7.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.7.1
```
