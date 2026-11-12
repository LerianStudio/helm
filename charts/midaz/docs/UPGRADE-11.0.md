# Helm upgrade from v10.4.3 to v11.0.0

## Stop before upgrading bundled MongoDB

**This is a data migration, not an in-place pod restart. Do not run a plain Helm upgrade or GitOps sync against a populated bundled MongoDB installation.** The old PVC is not automatically attached to the replica set.

This guide compares chart `10.4.3` with chart `11.0.0`. Both default to Midaz application `4.4.2`; the chart version is not the application version.

## Verified chart changes

- Bundled MongoDB changes from a standalone **Deployment** to a single-member replica-set **StatefulSet**. The target sets `mongodb.architecture: replicaset`, `mongodb.replicaCount: 1`, `mongodb.arbiter.enabled: false` and `mongodb.updateStrategy.type: RollingUpdate`.
- With release name `midaz`, the old Deployment mounts PVC `midaz-mongodb`. The new StatefulSet's `datadir` volume-claim template creates **`datadir-midaz-mongodb-0`**, not a mount of the old claim. These names change with the release name.
- The bundled MongoDB host default changes to `midaz-mongodb-headless`. Explicit datastore host overrides still take precedence and must be reviewed.
- `Recreate` is a Deployment strategy, not a valid StatefulSet strategy. The transition is between workload kinds, not an immutable-field edit of an existing MongoDB StatefulSet. A one-member replica set does not provide high availability or a zero-downtime guarantee.

## Data-protection and cutover requirements

**Backup and a verified restore are mandatory for a populated installation.** Retaining a volume is not evidence that the new workload uses it.

Use the release-specific [MongoDB migration section in the chart 11.0.0 README](https://github.com/LerianStudio/helm/blob/midaz-v11.0.0/charts/midaz/README.md#mongodb-replica-set-chart-1100) as the source for a reviewed, environment-specific runbook. Before executing it:

1. Record the release revision, complete intended Helm values, actual workload names, MongoDB authentication settings, PVC/PV bindings and reclaim policies. Restrict access to exported values and database backups; they can contain credentials or customer data. Do not commit them.
2. Stop application writers and drain their pods before taking a consistent backup. Keep ledger and any enabled legacy CRM writers at zero through the database cutover; account for other writers outside this release.
3. Test restoration to the intended replica-set destination and validate the databases and representative records before resuming writers. Review handling of MongoDB system databases and use the correct authentication database. Do not copy unquoted password placeholders into shell commands.
4. For Helm, verify the old retained claim remains protected and unmounted. For Argo CD with pruning, protect the old claim/PV before sync: a pruned claim with a `Delete` reclaim policy can destroy the old data. Without pruning, explicitly handle the old Deployment and Service: its running pod can otherwise be selected by the new headless Service and split application connections between old and new databases.
5. Apply a **complete migrated values file** explicitly to both preview and upgrade. Preserve application and migration image pins, credentials and unrelated settings; do not rely on edited local values being picked up automatically.
6. Resume writers only after validating restore results, replica-set readiness and application connectivity against the intended destination. Define downtime from a rehearsal, not an untested fixed estimate.

This documentation review verified source and rendered resource differences only. It did **not** execute a live migration or restore drill. An environment-specific migration remains blocked until those operational prerequisites are satisfied.

## Rollback is also a data operation

A plain `helm rollback` does not transfer writes from the new replica-set claim back to the old standalone claim. Stop writers, establish the authoritative dataset and recovery point, and validate a data-restoration and workload-recovery procedure before changing chart revisions. Never resume against an old retained claim merely because the old pod starts successfully.

## External MongoDB

When `mongodb.enabled: false`, the chart does not migrate the external database. Preserve the complete external connection configuration and verify topology, authentication and application compatibility independently. The application version is unchanged between these chart releases; do not infer a new transaction requirement solely from the chart major-version bump.

## Published chart

The reviewed target is `oci://ghcr.io/lerianstudio/midaz-helm`, version `11.0.0`. The package was available anonymously during review. This is not authorization to execute an upgrade before the data-cutover plan is validated.
