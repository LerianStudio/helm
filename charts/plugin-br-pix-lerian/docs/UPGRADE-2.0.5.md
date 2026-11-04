<!-- {% raw %} -->
# Helm Upgrade from v2.0.4 to v2.0.5

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Pod templates no longer carry the chart version label](#1-pod-templates-no-longer-carry-the-chart-version-label)
  - [2. Checksum annotations hash only ConfigMap and Secret data](#2-checksum-annotations-hash-only-configmap-and-secret-data)
  - [3. adapterProviderMock has no default PROVIDER_BASE_URL](#3-adapterprovidermock-has-no-default-provider_base_url)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Overview

The chart version changes from `2.0.4` to `2.0.5`. The application version (`appVersion: "1.1.0"`) does not change.

No action is required, with one exception: if you enabled `adapterProviderMock` and relied on its default `PROVIDER_BASE_URL`, set it before you upgrade (see change 3). Every enabled Deployment restarts its pods once during this upgrade.

## Changes

### 1. Pod templates no longer carry the chart version label

The `helm.sh/chart` label is removed from the pod templates of every Deployment. Resource metadata, including the Deployments themselves, keeps the label. Selectors do not change.

**Why it matters:** The pod template differs from v2.0.4, so every enabled Deployment rolls its pods once. From this release on, a chart version bump alone no longer restarts pods.

**How to handle it:** No action is required. Plan for the single rolling restart.

### 2. Checksum annotations hash only ConfigMap and Secret data

The `checksum/configmap` and `checksum/secret` pod annotations now hash only the `data` of the ConfigMap and the `stringData` of the Secret. Before, they hashed the whole rendered manifest, so the chart version label changed them on every release.

**Why it matters:** A change to a ConfigMap or Secret value still restarts the pods that use it. A chart version change alone does not.

**How to handle it:** No action is required.

### 3. adapterProviderMock has no default PROVIDER_BASE_URL

`adapterProviderMock.configmap.PROVIDER_BASE_URL` now defaults to an empty string. v2.0.4 defaulted it to a Lerian sandbox mock server URL.

`adapterProviderMock` ships `enabled: false` and is for development and homologation only.

#### If you do not enable adapterProviderMock

No action is required.

#### If you enable adapterProviderMock

Set `PROVIDER_BASE_URL` to your mock provider server. The component needs it, together with `PROVIDER_CLIENT_ID` and `PROVIDER_CLIENT_SECRET`, which you already set.

```yaml
adapterProviderMock:
  configmap:
    PROVIDER_BASE_URL: "<your mock provider server URL>"
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-lerian oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace plugin-br-pix-lerian --version 2.0.5
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-lerian oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace plugin-br-pix-lerian --version 2.0.5
```

## Verify

```bash
kubectl rollout status deployment -n plugin-br-pix-lerian -l app.kubernetes.io/instance=plugin-br-pix-lerian
```

If you enabled `adapterProviderMock`, confirm it is running and that its ConfigMap holds your URL:

```bash
kubectl get configmap -n plugin-br-pix-lerian plugin-br-pix-lerian-adapter-provider-mock -o jsonpath='{.data.PROVIDER_BASE_URL}'
```
<!-- {% endraw %} -->
