<!-- {% raw %} -->
# Helm Upgrade from v11.1.0 to v11.1.1

# Topics

- **[Fixes](#fixes)**
  - [1. Database Password Escaping for Special Characters](#1-database-password-escaping-for-special-characters)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Database Password Escaping for Special Characters

This patch changes the **Caradhras main server container**, not either init container. Its startup command now escapes backslashes and single quotes in `DB_PASSWORD` and encloses the password in single quotes in the PostgreSQL keyword DSN (`dataSourceName`). Spaces are preserved inside that quoted value. Double quotes, `$`, backticks and `!` are not escaped by this `sed` expression; expanding a shell variable does not re-evaluate its contents as shell commands.

In v11.1.0 the password was inserted as an unquoted DSN value. Depending on the password, whitespace or backslashes could produce a parsing error or change the password passed to the driver. Do not assume that every quote or shell metacharacter caused a failure. This patch does not change the database username, database, password itself, or server-side credentials.

The `wait-for-dependencies` and `migrate` init containers remain unchanged. `migrate` receives `POSTGRES_PASSWORD` through a Secret reference and constructs its own connection string. It runs before the main server, including when `caradhras.createDatabase` is `false`; setting that flag does not enable or disable migration. An already-created database does not bypass the main server's connection-string parsing.

The default application images are unchanged: auth and identity `3.17.0`, Caradhras and its migrator `2.1.0`. No values keys or dependency versions changed in this patch. Preserve existing license keys and registry credentials: the default Caradhras server still requires a nonempty `LICENSE_KEY`; the optional license-file mount is not a substitute for it with the default `2.1.0` image.

**Database password source (shared by the main server and migrator):**

- With bundled PostgreSQL and the default naming, the chart-kept Secret is `<release>-auth-database`, key `password`; an intentional bundled password value is `auth-database.auth.password`.
- An operator-managed `auth-database.auth.existingSecret` takes precedence and must contain key `password`.
- With PostgreSQL external/disabled and no operator database Secret, use `auth.secrets.DB_PASSWORD`, or `auth.useExistingSecret: true` with `auth.existingSecretName` naming a Secret containing `DB_PASSWORD`.
- `caradhras.secrets.DB_PASSWORD` and `caradhras.useExistingSecret` are **not** database-password sources. Caradhras's own Secret supplies license/session configuration.

Keep the existing password and Secret references for this patch. Do not decode Secrets to the terminal, paste credentials into commands or tickets, or enable shell tracing. This is not a password-rotation procedure: changing a Helm value or Secret does not itself update an existing PostgreSQL role. Coordinate any rotation separately with the database operator and all consumers. Do not claim arbitrary byte support: shell command substitution removes trailing newlines, and environment variables cannot contain NUL bytes.

**Before upgrading:**

1. Confirm the actual release name and namespace, and that the installed chart is `11.1.0`. The examples below use release `plugin-access-manager` in `midaz-plugins`; change both consistently if yours differ.
2. Take private, consistent PostgreSQL backups and preserve the release values, manifests and referenced Secrets through your approved secure backup process. Verify a restore procedure before rollout. Do not publish backup files or rendered Secrets.
3. Prepare `values-11.1.1.yaml` as the **complete intended user configuration**, not just a password fragment. Start from the authoritative configuration for the installed release and retain all intentional settings: database/Valkey endpoints and credentials or Secret references, license keys/references, image pins and pull Secrets, ingress/TLS, replicas/resources/scheduling, and application settings. Reconcile it with the target defaults. With `--reset-values`, any omitted override returns to the target default; old values are not automatically retained. Preserve credentials for existing persistent stores rather than allowing offline previews to generate replacements.
4. Keep the values file private (restrict permissions and exclude it from version control). Review the preview privately; `--suppress-secrets` reduces output exposure but does not make all rendered data non-sensitive.

**After upgrading:**

Use the Deployment name and selector from the rendered preview or installed manifest; overrides can change names. With the default names in the examples:

```bash
kubectl rollout status deployment/plugin-access-manager-caradhras -n midaz-plugins
kubectl get pods -n midaz-plugins -l 'app.kubernetes.io/name=plugin-access-manager-caradhras,app.kubernetes.io/instance=plugin-access-manager'
```

Verify both init containers complete, the main server becomes Ready, and the existing authentication/authorization smoke tests pass. If startup fails, identify the failing container from pod status before inspecting its logs through your approved private diagnostic channel. This patch does not repair unrelated migration, license, connectivity or credential failures. Never print the constructed DSN or decoded password as verification.

**Recovery:**

Stop and identify the failure before retrying. If a rollback is necessary, select the recorded known-good revision from `helm history plugin-access-manager -n midaz-plugins` and follow the tested recovery procedure. Helm rollback does not restore PostgreSQL data, external Secrets or rotated database credentials. Rolling back to `11.1.0` also restores the unquoted password DSN, so it is not a viable recovery for passwords that depend on this fix. Restore data or credentials only under the coordinated database recovery plan; do not rotate to a weaker password as a workaround.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://ghcr.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.1 --reset-values -f values-11.1.1.yaml --suppress-secrets
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://ghcr.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.1 --reset-values -f values-11.1.1.yaml --wait
```
<!-- {% endraw %} -->
