# Helm Upgrade from v2.0.4 to v2.0.5

This guide covers the upgrade from `alloy-lerian` chart version **2.0.4** to **2.0.5**. This patch release sets the `instance` label of the agent's self-metrics to the node name, so agents on different nodes no longer overwrite each other's series.

---

## Topics

- **[Fixes](#fixes)**
  - [1. Self-Scraping Instance Label Collision](#1-self-scraping-instance-label-collision)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### 1. Self-Scraping Instance Label Collision

The chart now sets the `instance` label of the agent's self-metrics from the `HOSTNAME` environment variable, which the upstream Alloy chart sets to the Kubernetes node name. Before, every agent scraped itself at `127.0.0.1:12345`, so all agents of a client wrote the same series and overwrote each other.

**What changed:**

The self-metrics relabel (`allowlist_agente`) gains one rule:

```yaml
rule {
  target_label = "instance"
  replacement  = sys.env("HOSTNAME")
}
```

**Migration Steps:**

No action required. The change is applied automatically on upgrade.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.5 -n monitoring -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.5 -n monitoring -f values.yaml
```
