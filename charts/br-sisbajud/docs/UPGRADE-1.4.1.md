# Helm Upgrade from v1.4.0 to v1.4.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a patch release that increments the chart version from `1.4.0` to `1.4.1` with no functional changes to templates, values, or application behavior.

| Setting | v1.4.0 | v1.4.1 |
|---------|--------|--------|
| Chart version | `1.4.0` | `1.4.1` |
| App version | Unchanged | Unchanged |
| Templates | No changes | No changes |
| Values schema | No changes | No changes |

**What changed:**

- Chart metadata version bump in `Chart.yaml`

**What did NOT change:**

- Application image tags (appVersion remains the same)
- Deployment templates
- ConfigMap or Secret structure
- Service, Ingress, or other Kubernetes resources
- Default values or configuration options
- Migration job behavior
- Subchart dependencies (PostgreSQL, Valkey)

**Action required:**

None. This upgrade can be applied without any configuration changes or migration steps. Existing `values.yaml` files are fully compatible.

> **Note:** This release contains only a version number change. No pods will be restarted unless other configuration changes are applied during the upgrade.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.4.1 -n br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.4.1 -n br-sisbajud
```
