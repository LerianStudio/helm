<!-- {% raw %} -->
# Helm Upgrade from v11.2.2 to v11.3.0

## Topics

- **[Features](#features)**
  - [1. New Tracer partition runner](#1-new-tracer-partition-runner)
  - [2. Partition reconcile hook for Tracer](#2-partition-reconcile-hook-for-tracer)
  - [3. Label name truncation for long resource names](#3-label-name-truncation-for-long-resource-names)
- **[Configuration Reference](#configuration-reference)**
  - [Tracer partition configuration](#tracer-partition-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Rollback](#rollback)**

## Features

**Who is affected.** On default values (Tracer off, Tracer tag `4.5.1`) this upgrade adds no resource. The new Tracer CronJob and hook appear only with `tracer.enabled: true` and a Tracer tag at or above `4.6.0-beta.30`. With the Tracer on, its pods roll once with the same image, and so do the CRM pods when CRM is on: the chart label in their ConfigMap and Secret changes the checksum annotations. The ledger pods and the ledger partition workloads do not change.

### 1. New Tracer partition runner

Chart v11.3.0 introduces a new **partition runner** for the Tracer component. This scheduled job creates validation record partitions ahead of time and reports health via exit codes.

| Setting | v11.2.2 | v11.3.0 |
|---------|---------|---------|
| `tracer.partition.enabled` | (not present) | `nil` (auto-enabled for tags >= 4.6.0-beta.30) |
| `tracer.partition.schedule` | (not present) | `"0 6 * * *"` |
| `tracer.partition.resources` | (not present) | `{ limits: { cpu: 200m, memory: 128Mi }, requests: { cpu: 50m, memory: 64Mi } }` |

#### What changed

The Tracer now ships with a `/partition` command that pre-creates table partitions for validation records. A new CronJob runs this command on a daily schedule, visiting every active tenant in multi-tenant mode.

**Auto-enablement logic:**

- When `tracer.partition.enabled` is unset (nil), the chart auto-enables the runner for Tracer image tags >= `4.6.0-beta.30` (the first tag shipping the `/partition` command)
- Older tags and non-SemVer tags default to disabled
- Leave `tracer.partition.enabled` unset unless you have a reason to override. Unset renders the CronJob and the reconcile hook only when `tracer.enabled: true` and the Tracer tag is a SemVer tag at or above `4.6.0-beta.30`. `false` removes both the CronJob and the reconcile hook. `true` forces both on: use it only for a non-SemVer tag of an image that ships `/partition`. On an older image the hook cannot start `/partition`, the hook Job fails, and the upgrade is reported failed. To keep the CronJob and drop only the hook, set `tracer.partition.reconcile.enabled: false`. No value keeps the hook without the CronJob.

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0 | Healthy, unpartitioned (`unpartitioned`), or a schema without partition support (`support_missing`) |
| 1 | A database or table needs attention: connection or tenant-listing failure, timeout, rows in DEFAULT, buffer below the horizon, coverage gap, `unconfigured`, `lock_table_below_floor` |
| 2 | Invalid invocation or configuration (unknown flag, invalid environment) |

#### Default configuration

```yaml
tracer:
  partition:
    enabled:  # unset = auto (on for >= 4.6.0-beta.30)
    schedule: "0 6 * * *"
    timeZone: ""
    activeDeadlineSeconds: 1800
    resources:
      limits:
        cpu: 200m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
```

| Flag | Default | Description |
|------|---------|-------------|
| `enabled` | `nil` (auto) | Run the scheduled runner; unset enables tags >= 4.6.0-beta.30 |
| `schedule` | `"0 6 * * *"` | Cron schedule in `timeZone`, defaulting to 06:00 |
| `timeZone` | `""` | IANA time zone for `schedule` (e.g. "America/Sao_Paulo"); empty uses the kube-controller-manager's zone (UTC on most managed clusters) |
| `activeDeadlineSeconds` | `1800` | Hard timeout for one run, in seconds (30 minutes) |

#### Why this matters

On a record the Tracer converted (a Tracer database whose validation record was empty when migration 000061 ran), the migration seeds six monthly partitions and the daily `ensure` keeps them ahead of the clock. Without it, once the seeded months run out, every validation is stored in the DEFAULT partition. That is an alerting condition of the Tracer, and moving the rows out is a manual procedure. A record that already held validations keeps its single table: the runner logs `unpartitioned` and exits 0.

The default `0 6 * * *` runs at 06:00 in `timeZone`, or in the kube-controller-manager's zone (UTC on most managed clusters) when `timeZone` is empty. Managed PostgreSQL services pick their default maintenance and backup windows per region. Check your database's windows and set `schedule` and `timeZone` outside them.

> **Important:** Choose a schedule time outside your database's maintenance window. Set `timeZone` to pin the schedule to a specific zone if your cluster's kube-controller-manager runs in a different zone than your database.

#### Disabling the partition runner

If you run `/partition ensure --reconcile-indexes` from your own scheduler (daily, off-peak, with the Tracer's environment), set `enabled: false`. This also removes the reconcile hook, so run `/partition reconcile-indexes --tolerate-unavailable` yourself after each Tracer migration.

```yaml
tracer:
  partition:
    enabled: false
```

#### First run and failures

The CronJob `midaz-tracer-partition` first runs at the next `schedule` time. It runs `/partition ensure --reconcile-indexes` and is not retried until the next day (`backoffLimit: 0`). To run it now: `kubectl -n midaz create job tracer-partition-manual --from=cronjob/midaz-tracer-partition`.

- Exit 0 with `unpartitioned`: the validation record held data when migration 000061 ran and kept its single table. The runner has nothing to do there.
- Exit 0 with `support_missing`: the database has not applied migration 000060. Check the migration Job.
- Exit 1 with `lock_table_below_floor`: the partitions are created, but PostgreSQL's `max_locks_per_transaction` is below the floor for the record's partitions. Set it to at least the logged `max_locks_needed` (on standbys too), restart PostgreSQL, and run the Job again.
- Exit 1 with `unconfigured`, rows in DEFAULT, or a connection or tenant-listing failure: read the `Partition table checked` and `Partition target unavailable` lines.

Under Argo CD the CronJob sits in the last wave (`"2"` by default). A failed run turns the Application `Degraded` until a run succeeds, but it does not stop the sync of the hooks and Deployments. Alert on `kube_job_status_failed{job_name=~".*-partition-.*"} > 0`.

### 2. Partition reconcile hook for Tracer

Chart v11.3.0 adds a **partition reconcile hook** that runs after Tracer migrations to ensure indexes are created on existing partitions.

| Setting | v11.2.2 | v11.3.0 |
|---------|---------|---------|
| `tracer.partition.reconcile.enabled` | (not present) | `true` |
| `tracer.partition.reconcile.syncWave` | (not present) | `"1"` |
| `tracer.partition.reconcile.activeDeadlineSeconds` | (not present) | `1800` |
| `tracer.partition.reconcile.ttlSecondsAfterFinished` | (not present) | `259200` |

#### What changed

A new Job runs `/partition reconcile-indexes --tolerate-unavailable` as a `post-install,post-upgrade` hook (Argo CD `Sync` hook). An unreachable database or tenant, or an index still pending, is logged as a Warn and does not fail the hook; the daily `ensure --reconcile-indexes` retries it. The hook behaves as follows:

- Empty registries and unpartitioned tables exit 0 (no-op)
- Existing partitions get their indexes reconciled after a schema migration
- A startup error (including licence gateway failures) still fails the hook

**Before (v11.2.2):**

There is no Tracer reconcile step: Tracer images before `4.6.0-beta.30` have no partitioned record and no `/partition` command. The hook realizes the indexes Tracer migrations register; the registry is empty at `4.6.0-beta.30`, so the hook exits 0 at once.

**After (v11.3.0):**

```yaml
tracer:
  partition:
    reconcile:
      enabled: true
      syncWave: "1"
      activeDeadlineSeconds: 1800
      ttlSecondsAfterFinished: 259200
```

| Flag | Default | Description |
|------|---------|-------------|
| `enabled` | `true` | Run reconcile-indexes after migration as a Sync hook |
| `syncWave` | `"1"` | Argo CD sync wave (after the migration Job's default wave 0); on plain Helm it runs post-install/post-upgrade with hook weight "10" |
| `activeDeadlineSeconds` | `1800` | Hard timeout for the reconcile Job (30 minutes; a concurrent index build on a large partition can take a while) |
| `ttlSecondsAfterFinished` | `259200` | How long a failed reconcile Job is kept for inspection (3 days); a successful hook Job is deleted at once |

#### Argo CD sync wave ordering

Under Argo CD the reconcile Job runs in sync wave `"1"`, after the Tracer migration Job (wave `"0"`) and alongside the Tracer Deployment (also wave `"1"`). It does not gate the rollout. On plain Helm it is a `post-install,post-upgrade` hook with weight `10`: it runs after the `pre-upgrade` migration Job and after the release's resources, including the new Tracer pods, are applied.

#### Why this matters

The hook realizes the indexes that later Tracer migrations register on existing partitions. The registry is empty at `4.6.0-beta.30`, so today the hook has nothing to build.

> **Note:** A concurrent index build on a large partition can take several minutes. The default 30-minute timeout accommodates most scenarios, but you may need to increase `activeDeadlineSeconds` for very large datasets.

#### Disabling the reconcile hook

If you manage index reconciliation out-of-band:

```yaml
tracer:
  partition:
    reconcile:
      enabled: false
```

### 3. Label name truncation for long resource names

Chart v11.3.0 shortens the `app.kubernetes.io/name` label of the partition workloads when it would exceed the Kubernetes limit of 63 characters.

#### What changed

The `app.kubernetes.io/name` label of the four partition workloads (ledger and Tracer CronJobs and reconcile hooks) is `<nameOverride>-<component>`. Starting with 11.3.0, a value past 63 characters becomes a 27-character prefix, an 8-character hash of the whole value, and a 26-character tail. This only happens with a `nameOverride` of 37 characters or more for the reconcile hooks, and 47 or more for the CronJobs. Below that nothing changes. At and above it, 11.2.2 rendered a ledger reconcile hook label the API server rejects, so no working install sees a changed label. Other workloads' labels are not shortened.

## Configuration Reference

### Tracer partition configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `tracer.partition.enabled` | bool (unset = auto) | `nil` (auto) | Run the scheduled partition runner; unset enables tags >= 4.6.0-beta.30 |
| `tracer.partition.schedule` | string | `"0 6 * * *"` | Cron schedule in `timeZone`, defaulting to 06:00 |
| `tracer.partition.timeZone` | string | `""` | IANA time zone for `schedule` (e.g. "America/Sao_Paulo"); empty uses kube-controller-manager's zone |
| `tracer.partition.activeDeadlineSeconds` | int | `1800` | Hard timeout for one run, in seconds |
| `tracer.partition.reconcile.enabled` | bool | `true` | Run reconcile-indexes after migration as a Sync hook |
| `tracer.partition.reconcile.syncWave` | string or integer | `"1"` | Argo CD sync wave (after migration Job's wave 0) |
| `tracer.partition.reconcile.activeDeadlineSeconds` | int | `1800` | Hard timeout for the reconcile Job, in seconds |
| `tracer.partition.reconcile.ttlSecondsAfterFinished` | int | `259200` | How long a failed reconcile Job is kept for inspection (3 days) |
| `tracer.partition.resources.limits.cpu` | string | `"200m"` | CPU limit for the partition runner |
| `tracer.partition.resources.limits.memory` | string | `"128Mi"` | Memory limit for the partition runner |
| `tracer.partition.resources.requests.cpu` | string | `"50m"` | Minimum CPU request for the partition runner |
| `tracer.partition.resources.requests.memory` | string | `"64Mi"` | Minimum memory request for the partition runner |

## Migration Steps

1. **Review the Tracer partition runner schedule.** The default schedule runs at 06:00 in the kube-controller-manager's time zone. If your database has a maintenance window near this time, adjust the schedule. Check your database's own maintenance and backup windows and pick a time outside them:

   ```yaml
   tracer:
     partition:
       schedule: "0 4 * * *"  # 04:00 in America/Sao_Paulo instead of 06:00
       timeZone: "America/Sao_Paulo"
   ```

2. **Optionally disable the partition runner.** Only if you run `/partition ensure --reconcile-indexes` from your own scheduler. This also removes the reconcile hook:

   ```yaml
   tracer:
     partition:
       enabled: false
   ```

3. **Optionally disable only the reconcile hook.** If you manage index reconciliation out-of-band and keep the CronJob:

   ```yaml
   tracer:
     partition:
       reconcile:
         enabled: false
   ```

> **Note:** No action is required for the label truncation.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.3.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.3.0 --timeout 35m
```

With no `-f` and no `--set`, Helm reuses the values of the current release with the 11.3.0 chart defaults. `--timeout 35m` lets Helm wait for the ledger reconcile hook (`pre-upgrade`) and the Tracer reconcile hook (`post-upgrade`) up to their 1800 s deadline. Adjust it if you change either `partition.reconcile.activeDeadlineSeconds`.

## Rollback

- **Rollback:** a Helm rollback to 11.2.2 deletes the `midaz-tracer-partition` CronJob and its Jobs. A failed reconcile hook Job stays until its 3-day TTL. Partitions the runner created stay in the database. A rollback also restores the 11.2.2 values: if this upgrade raised `tracer.image.tag` to `4.6.0-beta.30` or later and the record was converted, keep that tag (set it explicitly), because the Tracer image must not go below `4.6.0-beta.30` on a converted record. 11.2.2 schedules no Tracer partition pass, so run `/partition ensure` yourself before the seeded months run out.
<!-- {% endraw %} -->
