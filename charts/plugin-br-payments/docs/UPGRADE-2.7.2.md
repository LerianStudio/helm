# Helm Upgrade from v2.7.1 to v2.7.2

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application version bump to 1.6.0](#1-application-version-bump-to-160)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.7.1` to `2.7.2`. This is a patch release that updates the application version from `1.5.1` to `1.6.0`. The chart bump carries no breaking changes, no new configuration values, and no template modifications. The upgrade requires no operator action beyond running the upgrade command.

Existing deployments will continue to work without values changes. The upgrade triggers a rolling restart of the plugin pods to deploy the new application image.

## Changes

### 1. Application version bump to 1.6.0

The `appVersion` field in `Chart.yaml` and the default `app.image.tag` in `values.yaml` were updated from `1.5.1` to `1.6.0`. This change pulls a newer version of the `plugin-br-payments` application image.

**Before (v2.7.1):**

```yaml
# Chart.yaml
appVersion: "1.5.1"

# values.yaml
app:
  image:
    tag: "1.5.1"
```

**After (v2.7.2):**

```yaml
# Chart.yaml
appVersion: "1.6.0"

# values.yaml
app:
  image:
    tag: "1.6.0"
```

**Operational impact:**

The upgrade will pull the `1.6.0` image and perform a rolling restart of all plugin pods. If you override `app.image.tag` in your values overlay to pin a specific version, your override will continue to take precedence and the chart will not automatically upgrade the application image. Remove the override if you want to adopt the new default.

> **Note:** Review the `plugin-br-payments` application release notes for version `1.6.0` to understand what application-level changes are included. This chart upgrade guide covers only the Helm chart changes.

## Configuration Changes

| Setting | v2.7.1 | v2.7.2 |
|---------|--------|--------|
| `app.image.tag` | `"1.5.1"` | `"1.6.0"` |

No configuration values were added, removed, or changed beyond the image tag default. All existing values overlays remain compatible.

## Migration Steps

1. **(Optional)** If you override `app.image.tag` in your values overlay, decide whether to keep your pinned version or adopt the new `1.6.0` default. If you want to upgrade the application image, remove the `app.image.tag` override from your values file.

2. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments-helm
```

4. Confirm the new image version is deployed:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments-helm -o jsonpath='{.items[0].spec.containers[0].image}'
```

Expected output (if not overridden):

```
<registry>/plugin-br-payments:1.6.0
```

5. Check service logs to confirm the application starts successfully:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments-helm --tail=50
```

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.7.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.7.2
```
