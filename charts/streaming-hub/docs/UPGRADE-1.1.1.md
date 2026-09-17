# Helm Upgrade from v1.1.0 to v1.1.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a patch-level release with no functional changes, configuration updates, or template modifications. The chart version has been incremented from `1.1.0` to `1.1.1` as part of the release process.

| Setting | v1.1.0 | v1.1.1 |
|---------|--------|--------|
| Chart version | `1.1.0` | `1.1.1` |
| App version | `1.7.0` | `1.7.0` |

**Impact:** None. The rendered Kubernetes manifests are identical between v1.1.0 and v1.1.1. No values have changed, no templates have been modified, and no new features or fixes are included in this release.

**Migration required:** No action is required. Existing values files and configuration remain valid without modification. The upgrade is a no-op from an operational perspective.

> **Note:** This release exists solely to advance the chart version number. Operators may upgrade at their convenience or remain on v1.1.0 with no functional difference.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 1.1.1 -n streaming-hub
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 1.1.1 -n streaming-hub
```
