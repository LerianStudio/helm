# Helm Upgrade from v2.3.1 to v2.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version bump to 1.3.0](#1-application-version-bump-to-130)
  - [2. Default image tag pinning](#2-default-image-tag-pinning)
  - [3. Values formatting cleanup](#3-values-formatting-cleanup)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.3.1` to `2.4.0`. The application version advances from `1.2.0` to `1.3.0`, and the chart introduces a default image tag pin to `1.3.0` to ensure consistent deployments. The upgrade also includes formatting cleanup in `values.yaml` (removal of extra blank lines and comment indentation fixes) that does not affect functionality.

This upgrade requires no operator action beyond running the upgrade command unless you explicitly override `app.image.tag` in your values overlay. Existing deployments that rely on the chart's default tag behavior will automatically pull the `1.3.0` image.

## Features

### 1. Application version bump to 1.3.0

The `appVersion` field in `Chart.yaml` was updated from `1.2.0` to `1.3.0`, reflecting a new release of the `plugin-br-payments` application binary. The application version is the version of the software running inside the container, not the chart version itself.

**Before (v2.3.1):**

```yaml
appVersion: "1.2.0"
```

**After (v2.4.0):**

```yaml
appVersion: "1.3.0"
```

**Operational impact:**

The `appVersion` field is informational and does not directly control the container image tag. However, the chart's default image tag logic uses `Chart.appVersion` when `app.image.tag` is empty. In v2.4.0, the default tag is explicitly set to `"1.3.0"` (see [2. Default image tag pinning](#2-default-image-tag-pinning)), so deployments that do not override `app.image.tag` will pull the `1.3.0` image.

### 2. Default image tag pinning

The `app.image.tag` field in `values.yaml` now defaults to `"1.3.0"` instead of an empty string. Previously, when `app.image.tag` was empty, the chart's image helper template would fall back to `Chart.appVersion`. The new default makes the image tag explicit in the values file, improving clarity and preventing unintended image pulls when `Chart.appVersion` changes.

**Before (v2.3.1):**

```yaml
app:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-payments
    pullPolicy: IfNotPresent
    tag: ""
```

**After (v2.4.0):**

```yaml
app:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-payments
    pullPolicy: IfNotPresent
    tag: "1.3.0"
```

**Operational impact:**

Deployments that do not override `app.image.tag` in their values overlay will now explicitly use the `1.3.0` image. If you have pinned `app.image.tag` to a specific version in your values overlay (e.g., `tag: "1.2.0"`), your override will continue to take precedence, and the upgrade will not change your running image version.

> **Important:** If you rely on the chart's default image tag and want to stay on `1.2.0`, you must now explicitly set `app.image.tag: "1.2.0"` in your values overlay before upgrading to v2.4.0.

### 3. Values formatting cleanup

The `values.yaml` file was reformatted to remove extra blank lines between top-level sections and to correct comment indentation for the `app.configmap` and `app.secrets` blocks. The comments were previously indented as if they were part of the `configmap: {}` and `secrets: {}` map values; they are now aligned at the same level as the keys, matching standard YAML comment style.

**Before (v2.3.1):**

```yaml
  configmap: {}
    # BTG_API_BASE_URL: "https://api.btgpactual.com"
    # BTG_AUTH_URL: "https://id.btgpactual.com/oauth2/token"
    # MIDAZ_LEDGER_URL: "https://midaz-ledger.example.com/v1"
```

**After (v2.4.0):**

```yaml
  configmap: {}
  # BTG_API_BASE_URL: "https://api.btgpactual.com"
  # BTG_AUTH_URL: "https://id.btgpactual.com/oauth2/token"
  # MIDAZ_LEDGER_URL: "https://midaz-ledger.example.com/v1"
```

**Operational impact:**

This change is purely cosmetic and does not affect the rendered Kubernetes manifests. No operator action is required. If you maintain a values overlay that copies the comment structure from the upstream `values.yaml`, you may optionally update your overlay to match the new formatting for consistency.

## Configuration Changes

| Setting | v2.3.1 | v2.4.0 |
|---------|--------|--------|
| `Chart.yaml` `version` | `2.3.1` | `2.4.0` |
| `Chart.yaml` `appVersion` | `"1.2.0"` | `"1.3.0"` |
| `app.image.tag` | `""` (empty, falls back to `Chart.appVersion`) | `"1.3.0"` |

No configuration values were added or removed. The only functional change is the default value of `app.image.tag`.

## Migration Steps

1. **(Optional)** If you want to stay on application version `1.2.0` and not upgrade to `1.3.0`, explicitly set `app.image.tag: "1.2.0"` in your values overlay before running the upgrade command:

```yaml
app:
  image:
    tag: "1.2.0"
```

2. **(Optional)** If you override `app.image.tag` in your values overlay to a version other than `1.2.0` or `1.3.0`, verify that your override is still correct. The chart will respect your override and will not use the new default.

3. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n midaz-plugins
```

5. Confirm the running image version matches your expectation:

```bash
kubectl get deployment -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
```

Expected output (if you did not override `app.image.tag`):

```
ghcr.io/lerianstudio/plugin-br-payments:1.3.0
```

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.4.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.4.0
```
