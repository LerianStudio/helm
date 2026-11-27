<!-- {% raw %} -->
# Helm Upgrade from v11.4.x to v11.5.0

## Topics

- **[Before you upgrade](#before-you-upgrade)**
- **[Features](#features)**
  - [1. Index build bounds on the partition runner](#1-index-build-bounds-on-the-partition-runner)
  - [2. On-demand index build CronJob](#2-on-demand-index-build-cronjob)
- **[Which run builds your index](#which-run-builds-your-index)**
- **[Building a large index by hand](#building-a-large-index-by-hand)**
- **[Images older than 4.7.0](#images-older-than-470)**
- **[If you raised the hook deadline](#if-you-raised-the-hook-deadline)**
- **[Operational impact](#operational-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Before you upgrade

1. **Read the size of the tables the reconcile pass builds on.** The bounds below decide which run builds a registered index, by the size of the table (or of one partition). See [Which run builds your index](#which-run-builds-your-index).
2. **Check your image tags.** The bounds take effect only with ledger and tracer images `4.7.0` or later. Older images ignore them. See [Images older than 4.7.0](#images-older-than-470).
3. **Check your values for a raised hook deadline.** If you raised `ledger.partition.reconcile.activeDeadlineSeconds` and Helm `--timeout` to build a large index in the hook, the hook now defers that build. See [If you raised the hook deadline](#if-you-raised-the-hook-deadline).

## Features

### 1. Index build bounds on the partition runner

The partition runner (`/partition`) builds the indexes registered in `partition_index_registry` with `CREATE INDEX CONCURRENTLY`. A concurrent build cannot be resumed. On a large table it did not finish inside the Job deadline: the `pre-upgrade` hook died, left an invalid index and failed `helm upgrade`, and the daily CronJob started the same build again every day and was stopped again by its deadline.

From image `4.7.0`, the runner reads two variables and does not start a build that does not fit:

| Variable | Meaning |
|----------|---------|
| `PARTITION_INDEX_BUILD_MAX_BYTES` | Largest relation, in bytes (the table, or one partition), whose index build a run starts. `0` sets no limit. |
| `PARTITION_INDEX_BUILD_WINDOW_SECONDS` | Seconds, from the start of the process, during which a run starts index builds. `0` sets no window. |

A build that does not fit is not started. The entry stays `pending` with detail `build_deferred`, the runner logs `Partition index build deferred` (Warn) with the relation and its size, and the gauge `ledger_partition_index_unrealized` (`tracer_partition_index_unrealized` for the tracer) stays above 0. The reconcile hook still exits 0. The daily CronJob exits 1 until the index exists.

Chart 11.5.0 renders both variables on every partition workload, with four new keys per product:

| Key | Default | Rendered on |
|-----|---------|-------------|
| `ledger.partition.reconcile.maxBuildBytes` | `2147483648` (2 GiB) | Reconcile hook Job |
| `ledger.partition.reconcile.buildWindowSeconds` | `60` | Reconcile hook Job |
| `ledger.partition.maxBuildBytes` | `12884901888` (12 GiB) | Daily CronJob (`ensure --reconcile-indexes`) |
| `ledger.partition.buildWindowSeconds` | `600` | Daily CronJob |

The same keys exist under `tracer.partition`, with the same defaults. `0` renders `"0"` (no limit, no window). A negative or non-integer value fails the render.

The defaults were measured on a lab PostgreSQL 17, with the I/O converted to that of a small cloud disk: about 14 MiB/s of table read in the worst case. On faster storage you can raise them; keep the hook bound small enough to finish well inside `reconcile.activeDeadlineSeconds` and Helm `--timeout`.

The existing keys (`activeDeadlineSeconds`, `schedule`, `timeZone`, `reconcile.enabled`, `reconcile.syncWave`, `reconcile.ttlSecondsAfterFinished`) keep their behavior.

### 2. On-demand index build CronJob

A new key, `ledger.partition.build.enabled` (default `false`), renders a CronJob for the index a bounded run deferred:

| Object | Kind | What it does |
|--------|------|--------------|
| `midaz-ledger-partition-build` | CronJob, `suspend: true` | `reconcile-indexes` with both bounds at `"0"` (no limit, no window), `backoffLimit: 0`, no deadline by default |

It never runs by itself. You start a run with `kubectl create job --from=cronjob/...`, as in [Building a large index by hand](#building-a-large-index-by-hand).

| Key | Default | Meaning |
|-----|---------|---------|
| `ledger.partition.build.enabled` | `false` | Render the CronJob |
| `ledger.partition.build.activeDeadlineSeconds` | empty | Deadline of the build Job, in seconds. Empty sets none. |
| `ledger.partition.build.ttlSecondsAfterFinished` | `259200` | How long the finished Job is kept |

`tracer.partition.build.*` renders `midaz-tracer-partition-build` the same way. Neither renders when the product or its partition runner is off.

## Which run builds your index

At about 390 bytes per row of `transaction`, the defaults split the work into three bands:

| Size of `transaction` (or of one partition) | Rows, roughly | Built by |
|---------------------------------------------|---------------|----------|
| Up to 2 GiB | Up to 5.5 million | The reconcile hook, during the upgrade |
| 2 GiB to 12 GiB | 5.5 to 33 million | The daily CronJob at 06:00, within 24 hours of the upgrade |
| Above 12 GiB | Above 33 million | You, with the on-demand build CronJob |

Read the size on the transaction database (in a multi-tenant deployment, on each tenant's transaction database: the runner reconciles each one on its own):

```sql
SELECT pg_size_pretty(pg_relation_size('transaction'));
```

On the partitioned layout the bound applies to each partition, so read the largest partition instead:

```sql
SELECT p.relname, pg_size_pretty(pg_relation_size(p.oid))
FROM pg_inherits i JOIN pg_class p ON p.oid = i.inhrelid
WHERE i.inhparent = 'transaction'::regclass
ORDER BY pg_relation_size(p.oid) DESC
LIMIT 1;
```

## Building a large index by hand

Use this when the table is above `ledger.partition.maxBuildBytes`, or when you see `Partition index build deferred` in the CronJob log.

1. **Check the free disk.** While it runs, the build takes about 68 bytes per row of `transaction` for the index, plus about 60 bytes per row of sort temp (temporary files, or `maintenance_work_mem`). For 100 million rows, that is about 6.8 GB of index and 6 GB of temp.
2. **Render the build CronJob.** Add this to your values file and apply it (`helm upgrade`, or your Argo CD sync):

   ```yaml
   ledger:
     partition:
       build:
         enabled: true
   ```

3. **Start the build:**

   ```bash
   JOB=build-$(date +%Y%m%d)
   kubectl create job --from=cronjob/midaz-ledger-partition-build "$JOB" -n midaz
   ```

   Run it outside your peak hours, on a node that stays up. A Job stopped halfway leaves an invalid index; the next run drops it and starts over.

4. **Watch the log.** `Partition index build started` names the relation and its size; `Partition index build finished` closes it with `duration_ms` and `succeeded`:

   ```bash
   kubectl logs -f "job/$JOB" -n midaz
   ```

5. **Confirm that every registered index is valid:**

   ```sql
   SELECT r.index_name, i.indisvalid
   FROM partition_index_registry r
   LEFT JOIN pg_class c ON c.relname = r.index_name AND c.relnamespace = current_schema()::regnamespace
   LEFT JOIN pg_index i ON i.indexrelid = c.oid
   WHERE r.dropped_at IS NULL;
   ```

   Every row must show `indisvalid = true`. NULL means the index was not built yet; `false` means the next run rebuilds it. In a multi-tenant deployment, run it on every tenant's transaction database: the build Job visits them all, and one tenant can still be pending.

6. **Set `ledger.partition.build.enabled` back to `false`** once every database shows its indexes valid, and apply again. The CronJob and its Jobs go away.

For the tracer, use `tracer.partition.build.enabled` and `cronjob/midaz-tracer-partition-build` against the tracer database.

## Images older than 4.7.0

Images before `4.7.0` ignore both variables, so the chart renders with any image tag. On those images a large index still runs into the Job deadline, as before.

For those images, have the table owner build the index by hand before the upgrade, on each transaction database, with the registered name and definition. First list what is registered and what already exists:

```sql
SELECT r.index_name, r.table_name, r.definition, i.indisvalid
FROM partition_index_registry r
LEFT JOIN pg_class c ON c.relname = r.index_name AND c.relnamespace = current_schema()::regnamespace
LEFT JOIN pg_index i ON i.indexrelid = c.oid
WHERE r.dropped_at IS NULL;
```

On the unpartitioned layout:

```sql
-- indisvalid = false (left by an interrupted build): drop it first; an older runner
-- would rebuild it in the hook with no bound, and the upgrade would stop again
DROP INDEX CONCURRENTLY <index_name>;

-- indisvalid NULL, or after the drop:
CREATE INDEX CONCURRENTLY <index_name> ON <table_name> <definition>;
```

The hook then finds the index, adopts it and sets its fingerprint.

PostgreSQL builds no partitioned index concurrently, so on the partitioned layout the owner builds one index per partition, under the name the runner gives that partition's index; any other name is never attached. This lists each partition with that name:

```sql
SELECT p.relname AS partition,
       left('<index_name>', 50) || '_' ||
       left(md5(convert_to('<index_name>', 'UTF8') || '\x00'::bytea || convert_to(p.relname, 'UTF8')), 12) AS partition_index
FROM pg_inherits i JOIN pg_class p ON p.oid = i.inhrelid
WHERE i.inhparent = '<table_name>'::regclass;

-- for each partition whose index does not exist yet (drop an invalid one first, as above):
CREATE INDEX CONCURRENTLY <partition_index> ON <partition> <definition>;
```

The next run attaches them to the parent index.

## If you raised the hook deadline

If you followed the [11.2 guide](UPGRADE-11.2.md#large-ledgers) and raised `ledger.partition.reconcile.activeDeadlineSeconds` and `--timeout` to build a large index in the hook, the hook now defers any table above 2 GiB. To keep building there, raise `reconcile.maxBuildBytes` together with the deadline:

```yaml
ledger:
  partition:
    reconcile:
      activeDeadlineSeconds: 7200
      maxBuildBytes: 0
```

`0` removes the limit; a number in bytes keeps a ceiling. `reconcile.buildWindowSeconds` (60) still defers any build due after the first minute of the hook, such as a later tenant or partition: raise it too, or set it to `0`. Keep Helm `--timeout` above the deadline.

## Operational impact

- **Workloads:** the change adds nothing to the ledger and tracer Deployments. The partition CronJobs and the reconcile Jobs get two new env entries.
- **Upgrade time:** on a ledger above 2 GiB, the reconcile hook defers the build instead of running it, so `helm upgrade` no longer waits for it.
- **Daily CronJob:** it exits 1, and the Job shows as failed, while an index stays deferred. Expect this on a ledger above 12 GiB until you run the on-demand build.
- **Monitoring:** `Partition index build deferred` (Warn) in the runner log, and `ledger_partition_index_unrealized` > 0, until the index exists.
- **Rollback:** chart 11.4.x drops the variables, and the runner builds without bounds again.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.5.0 -f values-11.5.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

The diff shows `PARTITION_INDEX_BUILD_MAX_BYTES` and `PARTITION_INDEX_BUILD_WINDOW_SECONDS` on the partition CronJob and the reconcile Job.

## Command to upgrade

> **Important:** Pass your values with `-f`. Any `-f` or `--set` turns off the reuse of the release values, so a file that holds only a new block sends passwords, hosts and every other key back to the chart defaults.

1. Export the values of the current release. The file holds secrets: keep it out of Git and delete it after the upgrade.

   ```bash
   helm get values midaz -n midaz -o yaml > values-11.5.yaml
   ```

2. Edit `values-11.5.yaml` if you change a bound or follow [If you raised the hook deadline](#if-you-raised-the-hook-deadline).
3. Upgrade with the edited file:

   ```bash
   helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.5.0 -f values-11.5.yaml
   ```

> **Warning:** Do not add `--reuse-values`. It keeps the values of the previous release instead of the 11.5.0 defaults.
<!-- {% endraw %} -->
