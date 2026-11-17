<!-- {% raw %} -->
# Helm Upgrade from v2.6.1 to v2.6.2

## Scope

`lerian-common-helm` 2.6.2 is a library chart, not an installable application.
Its `appVersion` remains `1.0.0`; this release does not update application images.
The functional change from chart 2.6.1 is in the opt-in
`lerian-common.health.prometheusRule` helper. Consumers that do not include this
helper, or leave `monitoring.prometheusRule.enabled` disabled, do not emit its
PrometheusRule. Updating the library alone does not update deployed consumers:
the consuming chart must resolve the new dependency and be redeployed.

## Alert change

`HealthReportCheckDown` changes from:

```promql
max by (job, check) (health_check_status{status=~"down|degraded", mode="report"}) == 1
```

with `for: 15m`, to:

```promql
max by (job, check) (
  (min_over_time((sum without (status) (health_check_status{mode="report",status=~"down|degraded"}))[10m:1m]) > 0)
  and
  (sum without (status) (health_check_status{mode="report",status=~"down|degraded"}) > 0)
)
```

with `for: 5m`. Severity remains `warning`. The summary becomes
`A live pod reports a Report-mode check down or degraded`; the new description
explains that report checks do not remove pods from traffic and that a missing
series resolving an alert does not prove recovery.

The inner aggregation retains labels other than `status`, including the instance
label when supplied by the metric producer. The final aggregation is still by
`job, check`, not a separate alert per pod. The subquery uses a 10-minute range
and a 1-minute resolution; `for: 5m` is additional pending time, not a guarantee
that every alert fires exactly 5 or 10 minutes after startup. Actual timing and
resolution depend on samples, staleness, rule evaluation and pod churn. The old
rule also had a pending duration (`15m`); it did not fire immediately on startup.
Validate representative startup, recovery and missing-series scenarios in your
monitoring environment before relying on the new behavior. No Prometheus runtime
simulation or live upgrade is claimed by this guide.

## Prepare and preview the consuming chart

Do not run `helm install` or `helm upgrade` against the library itself. Work on
the product or umbrella chart that already consumes it. Confirm that the selected
consumer actually calls the health helper and supports the monitoring values.
A Prometheus Operator installation with the PrometheusRule CRD is required when
that resource is enabled.

1. Preserve the consumer's existing `Chart.yaml`, `Chart.lock`, release revision,
   complete intended values and Secret references privately. Treat exported values
   and rendered manifests as sensitive. Preserve unrelated dependency pins.
2. Change only the existing `lerian-common-helm` dependency version to `2.6.2`,
   retaining its verified publication repository. The dependency name is
   `lerian-common-helm`, not `lerian-common`. If the consumer uses an alias, retain it.
3. Resolve dependencies in the consumer's reviewed source workspace:

```bash
helm dependency update ./consumer-chart
```

Review `Chart.lock` and every resolved dependency: this command can update other
ranged dependencies too. Do not ship unrelated upgrades accidentally. Commit the
reviewed consumer dependency change through that consumer's normal release process.
For reproducible builds from the approved lock, use:

```bash
helm dependency build ./consumer-chart
helm lint ./consumer-chart -f complete-intended-values.yaml
helm template my-product ./consumer-chart -n my-namespace \
  -f complete-intended-values.yaml > rendered-private.yaml
```

`complete-intended-values.yaml` must contain the complete intended configuration,
including existing overrides and Secret references, not merely the monitoring
fragment. Render both the previous and updated consumer with identical values and
release identity. Privately compare the PrometheusRule expression, duration,
annotations, labels and all other resources. Check query cost and alert routing;
do not assume that a shorter `for` always means faster detection. No application
or database migration is introduced by this library diff, but the consuming chart
may have its own upgrade prerequisites.

If helm-diff is already available, preview the **consumer**, not the library:

```bash
helm diff upgrade my-product ./consumer-chart -n my-namespace \
  --reset-values -f complete-intended-values.yaml
```

## Upgrade and verify

After reviewing the complete intended values and the consumer's own upgrade
procedure:

```bash
helm upgrade my-product ./consumer-chart -n my-namespace \
  --reset-values -f complete-intended-values.yaml --wait --timeout 10m
helm status my-product -n my-namespace
kubectl get prometheusrule -n my-namespace PROMETHEUSRULE_NAME -o yaml
```

Replace the example release, namespace, path and rendered resource name. The
explicit reset avoids inheriting unreviewed stored overrides; omitting settings
from the complete values file can reset them to defaults. Verify that Prometheus
selects and loads the updated rule, that there are no evaluation errors, and that
alert routing still matches the intended labels. Rule loading and observed alert
behavior require live validation; a Helm render does not establish them.

## Rollback

Record the previous consumer release revision before the upgrade. If the new rule
causes unacceptable behavior, follow the consumer's rollback procedure and restore
the previously reviewed dependency and rule configuration. For a retained Helm
revision:

```bash
helm rollback my-product PREVIOUS_REVISION -n my-namespace --wait --timeout 10m
```

Verify the loaded Prometheus rule again. Helm rollback is not a database or
persistent-volume restore and does not reverse unrelated application-side effects.
<!-- {% endraw %} -->
