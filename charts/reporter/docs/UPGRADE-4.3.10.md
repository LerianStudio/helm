# Helm Upgrade from v4.3.9 to v4.3.10

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. lerian-common-helm dependency upgraded to v2.1.2](#1-lerian-common-helm-dependency-upgraded-to-v212)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that upgrades the `lerian-common-helm` dependency from `2.0.0` to `2.1.2`. No application code changes are included, and no values.yaml modifications are required.

| Field | v4.3.9 | v4.3.10 |
|-------|--------|---------|
| Chart version | `4.3.9` | `4.3.10` |
| App version | `4.2.0` | `4.2.0` |
| lerian-common-helm dependency | `2.0.0` | `2.1.2` |

## Fixes

### 1. lerian-common-helm dependency upgraded to v2.1.2

The `lerian-common-helm` library chart dependency has been upgraded from version `2.0.0` to `2.1.2`. This library chart provides shared templates and helpers used across Lerian Studio charts.

| Dependency | v4.3.9 | v4.3.10 |
|------------|--------|---------|
| `lerian-common-helm` | `2.0.0` | `2.1.2` |

**Before (v4.3.9):**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.0.0"
    repository: "oci://ghcr.io/lerianstudio"
```

**After (v4.3.10):**

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.1.2"
    repository: "oci://ghcr.io/lerianstudio"
```

> **Note:** The `lerian-common-helm` library chart contains shared template helpers and does not deploy any resources directly. Changes in this dependency may include bug fixes, template improvements, or new helper functions that improve chart maintainability. Consult the [lerian-common-helm changelog](https://github.com/lerianstudio/lerian-common-helm) for details on what changed between `2.0.0` and `2.1.2`.

The upgrade is transparent to operators — no values.yaml changes are required, and no behavioral changes are expected in the deployed resources.

## Migration Steps

This upgrade requires no configuration changes or manual intervention. The Helm upgrade will automatically pull the updated dependency and re-render all templates.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

4. Check manager and worker logs to confirm normal operation:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

> **Note:** The upgrade may trigger a rolling restart of manager and worker deployments if the dependency update results in template changes. Monitor pod status during the upgrade to ensure smooth rollout.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.10 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.10 -n reporter
```
