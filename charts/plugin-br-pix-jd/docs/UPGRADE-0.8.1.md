# Helm Upgrade from v0.8.0 to v0.8.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** that updates the application version from 1.6.1 to 1.7.0 across all components. The chart version increments from 0.8.0 to 0.8.1 with no changes to templates, configuration structure, or default values.

| Setting | v0.8.0 | v0.8.1 |
|---------|--------|--------|
| Chart Version | 0.8.0 | 0.8.1 |
| App Version | 1.6.1 | 1.7.0 |
| API Image Tag | 1.6.1 | 1.7.0 |
| Worker Image Tag | 1.6.1 | 1.7.0 |
| Migrations Image Tag | 1.6.1 | 1.7.0 |

## Application Version Update

The upgrade updates the container image tags for all three components to version 1.7.0:

**API component:**

```yaml
api:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    tag: "1.7.0"
```

**Worker component:**

```yaml
worker:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.7.0"
```

**Migrations job:**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.7.0"
```

> **Note:** If you have explicitly pinned image tags in your `values.yaml` (recommended for production), those pins will override the chart defaults. Review your values file and update any explicit `tag` overrides to `"1.7.0"` if you want to adopt the new application version.

> **Important:** The upgrade will trigger a rolling restart of the API deployment and a recreation of the worker deployment (if enabled). The migrations job will run during the upgrade hook phase if `migrations.enabled=true`.

**No configuration changes required.** This upgrade maintains full compatibility with existing v0.8.0 deployments. All template files, default values, and configuration structure remain unchanged.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.8.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.8.1
```
