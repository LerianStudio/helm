# Helm Upgrade from v1.0.8 to v1.0.9

## Release scope

Chart 1.0.9 updates the default br-sta application images to 1.4.1. Manager,
worker, migrations and the optional mock STA have explicit `1.4.1` image tags.
These are defaults, not a guarantee that an existing release adopts them: inspect
all retained image overrides and render the complete intended configuration.

The preceding chart used application 1.4.0 with explicit component pins. This
release updates those defaults to 1.4.1; retained custom pins still win. To adopt
the new defaults, remove obsolete pins from the complete intended values file
and apply that file with reset semantics as shown below, or explicitly choose
all intended component tags. Editing a local file without passing it to Helm
does not change the installed release.

Application 1.4.1 retains migration `000025_license_file` and the database-backed
licence startup introduced in 1.4.0. It also updates recipient compression
membership for AJUD302B. This guide does not establish live BACEN compatibility.
There is no new SQL migration in the 1.4.0-to-1.4.1 application source range;
that does not make application rollout or rollback risk-free.

## Prepare and preserve the configuration

1. Schedule the rollout and take consistent, private PostgreSQL backups and
   private backups of the release configuration and credential/key material.
   Preserve Secret references, external datastore endpoints, storage settings,
   encryption keys, streaming/auth configuration and unrelated overrides. Do not
   print decoded Secrets or commit live credentials to Git.
2. Establish a tested database/configuration restore procedure and compatible
   application recovery plan before upgrading. Helm rollback does not undo SQL
   migrations or restore database contents. Confirm the required licence state
   before starting the new processes.
3. Inspect the existing release's user-supplied values in a restricted location.
   Prepare `complete-intended-values.yaml` containing the complete intended
   configuration, not just changed image pins. `--reset-values` discards stored
   overrides not present in that file; a partial file can lose critical settings.
4. Verify the selected manager, worker, migrations and enabled mock tags. Removing
   old overrides should intentionally select the `1.4.1` defaults; do not remove
   unrelated configuration. Check image access for every enabled component.
5. Verify the actual migration execution mode. In single-tenant mode, an external
   PostgreSQL configuration renders a pre-install/pre-upgrade migration hook;
   bundled PostgreSQL renders a regular Job instead. In multi-tenant mode the
   chart suppresses this Job even when `migrations.enabled` is true: arrange and
   verify the supported tenant migration procedure before application rollout.
   Disabled migrations require a separately completed, supported procedure.

## Preview and upgrade

Use the same complete values file for both commands. Review the rendered images,
Secret references, migration resources, PVC names/mounts and selectors against
this release's current resources before applying. A render is not a database
migration, data copy, live upgrade or restore test.

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm \
  -n br-sta --version 1.0.9 --reset-values -f complete-intended-values.yaml
```

This requires the [helm-diff plugin](https://github.com/databus23/helm-diff).
After reviewing the preview and meeting the prerequisites:

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm \
  -n br-sta --version 1.0.9 --reset-values -f complete-intended-values.yaml
```

Use the actual release name and namespace if different. Do not enable bundled
infrastructure or the development mock as an upgrade workaround in production.

## Verify and recover

Verify the applicable migration outcome before accepting application readiness;
observe hook/Job execution while it runs and retain results privately. Do not
interpret an absent Job as success or failure without checking its lifecycle.
Confirm the rendered resource names rather than guessing a migration Job name.

```bash
kubectl get deployments -n br-sta -l app.kubernetes.io/instance=br-sta \
  -o custom-columns='NAME:.metadata.name,IMAGES:.spec.template.spec.containers[*].image,READY:.status.readyReplicas'
```

Verify manager/worker rollout, readiness and required application workflows using
the intended component versions. The mock is optional and does not prove BACEN
integration. Investigate failures before resuming dependent traffic.

If recovery is needed, stop the rollout and assess application/schema/licence
compatibility using the retained migration results. Helm rollback only reverts
Kubernetes release manifests; it is not data recovery. Use the pre-tested
coordinated database/configuration restore and compatible image plan when
required, preventing new writes during recovery. No live upgrade, migration or
restore execution is claimed by this guide.
