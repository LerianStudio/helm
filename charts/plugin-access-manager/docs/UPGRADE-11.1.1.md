<!-- {% raw %} -->
# Helm Upgrade from v11.1.0 to v11.1.1

# Topics

- **[Fixes](#fixes)**
  - [1. Database Password Escaping for Special Characters](#1-database-password-escaping-for-special-characters)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Database Password Escaping for Special Characters

This release fixes a critical bug where database passwords containing special characters (quotes, backslashes, or other shell metacharacters) would cause the Caradhras init container to fail when constructing the PostgreSQL connection string.

**What changed:**

The Caradhras deployment's init container now properly escapes the database password before interpolating it into the PostgreSQL DSN (Data Source Name). The password is sanitized to escape backslashes and single quotes, then wrapped in single quotes in the connection string.

**Before (v11.1.0):**

```yaml
- /bin/sh
- -c
- |
  export dataSourceName="user=${DB_USER} password=${DB_PASSWORD} host=${DB_HOST} port=${DB_PORT} sslmode=${DB_SSLMODE} connect_timeout=5 dbname=${DB_NAME}"
  exec /server --createDatabase={{- if hasKey .Values.caradhras "createDatabase" }}{{ .Values.caradhras.createDatabase }}{{- else }}false{{- end }}
```

**After (v11.1.1):**

```yaml
- /bin/sh
- -c
- |
  DB_PASSWORD_DSN=$(printf '%s' "$DB_PASSWORD" | sed -e 's/[\\'"'"']/\\&/g')
  export dataSourceName="user=${DB_USER} password='${DB_PASSWORD_DSN}' host=${DB_HOST} port=${DB_PORT} sslmode=${DB_SSLMODE} connect_timeout=5 dbname=${DB_NAME}"
  exec /server --createDatabase={{- if hasKey .Values.caradhras "createDatabase" }}{{ .Values.caradhras.createDatabase }}{{- else }}false{{- end }}
```

**Why this matters:**

- **Passwords with quotes break the DSN**: If your database password contains a single quote (`'`), double quote (`"`), or backslash (`\`), the unescaped interpolation in v11.1.0 would produce a malformed connection string, causing the init container to fail with a cryptic PostgreSQL error like `pq: unterminated quoted string` or `pq: syntax error`
- **Init container failures block pod startup**: The Caradhras pod cannot reach Ready state until the init container succeeds, so `helm upgrade --wait` or `--atomic` operations would time out
- **Error appears only in init container logs**: The failure occurs before the main container starts, so you must inspect the init container logs to see the connection error:

```bash
kubectl logs -n plugin-access-manager <caradhras-pod> -c <init-container-name> --previous
```

- **Common in generated passwords**: Many secret management tools (Vault, AWS Secrets Manager, 1Password) generate passwords with special characters by default, making this bug likely to affect production deployments

**Who is affected:**

You are affected if ALL of the following are true:

1. Your database password (from `caradhras.secrets.DB_PASSWORD`, `caradhras.useExistingSecret`, or the chart-generated Secret) contains any of these characters: `'`, `"`, `\`, or other shell metacharacters
2. The Caradhras init container is enabled (it runs when `caradhras.createDatabase` is `true` or when the chart needs to initialize the database schema)

**Who is NOT affected:**

- Deployments where the database password contains only alphanumeric characters, hyphens, and underscores
- Deployments using an external database that is already initialized (the init container may still run, but the bug would not surface if the database already exists)

**What you need to do:**

**No action required for most deployments.** This is a transparent bug fix. The upgrade will apply the corrected escaping logic automatically.

**If you are currently experiencing init container failures:**

1. Check if your database password contains special characters:

```bash
kubectl get secret plugin-access-manager-caradhras -n plugin-access-manager -o jsonpath='{.data.DB_PASSWORD}' | base64 -d | grep -E "['\\\"]"
```

2. If the password contains special characters and the Caradhras pod is crash-looping, upgrade to v11.1.1 to apply the fix:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 11.1.1 -n plugin-access-manager
```

3. Verify the init container succeeds:

```bash
kubectl logs -n plugin-access-manager -l app.kubernetes.io/component=caradhras -c <init-container-name> --tail=20
```

You should see a successful database connection or schema initialization message.

**If you want to rotate to a password with special characters:**

You can now safely use passwords containing quotes, backslashes, or other special characters. Update your values file:

```yaml
caradhras:
  secrets:
    DB_PASSWORD: "my'complex\"password\\with$pecial"
```

Or use an existing Secret:

```yaml
caradhras:
  useExistingSecret: true
  existingSecretName: my-db-credentials
```

> **Important:** The escaping logic handles single quotes, double quotes, and backslashes. Other shell metacharacters (e.g., `$`, `` ` ``, `!`) are also escaped by the `sed` command. However, extremely complex passwords with newlines or null bytes are not supported by PostgreSQL DSN format and should be avoided.

**Technical details:**

The fix uses a two-step approach:

1. **Escape the password**: `sed -e 's/[\\'"'"']/\\&/g'` escapes backslashes and single quotes by prefixing them with a backslash
2. **Quote the password in the DSN**: The escaped password is wrapped in single quotes in the connection string: `password='${DB_PASSWORD_DSN}'`

This ensures the PostgreSQL driver receives the literal password value, regardless of special characters.

**Example:**

| Original Password | Escaped Password | DSN Fragment |
|-------------------|------------------|--------------|
| `simple123` | `simple123` | `password='simple123'` |
| `my'password` | `my\'password` | `password='my\'password'` |
| `pass"word` | `pass"word` | `password='pass"word'` |
| `back\slash` | `back\\slash` | `password='back\\slash'` |
| `complex'\"pass` | `complex\'\"pass` | `password='complex\'\"pass'` |

> **Note:** Double quotes do not need escaping inside single-quoted PostgreSQL DSN values, but the `sed` command escapes them anyway for consistency.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.1.1
```
<!-- {% endraw %} -->
