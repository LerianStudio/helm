<!-- {% raw %} -->
# Upgrade Access Manager chart 11.2.0 to 11.2.1

## Scope and prerequisites

This patch changes delivery of the `app-lerian` client credential. Chart `appVersion` remains `3.17.0`; the default Caradhras server remains `2.1.0`. It does not rotate the credential held in the existing Caradhras database.

Schedule a maintenance window: auth, identity and Caradhras pod templates change across these chart versions, including their chart-version labels. Preserve any intentional server, migrator and application image pins in your intended configuration; do not combine this chart upgrade with an unreviewed application upgrade.

Before proceeding, have a consistent private backup of the Caradhras database, the current release values and manifests, and all referenced Secrets through your approved secret-backup system. Verify the database restore procedure and retain the current release revision, image references and Secret ownership information. Helm rollback does not restore database contents or external Secrets. Do not delete PVCs, reset the database, or uninstall as an upgrade workaround.

All commands below are operator instructions, not evidence of a tested live upgrade. Adapt release and namespace names to your installation.

## Credential delivery in 11.2.1

- With `auth.useExistingSecret: false`, the chart creates a separate Secret named from the auth fullname plus `-app-client-secret`, containing `AUTHORIZER_CLIENT_SECRET` and annotated `helm.sh/resource-policy: keep`. With default names this is `<release>-auth-app-client-secret`; name overrides can change it.
- With `auth.useExistingSecret: true`, no separate app-client Secret is created. All three workloads reference key `AUTHORIZER_CLIENT_SECRET` in `auth.existingSecretName` in the release namespace. This Secret must exist before the pods start; a successful offline render does not verify its existence or keys.
- Auth and identity receive explicit `AUTHORIZER_CLIENT_SECRET` references; Caradhras receives the same key as `appLerianClientSecret`. Chart wiring alone does not prove that a particular Caradhras image consumes it.
- Remove the obsolete **values override** `identity.secrets.AUTHORIZER_CLIENT_SECRET`. Do not clear the rest of `identity.secrets`. The chart-generated identity Secret can still contain a compatibility copy when `auth.secrets.AUTHORIZER_CLIENT_SECRET` is explicitly supplied; it is incorrect to say this key is always absent from that Secret. Preserve any consumers of that copy during a move to external Secrets.
- The chart-managed value resolver prefers an explicit auth value, then a matching existing kept Secret visible through `lookup`. Only after those choices does it reject missing values for offline renders or upgrades. Do not depend on lookup for GitOps rendering.

The keep annotation is not a backup or proof that reinstall will reopen the same database. Database identity, storage retention, release naming and retained resource ownership must be checked separately. Never replace a kept credential just to make an installation render.

## Existing database: preserve the working credential

Do not generate a new credential for this upgrade. Obtain the current working `app-lerian` credential through your approved secret-management process and privately verify it matches the existing application's database state. An old Kubernetes Secret is evidence of a previous configuration, not proof of database agreement. If the credential cannot be established, stop and arrange an approved recovery or coordinated rotation; do not guess it.

Do not print decoded Secrets in a terminal, paste credentials into chat or tickets, use `--set` to pass credentials, or commit plaintext/base64 Secret data or rendered manifests to Git. Base64 is not encryption. Keep all existing Secret keys and references not explicitly migrated, including database/Redis credentials, product license keys, organization settings, directory keys and bootstrap credentials.

### Preferred GitOps/reference-only path

Use your existing approved external-secret or encrypted-secret delivery mechanism to provision an operator-managed auth environment Secret in the release namespace. It must contain the current `AUTHORIZER_CLIENT_SECRET` **and every other key your existing auth workload and configured database/Redis paths require**. Switching `auth.useExistingSecret` disables generation of the whole auth environment Secret; a Secret containing only the client credential is not a general replacement. Preserve any identity compatibility-copy consumers separately.

Edit a private **complete intended values file**, starting from the current user-supplied values and reconciling them with the target defaults. The following is an edit illustration, not a complete configuration and not a file to apply by itself:

```yaml
# MERGE these settings into your COMPLETE intended values; retain other settings.
auth:
  useExistingSecret: true
  existingSecretName: access-manager-auth-env
# Remove only identity.secrets.AUTHORIZER_CLIENT_SECRET from the old values.
# Preserve identity's existing Secret mode/name and all its other settings.
```

Replace the example Secret name with your provisioned name. Preserve existing `auth-database.auth.existingSecret`, database connection settings, Redis references, `identity.useExistingSecret` / `identity.existingSecretName`, and `caradhras.useExistingSecret` / `caradhras.existingSecretName` where configured. Do not redirect unrelated secrets into the new auth Secret inadvertently. With bundled PostgreSQL the password normally comes from the database Secret's `password` key; external-database configurations can use the auth environment Secret's `DB_PASSWORD` key. Inspect the rendered references for your specific configuration.

Commit only non-sensitive references/configuration, or encrypted resources handled by your approved deployment system. Configure ordering so required external Secrets are available before application rollout. Retain every required non-client key in existing external identity Secrets. The explicit identity environment reference selects the auth Secret for this credential; removing a redundant key from another Secret is not required to make that reference work and can break another consumer.

External Secret value changes do **not** by themselves change the checksum based on `auth.secrets.AUTHORIZER_CLIENT_SECRET`. Do not rely on that checksum for externally managed rotation; use your established controlled rollout mechanism. Rotation of the database credential and dependent clients is a separate coordinated operation, not a values-only edit.

### Alternative: privately supplied chart-managed value

If you retain chart-managed Secrets, set `auth.secrets.AUTHORIZER_CLIENT_SECRET` to the current credential only in your private complete intended values file or approved decrypted deployment input. Remove only the obsolete identity override. Keep every unrelated setting intact; do not paste an example containing empty passwords or license keys over your configuration.

Helm release records and rendered output can contain sensitive data in this mode. Protect their storage/access and keep backups, diffs and render artifacts private. A private local file is not permission to put the credential into Git.

## Fresh installs: do not assume the shipped default can seed a new credential

The shipped Caradhras `2.1.0` does not consume `appLerianClientSecret` in its application-seeding path. Supplying an arbitrary generated value, whether in values or an external Secret, does not establish that the seeded database application has the same credential. A no-action default installation is not a supported recipe for generated-secret seeding.

The chart's automatic-generation branch requires a semver server tag `>=2.4.0-beta.4`, cluster Secret lookup capability, no reusable kept value, and a fresh install rather than an upgrade. Offline/client renders cannot demonstrate this branch. The `2.4.0-beta.4` seed source reads `appLerianClientSecret` for `admin/app-lerian`, but that source fact is **not** a full compatibility, migration or production-readiness certification for that prerelease or every numerically newer image.

This guide therefore does not prescribe a server-image jump as a chart migration workaround. For a fresh database, stop until an independently approved server/migrator combination and validated seeding/bootstrap runbook establish matching credentials. Do not use an unverified tag solely to satisfy the chart's version check.

Preserve the deployed images' licensing prerequisites. In particular the default Caradhras `2.1.0` release requires a nonempty `LICENSE_KEY` for product `caradhras`; a chart-accepted license-file mount alone does not satisfy that runtime prerequisite. Preserve auth and identity licensing separately.

## Prepare private complete values and preview

Run from an approved private workspace outside any Git checkout; disable shell tracing. The export can contain credentials. Set release and namespace to your actual deployment. `helm get values` is a starting point, not a complete intended configuration until reviewed against target defaults and all required Secret references.

```bash
set -eu
set +x
umask 077
RELEASE=plugin-access-manager
NAMESPACE=midaz-plugins
PRIVATE_DIR="$(mktemp -d "${HOME}/.access-manager-upgrade.XXXXXX")"
chmod 700 "$PRIVATE_DIR"
helm get values "$RELEASE" -n "$NAMESPACE" -o yaml > "$PRIVATE_DIR/current-user-values.yaml"
helm get manifest "$RELEASE" -n "$NAMESPACE" > "$PRIVATE_DIR/current-manifest.yaml"
helm history "$RELEASE" -n "$NAMESPACE" > "$PRIVATE_DIR/history.txt"
cp "$PRIVATE_DIR/current-user-values.yaml" "$PRIVATE_DIR/intended-values.yaml"
VALUES="$PRIVATE_DIR/intended-values.yaml"
```

Now edit `$VALUES` privately as described above and verify that it is the complete intended configuration. Back up the database and Secrets using your established backup system; the three exports above do not back them up. Do not proceed while credential agreement, backups or any required license/Secret key is unresolved.

Use **the same complete intended file** and reset semantics for every preview and upgrade. `--reset-values` is deliberate: removed legacy overrides must not be silently reused. It also discards old overrides you forgot to include, so a short migration fragment is unsafe.

```bash
helm template "$RELEASE" oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 11.2.1 -n "$NAMESPACE" --is-upgrade \
  -f "$VALUES" > "$PRIVATE_DIR/target-manifest.yaml"

# Optional, if the approved helm-diff plugin is already installed:
helm diff upgrade "$RELEASE" oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 11.2.1 -n "$NAMESPACE" --reset-values -f "$VALUES" \
  > "$PRIVATE_DIR/upgrade.diff"
```

`helm template` has no stored release values to reset; it uses target defaults plus this file and cannot prove live lookup/adoption. Inspect private output for the expected Secret names/keys, images, persistent-storage bindings, ingress/configuration and all three workloads' credential references. Do not publish diffs or manifests; they may contain encoded credentials. Rendering an existing-Secret reference cannot prove database agreement, startup readiness, secret existence or compatibility-copy consumers.

## Upgrade and verify

After private review and approved backup/recovery readiness:

```bash
helm upgrade "$RELEASE" oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 11.2.1 -n "$NAMESPACE" --reset-values -f "$VALUES" \
  > "$PRIVATE_DIR/upgrade-result.txt"
```

Check the actual auth, identity and Caradhras Deployments created by this release for successful rollout; use their rendered names rather than an assumed label selector. Verify application readiness, existing login and a representative existing machine-client authentication/authorization flow through your approved smoke tests without logging credentials or tokens. A Helm command exit status alone does not demonstrate authentication works.

If verification fails, stop further rollout and use the pre-reviewed recovery plan. A Helm rollback alone neither restores database state nor reverts external/kept Secrets. Keep the database application credential, restored Secret contents and all dependent clients consistent; do not regenerate a credential, delete a kept Secret or restore only one side as a quick fix. Any actual rotation requires a separately validated, version-specific authorization and coordinated dependent-client rollout procedure.

## Verification boundary

The release-source comparison and local synthetic renders support chart wiring and the source-specific caveats above. They are not a live install, upgrade, credential rotation, kept-Secret adoption test, database backup/restore drill or application compatibility certification. Passing documentation checks does not remove these operational prerequisites.
<!-- {% endraw %} -->
