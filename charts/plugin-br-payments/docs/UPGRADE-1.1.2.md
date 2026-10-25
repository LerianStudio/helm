# Helm Upgrade from v1.1.1 to v1.1.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Secure PostgreSQL role password handling](#1-secure-postgresql-role-password-handling)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `1.1.1` to `1.1.2`. The application version remains `1.0.0-beta.9`; the chart bump to `1.1.2` is a patch release that fixes a security issue in the PostgreSQL bootstrap job. The job now validates the `plugin_br_payments` role password and uses PostgreSQL's `\password` command to hash the password client-side before transmission, ensuring the plaintext password never appears in server logs or transaction history.

No configuration changes are required. The upgrade will trigger a new bootstrap job run if the job is still present in your cluster.

## Fixes

### 1. Secure PostgreSQL role password handling

The `bootstrap-postgres` job template was updated to prevent the `plugin_br_payments` role password from being transmitted or logged in plaintext during role creation.

**Before (v1.1.1):**

```yaml
PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -v pw="$DB_PASSWORD_PLUGIN_BR_PAYMENTS" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE" -c "CREATE ROLE plugin_br_payments LOGIN PASSWORD :'pw'"
```

**After (v1.1.2):**

```yaml
[ -n "$DB_PASSWORD_PLUGIN_BR_PAYMENTS" ] && [ "$(printf '%s' "$DB_PASSWORD_PLUGIN_BR_PAYMENTS" | tr -d '\r\n')" = "$DB_PASSWORD_PLUGIN_BR_PAYMENTS" ] || { echo "DB_PASSWORD_PLUGIN_BR_PAYMENTS is empty or contains a carriage return or line feed (often a trailing one from a Secret made with echo or on Windows); the plugin_br_payments role password must be a non-empty single line." >&2; exit 1; }
# \password hashes the password inside psql, so the server only receives its
# verifier, never the plaintext; the transaction never leaves a passwordless role.
printf '%s\n' 'BEGIN;' 'CREATE ROLE plugin_br_payments LOGIN;' '\password plugin_br_payments' "$DB_PASSWORD_PLUGIN_BR_PAYMENTS" "$DB_PASSWORD_PLUGIN_BR_PAYMENTS" 'COMMIT;' | PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE"
```

#### What changed

1. **Password validation**: The job now checks that `DB_PASSWORD_PLUGIN_BR_PAYMENTS` is non-empty and does not contain carriage return (`\r`) or line feed (`\n`) characters. Secrets created with `echo` (without `-n`) or on Windows systems often have trailing newlines that break the `\password` command.

2. **Client-side hashing**: The new implementation uses PostgreSQL's `\password` meta-command, which hashes the password inside the `psql` client. The server receives only the SCRAM-SHA-256 verifier, never the plaintext password. This prevents the password from appearing in:
   - PostgreSQL server logs (even with `log_statement = 'all'`)
   - `pg_stat_activity` views
   - Replication streams
   - Point-in-time recovery archives

3. **Transactional safety**: The role creation and password assignment are wrapped in a `BEGIN; ... COMMIT;` transaction, so the role is never left in a passwordless state if the `\password` command fails.

#### Operational impact

- **Existing deployments**: If the `plugin_br_payments` role already exists, the bootstrap job skips role creation entirely. The password change logic does not run, and the upgrade has no effect on the database.

- **New deployments or role recreation**: If you delete the role and re-run the bootstrap job (or deploy to a fresh database), the job will now fail fast if the password secret contains trailing whitespace. You must ensure the secret is created correctly:

```bash
# Correct: no trailing newline
kubectl create secret generic plugin-br-payments-db-password \
  --from-literal=password="$(cat password.txt | tr -d '\r\n')" \
  -n plugin-br-payments

# Or use printf instead of echo
printf '%s' 'your-password-here' | kubectl create secret generic plugin-br-payments-db-password \
  --from-file=password=/dev/stdin \
  -n plugin-br-payments
```

> **Warning:** If your `DB_PASSWORD_PLUGIN_BR_PAYMENTS` secret was created with `echo` or `kubectl create secret --from-literal=password="$(echo ...)"`, it likely contains a trailing newline. The v1.1.2 bootstrap job will reject it with an explicit error message. Recreate the secret without the trailing newline before running the job.

> **Note:** The bootstrap job is typically a one-time operation. If your cluster already has the `plugin_br_payments` role, this change will not affect your upgrade. The new validation and hashing logic only runs when creating the role for the first time.

## Migration Steps

1. **Verify your database password secret** (only if you plan to recreate the `plugin_br_payments` role or are deploying to a new database):

```bash
kubectl get secret plugin-br-payments-db-password -n plugin-br-payments -o jsonpath='{.data.password}' | base64 -d | od -An -tx1
```

If the output ends with `0a` (line feed) or `0d` (carriage return), recreate the secret:

```bash
kubectl delete secret plugin-br-payments-db-password -n plugin-br-payments
printf '%s' 'your-password-here' | kubectl create secret generic plugin-br-payments-db-password \
  --from-file=password=/dev/stdin \
  -n plugin-br-payments
```

2. **Run the upgrade** during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. **Verify the bootstrap job** (if it runs in your environment):

```bash
kubectl get jobs -n plugin-br-payments -l app.kubernetes.io/name=plugin-br-payments-helm
kubectl logs -n plugin-br-payments -l job-name=plugin-br-payments-bootstrap-postgres --tail=50
```

If the role already exists, you should see:

```
Role 'plugin_br_payments' already exists. Skipping creation.
```

If the role is being created, you should see no password-related errors. Any validation failure will print:

```
DB_PASSWORD_PLUGIN_BR_PAYMENTS is empty or contains a carriage return or line feed (often a trailing one from a Secret made with echo or on Windows); the plugin_br_payments role password must be a non-empty single line.
```

4. **Verify application pods** are running and healthy:

```bash
kubectl get pods -n plugin-br-payments -l app.kubernetes.io/name=plugin-br-payments-helm
```

> **Important:** This upgrade does not trigger a rolling restart of application pods. Only the bootstrap job (if present and not completed) will be affected.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.2 -n plugin-br-payments
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.2 -n plugin-br-payments
```
