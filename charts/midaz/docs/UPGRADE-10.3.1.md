# Helm Upgrade from v10.3.0 to v10.3.1

## Topics

- **[New features](#new-features)**
  - [1. Partition runner for transaction table management](#1-partition-runner-for-transaction-table-management)
  - [2. Reconcile indexes Job runs after migrations](#2-reconcile-indexes-job-runs-after-migrations)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## New features

### 1. Partition runner for transaction table management

v10.3.1 introduces a scheduled partition runner that creates transaction partitions ahead of time and reconciles indexes. The runner is automatically enabled for stable releases >= 4.5.0 and can be controlled via `ledger.partition.enabled`.

#### What changed

The chart adds a new CronJob (`midaz-ledger-partition`) that runs daily at 06:00 (configurable) to:

- Create future transaction partitions before they are needed
- Reconcile indexes on partitioned tables
- Report health via exit codes (0 = healthy, 1 = attention needed, 2 = invalid state)

In multi-tenant mode, the runner visits every active tenant.

| Setting | v10.3.0 | v10.3.1 |
|---------|---------|---------|
| `ledger.partition.enabled` | (not present) | `nil` (auto-enabled for stable >= 4.5.0) |
| `ledger.partition.schedule` | (not present) | `"0 6 * * *"` |
| `ledger.partition.timeZone` | (not present) | `""` (uses cluster default) |
| `ledger.partition.activeDeadlineSeconds` | (not present) | `1800` |
| `ledger.partition.resources.limits.cpu` | (not present) | `200m` |
| `ledger.partition.resources.limits.memory` | (not present) | `128Mi` |
| `ledger.partition.resources.requests.cpu` | (not present) | `50m` |
| `ledger.partition.resources.requests.memory` | (not present) | `64Mi` |

#### New configuration options

| Flag | Default | Description |
|------|---------|-------------|
| `ledger.partition.enabled` | `nil` | Auto-enables for stable tags >= 4.5.0; set `true` or `false` to override |
| `ledger.partition.schedule` | `"0 6 * * *"` | Cron schedule in `timeZone` (06:00 daily by default) |
| `ledger.partition.timeZone` | `""` | IANA time zone for schedule (e.g. `"America/Sao_Paulo"`); empty uses cluster default (usually UTC) |
| `ledger.partition.activeDeadlineSeconds` | `1800` | Hard timeout for one run (30 minutes) |

#### Environment variables

The partition runner uses the same database connection settings as the ledger service. The following environment variables are passed inline to override stale ConfigMaps during pre-upgrade hooks:

| Variable | Source | Description |
|----------|--------|-------------|
| `DB_TRANSACTION_HOST` | `ledger.datastores` or `ledger.configmap.DB_TRANSACTION_HOST` | PostgreSQL host for transaction database |
| `DB_TRANSACTION_PORT` | `ledger.datastores` or `ledger.configmap.DB_TRANSACTION_PORT` | PostgreSQL port (default: `5432`) |
| `DB_TRANSACTION_NAME` | `ledger.datastores` or `ledger.configmap.DB_TRANSACTION_NAME` | Database name (default: `transaction`) |
| `DB_TRANSACTION_USER` | `ledger.datastores` or `ledger.configmap.DB_TRANSACTION_USER` | Database user (default: `midaz`) |
| `DB_TRANSACTION_SSLMODE` | `ledger.datastores` or `ledger.configmap.DB_TRANSACTION_SSLMODE` | SSL mode (default: `disable`) |
| `MULTI_TENANT_ENABLED` | `ledger.configmap.MULTI_TENANT_ENABLED` | Whether multi-tenant mode is enabled |

In single-tenant mode, the runner uses the same PostgreSQL password as migrations (`DB_TRANSACTION_PASSWORD`).

#### Operational impact

- The CronJob is created automatically on upgrade when `ledger.enabled: true` and the image tag is a stable version >= 4.5.0 (a SemVer tag without a pre-release suffix).
- Pre-release tags (e.g. `4.5.0-beta.94`) default to disabled; set `ledger.partition.enabled: true` to enable explicitly.
- The chart's default ledger image tag, `4.5.0-beta.94`, is a pre-release, so with default values neither the CronJob nor the reconcile Job is created. If your transaction database uses the partitioned layout, set `ledger.partition.enabled: true` (Scenario 4): without the runner, new rows eventually land in the DEFAULT partition.
- The default schedule (`0 6 * * *`) runs at 06:00 in the configured time zone, chosen to avoid common managed PostgreSQL maintenance windows.
- The CronJob name is truncated to 42 characters plus `-partition` to stay within Kubernetes' 52-character limit for CronJob names.
- The runner exits 0 when partitions are healthy, 1 when attention is needed, and 2 for invalid states.
- The CronJob keeps its last 3 failed Jobs (`failedJobsHistoryLimit: 3`).

#### Action required

##### Scenario 1: You use a stable release >= 4.5.0

No action required. The partition runner is enabled automatically and runs daily at 06:00.

##### Scenario 2: You want to customize the schedule

Set the schedule and optionally the time zone in your values file:

```yaml
ledger:
  partition:
    schedule: "0 3 * * *"  # Run at 03:00 instead of 06:00
    timeZone: "America/Sao_Paulo"  # Pin to a specific time zone
```

> **Important:** Choose a schedule that avoids your database's maintenance windows.

##### Scenario 3: You want to disable the partition runner

Set `enabled: false` explicitly:

```yaml
ledger:
  partition:
    enabled: false
```

##### Scenario 4: You use a pre-release tag and want to enable the runner

Set `enabled: true` explicitly:

```yaml
ledger:
  image:
    tag: "4.5.0-beta.94"
  partition:
    enabled: true
```

##### Scenario 5: You need to adjust resource limits

Override the default resource requests and limits:

```yaml
ledger:
  partition:
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

#### Verification after upgrade

Check that the CronJob was created:

```bash
kubectl get cronjob -n midaz -l app.kubernetes.io/component=ledger-partition
```

View the CronJob schedule and last run:

```bash
kubectl get cronjob -n midaz -o wide
```

Check the most recent Job execution:

```bash
kubectl get jobs -n midaz -l app.kubernetes.io/component=ledger-partition --sort-by=.metadata.creationTimestamp
```

View logs from the most recent run:

```bash
kubectl logs -n midaz -l app.kubernetes.io/component=ledger-partition --tail=100
```

### 2. Reconcile indexes Job runs after migrations

v10.3.1 adds a `reconcile-indexes` Job that runs as a Helm hook after the migration Job completes. This ensures indexes are created on partitioned tables immediately after schema changes.

#### What changed

A new Job (`midaz-ledger-partition-reconcile-<tag>`) runs as a `post-install` and `pre-upgrade` hook (Argo CD sync wave 1) after the migration Job (wave 0). The Job:

- Reconciles indexes on all partitioned tables
- Tolerates unavailable databases (exits 0 to avoid blocking upgrades)
- Is deleted automatically on success
- Is kept for 3 days on failure for inspection

| Setting | v10.3.0 | v10.3.1 |
|---------|---------|---------|
| `ledger.partition.reconcile.enabled` | (not present) | `true` |
| `ledger.partition.reconcile.syncWave` | (not present) | `"1"` |
| `ledger.partition.reconcile.activeDeadlineSeconds` | (not present) | `1800` |
| `ledger.partition.reconcile.ttlSecondsAfterFinished` | (not present) | `259200` (3 days) |

#### New configuration options

| Flag | Default | Description |
|------|---------|-------------|
| `ledger.partition.reconcile.enabled` | `true` | Run reconcile-indexes after migration as a Sync/upgrade hook |
| `ledger.partition.reconcile.syncWave` | `"1"` | Argo CD sync wave (after migration Job's wave 0) |
| `ledger.partition.reconcile.activeDeadlineSeconds` | `1800` | Hard timeout for the Job (30 minutes; concurrent index builds can take time) |
| `ledger.partition.reconcile.ttlSecondsAfterFinished` | `259200` | How long a failed Job is kept (3 days; successful Jobs are deleted immediately) |

#### Operational impact

- The reconcile Job runs automatically on every `helm upgrade` when `ledger.enabled: true` and the partition runner is enabled.
- The Job name includes the image tag to ensure immutability (e.g. `midaz-ledger-partition-reconcile-4.5.0-beta.94`).
- The Job exits 0 when a database is unavailable or an index is still pending (`--tolerate-unavailable`), so those cases do not block upgrades. It still fails, and blocks the upgrade, on an invalid registry entry, a failed index build, a name conflict or a startup error.
- On success, the Job is deleted immediately by the `hook-succeeded` policy.
- On failure, the Job is kept for 3 days (`ttlSecondsAfterFinished: 259200`) for inspection.
- The daily CronJob retries index reconciliation, so temporary failures are recovered automatically.

#### Action required

##### Scenario 1: You keep `ledger.partition.reconcile.enabled: true` (default)

No action required. When the partition runner is enabled, the reconcile Job runs automatically after migrations.

##### Scenario 2: You want to disable the reconcile Job

Set `enabled: false`:

```yaml
ledger:
  partition:
    reconcile:
      enabled: false
```

> **Warning:** With the reconcile Job disabled, only the daily CronJob builds pending registered indexes.

##### Scenario 3: You need a longer timeout for large partitions

Increase the timeout:

```yaml
ledger:
  partition:
    reconcile:
      activeDeadlineSeconds: 3600  # 1 hour
```

> **Note:** Concurrent index builds on large partitions can take significant time.

##### Scenario 4: You want to adjust the Argo CD sync wave

Change the sync wave (must be after the migration Job's wave 0):

```yaml
ledger:
  partition:
    reconcile:
      syncWave: "2"
```

#### Verification after upgrade

Check that the reconcile Job ran:

```bash
kubectl get jobs -n midaz -l app.kubernetes.io/component=ledger-partition-reconcile --sort-by=.metadata.creationTimestamp
```

View logs from the reconcile Job:

```bash
kubectl logs -n midaz -l app.kubernetes.io/component=ledger-partition-reconcile --tail=100
```

If the Job succeeded, it is deleted automatically. Check for failed Jobs:

```bash
kubectl get jobs -n midaz -l app.kubernetes.io/component=ledger-partition-reconcile
```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.1 -n midaz
```
