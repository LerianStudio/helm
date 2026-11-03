# Helm Upgrade from v2.2.0 to v2.2.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.2.0` to `2.2.1`. This is a patch release that updates the application version from `1.2.0-beta.1` to `1.2.0`, marking the transition from beta to stable release. The chart itself contains no template, values, or configuration changes.

This upgrade requires no operator action beyond running the upgrade command. Existing deployments will continue to work without values changes.

## Application Version Update

The `appVersion` field in `Chart.yaml` has been updated from `1.2.0-beta.1` to `1.2.0`, indicating that the application has graduated from beta to stable release.

| Setting | v2.2.0 | v2.2.1 |
|---------|--------|--------|
| `appVersion` | `1.2.0-beta.1` | `1.2.0` |

**Operational impact:**

The upgrade will trigger a rolling restart of the plugin pods to deploy the new application image. The image tag is derived from the `appVersion` field unless explicitly overridden in your values overlay via `image.tag`.

If you have pinned `image.tag` in your values overlay to `1.2.0-beta.1`, you may choose to remove that override to allow the chart to use the default stable `1.2.0` tag, or explicitly update your override to `1.2.0`.

> **Note:** The application binary version `1.2.0` is the stable release of `1.2.0-beta.1`. Review the application's release notes for any behavioral changes or bug fixes included in the stable release.

## Configuration Changes

No configuration values, templates, or defaults were changed in this release. The only change is the `appVersion` field in `Chart.yaml`.

| Setting | v2.2.0 | v2.2.1 |
|---------|--------|--------|
| `appVersion` | `1.2.0-beta.1` | `1.2.0` |

## Migration Steps

1. **(Optional)** If you have explicitly set `image.tag: "1.2.0-beta.1"` in your values overlay, decide whether to:
   - Remove the override and allow the chart to use the default `1.2.0` tag, or
   - Update the override to `image.tag: "1.2.0"`

2. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

4. Confirm the new image version is deployed:

```bash
kubectl get deployment -n <namespace> -l app.kubernetes.io/name=plugin-br-payments-helm -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
```

Expected output (if using default image repository and tag):

```
<repository>:1.2.0
```

5. Check service logs to confirm the application started successfully:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-br-payments-helm --tail=50
```

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 2.2.1 -n plugin-br-payments
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 2.2.1 -n plugin-br-payments
```
