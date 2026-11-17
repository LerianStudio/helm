# Helm upgrade: System Facts 1.1.3 to 1.2.0

Chart **1.2.0** adds optional license-file mounts, removes the chart-version label from pod templates, and changes the default ingress hostname. Default service and worker images remain **1.1.0**. Chart support for a mount does not establish application support for file-based licensing.

## Compatibility and license requirements

With the default images, **do not clear `LICENSE_KEY` or migrate to file-only licensing**. The service still requires a nonempty `LICENSE_KEY` and `ORGANIZATION_IDS`. Its shipped application source does not read `LICENSE_FILE_PATH`; the default worker does not consume either licensing variable. Preserve the service's existing valid license configuration and Secret references.

A separately validated application upgrade is required before using file-based licensing. This guide establishes neither a compatible replacement image nor automatic license reload. A generic library-major requirement is not sufficient compatibility evidence. Existing image pins remain effective; inspect every component's image in the preview rather than assuming this chart upgrade adopts another application version.

| New key | Default | Rendered effect |
|---------|---------|-----------------|
| `system-facts.licenseFile.existingSecret` | `""` | Optional service Secret directory mount |
| `worker.licenseFile.existingSecret` | `""` | Optional worker Secret directory mount |
| `worker.secrets.LICENSE_KEY` | `""` | Worker Secret data; not consumed by default worker |

When configured, each optional mount uses `/etc/lerian/license`, expects a Secret key named `license`, and sets `LICENSE_FILE_PATH=/etc/lerian/license/license`. These are **render-only capabilities with the default images**, not a license migration procedure. Leave the optional mounts disabled unless an independently validated application configuration requires them. Do not print or decode credentials to verify configuration.

## Rollout and hostname impact

The chart removes `helm.sh/chart` from service and worker pod labels while retaining it on Deployment metadata. This changes the pod template of each enabled Deployment; plan for a rollout. A rollout is not proof of downtime, and its live outcome has not been tested here.

Removing the label does **not** guarantee that future chart-only upgrades avoid rollouts. The service hashes full generated ConfigMap and Secret manifests, including chart-version labels. The worker hashes configuration and Secret data instead. Compare rendered pod templates for each release; there is no no-restart guarantee.

The default `system-facts.ingress.hosts[0].host` changes from `system-facts.lerian.net` to `system-facts.example.com`. This can affect **existing releases** adopting new defaults with ingress enabled and no explicit hostname override. Reusing historical values can retain the old hostname. Ingress is enabled by default in both releases. Set the intended hostname explicitly, or explicitly disable ingress when it is not intended, and inspect the rendered Ingress before upgrading. Neither historical nor example domains are instructions to use that hostname in production.

Dependencies and default image versions are unchanged between these chart releases. This does not certify application runtime, datastore or operational compatibility for a particular environment.

## Prepare and preserve configuration

Use the actual release name and namespace if they differ from `system-facts`. Work in a private directory with restrictive permissions; release values, manifests, diff output and backups can contain credentials. Do not commit or upload them.

```bash
umask 077
helm list --namespace system-facts
helm history system-facts --namespace system-facts
helm get values system-facts --namespace system-facts > release-user-values.yaml
helm get values system-facts --namespace system-facts --all > release-computed-values.yaml
helm get manifest system-facts --namespace system-facts > release-manifest.yaml
```

Confirm the starting chart is `system-facts-helm-1.1.3`. Record the rollback revision. Prepare `complete-intended-values.yaml` from the private configuration backup, retaining **every required override, existing Secret reference, valid service license configuration, organization configuration, image pin and unrelated setting**. Review new defaults rather than blindly copying computed values. A feature-only fragment is not a complete replacement.

Explicitly retain the intended ingress hostname when ingress is enabled. Preserve other ingress settings, including TLS, annotations, class and paths. Editing a local file does not update the release until that file is passed to Helm.

Arrange consistent datastore backups and a tested recovery plan before upgrading. Helm rollback restores release manifests, not database contents, deleted data or independently rotated Secret contents. This guide does not exercise backup/restore or establish recovery compatibility with a separately changed application image.

## Preview and upgrade

Use **the same complete private file** in preview and upgrade. `--reset-values` intentionally replaces stored values; omitting required settings from the file loses those overrides. Do not substitute a partial license fragment or a command that omits the edited file.

With the public [helm-diff plugin](https://github.com/databus23/helm-diff) installed:

```bash
helm diff upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --namespace system-facts --version 1.2.0 \
  --reset-values --values complete-intended-values.yaml
```

Keep output private. Inspect service and enabled-worker images, pod templates, license and organization configuration references, ingress hostname/TLS, datastore references, selectors, PVC names and mounts. Stop if an unplanned change appears. A successful render is not application startup or licensing verification.

After reviewing the preview and arranging an appropriate maintenance window:

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --namespace system-facts --version 1.2.0 \
  --reset-values --values complete-intended-values.yaml
```

This command does not perform file-only license migration with the default images.

## Verify and recover

For the default resource names:

```bash
kubectl rollout status deployment/system-facts --namespace system-facts
helm list --namespace system-facts
helm status system-facts --namespace system-facts
kubectl get pods --namespace system-facts \
  --selector app.kubernetes.io/instance=system-facts
```

If the worker is enabled:

```bash
kubectl rollout status deployment/system-facts-worker --namespace system-facts
```

Use resource names and labels from the preview when naming overrides are configured. Confirm chart `system-facts-helm-1.2.0`, expected images, readiness and the environment's normal service/worker smoke tests. Inspect startup failures privately without exposing credentials. Readiness alone does not establish license reload, worker business processing or restore correctness.

If verification fails, stop further changes and investigate before reverting. After checking the recorded revision and recovery prerequisites above:

```bash
helm rollback system-facts <previous-revision> --namespace system-facts
```

Replace `<previous-revision>` with the recorded revision; do not run the placeholder literally. Recheck rollouts and smoke tests. Rollback does not undo independent datastore or Secret changes.

## Validation boundaries

This guide was checked against chart tags and published packages **1.1.3/1.2.0**, including locked embedded dependencies, and the default images' matching application revision. Static lint and synthetic renders cover labels, checksums, optional mounts and hostname behavior. No live upgrade, application execution, license reload, migration, restore, helm-diff execution or dependency build under enforced network isolation was performed.
