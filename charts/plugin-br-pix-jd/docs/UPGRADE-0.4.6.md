# Helm Upgrade from v0.4.5 to v0.4.6

## Version alignment

- Chart: `0.4.5` → `0.4.6`.
- App fallback (`Chart.appVersion`): `2.0.1` → `1.0.0`.
- Migration image default: `2.0.0` → `1.0.0`.

**`1.0.0` is newer than `2.0.1`, even though the number is lower.** The plugin's
git tag history was reset and its release train restarted; `1.0.0` is the first
stable release of the new train. Its code is the same as the former
`4.0.0-rc.3`.

The GHCR API, worker and migrations images all exist at `1.0.0`. The migrations
image carries the schema up to `000041`; migrations `000029` to `000041` are new
since `2.0.1` and run on the first sync.

## Breaking API contracts since 2.0.1

- `POST /v1/med/credits/inbound` is removed. A MED devolução now arrives on
  `POST /v1/webhooks/refunds`.
- Pix Automático writes now require the client timestamps:
  - `POST /v1/pix-automatico/authorizations`: `createdDateTime`,
    `solicitationDateTime` and `expirationDateTime`;
  - acceptance: `authorizedAt`;
  - validation: `validatedAt`;
  - schedules with `purpose=0`: `recipientReceivedAt`.

Clients calling those routes must change before the application is upgraded.

## Configuration changes

New keys, rendered into the api and worker ConfigMaps with the app's documented
defaults:

| Key | Default | Purpose |
|---|---|---|
| `JDPI_CALL_TIMEOUT_MS` | `30000` | Timeout of one JDPI HTTP attempt. |
| `JDPI_TOTAL_TIMEOUT_MS` | `50000` | Deadline of a whole JDPI call (token, attempts, backoff). Keep it below the ingress timeout. |
| `MIDAZ_FEE_MODE` | `auto` | `auto` posts on `/v2` when the ledger reports `4.1.0`+, else `/v1`; `legacy` forces `/v1`; `native` forces `/v2`. |
| `MIDAZ_FEE_MODE_REFRESH` | `5m` | How often `auto` re-reads the ledger's `/version`. |

The chart emits `MIDAZ_FEE_MODE` and `MIDAZ_FEE_MODE_REFRESH` explicitly: the
app's loader does not apply its declared defaults, so an unset `MIDAZ_FEE_MODE`
would run as `legacy`.

New optional Courier keys, single-tenant only and emitted only when set:

- `api.configmap.COURIER_URL` — the Courier process running the `admin` role.
- `api.secrets.COURIER_CLIENT_ID` and `api.secrets.COURIER_CLIENT_SECRET`.

Without a Courier, an on-us transfer on a participant declared shared is refused
with `503 PIX-0130` instead of settling internally. In multi-tenant mode the
Courier comes from the tenant's `jd-spi` bundle and these keys are ignored.

Retired keys, no longer read by the application in either deployment mode:

| Key | Replacement (systemplane) |
|---|---|
| `MIDAZ_ORGANIZATION_ID` | `tenancy/jd_integration_binding`, field `organizationId` |
| `MIDAZ_LEDGER_ID` | `tenancy/jd_integration_binding`, field `ledgerId` |
| `MIDAZ_ASSET_ID` | `tenant_policy/midaz.asset_id` |
| `MIDAZ_EXTERNAL_ID` | `tenant_policy/midaz.external_id` |

`api.configmap.MIDAZ_ASSET_ID` is no longer required by the chart. The four keys
are emitted only when set; each one left set produces a startup WARN. Remove them
from your values after provisioning the systemplane keys. Until the systemplane
keys are filled in, postings, refunds and inbound credits are refused with
`409 PIX-0106`.

`OTEL_RESOURCE_SERVICE_VERSION` is no longer read by the application; the version
is compiled into the binary. The chart still renders it, and it has no effect.

## Operator configuration

Merge these image pins into your existing values; they are not a complete install
configuration. Keep your existing credentials, datastores and tenant settings.

```yaml
api:
  image:
    tag: "1.0.0"
worker:
  # Keep the existing enabled flag; when enabled, use the dedicated worker image.
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.0.0"
migrations:
  image:
    tag: "1.0.0"
```

Explicit image tags in an existing values file win over chart defaults. An
explicit `migrations.image.tag: "2.0.0"` left from the previous upgrade must be
replaced, or the migration Job stops at the `2.0.1` schema.

In multi-tenant mode Tenant Manager owns schema migrations; the chart's
single-tenant migration Job remains skipped. This chart update is not proof of
client-environment readiness.

## Verification and rollback

Render with the target environment's values before upgrading. Verify the API image
is `1.0.0`, the enabled worker uses the dedicated worker repository, any rendered
migration Job uses `plugin-br-pix-jd-migrations:1.0.0`, and no retired `MIDAZ_*`
key remains in the rendered ConfigMaps.

Keep the previous chart and explicit component pins for rollback. Chart rollback
does not reverse applied database migrations; assess database compatibility before
rolling back the application. No environment deployment is performed by this PR.
