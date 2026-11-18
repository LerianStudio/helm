<!-- {% raw %} -->
# Helm Upgrade from v2.7.0 to v2.7.1

## Scope and operational prerequisites

Chart `2.7.1` changes `appVersion` and the default `app.image.tag` from `1.5.0` to `1.5.1`; templates, values schema and dependency lock are unchanged. This is not a guarantee of application compatibility or a no-action upgrade. Application 1.5.1 changes provider authorization recovery, including the TokenProvider-backed 401 refresh path. Validate representative provider payment and boleto requests, token expiry/401 recovery, webhook subscription health and background processing in your approved test environment before rollout.

Preserve all existing application, partner, tenant, database, license and Secret settings. Review retained image pins explicitly: `app.image.tag: "1.5.0"` keeps the older executable. Remove or update that pin in the **complete intended values** only when adopting 1.5.1 is approved. The default application image is `ghcr.io/lerianstudio/plugin-br-payments:1.5.1`.

The application Deployment uses RollingUpdate. Its ConfigMap/Secret checksums change across these chart releases even with an unchanged application image pin, so schedule and monitor the restart. With identical retained values/pins, the bundled PostgreSQL primary and replica pod templates are unchanged. The conditional multi-tenant control-plane migration Job is separate from the application Deployment and uses the same application image selection; review its hooks and license/Secret prerequisites when enabled. No zero-downtime guarantee follows from rendering or a Helm success.

## Data, licensing and recovery

The application 1.5.0-to-1.5.1 source comparison introduces no SQL migration files. Existing migration/startup obligations still apply to databases that have not reached the expected schema. Do not use this patch guide as a shortcut for upgrading from an older application/schema. In particular, main migration `000063` deletes legacy idempotency rows and `000070` builds lock-sensitive indexes; these are inherited from 1.5.0, not introduced by 1.5.1, and are not gated by Collections enablement.

Keep the established license source. For both application versions, a nonempty `LICENSE_FILE_PATH` selects the signed file ahead of `LICENSE_KEY`; the conditional `/controlplane-migrate` executable also checks the license before migration. A staged file must be valid; chart mounts alone do not establish acceptance. Keep production TLS, required credentials, provider endpoints and Collections database/module isolation intact. General readiness does not prove asynchronous Collections migrations or business flows are ready.

Before upgrading, approve a maintenance/writer-control plan, consistent protected database backups, configuration/Secret-reference records and a tested isolated recovery procedure. Helm rollback does not restore deleted data, undo external payment effects or establish old-image/schema compatibility. Stop if migration ownership, backup/restore readiness or runtime compatibility is unknown; do not delete PVCs, regenerate credentials or blindly restore data under a process that may rerun migrations.

## Prepare complete private values

Run from a private workspace, not a Git checkout. Adapt the release and namespace. Exports, renders, logs and diffs may contain credentials or sensitive payment data: keep them private under your approved access/retention controls and never print decoded Secrets.

```bash
set -eu
set +x
umask 077
RELEASE='my-payments'
NAMESPACE='midaz-plugins'
PRIVATE_DIR="$(mktemp -d "${HOME}/.payments-upgrade.XXXXXX")"
helm get values "$RELEASE" -n "$NAMESPACE" -o yaml > "$PRIVATE_DIR/current-user-values.yaml"
helm get manifest "$RELEASE" -n "$NAMESPACE" > "$PRIVATE_DIR/current-manifest.yaml"
helm history "$RELEASE" -n "$NAMESPACE" > "$PRIVATE_DIR/history.txt"
cp "$PRIVATE_DIR/current-user-values.yaml" "$PRIVATE_DIR/intended-values.yaml"
VALUES="$PRIVATE_DIR/intended-values.yaml"
```

Review/edit `$VALUES` against the target defaults. It must preserve **all intended overrides**, including unrelated resource, ingress, datastore/PVC, tenant, partner, license and externally managed Secret references, not merely an image-tag fragment. These Helm exports are not database or external-Secret backups. If multiple overlays are required, use the same complete ordered `-f` list everywhere below. `--reset-values` discards stored overrides omitted from the intended file and prevents silent reuse of deliberately removed overrides.

## Preview changes before upgrading

```bash
helm template "$RELEASE" oci://ghcr.io/lerianstudio/plugin-br-payments-helm \
  --namespace "$NAMESPACE" --version 2.7.1 --is-upgrade -f "$VALUES" \
  > "$PRIVATE_DIR/target-manifest.yaml"

# Optional: requires an independently reviewed helm-diff installation.
helm diff upgrade "$RELEASE" oci://ghcr.io/lerianstudio/plugin-br-payments-helm \
  --namespace "$NAMESPACE" --version 2.7.1 --reset-values -f "$VALUES" \
  > "$PRIVATE_DIR/upgrade.diff"
```

See the public [helm-diff documentation](https://github.com/databus23/helm-diff). Inspect the private render/diff for expected images, Secret references, datastore targets, storage bindings, workload names and hooks. Client rendering cannot establish live Secret existence or faithfully resolve cluster `lookup`; bundled database previews may need the current passwords supplied through protected values/Secret tooling, never CLI `--set` or decoded-Secret diagnostics. Use an approved server-side preview where cluster lookup is required. Rendering does not test startup, migrations or provider behavior.

## Command to upgrade

Only after operational approval and recovery readiness:

```bash
helm upgrade "$RELEASE" oci://ghcr.io/lerianstudio/plugin-br-payments-helm \
  --namespace "$NAMESPACE" --version 2.7.1 --reset-values -f "$VALUES" \
  > "$PRIVATE_DIR/upgrade-result.txt"
```

## Verify the release

Discover the actual Deployment name from the release-scoped inventory and compare it with the private rendered manifest; naming overrides can change it. The application label is `plugin-br-payments`, **not** the chart package name `plugin-br-payments-helm`.

```bash
kubectl get deployments -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE"
DEPLOYMENT='plugin-br-payments' # replace with the actual rendered Deployment name
kubectl rollout status "deployment/$DEPLOYMENT" -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[*].image}{"\n"}'
kubectl logs -n "$NAMESPACE" "deployment/$DEPLOYMENT" --all-pods=true --tail=50 \
  > "$PRIVATE_DIR/application-logs.txt"
```

Without an intentional override, expect `ghcr.io/lerianstudio/plugin-br-payments:1.5.1` for the application container. Check every rendered workload and conditional Job, not only the first container or pod. Verify main-schema readiness, the applicable Collections schema/tenant migration trails, license acceptance, provider authorization recovery and representative approved payment/boleto/webhook workflows; monitor relevant background processing separately. Healthy pods alone are insufficient. If verification fails, control writers/traffic and follow the reviewed recovery plan rather than assuming `helm rollback` restores data.

## Verification boundary

Offline comparison of the published 2.7.0/2.7.1 packages with identical synthetic values and embedded locked dependencies establishes chart output only. Application 1.5.1 source was matched to the public amd64 image revision. This guide does not certify a live installation/upgrade, server preview, application boot, database migration, provider transaction, helm-diff run or backup/restore.
<!-- {% endraw %} -->
