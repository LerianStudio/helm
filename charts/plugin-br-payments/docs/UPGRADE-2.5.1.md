# Helm Upgrade from v2.5.0 to v2.5.1

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application version upgrade to 1.4.0](#1-application-version-upgrade-to-140)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.5.0` to `2.5.1`. This is a patch release that upgrades the application version from `1.3.0` to `1.4.0`. The chart updates the default image tag to match the new application version.

No configuration changes are required. The upgrade will trigger a rolling restart of application pods to deploy the new image version.

## Changes

### 1. Application version upgrade to 1.4.0

The chart now deploys application version `1.4.0` (previously `1.3.0`). The `appVersion` field in `Chart.yaml` and the default `app.image.tag` in `values.yaml` have been updated to reflect this version bump.

**Before (v2.5.0):**

```yaml
# Chart.yaml
appVersion: "1.3.0"

# values.yaml
app:
  image:
    tag: "1.3.0"
```

**After (v2.5.1):**

```yaml
# Chart.yaml
appVersion: "1.4.0"

# values.yaml
app:
  image:
    tag: "1.4.0"
```

#### Operational impact

- **Existing deployments**: If you have not overridden `app.image.tag` in your values overlay, the upgrade will automatically pull and deploy the `1.4.0` image. Kubernetes will perform a rolling restart of the application pods.

- **Custom image tag overrides**: If you explicitly set `app.image.tag` in your values overlay to pin a specific version, the upgrade will not change your deployed image. You must manually update your values overlay to `1.4.0` to receive the application update:

```yaml
app:
  image:
    tag: "1.4.0"
```

> **Note:** The application version bump from `1.3.0` to `1.4.0` indicates a minor version upgrade of the plugin-br-payments application. Review the application's release notes for `1.4.0` to understand new features, bug fixes, or behavioral changes that may affect your deployment.

> **Important:** The rolling restart triggered by the image change will cause brief downtime for individual pods. Ensure your deployment has multiple replicas and appropriate `PodDisruptionBudget` settings if you require zero-downtime upgrades.

## Configuration Changes

| Setting | v2.5.0 | v2.5.1 |
|---------|--------|--------|
| `app.image.tag` | `"1.3.0"` | `"1.4.0"` |

No other configuration values were added, removed, or changed.

## Migration Steps

1. **(Optional)** If you override `app.image.tag` in your values overlay, update it to `1.4.0`:

```yaml
app:
  image:
    tag: "1.4.0"
```

2. **Run the upgrade** during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. **Monitor the rolling restart** of application pods:

```bash
kubectl rollout status deployment -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments-helm
```

4. **Verify all pods are running the new image version**:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments-helm -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

Expected output should show image tag `1.4.0` for all pods.

5. **Verify application health** after the upgrade:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments-helm
```

All pods should be in `Running` state with ready status `1/1` (or your configured replica count).

> **Warning:** If pods fail to start after the upgrade, check the pod logs for application errors related to the `1.4.0` version. You may need to roll back to `2.5.0` while investigating compatibility issues.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.5.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.5.1
```
