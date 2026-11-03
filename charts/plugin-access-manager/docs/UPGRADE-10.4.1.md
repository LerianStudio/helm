# Helm Upgrade from v10.4.0 to v10.4.1

# Topics

- **[Application Version Update](#application-version-update)**
  - [1. Image Tag Changes](#1-image-tag-changes)

# Application Version Update

### 1. Image Tag Changes

This release updates the application version from `3.16.0-beta.5` to `3.16.1`, moving from a beta pre-release to a stable release.

**What changed:**

The chart's `appVersion` and default image tags for both auth and identity components have been updated to use the stable `3.16.1` release instead of the beta version.

| Setting | v10.4.0 | v10.4.1 |
|---------|---------|---------|
| Chart `appVersion` | `3.16.0-beta.5` | `3.16.1` |
| `auth.image.tag` | `3.16.0-beta.5` | `3.16.1` |
| `identity.image.tag` | `3.16.0-beta.5` | `3.16.1` |

**Why this matters:**

This is a transition from a beta version to a stable release. The stable `3.16.1` release includes bug fixes and stability improvements over the beta version. Operators running the beta should upgrade to benefit from the stable release.

**Who is affected:**

- Installations using the chart's default image tags (no explicit `auth.image.tag` or `identity.image.tag` override)
- Installations that explicitly pinned to `3.16.0-beta.5`

**Who is NOT affected:**

- Installations with explicit image tag overrides pointing to a different version
- Installations using custom image repositories

**Migration steps:**

No configuration changes are required. The upgrade will automatically pull the new stable image tags.

If you have explicitly pinned the beta version in your values file, you can either:

#### Option 1: Use the chart default

Remove the explicit tag override to use the chart's default:

```yaml
# Before (v10.4.0)
auth:
  image:
    tag: "3.16.0-beta.5"

identity:
  image:
    tag: "3.16.0-beta.5"

# After (v10.4.1) - remove explicit tags
auth:
  image: {}

identity:
  image: {}
```

#### Option 2: Explicitly set the stable version

Update your values file to reference the stable release:

```yaml
# Before (v10.4.0)
auth:
  image:
    tag: "3.16.0-beta.5"

identity:
  image:
    tag: "3.16.0-beta.5"

# After (v10.4.1)
auth:
  image:
    tag: "3.16.1"

identity:
  image:
    tag: "3.16.1"
```

**Verification:**

After upgrade, confirm the running image tags:

```bash
kubectl -n <namespace> get deployment <release>-auth <release>-identity \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

Expected output should show `3.16.1` tags for both deployments.

> **Note:** This is a patch-level application upgrade. Review the [plugin-access-manager v3.16.1 release notes](https://github.com/LerianStudio/plugin-access-manager/releases/tag/v3.16.1) for application-level changes between the beta and stable versions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.4.1 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.4.1 -n plugin-access-manager
```
