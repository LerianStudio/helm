# Helm Upgrade from v9.0.0 to v9.0.1

# Topics

- ***[Overview](#overview)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Overview

This is a patch release that increments the chart version from 9.0.0 to 9.0.1 with no changes to templates, values, or application version.

| Component | v9.0.0 | v9.0.1 |
|-----------|--------|--------|
| Chart version | 9.0.0 | 9.0.1 |
| App version | 3.4.0 | 3.4.0 (unchanged) |

**What changed:**

- Chart metadata version bump only
- No template modifications
- No values.yaml changes
- No configuration changes required

**Migration impact:**

This upgrade requires no configuration changes or operator intervention. All existing values.yaml configurations remain valid and unchanged.

> **Note:** This release contains no functional changes. Upgrading is optional unless you require the latest chart version for dependency management or organizational policies.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.1 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.1 -n plugin-fees
```
