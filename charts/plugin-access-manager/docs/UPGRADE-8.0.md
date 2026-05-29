# Helm Upgrade from v7.x to v8.x

# Topics

- **[Features](#features)**
  - [1. Application Version Updates](#1-application-version-updates)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Application Version Updates

This release updates the application versions for the auth service and its backend component in the plugin-access-manager chart.

| Component | v7.0.0 | v8.0.0 |
|-----------|--------|--------|
| Auth Service | 2.6.6 | 2.6.7 |
| Auth Backend | 2.6.6 | 2.6.7 |
| Chart appVersion | 2.6.6 | 2.6.7 |

**What this means for operators:**

This is a patch version update that includes bug fixes and improvements. The upgrade should be seamless with no configuration changes required.

**What changed:**

The image tags for both the auth service and auth backend have been updated in `values.yaml`:

**Before (v7.0.0):**

```yaml
auth:
  image:
    tag: "2.6.6"
  
  backend:
    image:
      tag: "2.6.6"
```

**After (v8.0.0):**

```yaml
auth:
  image:
    tag: "2.6.7"
  
  backend:
    image:
      tag: "2.6.7"
```

**Why this matters:**

- The new version includes the latest bug fixes and stability improvements
- No breaking changes or configuration updates are required
- The upgrade follows semantic versioning with a patch-level increment
- Both auth service components are kept in sync at the same version

> **Note:** If you have overridden the image tags in your `values.yaml` or via `--set` flags, those overrides will continue to work. However, it's recommended to use the default tags provided by the chart unless you have a specific reason to pin to a different version.

**Default behavior:**

The chart will automatically pull and deploy version 2.6.7 for both auth service components. No action is required from operators unless custom image tags were previously configured.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.0.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.0.0 -n plugin-access-manager
```
