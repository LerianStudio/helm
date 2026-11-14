# Helm Upgrade from v1.5.1 to v1.6.0

## Scope and default-image limitation

`plugin-br-sisbajud-helm` 1.6.0 adds chart configuration for
`sisbajud.mensageria.permanentBlockEnabled`, default `false`, and emits
`MENSAGERIA_PERMANENT_BLOCK_ENABLED` in the application ConfigMap. It also
extends render-time permanent-switch guards and deployment notes. The Direct
switch remains `true` by default.

**This release does not provide a working new Mensageria permanent-block
switch with its default images.** Both chart versions ship executor and
migrations version 1.3.0. Their matching application source does not consume
`MENSAGERIA_PERMANENT_BLOCK_ENABLED`; emitting the variable cannot add that
behavior to the binary. Do not enable it expecting a new execution path, or
disable Direct expecting this flag to replace it. No unverified newer image
is recommended here. Custom image and companion rail compatibility require
separate validation; the chart does not pin or deploy that companion rail.

| Setting | 1.5.1 | 1.6.0 |
|---------|-------|-------|
| `sisbajud.mensageria.permanentBlockEnabled` | Not provided | `false` |
| `sisbajud.direct.permanentBlockEnabled` | `true` | `true` |
| Default application/migration version | `1.3.0` | `1.3.0` |

Keep the new flag disabled for the default images. This **incomplete overlay**
is not a complete installation configuration:

```yaml
sisbajud:
  mensageria:
    permanentBlockEnabled: false
```

## Render guards are not runtime certification

At chart 1.6.0, an enabled permanent switch requires streaming and brokers,
inbound authentication, single tenancy and a result emitter not explicitly
set to `"false"`. Mensageria additionally requires explicit streaming enablement;
its switch does not enable streaming by itself.

Relevant paths include `global.streaming.enabled`, `global.streaming.brokers`,
`global.auth.enabled`, `global.multiTenant.enabled` and
`sisbajud.direct.permanentResultEmitterEnabled`. Existing configmap overrides
can affect effective settings and must also be reviewed. A successful render
only establishes chart validation; it does not prove binary consumption,
transport/TLS/authentication readiness, supported business flows or rail
compatibility. In particular, passing these guards does not remove the default
image limitation above.

## Direct switch-off and existing court orders

Do not treat this upgrade as authorization to change Direct operation policy.
With active permanent orders, disabling
`sisbajud.direct.permanentBlockEnabled` requires retaining their maintenance
path. The shipped application checks this at startup and can refuse to boot
when the required maintenance dependencies are unavailable.

Direct-on can implicitly enable streaming. When turning Direct off, retain
**explicit** `global.streaming.enabled: true`, the intended brokers and effective
TLS/SASL configuration, inbound authentication, single tenancy and result
emitter. Preserve existing tenant and Secret references. Do not rely on the
unused Mensageria flag to keep maintenance working. Coordinate the transition
with the responsible operator and verify active-order maintenance and result
delivery through established operational checks; do not promise continuation
merely because Helm rendered successfully. The
`sisbajud_executor_permanent_active_with_switch_off` metric is a diagnostic,
not proof of end-to-end maintenance or order completion.

## Preserve configuration and prepare recovery

1. Confirm the installed chart is 1.5.1 and record effective executor/migration
   images, custom overrides and current active-order requirements. The new
   default-false key alone does not require a feature enablement migration.
2. Save values, manifests, history and previous chart/image revisions privately.
   These can contain credentials; restrict permissions and do not commit them,
   decoded Secrets or rendered manifests to Git or support messages.
3. Prepare `values-1.6.0.private.yaml` as the **complete intended configuration**.
   Reconcile target defaults with all existing settings: authentication, tenant,
   Direct policy, streaming/TLS/SASL, Mensageria endpoints/CA references, external
   stores, image pins, storage and Secret references. Preserve unrelated keys.
   Do not replace it with the short overlay above. Explicit reset removes any
   stored overrides omitted from this file.
4. Take consistent private PostgreSQL and other required persistent-data backups,
   and verify a tested recovery/cutover plan. Existing migration hooks may run
   during upgrade; inspect their effective image, settings and database target.
   No new SQL or migration-image change is claimed for this chart interval, but
   unchanged hooks are not evidence that upgrade cannot affect persistent data.

## Preview and upgrade

The examples assume release `plugin-br-sisbajud` in namespace `sisbajud`.
Substitute your actual release/namespace consistently. Keep render and diff
output private; use your approved installation of the
[helm-diff plugin](https://github.com/databus23/helm-diff) for the diff command.

```bash
umask 077
helm template plugin-br-sisbajud \
  oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  --version 1.6.0 --namespace sisbajud --is-upgrade \
  -f values-1.6.0.private.yaml > preview-1.6.0.private.yaml
helm diff upgrade plugin-br-sisbajud \
  oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  --version 1.6.0 --namespace sisbajud --reset-values \
  -f values-1.6.0.private.yaml > diff-1.6.0.private.txt
```

Review the hooks, effective non-secret switch configuration, image overrides,
Secret references, selectors, PVCs and pod-template changes before applying.
Upgrade renders of bundled datastores can require current credentials in the
private intended configuration; synthetic render placeholders are not deployment
credentials. Availability depends on actual workload strategy and readiness,
not just the chart version.

During the approved change window, after that review:

```bash
helm upgrade plugin-br-sisbajud \
  oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  --version 1.6.0 --namespace sisbajud --reset-values \
  -f values-1.6.0.private.yaml
```

## Verify and recover

Check actual release workloads, readiness, health, migration Job outcomes and
representative supported operations. Identify the ConfigMap referenced by the
release Deployment's `envFrom.configMapRef`; inspect only its non-secret
`DIRECT_PERMANENT_BLOCK_ENABLED` and `MENSAGERIA_PERMANENT_BLOCK_ENABLED` keys.
These are not explicit Deployment `env` entries, so querying that list alone
returns no evidence. Also account for explicit environment overrides when
checking effective pod configuration. ConfigMap presence still does not prove
runtime support for the unused new flag.

Verify the intended Direct policy, active-order maintenance, streaming result
delivery and retained configuration with the established runbook. If verification
fails, stop and follow the prepared recovery plan. Assess committed migration
or business effects before reverting resources. Helm rollback does not restore
databases or persistent data and can execute hooks; restore/cutover needs the
tested backup procedure and compatible application images.

Validation for this guide used exact 1.5.1/1.6.0 chart and matching default image
source revisions, documentation tests and synthetic lint/renders with exact
locked dependency versions. An enforced-offline dependency build attempt failed
on missing isolated repository configuration; no successful dependency build,
live upgrade, migration, restore or court-order maintenance test is claimed.
