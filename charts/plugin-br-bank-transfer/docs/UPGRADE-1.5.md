# Helm Upgrade from v1.4.x to v1.5.x
## Topics
- **[Overview](#overview)**- **[Version changes](#version-changes)**- **[Configuration changes](#configuration-changes)**- **[Template changes](#template-changes)**- **[Migration steps](#migration-steps)**- **[Preview changes before upgrading](#preview-changes-before-upgrading)**- **[Command to upgrade](#command-to-upgrade)**

## Overview
This guide covers the `plugin-br-bank-transfer` chart upgrade from `1.4.0` to `1.5.0-beta.1`. It was generated retroactively from the chart history and focuses on minor version changes; patch-only releases are intentionally ignored.

Because this is a minor upgrade, the expected path is an in-place Helm upgrade after reviewing new values and changed defaults.

## Version changes

| Field | Previous | Current |
|-------|----------|---------|
| Chart version | `1.4.0` | `1.5.0-beta.1` |
| App version | `2.4.0` | `2.4.0` |

## Configuration changes

### Added values

_No direct values.yaml key changes detected._

### Removed values

_No direct values.yaml key changes detected._

### Changed operational values

_No image, env, secret, probe, ingress, service, port, or enablement changes detected in values.yaml._

## Template changes

### Added files

- No chart files added.

### Removed files

- No chart files removed.

### Modified files

- `charts/plugin-br-bank-transfer/Chart.yaml`
- `charts/plugin-br-bank-transfer/templates/deployment.yaml`
- `charts/plugin-br-bank-transfer/values.yaml`

## Migration steps

1. Read this guide and compare your custom values against `charts/plugin-br-bank-transfer/values.yaml`.
2. Add any required new values for your environment, especially secrets, configmaps, probes, ingress, and service settings.
3. Render the chart locally with your production values and review the manifest diff.
4. Apply the upgrade in a controlled environment before production.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer ./charts/plugin-br-bank-transfer \
  --namespace <namespace> \
  --values <your-values.yaml>
```

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer ./charts/plugin-br-bank-transfer \
  --namespace <namespace> \
  --values <your-values.yaml>
```
