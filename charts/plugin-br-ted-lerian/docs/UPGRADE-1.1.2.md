# Helm Upgrade from v1.1.1 to v1.1.2

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a patch release that updates only the chart version metadata. There are no functional changes, configuration updates, or template modifications in this release.

| Setting | v1.1.1 | v1.1.2 |
|---------|--------|--------|
| Chart version | 1.1.1 | 1.1.2 |
| App version | 1.0.0-beta.64 | 1.0.0-beta.64 |

**What changed:**
- Chart version bumped from `1.1.1` to `1.1.2` in `Chart.yaml`

**What stayed the same:**
- Application version remains `1.0.0-beta.64`
- All values.yaml configuration unchanged
- All template files unchanged
- All default behaviors unchanged

**Impact:** This is a zero-downtime upgrade with no configuration migration required. Your existing values files will work without modification.

> **Note:** This release contains no breaking changes, new features, or bug fixes. It is a metadata-only update.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.2 -n plugin-br-ted-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.2 -n plugin-br-ted-lerian
```
