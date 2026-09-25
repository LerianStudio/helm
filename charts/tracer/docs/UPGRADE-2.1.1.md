# Helm Upgrade from v2.1.0 to v2.1.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Secure PostgreSQL role password creation](#1-secure-postgresql-role-password-creation)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `2.1.0` to `2.1.1`. This patch release fixes a security vulnerability in the PostgreSQL bootstrap job that could expose the tracer role password in server logs and transaction history. The application version remains unchanged at `1.0.0`.

| Field | v2.1.0 | v2.1.1 |
|-------|--------|--------|
| Chart version | `2.1.0` | `2.1.1` |
| App version | `1.0.0` | `1.0.0` |

> **Important:** This release changes how the tracer database role password is set during bootstrap. The new method prevents plaintext passwords from appearing in PostgreSQL server logs or transaction history.

## Fixes

### 1. Secure PostgreSQL role password creation

The bootstrap job now uses PostgreSQL's `\password` meta-command to set the tracer role password securely. Previously, the password was passed in plaintext via a `CREATE ROLE` SQL statement, which could be logged by the PostgreSQL server or appear in `pg_stat_statements` and transaction logs.

**Security improvements:**

- The password is hashed inside the `psql` client before transmission
- The PostgreSQL server receives only the password verifier (hash), never the plaintext
- The role is created inside a transaction, preventing a window where the role exists without a password
- A validation check ensures the password does not contain carriage return or line feed characters, which would break the `\password` input format

**Before (v2.1.0):**

```yaml
echo "Creating role 'tracer'..."
PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE" -c "CREATE ROLE tracer LOGIN PASSWORD '$DB_PASSWORD_TRACER'"
```

**After (v2.1.1):**

```yaml
# \password reads the password as input lines and strips a trailing CR, so it must hold no CR or LF.
[ "$(printf '%s' "$DB_PASSWORD_TRACER" | tr -d '\r\n')" = "$DB_PASSWORD_TRACER" ] || { echo "DB_PASSWORD_TRACER contains a carriage return or line feed (often a trailing one from a Secret made with echo or on Windows); the tracer role password must be a single line." >&2; exit 1; }
echo "Creating role 'tracer'..."
# \password hashes the password inside psql, so the server only receives its
# verifier, never the plaintext; the transaction never leaves a passwordless role.
printf '%s\n' 'BEGIN;' 'CREATE ROLE tracer LOGIN;' '\password tracer' "$DB_PASSWORD_TRACER" "$DB_PASSWORD_TRACER" 'COMMIT;' | PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE"
```

**Operational impact:**

- **Existing deployments:** If the tracer role already exists, the bootstrap job skips role creation and this change has no effect. The upgrade is safe and requires no action.
- **New deployments or re-bootstrapping:** The tracer role password must not contain carriage return (`\r`) or line feed (`\n`) characters. If the password contains these characters (often from secrets created with `echo` without `-n`, or on Windows systems), the bootstrap job will fail with a clear error message.

> **Warning:** If you are using a secret management tool or script that appends a newline to secret values, ensure the tracer password is stored without trailing whitespace. Use `echo -n` or equivalent when creating secrets manually.

**Password validation:**

The bootstrap script now validates the password format before attempting to create the role:

```bash
[ "$(printf '%s' "$DB_PASSWORD_TRACER" | tr -d '\r\n')" = "$DB_PASSWORD_TRACER" ] || { echo "DB_PASSWORD_TRACER contains a carriage return or line feed (often a trailing one from a Secret made with echo or on Windows); the tracer role password must be a single line." >&2; exit 1; }
```

If this validation fails, the job will exit with status code 1 and log the error to stderr. Check the bootstrap job logs:

```bash
kubectl logs -n tracer -l job-name=tracer-bootstrap-postgres
```

**How to fix password format issues:**

If you encounter the validation error, recreate the secret without trailing newlines:

```bash
# Correct: no trailing newline
kubectl create secret generic tracer-db-secret \
  --from-literal=password="your-secure-password" \
  -n tracer --dry-run=client -o yaml | kubectl apply -f -

# Or using echo -n
echo -n "your-secure-password" | kubectl create secret generic tracer-db-secret \
  --from-file=password=/dev/stdin \
  -n tracer --dry-run=client -o yaml | kubectl apply -f -
```

Then trigger a new bootstrap job or upgrade.

## Migration Steps

This upgrade is backward-compatible and requires no configuration changes for existing deployments.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. If you are deploying to a fresh database or plan to re-run the bootstrap job, verify that your tracer password does not contain carriage return or line feed characters:

   ```bash
   # Check if the password contains CR or LF
   kubectl get secret tracer-db-secret -n tracer -o jsonpath='{.data.password}' | base64 -d | od -c
   ```

   Look for `\r` or `\n` in the output. If present, recreate the secret without trailing whitespace.

3. Apply the upgrade:

   ```bash
   helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.1 -n tracer
   ```

4. Verify the bootstrap job completes successfully (only relevant if the job runs):

   ```bash
   kubectl get jobs -n tracer -l app.kubernetes.io/name=tracer-helm
   kubectl logs -n tracer -l job-name=tracer-bootstrap-postgres --tail=50
   ```

5. Verify all pods are running and healthy:

   ```bash
   kubectl get pods -n tracer
   ```

6. Check application logs for any startup issues:

   ```bash
   kubectl logs -n tracer -l app.kubernetes.io/name=tracer-helm --tail=50
   ```

> **Note:** For existing deployments where the tracer role is already created, this upgrade only updates the bootstrap job template. The job will skip role creation and the new password-setting logic will not execute.

## Preview changes before upgrading

```bash
helm diff upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.1 -n tracer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.1 -n tracer
```
