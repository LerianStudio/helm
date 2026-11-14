# Helm upgrade from v10.4.3 to v11.0.0

## Stop before upgrading bundled MongoDB

**This is a data migration, not an in-place pod restart. Do not run a plain Helm upgrade or GitOps sync against a populated bundled MongoDB installation.** The old PVC is not automatically attached to the replica set.

This guide compares chart `10.4.3` with chart `11.0.0`. Both default to Midaz application `4.4.2`; the chart version is not the application version. Preserve any explicitly selected application images and validate their own requirements separately.

## Verified chart changes

- Bundled MongoDB changes from a standalone **Deployment** to a single-member replica-set **StatefulSet**. The target sets `mongodb.architecture: replicaset`, `mongodb.replicaCount: 1`, `mongodb.arbiter.enabled: false` and `mongodb.updateStrategy.type: RollingUpdate`.
- With release name `midaz` and default naming, the old Deployment mounts PVC `midaz-mongodb`. The new StatefulSet's `datadir` volume-claim template creates **`datadir-midaz-mongodb-0`**, not a mount of the old claim. Inspect rendered names and actual PVC/PV bindings for your configuration.
- The bundled MongoDB host default changes to `midaz-mongodb-headless`. Explicit datastore host overrides and full connection URIs must be reviewed; they can bypass that default.
- `Recreate` is a Deployment strategy, not a valid StatefulSet strategy. The transition is between workload kinds, not an immutable-field edit of an existing MongoDB StatefulSet. A one-member replica set does not provide high availability or a zero-downtime guarantee.

## This guide supersedes the historical migration instructions

The [MongoDB section in the chart 11.0.0 README](https://github.com/LerianStudio/helm/blob/e218b8b999e95d7ac33a862e7f28ca9f8c806605/charts/midaz/README.md#mongodb-replica-set-chart-1100) is historical context, **not an executable runbook**. For this upgrade, use the requirements and ordering below instead of its Option A/Option B instructions, Helm commands, runtime assertions and cleanup commands.

In particular:

- Do not use its cutover or writer-resume `helm upgrade -f values.yaml` commands as written. Use `--reset-values` and explicit complete intended values at **every** preview and upgrade below; do not reuse stored legacy overrides.
- Its claims that fee quota usage is recorded in a MongoDB transaction and that a single-tenant ledger therefore refuses standalone MongoDB are not supported by the shipped Midaz `4.4.2` implementation. That implementation writes a quota marker and then updates its counter separately, with an explicitly documented non-atomic failure window. Do not turn these historical assertions into a new application startup or external-database requirement for this chart-only upgrade. This is not a blanket compatibility guarantee for any MongoDB topology, provider, configuration or differently pinned image.
- Do not automatically delete the old claim or change its PV back to `Delete` after a smoke test. Retain recovery data until the approved recovery-retention period and separate cleanup authorization have been satisfied.

## Prepare a complete, private migration plan

**Backup and a verified restore are mandatory for a populated installation.** Retaining a volume is not evidence that the new workload uses it. No generic dump/restore command can choose your authoritative databases, users, encryption material or recovery point for you.

Before the maintenance window:

1. Record the current release revision and chart version, complete intended Helm configuration, actual workload names, MongoDB database names and authentication database, PVC/PV bindings and reclaim policies. Save both user-supplied and computed release values and the rendered manifest privately. These exports are recovery evidence, not ready-made target values files: review removed overrides and changed defaults rather than blindly copying computed old defaults.
2. Preserve all unrelated intended settings: application and migration image pins, enabled components, external services, storage, networking, resources, autoscaling, authentication, license settings, Secret references and required encryption keys. Back up the referenced Secrets securely through your approved process; Helm values alone may not contain the live generated credentials. Do not decode Secrets into logs, place credentials in command arguments, or commit values, manifests or backups.
3. Keep existing database credentials stable. For an operator-managed `mongodb.auth.existingSecret`, prepare the required `mongodb-replica-set-key` alongside the existing password keys before creating the replica set. For declarative rendering without cluster lookup, provide stable secret material through the approved secret-management path; do not accept random credentials or replica-set keys changing between renders. Do not rotate existing root/application passwords incidentally during cutover.
4. Rehearse backup, restoration and recovery with the intended MongoDB destination and tools. Specify the included databases/collections, index and data validation, treatment of `admin`, `config` and other system data, authentication/user recreation, TLS and encryption prerequisites. Preserve application encryption keys needed to read restored CRM data. Destructive restore options such as `--drop` require a verified isolated destination and explicit approval, not copying a historical command.
5. Protect the old PV with a verified `Retain` reclaim policy before any action that could delete its claim. Check claim-retention annotations and GitOps pruning separately; a retained PV does not itself preserve a deleted PVC object or prove a tested rebind procedure. Record and rehearse how to recover the old data and workloads if cutover fails.
6. Inventory **all** writers, including ledger, enabled legacy CRM, workers, Jobs, external clients and controllers that can restart or scale workloads. Arrange maintenance isolation and pause relevant reconciliation/auto-sync. Account for pending messages, in-flight work and other datastores when defining a consistent recovery point. Do not assume scaling one Deployment to zero proves all writes stopped.

Prepare two full target configuration files, stored privately:

- `values-11.0-resume.yaml`: the complete intended running configuration for chart `11.0.0`. Remove or intentionally replace legacy MongoDB host overrides at every active datastore/configuration layer, including full URIs. For the replica-set path, select `replicaset` and `RollingUpdate`, not a retained `standalone`/`Recreate` override. Preserve intended credentials and all unrelated settings.
- `values-11.0-paused.yaml`: the same complete configuration, except set `ledger.autoscaling.enabled: false` and `ledger.replicaCount: 0`; also set `crm.autoscaling.enabled: false` and `crm.replicaCount: 0` when legacy CRM is enabled. Do not enable a previously disabled component. Keep all other identified writers stopped by the reviewed maintenance controls.

Also prepare a complete `values-10.4.3-paused.yaml` from the **current** intended configuration, changing only the writer-pause settings and any independently reviewed prerequisites. This keeps the old topology in place while pausing writers before the final backup. Record each enabled writer's intended resume replica count separately; when autoscaling will be enabled, record its intended `autoscaling.minReplicas`.

`--reset-values` starts from the selected chart's defaults. Missing intended configuration can be lost; a small migration fragment or `{}` is **not** a complete file. Do not substitute `--reuse-values` or `--reset-then-reuse-values`: deleted legacy overrides must not survive. Review private preview output for Secrets, unexpected resources, changed hosts, replica counts, storage names and Jobs before approving each upgrade.

## Helm CLI cutover ordering

The examples assume release `midaz` in namespace `midaz` and the reviewed GHCR publication. Adapt names only after checking your deployment. Run these on the authorized operator host, with restricted local files and shell tracing disabled. **They are templates for a rehearsed plan, not authorization to run a production migration.** Preview files can contain credentials; keep them private and do not paste them into tickets or CI logs.

### 1. Pause writers on the existing chart, then take the final backup

First preview and apply the complete paused predecessor configuration. Inspect the changes and any rendered Jobs before applying; do not run unreviewed hooks or migrations.

```sh
umask 077
helm upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm --version 10.4.3 --namespace midaz --reset-values -f values-10.4.3-paused.yaml --dry-run > preview-10.4.3-paused.txt
# STOP: privately review the preview before continuing.
helm upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm --version 10.4.3 --namespace midaz --reset-values -f values-10.4.3-paused.yaml
```

Verify the targeted application Deployments have desired replicas zero, their writer pods have terminated, their HPAs cannot restore replicas, and no other writer/controller remains active. If they do, stop here. Take the final consistent backup using the rehearsed procedure while the old MongoDB is still available. Verify the backup, its scope and the selected recovery point. Protect the old PVC/PV **before** replacing or pruning any old resources.

### 2. Create the target with writers still paused

```sh
helm upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm --version 11.0.0 --namespace midaz --reset-values -f values-11.0-paused.yaml --dry-run > preview-11.0-paused.txt
# STOP: privately review the preview before continuing.
helm upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm --version 11.0.0 --namespace midaz --reset-values -f values-11.0-paused.yaml
```

Do not use automatic Helm rollback as database recovery. If an upgrade fails, keep writers stopped and follow the rehearsed recovery decision; chart revision status is not evidence that data is authoritative or restored.

Verify that the old MongoDB Deployment no longer has running pods and that its retained claim is unmounted and protected. Inspect the new headless Service's endpoints: none may refer to the old standalone instance. With default naming, confirm the target StatefulSet is `midaz-mongodb` and the new claim is `datadir-midaz-mongodb-0`; inspect actual mounts and storage, not names alone. Confirm the new replica set has its intended primary and is ready. Application writers must still be at zero.

### 3. Restore and validate before resuming

Restore the final backup to the intended new destination using the rehearsed, authorized database procedure, with correct authentication and system-database handling. Do not restore into the retained old source by mistake. Validate database/collection coverage, representative records and indexes, authentication, required encryption keys and application connection configuration. Confirm all active MongoDB destinations point to the intended dataset. Review any migration Jobs independently; a successful Helm command or ready MongoDB pod does not prove a restore or application migration completed.

Do not resume until the approved restore-validation checklist passes. If it fails, keep writers stopped, preserve both datasets and use the rehearsed recovery plan.

### 4. Resume with the complete running configuration

```sh
helm upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm --version 11.0.0 --namespace midaz --reset-values -f values-11.0-resume.yaml --dry-run > preview-11.0-resume.txt
# STOP: privately review the preview before continuing.
helm upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm --version 11.0.0 --namespace midaz --reset-values -f values-11.0-resume.yaml
```

When autoscaling is enabled the chart omits Deployment `spec.replicas`; re-enabling the HPA does not by itself reliably restart a Deployment held at zero. Explicitly scale each enabled application Deployment to its separately recorded intended initial replica count (its intended `autoscaling.minReplicas` for an HPA-managed workload), using its verified exact name. Do not use a single shared count for ledger and CRM unless both counts really match. When autoscaling is disabled, verify the resumed configuration renders and applies the intended nonzero `replicaCount`.

Check each enabled application's readiness and connectivity, then validate representative holders, fee packages and relevant operations through the authenticated application interfaces. Keep real credentials out of commands/logs. Release external writers and reconciliation controls only in the reviewed order and verify they do not reapply the old chart, hosts or paused values. Define downtime from rehearsal, not a fixed untested estimate.

## Argo CD / GitOps cutover

Argo CD rendering is not a Helm release to upgrade with the CLI commands above. Pause auto-sync and other reconciliation before the maintenance window. In the reviewed desired state for chart `10.4.3`, apply the complete paused configuration and disable the writer HPAs; verify writer pods are gone before the final backup. Protect the old claim/PV before any sync/prune, then select chart `11.0.0` with the complete paused target configuration.

Audit **all** effective GitOps values sources, parameters and overlays so removed host/strategy overrides are not reintroduced. Keep credentials and the replica-set key stable through the approved secret-management process. Review sync waves, migration Jobs, pruning and retention in advance; do not assume sync completion proves data was restored.

If pruning removes the old PVC, its PV must already be protected and its recovery bindings recorded. With pruning disabled, explicitly retire the old MongoDB Deployment and obsolete Service after the final backup, under the reviewed plan, while preserving the old data. The old pod's labels can match the new headless Service and split connections if it remains running. Verify endpoints and mounts before restoring/resuming.

Follow the same destination, restore and validation gates as the Helm path. Only after those gates pass, apply the complete running desired configuration and sync. Explicitly seed each enabled HPA-managed Deployment's recorded initial replica count if it remains at zero, then check actual application readiness. Restore auto-sync only after confirming the desired state no longer reinstates the old topology or paused writer settings.

## Rollback is also a data operation

A plain `helm rollback` does not transfer writes from the new replica-set claim back to the old standalone claim. Stop writers, establish the authoritative dataset and recovery point, and validate a data-restoration and workload-recovery procedure before changing chart revisions. After new writes have been accepted, the old retained claim is stale unless a verified recovery procedure reconciles/restores the selected authoritative data. Never resume against it merely because the old pod starts successfully. Keep the old storage, backups and credentials under the approved recovery-retention policy; cleanup is a separate authorized operation, not an automatic final command.

## External MongoDB and deferred migrations

When `mongodb.enabled: false`, the chart does not migrate the external database. Preserve the complete external connection configuration, TLS, credentials and Secret references, and verify topology, authentication and compatibility with the actual application image independently. Do not infer a new MongoDB transaction requirement or a provider/version compatibility guarantee solely from this chart major-version bump or the historical README.

If you cannot satisfy the bundled migration prerequisites, defer the upgrade. Do not use the historical Option A runtime assertions as a compatibility decision or improvise a topology switch during the window.

## Verification boundary and published chart

This documentation review verified source and rendered resource differences only. It did **not** execute a live migration, application startup test or restore drill. An environment-specific migration remains blocked until its operational prerequisites are satisfied.

The reviewed target is `oci://ghcr.io/lerianstudio/midaz-helm`, version `11.0.0`. The package was available anonymously during review. This is not authorization to execute an upgrade before the data-cutover and recovery plans are validated.
