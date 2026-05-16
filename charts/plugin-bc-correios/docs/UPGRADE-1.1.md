# Helm Upgrade from v1.0.x to v1.1.x
## Topics
- **[Overview](#overview)**- **[Version changes](#version-changes)**- **[Configuration changes](#configuration-changes)**- **[Template changes](#template-changes)**- **[Migration steps](#migration-steps)**- **[Preview changes before upgrading](#preview-changes-before-upgrading)**- **[Command to upgrade](#command-to-upgrade)**

## Overview
This guide covers the `plugin-bc-correios` chart upgrade from `1.0.1` to `1.1.0-beta.1`. It was generated retroactively from the chart history and focuses on minor version changes; patch-only releases are intentionally ignored.

Because this is a minor upgrade, the expected path is an in-place Helm upgrade after reviewing new values and changed defaults.

## Version changes

| Field | Previous | Current |
|-------|----------|---------|
| Chart version | `1.0.1` | `1.1.0-beta.1` |
| App version | `1.0.0` | `1.2.0` |

## Configuration changes

### Added values

```yaml
br-spb-bc-correios.image.tag: "1.2.0"
```

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

- `charts/plugin-bc-correios/Chart.yaml`
- `charts/plugin-bc-correios/values.yaml`

## Migration steps

1. Read this guide and compare your custom values against `charts/plugin-bc-correios/values.yaml`.
2. Add any required new values for your environment, especially secrets, configmaps, probes, ingress, and service settings.
3. Render the chart locally with your production values and review the manifest diff.
4. Apply the upgrade in a controlled environment before production.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-bc-correios ./charts/plugin-bc-correios \
  --namespace <namespace> \
  --values <your-values.yaml>
```

## Command to upgrade

```bash
helm upgrade plugin-bc-correios ./charts/plugin-bc-correios \
  --namespace <namespace> \
  --values <your-values.yaml>
```
