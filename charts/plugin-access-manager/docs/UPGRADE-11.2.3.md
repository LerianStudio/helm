<!-- {% raw %} -->
# Helm Upgrade from v11.2.2 to v11.2.3

# Topics

- **[Fixes](#fixes)**
  - [1. Database TLS Configuration for Migrations](#1-database-tls-configuration-for-migrations)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Database TLS Configuration for Migrations

This release fixes a database connection issue in the Caradhras migrations container when using `sslmode=disable`. The migrations container now correctly reads the `ALLOW_INSECURE_TLS` environment variable to permit insecure database connections when explicitly configured.

**What changed:**

The Caradhras migrations Deployment now includes the `ALLOW_INSECURE_TLS` environment variable, sourced from the Caradhras ConfigMap:

**Before (v11.2.2):**

```yaml
# templates/caradhras/deployment.yaml
env:
  - name: DB_SSLMODE
    valueFrom:
      configMapKeyRef:
        name: {{ include "plugin-auth.fullname" . }}
        key: DB_SSLMODE
  {{- /* The migrator is licence-gated and, on a fresh install, the first process to
       fetch the licence file: it needs the key (or file) and, behind a proxy,
       caradhras.migrations.extraEnvVars (HTTPS_PROXY). */}}
```

**After (v11.2.3):**

```yaml
# templates/caradhras/deployment.yaml
env:
  - name: DB_SSLMODE
    valueFrom:
      configMapKeyRef:
        name: {{ include "plugin-auth.fullname" . }}
        key: DB_SSLMODE
  # lib-commons refuses sslmode=disable unless this is true; same key the server reads.
  - name: ALLOW_INSECURE_TLS
    valueFrom:
      configMapKeyRef:
        name: {{ include "plugin-caradhras.fullname" . }}
        key: ALLOW_INSECURE_TLS
  {{- /* The migrator is licence-gated and, on a fresh install, the first process to
       fetch the licence file: it needs the key (or file) and, behind a proxy,
       caradhras.migrations.extraEnvVars (HTTPS_PROXY). */}}
```

**Why this matters:**

The `lib-commons` library used by the migrations container enforces TLS by default and refuses to connect to a database with `sslmode=disable` unless `ALLOW_INSECURE_TLS` is explicitly set to `true`. Without this environment variable, migrations would fail to connect to databases configured without TLS, even when `DB_SSLMODE=disable` was correctly set.

This fix ensures that:
- Migrations can connect to databases with `sslmode=disable` when `ALLOW_INSECURE_TLS` is enabled
- The migrations container uses the same TLS policy as the main Caradhras server
- Database connection behavior is consistent across all Caradhras components

**Environment variable details:**

| Variable | Source | Purpose |
|----------|--------|---------|
| `ALLOW_INSECURE_TLS` | `plugin-caradhras` ConfigMap | Permits database connections with `sslmode=disable` when set to `true` |

**Default behavior:**

The `ALLOW_INSECURE_TLS` value is read from the Caradhras ConfigMap, which is controlled by your chart configuration. If you have not explicitly configured this value, the chart's default behavior applies.

**Operational impact:**

- **Databases with TLS enabled**: No action required. This change does not affect secure database connections.
- **Databases with `sslmode=disable`**: If you previously experienced migration failures with connection errors, this fix resolves those issues. Ensure `ALLOW_INSECURE_TLS` is set appropriately in your configuration.
- **New installations**: No action required. The migrations container will correctly read the TLS policy from the ConfigMap.

**Configuration example:**

If you are using a database without TLS (e.g., for development or testing), ensure your values include:

```yaml
caradhras:
  config:
    ALLOW_INSECURE_TLS: "true"

auth:
  secrets:
    DB_SSLMODE: "disable"
```

> **Warning:** Disabling TLS for database connections is not recommended for production environments. Always use encrypted connections (`sslmode=require` or higher) and keep `ALLOW_INSECURE_TLS` set to `false` in production.

**Migration scenarios:**

#### Scenario 1: Using TLS-enabled database (recommended)

No action required. The default secure configuration continues to work:

```yaml
auth:
  secrets:
    DB_SSLMODE: "require"
```

#### Scenario 2: Using database without TLS (development/testing)

Ensure both `DB_SSLMODE` and `ALLOW_INSECURE_TLS` are configured:

```yaml
caradhras:
  config:
    ALLOW_INSECURE_TLS: "true"

auth:
  secrets:
    DB_SSLMODE: "disable"
```

> **Important:** If you set `DB_SSLMODE=disable` but do not set `ALLOW_INSECURE_TLS=true`, the migrations container will fail to connect to the database. Both settings must be aligned.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.3
```
<!-- {% endraw %} -->
