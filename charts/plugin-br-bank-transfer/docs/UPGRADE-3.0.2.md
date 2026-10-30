# Helm Upgrade from v3.0.1 to v3.0.2

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.0.2 updates the application version from 3.2.0 to 3.3.0. The chart itself changes in two places only: `appVersion` in `Chart.yaml` and the default `bankTransfer.image.tag` in `values.yaml`. No template, schema or other value changed, and no value key was added, removed or renamed. The application upgrade does include database migrations (see below), and the upgrade rolls the application pods.

## Application Version Update

**What changed:**  
The chart now deploys application version 3.3.0 (previously 3.2.0). The default container image tag has been updated accordingly.

| Setting | v3.0.1 | v3.0.2 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `3.2.0` | `3.3.0` |
| `bankTransfer.image.tag` | `3.2.0` | `3.3.0` |
| `bankTransfer.migrations.image.tag` (empty by default, follows the app tag) | `3.2.0` | `3.3.0` |

**Why it matters:**  
App v3.3.0 changes how the application talks to Midaz and settles TED transfers. The v3.3.0 changelog lists, among others:

- Midaz reads now run behind their own circuit breaker, separate from the write breaker, and readiness is gated on the read breaker.
- The fee is refunded on a TED out devolution.
- Settlement handling for `sitlancstr` 2, 3 and 4 was changed, and an aged pending settlement is parked only while awaiting.
- Dependency bumps for `go-jose` and `x/net`.

See the application's v3.3.0 release notes for the full list.

**Database migrations:**  
App v3.3.0 adds four migrations on top of v3.2.0 (000066 to 000069):

- `000066`: widens the CHECK constraint on `jd_incoming_messages.retention_scope_transfer_type` (created `NOT VALID`).
- `000067`: adds the nullable columns `return_reason_code` and `reversal_transaction_id` to `transfers` and updates column comments. The application reads these columns in every transfer query, so a database without this migration cannot serve transfer reads.
- `000068` and `000069`: build two partial unique indexes on `transfers` with `CREATE INDEX CONCURRENTLY`. On a large `transfers` table the build can take a while. If one of them aborts, it leaves an INVALID index and a dirty migration version that needs manual cleanup (the application's `migrations/README.md` describes the steps).

The migrations image tag defaults to the application tag, so it moves to 3.3.0 unless you set `bankTransfer.migrations.image.tag`. With the bundled PostgreSQL the migrations run as an initContainer of each application pod. With an external PostgreSQL they run as a Helm `pre-install,pre-upgrade` hook Job (ArgoCD PreSync) before the new pods start. Allow time for the hook Job on a large database; its `activeDeadlineSeconds` defaults to 600.

**Operational impact:**  
- The Deployment performs a rolling update. The new image tag changes the pod template, and the `helm.sh/chart` and `app.kubernetes.io/version` pod labels change as well. A chart version bump alone would also roll the pods, because of the `helm.sh/chart` label.
- No values changes are required.
- Migrations 000067 to 000069 are not reverted by a chart rollback. A rollback to chart 3.0.1 (app 3.2.0) keeps the new columns and indexes. Do not run the down migrations of 000067 or 000068 without reading the application's `migrations/README.md`, because they drop data.

**Migration required:**  
No values migration. The database migrations above run automatically as part of `helm upgrade`.

> **Note:** If you have explicitly overridden `bankTransfer.image.tag` in your values, update it to `3.3.0` or remove the override to use the chart default. If you pin `bankTransfer.migrations.image.tag` separately, move it to `3.3.0` as well, otherwise the new schema is not applied.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.2 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.2 -n plugin-br-bank-transfer
```
