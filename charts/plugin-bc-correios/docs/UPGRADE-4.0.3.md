<!-- {% raw %} -->
# BC Correios chart 4.0.2 → 4.0.3

## Release scope

Chart 4.0.3 adds `checksum/config` and `checksum/secret` to the **BC Correios application Deployment pod template**. Both releases retain appVersion and default application image tag **1.1.0**; an explicit image override remains effective. This is a chart change, not a new application release.

Helm computes these annotations from the chart's application ConfigMap and generated application Secret templates. When an upgrade changes either rendered template, Kubernetes can roll the application Deployment according to its configured update strategy. This is not a live watcher of Kubernetes objects or an immediate configuration reload.

The checksums do **not** hash PostgreSQL or Valkey subchart Secrets, external Secrets or external ConfigMaps. Independently changing those resources does not change these annotations. Plan credential rotation and the required application rollout separately: editing a Secret or Helm value does not rotate a PostgreSQL role password.

The first upgrade from 4.0.2 adds the annotations even with identical application values. This changes the application pod template; it does not imply that every workload in the release restarts. SeaweedFS does not receive these two new annotations. Preserve unrelated custom pod annotations and inspect the actual rendered update strategy, replicas and readiness settings before scheduling the upgrade. Do not override the chart's checksum annotation keys.

## Prerequisites and recovery

The historical chart diff introduces no new migration files or migration-template changes. Existing migration, startup, backup and recovery prerequisites still apply; a small chart diff is not proof of safe application startup or schema compatibility.

The chart packages for 4.0.2 and 4.0.3 were retrieved anonymously from GHCR during review. The Docker Hub chart path returned an authorization failure, so the commands below use the verified GHCR path. Chart availability does not prove availability or source provenance of the application image. Anonymous access to the default application-image repository was denied during review: obtain verified pull access, image digest/build provenance and exact-runtime prerequisites before production changes. Do not assume that a source tag alone identifies the published binary.

Before upgrading:

1. Identify the actual release and namespace, naming overrides, application image pin, datastore identities, PVCs, credentials and Secret references.
2. Preserve private copies of release values/manifests and consistent backups of every persistent datastore in use, including external stores. Rehearse restore and application compatibility in isolation; preserve credentials and any required keys securely.
3. Prepare one **complete intended configuration** in `values.private.yaml`, including every still-required non-default value, image pin, datastore credential and Secret reference. Keep this file and exported Helm data private and out of Git, logs and chat. Do not use a fragment as a complete replacement.
4. Rehearse the upgrade and recovery with the exact package/images. Plan a maintenance window when single-replica or availability constraints require it. Rendering is not an exercised deployment or restore.

A Helm rollback does not restore database contents or independently managed credentials. Validate older-binary compatibility with the current schema/data before rollback; otherwise use the independently rehearsed recovery procedure. Do not run a newer writer against restored data until its startup/migration effects are understood.

## Preview and upgrade

The examples assume release/namespace `plugin-bc-correios`. Adjust them to the actual installation. Reset semantics deliberately discard omitted user overrides; review the complete intended file and preserve every required setting explicitly.

Preview with the [helm-diff plugin](https://github.com/databus23/helm-diff), after verifying plugin compatibility with your Helm version. Rendered output can contain secrets: redirect it to a restricted private file rather than public CI logs.

```bash
umask 077
helm diff upgrade plugin-bc-correios \
  oci://ghcr.io/lerianstudio/plugin-bc-correios-helm \
  --version 4.0.3 -n plugin-bc-correios \
  --reset-values -f values.private.yaml > upgrade.private.diff
```

Inspect the application Deployment, its two checksums, image pins, ConfigMap, generated Secret, all referenced Secrets, migration resources, selectors and storage identities. A changed credential requires a coordinated server/client rotation plan, not merely a changed checksum.

After the release, rehearsal and recovery gates pass, apply the **same** complete intended file:

```bash
helm upgrade plugin-bc-correios \
  oci://ghcr.io/lerianstudio/plugin-bc-correios-helm \
  --version 4.0.3 -n plugin-bc-correios \
  --reset-values -f values.private.yaml
```

These commands are instructions for the operator, not a claim that a live upgrade was executed during documentation review.

## Verify the application workload

With default naming the application Deployment is `bc-correios`, not `plugin-bc-correios-bc-correios`. Adjust the Deployment and namespace below when verified naming overrides change them.

```bash
kubectl rollout status deployment/bc-correios \
  -n plugin-bc-correios --timeout=300s
kubectl get deployment bc-correios -n plugin-bc-correios \
  -o go-template='{{ index .spec.template.metadata.annotations "checksum/config" }}{{ "\n" }}{{ index .spec.template.metadata.annotations "checksum/secret" }}{{ "\n" }}'
kubectl logs -n plugin-bc-correios \
  -l app.kubernetes.io/name=bc-correios,app.kubernetes.io/instance=plugin-bc-correios,app.kubernetes.io/component=bc-correios \
  --all-containers=true --tail=50
```

Keep logs private and check for startup, database and migration failures. The component selector avoids including SeaweedFS. A completed rollout or present annotation is not proof that every business integration is healthy; validate the enabled application flows and datastore connectivity separately.

If a checksum demonstration is needed, use an isolated rehearsal and a supported application ConfigMap key such as `bc-correios.configmap.LOG_LEVEL`, retaining the complete intended configuration in both preview and upgrade. Compare the rendered ConfigMap and Deployment checksums first and verify runtime acceptance independently. Do not use nonexistent `bc-correios.someConfigValue` or `bc-correios.database.password` keys, or print passwords to demonstrate rollout.

## Exact-release chart sources

- [4.0.2 → 4.0.3 chart comparison](https://github.com/LerianStudio/helm/compare/plugin-bc-correios-v4.0.2...plugin-bc-correios-v4.0.3)
- [4.0.3 application Deployment](https://github.com/LerianStudio/helm/blob/e6edf7fecbe43aad643327589d18dc23e3da759c/charts/plugin-bc-correios/templates/deployment.yaml)
- [4.0.3 values](https://github.com/LerianStudio/helm/blob/e6edf7fecbe43aad643327589d18dc23e3da759c/charts/plugin-bc-correios/values.yaml)

These sources establish chart behavior, not application-image provenance or a successful live migration.
<!-- {% endraw %} -->
