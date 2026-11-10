# Helm Upgrade from v2.0.2 to v2.0.3

This guide covers the upgrade from `alloy-lerian` chart version **2.0.2** to **2.0.3**. This patch release contains only a version bump with no functional changes, template modifications, or configuration updates.

---

## Topics

- **[Changes](#changes)**
  - [Version Bump Only](#version-bump-only)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Changes

### Version Bump Only

This release increments the chart version from `2.0.2` to `2.0.3` with no other modifications.

| Setting | v2.0.2 | v2.0.3 |
|---------|--------|--------|
| Chart version | `2.0.2` | `2.0.3` |
| App version | `1.18.1` | `1.18.1` (unchanged) |

**What changed:**

The `Chart.yaml` file was updated to reflect the new version number. No templates, values, or dependencies were modified.

**What this means:**

- No configuration changes are required
- No behavioral changes will occur
- The upgrade is a metadata-only change
- All existing configurations remain valid

**Migration Steps:**

No action required. The upgrade can be applied directly with no preparation.

> **Note:** This release follows semantic versioning conventions. The patch version increment indicates backward-compatible maintenance changes only.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.3 -n alloy-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.3 -n alloy-lerian
```
