# Helm Upgrade from v11.1.0 to v11.1.1

## Release scope and effective images

Chart 11.1.1 updates application 4.4.2 to 4.4.3. The default ledger/tracer and
migration images advance to 4.4.3. The chart templates and configuration schema
are unchanged; application behavior is not necessarily unchanged.

Existing image overrides can retain older versions. Check `ledger.image.tag`,
`tracer.image.tag` and the consumed migration overrides
`ledger.migrations.image.tag` and `tracer.migrations.image.tag`. Migration Jobs
fall back through their component image tag and appVersion when their own tag is
empty; do not confuse generated root-level migration image keys with those
consumed overrides. Select a compatible complete image set deliberately.

Default image/version changes update enabled workload pod templates. The chart
excludes `helm.sh/chart` from pod labels, so a chart label alone does not guarantee
a restart. A retained image pin may prevent the advertised application update.
Do not promise an exact restart count or zero downtime; check the actual replica
count, update strategy and readiness behavior. Tracer is disabled by default.

## Cross-ledger holds: rollout and rollback boundary

Application 4.4.3 fixes holds whose receiving-ledger destination part also has a
client account as a source. Such held-payer groups persist `formatVersion: 2`.
Groups already stored with `formatVersion: 1` retain their earlier behavior.

An older pod refuses commit/cancel of a version-2 group without moving balances;
its reconciler leaves that unreadable group untouched. During a mixed-version
rolling deployment, retry that refusal after a new-version pod can serve the
request, following the application's lifecycle/idempotency contract. Do not
blindly replay an operation with an uncertain result.

**Do not roll back to 4.4.2 while a version-2 group is still pending.** Older pods
cannot commit or cancel it. Establish a supported pending-group drain/recovery
procedure before rollout and verify that condition before considering rollback.
Unchanged SQL migration files do not imply unrestricted application rollback.

## Prerequisites and migration execution

- Take consistent private backups of the database state, configuration and
  credential references, and establish a tested coordinated restore procedure.
  Preserve external datastore/storage endpoints and unrelated settings. Do not
  commit live credentials or expose backup contents in diagnostics.
- Review effective image pins and supported application/database compatibility.
  If changing pins, prepare `complete-intended-values.yaml` with the complete
  intended configuration. Both commands below use `--reset-values`; settings
  missing from a partial file are discarded. Preserve unrelated overrides and
  Secret references explicitly.
- The ledger migration hook requires ledger and its migrations to be enabled;
  tracer additionally requires tracer and its migrations to be enabled. Confirm
  the actual rendered conditions rather than assuming every Job always runs.
- Migration hooks use `before-hook-creation,hook-succeeded` deletion policy.
  Successful Jobs are normally deleted. Observe/capture their execution results
  privately while upgrading; an empty post-upgrade Job list is not proof of
  failure or success. Helm rollback does not undo database changes or restore data.

## Preview and upgrade

Use your actual release name and namespace and the same complete intended values
file throughout. Inspect images, enabled workloads, migration hooks, PVCs/mounts
and Secret references before applying. A render does not exercise an upgrade,
migration, live workload availability or restore.

```bash
helm diff upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm \
  -n midaz --version 11.1.1 --reset-values -f complete-intended-values.yaml
```

This requires the [helm-diff plugin](https://github.com/databus23/helm-diff).
After the preview and prerequisites have been checked:

```bash
helm upgrade midaz oci://ghcr.io/lerianstudio/midaz-helm \
  -n midaz --version 11.1.1 --reset-values -f complete-intended-values.yaml
```

## Verify and recover

Inspect all deployments for the intended release rather than assuming the first
matching item belongs to it:

```bash
kubectl get deployments -n midaz -l app.kubernetes.io/instance=midaz \
  -o custom-columns='NAME:.metadata.name,IMAGES:.spec.template.spec.containers[*].image,READY:.status.readyReplicas'
```

Verify effective image tags, enabled-workload rollout/readiness, the retained
migration execution evidence and relevant ledger operations. Check tracer only
when it is enabled. Expect 4.4.3 only for components intentionally advanced to
that version; retained pins must be assessed explicitly.

On a failure, stop rollout and inspect pending held-payer groups before deciding
recovery. Do not roll back while version-2 groups remain pending. Coordinate a
compatible application/data/configuration recovery using the tested procedure;
Helm rollback alone neither restores data nor resolves an incompatible pending
intent. No live upgrade, migration execution, rollback or restore test is claimed.
