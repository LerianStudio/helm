# Helm Upgrade from v2.0.8 to v2.0.9

This guide covers the upgrade from `alloy-lerian` chart version **2.0.8** to **2.0.9**. This patch release changes one render error message and some descriptions. No value, default, template logic or Kubernetes resource changes.

---

## Topics

- **[Changes](#changes)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

---

## Changes

- With Fleet Management enabled and no `ALLOY_FLEET_POD_NAME` in `node.alloy.extraEnv`, the render still fails. The error message no longer ends with a stray `%!(EXTRA ...)` text.
- One description in `values.schema.json` and some comments in `values.yaml` are reworded.
- The rendered manifests are the same except for the `helm.sh/chart` label. No pod template changes, so no pod restarts.

**Migration Steps:**

No action required.

The commands in this guide use the release name `alloy-lerian` and the namespace `monitoring`. These are examples: replace them with the values you used at install time.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.9 -n monitoring -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.9 -n monitoring -f values.yaml
```

---

## Verify

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/instance=alloy-lerian
```

The pods must be `Running`, and telemetry must keep arriving at the destination.
