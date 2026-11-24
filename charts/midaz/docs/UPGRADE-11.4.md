# Helm Upgrade from v11.3.0 to v11.4.0

## Topics

- **[Application version bump to 4.6.0](#application-version-bump-to-460)**
- **[New configuration flag](#new-configuration-flag)**
  - [1. TRANSACTION_FEE_ITEMS_ENABLED](#1-transaction_fee_items_enabled)
- **[Configuration reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application version bump to 4.6.0

This release updates the Midaz application images from `4.5.1` to `4.6.0` for the `ledger`, `tracer`, and their migration runners. The chart version increments from `11.3.0` to `11.4.0`.

### What changed

| Setting | v11.3.0 | v11.4.0 |
|---------|---------|---------|
| `appVersion` | `4.5.1` | `4.6.0` |
| `ledger.image.tag` | `4.5.1` | `4.6.0` |
| `tracer.image.tag` | `4.5.1` | `4.6.0` |
| `midaz-ledger-migrations.image.tag` | `4.5.1` | `4.6.0` |
| `midaz-tracer-migrations.image.tag` | `4.5.1` | `4.6.0` |

The `crm` service image tag is not changed in this release.

The migration Jobs take their tag from `ledger.migrations.image.tag` (or `tracer.migrations.image.tag`), then `ledger.image.tag` (or `tracer.image.tag`), then `appVersion`. The templates do not read the top-level `midaz-ledger-migrations` and `midaz-tracer-migrations` keys.

> **Important:** If your values pin `ledger.image.tag` or `tracer.image.tag`, the pin wins over the new default, and the migration Jobs follow it. Set the pin to `4.6.0` or remove it.

### Operational impact

- **Pod restarts:** `midaz-ledger` and `midaz-tracer` roll once for the new image. `midaz-crm` also rolls with the same image: its ConfigMap and Secret carry the `helm.sh/chart` label, so the `checksum/config` and `checksum/secret` annotations change. The pod templates do not carry `helm.sh/chart`. The bundled Valkey, PostgreSQL, MongoDB and RabbitMQ pods do not roll.
- **Hooks on `helm upgrade`:** Helm runs these hooks before it applies the Deployments. A failed or timed-out hook stops the upgrade before the new pods start.
  1. Weight `-1`: RabbitMQ definitions ConfigMap.
  2. Weight `0`: RabbitMQ bootstrap Job, `midaz-ledger-migrations-4.6.0`, and `midaz-tracer-migrations-4.6.0-<hash>` when the tracer is on.
  3. Weight `5`: license hook Secret, only with `ledger.secrets.LICENSE_KEY`.
  4. Weight `10`: `midaz-ledger-partition-reconcile-4.6.0`, which runs `reconcile-indexes --tolerate-unavailable` with `activeDeadlineSeconds: 1800`.
- **Migrations:** Check the Midaz 4.6.0 release notes for any new migrations. The migration Jobs will apply them during the upgrade hook phase.
- **Reconcile Job:** the Job name carries the image tag, so it runs again on this upgrade. The build time grows with the `transaction` table, so keep `--timeout 35m` as in [Command to upgrade](#command-to-upgrade).
- **Schedule:** the `midaz-ledger-partition` CronJob uses the `4.6.0` image from its next run.
- **Rollback:** If 4.6.0 adds migrations, a Helm rollback to 11.3.0 may require a database restore. Verify the migration set before planning rollback procedures.

### Action required

No values change is required for the version bump itself. Check any image tag pin in your values and review the new configuration flag below.

### Verification after upgrade

Check that the new image tags are running:

```bash
kubectl get deployment -n midaz midaz-ledger -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get deployment -n midaz midaz-tracer -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Both commands should return images tagged with `4.6.0`.

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

## New configuration flag

### 1. TRANSACTION_FEE_ITEMS_ENABLED

Chart 11.4.0 adds `TRANSACTION_FEE_ITEMS_ENABLED` to the ledger ConfigMap, with a rendered default of `"false"`. This environment variable controls whether the ledger accepts and processes fee items in transaction requests.

#### What changed

**Before (v11.3.0):**

The ledger ConfigMap did not include `TRANSACTION_FEE_ITEMS_ENABLED`. The application behavior for fee items depended on the image's internal defaults.

**After (v11.4.0):**

```yaml
data:
  TRANSACTION_FEE_ITEMS_ENABLED: "false"
```

The ledger ConfigMap now explicitly sets this flag. The default `"false"` preserves the existing behavior: the ledger does not process fee items.

#### Configuration reference

| Flag | Default | Description |
|------|---------|-------------|
| `TRANSACTION_FEE_ITEMS_ENABLED` | `"false"` | When `"true"`, the ledger accepts and processes fee items in transaction requests. When `"false"`, fee items are ignored or rejected depending on the application version. |

#### Operational impact

- **Default behavior:** With the default `"false"`, the ledger continues to operate as it did in 11.3.0. No client-facing behavior changes.
- **Pod restart:** Adding this ConfigMap key changes the `midaz-ledger` pod template checksum, triggering a rollout when you upgrade to 11.4.0.
- **Enabling fee items:** Setting this flag to `"true"` enables fee-item processing in the 4.6.0 ledger. This may change transaction validation, storage, and response structure. Review the Midaz 4.6.0 application release notes and test fee-item requests in a non-production environment before enabling this in production.

#### Action required

No action is required to preserve existing behavior. The default `"false"` maintains compatibility with 11.3.0.

If you want to enable fee-item processing, add this override to your values:

```yaml
ledger:
  configmap:
    TRANSACTION_FEE_ITEMS_ENABLED: "true"
```

> **Warning:** Enabling `TRANSACTION_FEE_ITEMS_ENABLED` changes how the ledger processes transactions with fee items. Test thoroughly in a staging environment and verify that your clients send well-formed fee-item payloads before enabling this in production.

## Configuration reference

The following table lists all new configuration keys introduced in this release:

| Value path | Default | Description |
|------------|---------|-------------|
| `ledger.configmap.TRANSACTION_FEE_ITEMS_ENABLED` | `"false"` | Controls whether the ledger accepts and processes fee items in transaction requests. |

To override the default, include the key in your values file:

```yaml
ledger:
  configmap:
    TRANSACTION_FEE_ITEMS_ENABLED: "false"
```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.4.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.4.0 --timeout 35m
```

With no `-f` and no `--set`, Helm reuses the values of the current release with the 11.4.0 chart defaults. `--timeout 35m` lets Helm wait for the reconcile hook up to its 1800 s deadline. Adjust it if you change `ledger.partition.reconcile.activeDeadlineSeconds`.

> **Warning:** Do not add `--reuse-values`. It renders with the 11.3.0 chart defaults, so `ledger.image.tag` and `tracer.image.tag` stay on `4.5.1`.
