# Helm Upgrade from v2.5.1 to v2.6.0

## Overview

This guide covers chart `plugin-br-payments` **2.5.1 → 2.6.0**. Both releases default to application image **1.4.0**. The runtime configuration change is chart/schema support for optional `app.secrets.SANDBOX_FAKEBTG_ADMIN_KEY` in the chart-managed Secret. No new database migration is introduced by this same-application-version chart delta.

**Chart support is not application support.** The shipped application 1.4.0 does not read `SANDBOX_FAKEBTG_ADMIN_KEY`. Its FakeBTG administrative adapter sends no authentication credential. Setting this key does **not** enable authenticated sandbox operations, secure that adapter, or activate sandbox simulation. Do not select an unverified newer application image to work around this limitation.

Sandbox simulation is non-production only and has separate toggle, admin URL and matching endpoint-origin prerequisites. This guide does not enable it. Keep production configuration unchanged and do not add an unused sandbox credential.

## Configuration changes

| Setting | 2.5.1 | 2.6.0 |
|---|---|---|
| Chart version | 2.5.1 | 2.6.0 |
| Default application image | 1.4.0 | 1.4.0 |
| `app.secrets.SANDBOX_FAKEBTG_ADMIN_KEY` | Rejected by schema | Optional chart-managed Secret key; no default |

No existing configuration key is removed. No new credential is required. Existing operator-managed Secret references must be preserved; adding chart-managed values does not update an external Secret. Never put real credentials in Git, tickets, terminal output or shared logs.

The chart's configuration/Secret checksum annotations change between these releases even with identical values. Expect a rolling restart; assess replica count, readiness and maintenance-window requirements before proceeding.

## Prepare and preserve configuration

1. Confirm the actual release, namespace, Deployment name, current image overrides and Secret ownership. Commands below assume release `my-payments`, namespace `midaz-plugins` and the default Deployment name `plugin-br-payments`; adapt them to actual name overrides.
2. Record the current release revision. Before any change, obtain private consistent datastore backups and a recovery procedure appropriate to the deployment, including operator-owned Secrets and credential references. Validate recovery in an isolated environment. Do not treat a Helm rollback as a data restore.
3. Export release metadata and user values into a fresh owner-only directory. Disable shell tracing and protect Helm output, which may include secrets:

```bash
set +x
umask 077
backup_dir="$(mktemp -d "${PWD}/payments-upgrade.XXXXXXXX")"
helm history my-payments --namespace midaz-plugins > "$backup_dir/history.private.txt"
helm get values my-payments --namespace midaz-plugins -o yaml > "$backup_dir/current-values.private.yaml"
helm get manifest my-payments --namespace midaz-plugins > "$backup_dir/manifest.private.yaml"
cp "$backup_dir/current-values.private.yaml" "$backup_dir/intended-values.private.yaml"
```

4. Privately review `intended-values.private.yaml` and construct the **complete intended configuration**. Retain unrelated overrides, routing/authentication/licensing settings, image pins, storage/PVC settings and existing Secret references. Both commands below use `--reset-values`: any omitted override reverts to the new chart default. Do not apply until all intended overrides and credentials are accounted for. Preserve the existing application image pin unless a separately validated change is intended. Do not add the unused sandbox key for application 1.4.0.

## Preview changes before upgrading

Requires the separately installed [helm-diff plugin](https://github.com/databus23/helm-diff). Preview in the same shell as the private export; store output privately because manifests can contain credentials.

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm \
  --namespace midaz-plugins --version 2.6.0 \
  --reset-values -f "$backup_dir/intended-values.private.yaml" \
  > "$backup_dir/preview.private.txt"
```

Review the private preview for unintended Secret, image, PVC, workload or routing changes. Abort if the diff does not match the approved configuration. Any Helm hook execution must be assessed from the actual chart and deployment configuration; do not infer recovery safety from the unchanged application version.

## Command to upgrade

Apply exactly the configuration reviewed above:

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm \
  --namespace midaz-plugins --version 2.6.0 \
  --reset-values -f "$backup_dir/intended-values.private.yaml" \
  > "$backup_dir/upgrade.private.txt"
```

## Verify and recover

```bash
kubectl get pods --namespace midaz-plugins \
  -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments
kubectl rollout status --namespace midaz-plugins deployment/plugin-br-payments --timeout=300s
```

Validate readiness, expected images, dependencies and representative payment behavior without disclosing credentials. Do not print or decode Secret values as a verification step, and do not interpret a rendered sandbox key as proof that application 1.4.0 authenticates FakeBTG requests.

If validation fails, stop the rollout/traffic using the deployment's approved recovery procedure and assess datastore and Secret compatibility before reverting. Select the recorded pre-upgrade revision, not an assumed revision number:

```bash
helm rollback my-payments <recorded-pre-upgrade-revision> --namespace midaz-plugins
```

Rollback restores Helm-managed release resources, not database contents, external Secrets, or external side effects; hooks may have additional effects. Restore data/Secrets only through the validated private recovery procedure with writers controlled, then verify data consistency and application readiness before traffic resumes. Retain sensitive backups under the organization's protected retention policy, and remove temporary exports/previews when no longer needed. No live upgrade, backup or restore drill is claimed by this guide.
