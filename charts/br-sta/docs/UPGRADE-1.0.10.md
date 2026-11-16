# Helm Upgrade from v1.0.9 to v1.0.10

## Release scope

Chart 1.0.10 changes `appVersion` and the default manager, worker, migrations and
optional mock STA image tags from `1.4.1` to `1.4.2`. The release does not change
the chart's configuration schema or workload templates. These are defaults:
retained custom image tags still select those custom versions, even when pods
restart. Select a compatible manager/worker/migrator set explicitly and account
for the mock when enabled. Do not infer application adoption from a restart.

The public manager, worker and migrations OCI images identify application source
revisions `a0780f842cae99239903e2dba7d950dea71c7ebb` (1.4.1) and
`54257bc4c093265d8db32c22ab72281ad6a41ea8` (1.4.2). The STA service source,
including its SQL migrations, is unchanged between those revisions; other
monorepo/shared code does change. This is not a claim of identical runtime
behavior or tested BACEN compatibility.

The application retains migration `000025_license_file` and database-backed
licence startup. Confirm the required schema and valid licence provisioning
before accepting manager/worker readiness. An image bump alone does not satisfy
these prerequisites.

## Prepare and preserve configuration

1. Schedule the rollout, including a worker interruption: the manager defaults to
   `RollingUpdate`, but the worker always uses `Recreate` with one replica, not a
   rolling update. Check any configured manager strategy and disruption policy.
2. Take consistent private PostgreSQL backups and private backups of release
   configuration, licence state, encryption keys and credential material. Preserve
   external datastore endpoints, storage, streaming/auth configuration, Secret
   references and unrelated overrides. Never print decoded Secrets or commit
   live credentials to Git. Establish and test a coordinated database/configuration
   restore and compatible application recovery plan before upgrading.
3. Inspect the installed release's user-supplied values in a restricted location.
   Prepare `complete-intended-values.yaml` with the **complete intended
   configuration**, not just changed image tags. The commands below use
   `--reset-values`: stored overrides omitted from that file are discarded.
4. To select 1.4.2 defaults, remove obsolete component image pins from that complete
   file, or explicitly set every intended component tag. Preserve all unrelated
   settings. Check access to every selected image from the deployment environment.
   The optional `mock-sta-server` repository refused anonymous token access during
   release review; its tag existence/source could not be verified anonymously.
   If the mock is enabled, stop until its exact image access and provenance have
   been independently verified. Do not enable the development mock or bundled
   infrastructure as a production upgrade workaround.
5. Check actual migration execution mode. In single-tenant mode with external
   PostgreSQL, the chart renders a `pre-install,pre-upgrade` migration hook. With
   bundled PostgreSQL it renders a regular Job instead; do not assume pre-upgrade
   ordering. Multi-tenant mode suppresses this Job even when
   `migrations.enabled=true`; arrange and verify the supported tenant migration
   procedure. Disabled migrations also require a separately completed procedure.

## Preview and upgrade

Use the actual release name and namespace if different. Use the **same complete
values file and reset semantics** for preview and upgrade. Review all effective
images, migration resources, Secret references, PVC names/mounts and selectors
against the installed release before applying. A render is not a database
migration, data copy, live upgrade or restore test.

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm \
  -n br-sta --version 1.0.10 --reset-values -f complete-intended-values.yaml
```

Preview requires the [helm-diff plugin](https://github.com/databus23/helm-diff).
After reviewing the preview and meeting all prerequisites:

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm \
  -n br-sta --version 1.0.10 --reset-values -f complete-intended-values.yaml
```

The chart package at this GHCR location/version was anonymously retrievable
during review. The image-tag defaults do not promise that every pod will be
recreated in every configuration. In the reviewed synthetic configuration,
manager/worker ConfigMap checksums changed across these chart versions even
with all component tags pinned to 1.4.1, so those Deployments would restart but
still run 1.4.1. Migration Job identity depends on its rendered spec; external
hooks and regular Jobs have different execution/lifecycle behavior. Review the
actual rendered PodTemplates and Job resources rather than assuming universal
rollout or rerun behavior.

## Verify and recover

Verify the applicable migration outcome before accepting application readiness.
Observe hook/Job execution while it runs and retain results privately; successful
external hooks are deleted. An absent Job is not proof of success or failure.
Use rendered resource names; migration names contain a spec hash.

```bash
kubectl get deployments -n br-sta -l app.kubernetes.io/instance=br-sta \
  -o custom-columns='NAME:.metadata.name,IMAGES:.spec.template.spec.containers[*].image,READY:.status.readyReplicas'
```

The instance label scopes this query to the Helm release. The default application
name label is `br-sta`, not the package name `br-sta-helm`; `nameOverride` can
change it. Respect any configured `namespaceOverride` when querying resources.
Verify each enabled manager/worker Deployment's rollout, readiness, effective
image and required business workflows; use the rendered names if overrides are
set. An enabled mock proves neither connectivity nor compatibility with BACEN.
Investigate failures before resuming dependent traffic.

For recovery, stop the rollout and assess schema/licence/application compatibility.
Helm rollback reverts release manifests, not SQL migrations or database contents.
Use the pre-tested coordinated restore and compatible image plan when needed,
preventing new writes during recovery. This guide does not claim a live upgrade,
migration, restore or BACEN integration test.
