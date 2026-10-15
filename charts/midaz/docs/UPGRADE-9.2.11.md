# Helm Upgrade from v9.2.10 to v9.2.11

## Topics

- **[Fixes](#fixes)**
  - [1. PostgreSQL replica password key selection for bundled vs external deployments](#1-postgresql-replica-password-key-selection-for-bundled-vs-external-deployments)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. PostgreSQL replica password key selection for bundled vs external deployments

The ledger deployment template now correctly distinguishes between bundled (chart-managed) and external PostgreSQL deployments when selecting the secret key for replica database passwords.

#### What changed

The template logic for injecting PostgreSQL replica credentials into the ledger deployment has been updated to use the correct secret key based on your PostgreSQL deployment type:

| Deployment Type | Secret Key (v9.2.10) | Secret Key (v9.2.11) | Impact |
|----------------|---------------------|---------------------|---------|
| Bundled PostgreSQL (chart subchart enabled) | `replication-password` | `password` | Replica connections now use the same role as primary |
| External PostgreSQL (operator-managed Secret) | `replication-password` | `replication-password` | No change; external setups continue using dedicated replica user |

**Before (v9.2.10):**

```yaml
{{- include "midaz.infraSecretRef" (dict "context" $ "subchart" "postgresql" "key" "replication-password" "envName" "DB_ONBOARDING_REPLICA_PASSWORD") | nindent 12 }}
{{- include "midaz.infraSecretRef" (dict "context" $ "subchart" "postgresql" "key" "replication-password" "envName" "DB_TRANSACTION_REPLICA_PASSWORD") | nindent 12 }}
```

**After (v9.2.11):**

```yaml
{{- $replicaKey := ternary "password" "replication-password" $pgBundled }}
{{- include "midaz.infraSecretRef" (dict "context" $ "subchart" "postgresql" "key" $replicaKey "envName" "DB_ONBOARDING_REPLICA_PASSWORD") | nindent 12 }}
{{- include "midaz.infraSecretRef" (dict "context" $ "subchart" "postgresql" "key" $replicaKey "envName" "DB_TRANSACTION_REPLICA_PASSWORD") | nindent 12 }}
```

#### Why this matters

The bundled Bitnami PostgreSQL subchart creates a read replica that inherits the primary database's roles and credentials. The replica uses the same `midaz` role and password (stored under the `password` key) for both primary and replica connections. The previous template incorrectly referenced `replication-password`, which is only relevant for external PostgreSQL deployments where a separate replication user exists.

This fix ensures:
- **Bundled deployments**: Replica connections use the correct `password` key, matching the primary role
- **External deployments**: Replica connections continue using `replication-password` for dedicated replica users

#### Operational impact

**If you use the bundled PostgreSQL subchart** (`postgresql.enabled: true` and `postgresql.external: false` or unset):

- The ledger pods will now correctly reference the `password` secret key for replica database connections
- No action required; the fix is automatic on upgrade
- Existing connections will reconnect using the correct credentials after pod restart

**If you use an external PostgreSQL** (operator-managed Secret with `postgresql.enabled: false` or `postgresql.external: true`):

- Behavior is unchanged; the template continues using `replication-password`
- Ensure your operator-managed Secret contains both keys:
  - `password`: for primary database connections
  - `replication-password`: for replica database connections (if replicas are configured)

> **Note:** This is a bug fix with no breaking changes. No values.yaml modifications are required. The ledger deployment will automatically use the correct secret key based on your PostgreSQL configuration.

#### Documentation update

The inline comment in `values.yaml` has been clarified to reflect this behavior:

**Before (v9.2.10):**

```yaml
# DB_ONBOARDING_PASSWORD / DB_ONBOARDING_REPLICA_PASSWORD are single-sourced from
# the Bitnami postgresql subchart Secret (keys `password` / `replication-password`)
```

**After (v9.2.11):**

```yaml
# DB_ONBOARDING_PASSWORD / DB_ONBOARDING_REPLICA_PASSWORD are single-sourced from
# the Bitnami postgresql subchart Secret (key `password`, replicas included)
```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.11 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.11 -n midaz
```
