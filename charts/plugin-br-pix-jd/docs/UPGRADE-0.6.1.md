# Helm Upgrade from v0.6.0 to v0.6.1

## Topics

- **[Overview](#overview)**
- **[What Changed](#what-changed)**
  - [Application Version Update](#application-version-update)
  - [Image Tag Updates](#image-tag-updates)
- **[Migration Impact](#migration-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** that updates the `plugin-br-pix-jd` chart from version 0.6.0 to 0.6.1. The primary change is the promotion of the application from beta to stable release (1.6.0-beta.3 → 1.6.0), with corresponding image tag updates across all components.

| Setting | v0.6.0 | v0.6.1 |
|---------|--------|--------|
| Chart Version | 0.6.0 | 0.6.1 |
| App Version | 1.6.0-beta.3 | 1.6.0 |
| API Image Tag | 1.6.0-beta.3 | 1.6.0 |
| Worker Image Tag | 1.6.0-beta.3 | 1.6.0 |
| Migrations Image Tag | 1.5.0 | 1.6.0 |

## What Changed

### Application Version Update

The chart's `appVersion` has been updated from `1.6.0-beta.3` to `1.6.0`, marking the transition from beta to stable release. This is a production-ready release with no breaking changes from the beta version.

**Chart.yaml change:**

| Field | v0.6.0 | v0.6.1 |
|-------|--------|--------|
| `appVersion` | 1.6.0-beta.3 | 1.6.0 |

### Image Tag Updates

All component image tags have been updated to align with the stable 1.6.0 release:

#### API Component

The API image tag has been updated to the stable release:

**values.yaml change:**

| Field | v0.6.0 | v0.6.1 |
|-------|--------|--------|
| `api.image.tag` | 1.6.0-beta.3 | 1.6.0 |

**Default configuration (v0.6.1):**

```yaml
api:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    tag: "1.6.0"
    pullPolicy: IfNotPresent
```

#### Worker Component

The worker image tag has been updated to match the API version:

**values.yaml change:**

| Field | v0.6.0 | v0.6.1 |
|-------|--------|--------|
| `worker.image.tag` | 1.6.0-beta.3 | 1.6.0 |

**Default configuration (v0.6.1):**

```yaml
worker:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.6.0"
    pullPolicy: IfNotPresent
```

#### Migrations Component

The migrations image tag has been updated from 1.5.0 to 1.6.0:

**values.yaml change:**

| Field | v0.6.0 | v0.6.1 |
|-------|--------|--------|
| `migrations.image.tag` | 1.5.0 | 1.6.0 |

**Default configuration (v0.6.1):**

```yaml
migrations:
  image:
    tag: "1.6.0"
    pullPolicy: IfNotPresent
```

## Migration Impact

**No configuration changes required.** This upgrade can be applied directly to existing v0.6.0 installations without modifying your values file.

The upgrade will:

- **Run the migrations Job** (if enabled) with the 1.6.0 migrations image
- **Roll out new API pods** with the stable 1.6.0 image
- **Roll out new worker pods** (if enabled) with the stable 1.6.0 image

> **Note:** If you have explicitly pinned image tags in your values file (e.g., `api.image.tag: "1.6.0-beta.3"`), you should update them to `"1.6.0"` or remove the override to use the chart's default:

```yaml
api:
  image:
    tag: "1.6.0"

worker:
  image:
    tag: "1.6.0"
```

> **Note:** The upgrade follows standard rolling update behavior. With the default deployment strategy (`RollingUpdate` with `maxUnavailable: 0`), the API will maintain availability throughout the rollout.

## Preview changes before upgrading

```bash
helm diff upgrade <pix-release> oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.6.1 -n midaz-plugins
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <pix-release> oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.6.1 -n midaz-plugins
```

Replace `<pix-release>` with your release name.
