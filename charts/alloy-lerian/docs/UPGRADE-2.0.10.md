# Helm Upgrade from v2.0.9 to v2.0.10

This guide covers the upgrade from `alloy-lerian` chart version **2.0.9** to **2.0.10**. This patch release changes comments in `values.yaml` and one schema description. No value, default or template changes.

---

## Topics

- **[Changes](#changes)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

---

## Changes

- The `spanMetrics` comments in `values.yaml` now say why span metrics are off by default and when to turn them on. `spanMetrics.enabled` stays `false`.
- The `spanMetrics` description in `values.schema.json` is reworded. The schema accepts the same values as before.
- The rendered manifests are the same except for the `helm.sh/chart` label. No pod template changes, so no pod restarts.

**Migration Steps:**

No action required.

The commands in this guide use the release name `alloy-lerian` and the namespace `monitoring`. These are examples: replace them with the values you used at install time.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.10 -n monitoring -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.10 -n monitoring -f values.yaml
```

---

## Verify

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/instance=alloy-lerian
```

The pods must be `Running`, and telemetry must keep arriving at the destination.
