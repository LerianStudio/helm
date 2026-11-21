# Helm Upgrade from v11.2.1 to v11.2.2

## Topics

- **[Fixes](#fixes)**
  - [1. Ledger partition CronJob Argo CD sync wave ordering](#1-ledger-partition-cronjob-argo-cd-sync-wave-ordering)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Ledger partition CronJob Argo CD sync wave ordering

The ledger partition CronJob now applies in a later Argo CD sync wave to prevent a `Degraded` CronJob from blocking the deployment of migration Jobs and application Deployments.

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

Argo CD gates a sync on a resource's health only while a later wave, or a hook in the same wave, is still pending. If the partition CronJob is created in the default wave (wave `"0"`) or the same wave as the ledger Deployment, a `Degraded` CronJob (e.g., due to a misconfigured schedule or suspended state) can block the entire sync, preventing migration Jobs and Deployments from applying.

By placing the CronJob in a wave **after** all critical resources, Argo CD will not wait for the CronJob's health before proceeding with the ledger and tracer components.

#### Impact on existing deployments

| Setting | v11.2.1 | v11.2.2 |
|---------|---------|---------|
| `argocd.argoproj.io/sync-wave` annotation on partition CronJob | Not present | Dynamically calculated (default `"2"`) |

> **Note:** This change only affects Argo CD-managed deployments. Plain `helm install` / `helm upgrade` ignores the `argocd.argoproj.io/sync-wave` annotation, so non-Argo CD deployments are unaffected.

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

> **Important:** If you have explicitly set `ledger.partition.annotations` in your values to include a custom `argocd.argoproj.io/sync-wave`, it will be overridden by the chart's calculated value. Remove the custom annotation from your values to allow the chart to manage the sync wave automatically.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.2
```
