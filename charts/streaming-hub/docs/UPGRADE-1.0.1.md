# Helm Upgrade from v1.0.0 to v1.0.1

## Topics

- **[Application Version Update](#application-version-update)**
- **[Whitespace Normalization](#whitespace-normalization)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Application Version Update

The chart now ships with a newer application version.

| Setting | v1.0.0 | v1.0.1 |
|---------|--------|--------|
| Chart version | `1.0.0` | `1.0.1` |
| App version | `1.5.0-beta.8` | `1.7.0` |

**Impact:** This is a patch-level chart update that bumps the default application image tag from `1.5.0-beta.8` to `1.7.0`. The application version moves from a beta pre-release to a stable release.

**Configuration:**

If you have explicitly pinned the image tag in your values, no action is required:

```yaml
streamingHub:
  image:
    tag: "1.5.0-beta.8"  # Your explicit override remains active
```

If you rely on the chart's default `appVersion` (i.e., `streamingHub.image.tag` is empty or unset), the upgrade will automatically pull the new `1.7.0` image.

**Migration required:** Review the application release notes for `1.7.0` to understand any behavioral changes, bug fixes, or new features introduced between `1.5.0-beta.8` and `1.7.0`. No chart-level configuration changes are required for this version bump.

> **Note:** The application image repository remains unchanged (`ghcr.io/lerianstudio/streaming-hub`). Only the default tag is updated.

---

## Whitespace Normalization

The chart source files have been cleaned up to remove trailing blank lines in `Chart.yaml` and `values.yaml`. This is a cosmetic change with no functional impact.

**Impact:** None. The rendered Kubernetes manifests are identical. This change improves chart maintainability and consistency but does not affect deployment behavior, resource configuration, or runtime operation.

> **Note:** If you maintain a fork or patch of this chart, you may see whitespace-only diffs when rebasing. These can be safely ignored.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 1.0.1 -n streaming-hub
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 1.0.1 -n streaming-hub
```
