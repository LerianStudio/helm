<!-- {% raw %} -->
# Helm Upgrade from v2.6.1 to v2.6.2

## Topics ToC

- **[Fixes](#fixes)**
  - [1. HealthReportCheckDown Alert Refinement](#1-healthreportcheckdown-alert-refinement)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. HealthReportCheckDown Alert Refinement

The `HealthReportCheckDown` Prometheus alert rule has been refined to reduce false positives and improve alert accuracy for Report-mode health checks.

#### What changed

The alert query, duration threshold, and annotations have been updated to better handle pod lifecycle events and distinguish between transient failures and persistent degradation.

| Setting | v2.6.1 | v2.6.2 |
|---------|---------|---------|
| Alert expression | `max by (job, check) (health_check_status{status=~"down\|degraded", mode="report"}) == 1` | Multi-clause expression with 10-minute lookback window |
| Alert duration (`for:`) | `15m` | `5m` |
| Alert summary | `"A reported dependency is down or degraded"` | `"A live pod reports a Report-mode check down or degraded"` |
| Alert description | _(none)_ | Detailed explanation of check behavior and resolution semantics |

**Before (v2.6.1):**

```yaml
- alert: HealthReportCheckDown
  expr: max by (job, check) (health_check_status{status=~"down|degraded", mode="report"}) == 1
  for: 15m
  labels: {severity: warning}
  annotations: {summary: "A reported dependency is down or degraded"}
```

**After (v2.6.2):**

```yaml
- alert: HealthReportCheckDown
  expr: |-
    max by (job, check) (
      (min_over_time((sum without (status) (health_check_status{mode="report",status=~"down|degraded"}))[10m:1m]) > 0)
      and
      (sum without (status) (health_check_status{mode="report",status=~"down|degraded"}) > 0)
    )
  for: 5m
  labels: {severity: warning}
  annotations:
    summary: "A live pod reports a Report-mode check down or degraded"
    description: >-
      A live pod reports the Report-mode check `{{ $labels.check }}` of `{{ $labels.job }}` as down or degraded
      for the last 10 minutes, or since it started if it is younger, and still now. Report checks never remove the pod from traffic.
      The check is either an external dependency of the service or a worker of the service itself. A check that has not
      been up since the pod started points to a code or configuration defect, not to an outage. The alert
      resolves when the check returns to up or when the pod that reports it stops existing; a resolution by
      missing series does not prove recovery.
```

#### Why it matters

**Problem solved:**

The v2.6.1 alert fired immediately when a pod started with a down check, even if the check was expected to be down during initialization (e.g., waiting for a database migration). It also did not distinguish between a pod that had been healthy and degraded versus a pod that was misconfigured from the start.

**Improvements in v2.6.2:**

1. **Lookback window:** The new expression uses `min_over_time(...[10m:1m])` to check if the check has been down for at least 10 minutes (or since pod start if younger). This prevents alerts on transient startup failures.

2. **Per-pod granularity:** The `sum without (status)` aggregation preserves the OpenTelemetry instance label, ensuring the alert is scoped to individual pods. A pod that reported `up` in the last 10 minutes cannot fire the alert on its final `down` sample when it terminates.

3. **Faster detection:** The `for: 5m` duration (down from 15m) allows faster alerting once the 10-minute lookback condition is met, reducing mean time to detection for persistent failures.

4. **Clearer semantics:** The new description explains that:
   - Report-mode checks never remove pods from traffic (unlike Request-mode checks)
   - A check that has never been `up` since pod start indicates a configuration or code defect, not an infrastructure outage
   - Alert resolution by missing series (pod deletion) does not prove the underlying issue is fixed

#### Operational impact

> **Important:** This is a library chart (type: library) that is consumed as a dependency by other charts. The `lerian-common.health.prometheusRule` helper is opt-in and only affects charts that explicitly call it with `monitoring.prometheusRule.enabled: true`.

**For operators using the health PrometheusRule:**

- **No configuration changes required.** The alert rule is automatically updated when you upgrade `lerian-common` and redeploy charts that consume the `lerian-common.health.prometheusRule` helper.

- **Alert behavior changes:**
  - Pods that start with a down check will not fire an alert until the check has been down for 10 minutes (or 5 minutes if the pod is younger than 10 minutes).
  - Alerts will resolve when the pod is deleted, even if the underlying dependency is still down. Monitor alert resolution patterns to distinguish between pod churn and genuine recovery.
  - Alerts that fire immediately after pod start (within 10 minutes) indicate a configuration or code defect that should be investigated separately from infrastructure outages.

- **Prometheus query performance:** The new expression uses subqueries (`[10m:1m]`) which may increase query cost. If you observe Prometheus performance degradation, consider increasing the evaluation interval for this rule group or tuning Prometheus resource limits.

**For operators not using the health PrometheusRule:**

No impact. The `lerian-common.health.prometheusRule` helper renders nothing unless `monitoring.prometheusRule.enabled` is set to `true` in the consuming chart.

#### Migration steps

1. **Upgrade `lerian-common` dependency** in your product or umbrella chart's `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 2.6.2
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Redeploy charts that use the health PrometheusRule:**

```bash
helm upgrade my-chart . -n lerian --values values.yaml
```

4. **Verify the PrometheusRule resource** has been updated:

```bash
kubectl get prometheusrule -n lerian -o yaml | grep -A 20 HealthReportCheckDown
```

You should see the new multi-clause expression with the 10-minute lookback window.

5. **Review existing alerts** in your Prometheus/Alertmanager instance. Alerts that were firing under v2.6.1 may resolve or change behavior:
   - Alerts for pods that recently started (< 10 minutes ago) will resolve automatically.
   - Alerts for pods with persistent down checks (> 10 minutes) will continue firing but with updated annotations.

6. **(Optional) Adjust alert routing or silences** if your alerting pipeline relies on the old summary text (`"A reported dependency is down or degraded"`). The new summary is `"A live pod reports a Report-mode check down or degraded"`.

> **Note:** The alert severity remains `warning`. No changes to alert routing based on severity are required.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.6.2 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of this upgrade, run `helm diff` on the **product charts** that consume the `lerian-common.health.prometheusRule` helper with `monitoring.prometheusRule.enabled: true`.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.6.2 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update it as a dependency in your umbrella or product chart's `Chart.yaml`, run `helm dependency update`, and upgrade the consuming chart.
<!-- {% endraw %} -->
