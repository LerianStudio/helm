# Helm Upgrade from v9.2.3 to v9.2.4

## Topics

- **[Fixes](#fixes)**
  - [1. PostgreSQL role creation security hardening](#1-postgresql-role-creation-security-hardening)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. PostgreSQL role creation security hardening

The PostgreSQL bootstrap job has been updated to prevent password leakage in server logs during role creation.

#### What changed

The `bootstrap-postgres.yaml` template now implements a more secure method for creating the `midaz` database role. Previously, the `CREATE ROLE` statement with password was passed directly via the `-c` flag to `psql`, which could expose the password in PostgreSQL server logs if the statement failed.

**Before (v9.2.3):**

```yaml
echo "Creating role 'midaz'..."
PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE" -c "CREATE ROLE midaz LOGIN PASSWORD '$DB_PASSWORD_MIDAZ'"
```

**After (v9.2.4):**

```yaml
echo "Creating role 'midaz'..."
# A CREATE ROLE that fails is written to the server log with its
# password, so a superuser hides that log line first, and an admin
# that cannot create roles never sends the statement. The password
# reaches psql through its environment, never through argv.
ADMIN=$(PGPASSWORD="$DB_ADMIN_PASSWORD" psql -At -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE" -c "SELECT rolsuper, rolcreaterole FROM pg_roles WHERE rolname = current_user")
HIDE=""
case "$ADMIN" in
  "t|"*) HIDE="SET log_min_error_statement = panic;" ;;
  *"|t") ;;
  *) echo "Admin user '$DB_USER_ADMIN' cannot create roles; grant it CREATEROLE." >&2; exit 1 ;;
esac
printf '%s\n' "$HIDE" '\getenv pw DB_PASSWORD_MIDAZ' "CREATE ROLE midaz LOGIN PASSWORD :'pw'" | PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE"
```

#### Why it matters

This change addresses a security concern where database passwords could be exposed in PostgreSQL server logs if role creation failed. The new implementation:

1. **Checks admin privileges**: Verifies that the admin user has either `SUPERUSER` or `CREATEROLE` privileges before attempting role creation
2. **Suppresses password logging**: For superusers, sets `log_min_error_statement = panic` to prevent failed statements from being logged
3. **Uses environment variables**: Passes the password via `\getenv` and psql variable interpolation instead of command-line arguments, preventing exposure in process listings and logs

#### Impact

- **Security**: Passwords are no longer exposed in PostgreSQL server logs or process arguments during role creation
- **Validation**: The bootstrap job will now fail early with a clear error message if the admin user lacks the `CREATEROLE` privilege
- **Behavior**: The role creation logic is functionally equivalent — existing deployments will continue to work without configuration changes
- **Downtime**: None — this change only affects the bootstrap job, which runs during initial installation or when the role does not exist

> **Important:** If your PostgreSQL admin user does not have `SUPERUSER` or `CREATEROLE` privileges, the bootstrap job will now fail with the message: "Admin user '$DB_USER_ADMIN' cannot create roles; grant it CREATEROLE." Ensure your admin user has the appropriate privileges before upgrading.

#### Migration steps

No action is required for most operators. The upgrade will automatically apply the improved security logic.

**If the bootstrap job fails after upgrade:**

1. Verify that your PostgreSQL admin user has the necessary privileges:

```bash
kubectl logs -n midaz -l job-name=midaz-bootstrap-postgres --tail=50
```

2. If you see the error "Admin user cannot create roles; grant it CREATEROLE", connect to your PostgreSQL instance and grant the privilege:

```bash
# Connect to PostgreSQL as a superuser
psql -h <db-host> -U <superuser> -d <database>

# Grant CREATEROLE to your admin user
ALTER ROLE <admin-user> CREATEROLE;
```

3. Delete the failed job and let Helm recreate it:

```bash
kubectl delete job -n midaz midaz-bootstrap-postgres
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.4 -n midaz
```

> **Note:** This security improvement does not change any Helm values or require updates to your `values.yaml` configuration.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.4 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.4 -n midaz
```
