<!-- {% raw %} -->
# Helm Upgrade from v5.4.1 to v5.5.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version upgrade to 1.15.0](#1-application-version-upgrade-to-1150)
  - [2. License file path configuration](#2-license-file-path-configuration)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that upgrades the application version from `1.14.1` to `1.15.0` across all five components (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) and introduces a new `LICENSE_FILE_PATH` environment variable for each component. The chart version moves from `5.4.1` to `5.5.0`.

No values are removed or renamed. The new `LICENSE_FILE_PATH` configuration is additive and defaults to an empty string, preserving backward compatibility with existing deployments that use the `LICENSE_KEY` secret approach.

The expected upgrade path is an in-place Helm upgrade. All component deployments will perform a rolling restart due to the image tag and ConfigMap changes.

## Features

### 1. Application version upgrade to 1.15.0

All five component images are upgraded from `1.14.1` to `1.15.0`. This affects the container image tags for `pix`, `inbound`, `outbound`, `reconciliation`, and `schedule`.

**What changed:**

| Component | v5.4.1 image tag | v5.5.0 image tag |
|-----------|------------------|------------------|
| `pix` | `1.14.1` | `1.15.0` |
| `inbound` | `1.14.1` | `1.15.0` |
| `outbound` | `1.14.1` | `1.15.0` |
| `reconciliation` | `1.14.1` | `1.15.0` |
| `schedule` | `1.14.1` | `1.15.0` |

**Why it matters:**

The new application version may include bug fixes, performance improvements, or new features. Review the application release notes for `1.15.0` to understand the changes in the underlying service binaries.

**Operational impact:**

The upgrade will trigger a rolling restart of all five deployments. Depending on your replica count and readiness probe configuration, this may cause brief service interruptions. Plan the upgrade during a maintenance window if you run single replicas.

**Example configuration:**

The image tags are set automatically by the chart. If you need to pin a specific version or use a custom registry, override the image configuration per component:

```yaml
pix:
  image:
    repository: custom-registry.example.com/pix
    tag: "1.15.0"
    pullPolicy: IfNotPresent
```

### 2. License file path configuration

A new environment variable `LICENSE_FILE_PATH` is now configurable for all five components. This variable allows operators to specify a custom path to a license file mounted into the container, providing an alternative to the existing `LICENSE_KEY` secret-based approach.

**What changed:**

Each component's ConfigMap template now includes a `LICENSE_FILE_PATH` entry that reads from the corresponding `configmap` values block:

| Component | New ConfigMap key | Values path |
|-----------|-------------------|-------------|
| `pix` | `LICENSE_FILE_PATH` | `pix.configmap.LICENSE_FILE_PATH` |
| `inbound` | `LICENSE_FILE_PATH` | `inbound.configmap.LICENSE_FILE_PATH` |
| `outbound` | `LICENSE_FILE_PATH` | `outbound.configmap.LICENSE_FILE_PATH` |
| `reconciliation` | `LICENSE_FILE_PATH` | `reconciliation.configmap.LICENSE_FILE_PATH` |
| `schedule` | `LICENSE_FILE_PATH` | `schedule.configmap.LICENSE_FILE_PATH` |

**Before (v5.4.1):**

The ConfigMap templates did not include `LICENSE_FILE_PATH`. License configuration relied solely on the `LICENSE_KEY` secret or the `licenseFile.existingSecret` volume mount at `/etc/lerian/license`.

**After (v5.5.0):**

Each ConfigMap template includes:

```yaml
LICENSE_FILE_PATH: {{ .Values.<component>.configmap.LICENSE_FILE_PATH | default "" | quote }}
```

**Why it matters:**

This change adds ConfigMap overrides for an explicitly mounted license file. When `licenseFile.existingSecret` is set, the chart already mounts the Secret and explicitly sets `LICENSE_FILE_PATH=/etc/lerian/license/license` for every component; that environment entry takes precedence over the ConfigMap override.

**Operational impact:**

When the effective `LICENSE_FILE_PATH` is empty, application version `1.15.0` uses `LICENSE_KEY`; it does not automatically search default file paths. A nonempty `LICENSE_FILE_PATH` selects file-based licensing.

No ConfigMap path override is needed with `licenseFile.existingSecret`. For a license file mounted by another mechanism, leave `licenseFile.existingSecret` empty and set the actual file path per component; the following example assumes that mechanism mounts the file at `/etc/lerian/license/license`:

```yaml
pix:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"

inbound:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"

outbound:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"

reconciliation:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"

schedule:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"
```

> **Note:** The chart's `licenseFile.existingSecret` mounts the secret at `/etc/lerian/license` with the key `license`. If you use this feature, the full path to the license file is `/etc/lerian/license/license`.

> **Important:** If you mount a license file at a custom path (outside the chart's `licenseFile` mechanism), you must set `LICENSE_FILE_PATH` to that custom path for each component that requires it.

## Configuration Reference

The following override keys are supported by the ConfigMap templates and may be added to your custom values file. Their template default is an empty string; they are not listed in the chart's default `values.yaml`.

| Key | Default | Description |
|-----|---------|-------------|
| `pix.configmap.LICENSE_FILE_PATH` | `""` | Path to the license file for the `pix` component |
| `inbound.configmap.LICENSE_FILE_PATH` | `""` | Path to the license file for the `inbound` component |
| `outbound.configmap.LICENSE_FILE_PATH` | `""` | Path to the license file for the `outbound` component |
| `reconciliation.configmap.LICENSE_FILE_PATH` | `""` | Path to the license file for the `reconciliation` component |
| `schedule.configmap.LICENSE_FILE_PATH` | `""` | Path to the license file for the `schedule` component |

**Example values override:**

```yaml
pix:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"

inbound:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"

outbound:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"

reconciliation:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"

schedule:
  configmap:
    LICENSE_FILE_PATH: "/etc/lerian/license/license"
```

## Migration Steps

This upgrade requires no destructive migration steps. The new `LICENSE_FILE_PATH` configuration is optional and defaults to an empty string, preserving existing license configuration behavior.

**Recommended upgrade process:**

1. Review the application release notes for version `1.15.0` to understand any behavioral changes in the service binaries.

2. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

3. If using `licenseFile.existingSecret`, no path override is needed. For a file mounted by another mechanism, leave `licenseFile.existingSecret` empty and configure each component's `LICENSE_FILE_PATH` with its actual mounted path as shown in [Configuration Reference](#configuration-reference). The preview and upgrade commands below use `values.yaml`: this must be your complete maintained values file, preserving all installation-specific overrides, with the intended changes applied. Keep it outside version control and restrict its permissions if it contains secrets.

4. Run the upgrade command during a maintenance window.

5. Inspect all five application workloads after the upgrade. The commands below assume the documented release name and default component names; adapt both if overridden. Pod listing alone does not establish readiness; check the READY/STATUS columns and each Deployment's rollout status.

```bash
kubectl get pods -n midaz-plugins -l 'app.kubernetes.io/instance=plugin-br-pix-indirect-btg,app.kubernetes.io/name in (plugin-br-pix-indirect-btg,plugin-br-pix-indirect-btg-worker-inbound,plugin-br-pix-indirect-btg-worker-outbound,plugin-br-pix-indirect-btg-worker-reconciliation,plugin-br-pix-indirect-btg-worker-schedule)'
```

6. Check the logs of each component to confirm the license is loaded correctly:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg,app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
kubectl logs -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg,app.kubernetes.io/name=plugin-br-pix-indirect-btg-worker-inbound --tail=50
kubectl logs -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg,app.kubernetes.io/name=plugin-br-pix-indirect-btg-worker-outbound --tail=50
kubectl logs -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg,app.kubernetes.io/name=plugin-br-pix-indirect-btg-worker-reconciliation --tail=50
kubectl logs -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg,app.kubernetes.io/name=plugin-br-pix-indirect-btg-worker-schedule --tail=50
```

> **Note:** The upgrade triggers a rolling restart of all five deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) because the image tag and ConfigMap spec change. Depending on your replica count and probe timing, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.5.0 -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.5.0 -f values.yaml
```
<!-- {% endraw %} -->
