# Helm Upgrade from v2.0.2 to v2.0.3

## Topics

- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Application Version Update

The chart now ships with a newer application version.

| Setting | v2.0.2 | v2.0.3 |
|---------|--------|--------|
| Chart version | `2.0.2` | `2.0.3` |
| App version | `3.0.0` | `3.1.0` |

**Impact:** This is a patch-level chart update that bumps the default application image tag from `3.0.0` to `3.1.0`. The application version moves from a stable release to a newer stable release.

**Configuration:**

If you have explicitly pinned the image tag in your values, no action is required:

```yaml
streamingHub:
  image:
    tag: "3.0.0"  # Your explicit override remains active
```

If you rely on the chart's default `appVersion` (i.e., `streamingHub.image.tag` is empty or unset), the upgrade will automatically pull the new `3.1.0` image.

**Migration required:** Review the application release notes for `3.1.0` to understand any behavioral changes, bug fixes, or new features introduced between `3.0.0` and `3.1.0`. No chart-level configuration changes are required for this version bump.

> **Note:** The application image repository remains unchanged (`ghcr.io/lerianstudio/streaming-hub`). Only the default tag is updated.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 2.0.3 -n streaming-hub
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 2.0.3 -n streaming-hub
```
