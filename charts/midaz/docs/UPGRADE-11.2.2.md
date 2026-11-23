# Helm Upgrade from v11.2.1 to v11.2.2

## Topics

- **[Fixes](#fixes)**
  - [1. Ledger partition CronJob Argo CD sync wave ordering](#1-ledger-partition-cronjob-argo-cd-sync-wave-ordering)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Ledger partition CronJob Argo CD sync wave ordering

The ledger partition CronJob now applies in the last Argo CD sync wave of the chart. A `Degraded` CronJob no longer stops the ledger and tracer Deployments and the partition reconcile hook from applying.

#### What changed

**Before (v11.2.1):**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: midaz-ledger-partition
  labels:
    app.kubernetes.io/component: midaz-ledger-partition
spec:
  schedule: "0 6 * * *"
```

**After (v11.2.2):**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: midaz-ledger-partition
  labels:
    app.kubernetes.io/component: midaz-ledger-partition
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  schedule: "0 6 * * *"
```

The CronJob now renders with an `argocd.argoproj.io/sync-wave` annotation set to one wave higher than the maximum of:

- `ledger.migrations.deploymentSyncWave` (default `"1"`)
- `tracer.migrations.deploymentSyncWave` (default `"1"`)
- `ledger.partition.reconcile.syncWave` (default `"1"`)

This ensures the CronJob applies **after** all migration Jobs and Deployments have completed their sync waves.

#### Why this matters

Argo CD gates a sync on a resource's health only while a later wave, or a hook in the same wave, is still pending. Up to 11.2.1 the partition CronJob had no sync-wave annotation, so Argo CD applied it in wave `"0"`, together with the migration Jobs (`Sync` hooks). After one failed scheduled run, Argo CD reads the CronJob as `Degraded` and fails the sync at wave `"0"`. The migration Jobs ran, but nothing from wave `"1"` applied: when the migration Jobs render, that wave holds the ledger and tracer Deployments and the `midaz-ledger-partition-reconcile` hook. A release that fixes the failing run could not roll out.

By placing the CronJob in a wave **after** all critical resources, Argo CD will not wait for the CronJob's health before proceeding with the ledger and tracer components.

> **Note:** Argo CD still reports the Application as `Degraded` until a scheduled run of the CronJob succeeds. The sync of the hooks and Deployments completes, so this status alone does not mean that the upgrade failed. The job-failure alert (`kube_job_status_failed`) does not change.

#### Impact on existing deployments

| Setting | v11.2.1 | v11.2.2 |
|---------|---------|---------|
| `argocd.argoproj.io/sync-wave` annotation on partition CronJob | Not present | Dynamically calculated (default `"2"`) |

> **Note:** Plain `helm install` / `helm upgrade` ignores the `argocd.argoproj.io/sync-wave` annotation, so the new order applies only to Argo CD. The pod restarts and hooks below apply to both Helm and Argo CD.

#### Operational impact

- **Pod restarts:** `midaz-crm` and `midaz-tracer` roll once with the same images. Their ConfigMap and Secret carry the `helm.sh/chart` label, so the `checksum/config` and `checksum/secret` annotations change while the content stays the same. `midaz-ledger` and the CronJob pod template do not change. The bundled Valkey, PostgreSQL, MongoDB and RabbitMQ pods do not roll.
- **Hooks on `helm upgrade`:** Helm runs these hooks before it applies the Deployments. A failed or timed-out hook stops the upgrade before the new pods start.
  1. Weight `-1`: RabbitMQ definitions ConfigMap.
  2. Weight `0`: RabbitMQ bootstrap Job, `midaz-ledger-migrations-4.5.1`, and `midaz-tracer-migrations-4.5.1-<hash>` when the tracer is on.
  3. Weight `5`: license hook Secret, only with `ledger.secrets.LICENSE_KEY`.
  4. Weight `10`: `midaz-ledger-partition-reconcile-4.5.1`, which runs `reconcile-indexes --tolerate-unavailable` with `activeDeadlineSeconds: 1800`.
- **Migrations:** the images stay on `4.5.1`, so both migration Jobs apply nothing new.
- **Reconcile Job:** Helm runs the hook on every upgrade, so it runs again with the same `4.5.1` name. The `before-hook-creation` policy removes a failed copy left by an earlier run. When an earlier upgrade built `idx_transaction_organization_ledger_id_live`, it finds the index and exits. When an earlier upgrade skipped the hook (`ledger.partition.reconcile.enabled: false`) or left the index pending or invalid, this run builds it. The build time grows with the `transaction` table, so keep `--timeout 35m` as in [Command to upgrade](#command-to-upgrade). See [section 3 of the 11.2 guide](UPGRADE-11.2.md#3-ledger-partition-runner-and-index-reconcile-hook).

#### Migration steps

No action is required from operators. The sync wave is calculated automatically based on existing values.

If you have customized the sync waves for migrations or the partition reconcile Job, the CronJob will automatically apply one wave later:

```yaml
ledger:
  migrations:
    deploymentSyncWave: "3"
  partition:
    reconcile:
      syncWave: "2"
```

In this example, the partition CronJob would render with `argocd.argoproj.io/sync-wave: "4"` (one higher than the maximum of `3`, `1`, and `2`).

The chart has no value for the CronJob annotations. Only the three wave values above change the CronJob wave.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.2 --timeout 35m
```

With no `-f` and no `--set`, Helm reuses the values of the current release with the 11.2.2 chart defaults. `--timeout 35m` lets Helm wait for the reconcile hook up to its 1800 s deadline. Adjust it if you change `ledger.partition.reconcile.activeDeadlineSeconds`.
