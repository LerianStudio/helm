# Helm Upgrade from v1.0.0 to v1.0.1

## Topics

- **[Fixes](#fixes)**
  - [Migration job environment variable corrections](#migration-job-environment-variable-corrections)
  - [Non-TLS PostgreSQL connection support](#non-tls-postgresql-connection-support)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### Migration job environment variable corrections

The migration job template has been updated to use the correct environment variable names and add missing configuration that aligns with the lib-commons migrator expectations.

**Before (v1.0.0):**

```yaml
env:
  - name: POSTGRES_HOST
    value: "..."
  - name: POSTGRES_PORT
    value: "..."
  - name: POSTGRES_USER
    value: "..."
  - name: POSTGRES_DB
    value: "..."
  - name: POSTGRES_SSLMODE
    value: "..."
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: ...
        key: ...
```

**After (v1.0.1):**

```yaml
env:
  - name: MIGRATIONS_PATH
    value: "/migrations"
  - name: POSTGRES_HOST
    value: "..."
  - name: POSTGRES_PORT
    value: "..."
  - name: POSTGRES_USER
    value: "..."
  - name: POSTGRES_NAME
    value: "..."
  - name: POSTGRES_SSLMODE
    value: "..."
  - name: ENV_NAME
    value: "development"
  - name: POSTGRES_CONNECT_TIMEOUT_SEC
    value: "10"
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: ...
        key: ...
```

| Environment Variable | v1.0.0 | v1.0.1 | Description |
|---------------------|---------|---------|-------------|
| `MIGRATIONS_PATH` | Not set | `/migrations` | Path where migration files are located |
| `POSTGRES_DB` | Used | Removed | Old database name variable |
| `POSTGRES_NAME` | Not set | Used | Correct database name variable expected by lib-commons |
| `ENV_NAME` | Not set | `development` (default) | Environment name, sourced from `brSisbajud.configmap.ENV_NAME` |
| `POSTGRES_CONNECT_TIMEOUT_SEC` | Not set | `10` (default) | Connection timeout in seconds |

#### New environment variables

| Variable | Default | Source | Description |
|----------|---------|--------|-------------|
| `MIGRATIONS_PATH` | `/migrations` | Hardcoded | Directory containing migration files |
| `ENV_NAME` | `development` | `brSisbajud.configmap.ENV_NAME` | Environment identifier |
| `POSTGRES_CONNECT_TIMEOUT_SEC` | `10` | `migrations.postgres.connectTimeoutSec` or `brSisbajud.configmap.POSTGRES_CONNECT_TIMEOUT_SEC` | PostgreSQL connection timeout |

> **Note:** The `POSTGRES_DB` variable has been renamed to `POSTGRES_NAME` to match lib-commons migrator expectations. This change is backward compatible as the value source remains `migrations.postgres.database`.

#### Customizing new variables

To override the default values, add the following to your `values.yaml`:

```yaml
brSisbajud:
  configmap:
    ENV_NAME: "production"
    POSTGRES_CONNECT_TIMEOUT_SEC: "30"

migrations:
  postgres:
    connectTimeoutSec: "30"
```

### Non-TLS PostgreSQL connection support

The migration job now properly supports non-TLS PostgreSQL connections by respecting the `ALLOW_INSECURE_TLS` environment variable. Previously, even with `sslmode=disable`, the lib-commons migrator would refuse non-TLS connections.

The chart now resolves `ALLOW_INSECURE_TLS` from three possible sources (in order of precedence):

1. `migrations.allowInsecureTLS` (migration-specific override)
2. `brSisbajud.extraEnvVars` (array of env vars)
3. `brSisbajud.configmap.ALLOW_INSECURE_TLS` (configmap entry)

**Template logic added:**

```yaml
{{- $allowInsecureTLS := "" -}}
{{- if hasKey .Values.migrations "allowInsecureTLS" -}}
{{- $allowInsecureTLS = toString .Values.migrations.allowInsecureTLS -}}
{{- else -}}
{{- range $extraEnv -}}
{{- if eq .name "ALLOW_INSECURE_TLS" -}}
{{- $allowInsecureTLS = toString .value -}}
{{- end -}}
{{- end -}}
{{- if eq $allowInsecureTLS "" -}}
{{- if hasKey .Values.brSisbajud.configmap "ALLOW_INSECURE_TLS" -}}
{{- $allowInsecureTLS = toString (index .Values.brSisbajud.configmap "ALLOW_INSECURE_TLS") -}}
{{- end -}}
{{- end -}}
{{- end }}
```

> **Important:** The `ALLOW_INSECURE_TLS` variable is only emitted when explicitly set. TLS-enabled environments remain secure by default.

#### For non-TLS PostgreSQL environments

If you are using PostgreSQL without TLS (e.g., `sslmode=disable`), you must now explicitly enable insecure connections:

**Option 1: Migration-specific override**

```yaml
migrations:
  allowInsecureTLS: true
  postgres:
    sslMode: "disable"
```

**Option 2: Application-wide setting via configmap**

```yaml
brSisbajud:
  configmap:
    ALLOW_INSECURE_TLS: "true"
    POSTGRES_SSLMODE: "disable"
```

**Option 3: Application-wide setting via extraEnvVars**

```yaml
brSisbajud:
  extraEnvVars:
    - name: ALLOW_INSECURE_TLS
      value: "true"
```

> **Warning:** Only set `ALLOW_INSECURE_TLS: true` in development or test environments. Production deployments should use TLS-enabled PostgreSQL connections.

#### For TLS-enabled PostgreSQL environments

No action required. The variable will not be set, and the migrator will enforce TLS by default.

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.0.1 -n br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.0.1 -n br-sisbajud
```
