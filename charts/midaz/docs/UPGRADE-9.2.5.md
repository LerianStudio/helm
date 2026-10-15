# Helm Upgrade from v9.2.4 to v9.2.5

## Topics

- **[Application Version Update](#application-version-update)**
  - [1. Midaz application bump to 4.0.7](#1-midaz-application-bump-to-407)
  - [2. Image tag updates](#2-image-tag-updates)
- **[Fixes](#fixes)**
  - [1. Secure PostgreSQL role creation with password hashing](#1-secure-postgresql-role-creation-with-password-hashing)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

### 1. Midaz application bump to 4.0.7

This patch release updates the Midaz application from version `4.0.5` to `4.0.7`. This is a minor patch update that includes bug fixes and stability improvements.

| Component | v9.2.4 | v9.2.5 |
|-----------|--------|--------|
| appVersion | 4.0.5 | 4.0.7 |

For detailed application-level changes, refer to the [Midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

### 2. Image tag updates

The following container image tags have been updated to align with the new application version:

| Component | v9.2.4 | v9.2.5 |
|-----------|--------|--------|
| ledger.image.tag | 4.0.5 | 4.0.7 |

**Before (v9.2.4):**

```yaml
ledger:
  image:
    tag: "4.0.5"
```

**After (v9.2.5):**

```yaml
ledger:
  image:
    tag: "4.0.7"
```

> **Note:** If you have overridden this image tag in your `values.yaml`, ensure it is updated to `4.0.7` or removed to use the chart default.

#### Operational Impact

This is a straightforward patch upgrade with no breaking changes to the application. The upgrade will:

- Pull the new container image for the `ledger` component
- Perform a rolling update of the ledger deployment
- Maintain backward compatibility with existing configurations

## Fixes

### 1. Secure PostgreSQL role creation with password hashing

The PostgreSQL bootstrap job has been enhanced to create the `midaz` database role more securely by hashing passwords client-side before transmission to the database server.

#### What changed

The bootstrap job now uses PostgreSQL's `\password` meta-command to hash the `midaz` role password inside the `psql` client. This ensures that only the password verifier (hash) is sent to the server, never the plaintext password. Additionally, the job now validates that the password does not contain carriage return or line feed characters, which would cause `\password` to fail.

| Aspect | v9.2.4 | v9.2.5 |
|--------|--------|--------|
| Password transmission | Plaintext via `CREATE ROLE ... PASSWORD` | Hashed via `\password` meta-command |
| Password validation | None | Checks for CR/LF characters before role creation |
| Transaction safety | Role created, then password set | Role and password set atomically in `BEGIN`/`COMMIT` block |

#### Why it matters

**Security improvement:**
- In v9.2.4, the plaintext password was sent to the PostgreSQL server in the `CREATE ROLE` statement, potentially exposing it in server logs if the statement failed
- In v9.2.5, the password is hashed client-side using `\password`, so the server only receives the cryptographic verifier (SCRAM-SHA-256 hash by default)
- This prevents password leakage in PostgreSQL logs, network traffic captures, or query monitoring tools

**Reliability improvement:**
- The new implementation validates that `DB_PASSWORD_MIDAZ` contains no carriage return (`\r`) or line feed (`\n`) characters before attempting role creation
- This prevents silent failures where `\password` would strip trailing CR/LF and create a role with a different password than expected
- The validation is especially important for secrets created on Windows or with `echo` commands that add trailing newlines

**Atomicity improvement:**
- The role creation and password setting now occur within a single transaction (`BEGIN`/`COMMIT`), ensuring the role is never left in a passwordless state

#### Configuration details

**Before (v9.2.4):**

The bootstrap job used `CREATE ROLE midaz LOGIN PASSWORD :'pw'` with the password passed through the `psql` environment. The implementation attempted to hide the statement from logs by setting `log_min_error_statement = panic` for superusers, but this did not prevent the plaintext password from being transmitted to the server.

**After (v9.2.5):**

The bootstrap job now:
1. Validates that `DB_PASSWORD_MIDAZ` contains no CR or LF characters
2. Creates the role without a password inside a transaction
3. Uses `\password midaz` to set the password, which hashes it client-side
4. Commits the transaction atomically

The relevant section of the bootstrap script now looks like:

```yaml
# Validation before role creation
[ "$ROLE_EXISTS" = "1" ] || [ "$(printf '%s' "$DB_PASSWORD_MIDAZ" | tr -d '\r\n')" = "$DB_PASSWORD_MIDAZ" ] || { echo "DB_PASSWORD_MIDAZ contains a carriage return or line feed (often a trailing one from a Secret made with echo or on Windows); the midaz role password must be a single line." >&2; exit 1; }

# Secure role creation with client-side password hashing
printf '%s\n' 'BEGIN;' 'CREATE ROLE midaz LOGIN;' '\password midaz' "$DB_PASSWORD_MIDAZ" "$DB_PASSWORD_MIDAZ" 'COMMIT;' | PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE"
```

#### Action required

**For most operators:** No action is required. The change only affects the initial creation of the `midaz` database role. If the role already exists (which it will in any environment that has previously run the bootstrap job), the new code path is skipped entirely.

**For new deployments or role recreation scenarios:**

If you are deploying Midaz for the first time, or if you need to recreate the `midaz` database role, ensure that your `DB_PASSWORD_MIDAZ` secret value:

1. **Does not contain trailing newlines or carriage returns**
2. **Is a single-line string**

> **Warning:** If your secret was created with a command like `echo "password" | base64` or on Windows with CRLF line endings, it may contain a trailing newline or carriage return. The bootstrap job will now fail with a clear error message instead of silently creating a role with a mismatched password.

To verify your secret does not have trailing whitespace:

```bash
kubectl get secret midaz-postgres-secret -n midaz -o jsonpath='{.data.DB_PASSWORD_MIDAZ}' | base64 -d | od -c
```

If you see `\r` or `\n` at the end, recreate the secret:

```bash
# Correct way to create the secret (no trailing newline)
kubectl create secret generic midaz-postgres-secret \
  --from-literal=DB_PASSWORD_MIDAZ='your-password-here' \
  -n midaz --dry-run=client -o yaml | kubectl apply -f -
```

Or via Helm values (recommended):

```yaml
# In your values.yaml or --set flag
global:
  postgresql:
    auth:
      password: "your-password-here"  # No trailing newline
```

> **Important:** This validation only runs when the `midaz` role does not yet exist. Existing roles are not affected, and their passwords are not changed or re-validated during the upgrade.

#### Operational Impact

- **Existing environments:** No impact. The bootstrap job detects that the `midaz` role already exists and skips creation entirely.
- **New deployments:** The bootstrap job will fail fast with a clear error message if the password secret contains invalid characters, preventing silent misconfigurations.
- **Security posture:** Improved. Passwords are no longer transmitted in plaintext to the database server during role creation.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.5 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.5 -n midaz
```
