# Helm Upgrade from v2.3.0 to v2.3.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. MongoDB Authentication Database Correction](#1-mongodb-authentication-database-correction)
  - [2. PostgreSQL Migrations for Bundled Subchart](#2-postgresql-migrations-for-bundled-subchart)
  - [3. MongoDB URI Authentication Source](#3-mongodb-uri-authentication-source)
- **[Configuration Reference](#configuration-reference)**
  - [Modified MongoDB Settings](#modified-mongodb-settings)
  - [New Template Helpers](#new-template-helpers)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review MongoDB Database Configuration](#step-1-review-mongodb-database-configuration)
  - [Step 2: Verify PostgreSQL Migration Strategy](#step-2-verify-postgresql-migration-strategy)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.3.1 is a patch release that fixes three critical issues related to database configuration and migrations. The release corrects the default MongoDB authentication database to match the application's expected database name, refactors PostgreSQL migrations to support bundled subchart deployments via initContainers, and fixes the MongoDB URI authentication source to use the correct database. These changes ensure proper database connectivity for both bundled and external infrastructure scenarios.

No breaking changes are introduced. Operators using default MongoDB settings should review the database name change to ensure alignment with their deployment.

## Fixes

### 1. MongoDB Authentication Database Correction

**What changed:**  
The default MongoDB authentication database in `mongodb.auth.databases[0]` has been corrected from `plugin_br_bank_transfer_jd` to `plugin_br_bank_transfer`.

**Before (v2.3.0):**

| Setting | Value |
|---------|-------|
| `mongodb.auth.databases[0]` | `plugin_br_bank_transfer_jd` |
| `bankTransfer.configmap.MONGO_DATABASE` | `plugin_br_bank_transfer` (default) |

**After (v2.3.1):**

| Setting | Value |
|---------|-------|
| `mongodb.auth.databases[0]` | `plugin_br_bank_transfer` |
| `bankTransfer.configmap.MONGO_DATABASE` | `plugin_br_bank_transfer` (default) |

**Why it matters:**  
The bundled MongoDB subchart creates the application user (`mongodb.auth.usernames[0]`, default `bank_transfer`) in the database specified by `mongodb.auth.databases[0]`. The application authenticates against this database (the `authSource` in the MongoDB URI). The previous default (`plugin_br_bank_transfer_jd`) did not match the application's expected database name (`MONGO_DATABASE`, default `plugin_br_bank_transfer`), causing authentication failures when using the bundled subchart with default settings.

**Operational impact:**  
- **New deployments:** The corrected default ensures the subchart creates the user in the correct database
- **Existing deployments with bundled MongoDB:** If you deployed v2.3.0 with the default `mongodb.auth.databases[0]` value, your MongoDB instance has a user in the `plugin_br_bank_transfer_jd` database. Upgrading to v2.3.1 will change the default to `plugin_br_bank_transfer`, but your existing MongoDB StatefulSet will not automatically migrate the user. See [Step 1: Review MongoDB Database Configuration](#step-1-review-mongodb-database-configuration) for migration options
- **Existing deployments with external MongoDB:** No impact — external MongoDB configuration is managed outside the chart

**values.yaml diff:**

```yaml
# v2.3.0
mongodb:
  auth:
    databases:
      - "plugin_br_bank_transfer_jd"

# v2.3.1
mongodb:
  auth:
    # The subchart creates bank_transfer in this database and the app authenticates against it:
    # keep it equal to bankTransfer.configmap.MONGO_DATABASE (default plugin_br_bank_transfer).
    databases:
      - "plugin_br_bank_transfer"
```

### 2. PostgreSQL Migrations for Bundled Subchart

**What changed:**  
PostgreSQL migrations now run as an initContainer in the application Deployment when using the bundled PostgreSQL subchart (`postgresql.enabled=true` and `postgresql.external=false`). Previously, migrations always ran as a pre-install/pre-upgrade hook Job, which caused deadlocks when the bundled subchart was enabled (the hook waited for PostgreSQL to be ready, but PostgreSQL was created in the same Helm sync phase).

**Before (v2.3.0):**

```yaml
# templates/migrations.yaml — always a hook Job
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "argocd.argoproj.io/hook": PreSync
```

**After (v2.3.1):**

```yaml
# templates/migrations.yaml — hook Job only for external PostgreSQL
{{- if ne (include "bank-transfer.postgresInternal" .) "true" }}
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "argocd.argoproj.io/hook": PreSync
{{- end }}

# templates/deployment.yaml — initContainer for bundled PostgreSQL
{{- if and (eq (include "bank-transfer.postgresInternal" .) "true") (eq (lower (toString .Values.bankTransfer.migrations.enabled)) "true") }}
{{- include "bank-transfer.migrationsContainer" . | nindent 8 }}
{{- end }}
```

**Why it matters:**  
- **Bundled PostgreSQL:** The subchart StatefulSet is created during the Sync phase. A pre-install/pre-upgrade hook runs before Sync and would wait indefinitely for PostgreSQL to exist. Running migrations as an initContainer ensures each application pod waits for its own database to be ready before starting, and golang-migrate's locking prevents concurrent migration conflicts
- **External PostgreSQL:** The database already exists before the Helm release is applied. The pre-install/pre-upgrade hook Job runs migrations before the application Deployment rolls out, ensuring schema-first upgrades

**Operational impact:**  
- **Bundled PostgreSQL deployments:** Migrations now run as an initContainer in every application pod. The first pod to acquire the migration lock will apply schema changes; subsequent pods will see the lock and wait or skip (golang-migrate behavior). Application pods will not become Ready until migrations complete
- **External PostgreSQL deployments:** No change — migrations continue to run as a hook Job before the application rolls out
- **Migration Secret:** When using bundled PostgreSQL, the chart no longer creates a separate migration-only Secret (`<release>-migrations`). The initContainer reads the PostgreSQL password directly from the subchart Secret (`<release>-postgresql`)

**New template helper:**

The chart introduces a new helper template `bank-transfer.postgresInternal` to determine whether the bundled subchart is enabled:

```yaml
{{- define "bank-transfer.postgresInternal" -}}
{{- $pg := default dict .Values.postgresql -}}
{{- and (eq (lower (toString $pg.enabled)) "true") (ne (lower (toString $pg.external)) "true") -}}
{{- end }}
```

This helper is used throughout the templates to conditionally render migration resources.

**Migration container definition:**

The migration logic has been extracted into a reusable template helper `bank-transfer.migrationsContainer` (defined in `templates/migrations.yaml`) that is included by both the hook Job (external path) and the Deployment initContainer (bundled path). The container spec is identical in both cases.

### 3. MongoDB URI Authentication Source

**What changed:**  
The MongoDB URI template now uses the correct `authSource` when connecting to the bundled MongoDB subchart. Previously, the URI hardcoded `authSource=admin`; it now uses `mongodb.auth.databases[0]` (the database where the subchart creates the application user).

**Before (v2.3.0):**

```yaml
# templates/_helpers.tpl
- name: MONGO_URI
  value: {{ printf "mongodb://bank_transfer:$(MONGO_PASSWORD)@%s.%s.svc.cluster.local:27017/?authSource=admin" $mongoFullname $ns | quote }}
```

**After (v2.3.1):**

```yaml
# templates/_helpers.tpl
- name: MONGO_URI
  value: {{ printf "mongodb://%s:$(MONGO_PASSWORD)@%s.%s.svc.cluster.local:27017/?authSource=%s" (first $mongoAuth.usernames) $mongoFullname $ns (first $mongoAuth.databases) | quote }}
```

**Why it matters:**  
The MongoDB URI must specify the correct `authSource` (the database where the user's credentials are stored). The bundled subchart creates the application user in `mongodb.auth.databases[0]`, not in the `admin` database. Using `authSource=admin` caused authentication failures when the user was created in a different database.

**Operational impact:**  
- **Bundled MongoDB deployments:** The URI now correctly references `mongodb.auth.databases[0]` as the `authSource`, ensuring successful authentication
- **External MongoDB deployments:** No impact — external MongoDB URIs are typically provided via `bankTransfer.secrets.MONGO_URI` and are not affected by this template change

**Additional change:**  
The URI template now uses `(first $mongoAuth.usernames)` instead of the hardcoded `bank_transfer` username, making it consistent with the subchart's `mongodb.auth.usernames[0]` configuration.

## Configuration Reference

### Modified MongoDB Settings

| Setting | v2.3.0 Default | v2.3.1 Default | Description |
|---------|----------------|----------------|-------------|
| `mongodb.auth.databases[0]` | `plugin_br_bank_transfer_jd` | `plugin_br_bank_transfer` | Database where the subchart creates the application user; must match `bankTransfer.configmap.MONGO_DATABASE` |

**Recommended configuration:**

```yaml
mongodb:
  auth:
    usernames:
      - "bank_transfer"
    passwords:
      - ""  # Supply via values override or existingSecret
    databases:
      - "plugin_br_bank_transfer"  # Must match bankTransfer.configmap.MONGO_DATABASE

bankTransfer:
  configmap:
    MONGO_DATABASE: "plugin_br_bank_transfer"  # Default; must match mongodb.auth.databases[0]
```

### New Template Helpers

| Helper | Purpose |
|--------|---------|
| `bank-transfer.postgresInternal` | Returns `true` when the bundled PostgreSQL subchart is enabled (`postgresql.enabled=true` and `postgresql.external!=true`) |
| `bank-transfer.migrationsContainer` | Emits the PostgreSQL migrations container spec (used by both the hook Job and the Deployment initContainer) |

## Migration Steps

### Step 1: Review MongoDB Database Configuration

If you are using the bundled MongoDB subchart (`mongodb.enabled=true`) and deployed v2.3.0 with default settings, your MongoDB instance has a user in the `plugin_br_bank_transfer_jd` database. You have two options:

#### Option 1: Keep existing database name (no migration required)

Override the default to match your existing deployment:

```yaml
mongodb:
  auth:
    databases:
      - "plugin_br_bank_transfer_jd"

bankTransfer:
  configmap:
    MONGO_DATABASE: "plugin_br_bank_transfer_jd"
```

Add this to your `values-override.yaml` and upgrade normally. The chart will continue to use your existing database.

#### Option 2: Migrate to the corrected database name

If you want to align with the corrected default (`plugin_br_bank_transfer`), you must manually migrate your MongoDB data:

1. **Backup your existing database:**

```bash
kubectl exec -n plugin-br-bank-transfer <mongodb-pod-name> -- mongodump --authenticationDatabase=plugin_br_bank_transfer_jd --username=bank_transfer --password=<password> --db=plugin_br_bank_transfer_jd --archive=/tmp/backup.archive
```

2. **Create the new database and user:**

```bash
kubectl exec -n plugin-br-bank-transfer <mongodb-pod-name> -- mongosh --eval '
  use plugin_br_bank_transfer;
  db.createUser({
    user: "bank_transfer",
    pwd: "<password>",
    roles: [{ role: "readWrite", db: "plugin_br_bank_transfer" }]
  });
'
```

3. **Restore data to the new database:**

```bash
kubectl exec -n plugin-br-bank-transfer <mongodb-pod-name> -- mongorestore --authenticationDatabase=plugin_br_bank_transfer --username=bank_transfer --password=<password> --db=plugin_br_bank_transfer --archive=/tmp/backup.archive
```

4. **Update your values to use the new database:**

```yaml
mongodb:
  auth:
    databases:
      - "plugin_br_bank_transfer"

bankTransfer:
  configmap:
    MONGO_DATABASE: "plugin_br_bank_transfer"
```

5. **Upgrade the chart** (see [Command to upgrade](#command-to-upgrade) below)

> **Important:** If you are using external MongoDB, this change does not affect you. External MongoDB configuration is managed outside the chart.

### Step 2: Verify PostgreSQL Migration Strategy

No action is required, but you should understand the new migration behavior:

- **If you use bundled PostgreSQL** (`postgresql.enabled=true`, `postgresql.external=false`): Migrations now run as an initContainer in the application Deployment. You will see the migration container logs in each application pod's init logs. The first pod to start will apply migrations; subsequent pods will wait for the lock or skip if migrations are already complete.

- **If you use external PostgreSQL** (`postgresql.enabled=false` or `postgresql.external=true`): Migrations continue to run as a pre-install/pre-upgrade hook Job. No change in behavior.

To verify migration logs after upgrading:

**Bundled PostgreSQL:**

```bash
kubectl logs -n plugin-br-bank-transfer <app-pod-name> -c migrations
```

**External PostgreSQL:**

```bash
kubectl logs -n plugin-br-bank-transfer -l job-name=<release-name>-migrations
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.3.1 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.3.1 -n plugin-br-bank-transfer
```
