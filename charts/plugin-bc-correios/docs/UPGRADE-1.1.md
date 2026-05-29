# Helm Upgrade from v1.0.x to v1.1.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version bump to 1.2.0](#1-application-version-bump-to-120)
  - [2. br-spb-bc-correios sibling image tag pinned](#2-br-spb-bc-correios-sibling-image-tag-pinned)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that updates the application version of the BC Correios plugin and pins the image tag of the `br-spb-bc-correios` sibling component. No breaking changes are introduced and no manual data migration is required.

## Features

### 1. Application version bump to 1.2.0

The chart now ships with `appVersion` `1.2.0`, replacing the previous `1.0.0`. The chart version itself moves from `1.0.1` to `1.1.0-beta.1`.

| Component   | v1.0.1  | v1.1.0-beta.1   |
|-------------|---------|-----------------|
| version     | 1.0.1   | 1.1.0-beta.1    |
| appVersion  | 1.0.0   | 1.2.0           |

The `bc-correios.image.tag` value in `values.yaml` still defaults to `"1.0.0"`. The runtime image tag is rendered by the CI/CD pipeline through the existing `helm_values_key_mappings` declared in `values.yaml`:

```yaml
# helm_values_key_mappings: '{"plugin-bc-correios": "bc-correios"}'
```

If you set `bc-correios.image.tag` explicitly in your overrides, align it with the new `appVersion`:

```yaml
bc-correios:
  image:
    repository: lerianstudio/plugin-bc-correios
    tag: "1.2.0"
```

> **Note:** For application-level changes included in version 1.2.0, refer to the [plugin-bc-correios changelog](https://github.com/LerianStudio/plugin-bc-correios).

### 2. br-spb-bc-correios sibling image tag pinned

A new top-level `br-spb-bc-correios` block is added to `values.yaml`, pinning the image tag of the sibling SPB BC Correios component to `1.2.0`.

| Component                      | v1.0.1  | v1.1.0-beta.1 |
|--------------------------------|---------|---------------|
| br-spb-bc-correios.image.tag   | _unset_ | 1.2.0         |

```yaml
br-spb-bc-correios:
  image:
    tag: 1.2.0
```

If you already override this value, review your override against the new chart default. No other keys are introduced.

## Configuration Changes

No keys are removed or renamed in this release. The following table summarizes the value changes:

| Setting                      | v1.0.1  | v1.1.0-beta.1 |
|------------------------------|---------|---------------|
| Chart `version`              | 1.0.1   | 1.1.0-beta.1  |
| Chart `appVersion`           | 1.0.0   | 1.2.0         |
| `br-spb-bc-correios.image.tag` | _unset_ | 1.2.0       |

All existing `values.yaml` settings remain compatible with version 1.1.0-beta.1.

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will roll the pods with the new image tags.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))
2. Ensure you have a recent backup of your data (if using chart-managed databases)
3. Run the upgrade command during a maintenance window
4. Verify all pods are running and healthy after the upgrade

```bash
kubectl get pods -n <namespace>
```

5. Check service logs for any startup issues

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-bc-correios-helm --tail=50
```

> **Note:** The upgrade will trigger a rolling restart of the BC Correios pods. Depending on your replica count and readiness probe configuration, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 1.1.0-beta.1 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 1.1.0-beta.1 -n <namespace>
```
