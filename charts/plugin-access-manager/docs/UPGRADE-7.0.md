# Helm Upgrade from v6.x to v7.x

# Topics

- **[Features](#features)**
  - [1. Application Version Updates](#1-application-version-updates)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Application Version Updates

This release updates the application versions for all three services in the plugin-access-manager chart.

| Service | v6.5.0 | v7.0.0 |
|---------|--------|--------|
| Identity | 2.4.4 | 2.4.5 |
| Auth | 2.6.5 | 2.6.6 |
| Auth Backend | 2.6.5 | 2.6.6 |
| Chart appVersion | 2.6.5 | 2.6.6 |

**What this means for operators:**

These are patch version updates that include bug fixes and improvements. The upgrade should be seamless with no configuration changes required.

**Why this is a major version bump:**

While the application versions are patch updates, this chart release is marked as v7.0.0 (a major version) to follow semantic versioning practices. This indicates that the chart maintainers want to signal a significant milestone or prepare for potential breaking changes in the deployment lifecycle. However, no breaking configuration changes are present in this release.

**Default behavior:**

The new image tags will be pulled automatically during the upgrade. If you have overridden the image tags in your `values.yaml`, you may want to update them to use the latest versions:

```yaml
identity:
  image:
    tag: "2.4.5"

auth:
  image:
    tag: "2.6.6"
  
  backend:
    image:
      tag: "2.6.6"
```

> **Note:** If you're using `pullPolicy: Always`, the new images will be pulled automatically. If you're using `pullPolicy: IfNotPresent`, ensure your nodes pull the updated images or temporarily switch to `Always` during the upgrade.

# Configuration Reference

No new configuration options were introduced in this release. All existing configuration from v6.5.0 remains valid and unchanged.

The only modifications are the default image tags in the following sections of `values.yaml`:

```yaml
identity:
  image:
    repository: lerianstudio/identity
    pullPolicy: Always
    tag: "2.4.5"  # Updated from 2.4.4
```

```yaml
auth:
  image:
    repository: lerianstudio/auth
    pullPolicy: Always
    tag: "2.6.6"  # Updated from 2.6.5
```

```yaml
auth:
  backend:
    image:
      repository: lerianstudio/auth-backend
      pullPolicy: Always
      tag: "2.6.6"  # Updated from 2.6.5
```

**If you have customized image tags:**

Review your current `values.yaml` overrides. If you've pinned specific versions, consider updating to the new defaults:

```yaml
# Your current values.yaml (example)
identity:
  image:
    tag: "2.4.4"  # Consider updating to 2.4.5

auth:
  image:
    tag: "2.6.5"  # Consider updating to 2.6.6
  
  backend:
    image:
      tag: "2.6.5"  # Consider updating to 2.6.6
```

> **Important:** If you maintain custom image tags for compliance or testing reasons, ensure your images are compatible with chart version 7.0.0. The chart templates have not changed, so any v6.5.0-compatible images should work with v7.0.0.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 7.0.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 7.0.0 -n plugin-access-manager
```
