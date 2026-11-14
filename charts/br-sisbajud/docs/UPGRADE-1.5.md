# Helm upgrade from v1.4.4 to v1.5.0

## Release scope and runtime limitation

This guide compares chart `br-sisbajud` 1.4.4 with 1.5.0. Both have appVersion `1.1.0`; the default application and migration images remain `br-sisbajud:1.1.0` and `br-sisbajud-migrations:1.1.0`. Existing image-tag overrides remain separate configuration and must be reviewed and preserved. A chart version is not an application version.

Chart 1.5.0 adds ConfigMap wiring for `STA_DOCUMENT_TYPE_AJUD302B`, sourced from `brSisbajud.sta.documentTypeAjud302b`, with fallback `AJUD302B`. Chart 1.4.4 does not emit that variable. Existing AJUD302/AJUD309 wiring is unchanged.

**This is chart-only wiring, not working AJUD302B processing in the default application.** The exact source revision of both default images is `946d8fb9801f4f1d67cf92578e897ac7e4b7ac5f`. That application's STA configuration and outbound document-type mapping support AJUD302/AJUD309, not the new variable. Do not enable a production AJUD302B flow on the strength of this chart addition. A separately verified compatible application release and integration tests would be required; this guide does not prescribe a replacement image.

The following is an optional edit to merge into a complete intended values file, **not** a deployable configuration:

```yaml
brSisbajud:
  sta:
    documentTypeAjud302b: "AJUD302B"
```

Omitting this key still renders the fallback in 1.5.0; setting it does not make the default binary consume it. Do not enable STA transfers or its consumer merely to expose this variable. Preserve the existing integration configuration. If that configuration uses the STA Kafka stream, the chart key is `brSisbajud.sta.stream.brokers`, not `bootstrapServers`; `groupId` is not consumed by this chart helper. Enabling STA requires separately validated endpoints, object-store bucket/endpoint parity, credentials and environment-specific identifiers. None is supplied by the fragment above.

## Prepare complete configuration and recovery

1. Confirm that the installed predecessor is chart 1.4.4 and record its revision, image overrides and effective configuration. For the example commands below, the Helm release and namespace are both `br-sisbajud`; substitute the real names consistently.
2. Capture the release values and manifest in a private directory. These files can contain credentials; do not commit them, upload them to tickets or paste their contents into logs.

```bash
umask 077
mkdir -p private-br-sisbajud-upgrade
helm history br-sisbajud -n br-sisbajud > private-br-sisbajud-upgrade/history.txt
helm get values br-sisbajud -n br-sisbajud -o yaml > private-br-sisbajud-upgrade/user-values.yaml
helm get values br-sisbajud -n br-sisbajud --all -o yaml > private-br-sisbajud-upgrade/effective-values.yaml
helm get manifest br-sisbajud -n br-sisbajud > private-br-sisbajud-upgrade/manifest.yaml
```

3. Prepare `values-1.5.0.yaml` as the **complete intended configuration** against chart 1.5.0. Preserve unrelated overrides, application/migration image pins, endpoints, authentication, license configuration, execution TLS, external Secret references and datastore configuration. Review the private snapshots rather than blindly treating computed old defaults as the new configuration. The commands below use `--reset-values`, so an incomplete file would lose omitted overrides. Do not replace this file with the optional fragment above.
4. Before running any upgrade, obtain consistent, recoverable backups of persistent state and the required protected credentials/encryption material. Include PostgreSQL and any deployed object storage, broker state/offsets and other persistent dependencies as required by the actual topology. Coordinate writers/consumers and agree a recovery point and downtime plan. Verify recovery in a suitable isolated environment; Helm release metadata is not a data backup.
5. Review the rendered application, init containers and every enabled hook/bootstrap Job. The chart diff does not introduce a new application/migration image or SQL migration, but migrations remain enabled by default and upgrade hooks can still run. Retained image overrides or configuration changes can change behavior; do not infer safety from the additive environment variable alone.

## Preview and upgrade

Use the same complete intended values in preview and upgrade. This guide does not install plugins; the optional diff requires an already reviewed [helm-diff plugin](https://github.com/databus23/helm-diff). Treat both preview files as confidential because rendered Secrets can be included.

```bash
umask 077
helm template br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm \
  -n br-sisbajud --version 1.5.0 --is-upgrade \
  -f values-1.5.0.yaml > private-br-sisbajud-upgrade/target-render.yaml
helm diff upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm \
  -n br-sisbajud --version 1.5.0 --reset-values \
  -f values-1.5.0.yaml > private-br-sisbajud-upgrade/preview.diff
```

Stop on unexpected image, Secret reference, workload, storage, hook or endpoint changes. Resolve the cause and repeat the preview before proceeding. A template/diff is not a running application or migration test.

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm \
  -n br-sisbajud --version 1.5.0 --reset-values \
  -f values-1.5.0.yaml --wait --timeout 10m
```

For GitOps-managed releases, update the owning desired-state chart pin and complete effective values instead of issuing an out-of-band Helm upgrade. Review the controller's rendered resources, sync ordering, hooks and pruning separately; a GitOps application need not be a Helm-managed release.

## Verify before resuming normal traffic

For the release/namespace shown above, the application label is `br-sisbajud`, not the chart package name `br-sisbajud-helm`. Verify the actual rendered names if naming overrides are present.

```bash
kubectl -n br-sisbajud get deployments,pods \
  -l app.kubernetes.io/name=br-sisbajud,app.kubernetes.io/instance=br-sisbajud
kubectl -n br-sisbajud rollout status deployment/br-sisbajud --timeout=10m
kubectl -n br-sisbajud get jobs -l app.kubernetes.io/instance=br-sisbajud
```

Confirm application readiness and the outcome of every enabled migration/bootstrap Job, including any migrations init container. Review failures privately without disclosing credentials. Verify effective image tags, Secret references, datastore connectivity and the existing supported AJUD302/AJUD309 flows through environment-appropriate smoke tests before resuming normal processing. A green rollout or Helm exit code does not establish AJUD302B support or data consistency.

## Rollback and recovery boundary

Do not automatically roll back into a database or dependency state incompatible with the preceding application. Stop affected writers/consumers first and assess hooks, migrations and state changes. Helm rollback can restore release resources but does **not** restore PostgreSQL, object-store contents, broker messages/offsets, encryption material or external effects. Recover those from the verified backups and agreed recovery point when needed, reconcile in-flight work, and verify readiness and data consistency before traffic resumes. Retain the old configuration, backups and recovery material until the upgrade is accepted.

Validation for this guide is source comparison, anonymous publication checks and synthetic Helm renders of the exact chart releases. No live upgrade, SQL migration, application startup or restore drill was executed as part of the documentation review. Operator-specific prerequisites above remain mandatory.
