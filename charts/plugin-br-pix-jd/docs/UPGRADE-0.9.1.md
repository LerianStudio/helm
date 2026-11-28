# Helm Upgrade from v0.9.0 to v0.9.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
  - [Image Tag Changes](#image-tag-changes)
- **[Antifraud destinations (breaking in 1.8.0)](#antifraud-destinations-breaking-in-180)**
- **[New operator routes need permissions](#new-operator-routes-need-permissions)**
- **[Database migrations](#database-migrations)**
- **[Mixed versions during the rollout](#mixed-versions-during-the-rollout)**
- **[Rolling back](#rolling-back)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The chart is a **patch release** (0.9.0 to 0.9.1): it changes no templates, configuration structure or default values beyond the image tags. The application it ships is a **minor release with a breaking change** (1.7.0 to 1.8.0): antifraud partner destinations must now be approved, or routed antifraud flows deny every call. Read [Antifraud destinations](#antifraud-destinations-breaking-in-180) before you upgrade.

| Setting | v0.9.0 | v0.9.1 |
|---------|--------|--------|
| Chart Version | 0.9.0 | 0.9.1 |
| App Version | 1.7.0 | 1.8.0 |
| API Image Tag | 1.7.0 | 1.8.0 |
| Worker Image Tag | 1.7.0 | 1.8.0 |
| Migrations Image Tag | 1.7.0 | 1.8.0 |

## Application Version Update

The upgrade updates the application container images across all three components (API, worker, and migrations) to version 1.8.0. This is a coordinated update that maintains version alignment between the application logic and database schema migrations.

### Image Tag Changes

All component image tags have been updated to `1.8.0`:

| Component | Image Repository | v0.9.0 Tag | v0.9.1 Tag |
|-----------|-----------------|------------|------------|
| API | `ghcr.io/lerianstudio/plugin-br-pix-jd` | `1.7.0` | `1.8.0` |
| Worker | `ghcr.io/lerianstudio/plugin-br-pix-jd-worker` | `1.7.0` | `1.8.0` |
| Migrations | `ghcr.io/lerianstudio/plugin-br-pix-jd-migrations` | `1.7.0` | `1.8.0` |

**Before (v0.9.0):**

```yaml
api:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    tag: "1.7.0"

worker:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.7.0"

migrations:
  image:
    tag: "1.7.0"
```

**After (v0.9.1):**

```yaml
api:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    tag: "1.8.0"

worker:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.8.0"

migrations:
  image:
    tag: "1.8.0"
```

> **Note:** If you have explicitly pinned image tags in your `values.yaml` to `1.7.0`, those overrides will prevent the automatic upgrade to `1.8.0`. Review your values file and remove or update any explicit tag pins.

> **Important:** The migrations image version must match the application version. The chart maintains this alignment by default, but if you override `api.image.tag` without updating `migrations.image.tag`, the migration Job may apply an incompatible schema version.

## Antifraud destinations (breaking in 1.8.0)

Application 1.8.0 sends an antifraud partner's credential, token, signature and headers only to destinations the installation approved. The three lists are empty by default, and an empty list approves nothing.

**Who is affected:**

- An installation where any tenant stores an antifraud route with an endpoint (`antifraud.<flow>.route`, namespace `tenant_policy`; flows `in`, `out`, `intra_out`, `intra_in`). With empty lists, saving that route returns HTTP 400 `validation_error`, and a flow that is on denies every call with cause `INVALID_CONFIG`.
- An installation with an `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` entry that holds `=` or `*`. 1.7.0 accepted it; the 1.8.0 api and worker refuse to boot.
- Not affected: every route is `{}` (the default) and no private-host entry holds `=` or `*`.

**Before you upgrade:**

1. In each tenant, find the routed flows: `GET /system/tenant_policy/antifraud.<flow>.enabled` and `GET /system/tenant_policy/antifraud.<flow>.route`.
2. Remove every `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` entry that holds `=` or `*`.
3. Approve each partner destination under `api.extraConfigmap` and `worker.extraConfigmap`, with the same values in both: both processes call the partner. The chart has no dedicated keys. 1.7.0 does not read `ANTIFRAUD_PARTNER_HOSTS` or `ANTIFRAUD_PARTNER_TOKEN_URLS`, so you can set them before the upgrade.

```yaml
api:
  extraConfigmap:
    ANTIFRAUD_PARTNER_HOSTS: "partner.example.com"
    ANTIFRAUD_PARTNER_TOKEN_URLS: "https://idp.example.com/oauth/token"
worker:
  extraConfigmap:
    ANTIFRAUD_PARTNER_HOSTS: "partner.example.com"
    ANTIFRAUD_PARTNER_TOKEN_URLS: "https://idp.example.com/oauth/token"
```

Entry formats and the full rules: [Antifraud destinations](../README.md#antifraud-destinations) in the chart README and [Antifraud partner](https://docs.lerian.studio/en/interfaces/pix-jd/pix-jd-environment-variables#antifraud-partner). Pass your values file to the upgrade (`-f`), or the lists never reach the ConfigMaps.

## New operator routes need permissions

1.8.0 adds two routes that only a person (role `editor` or `operator`) can call:

| Route | Resource | Used for |
|-------|----------|----------|
| `POST /v1/manual-reviews/{transactionId}/resolution` | `manual-reviews` / `post` | settle or revert a sent Pix left in `MANUAL_REVIEW`. Manual review is on by default |
| `POST /v1/med/refunds/{idSolDevolucao}/reserve-resolution` | `med-reserve-resolutions` / `post` | resolve a MED refund whose reserve attempt is unresolved (`409 PIX-0181`) |

With plugin auth on, a route answers `403` until the access manager carries its resource. The app publishes its own manifest only with `api.configmap.IDP_DECLARATION_ENABLED="true"` (default `"false"`). Otherwise, register both resources in the access manager before the upgrade. No Caradhras RBAC migration carries them yet.

## Database migrations

Application 1.8.0 adds migrations `000080` to `000091`. Who runs them, and when, depends on the install:

| Install | Runs the migrations | When |
|---------|---------------------|------|
| External PostgreSQL (default) | Job `plugin-br-pix-jd-migrations`, `pre-upgrade` hook | before the api and worker roll out |
| Bundled PostgreSQL (`postgresql.enabled=true`) | the same Job, `post-upgrade` hook | after the api rolls out. The 1.8.0 api returns errors on PIX routes until the Job finishes (issue #2605) |
| Multi-tenant (`MULTI_TENANT_ENABLED=true`) | the Tenant Manager, in each tenant database | the chart renders no Job |

> **Warning (large tables):** `000080` and `000082` add a `CHECK` constraint to `transaction`, and `000090` adds columns with a `CHECK` to `med_refund_request`. PostgreSQL checks every row while it holds an `ACCESS EXCLUSIVE` lock, so reads and writes on that table wait. `000083` and `000088` also build indexes on `transaction`, and `000086` copies pending feedback into a new table. The Job stops at `migrations.activeDeadlineSeconds` (default `600`). A Job stopped in the middle of a file leaves `schema_migrations` dirty, and every later run refuses until an operator runs `migrate force`. On a large `transaction` table, upgrade off-peak, raise `migrations.activeDeadlineSeconds`, and keep `--timeout` above it. The duration was not measured.

Follow the Job while it runs (with the `hook-succeeded` delete policy, it is gone once it succeeds):

```bash
kubectl -n midaz-plugins logs -f job/plugin-br-pix-jd-migrations
```

## Mixed versions during the rollout

1.8.0 moves the end of antifraud holds from the worker to the api. Upgrade the api first, and move the worker only after every api pod runs 1.8.0 (see [Command to upgrade](#command-to-upgrade)). A 1.7.0 api with a 1.8.0 worker ends no hold. While the 1.7.0 worker runs next to the 1.8.0 api, it still ends holds itself.

- Keep `antifraud.intra_out.review_window_minutes` at `0` (the value migration `000081` seeds) until every api and worker pod runs 1.8.0. A 1.7.0 worker that finds a cross-ledger internal transfer held in `FRAUD_ANALYSIS` marks it `ERROR` and does not release its reserve on the payer's ledger. The reserve stays until someone cancels it in Midaz.
- Turn on `antifraud.holds_paused`, `antifraud.in.cautelar_enabled` and `antifraud.intra_in.cautelar_enabled` only after every pod runs 1.8.0. 1.7.0 pods do not read these keys.
- Antifraud feedback that a 1.7.0 pod ends after the migrations Job ran is not in the `000086` copy, and 1.8.0 does not send it. The feedback is advisory. To send it, run the SQL of `000086_backfill_antifraud_feedback_outbox.up.sql` again within 24 h of the rollout: it skips events already queued.

## Rolling back

The chart runs `migrate up` only. It never runs the `down` files.

> **Warning:** 1.7.0 has no code for the states 1.8.0 creates. Before you roll back, set `antifraud.intra_out.review_window_minutes` to `0` and the two `cautelar_enabled` keys to `false`. Then wait until every tenant database has no row in these states:
>
> - cautelar block alive (`cautelar_status` in `AWAITING`, `UNBATCHED`, `BLOCKED`, `RETURNING`). Under 1.7.0, the Midaz hold stays past `cautelar_expires_at`, and the holder's funds stay unavailable.
> - cautelar block a MED took whose hold is not `CANCELED` (`cautelar_status = 'MED'`; read each `cautelar_hold_id` in Midaz). Re-run the effectuation under 1.8.0 until the hold is `CANCELED`: a 1.7.0 effectuation reserves the MED amount and never cancels the hold.
> - internal transfer that 1.8.0 held for review, still `PENDING` (`fraud_check->>'decideBy'` set, whatever `resolution` holds; `resolution` is absent while the analysis is open). This covers one still in `FRAUD_ANALYSIS`, one decided or expired whose reserve release failed, and a same-ledger one allowed whose commit failed. A 1.7.0 worker marks a refused one `ERROR` and parks an allowed one, and both keep the payer's reserve. A `200` with status `PENDING` from the decision, or a `204` from `expire-due`, does not prove the release.
> - sent Pix in `MANUAL_REVIEW`. 1.7.0 has no route to resolve it. No setting stops new rows from entering this state, so check it right before the rollback. 1.7.0 still settles a primary order, but never a scheduled order that JD accepted.
> - MED refund with an unresolved reserve attempt (`eff_status = 0` and `eff_status_at` set). A 1.7.0 retry reserves again.
>
> Decide or cancel open analyses and blocks, or call `POST /v1/fraud-analyses/expire-due` after their deadlines. Resolve manual reviews and reserve attempts through their routes.

- `helm rollback` to the 0.9.0 revision does not run the migrations Job (the Job has no rollback hook). 1.7.0 then runs on the 1.8.0 schema, and it ignores `ANTIFRAUD_PARTNER_HOSTS` and `ANTIFRAUD_PARTNER_TOKEN_URLS`: a route can again reach any public https host.
- `helm upgrade --version 0.9.0` (or an Argo CD sync to 0.9.0) runs the 1.7.0 migrations Job, which fails with `no migration found for version 91`, and the upgrade fails.
- Do not run the `down` files by hand after you used manual review or the cautelar block. The down of `000080` clears `pending_reason = 'MANUAL_REVIEW'` and drops `manual_review`; the down of `000082` drops the `cautelar_*` columns.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.9.1 -f <your-values>.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

With `worker.enabled=true`, upgrade in two steps so the api runs 1.8.0 before the worker does. First, keep the worker on 1.7.0 and wait for the api:

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.9.1 -f <your-values>.yaml --set worker.image.tag=1.7.0 --timeout 15m
kubectl -n midaz-plugins rollout status deployment/plugin-br-pix-jd-api
```

Then move the worker to 1.8.0 (the same command without the pin). With `worker.enabled=false`, run only this command:

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.9.1 -f <your-values>.yaml --timeout 15m
```

With Argo CD, do the same with two commits: first pin `worker.image.tag: "1.7.0"` in the values. Push the commit that removes the pin only after the sync finished and every api pod runs 1.8.0. Argo CD applies two commits that land within one poll as one sync.

> **Note:** Without `-f`, Helm reuses the stored values, so the antifraud lists and any tag-pin change above never land. With `-f`, Helm drops the stored values: repeat every `--set` and `--set-file` you used at install (signing key, certificate). Keep `--timeout` above `migrations.activeDeadlineSeconds`; the default `5m` is shorter than the Job's `600` seconds.
