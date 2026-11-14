# Helm Upgrade from v11.2.2 to v11.2.3

## What changes

Chart 11.2.3 adds `ALLOW_INSECURE_TLS` to the `migrate` init container in the Caradhras Deployment. It comes from the Caradhras ConfigMap, controlled by `caradhras.allowInsecureTLS` (default: `true`). The init container already receives `POSTGRES_SSLMODE` from the auth ConfigMap key `DB_SSLMODE`.

This is a chart environment-wiring change, not a migration-image update. Auth and identity remain at `3.19.0`; Caradhras and its migrations image remain at `2.1.0`. There is no new SQL migration or dependency-version change in this chart patch.

**Do not interpret the extra environment variable as proof of a runtime migration fix.** The default `2.1.0` migrator builds its PostgreSQL DSN and connects directly through pgx; it does not read `ALLOW_INSECURE_TLS` or gate `sslmode=disable` on that flag. Both chart versions ship that same image. A different overridden image must be validated separately. In particular, this patch alone does not establish that a previously failing migration now succeeds or that every component has the same TLS policy.

## Correct configuration paths

The following are partial examples, not complete upgrade values files. Merge the intended settings into your complete configuration.

For a TLS-capable external PostgreSQL deployment:

```yaml
auth:
  configmap:
    DB_SSLMODE: "require"
caradhras:
  allowInsecureTLS: false
```

`require` encrypts the PostgreSQL connection; use CA/hostname verification settings supported by your deployment when required. Confirm the actual rendered settings and connectivity before rollout. Do not describe chart defaults as secure: `auth.configmap.DB_SSLMODE` defaults to `disable`, and `caradhras.allowInsecureTLS` defaults to `true`.

For an isolated development/test database without TLS only:

```yaml
auth:
  configmap:
    DB_SSLMODE: "disable"
caradhras:
  allowInsecureTLS: true
```

Do not use `auth.secrets.DB_SSLMODE` or `caradhras.config.ALLOW_INSECURE_TLS`: those paths do not configure these rendered settings. Auth and identity have separate `configmap.ALLOW_INSECURE_TLS` settings; a Caradhras setting is not a global security switch. Check Redis TLS and every relevant component's configuration before removing an insecurity waiver. Never disable transport security merely to work around an unexplained production connection failure.

## Prepare and preserve the release

1. Record the installed Helm revision and capture the current values and manifest in a private directory. These outputs can contain credentials: never commit, publish or paste them.

   ```bash
   umask 077
   mkdir -p private-upgrade-backup
   helm history plugin-access-manager -n midaz-plugins > private-upgrade-backup/history.txt
   helm get values plugin-access-manager -n midaz-plugins -o yaml > private-upgrade-backup/values.yaml
   helm get manifest plugin-access-manager -n midaz-plugins > private-upgrade-backup/manifest.yaml
   ```

2. Prepare `values-11.2.3.yaml` as the **complete intended configuration**, using the saved overrides and target defaults. Preserve unrelated settings, endpoints, image pins, storage, application-client credentials, license-file references and existing Secret names/references. Correct unused paths rather than retaining both forms. Do not replace existing credentials or use one of the partial snippets above as this file.
3. Take a consistent PostgreSQL backup using your database runbook and verify the corresponding restore procedure before upgrading. Preserve credential/Secret references privately. Replacement Caradhras pods run the unchanged, up-only migrator init container; an unchanged image is not proof that it will perform no database work on your schema. Review the rendered rollout and migration configuration for your actual deployment.
4. Validate the TLS settings and migration behavior with the exact selected images in staging. No live upgrade, migration, rollback or restore is demonstrated by this guide's source/render checks.

## Preview and upgrade

Both commands deliberately reset stored Helm overrides and apply the same complete file. `--reset-values` with a partial file would discard unrelated configuration. Review all changes, including datastore, Secret and storage references, before proceeding.

The preview requires the [helm-diff plugin](https://github.com/databus23/helm-diff).

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.3 --reset-values -f values-11.2.3.yaml
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.3 --reset-values -f values-11.2.3.yaml --wait --timeout 10m
```

## Verify and recover

Discover the actual Deployment names from the rendered manifest; do not assume a release-name-independent selector. Check rollout/readiness and the `migrate` init-container result/logs privately. Test authentication, token issuance and representative allowed/denied authorization requests using your approved smoke-test procedure. Redact logs before sharing them.

If rollback is needed, replace `PREVIOUS_REVISION` with the recorded installed revision:

```bash
helm rollback plugin-access-manager PREVIOUS_REVISION -n midaz-plugins --wait --timeout 10m
```

Helm rollback restores Kubernetes release configuration, **not database contents or schema**. Check compatibility with database writes and migrations already applied before rolling back. If restoration is necessary, stop the rollout and follow the reviewed database restore/cutover procedure; do not assume an application rollback reverses an up-only migration.
