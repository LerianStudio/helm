<!-- {% raw %} -->
# Upgrade Payments chart 2.6.0 to 2.7.0

## Scope and stop conditions

Chart `2.7.0` advances the default application from `1.4.0` to `1.5.0`. It adds conditional Collections configuration and `WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP`. Collections is off without the activation setting for the selected tenancy mode. That does **not** make the application upgrade a no-op: main-database migrations and pod-template changes remain relevant without Collections.

**Do not proceed without approved data-retention, migration and recovery readiness.** Application 1.5.0 introduces main migrations 000062–000070 relative to 1.4.0. Migration `000063_deprecate_chave_idempotencia` deletes the rows in the legacy `chave_idempotencia` table if present, then renames it. Its source explains that obsolete cached response bodies exceeded their retention period. This deletion is not gated by Collections. Migration `000070_add_boleto_our_number_active_v2` builds indexes without `CONCURRENTLY`; its documented SHARE lock blocks boleto writes while the indexes build.

Schedule an appropriate maintenance window and control incoming traffic and background writers. Privately record the current Helm revision, full intended configuration, workload images, database/schema versions, PVC/storage bindings and external Secret ownership/references. Require consistent protected backups of affected databases and required Secret/configuration metadata, plus an isolated tested recovery procedure. Apply retention/access controls to backups; a backup is not permission to retain expired personal data indefinitely or reintroduce it into service.

Helm rollback does not restore deleted rows, reverse external payment effects, or guarantee old application/schema compatibility. Assess those independently. Never restore legacy data under a new process that can rerun destructive migration, delete PVCs, uninstall, or regenerate credentials as a quick recovery workaround. If writer controls, migration ownership, image compatibility, backup or restore readiness are unknown, stop.

## Collections activation and database isolation

The module uses its own database and migration history. It must not share the host application's database/schema migration table. A separate database may use the same PostgreSQL server; `COLLECTIONS_POSTGRES_HOST` is not a requirement for a separate physical server.

- **Single-tenant:** a nonempty `COLLECTIONS_POSTGRES_HOST` activates Collections. Supply a different host/port/database target from the main database, a nonempty user/database name, and the required cursor key. Production additionally requires the Collections password and an accepted secure SSL mode. Explicitly verify the database is distinct even when DNS aliases differ.
- **Multi-tenant:** a nonempty `MULTI_TENANT_COLLECTIONS_POSTGRES_MODULE` names the provisioned Tenant Manager module. It is **not a boolean**; `"true"` would select a module literally named `true`. Setting only `COLLECTIONS_POSTGRES_HOST` does not activate this mode. Use explicit, distinct host and Collections module names, including `MULTI_TENANT_POSTGRES_MODULE`, and validate each tenant's database resolution and migration readiness through the approved Tenant Manager procedure. An empty host module is only warned about at boot: ambiguous databases can refuse requests, while host background paths remain unguarded. Do not use that warning as a safe configuration recipe.

The chart emits the new ConfigMap/Secret keys only when supplied; it does not provision the databases, tenant modules or partner credentials. Do not combine this upgrade with an unvalidated tenant/database cutover.

### Required secrets and process settings

`COLLECTIONS_CURSOR_HMAC_KEY` is required whenever Collections is on in either tenancy mode. It must be standard base64 encoding of **exactly 32 bytes**, not a free-form string or a URL-safe encoding. Generate and deliver it through approved private secret-management tooling; retain the intended key consistently across dependent instances. Never paste a real key into this guide, Git, logs or chat.

Single-tenant PCR credentials `COLLECTIONS_PCR_CLIENT_ID` and `COLLECTIONS_PCR_CLIENT_SECRET` must be supplied together or both omitted. Omission satisfies this pairing check, not proof of partner authorization or business-flow readiness. Preserve all other existing application, database, license and partner credentials. Use the deployment's established Secret mode: enabling an external Secret suppresses chart-generated values and requires all needed keys to be provisioned before rollout.

The following are application 1.5.0 defaults when omitted, **not recommended production tuning**. The SSL default is not accepted for a production Collections connection; configure a validated secure connection explicitly.

| Setting | App default | Enabled-module requirement |
|---|---|---|
| `COLLECTIONS_POSTGRES_PORT` | `5432` | Match provisioned target |
| `COLLECTIONS_POSTGRES_USER` | empty | Required in single-tenant |
| `COLLECTIONS_POSTGRES_DB` | `plugin-br-payments-collections` | Distinct from host database |
| `COLLECTIONS_POSTGRES_SSLMODE` | `disable` | Secure accepted mode in production |
| `COLLECTIONS_POSTGRES_MAX_OPEN_CONNS` | `10` | Review capacity |
| `COLLECTIONS_POSTGRES_MAX_IDLE_CONNS` | `5` | Review capacity |
| `COLLECTIONS_POSTGRES_PASSWORD` | empty | Required in production single-tenant |

Worker durations below are seconds, with inclusive accepted bounds. Dispatch concurrency is a count, not seconds. Process defaults also seed tenant operational defaults where applicable; review per-tenant configuration independently.

| Setting | Default | Bounds |
|---|---|---|
| `COLLECTIONS_COMMAND_RESEND_INTERVAL_SEC` | `10` | 1–3600 |
| `COLLECTIONS_COMMAND_PROCESSING_TIMEOUT_SEC` | `300` | 180–3600 |
| `COLLECTIONS_COMMAND_DISPATCH_CONCURRENCY` | `4` | 1–64 |
| `COLLECTIONS_SUBSCRIPTION_CHECK_INTERVAL_SEC` | `300` | 60–3600 |
| `COLLECTIONS_NOTICE_APPLY_INTERVAL_SEC` | `5` | 1–300 |
| `COLLECTIONS_BENEFICIARY_POLL_INTERVAL_SEC` | `30` | 5–3600 |
| `COLLECTIONS_AGREEMENT_BRANCH_SWEEP_INTERVAL_SEC` | `3600` | 60–86400 |
| `COLLECTIONS_INVENTORY_INTERVAL_SEC` | `900` | 60–86400 |
| `COLLECTIONS_ENABLEMENT_ITEM_INTERVAL_SEC` | `5` | 1–300 |
| `COLLECTIONS_TITLE_FACT_DISPATCH_INTERVAL_SEC` | `5` | 1–300 |
| `COLLECTIONS_TITLE_OUTCOME_POLL_INTERVAL_SEC` | `30` | 5–3600 |

`COLLECTIONS_DISABLED` defaults to `false`. In single-tenant, `true` refuses **new issuance** with `422 PBP-0833`; existing issuance continues. It is not a module shutdown, database disconnect or worker kill switch, and it is not the multi-tenant disablement control. Recovery requires separately approved writer/traffic controls, not this flag alone.

### Migration completion is not pod readiness

Invalid required process configuration can refuse boot. A Collections database/schema outage is different: single-tenant Collections migrations run asynchronously after license acceptance, retry failures and gate Collections paths with `503` until schema readiness. They do not gate general application readiness. Multi-tenant schema migration belongs to Tenant Manager. Therefore healthy pods do not prove Collections works.

Review the separate Collections migration set 000001–000029 before enablement. Single-tenant main-schema migrations run in the host startup path; multi-tenant schema ownership must follow Tenant Manager's deployment-specific procedure. Verify both database targets and migration trails, not merely a successful Helm command or log grep.

## Webhook HTTP acknowledgment

`WEBHOOK_PUBLIC_ALLOW_INSECURE_HTTP` defaults to `false` and concerns **this service's own** `WEBHOOK_PUBLIC_BASE_URL`, not every webhook endpoint. It is not a TLS certificate-validation bypass.

Application 1.5.0 refuses the flag when true unless `ENV_NAME` is `local`, `development` or `test` (case-insensitive). Do not interpret every non-production environment, such as staging, as allowlisted. Production retains HTTPS validation. Outside production, an HTTP public URL can already boot without this flag, with a security/future-refusal warning. In the allowed development/test environments, the flag acknowledges HTTP and changes that warning; it does not make clear-text callbacks safe. Keep production HTTPS and existing endpoint/authentication requirements intact.

## Prepare complete private values

Run operator commands from a private workspace, not a Git checkout. These examples are not evidence of a live upgrade. Adapt release/namespace names. Keep exports, manifests, diffs and Helm output private; they can contain credentials, including encoded Secret data.

```bash
set -eu
set +x
umask 077
RELEASE=my-payments
NAMESPACE=midaz-plugins
PRIVATE_DIR="$(mktemp -d "${HOME}/.payments-upgrade.XXXXXX")"
chmod 700 "$PRIVATE_DIR"
helm get values "$RELEASE" -n "$NAMESPACE" -o yaml > "$PRIVATE_DIR/current-user-values.yaml"
helm get manifest "$RELEASE" -n "$NAMESPACE" > "$PRIVATE_DIR/current-manifest.yaml"
helm history "$RELEASE" -n "$NAMESPACE" > "$PRIVATE_DIR/history.txt"
cp "$PRIVATE_DIR/current-user-values.yaml" "$PRIVATE_DIR/intended-values.yaml"
VALUES="$PRIVATE_DIR/intended-values.yaml"
```

Edit `$VALUES` privately against target defaults. It must be the **complete intended configuration**, not a Collections-only fragment. Preserve unrelated settings, database/PVC bindings, ingress, partner configuration, licenses, Secret names/keys and intentional image pins. These exports do not back up databases or external Secrets. Retain them only under the approved protected recovery/retention policy; remove temporary copies after that policy permits.

A retained `app.image.tag: "1.4.0"` keeps the older runtime and does not acquire 1.5.0 Collections behavior merely because the new chart renders its keys. Make any image-pin change explicit and independently validated. ConfigMap/Secret checksum changes roll pods across these chart versions even with retained image pins; the default Deployment strategy is RollingUpdate, not proof of zero downtime.

## Preview and upgrade with identical inputs

`--reset-values` intentionally prevents silent reuse of removed overrides. It also discards any old override omitted from `$VALUES`, so do not proceed with an incomplete fragment. Use the same complete private file for every preview and upgrade.

```bash
helm template "$RELEASE" oci://ghcr.io/lerianstudio/plugin-br-payments-helm \
  --version 2.7.0 -n "$NAMESPACE" --is-upgrade -f "$VALUES" \
  > "$PRIVATE_DIR/target-manifest.yaml"

# Optional: only with the approved helm-diff plugin already installed.
helm diff upgrade "$RELEASE" oci://ghcr.io/lerianstudio/plugin-br-payments-helm \
  --version 2.7.0 -n "$NAMESPACE" --reset-values -f "$VALUES" \
  > "$PRIVATE_DIR/upgrade.diff"
```

`helm template` has no stored release values to reset and cannot prove live Secret existence, database resolution, credentials, migrations or business compatibility. Inspect the private result for expected images, database targets, Secret references, release-scoped resource names and storage bindings. Use the public [helm-diff documentation](https://github.com/databus23/helm-diff) for the plugin; do not publish its output.

Only after approved backups, maintenance/writer controls, migration ownership and recovery readiness:

```bash
helm upgrade "$RELEASE" oci://ghcr.io/lerianstudio/plugin-br-payments-helm \
  --version 2.7.0 -n "$NAMESPACE" --reset-values -f "$VALUES" \
  > "$PRIVATE_DIR/upgrade-result.txt"
```

Verify the actual Deployment created by this release reaches its expected image and rollout state, using its private rendered name rather than a namespace-wide or guessed selector. Confirm main-schema migration completion and, when enabled, the correct Collections migration trail/schema readiness for each applicable database/tenant. Exercise approved representative existing payment and Collections workflows, partner authorization/callbacks and expected unavailable-module behavior without recording sensitive payloads. Verify relevant background processing separately; general readiness is insufficient.

If verification fails, stop further rollout and apply the pre-reviewed recovery plan with writers controlled. Assess schema/image compatibility, external effects and the retention consequences before any restore; do not assume Helm rollback restores the database or makes deleted legacy data safe to reuse.

## Verification boundary

This guide is based on chart tags `plugin-br-payments-v2.6.0` and `plugin-br-payments-v2.7.0`, their published packages with locked dependencies, and application 1.5.0 source matched to the shipped image revision. Offline renders establish emitted manifests only. No live installation, upgrade, migration, restore, partner transaction or tenant cutover is certified here.
<!-- {% endraw %} -->
