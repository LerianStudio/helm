# Helm Upgrade from v2.2.0 to v2.2.1

## Topics

- **[Features](#features)**
  - [1. Application Version Upgrade to 1.6.0](#1-application-version-upgrade-to-160)
  - [2. Image Tag Pinning for All Components](#2-image-tag-pinning-for-all-components)
  - [3. Chart.yaml Formatting Cleanup](#3-chartyaml-formatting-cleanup)
  - [4. Values.yaml Formatting Cleanup](#4-valuesyaml-formatting-cleanup)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application Version Upgrade to 1.6.0

**What changed:**

The chart's `appVersion` has been updated from `1.3.0` to `1.6.0`, reflecting the underlying application version deployed by this chart.

| Setting | v2.2.0 | v2.2.1 |
|---------|--------|--------|
| `appVersion` | `1.3.0` | `1.6.0` |

**Why it matters:**

The `appVersion` field in `Chart.yaml` documents the version of the application being deployed. This update indicates that the chart now deploys application version `1.6.0`, which may include bug fixes, features, or other changes from the application's release cycle.

**How to handle it:**

No action is required. The application version is informational and does not affect the chart's behavior. The actual container images deployed are controlled by the `image.tag` values for each component (see [Image Tag Pinning](#2-image-tag-pinning-for-all-components)).

**After (v2.2.1) Chart.yaml:**

```yaml
# This is the version number of the application being deployed.
appVersion: "1.6.0"
```

### 2. Image Tag Pinning for All Components

**What changed:**

All components now have their `image.tag` explicitly set to `"1.6.0"` in `values.yaml`. Previously, these tags were empty strings (`""`), which caused the chart to fall back to `Chart.AppVersion`.

| Component | v2.2.0 | v2.2.1 |
|-----------|--------|--------|
| `spi.image.tag` | `""` | `"1.6.0"` |
| `spiSystemplane.image.tag` | `""` | `"1.6.0"` |
| `adapterProviderMock.image.tag` | `""` | `"1.6.0"` |
| `dictHub.image.tag` | `""` | `"1.6.0"` |

**Why it matters:**

Pinning the image tag explicitly in `values.yaml` makes the deployed version more visible and easier to override per environment. Previously, operators had to know that an empty `image.tag` would fall back to `Chart.AppVersion`. Now, the deployed version is explicit in the values file.

**How to handle it:**

#### If you have not overridden image.tag

No action is required. The chart will now deploy version `1.6.0` of each component image, which is the same behavior as before (since `Chart.AppVersion` is also `1.6.0`).

#### If you have overridden image.tag in your values

Your override will continue to take precedence. The new default of `"1.6.0"` only applies when you do not set `<component>.image.tag` in your values.

**After (v2.2.1) values.yaml:**

```yaml
spi:
  image:
    repository: "ghcr.io/lerianstudio/plugin-br-pix-lerian-spi-api"
    pullPolicy: ""
    tag: "1.6.0"

spiSystemplane:
  image:
    repository: "ghcr.io/lerianstudio/plugin-br-pix-lerian-spi-systemplane-api"
    pullPolicy: ""
    tag: "1.6.0"

adapterProviderMock:
  image:
    repository: "ghcr.io/lerianstudio/plugin-br-pix-lerian-adapter-provider-mock-api"
    pullPolicy: ""
    tag: "1.6.0"

dictHub:
  image:
    repository: "ghcr.io/lerianstudio/plugin-br-pix-lerian-dict-hub-api"
    pullPolicy: ""
    tag: "1.6.0"
```

> **Note:** The diff shows changes for `spi`, `spiSystemplane`, `adapterProviderMock`, and `dictHub`. All other components in the chart follow the same pattern and have been updated to `tag: "1.6.0"`.

### 3. Chart.yaml Formatting Cleanup

**What changed:**

The `Chart.yaml` file has been reformatted to remove excessive blank lines between sections. No functional metadata has changed.

**Why it matters:**

This is a cosmetic change that improves readability and consistency. It does not affect the chart's behavior or the resources deployed.

**How to handle it:**

No action is required. This change is transparent to operators.

**Before (v2.2.0) Chart.yaml:**

```yaml
type: application
annotations:
  lerian.studio/chart-type: multi-component

home: https://github.com/LerianStudio/helm

# A list of maintainers who are responsible for the chart
maintainers:
  - name: "Lerian Studio"
    email: "support@lerian.studio"

# This is the chart version. This version number should be incremented each time you make changes
# to the chart and its templates, including the app version.

version: 2.2.0

# This is the version number of the application being deployed.
appVersion: "1.3.0"
```

**After (v2.2.1) Chart.yaml:**

```yaml
type: application
annotations:
  lerian.studio/chart-type: multi-component
home: https://github.com/LerianStudio/helm
# A list of maintainers who are responsible for the chart
maintainers:
  - name: "Lerian Studio"
    email: "support@lerian.studio"
# This is the chart version. This version number should be incremented each time you make changes
# to the chart and its templates, including the app version.
version: 2.2.1
# This is the version number of the application being deployed.
appVersion: "1.6.0"
```

### 4. Values.yaml Formatting Cleanup

**What changed:**

The `values.yaml` file has been reformatted to remove excessive blank lines between configuration blocks and to normalize inline comment spacing. No configuration keys, values, or defaults have changed.

**Why it matters:**

This is a cosmetic change that improves readability and consistency. It does not affect the chart's behavior or the resources deployed.

**How to handle it:**

No action is required. This change is transparent to operators. If you maintain custom values files, you may optionally reformat them to match the new style, but this is not required.

**Example changes:**

**Before (v2.2.0) values.yaml:**

```yaml
# Override the chart name in resource names
nameOverride: ""
fullnameOverride: ""

# Override the namespace where resources are created. Defaults to
# .Release.Namespace (the -n flag passed to helm install).
namespaceOverride: ""

# =============================================================================
# GLOBAL DEFAULTS — applied to all components unless overridden in their block
# =============================================================================
global:
  # -- Image pull secrets propagated to every component when the component's
  # own `imagePullSecrets` list is empty.
  imagePullSecrets: []

  # ---------------------------------------------------------------------------
```

**After (v2.2.1) values.yaml:**

```yaml
# Override the chart name in resource names
nameOverride: ""
fullnameOverride: ""
# Override the namespace where resources are created. Defaults to
# .Release.Namespace (the -n flag passed to helm install).
namespaceOverride: ""
# =============================================================================
# GLOBAL DEFAULTS — applied to all components unless overridden in their block
# =============================================================================
global:
  # -- Image pull secrets propagated to every component when the component's
  # own `imagePullSecrets` list is empty.
  imagePullSecrets: []
  # ---------------------------------------------------------------------------
```

**Before (v2.2.0) values.yaml:**

```yaml
    postgresAdminLogin:
      useExistingSecret:
        name: ""   # PRODUCTION: set this, leave password empty
      username: "postgres"
      password: ""   # required when useExistingSecret.name is empty
```

**After (v2.2.1) values.yaml:**

```yaml
    postgresAdminLogin:
      useExistingSecret:
        name: "" # PRODUCTION: set this, leave password empty
      username: "postgres"
      password: "" # required when useExistingSecret.name is empty
```

## Preview changes before upgrading

```bash
helm diff upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.2.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.2.1
```
