# Helm Upgrade from v8.0.3 to v8.0.4

# Topics

- ***[Overview](#overview)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Overview

This is a patch release that updates the chart version from 8.0.3 to 8.0.4. No changes were made to templates, values, or application configuration.

| Setting | v8.0.3 | v8.0.4 |
|---------|--------|--------|
| Chart version | 8.0.3 | 8.0.4 |
| App version | 3.4.0 | 3.4.0 (unchanged) |

**What changed:**

- Chart metadata version bump only

**Migration impact:**

- No configuration changes required
- No breaking changes
- No new features or deprecations
- Existing values.yaml configurations remain fully compatible

This upgrade can be applied without any modifications to your existing configuration.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.4 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.4 -n plugin-fees
```
