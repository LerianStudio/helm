<!-- {% raw %} -->
# Helm Upgrade from v2.x to v3.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Plugin authentication now enabled by default](#1-plugin-authentication-now-enabled-by-default)
  - [2. Environment variable added: ENV_NAME](#2-environment-variable-added-env_name)
  - [3. Plugin auth host variable renamed: PLUGIN_AUTH_HOST to PLUGIN_AUTH_ADDRESS](#3-plugin-auth-host-variable-renamed-plugin_auth_host-to-plugin_auth_address)
  - [4. Bitnami image repositories replaced with bitnamilegacy](#4-bitnami-image-repositories-replaced-with-bitnamilegacy)
  - [5. Bundled RabbitMQ no longer creates default user credentials](#5-bundled-rabbitmq-no-longer-creates-default-user-credentials)
  - [6. RabbitMQ bootstrap job no longer creates users or permissions](#6-rabbitmq-bootstrap-job-no-longer-creates-users-or-permissions)
  - [7. Valkey password handling changed for bundled instances](#7-valkey-password-handling-changed-for-bundled-instances)
  - [8. PostgreSQL bootstrap job now validates the role password](#8-postgresql-bootstrap-job-now-validates-the-role-password)
- **[Features](#features)**
  - [1. New helper for boolean flags with true defaults](#1-new-helper-for-boolean-flags-with-true-defaults)
  - [2. Improved documentation for configuration values](#2-improved-documentation-for-configuration-values)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: Development environment without Access Manager](#scenario-1-development-environment-without-access-manager)
  - [Scenario 2: Production environment with Access Manager](#scenario-2-production-environment-with-access-manager)
  - [Scenario 3: External RabbitMQ with existing user accounts](#scenario-3-external-rabbitmq-with-existing-user-accounts)
  - [Scenario 4: Bundled RabbitMQ with manual user provisioning](#scenario-4-bundled-rabbitmq-with-manual-user-provisioning)
- **[Configuration Reference](#configuration-reference)**
  - [Authentication Settings](#authentication-settings)
  - [RabbitMQ User Provisioning](#rabbitmq-user-provisioning)
  - [Valkey Password Configuration](#valkey-password-configuration)
- **[Migration Steps](#migration-steps)**

## Overview

This is a major release that changes the default authentication behavior, renames critical environment variables, switches dependency image repositories from `bitnami/*` to `bitnamilegacy/*`, and modifies how RabbitMQ user accounts and Valkey passwords are provisioned. The chart version moves from 2.2.0 to 3.0.0. **All operators must review their values files and take action before upgrading**, particularly around authentication settings, RabbitMQ user provisioning, and dependency image repositories.

## Breaking Changes

### 1. Plugin authentication now enabled by default

The `PLUGIN_AUTH_ENABLED` configuration variable now defaults to `"true"` (previously `"false"`), and the chart provides a default Access Manager service URL. This means the plugin will attempt to authenticate requests against the Access Manager by default.

**Before (v2.2.0):**

```yaml
bc-correios:
  configmap:
    PLUGIN_AUTH_ENABLED: "false"
    PLUGIN_AUTH_HOST: ""
```

**After (v3.0.0):**

```yaml
bc-correios:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"
```

**Operational impact:**

- If you do not have the Access Manager deployed, the plugin will fail to start or reject all requests with authentication errors
- Development environments that previously ran without authentication must now explicitly disable it (see [Scenario 1](#scenario-1-development-environment-without-access-manager))
- The application enforces that `PLUGIN_AUTH_ENABLED` cannot be `"false"` unless `APP_ENV` is `"development"` (see next breaking change)

> **Warning:** If you upgrade without adjusting authentication settings and do not have Access Manager deployed, the plugin pods will fail health checks and enter a crash loop. Review [Deployment Scenarios](#deployment-scenarios) before upgrading.

### 2. Environment variable added: ENV_NAME

The chart now renders `ENV_NAME` (default `"production"`) for the libraries. `APP_ENV` is still the variable the application reads for its own environment.

**Before (v2.2.0):**

```yaml
bc-correios:
  configmap:
    APP_ENV: "development"
```

**After (v3.0.0):**

```yaml
bc-correios:
  configmap:
    ENV_NAME: "production"
    APP_ENV: "production"   # set it to run the application's production checks
```

**Operational impact:**

- The application reads `APP_ENV`; `ENV_NAME` sets the libraries' environment (auth-client log format, lib-commons security tier) and `APP_ENV` drives the app's own validation. The chart renders `APP_ENV` as `"production"` unless you set it in `bc-correios.configmap` or `bc-correios.extraEnvVars`
- When `APP_ENV` is not `"development"`, the application refuses to start if `PLUGIN_AUTH_ENABLED` is `"false"`, and the chart refuses to render an empty `LICENSE_KEY`, `POSTGRES_SSLMODE: "disable"` and `ALLOWED_ORIGINS` empty or `*`
- A values file that sets `APP_ENV` keeps working
- If you run a development environment without Access Manager, set `PLUGIN_AUTH_ENABLED: "false"` and set `APP_ENV: "development"` (see [Scenario 1](#scenario-1-development-environment-without-access-manager))

> **Important:** The chart runs the application's production checks by default. For a development install set `bc-correios.configmap.APP_ENV: "development"`.

### 3. Plugin auth host variable renamed: PLUGIN_AUTH_HOST to PLUGIN_AUTH_ADDRESS

The configuration variable for the Access Manager service URL has been renamed from `PLUGIN_AUTH_HOST` to `PLUGIN_AUTH_ADDRESS`.

**Before (v2.2.0):**

```yaml
bc-correios:
  configmap:
    PLUGIN_AUTH_HOST: ""
```

**After (v3.0.0):**

```yaml
bc-correios:
  configmap:
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"
```

**Operational impact:**

- The application reads `PLUGIN_AUTH_ADDRESS` and lib-auth reads `PLUGIN_AUTH_HOST`; the chart renders both with one value. `PLUGIN_AUTH_HOST` in `bc-correios.configmap` or `bc-correios.extraEnvVars`, when set, takes precedence. With `bc-correios.useExistingSecret`, set `PLUGIN_AUTH_HOST` in that Secret or in `configmap`
- The new default assumes the Access Manager auth service is deployed in the `midaz-plugins` namespace with the release name `plugin-access-manager-auth`

> **Note:** If your Access Manager is deployed with a different release name or namespace, override `PLUGIN_AUTH_ADDRESS` with the correct service URL.

### 4. Bitnami image repositories replaced with bitnamilegacy

The PostgreSQL and Valkey subchart image repositories have been changed from `bitnami/postgresql` and `bitnami/valkey` to `bitnamilegacy/postgresql` and `bitnamilegacy/valkey`. The `global.security.allowInsecureImages` flag is now set to `true` for both subcharts.

**Before (v2.2.0):**

```yaml
valkey:
  global:
    security:
      allowInsecureImages: false
  image:
    repository: bitnami/valkey
    tag: "8.0.2"

postgresql:
  global:
    security:
      allowInsecureImages: false
  image:
    repository: bitnami/postgresql
    tag: "17.4.0"
```

**After (v3.0.0):**

```yaml
valkey:
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamilegacy/valkey
    tag: "8.0.2"

postgresql:
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamilegacy/postgresql
    tag: "17.4.0"
```

**Operational impact:**

- The image tags remain the same (`8.0.2` for Valkey, `17.4.0` for PostgreSQL), so the data format is unchanged
- Existing PersistentVolumeClaims will continue to work without data migration
- If you have custom image pull policies or registry mirrors configured, verify they support the `bitnamilegacy` repository

### 5. Bundled RabbitMQ no longer creates default user credentials

When using the bundled RabbitMQ with `rabbitmq.authentication.existingSecret` set (which is now required for the Erlang cookie), the broker is started without `RABBITMQ_DEFAULT_USER` or `RABBITMQ_DEFAULT_PASS` environment variables. The `rabbitmq.authentication.user.value` and `rabbitmq.authentication.password.value` settings are ignored when `existingSecret` is set.

**Before (v2.2.0):**

The bundled RabbitMQ would create a default user account based on `rabbitmq.authentication.user.value` and `rabbitmq.authentication.password.value`, even when `existingSecret` was set for the Erlang cookie.

**After (v3.0.0):**

When `rabbitmq.authentication.existingSecret` is set, the bundled RabbitMQ starts without any default user credentials. The `user.value` and `password.value` settings are ignored because they do not declare a `secretKey` and the subchart only honors them when `existingSecret` is unset.

**Operational impact:**

- Without `bc-correios.useExistingSecret`, the chart declares the `RABBITMQ_USER` account with `RABBITMQ_PASS` (`templates/rabbitmq_load_definitions.yaml`). Set `bc-correios.secrets.RABBITMQ_URL` to use that account (`amqp://<RABBITMQ_USER>:<RABBITMQ_PASS>@<release>-rabbitmq:5672/`) and no manual provisioning is needed; for any other account in the URL, provision it as described below. With `bc-correios.useExistingSecret` or an external broker, you must provision the RabbitMQ user account that `bc-correios.secrets.RABBITMQ_URL` references
- The Erlang cookie (`RABBITMQ_ERLANG_COOKIE`) is still required in the application Secret when `rabbitmq.enabled` is `true` (see `bc-correios.rabbitmqErlangCookieRequired` helper)
- If you do not provision the user account, the plugin will fail to connect to RabbitMQ and enter a crash loop

> **Warning:** With `bc-correios.useExistingSecret`, the bundled RabbitMQ starts with no user accounts. You must create the user referenced in `RABBITMQ_URL` before the plugin can connect. See [Scenario 4](#scenario-4-bundled-rabbitmq-with-manual-user-provisioning) for instructions.

### 6. RabbitMQ bootstrap job no longer creates users or permissions

The `global.externalRabbitmqDefinitions` bootstrap job now only imports exchanges, queues, and bindings from `files/rabbitmq/load_definitions.json` (vhost `/`). It no longer creates users or sets permissions.

**Before (v2.2.0):**

The bootstrap job would create users, vhosts, and permissions in addition to importing definitions.

**After (v3.0.0):**

The bootstrap job only imports exchanges, queues, and bindings. User accounts and permissions must be provisioned separately.

**Operational impact:**

- If you use an external RabbitMQ and enable `global.externalRabbitmqDefinitions.enabled`, you must ensure the user account referenced in `bc-correios.secrets.RABBITMQ_URL` already exists with appropriate permissions on vhost `/`
- The job will fail if the user account does not exist or lacks permissions to import definitions

> **Important:** The NOTES.txt template now states: "RabbitMQ bootstrap job will run to import exchanges, queues, and bindings (vhost '/'). It does not create users: the broker account referenced by bc-correios.secrets.RABBITMQ_URL must already exist."

### 7. Valkey password handling changed for bundled instances

When using the bundled Valkey with authentication enabled (the default), the `CACHE_PASSWORD` environment variable is now read from the Valkey subchart's Secret via `secretKeyRef` instead of from the application Secret. The `bc-correios.secrets.CACHE_PASSWORD` value is ignored in this configuration.

**Before (v2.2.0):**

The `CACHE_PASSWORD` was always read from the application Secret, regardless of whether the bundled Valkey or an external Valkey was used.

**After (v3.0.0):**

- **Bundled Valkey with auth enabled:** `CACHE_PASSWORD` is read from the Valkey Secret (`<release>-valkey`, key `valkey-password`) via `secretKeyRef`
- **Bundled Valkey with auth disabled:** `CACHE_PASSWORD` is read from the application Secret (from `bc-correios.secrets.CACHE_PASSWORD`)
- **External Valkey with `valkey.auth.existingSecret`:** `CACHE_PASSWORD` is read from the existing Secret via `secretKeyRef`
- **External Valkey without `existingSecret`:** `CACHE_PASSWORD` is read from the application Secret (from `bc-correios.secrets.CACHE_PASSWORD`)

**Operational impact:**

- If you use the bundled Valkey with auth enabled (the default), you no longer need to set `bc-correios.secrets.CACHE_PASSWORD` in your values file
- If you previously set `bc-correios.secrets.CACHE_PASSWORD` to match the Valkey password, that value is now ignored
- If you use an external Valkey without `valkey.auth.existingSecret`, you must continue to set `bc-correios.secrets.CACHE_PASSWORD`

> **Note:** The new `bc-correios.valkeyPasswordFromSubchart` helper determines whether to read the password from the Valkey Secret or the application Secret. The deployment template includes a conditional `secretKeyRef` block that is only rendered when this helper returns `"true"`.

### 8. PostgreSQL bootstrap job now validates the role password

The PostgreSQL bootstrap job now validates that `DB_PASSWORD_BC_CORREIOS` is non-empty and contains no carriage return or line feed characters.

**After (v3.0.0):**

```bash
[ -n "$DB_PASSWORD_BC_CORREIOS" ] && [ "$(printf '%s' "$DB_PASSWORD_BC_CORREIOS" | tr -d '\r\n')" = "$DB_PASSWORD_BC_CORREIOS" ] || { echo "DB_PASSWORD_BC_CORREIOS is empty or contains a carriage return or line feed (often a trailing one from a Secret made with echo or on Windows); the plugin-bc-correios role password must be a non-empty single line." >&2; exit 1; }
printf '%s\n' 'BEGIN;' 'CREATE ROLE "plugin-bc-correios" LOGIN;' '\password "plugin-bc-correios"' "$DB_PASSWORD_BC_CORREIOS" "$DB_PASSWORD_BC_CORREIOS" 'COMMIT;' | PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE"
```

**Operational impact:**

- The bootstrap job will fail if `DB_PASSWORD_BC_CORREIOS` is empty or contains a carriage return or line feed character
- If you create the Secret manually (e.g., with `kubectl create secret` or `echo`), ensure the password value does not include a trailing newline

> **Warning:** If your Secret was created with `echo` without the `-n` flag, it likely contains a trailing newline. The bootstrap job will fail with the error: "DB_PASSWORD_BC_CORREIOS is empty or contains a carriage return or line feed." Recreate the Secret without the trailing newline.

## Features

### 1. New helper for boolean flags with true defaults

A new template helper `bc-correios.flagDefaultTrue` has been introduced to handle boolean flags that default to `"true"`. This helper correctly renders explicit boolean `false` values (which Sprig's `default` function treats as empty).

**Usage in templates:**

```yaml
ALLOW_INSECURE_TLS: {{ include "bc-correios.flagDefaultTrue" $component.configmap.ALLOW_INSECURE_TLS | quote }}
PLUGIN_AUTH_ENABLED: {{ include "bc-correios.flagDefaultTrue" $component.configmap.PLUGIN_AUTH_ENABLED | quote }}
```

**Operational impact:**

- Flags like `ALLOW_INSECURE_TLS`, `PLUGIN_AUTH_ENABLED`, `OBJECT_STORAGE_PATH_STYLE`, and `FEATURE_AI_INSIGHTS_ENABLED` now correctly render `"false"` when explicitly set to `false` in values
- Previously, setting these flags to `false` would result in the default `"true"` being rendered

> **Note:** This is a template-level improvement and does not require changes to your values file unless you were working around the previous behavior.

### 2. Improved documentation for configuration values

The `values.yaml` file now includes extensive inline comments explaining the behavior of various configuration settings, particularly around authentication, RabbitMQ user provisioning, and Valkey password handling.

**Key documentation additions:**

- `global.externalRabbitmqDefinitions`: Clarifies that the job imports definitions but does not create users
- `bc-correios.configmap.ENV_NAME`: Sets the libraries' environment; `APP_ENV` drives the app's own validation
- `bc-correios.configmap.PLUGIN_AUTH_ADDRESS`: Documents the default Access Manager service URL
- `bc-correios.secrets.CACHE_PASSWORD`: Explains when this value is used vs. when the password is read from the Valkey Secret
- `rabbitmq.authentication`: Documents that `user.value` and `password.value` are ignored when `existingSecret` is set
- `rabbitmq.persistence.size`: Clarifies that this key has no effect because the groundhog2k subchart uses `storage.requestedSize` instead

> **Note:** These documentation improvements do not change behavior but provide critical context for operators configuring the chart.

## Deployment Scenarios

This section provides concrete configuration examples for common deployment scenarios. Choose the scenario that matches your environment and follow the corresponding configuration.

### Scenario 1: Development environment without Access Manager

If you run a development environment and do not have the Access Manager deployed, you must explicitly disable authentication and set the environment name and `APP_ENV` to `"development"`.

**Required configuration:**

```yaml
bc-correios:
  configmap:
    ENV_NAME: "development"
    APP_ENV: "development"
    PLUGIN_AUTH_ENABLED: "false"
```

**Why this is required:**

- The application refuses to start with `PLUGIN_AUTH_ENABLED: "false"` unless `APP_ENV` is `"development"`
- Without `PLUGIN_AUTH_ENABLED: "false"`, the chart defaults to `PLUGIN_AUTH_ENABLED: "true"`, causing the plugin to fail authentication checks

> **Warning:** Do not use this configuration in production. The application enforces that authentication cannot be disabled in production environments.

### Scenario 2: Production environment with Access Manager

If you run a production environment with the Access Manager deployed, verify that the default Access Manager service URL matches your deployment.

**Production configuration (the Access Manager address is the default; the last three values have no production-ready default):**

```yaml
bc-correios:
  configmap:
    ENV_NAME: "production"
    APP_ENV: "production"
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"
    LICENSE_KEY: "<your-license-key>"   # or put LICENSE_KEY in the Secret of bc-correios.useExistingSecret
    POSTGRES_SSLMODE: "require"
    ALLOWED_ORIGINS: "https://app.example.com"
```

The bundled PostgreSQL has TLS off. With it, also set `postgresql.tls.enabled: true` and `postgresql.tls.autoGenerated: true`, or use an external PostgreSQL with TLS.

**If your Access Manager is deployed with a different release name or namespace:**

```yaml
bc-correios:
  configmap:
    PLUGIN_AUTH_ADDRESS: "http://<your-access-manager-service>.<namespace>.svc.cluster.local:<port>"
```

**Migration steps:**

1. Verify the Access Manager is deployed and healthy
2. Confirm the service URL matches the `PLUGIN_AUTH_ADDRESS` value
3. Ensure the `PLUGIN_AUTH_CLIENT_ID` matches the client ID registered in Access Manager (default: `"plugin-bc-correios"`)

### Scenario 3: External RabbitMQ with existing user accounts

If you use an external RabbitMQ broker with existing user accounts, ensure the user referenced in `bc-correios.secrets.RABBITMQ_URL` has appropriate permissions on vhost `/`.

**Required configuration:**

```yaml
rabbitmq:
  enabled: false
  external: true

bc-correios:
  secrets:
    RABBITMQ_URL: "amqp://<username>:<password>@<rabbitmq-host>:5672/"
```

**If you enable the definitions bootstrap job:**

```yaml
global:
  externalRabbitmqDefinitions:
    enabled: true
```

**Migration steps:**

1. Verify the user account referenced in `RABBITMQ_URL` exists in your external RabbitMQ
2. Ensure the user has permissions to create exchanges, queues, and bindings on vhost `/`
3. If you enable `global.externalRabbitmqDefinitions.enabled`, verify the user can import definitions

> **Important:** The bootstrap job no longer creates users. If the user does not exist or lacks permissions, the job will fail.

### Scenario 4: Bundled RabbitMQ with manual user provisioning

Without `bc-correios.useExistingSecret`, the chart declares the `RABBITMQ_USER` account with `RABBITMQ_PASS`; if `RABBITMQ_URL` uses that account, you need no manual provisioning. If you use the bundled RabbitMQ with `bc-correios.useExistingSecret`, you must manually provision the user account referenced in `RABBITMQ_URL` in the app Secret because the broker starts without default credentials when `rabbitmq.authentication.existingSecret` is set.

**Required configuration:**

```yaml
rabbitmq:
  enabled: true
  authentication:
    existingSecret: "<your-secret-name>"
    erlangCookie:
      secretKey: "erlang-cookie"

bc-correios:
  useExistingSecret: true
  existingSecretName: "<app-secret-name>" # holds RABBITMQ_URL (amqp://<username>:<password>@plugin-bc-correios-rabbitmq:5672/)
```

**Migration steps:**

1. Generate a stable Erlang cookie and store it in a Secret:

```bash
kubectl create secret generic rabbitmq-erlang-cookie \
  --from-literal=erlang-cookie=$(openssl rand -hex 32) \
  -n <namespace>
```

2. Set `rabbitmq.authentication.existingSecret` to the Secret name and `erlangCookie.secretKey` to `"erlang-cookie"`

3. After the RabbitMQ pod starts, create the user account manually:

```bash
kubectl exec -n <namespace> -it <rabbitmq-pod-name> -- rabbitmqctl add_user <username> <password>
kubectl exec -n <namespace> -it <rabbitmq-pod-name> -- rabbitmqctl set_permissions -p / <username> ".*" ".*" ".*"
```

4. Put `RABBITMQ_URL` with that username and password in the app Secret (`bc-correios.existingSecretName`)

> **Warning:** The Erlang cookie must be a stable value. Changing it across upgrades breaks the RabbitMQ cluster. Generate it once and store it in a Secret that persists across upgrades.

## Configuration Reference

### Authentication Settings

The following table describes the authentication-related configuration settings.

| Flag | Default (v3.0.0) | Description |
|------|------------------|-------------|
| `bc-correios.configmap.ENV_NAME` | `"production"` | Sets the libraries' environment (auth-client log format, lib-commons security tier). `APP_ENV` drives the app's own validation. |
| `bc-correios.configmap.PLUGIN_AUTH_ENABLED` | `"true"` | Enable or disable plugin authentication. Must be `"true"` in production. |
| `bc-correios.configmap.PLUGIN_AUTH_ADDRESS` | `"http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"` | Access Manager auth service URL. Override if your Access Manager is deployed with a different release name or namespace. |
| `bc-correios.configmap.PLUGIN_AUTH_CLIENT_ID` | `"plugin-bc-correios"` | Client ID registered in Access Manager. |

**Complete YAML example:**

```yaml
bc-correios:
  configmap:
    ENV_NAME: "production"
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"
    PLUGIN_AUTH_CLIENT_ID: "plugin-bc-correios"
```

### RabbitMQ User Provisioning

The following table describes the RabbitMQ user provisioning behavior.

| Configuration | Behavior |
|---------------|----------|
| Bundled RabbitMQ without `existingSecret` | The subchart creates a default user based on `rabbitmq.authentication.user.value` and `rabbitmq.authentication.password.value`. |
| Bundled RabbitMQ with `existingSecret`, without `bc-correios.useExistingSecret` | The chart declares the `RABBITMQ_USER` account with `RABBITMQ_PASS`; no manual provisioning is needed when `RABBITMQ_URL` uses that account. |
| Bundled RabbitMQ with `existingSecret` and `bc-correios.useExistingSecret` | The broker starts without default credentials. You must manually provision the user account referenced in `RABBITMQ_URL` in the app Secret. |
| External RabbitMQ | The user account referenced in `bc-correios.secrets.RABBITMQ_URL` must already exist with appropriate permissions. |

**Example: Bundled RabbitMQ with manual user provisioning:**

```yaml
rabbitmq:
  enabled: true
  authentication:
    existingSecret: "rabbitmq-erlang-cookie"
    erlangCookie:
      secretKey: "erlang-cookie"

bc-correios:
  useExistingSecret: true
  existingSecretName: "<app-secret-name>" # holds RABBITMQ_URL (amqp://bc_correios:changeme@plugin-bc-correios-rabbitmq:5672/)
```

### Valkey Password Configuration

The following table describes when `CACHE_PASSWORD` is read from the Valkey Secret vs. the application Secret.

| Configuration | Password Source |
|---------------|-----------------|
| Bundled Valkey with `auth.enabled: true` (default) | Valkey Secret (`<release>-valkey`, key `valkey-password`) via `secretKeyRef` |
| Bundled Valkey with `auth.enabled: false` | Application Secret (`bc-correios.secrets.CACHE_PASSWORD`) |
| External Valkey with `valkey.auth.existingSecret` | Existing Secret (name from `existingSecret`, key from `existingSecretPasswordKey` or `valkey-password`) via `secretKeyRef` |
| External Valkey without `existingSecret` | Application Secret (`bc-correios.secrets.CACHE_PASSWORD`) |

**Example: Bundled Valkey with auth enabled (default):**

```yaml
valkey:
  enabled: true
  auth:
    enabled: true
    password: ""  # Leave empty to let the subchart generate it

bc-correios:
  secrets:
    # CACHE_PASSWORD is ignored; the password is read from the Valkey Secret
```

**Example: External Valkey without existingSecret:**

```yaml
valkey:
  enabled: false
  external: true

bc-correios:
  secrets:
    CACHE_PASSWORD: "your-valkey-password"
```

## Migration Steps

This upgrade requires careful preparation due to the breaking changes around authentication, RabbitMQ user provisioning, and dependency image repositories. Follow these steps in order.

**Step 1: Review your current authentication configuration**

Determine whether you run a development or production environment and whether you have the Access Manager deployed.

- **Development without Access Manager:** You must set `PLUGIN_AUTH_ENABLED: "false"` (see [Scenario 1](#scenario-1-development-environment-without-access-manager))
- **Production with Access Manager:** Verify the `PLUGIN_AUTH_ADDRESS` matches your Access Manager service URL (see [Scenario 2](#scenario-2-production-environment-with-access-manager))

**Step 2: Update environment variable names in your values file**

Keep `APP_ENV` in your values file; the application still reads it. `PLUGIN_AUTH_HOST` still works and takes precedence; `PLUGIN_AUTH_ADDRESS` is the values key the chart renders under both names:

```yaml
# Before (v2.2.0)
bc-correios:
  configmap:
    APP_ENV: "production"
    PLUGIN_AUTH_HOST: "http://my-access-manager:4000"

# After (v3.0.0)
bc-correios:
  configmap:
    ENV_NAME: "production"
    APP_ENV: "production"
    PLUGIN_AUTH_ADDRESS: "http://my-access-manager:4000"
```

**Step 3: Provision RabbitMQ user accounts**

If you use the bundled RabbitMQ with `rabbitmq.authentication.existingSecret` and `bc-correios.useExistingSecret` set, or if you use an external RabbitMQ, ensure the user account referenced in `bc-correios.secrets.RABBITMQ_URL` exists with appropriate permissions.

- **Bundled RabbitMQ:** Follow [Scenario 4](#scenario-4-bundled-rabbitmq-with-manual-user-provisioning)
- **External RabbitMQ:** Follow [Scenario 3](#scenario-3-external-rabbitmq-with-existing-user-accounts)

**Step 4: Verify PostgreSQL role password Secret**

If you create the PostgreSQL role password Secret manually, ensure the password value does not contain a trailing newline:

```bash
kubectl create secret generic postgres-bc-correios-password \
  --from-literal=password=$(openssl rand -base64 32 | tr -d '\n') \
  -n <namespace>
```

**Step 5: Review Valkey password configuration**

If you use the bundled Valkey with auth enabled (the default), you no longer need to set `bc-correios.secrets.CACHE_PASSWORD`. If you use an external Valkey without `valkey.auth.existingSecret`, ensure `bc-correios.secrets.CACHE_PASSWORD` is set.

**Step 6: Preview the upgrade**

Use the helm-diff plugin to preview the changes:

```bash
helm diff upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 3.0.0 -n <namespace> -f your-values.yaml
```

**Step 7: Backup your data**

Ensure you have recent backups of your PostgreSQL database, RabbitMQ definitions, and any persistent volumes.

**Step 8: Run the upgrade**

Execute the upgrade command during a maintenance window:

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 3.0.0 -n <namespace> -f your-values.yaml
```

**Step 9: Verify the upgrade**

Check that all pods are running and healthy:

```bash
kubectl get pods -n <namespace>
```

Check service logs for authentication or connection errors:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=bc-correios,app.kubernetes.io/instance=plugin-bc-correios --tail=50
```

Verify the plugin can connect to RabbitMQ, PostgreSQL, and Valkey:

```bash
kubectl exec -n <namespace> -it <pod-name> -- wget -qO- http://localhost:9090/health/ready
```
<!-- {% endraw %} -->
