# Helm Upgrade from v2.2.x to v2.3.x
## Topics
- **[Overview](#overview)**- **[Version changes](#version-changes)**- **[Configuration changes](#configuration-changes)**- **[Template changes](#template-changes)**- **[Migration steps](#migration-steps)**- **[Preview changes before upgrading](#preview-changes-before-upgrading)**- **[Command to upgrade](#command-to-upgrade)**

## Overview
This guide covers the `plugin-br-pix-direct-jd` chart upgrade from `2.2.11` to `2.3.0-beta.1`. It was generated retroactively from the chart history and focuses on minor version changes; patch-only releases are intentionally ignored.

Because this is a minor upgrade, the expected path is an in-place Helm upgrade after reviewing new values and changed defaults.

## Version changes

| Field | Previous | Current |
|-------|----------|---------|
| Chart version | `2.2.11` | `2.3.0-beta.1` |
| App version | `1.2.1-beta.11` | `1.2.1-beta.11` |

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

- `charts/plugin-br-pix-direct-jd/CHANGELOG.md`
- `charts/plugin-br-pix-direct-jd/Chart.yaml`
- `charts/plugin-br-pix-direct-jd/templates/plugin-br-pix-direct-jd/deployment.yaml`
- `charts/plugin-br-pix-direct-jd/values.yaml`

## Migration steps

1. Read this guide and compare your custom values against `charts/plugin-br-pix-direct-jd/values.yaml`.
2. Add any required new values for your environment, especially secrets, configmaps, probes, ingress, and service settings.
3. Render the chart locally with your production values and review the manifest diff.
4. Apply the upgrade in a controlled environment before production.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-direct-jd ./charts/plugin-br-pix-direct-jd \
  --namespace <namespace> \
  --values <your-values.yaml>
```

## Command to upgrade

```bash
helm upgrade plugin-br-pix-direct-jd ./charts/plugin-br-pix-direct-jd \
  --namespace <namespace> \
  --values <your-values.yaml>
```
