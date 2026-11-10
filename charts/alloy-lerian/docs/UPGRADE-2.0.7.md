# Helm Upgrade from v2.0.6 to v2.0.7

This guide covers the upgrade from `alloy-lerian` chart version **2.0.6** to **2.0.7**. This patch release changes comments only. No value, default, template logic or Kubernetes resource changes.

---

## Topics

- **[Changes](#changes)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Changes

- Comments in `values.yaml` and in the templates are reworded. Some of these comments are part of the rendered `config.alloy`, so the node and singleton ConfigMaps change. The agents load the new ConfigMaps and the pods do not restart, because no pod template changes.
- The package no longer contains two example values files that described internal environments. `examples/values-cliente.yaml` is still in the package.

**Migration Steps:**

No action required.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.7 -n monitoring -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.7 -n monitoring -f values.yaml
```
