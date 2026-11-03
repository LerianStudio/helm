# Helm Upgrade from v1.0.0 to v1.0.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a patch release. No configuration changes, template modifications, or breaking changes are included.

| Setting | v1.0.0 | v1.0.1 |
|---------|--------|--------|
| Chart version | `1.0.0` | `1.0.1` |
| App version | `1.0.0-beta.33` | `1.0.0-beta.33` |

**What changed:**
- Chart version bumped from `1.0.0` to `1.0.1` in `Chart.yaml`
- The chart README now states the chart license as Elastic License 2.0 (previously Apache-2.0)

**What stayed the same:**
- Application version remains `1.0.0-beta.33`
- All values.yaml defaults unchanged
- All template files unchanged
- All configuration parameters unchanged

**Impact:** This upgrade requires no configuration changes or migration steps. Existing values files are fully compatible.

> **Note:** No application behavior, deployment manifests, or configuration options have changed.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.0.1 -n plugin-br-ted-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.0.1 -n plugin-br-ted-lerian
```
