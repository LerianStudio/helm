# Helm Upgrade from v1.1.1 to v1.1.2

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. PostgreSQL role password validation](#1-postgresql-role-password-validation)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `1.1.1` to `1.1.2`. The application version remains `1.0.0-beta.9`; the chart bump to `1.1.2` is a patch release that updates the PostgreSQL bootstrap job. The job now checks the `plugin_br_payments` role password before it creates the role.

No configuration changes are required. The upgrade will trigger a new bootstrap job run if the job is still present in your cluster.

## Changes

### 1. PostgreSQL role password validation

The `bootstrap-postgres` job now checks that `DB_PASSWORD_PLUGIN_BR_PAYMENTS` is non-empty and does not contain carriage return (`\r`) or line feed (`\n`) characters. Secrets created with `echo` (without `-n`) or on Windows systems often have trailing newlines. The job stops with an error message when the check fails.

#### Operational impact

- **Existing deployments**: If the `plugin_br_payments` role already exists, the bootstrap job skips role creation entirely. The password change logic does not run, and the upgrade has no effect on the database.

- **New deployments or role recreation**: If you delete the role and re-run the bootstrap job (or deploy to a fresh database), the job will now fail fast if the password secret contains trailing whitespace. You must ensure the secret is created correctly. The job reads the key `DB_PASSWORD_PLUGIN_BR_PAYMENTS` from the Secret named in `global.externalPostgresDefinitions.paymentsCredentials.useExistingSecret.name`:

```bash
# Correct: no trailing newline
kubectl create secret generic plugin-br-payments-db-password \
  --from-literal=DB_PASSWORD_PLUGIN_BR_PAYMENTS="$(cat password.txt | tr -d '\r\n')" \
  -n plugin-br-payments

# Or use printf instead of echo
printf '%s' 'your-password-here' | kubectl create secret generic plugin-br-payments-db-password \
  --from-file=DB_PASSWORD_PLUGIN_BR_PAYMENTS=/dev/stdin \
  -n plugin-br-payments
```

> **Warning:** If your `DB_PASSWORD_PLUGIN_BR_PAYMENTS` secret was created with `echo`, it likely contains a trailing newline. The v1.1.2 bootstrap job will reject it with an explicit error message. Recreate the secret without the trailing newline before running the job.

> **Note:** The bootstrap job is typically a one-time operation. If your cluster already has the `plugin_br_payments` role, this change will not affect your upgrade. The new validation only runs when creating the role for the first time.

## Migration Steps

1. **Verify your database password secret** (only if you plan to recreate the `plugin_br_payments` role or are deploying to a new database):

```bash
kubectl get secret plugin-br-payments-db-password -n plugin-br-payments -o jsonpath='{.data.DB_PASSWORD_PLUGIN_BR_PAYMENTS}' | base64 -d | od -An -tx1
```

If the output ends with `0a` (line feed) or `0d` (carriage return), recreate the secret:

```bash
kubectl delete secret plugin-br-payments-db-password -n plugin-br-payments
printf '%s' 'your-password-here' | kubectl create secret generic plugin-br-payments-db-password \
  --from-file=DB_PASSWORD_PLUGIN_BR_PAYMENTS=/dev/stdin \
  -n plugin-br-payments
```

2. **Run the upgrade** during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. **Verify the bootstrap job** (if it runs in your environment):

```bash
kubectl get jobs -n plugin-br-payments -l app.kubernetes.io/name=plugin-br-payments-helm
kubectl logs -n plugin-br-payments -l job-name=plugin-br-payments-bootstrap-postgres --tail=50
```

If the database and the role already exist, you should see:

```
Bootstrap already complete (database 'plugin_br_payments' and role 'plugin_br_payments' exist). Skipping creation.
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
