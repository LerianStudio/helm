# Helm Upgrade from v10.0.1 to v10.0.2

## Topics

- **[Fixes](#fixes)**
  - [1. Chart version metadata update](#1-chart-version-metadata-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Chart version metadata update

This is a patch release that updates only the chart version metadata in `Chart.yaml`. No functional changes, configuration updates, or template modifications are included in this release.

#### What changed

The chart version has been incremented from `10.0.1` to `10.0.2` to maintain proper semantic versioning. The application version (`appVersion: "4.3.0"`) remains unchanged.

| Setting | v10.0.1 | v10.0.2 |
|---------|---------|---------|
| Chart version | `10.0.1` | `10.0.2` |
| App version | `4.3.0` | `4.3.0` |

#### Why this matters

This release ensures the chart version is properly tracked in Helm's release history. While no configuration or deployment changes occur, upgrading to `10.0.2` keeps your installation aligned with the latest chart metadata.

#### Migration impact

**No action required.** This upgrade:
- Does not modify any deployed resources
- Does not change any default values or configuration
- Does not require any values.yaml updates
- Does not trigger pod restarts or service disruptions

The upgrade will complete immediately with no observable changes to running workloads.

> **Note:** You can safely upgrade from `10.0.1` to `10.0.2` without reviewing your current configuration or planning downtime.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.2 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.2 -n midaz
```
