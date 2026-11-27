<!-- {% raw %} -->
# Helm Upgrade from v11.1.2 to v11.2.0

## Topics

- **[Before you upgrade](#before-you-upgrade)**
- **[Features](#features)**
  - [1. Application version upgraded to 4.5.0](#1-application-version-upgraded-to-450)
  - [2. Health preset turned on by the 4.5.0 image](#2-health-preset-turned-on-by-the-450-image)
  - [3. Ledger partition runner and index reconcile hook](#3-ledger-partition-runner-and-index-reconcile-hook)
  - [4. New ConfigMap keys: STREAMING_TENANT_KAFKA and TRANSACTION_CREATED_BY_ENABLED](#4-new-configmap-keys-streaming_tenant_kafka-and-transaction_created_by_enabled)
  - [5. OTEL_TRUST_INBOUND_TRACE_CONTEXT now takes effect](#5-otel_trust_inbound_trace_context-now-takes-effect)
- **[Operational impact](#operational-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Before you upgrade

Check these points first. Each one can stop the upgrade.

1. **Export the release values to a file.** The steps below change your values, and the upgrade command takes the file with `-f`. See [Command to upgrade](#command-to-upgrade).
2. **Remove the values the health preset owns.** With the 4.5.0 image, the chart refuses to render if any of these keys is set on `ledger` or `tracer`: `pdb.minAvailable`, `pdb.maxUnavailable`, `deploymentUpdate`, `livenessProbe`, `readinessProbe`, `startupProbe`, `terminationGracePeriodSeconds`. Chart 11.1.2 accepted them. See [section 2](#2-health-preset-turned-on-by-the-450-image).
3. **Plan for the index reconcile hook.** A new `pre-upgrade` hook builds indexes on the ledger `transaction` table before the new pods start. On a large table, it can take longer than the Helm default `--timeout` of 5 minutes. See [section 3](#3-ledger-partition-runner-and-index-reconcile-hook).
4. **Back up the databases.** The 4.5.0 migration Jobs apply 33 new ledger transaction-database migrations (`000050` to `000082`) and 22 new tracer migrations (`000034` to `000055`). A rollback to chart 11.1.2 puts the 4.4.3 images back on the migrated schema; that combination was not tested.

## Features

### 1. Application version upgraded to 4.5.0

The chart now deploys Midaz `4.5.0` (previously `4.4.3`).

| Component | Setting | v11.1.2 | v11.2.0 |
|-----------|---------|---------|---------|
| Ledger service | `ledger.image.tag` | `4.4.3` | `4.5.0` |
| Tracer service | `tracer.image.tag` | `4.4.3` | `4.5.0` |
| Ledger migrations | `midaz-ledger-migrations.image.tag` | `4.4.3` | `4.5.0` |
| Tracer migrations | `midaz-tracer-migrations.image.tag` | `4.4.3` | `4.5.0` |
| App version | `appVersion` | `4.4.3` | `4.5.0` |

If you pin `ledger.image.tag` or `tracer.image.tag`, the pin wins. A tag below `4.5.0-beta.94` keeps the 4.4 probes and ports, and a ledger tag below `4.5.0-beta.1` renders no partition runner.

- The ledger migrations Job runs as a `pre-upgrade` hook on every upgrade.
- With `tracer.enabled: true`, the tracer migrations Job also runs as a `pre-upgrade` hook.
- Read the Midaz 4.5.0 release notes for the application changes.

### 2. Health preset turned on by the 4.5.0 image

From image `4.5.0-beta.94`, the chart hands probes, ports, rollout strategy, grace period and PDB to the shared health preset (`lerian-common.health`, stack `go`). The `4.5.0` default image turns it on for the ledger and the tracer.

What the preset renders, compared with chart 11.1.2 on the 4.4.3 image:

| Item | Ledger 11.1.2 | Ledger 11.2.0 | Tracer 11.1.2 | Tracer 11.2.0 |
|------|---------------|---------------|---------------|---------------|
| Probe port | `http` (3002) | `health` (8099) | 4020 | `health` (8099) |
| `startupProbe` | none | `/health`, period 5s, 60 failures | none | same as ledger |
| Readiness probe | `/readyz`, period 10s, timeout 16s | `/readyz`, period 5s, timeout 3s | `/readyz`, period 10s, timeout 5s | `/readyz`, period 5s, timeout 3s |
| `maxSurge` / `maxUnavailable` | `100%` / `0` | `25%` / `0` | `1` / `0` | `25%` / `0` |
| `terminationGracePeriodSeconds` | 72 | 55 | 55 | 55 |
| PDB | `maxUnavailable: 1` | `maxUnavailable: 1`, `unhealthyPodEvictionPolicy: AlwaysAllow` | `maxUnavailable: 1` | same as ledger |

Other changes from the preset:

- The ledger and tracer Services get a `health` port (8099). The container gets the `HEALTH_PORT=8099`, `SHUTDOWN_DRAIN_DELAY=15s` and `SHUTDOWN_TIMEOUT=30s` env entries.
- The ledger ConfigMap no longer renders `RABBITMQ_PROTOCOL`, `RABBITMQ_PORT_AMQP` and `RABBITMQ_HEALTH_CHECK_URL`. The tracer ConfigMap no longer renders `READYZ_DRAIN_GRACE_SECONDS`.
- The only value left under `ledger.health` and `tracer.health` is `stack`.

If a NetworkPolicy, service mesh or monitoring tool in your cluster names the probe port, allow port 8099.

#### Values the preset refuses

The chart fails the render on these keys. Remove them from `values-11.2.yaml`, the file you export in [Command to upgrade](#command-to-upgrade):

| Key (on `ledger` or `tracer`) | Error |
|-------------------------------|-------|
| `pdb.minAvailable`, `pdb.maxUnavailable` | `midaz: ledger.pdb.minAvailable is owned by the health preset (PDB maxUnavailable 1); remove it` |
| `deploymentUpdate` | `midaz: ledger.deploymentUpdate is owned by the health preset (RollingUpdate); remove it` |
| `livenessProbe`, `readinessProbe`, `startupProbe`, `terminationGracePeriodSeconds` | `lerian-common.health: ledger: livenessProbe is owned by the health preset; remove it` |

`pdb.enabled` and `pdb.annotations` stay valid. `helm get values` shows only user-supplied values, so a key that is absent from the exported file comes from the chart defaults and does not block the upgrade.

### 3. Ledger partition runner and index reconcile hook

From ledger image `4.5.0-beta.1`, the chart renders the partition runner (`/partition` in the ledger image). With the 4.5.0 default, chart 11.2.0 adds these objects:

| Object | Kind | What it does |
|--------|------|--------------|
| `midaz-ledger-partition` | CronJob | `ensure --reconcile-indexes` at `0 6 * * *` (`ledger.partition.schedule`), `concurrencyPolicy: Forbid`, `activeDeadlineSeconds: 1800` |
| `midaz-ledger-partition-reconcile-4.5.0` | Job, hook `post-install,pre-upgrade`, weight `10` | `reconcile-indexes --tolerate-unavailable`, `activeDeadlineSeconds: 1800`, `backoffLimit: 2` |
| `midaz-ledger-license-hook` | Secret, hook `pre-install,pre-upgrade`, weight `5` | Rendered only when `ledger.secrets.LICENSE_KEY` is set and `ledger.useExistingSecret` is false. It carries the license to the reconcile Job, which runs before the release Secret is written. |

#### Hook order on `helm upgrade`

1. Weight `-1`: RabbitMQ definitions ConfigMap.
2. Weight `0`: RabbitMQ bootstrap Job, ledger migrations Job, and the tracer migrations Job when the tracer is on.
3. Weight `5`: license hook Secret, only with `LICENSE_KEY`.
4. Weight `10`: partition reconcile Job.
5. Helm then applies the Deployments and the pods roll.

On Argo CD, the reconcile Job is a `Sync` hook in wave `1` (`ledger.partition.reconcile.syncWave`), after the migrations in wave 0.

#### Large ledgers

The 4.5.0 migrations register `idx_transaction_organization_ledger_id_live` on the `transaction` table (migration `000079`). The reconcile Job builds it with `CREATE INDEX CONCURRENTLY`, so the build time grows with the table size.

- `--tolerate-unavailable` makes a pending index or an unreachable database exit 0. The next pass builds a pending index.
- Helm waits for each hook Job up to `--timeout`, 5 minutes by default. If the Job still runs at that point, `helm upgrade` fails. The migrations are already applied and the pods are still on 4.4.3.
- Kubernetes stops the Job after `activeDeadlineSeconds` (1800 s). An interrupted build leaves an invalid index, which the next pass rebuilds with `REINDEX INDEX CONCURRENTLY`.

The build time on a large table was not measured. If your `transaction` table is large, set `--timeout` above the Job deadline, for example `--timeout 35m`. Raise the deadline if needed, and raise `--timeout` with it. Add the block to `values-11.2.yaml`:

```yaml
ledger:
  partition:
    reconcile:
      activeDeadlineSeconds: 7200
```

Do not skip the hook to leave the build to the daily CronJob: the CronJob has its own 1800 s deadline, so on a large table it starts the same build every day and is stopped again. Chart 11.5.0, with ledger image 4.7.0 or later, bounds the builds of the hook and the CronJob and adds an on-demand build for a large table; see the [11.5 guide](UPGRADE-11.5.md#which-run-builds-your-index).

`ledger.partition.timeZone` pins the CronJob schedule to a zone. Empty uses the zone of the kube-controller-manager, UTC on most managed clusters. `ledger.partition.enabled: false` removes both the CronJob and the hook.

### 4. New ConfigMap keys: STREAMING_TENANT_KAFKA and TRANSACTION_CREATED_BY_ENABLED

The templates render three new keys, always with the value `"false"`:

| ConfigMap | Key | Rendered value |
|-----------|-----|----------------|
| `midaz-ledger` | `STREAMING_TENANT_KAFKA` | `"false"` |
| `midaz-ledger` | `TRANSACTION_CREATED_BY_ENABLED` | `"false"` |
| `midaz-tracer` | `STREAMING_TENANT_KAFKA` | `"false"` |

> **Important:** Chart 11.2.0 does not let you change these keys. The templates read `ledger.configmap.STREAMING_TENANT_KAFKA`, `ledger.configmap.TRANSACTION_CREATED_BY_ENABLED` and `tracer.configmap.STREAMING_TENANT_KAFKA`, but `values.schema.json` does not allow them. `helm template` then fails with `invalid propertyName 'STREAMING_TENANT_KAFKA'`. Keep the default until a chart release adds the keys to the schema.

What the flags do in Midaz 4.5.0, for reference:

- `STREAMING_TENANT_KAFKA` has effect only with `MULTI_TENANT_ENABLED=true`. Each tenant then publishes to its own topic, with the brokers and credentials that the Tenant Manager serves, and the service does not read `STREAMING_BROKERS`.
- `TRANSACTION_CREATED_BY_ENABLED` records the authenticated caller on each transaction. It has effect only with `PLUGIN_AUTH_ENABLED=true`. Pods older than 4.5.0 refuse a completion plan that carries `createdBy`, so do not turn it on while 4.4.x pods still run.

### 5. OTEL_TRUST_INBOUND_TRACE_CONTEXT now takes effect

`ledger.configmap.OTEL_TRUST_INBOUND_TRACE_CONTEXT` and `tracer.configmap.OTEL_TRUST_INBOUND_TRACE_CONTEXT` exist since chart 11.1.0, with default `"false"`. The [11.1 guide](UPGRADE-11.1.md) says that the 4.4.x images do not read the variable. The 4.5.0 ledger and tracer read it.

With `"true"`, the service trusts the inbound trace context: the caller chooses the trace id and, through the sampled flag, whether the service records the trace. Turn it on only behind a gateway that sets or strips those headers.

## Operational impact

- **Pod restarts:** the ledger and tracer pods roll once, for the new image, the chart label, the new ConfigMap keys and the health preset.
- **Upgrade order:** the migrations and the reconcile Job run before the new pods. A failed or timed-out hook stops the upgrade after the migrations.
- **Rollout:** `maxSurge` is now `25%` with `maxUnavailable: 0`. The ledger previously surged `100%`, so its rollout takes more steps.
- **Schedule:** the new `midaz-ledger-partition` CronJob runs every day at 06:00 against the transaction database.
- **Rollback:** Helm rollback does not revert the database migrations. Restore from backup if you must return to 4.4.3.

## Preview changes before upgrading

Run the preview with the same values file as the upgrade (see [Command to upgrade](#command-to-upgrade)):

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.0 -f values-11.2.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

A render error with `is owned by the health preset` means a key from [section 2](#values-the-preset-refuses) is still in your values.

## Command to upgrade

> **Important:** Pass your values with `-f`. Any `-f` or `--set` turns off the reuse of the release values, so a file that holds only a new block sends passwords, hosts and every other key back to the chart defaults. Without `-f` or `--set`, Helm reuses the previous values unchanged, and the edits from sections 2 and 3 do not reach the release.

1. Export the values of the current release. The file holds secrets: keep it out of Git and delete it after the upgrade.

   ```bash
   helm get values midaz -n midaz -o yaml > values-11.2.yaml
   ```

2. Edit `values-11.2.yaml`: remove the keys from [section 2](#values-the-preset-refuses) and add the `ledger.partition` block from [section 3](#large-ledgers) if you need one.
3. Upgrade with the edited file:

   ```bash
   helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.0 -f values-11.2.yaml --timeout 35m
   ```

`--timeout 35m` lets Helm wait for the reconcile hook up to its 1800 s deadline. Adjust it if you change `ledger.partition.reconcile.activeDeadlineSeconds`.

> **Warning:** Do not add `--reuse-values`. It renders with the 11.1.2 chart defaults, so `ledger.image.tag` and the other defaults stay on `4.4.3`.
<!-- {% endraw %} -->
