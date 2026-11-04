# Helm Upgrade from v2.2.1 to v2.2.2

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify the upgrade](#verify-the-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.2.1` to `2.2.2`. This is a patch release. The application version stays at `1.2.0`.

No operator action is required beyond the upgrade command. Your values overlay keeps working without changes. The pods restart once during the upgrade (see [Changes](#changes)).

## Changes

1. **Pod labels.** The Deployment pod template no longer carries the `helm.sh/chart` label. Because the pod template changes, Kubernetes rolls the pods once. The selector labels do not change.
2. **`REQUEST_TIMEOUT_SEC`.** `app.configmap.REQUEST_TIMEOUT_SEC` is now accepted by `values.schema.json`, and the chart renders it in the ConfigMap when you set it. Application `1.2.0` reads this variable. If you do not set it, the ConfigMap is unchanged.
3. **Starter overlay.** `values-template.yaml` now pins `app.image.tag` to `1.2.0`, so the starter overlay renders with the current application version.
4. **Bundled PostgreSQL certificate rotation.** `values.yaml` now documents how to rotate the auto-generated TLS certificate: delete the `<release>-postgresql-crt` Secret, run `helm upgrade`, then restart the PostgreSQL pods and the application pods. The certificate is valid for 365 days and is kept across upgrades. This is a comment only; no value changed.
5. **Chart metadata.** The `sources` list in `Chart.yaml` and the Source section of `NOTES.txt` now list only the chart source in the Helm repository.

| Setting | v2.2.1 | v2.2.2 |
|---------|--------|--------|
| `app.configmap.REQUEST_TIMEOUT_SEC` | rejected by the schema | accepted; rendered when set |
| `values-template.yaml` `app.image.tag` | `1.0.2` | `1.2.0` |
| Pod template label `helm.sh/chart` | present | removed |

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --version 2.2.2 -n plugin-br-payments -f <your-values>.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --version 2.2.2 -n plugin-br-payments -f <your-values>.yaml
```

## Verify the upgrade

```bash
kubectl rollout status deployment/plugin-br-payments -n plugin-br-payments
kubectl get pods -n plugin-br-payments
```

All pods must reach `Running` and `Ready`.
