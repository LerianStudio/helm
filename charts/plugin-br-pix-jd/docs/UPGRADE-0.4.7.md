# Helm Upgrade from v0.4.6 to v0.4.7

## Version alignment

- Chart: `0.4.6` → `0.4.7`.
- App fallback (`Chart.appVersion`): `1.0.0` → `1.0.1`.
- Migration image default: `1.0.0` → `1.0.1`.

This is a patch release. The GHCR API, worker and migrations images all exist at
`1.0.1`. The migrations image carries the same schema as `1.0.0` (up to `000041`);
no migration is new.

## What the application fixes

- **A configuration value could read back stale.** Saving one runtime setting
  could make a different, unrelated setting return an older value until the next
  refresh. The application now uses `lib-systemplane` `v4.1.2`, where each setting
  keeps its own latest value.
- **The acting participant could change under a cached client (multi-tenant).**
  The ISPB a request acts on is now copied before the cached JDPI client keeps it,
  so a later request cannot alter the participant an earlier one is still using.

## Configuration changes

None. No values key is added, removed or changed, and the application reads the
same environment variables as `1.0.0`.

## Operator configuration

Merge these image pins into your existing values; they are not a complete install
configuration.

```yaml
api:
  image:
    tag: "1.0.1"
worker:
  # Keep the existing enabled flag; when enabled, use the dedicated worker image.
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.0.1"
migrations:
  image:
    tag: "1.0.1"
```

Explicit image tags in an existing values file win over chart defaults; update
them to `1.0.1`.

## Verification and rollback

Render with the target environment's values before upgrading. Verify the API image
is `1.0.1`, the enabled worker uses `plugin-br-pix-jd-worker:1.0.1`, and any
rendered migration Job uses `plugin-br-pix-jd-migrations:1.0.1`.

Rolling back to chart `0.4.6` and app `1.0.0` needs no database step: the schema
is the same. No environment deployment is performed by this PR.
