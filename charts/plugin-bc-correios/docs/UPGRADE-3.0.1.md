# Helm Upgrade from v3.0.0 to v3.0.1

## Topics

- **[Overview](#overview)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that increments the chart version from 3.0.0 to 3.0.1. No changes have been made to the application version, values schema, or template files. This release contains no functional changes, breaking changes, or new features. Operators can upgrade without modifying their existing values files or performing any manual migration steps.

## Configuration Changes

The only change in this release is the chart version bump:

| Setting         | v3.0.0 | v3.0.1 |
|-----------------|--------|--------|
| Chart `version` | 3.0.0  | 3.0.1  |

All existing `values.yaml` settings remain fully compatible with version 3.0.1. No values have been added, removed, or modified.

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will complete without triggering any pod restarts or configuration changes, as no templates or values have been modified.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))

2. Run the upgrade command:

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 3.0.1 -n <namespace>
```

3. Verify the chart version has been updated:

```bash
helm list -n <namespace>
```

> **Note:** This upgrade will not trigger a rolling restart of pods. The running workloads will remain unchanged.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 3.0.1 -n plugin-bc-correios
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 3.0.1 -n plugin-bc-correios
```
