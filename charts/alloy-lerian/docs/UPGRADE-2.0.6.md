<!-- {% raw %} -->
# Helm Upgrade from v2.0.5 to v2.0.6

This guide covers the upgrade from `alloy-lerian` chart version **2.0.5** to **2.0.6**. This patch release fixes the self-metrics instance label to distinguish between node and singleton roles, preventing series collision at the destination.

---

## Topics

- **[Fixes](#fixes)**
  - [1. Self-Metrics Instance Label Collision](#1-self-metrics-instance-label-collision)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### 1. Self-Metrics Instance Label Collision

The self-metrics pipeline now appends the role name (`-node` or `-singleton`) to the `instance` label, preventing both roles from writing to the same series when they run on the same node.

**Before (v2.0.5):**

```yaml
prometheus.relabel "allowlist_agente" {
  rule {
    source_labels = ["__name__"]
    regex         = {{ join "|" ((.Values.collection).selfMetricsAllowlist | default list) | quote }}
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

**After (v2.0.6):**

```yaml
prometheus.relabel "allowlist_agente" {
  rule {
    source_labels = ["__name__"]
    regex         = {{ join "|" ((.ctx.Values.collection).selfMetricsAllowlist | default list) | quote }}
    action        = "keep"
  }

  rule {
    target_label = "client.id"
    replacement  = sys.env("ALLOY_CLIENT_ID")
  }

  // Every agent scrapes itself at 127.0.0.1:12345, so without an identity all
  // agents of a client write one series. HOSTNAME is the node name (the pod
  // name is not in the sanitised env), and one node hosts one agent per role.
  rule {
    target_label = "instance"
    replacement  = sys.env("HOSTNAME") + {{ printf "-%s" .role | quote }}
  }

  forward_to = [otelcol.receiver.prometheus.ponte_agente.receiver]
}
```

**What changed:**

| Setting | v2.0.5 | v2.0.6 |
|---------|--------|--------|
| `instance` label for node role | `<node-name>` | `<node-name>-node` |
| `instance` label for singleton role | `<node-name>` | `<node-name>-singleton` |
| Template context for self-metrics helper | `.` (root context) | `dict "ctx" . "role" "<role>"` |

**What this means:**

- In v2.0.5, if both the node DaemonSet and singleton Deployment ran on the same node, they wrote to the same series (same `client.id` and `instance` labels), causing one to overwrite the other's metrics
- In v2.0.6, the `instance` label includes the role suffix (`-node` or `-singleton`), creating distinct series for each role
- The self-metrics helper template (`alloy-lerian.config.selfMetrics`) now receives a dictionary with `ctx` (the root context) and `role` (the role name), allowing it to append the role to the instance label

**Migration Steps:**

No action required. The change is backward-compatible:

1. On upgrade, new series with the `-node` and `-singleton` suffixes will be created
2. Old series without the suffix will stop receiving updates and age out according to your retention policy
3. If you have dashboards or alerts that query self-metrics by `instance` label, update them to match the new pattern:

**Before:**

```promql
alloy_build_info{client_id="acme-prd", instance="ip-10-0-1-42"}
```

**After:**

```promql
alloy_build_info{client_id="acme-prd", instance="ip-10-0-1-42-node"}
alloy_build_info{client_id="acme-prd", instance="ip-10-0-1-42-singleton"}
```

Or use a regex to match both:

```promql
alloy_build_info{client_id="acme-prd", instance=~"ip-10-0-1-42.*"}
```

> **Note:** The `HOSTNAME` environment variable contains the node name, not the pod name. In Kubernetes, the pod name is available via the downward API (`metadata.name`), but the chart sanitizes environment variables and does not expose it. Since one node hosts at most one pod per role (DaemonSet for node, single-replica Deployment for singleton), the node name plus role suffix is sufficient to uniquely identify each agent.

**Template context change:**

The self-metrics helper is now called with a dictionary instead of the root context:

**Before (v2.0.5):**

```yaml
{{- if (.Values.collection).selfMetrics }}
{{ include "alloy-lerian.config.selfMetrics" . }}
{{- end }}
```

**After (v2.0.6):**

```yaml
{{- if (.Values.collection).selfMetrics }}
{{ include "alloy-lerian.config.selfMetrics" (dict "ctx" . "role" "node") }}
{{- end }}
```

This change is internal to the chart and does not affect values overrides. The helper accesses values via `.ctx.Values` instead of `.Values`, and uses `.role` to append the role suffix to the instance label.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.6 -n alloy-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.6 -n alloy-lerian
```
<!-- {% endraw %} -->
