# Helm Upgrade from v4.1.3 to v4.2.0

## Compatibility boundary

Chart `4.2.0` adds optional license-file mounts for manager and worker. It does **not** upgrade the application: both charts ship Fetcher `4.1.0` (`appVersion` and default images).

**Keep `LICENSE_KEY` with the default images.** Fetcher `4.1.0` uses `lib-license-go/v4` and rejects an empty `LICENSE_KEY` during manager and worker startup. Mounting a file or setting `LICENSE_FILE_PATH` does not make those images consume it. This guide does not identify a compatible file-mode application release and therefore does not prescribe a file-only migration.

Existing key-mode configuration remains supported. Leave both `licenseFile.existingSecret` values empty and preserve the current license key and all other settings or external Secret references. An upgrade can restart workloads; do not interpret optional file mounts as a no-restart guarantee.

## Chart changes

Between chart tags `fetcher-v4.1.3` and `fetcher-v4.2.0`, the chart adds:

| Value | Default | Rendered effect when nonempty |
|-------|---------|-------------------------------|
| `manager.licenseFile.existingSecret` | `""` | Mounts the named Secret into manager |
| `worker.licenseFile.existingSecret` | `""` | Mounts the named Secret into worker |

Each Secret must be in the release namespace and contain key `license`. The chart mounts that key read-only at `/etc/lerian/license/license` with mode `0444` and sets `LICENSE_FILE_PATH` to that path. It uses a directory mount, not `subPath`, so Kubernetes can eventually propagate Secret updates. Application reload behavior is a separate compatibility requirement, not established by this chart change.

The following is a **chart-wiring reference only**, not a working file-only recipe for the default images:

```yaml
manager:
  licenseFile:
    existingSecret: fetcher-manager-license
worker:
  licenseFile:
    existingSecret: fetcher-worker-license
```

Do not clear `secrets.LICENSE_KEY` or change application image tags based on this example. A future file-mode deployment requires independently verified application support for both components, its documented mode precedence/reload behavior, provisioned Secrets, and a separate tested migration plan.

## Prepare and back up

The commands below assume release `fetcher` in namespace `midaz-plugins`. Substitute the existing release and namespace if different. Run these on an authorized operator workstation; this document does not execute them.

1. Record the current Helm revision and confirm the installed chart is `4.1.3`.
2. Back up release values and rendered manifests privately. They may contain credentials. Never commit them, upload them to tickets, or paste them into chat.
3. Back up externally managed Secrets through the approved secret-management process without printing their contents. Preserve names, keys and access policies. Take the required datastore and object-storage backups and verify the restore procedure before the maintenance window.

```bash
umask 077
mkdir -p fetcher-upgrade-private
helm history fetcher -n midaz-plugins > fetcher-upgrade-private/history.txt
helm get values fetcher -n midaz-plugins -o yaml > fetcher-upgrade-private/original-values.yaml
helm get manifest fetcher -n midaz-plugins > fetcher-upgrade-private/original-manifest.yaml
cp fetcher-upgrade-private/original-values.yaml fetcher-upgrade-private/intended-values.yaml
```

Review `intended-values.yaml` against both releases. It must contain the **complete intended overrides**, not just a partial license snippet: retain image overrides, credentials, license key or existing Secret references, external datastore addresses, storage, ingress, resources, scheduling and other custom settings. An export is a starting point, not proof the intended configuration is complete. Preserve both file-mode settings as empty for the default `4.1.0` images. Do not replace existing credentials with empty example values.

`--reset-values -f` below deliberately replaces stored overrides with this reviewed file, layered onto the target chart defaults. Omitting an intended override can reset it. Do not use this strategy until the complete configuration has been reviewed.

## Preview

Fetch the exact public chart package with your normal approved Helm registry configuration:

```bash
helm pull oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.2.0 --destination fetcher-upgrade-private
helm lint fetcher-upgrade-private/fetcher-helm-4.2.0.tgz -f fetcher-upgrade-private/intended-values.yaml
helm template fetcher fetcher-upgrade-private/fetcher-helm-4.2.0.tgz -n midaz-plugins -f fetcher-upgrade-private/intended-values.yaml > fetcher-upgrade-private/preview.yaml
helm upgrade fetcher fetcher-upgrade-private/fetcher-helm-4.2.0.tgz -n midaz-plugins --reset-values -f fetcher-upgrade-private/intended-values.yaml --dry-run > fetcher-upgrade-private/upgrade-dry-run.txt
```

Keep render/dry-run output private because it may include Secret data. Compare workload names, selectors, PVC names/mounts, external Secret references and all image tags with the current manifest. A successful render does not validate credentials, application startup, licensing, data recovery or a live upgrade. Do not proceed if any persistent resource would be replaced unexpectedly.

## Upgrade and verify

Use the same reviewed package and complete intended values used for the preview:

```bash
helm upgrade fetcher fetcher-upgrade-private/fetcher-helm-4.2.0.tgz -n midaz-plugins --reset-values -f fetcher-upgrade-private/intended-values.yaml --wait --timeout 10m
kubectl get deployments -n midaz-plugins -l app.kubernetes.io/instance=fetcher
kubectl get pods -n midaz-plugins -l app.kubernetes.io/instance=fetcher
```

Use the actual manager and worker Deployment names from that listing to check rollout status. Do not use `app.kubernetes.io/name=fetcher`: the default component names are `fetcher-manager` and `fetcher-worker`. Do not pass a label selector to `kubectl exec`; it requires a resource name. Scope any additional pod selection to this release and component.

Confirm both components become ready, retain the intended license configuration and datastore connections, and complete an approved functional extraction check. Review logs privately for startup/licensing errors; do not print license files, Secret data or credentials as verification. Helm readiness alone does not prove an extraction succeeded.

## Recovery boundary

If the upgrade fails, stop further changes and retain private diagnostics. After assessing compatibility, use the **previous revision number recorded before the upgrade**:

```bash
helm rollback fetcher PREVIOUS_REVISION -n midaz-plugins --wait --timeout 10m
```

Replace `PREVIOUS_REVISION` with that recorded numeric revision. Verify manager and worker readiness and the functional extraction check again. Helm rollback does not restore externally managed Secrets, databases or object storage and cannot reverse arbitrary application/data changes. Restore those only through the separately verified backup/restore runbook and the approved recovery decision. Do not uninstall the release or delete PVCs to recover.

## Validation scope

This guide is based on exact chart release sources, rendered templates and the shipped Fetcher `4.1.0` startup source. No live install, upgrade, license rotation, backup or restore was exercised as part of this documentation review. Operators must validate the procedure in a suitable non-production environment before production use.
