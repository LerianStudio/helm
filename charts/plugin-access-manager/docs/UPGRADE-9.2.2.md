# Helm Upgrade from v9.2.1 to v9.2.2

# Topics

- **[Fixes](#fixes)**
  - [1. User Initialization Image Version Update](#1-user-initialization-image-version-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. User Initialization Image Version Update

**What changed:**

The default image tag for the user initialization container has been updated from `3.2.0-beta.67` to `3.3.1`.

| Setting | v9.2.1 | v9.2.2 |
|---------|--------|--------|
| Default init user image tag | `3.2.0-beta.67` | `3.3.1` |

**Before (v9.2.1):**

```yaml
# templates/auth/init_user.yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.2.0-beta.67" }}"
```

**After (v9.2.2):**

```yaml
# templates/auth/init_user.yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.3.1" }}"
```

**Why this matters:**

The `3.3.1` image is a stable release that replaces the beta version. This update ensures the user initialization Job uses a production-ready image with bug fixes and improvements from the beta cycle.

**Operational impact:**

- If you have not explicitly set `auth.initUser.image.tag` in your `values.yaml`, the upgrade will automatically use the new `3.3.1` image
- If you have pinned a specific image tag, your override will continue to take precedence
- The init user Job only runs when `auth.initUser.enabled: true` — if you've disabled it (recommended for upgrades of existing releases), this change has no effect

**What operators need to do:**

No action required. The image version update is automatic and backward-compatible.

> **Note:** As documented in the v9.0.0 upgrade guide, most operators upgrading an existing release should have `auth.initUser.enabled: false` because the admin user was already created during the original installation. If you have it disabled, this image version change does not affect your deployment.

**Example: Pinning a specific image version**

If you need to pin a different image version:

```yaml
auth:
  initUser:
    image:
      repository: "ghcr.io/lerianstudio/caradhras-user-init"
      tag: "3.2.0-beta.67"
      pullPolicy: "Always"
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.2 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.2 -n plugin-access-manager
```
