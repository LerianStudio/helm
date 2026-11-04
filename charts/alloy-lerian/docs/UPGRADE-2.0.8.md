# Helm Upgrade from v2.0.7 to v2.0.8

This guide covers the upgrade from `alloy-lerian` chart version **2.0.7** to **2.0.8**. This patch release narrows the permissions the chart grants, makes the client profile refuse `node-exporter.enabled: true`, and adds notes about image registries and Fleet Management. Telemetry and Fleet Management defaults do not change, and the rendered agent configuration is the same apart from comments.

---

## Topics

- **[Changes](#changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

---

## Changes

- **Narrower permission set.** The node and singleton agents no longer have cluster-wide read access to Secrets, ConfigMaps and `pods/log`. No component in the rendered pipeline reads them through the Kubernetes API. Kube-state-metrics no longer lists Secrets and ConfigMaps. Its allowlist already excluded those metric families, so the exported series do not change.
- **Client profile and `node-exporter`.** With `profile: client`, `node-exporter.enabled: true` now fails at render time. `values.yaml` and `Chart.yaml` already said the client profile does not accept it. Node-infrastructure collection stays available only in the `own` profile.
- **Image registry.** `values.yaml` documents `global.image.registry`. `global.imageRegistry` applies to the kube-state-metrics and node-exporter images only. The agent and config-reloader images use `global.image.registry`. If only `global.imageRegistry` is set, `NOTES.txt` now warns about it after install or upgrade.
- **`NOTES.txt`.** It now states where collection and sanitization run for each role when Fleet Management is on, and that the `alloy-lerian` Secret needs the `fleet-token` key in both profiles.
- **Comments and messages.** Comments in `values.yaml` and the templates, the 1.0 upgrade guide, the client example and two render-guard messages keep only operator-facing text. The comments that appear in `config.alloy` change, so the node and singleton ConfigMaps change. The agents reload them.

---

## Migration Steps

Before the upgrade, check one case only:

- If you use `profile: client` and set `node-exporter.enabled: true`, remove that setting. The render now fails with it.

No other action is required.

Pods restarting: kube-state-metrics restarts once, because its container arguments change. The agent pods do not restart, because no pod template changes.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.8 -n monitoring -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.8 -n monitoring -f values.yaml
```

---

## Verify

```bash
kubectl get pods -n monitoring
kubectl auth can-i list secrets --as=system:serviceaccount:monitoring:<agent-service-account>
```

The second command prints `no` for the agent service accounts after the upgrade. The agent and kube-state-metrics pods must be `Running`, and telemetry must keep arriving at the destination.
