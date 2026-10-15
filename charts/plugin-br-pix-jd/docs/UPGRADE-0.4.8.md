# Helm Upgrade from v0.4.7 to v0.4.8

## Version alignment

- Chart: `0.4.7` → `0.4.8`.
- App fallback (`Chart.appVersion`): `1.0.1` → `1.1.0`.
- Migration image default: `1.0.1` → `1.1.0`.

This is a minor release. The GHCR API, worker and migrations images all exist at
`1.1.0`. The migrations image adds one migration, `000042`, which is now the latest.

## What the application fixes

- **A payer can look up a third party's Pix key before paying it.** The new route
  `GET /v1/entries/{entryId}/lookup` (JDPI §8.2.14) resolves anyone's key into the
  recipient a payment needs, plus the end-to-end id that makes the payment one
  initiated by key. Lookups are limited per payer account (default 100 per 60
  seconds), because DICT counts every lookup against the payer and the institution.
  See [plugin-br-pix-jd#367](https://github.com/LerianStudio/plugin-br-pix-jd/issues/367).
- **An on-us payment by key credits the account DICT binds the key to.** The
  account the order names is checked against DICT before anything is held; a field
  that differs is refused naming that field
  ([plugin-br-pix-jd#314](https://github.com/LerianStudio/plugin-br-pix-jd/issues/314)).

## Access manager prerequisite

The new route is guarded by a new RBAC resource, `entries-lookup` (action `get`).
Until the access manager carries it, the route answers `403` for every caller.

The permission is added by Caradhras RBAC migration `84`. Upgrade the
`plugin-access-manager` chart to a Caradhras build that includes migration `84`
**before** upgrading this chart. The other routes are not affected.

## Database migration

`000042` seeds two runtime settings in `systemplane_entries`, namespace
`plugin-br-pix-jd.http`:

- `rate_limit.key_lookup.max` = `100`
- `rate_limit.key_lookup.window_sec` = `60`

It is idempotent (`ON CONFLICT DO NOTHING`): a value an operator already set is kept.

## Configuration changes

None. No values key is added, removed or changed, and the application reads the
same environment variables as `1.0.1`. The lookup limit is tuned through the two
runtime settings above, not through environment variables.

## Operator configuration

Merge these image pins into your existing values; they are not a complete install
configuration.

```yaml
api:
  image:
    tag: "1.1.0"
worker:
  # Keep the existing enabled flag; when enabled, use the dedicated worker image.
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.1.0"
migrations:
  image:
    tag: "1.1.0"
```

Explicit image tags in an existing values file win over chart defaults; update
them to `1.1.0`.

## Verification and rollback

Render with the target environment's values before upgrading. Verify the API image
is `1.1.0`, the enabled worker uses `plugin-br-pix-jd-worker:1.1.0`, and any
rendered migration Job uses `plugin-br-pix-jd-migrations:1.1.0`.

Rolling back to chart `0.4.7` and app `1.0.1` needs no database step: the two rows
`000042` seeds are not read by `1.0.1`. No environment deployment is performed by
this PR.
