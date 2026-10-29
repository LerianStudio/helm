<!-- {% raw %} -->
# Helm Upgrade from v10.0.2 to v10.0.3

# Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a patch release that updates the application version from 3.11.1 to 3.13.1. The chart version increments from 10.0.2 to 10.0.3.

**What changed:**

- Application version (appVersion) updated from `3.11.1` to `3.13.1`
- Identity service image tag updated to `3.13.1`
- Auth service image tag updated to `3.13.1`
- Auth init user container default image tag updated to `3.13.1`

**What this means for operators:**

This release updates the container images for the identity and auth services to version 3.13.1. The upgrade will trigger rolling updates of the affected deployments. No configuration changes or migration steps are required unless you have explicitly pinned image tags in your values.

| Component | v10.0.2 | v10.0.3 |
|-----------|---------|---------|
| Chart version | 10.0.2 | 10.0.3 |
| App version | 3.11.1 | 3.13.1 |
| Identity image tag | 3.11.1 | 3.13.1 |
| Auth image tag | 3.11.1 | 3.13.1 |
| Auth init user image tag | 3.11.1 | 3.13.1 |

**Action required:**

None, unless you have overridden image tags in your values. If you use the default image configuration, the upgrade will automatically pull and deploy version 3.13.1.

# Application Version Update

### Identity Service Image

The default image tag for the identity service has been updated.

**Before (v10.0.2):**

```yaml
identity:
  image:
    tag: "3.11.1"
```

**After (v10.0.3):**

```yaml
identity:
  image:
    tag: "3.13.1"
```

**Impact:**

If you are using the default image configuration (no explicit override in your values), the identity deployment will perform a rolling update to version 3.13.1. If you have explicitly set `identity.image.tag` in your values.yaml, your override will continue to be respected and no change will occur.

### Auth Service Image

The default image tag for the auth service has been updated.

**Before (v10.0.2):**

```yaml
auth:
  image:
    tag: "3.11.1"
```

**After (v10.0.3):**

```yaml
auth:
  image:
    tag: "3.13.1"
```

**Impact:**

If you are using the default image configuration (no explicit override in your values), the auth deployment will perform a rolling update to version 3.13.1. If you have explicitly set `auth.image.tag` in your values.yaml, your override will continue to be respected and no change will occur.

### Auth Init User Container

The default image tag for the auth init user job has been updated in the template.

**Before (v10.0.2):**

```yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.11.1" }}"
```

**After (v10.0.3):**

```yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.13.1" }}"
```

**Impact:**

The init user job that runs during auth service initialization will use version 3.13.1 by default. This job typically runs once during initial deployment or when auth configuration changes. If you have explicitly configured `auth.initUser.image.tag` in your values, your override will be respected.

> **Note:** The init user job is part of the auth service initialization process. If the job is already completed in your environment, it will not re-run unless the auth service configuration changes or the job is manually deleted.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.3 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.3 -n plugin-access-manager
```
<!-- {% endraw %} -->
