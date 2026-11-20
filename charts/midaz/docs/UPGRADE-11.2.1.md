# Helm Upgrade from v11.2.0 to v11.2.1

## Topics

- **[Application behavior changes in 4.5.1](#application-behavior-changes-in-451)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 4.5.1](#1-application-version-bump-to-451)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application behavior changes in 4.5.1

- **Action:** no values change. Check any `/v1` client that sends a `from` or `to` leg with a zero or negative `amount`: the ledger now accepts the transaction and drops the leg.

Midaz 4.5.1 ([LerianStudio/midaz#3339](https://github.com/LerianStudio/midaz/pull/3339)) returns `/v1` to the 3.8.2 behavior for a leg whose `amount` is present and not positive, with no `share` and no `remaining`:

| Call on `/v1` | 4.5.0 | 4.5.1 |
|---------------|-------|-------|
| Create with a zero or negative leg | `500` with code `0046` | `201`, the ledger drops the leg |
| Commit or cancel of a pending transaction created on 3.8.2 with that leg | `500` with code `0046`, the transaction stays `PENDING` | The commit or cancel completes |

- The dropped leg has no operation and is not listed in `source` or `destination`. On 3.8.2 the account stayed listed there.
- The create stores the body without the leg, and the idempotency hash covers the request without it. A commit or cancel does not rewrite the stored body of a 3.8.2 hold.
- The ledger logs one warn per transaction, `Dropped transaction legs with a non-positive amount`, with `dropped_legs_count`, `dropped_from_indexes` and `dropped_to_indexes`. The log carries no alias and no amount.
- `/v2` still refuses a zero leg with `422` and code `0125`. Revert does not change.

> **Note:** A plugin-fees 3.4.0 body for a fee that rounds to zero still carries `metadata.packageAppliedID`, and `/v1` refuses that key with `400` and code `0512` before it reads the legs. 4.5.1 does not change that refusal.

## Fixes

### 1. Application version bump to 4.5.1

This release updates the Midaz application images from `4.5.0` to `4.5.1` for the `ledger`, `tracer`, and their migration runners. The chart version increments from `11.2.0` to `11.2.1`. No values, templates or migrations change. The new ledger image changes the `/v1` behavior described in [Application behavior changes in 4.5.1](#application-behavior-changes-in-451).

#### What changed

| Setting | v11.2.0 | v11.2.1 |
|---------|---------|---------|
| `appVersion` | `4.5.0` | `4.5.1` |
| `ledger.image.tag` | `4.5.0` | `4.5.1` |
| `tracer.image.tag` | `4.5.0` | `4.5.1` |
| `midaz-ledger-migrations.image.tag` | `4.5.0` | `4.5.1` |
| `midaz-tracer-migrations.image.tag` | `4.5.0` | `4.5.1` |

The `crm` service image tag is not changed in this release.

The migration Jobs take their tag from `ledger.migrations.image.tag` (or `tracer.migrations.image.tag`), then `ledger.image.tag` (or `tracer.image.tag`), then `appVersion`. The templates do not read the top-level `midaz-ledger-migrations` and `midaz-tracer-migrations` keys.

> **Important:** If your values pin `ledger.image.tag` or `tracer.image.tag`, the pin wins over the new default, and the migration Jobs follow it. Set the pin to `4.5.1` or remove it.

#### Operational impact

- **Pod restarts:** `midaz-ledger` and `midaz-tracer` roll once for the new image. `midaz-crm` also rolls with the same `3.8.4` image: its ConfigMap and Secret carry the `helm.sh/chart` label, so the `checksum/config` and `checksum/secret` annotations change. The pod templates do not carry `helm.sh/chart`. The bundled Valkey, PostgreSQL, MongoDB and RabbitMQ pods do not roll.
- **Hooks on `helm upgrade`:** Helm runs these hooks before it applies the Deployments. A failed or timed-out hook stops the upgrade before the new pods start.
  1. Weight `-1`: RabbitMQ definitions ConfigMap.
  2. Weight `0`: RabbitMQ bootstrap Job, `midaz-ledger-migrations-4.5.1`, and `midaz-tracer-migrations-4.5.1-<hash>` when the tracer is on.
  3. Weight `5`: license hook Secret, only with `ledger.secrets.LICENSE_KEY`.
  4. Weight `10`: `midaz-ledger-partition-reconcile-4.5.1`, which runs `reconcile-indexes --tolerate-unavailable` with `activeDeadlineSeconds: 1800`.
- **Migrations:** 4.5.1 adds no migrations, so both migration Jobs apply nothing new.
- **Reconcile Job:** the Job name carries the image tag, so it runs again on this upgrade. When the 11.2.0 upgrade built `idx_transaction_organization_ledger_id_live`, it finds the index and exits. When the 11.2.0 upgrade skipped the hook (`ledger.partition.reconcile.enabled: false`) or left the index pending or invalid, this run builds it. The build time grows with the `transaction` table, so keep `--timeout 35m` as in [Command to upgrade](#command-to-upgrade). See [section 3 of the 11.2 guide](UPGRADE-11.2.md#3-ledger-partition-runner-and-index-reconcile-hook).
- **Schedule:** the `midaz-ledger-partition` CronJob uses the `4.5.1` image from its next run.
- **Rollback:** 4.5.1 adds no migrations, so a Helm rollback to 11.2.0 needs no database restore.

#### Action required

No values change is required. Check the `/v1` clients described in [Application behavior changes in 4.5.1](#application-behavior-changes-in-451) and any image tag pin.

#### Verification after upgrade

Check that the new image tags are running:

```bash
kubectl get deployment -n midaz midaz-ledger -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get deployment -n midaz midaz-tracer -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Both commands should return images tagged with `4.5.1`.

Check the CronJob image:

```bash
kubectl get cronjob -n midaz midaz-ledger-partition -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}'
```

Check that the release is `deployed`:

```bash
helm status midaz -n midaz
```

The migration and reconcile Jobs are hooks with `hook-delete-policy: before-hook-creation,hook-succeeded`, so Helm deletes them when they succeed. After a successful upgrade, this command returns `No resources found`:

```bash
kubectl get job -n midaz -l 'app.kubernetes.io/name in (midaz-ledger-migrations,midaz-tracer-migrations,midaz-ledger-partition-reconcile)'
```

A Job that this command lists failed or still runs. Read its logs before you retry the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.1 --timeout 35m
```

With no `-f` and no `--set`, Helm reuses the values of the current release with the 11.2.1 chart defaults. `--timeout 35m` lets Helm wait for the reconcile hook up to its 1800 s deadline. Adjust it if you change `ledger.partition.reconcile.activeDeadlineSeconds`.

> **Warning:** Do not add `--reuse-values`. It renders with the 11.2.0 chart defaults, so `ledger.image.tag` and `tracer.image.tag` stay on `4.5.0`.
