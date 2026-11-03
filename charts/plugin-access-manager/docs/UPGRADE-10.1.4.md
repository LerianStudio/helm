# Helm Upgrade from v10.1.3 to v10.1.4

# Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

Version 10.1.4 is a patch release that contains no functional changes, template modifications, or configuration updates. The chart version moves from `10.1.3` to `10.1.4` in `Chart.yaml`, and `README.md` now declares the chart license as Elastic License 2.0 instead of Apache-2.0.

**What changed:**

| File | Change |
|------|--------|
| `Chart.yaml` | `version: 10.1.3` → `version: 10.1.4` |
| `README.md` | license line: Apache-2.0 → Elastic License 2.0 |
| `docs/` | upgrade guides for earlier releases added |

**Why this matters:**

Rendered resources carry the new chart version in the `helm.sh/chart` label. That label is part of the pod templates of the auth, identity and caradhras Deployments (and of the Caradhras UI Deployment when `caradhras.ui.enabled` is true), so the upgrade replaces their pods, even though no image or setting changes. The application version (`appVersion: "3.14.0"`), all templates, default values, and configuration remain identical to v10.1.3.

**What operators need to do:**

No configuration changes, migration steps, or operational actions are required. The upgrade is a direct replacement with zero functional diff.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.4 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.4 -n plugin-access-manager
```
