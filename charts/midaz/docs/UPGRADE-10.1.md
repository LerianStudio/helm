# Helm Upgrade from v10.0.0 to v10.1.0

## Topics

- **[Features](#features)**
  - [1. Ledger Partition Runner](#1-ledger-partition-runner)
- **[Configuration Reference](#configuration-reference)**
- **[Disabling the runner](#disabling-the-runner)**
- **[What to expect after the upgrade](#what-to-expect-after-the-upgrade)**
- **[Alert signals](#alert-signals)**
- **[BYOC and installs without this chart](#byoc-and-installs-without-this-chart)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Ledger Partition Runner

Ledger images from `4.4.0` on ship a second binary, `/partition`, next to `/app`.
It does the online work on the `transaction` and `operation` tables that a schema
migration cannot: it creates time partitions ahead of the clock on a partitioned
database and builds the indexes registered in the partition-index registry. The
image entrypoint is still `/app`; the chart runs the runner by overriding the
container command.

The chart adds two workloads for it:

| Resource | Name | Runs | When |
|----------|------|------|------|
| `CronJob` | `<release>-ledger-partition` | `/partition ensure --reconcile-indexes` | Daily, `0 3 * * *` by default |
| `Job` (hook) | `<release>-ledger-partition-reconcile-<ledger tag>` | `/partition reconcile-indexes --tolerate-unavailable` | On every install, upgrade and Argo CD sync, after the ledger migration Job and alongside the app rollout |

- **`ensure`** creates the missing partitions up to the configured horizon,
  refreshes the statistics of each partitioned table and reports a health verdict
  per table. It never detaches or drops a partition and runs no DDL on an
  unpartitioned table. `--reconcile-indexes` adds the index reconcile pass to the
  same daily run, so an index the deploy hook skipped is retried every day.
- **`reconcile-indexes`** brings every database in line with the partition-index
  registry. An empty registry, an unpartitioned table or a database without the
  partition support migration all exit `0` without changes, so the hook never
  blocks a sync on an older schema. `--tolerate-unavailable` also keeps an
  unreachable tenant database or a pending index from failing the hook: **a deploy
  never fails because of one**. Those failures still surface in the daily CronJob
  run (exit `1`, a failed Job, `kube_job_status_failed`). The hook still fails
  (exit `1`) on an invalid registry entry, a failed index build or a name
  conflict, and (exit `2`) on a usage or startup error.
- **Ordering.** The reconcile Job runs after the migration Job and alongside the
  app rollout, not before the new ledger version starts serving. On plain Helm it
  is a `post-install,pre-upgrade` hook with weight `10`, after the migration Job's
  weight `0`. On Argo CD it is a `Sync` hook in wave
  `ledger.partition.reconcile.syncWave` (default `"1"`, the Deployment's wave),
  after the migration Job's wave `0`. Both hooks are deleted once they succeed;
  a failed one is kept for `ledger.partition.reconcile.ttlSecondsAfterFinished`
  (default 3 days), like the migration Jobs.
- **One CronJob per release.** In multi-tenant mode the runner lists the active
  tenants of the ledger itself and visits each tenant's transaction database; a
  failing tenant never stops the pass.
- **Connection settings.** Both workloads set `DB_TRANSACTION_*` and the
  `MULTI_TENANT_*` block inline from the release values (the same datastore masks
  and defaults as the migration Job), so on a plain `helm upgrade` the
  `pre-upgrade` hook uses this release's values rather than the previous
  ConfigMap. Everything else comes from the ledger's own ConfigMap and Secret, and
  the PostgreSQL password from the same Secret the migration Job reads. Nothing new has
  to be provisioned. The runner never logs a DSN, host, user or password.
- **Scheduling.** The pods reuse `ledger.image`, `ledger.imagePullSecrets`,
  `ledger.podSecurityContext`, `ledger.securityContext`, `ledger.nodeSelector`,
  `ledger.affinity` and `ledger.tolerations`, with their own small resource block.

#### When it renders

`ledger.partition.enabled` is tri-state:

| Value | Result |
|-------|--------|
| unset (default) | On for stable ledger tags `>= 4.4.0`; off for earlier tags, for pre-releases (set `true` on a pre-release that ships `/partition`) and for non-SemVer tags |
| `true` | On, for an earlier or custom build that already carries `/partition` |
| `false` | Off |

The chart default ledger tag in this release is below `4.4.0`, so **a default
upgrade renders nothing new**. The runner appears when you move the ledger to a stable
`4.4.0` or later image.

#### Configuration Example

```yaml
ledger:
  partition:
    # Unset = auto by ledger tag; true / false pins it
    enabled:
    schedule: "0 3 * * *"
    # IANA time zone; empty uses the kube-controller-manager's zone
    timeZone: "America/Sao_Paulo"
    activeDeadlineSeconds: 1800
    reconcile:
      enabled: true
      syncWave: "1"
      activeDeadlineSeconds: 1800
      ttlSecondsAfterFinished: 259200
    resources:
      limits:
        cpu: 200m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
```

## Configuration Reference

| Setting | v10.0.0 | v10.1.0 |
|---------|--------|--------|
| `ledger.partition.enabled` | Not present | unset (auto: on for ledger `>= 4.4.0`) |
| `ledger.partition.schedule` | Not present | `"0 3 * * *"` |
| `ledger.partition.timeZone` | Not present | `""` |
| `ledger.partition.activeDeadlineSeconds` | Not present | `1800` |
| `ledger.partition.reconcile.enabled` | Not present | `true` |
| `ledger.partition.reconcile.syncWave` | Not present | `"1"` |
| `ledger.partition.reconcile.activeDeadlineSeconds` | Not present | `1800` |
| `ledger.partition.reconcile.ttlSecondsAfterFinished` | Not present | `259200` |
| `ledger.partition.resources` | Not present | `200m`/`128Mi` limits, `50m`/`64Mi` requests |

**Template Changes:**

- New `templates/ledger/partition-cronjob.yaml` and
  `templates/ledger/partition-reconcile-job.yaml`.
- The Job-name helper shared with the migration Jobs accepts a suffix, so the
  reconcile Job name carries the ledger tag and stays within 63 characters. The
  migration Job names are unchanged.

## Disabling the runner

Turn both workloads off:

```yaml
ledger:
  partition:
    enabled: false
```

Keep the daily `ensure` and drop only the reconcile hook:

```yaml
ledger:
  partition:
    reconcile:
      enabled: false
```

Turning the runner off on a database that is still unpartitioned has no effect
on the ledger. On a **partitioned** database, `ensure` is what keeps future
partitions ahead of the clock; if it stops, new rows eventually land in the
DEFAULT partition (see [Alert signals](#alert-signals)).

## What to expect after the upgrade

- **Existing databases stay unpartitioned.** The schema keeps its current layout
  until a database is converted. The runner then logs one line per table with
  `skipped_reason=unpartitioned` and exits `0`:

  ```text
  Partition table not partitioned  {"database": "single-tenant", "table": "transaction", "created": 0, "skipped_reason": "unpartitioned"}
  Partition table not partitioned  {"database": "single-tenant", "table": "operation", "created": 0, "skipped_reason": "unpartitioned"}
  Partition ensure pass finished   {"databases": 1, "databases_failed": 0}
  ```

  The reconcile pass logs `Partition index registry empty` and exits `0`. A
  multi-tenant database that has not received the partition support migration
  yet is reported as `support_missing` and also exits `0`.
- **`/readyz`.** In single-tenant mode the ledger exposes two informational
  checks, `partition-future-buffer` and `partition-default-rows`. They report only
  `up` or `skipped`, never `down`, so they never turn `/readyz` into a `503`. On an
  unpartitioned database both stay `skipped` with
  `reason: transaction table is not partitioned` until the conversion. In
  multi-tenant mode they are not registered; the tenant health prober reports a
  `partition` dependency per tenant instead.
- **Run it on demand** to check a database without waiting for the schedule:

  ```bash
  kubectl -n midaz create job partition-manual --from=cronjob/midaz-ledger-partition
  kubectl -n midaz logs -f job/partition-manual
  ```

## Alert signals

- **Exit code of the runner Job.** `0` healthy, unpartitioned or support missing;
  `1` at least one database or table needs attention (unreachable database, rows
  in DEFAULT, buffer below the horizon, coverage gap, index still pending or
  failed, invalid registry entry); `2` usage or startup error. The reconcile hook
  runs with `--tolerate-unavailable`, so an unreachable database or a pending
  index does not fail it, while an invalid entry, a failed build, a name conflict
  or a startup error still does; the daily CronJob runs both
  passes without that flag and is where the other failures show. The CronJob uses `backoffLimit: 0`, so a
  failed run stays visible as a failed Job and the next schedule repeats the
  work. With kube-state-metrics:

  ```promql
  kube_job_status_failed{job_name=~".*-partition-.*"} > 0
  ```

- **Ledger metrics** (only for a partitioned single-tenant database):
  `ledger_partition_future_buffer_depth` (warn when below the table's horizon for
  more than a day), `ledger_partition_default_rows` and
  `ledger_partition_default_inserts_total` (any value above zero is act-now).
- **Multi-tenant:** `tenant_dependency_up_ratio{dependency="partition"} == 0` for
  a tenant whose partitions are unhealthy.

The full rule set and the DEFAULT runbook are in the Midaz repository, under
"Partition health and alerting" in `docs/infra/migrations.md`.

## BYOC and installs without this chart

If you deploy the ledger without this chart, run the same two steps yourself,
from the ledger image with the ledger's own `DB_TRANSACTION_*` variables (or
`MULTI_TENANT_*` and `APPLICATION_NAME` in multi-tenant mode):

1. `/partition reconcile-indexes --tolerate-unavailable` after every migration
   run, alongside the rollout of the new ledger version.
2. `/partition ensure --reconcile-indexes` once a day, off-peak.

Treat a non-zero exit code of the daily run as an alert; the deploy-time step
fails only on an invalid registry entry, a failed index build, a name conflict
or a startup error.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.0 -n midaz
```
