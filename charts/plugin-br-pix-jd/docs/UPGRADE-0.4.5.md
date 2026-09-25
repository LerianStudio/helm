# Helm Upgrade from v0.4.4 to v0.4.5

## Version alignment

- Chart: `0.4.4` → `0.4.5`.
- App fallback (`Chart.appVersion`): `1.13.0-beta.4` → `2.0.1`.
- Migration image default: empty (appVersion fallback) → explicit `2.0.0`.

The GHCR API and worker images exist at `2.0.1`. The migrations image exists at
`2.0.0`, not `2.0.1`. The application diff from `v2.0.0` to `v2.0.1` contains no
changes to migration sources or the migrations image build; that release's
migration build was skipped. Keeping the migration tag independent prevents an
ImagePullBackOff in the migration hook.

## Operator configuration

Merge these image pins into your existing values; they are not a complete install
configuration. Keep your existing credentials, datastores and tenant settings.

```yaml
api:
  image:
    tag: "2.0.1"
worker:
  # Keep the existing enabled flag; when enabled, use the dedicated worker image.
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "2.0.1"
migrations:
  image:
    tag: "2.0.0"
```

Explicit image tags in an existing values file win over chart defaults. Remove or
replace an explicit empty `migrations.image.tag`: an empty string restores the
appVersion fallback and requests the nonexistent migrations `2.0.1` image.

This chart update does not configure multi-ledger catalogs, CRM account ledger
bindings or transaction routes, and is not proof of client-environment readiness.
If the application is still on the old 1.x beta default, validate the application
2.x upgrade separately before rollout. In multi-tenant mode Tenant Manager owns
schema migrations; the chart's single-tenant migration Job remains skipped.

## Verification and rollback

Render with the target environment's values before upgrading. Verify the API image
is `2.0.1`, the enabled worker uses the dedicated worker repository, and any rendered
migration Job uses `plugin-br-pix-jd-migrations:2.0.0`.

Keep the previous chart and explicit component pins for rollback. Chart rollback
does not reverse applied database migrations; assess database compatibility before
rolling back the application. No environment deployment is performed by this PR.
