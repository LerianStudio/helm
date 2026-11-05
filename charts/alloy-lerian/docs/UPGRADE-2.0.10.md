# Helm Upgrade from v2.0.9 to v2.0.10

This guide covers the upgrade from `alloy-lerian` chart version **2.0.9** to **2.0.10**. This patch release updates the span metrics documentation to reflect that generation is now disabled by default and clarifies when operators should enable it.

---

## Topics

- **[Documentation Changes](#documentation-changes)**
  - [1. Span Metrics Generation Default](#1-span-metrics-generation-default)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Documentation Changes

### 1. Span Metrics Generation Default

The `spanMetrics` section documentation has been rewritten to clarify that span metrics generation is **disabled by default** and should only be enabled when explicitly requested by Lerian.

| Setting | v2.0.9 | v2.0.10 |
|---------|--------|--------|
| `spanMetrics.enabled` | `false` (with warning about migration) | `false` (documented as default behavior) |
| Documentation focus | Migration from agent to server generation | When to enable and why it's off by default |

**What changed:**

The documentation now explains:

1. **Why it's off by default**: The node role is a DaemonSet, so generation here creates one accumulator per node. Each pod writes the same series with different values at the same timestamp, which the destination rejects.

2. **Where generation happens**: The telemetry server derives these metrics from the spans it receives. This provides a single accumulator per cluster instead of one per node.

3. **When to enable**: Only when Lerian explicitly asks you to. If both the agent and the server generate the series for the same stack, the counts double.

4. **Series name difference**: Generated at the agent, the series are `calls_total` and `duration_milliseconds_*`. Generated at the server, they are `traces_span_metrics_*`.

**Before (v2.0.9):**

```yaml
spanMetrics:
  # 🔴 DESLIGADO POR PADRAO (2026-10-06). A geracao de spanmetrics e
  # responsabilidade do collector-server, nao do agente.
  #
  # POR QUE: o papel `node` e um DaemonSet, logo ha UM ACUMULADOR POR NO. Cada
  # um mantem estado proprio e escreve a MESMA serie com valores diferentes no
  # mesmo timestamp — o destino rejeita com `new-value-for-timestamp`. Foi
  # exatamente o que os ambientes internos mediram antes de mover a geracao
  # para o concentrador.
  #
  # [... extensive migration instructions ...]
  enabled: false
```

**After (v2.0.10):**

```yaml
spanMetrics:
  # Off by default: the telemetry server derives these metrics from the spans it
  # receives. The node role is a DaemonSet, so generation here keeps one
  # accumulator per node, and the pods write the same series with different
  # values at the same timestamp, which the destination rejects. Turn it on only
  # when Lerian asks you to: if the agent and the server both generate the
  # series for the same stack, the counts double. Generated here the series are
  # `calls_total` and `duration_milliseconds_*`; generated on the server they are
  # `traces_span_metrics_*`.
  enabled: false
```

**What this means:**

- The default behavior (`enabled: false`) remains unchanged
- The documentation is now clearer about why generation is disabled and when to enable it
- The migration-focused language has been replaced with operational guidance

**Migration Steps:**

No action required. The default value and behavior are unchanged. If you have explicitly set `spanMetrics.enabled: true` in your values, review with Lerian whether this is still necessary to avoid double-counting metrics.

> **Important:** If you enable span metrics generation at the agent level, verify that the telemetry server is **not** also generating them for your stack. Query for both `calls_total` and `traces_span_metrics_calls_total` at your destination to check for duplication.

**Configuration reference:**

```yaml
spanMetrics:
  enabled: false

  # Changing the buckets renames every `_bucket` series and orphans its history.
  buckets: ["10ms", "50ms", "100ms", "200ms", "500ms", "1s", "5s", "10s"]

  # The write rate of the derived series. The chart refuses less than 60s,
  # because the destination charges series x writes per minute.
  flushInterval: "60s"

  # Metric name prefix. Empty yields bare `calls_total` /
  # `duration_milliseconds_*`, the names the dashboards and alert rules query.
  namespace: ""

  # Series with no new datapoint for this long are dropped.
  expiration: "5m"

  # Ceiling on distinct dimension combinations per agent; 0 disables it. Past
  # the ceiling, new combinations fold into one entry labelled
  # `otel.metric.overflow="true"`, so hitting the limit is visible at the
  # destination. `span_name` is always a dimension, so one service that puts an
  # id in its span names can reach the ceiling. 20000 caps a runaway, not
  # normal traffic.
  cardinalityLimit: 20000

  # Every dimension multiplies cardinality, and each combination is a billable
  # series. `http.method` and `http.status_code` repeat the canonical
  # `http.request.method` and `http.response.status_code`; they stay because
  # alert rules still query the legacy names. `k8s.pod.name` and
  # `k8s.container.name` are left out on purpose: pod names change on every
  # rollout and mint series that never get another datapoint.
  dimensions:
    - k8s.namespace.name
    - k8s.deployment.name
    - http.route
    - http.method
    - http.request.method
    - http.status_code
    - http.response.status_code
    - tenant.id
```

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm -n monitoring --version 2.0.10
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm -n monitoring --version 2.0.10
```
