# Helm Upgrade from v2.0.0 to v2.0.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a patch-level chart version bump with no functional changes, configuration updates, or template modifications.

| Setting | v2.0.0 | v2.0.1 |
|---------|--------|--------|
| Chart version | `2.0.0` | `2.0.1` |
| App version | `3.0.0` | `3.0.0` |

**Impact:** None. The chart version has been incremented from `2.0.0` to `2.0.1` in `Chart.yaml`, but no changes have been made to:

- Application image tags or versions
- Values schema or defaults
- Template rendering logic
- ConfigMap or Secret structure
- Deployment, Service, or other Kubernetes resource definitions

**Migration required:** None. This upgrade is a no-op from an operational perspective. Existing values files and configuration remain fully compatible. The rendered Kubernetes manifests are identical between v2.0.0 and v2.0.1.

> **Note:** This version bump may have been triggered by repository automation, CI/CD pipeline changes, or chart metadata updates not reflected in the Helm chart source files. Operators can safely upgrade without reviewing application release notes or adjusting configuration.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 2.0.1 -n streaming-hub
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://registry-1.docker.io/lerianstudio/streaming-hub-helm --version 2.0.1 -n streaming-hub
```
