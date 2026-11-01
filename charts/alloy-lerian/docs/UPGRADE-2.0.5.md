# Helm Upgrade from v2.0.4 to v2.0.5

This guide covers the upgrade from `alloy-lerian` chart version **2.0.4** to **2.0.5**. This patch release fixes a metric cardinality issue where self-scraping metrics from multiple agents overwrote each other due to missing instance labels.

---

## Topics

- **[Fixes](#fixes)**
  - [1. Self-Scraping Instance Label Collision](#1-self-scraping-instance-label-collision)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### 1. Self-Scraping Instance Label Collision

The chart now adds the pod name as the `instance` label for self-scraping metrics to prevent agents from overwriting each other's series.

**Before (v2.0.4):**

```yaml
prometheus.relabel "allowlist_agente" {
  forward_to = [prometheus.relabel.marca_origem_agente.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "alloy_.*"
    action        = "keep"
  }

  rule {
    target_label = "client.id"
    replacement  = sys.env("ALLOY_CLIENT_ID")
  }

  forward_to = [otelcol.receiver.prometheus.ponte_agente.receiver]
}
```

**After (v2.0.5):**

```yaml
prometheus.relabel "allowlist_agente" {
  forward_to = [prometheus.relabel.marca_origem_agente.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "alloy_.*"
    action        = "keep"
  }

  rule {
    target_label = "client.id"
    replacement  = sys.env("ALLOY_CLIENT_ID")
  }

  // Every agent scrapes itself at 127.0.0.1:12345; without the pod name all
  // agents of a client write the same series and overwrite each other.
  rule {
    target_label = "instance"
    replacement  = sys.env("HOSTNAME")
  }

  forward_to = [otelcol.receiver.prometheus.ponte_agente.receiver]
}
```

**What changed:**

A new relabeling rule sets the `instance` label to the pod's hostname (available via the `HOSTNAME` environment variable) for all self-scraping metrics.

**What this means:**

| Setting | v2.0.4 | v2.0.5 |
|---------|--------|--------|
| Self-scraping `instance` label | `127.0.0.1:12345` (same for all agents) | Pod name (unique per agent) |
| Series collision | All agents overwrite each other's metrics | Each agent writes distinct series |

**Why this matters:**

Every Alloy agent scrapes its own metrics at `127.0.0.1:12345`. Without a unique `instance` label, all agents in a client cluster write to the same series identity:

```
alloy_build_info{client.id="acme-prd", instance="127.0.0.1:12345", job="alloy-lerian-node"}
```

When multiple agents write to the same series, only the last write is preserved. This causes:

- Metric gaps when an agent stops reporting
- Incorrect aggregation (e.g., `sum(alloy_component_controller_running_components)` returns the count from only one agent instead of all)
- Loss of per-agent observability (cannot distinguish which agent is experiencing issues)

With the pod name as the `instance` label, each agent writes to a distinct series:

```
alloy_build_info{client.id="acme-prd", instance="alloy-lerian-node-abc12", job="alloy-lerian-node"}
alloy_build_info{client.id="acme-prd", instance="alloy-lerian-node-def34", job="alloy-lerian-node"}
```

**Migration Steps:**

No action required. The change is applied automatically on upgrade.

**Verify after upgrade:**

Query the destination to confirm each agent is writing distinct series:

```bash
# Replace with your actual query endpoint
curl -G 'https://telemetry.lerian.io/api/v1/query' \
  --data-urlencode 'query=alloy_build_info{client.id="acme-prd"}'
```

You should see one series per agent pod, each with a unique `instance` label matching the pod name.

> **Note:** Existing series with `instance="127.0.0.1:12345"` will remain in the destination until they expire according to the retention policy. The new series with pod names will appear immediately after upgrade.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.5 -n alloy-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.5 -n alloy-lerian
```
