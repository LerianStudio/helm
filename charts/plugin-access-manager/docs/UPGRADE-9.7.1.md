# Helm Upgrade from v9.7.0 to v9.7.1

# Topics

- **[Fixes](#fixes)**
  - [1. Application Version Updates](#1-application-version-updates)
  - [2. Init User Container Image Update](#2-init-user-container-image-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Application Version Updates

This release updates the application versions for the identity and auth services in the plugin-access-manager chart.

| Component | v9.7.0 | v9.7.1 |
|-----------|--------|--------|
| Chart appVersion | 3.11.0 | 3.11.1 |
| Identity service | 3.11.0 | 3.11.1 |
| Auth service | 3.11.0 | 3.11.1 |

**What this means for operators:**

This is a patch version update that includes bug fixes and improvements. The upgrade should be seamless with no configuration changes required.

**What changed:**

The image tags have been updated in `values.yaml`:

**Before (v9.7.0):**

```yaml
identity:
  image:
    tag: "3.11.0"

auth:
  image:
    tag: "3.11.0"
```

**After (v9.7.1):**

```yaml
identity:
  image:
    tag: "3.11.1"

auth:
  image:
    tag: "3.11.1"
```

> **Note:** If you have overridden the image tags in your custom values file, you may want to update them to use the new version or remove the override to use the chart defaults.

### 2. Init User Container Image Update

The default image tag for the init user container has been updated to match the application version bump.

**What changed:**

The hardcoded fallback image tag in the auth init user template has been updated:

**Before (v9.7.0):**

```yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.11.0" }}"
```

**After (v9.7.1):**

```yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.11.1" }}"
```

**Why this matters:**

The init user container runs before the auth service starts and is responsible for initializing user data. This update ensures the init container uses the same version as the main application services.

**Default behavior:**

If you haven't explicitly configured `auth.initUser.image` in your values file, the chart will automatically use the new default tag `3.11.1`. If you have overridden this value, your custom configuration will continue to be used.

> **Note:** This change only affects deployments that rely on the default init user image tag. If you've specified a custom image or tag via `auth.initUser.image`, no action is required unless you want to align with the new version.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.7.1 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.7.1 -n plugin-access-manager
```
