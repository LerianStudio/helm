# Helm Upgrade from v9.3.0 to v9.4.0

# Topics

- **[Features](#features)**
  - [1. Redis AUTH Password Support for Caradhras](#1-redis-auth-password-support-for-caradhras)
- **[Configuration Reference](#configuration-reference)**
  - [Caradhras Redis Password Configuration](#caradhras-redis-password-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Redis AUTH Password Support for Caradhras

The caradhras service now supports Redis/Valkey instances that require AUTH authentication through a new dedicated `redisPassword` configuration key.

**What changed:**

Previously, if your Redis required AUTH, you had to embed the password into the connection string in `caradhras.secrets.redisEndpoint` using Beego's positional format (`host:port,poolsize,password,dbnum`). This approach had two problems:

1. The password had to be manually spliced into the connection string
2. The password needed to be duplicated for both the session store and the rate limiter

Now, you can provide the Redis password separately via `caradhras.redisPassword`, and the caradhras application will automatically inject it into both Redis consumers (the Beego session store and the lib-commons rate limiter).

**Why this matters:**

- **Simpler configuration**: The `redisEndpoint` stays a clean `host:port` format with no password splicing required
- **Single source of truth**: One password configuration serves both Redis consumers
- **Better secret management**: The password is delivered via `secretKeyRef` (same mechanism as `DB_PASSWORD`), never exposed in ConfigMaps
- **Backward compatible**: Opt-in only — Redis instances without AUTH continue to work with no configuration changes

**Default behavior:**

The feature is **disabled by default**. If you don't enable `caradhras.redisPassword.enabled`, your existing configuration continues to work exactly as before. This ensures zero impact for operators using Redis without AUTH or those who already have passwords in their connection strings.

| Setting | v9.3.0 | v9.4.0 |
|---------|--------|--------|
| Redis password support | Manual embedding in connection string only | Dedicated `redisPassword` config key (opt-in) |
| Password injection method | N/A | `secretKeyRef` environment variable |
| Default state | N/A | Disabled (`caradhras.redisPassword.enabled: false`) |

**Before (v9.3.0):**

```yaml
# Redis with AUTH required embedding password in connection string
caradhras:
  secrets:
    redisEndpoint: "redis.example.com:6379,100,mySecretPassword,0"
```

**After (v9.4.0):**

```yaml
# Option 1: Keep existing approach (still supported)
caradhras:
  secrets:
    redisEndpoint: "redis.example.com:6379,100,mySecretPassword,0"

# Option 2: Use new dedicated password configuration (recommended)
caradhras:
  configmap:
    redisEndpoint: "redis.example.com:6379"  # Clean host:port only
  redisPassword:
    enabled: true
    # Defaults to auth Secret (where DB_PASSWORD already reads from)
    # secretName: ""  # Optional: override to use a different Secret
    # secretKey: REDIS_PASSWORD  # Optional: override to use a different key
```

**Template changes:**

The deployment template now conditionally injects the `redisPassword` environment variable when enabled:

**Before (v9.3.0):**

```yaml
# caradhras deployment - no redisPassword env
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "plugin-auth.dbPasswordSecretName" . }}
        key: {{ .Values.auth.dbPassword.secretKey | default "DB_PASSWORD" }}
```

**After (v9.4.0):**

```yaml
# caradhras deployment - conditional redisPassword env
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "plugin-auth.dbPasswordSecretName" . }}
        key: {{ .Values.auth.dbPassword.secretKey | default "DB_PASSWORD" }}
  {{- if include "plugin-caradhras.redisPasswordEnabled" . }}
  - name: redisPassword
    valueFrom:
      secretKeyRef:
        name: {{ include "plugin-caradhras.redisPasswordSecretName" . }}
        key: {{ $rp.secretKey | default "REDIS_PASSWORD" }}
  {{- end }}
```

**New validation rules:**

The chart now includes enhanced validation to prevent configuration conflicts:

1. **Password in ConfigMap detection**: If `caradhras.configmap.redisEndpoint` contains a password (third field in Beego's positional format), the chart fails with an error directing you to move it to `caradhras.secrets.redisEndpoint` or use an existing Secret
2. **Conflicting configuration detection**: If `caradhras.redisPassword.enabled` is true and your endpoint contains Beego savePath fields (commas), the chart fails because caradhras compares the endpoint's password field with `redisPassword` and refuses to boot when they differ
3. **Multi-replica session store requirement**: If caradhras runs with multiple replicas but has no shared session store configured, the chart fails with guidance to configure Redis or scale back to one replica

> **Important:** These validations run at `helm upgrade` time and will prevent deployment if configuration conflicts are detected. Review the error messages carefully — they include specific remediation steps.

# Configuration Reference

### Caradhras Redis Password Configuration

Configure Redis AUTH password for the caradhras service in your `values.yaml`:

```yaml
caradhras:
  redisPassword:
    # Opt-in flag - must be explicitly enabled
    enabled: false
    
    # Secret holding the password
    # Empty string defaults to the auth Secret (recommended)
    secretName: ""
    
    # Key inside that Secret
    # Defaults to REDIS_PASSWORD (already present in auth Secret)
    secretKey: REDIS_PASSWORD
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `enabled` | `false` | Opt-in flag to enable Redis password injection. Must be explicitly set to `true` |
| `secretName` | `""` (uses auth Secret) | Name of the Secret holding the Redis password. Empty defaults to the auth Secret where `DB_PASSWORD` already reads from |
| `secretKey` | `REDIS_PASSWORD` | Key inside the Secret containing the password value |

**How the default Secret resolution works:**

When `secretName` is empty (default), the chart resolves the Secret name using the same logic as the caradhras `DB_PASSWORD`:

- If `auth.useExistingSecret` is `false`: Uses the chart-managed auth Secret (template: `plugin-auth.fullname`)
- If `auth.useExistingSecret` is `true`: Uses `auth.existingSecretName` (you must provide this)

The chart-managed auth Secret already includes a `REDIS_PASSWORD` key (see `templates/auth/secrets.yaml`), so the default configuration works out of the box when using chart-managed secrets.

> **Note:** The `REDIS_PASSWORD` key in the auth Secret is populated from `auth.secrets.REDIS_PASSWORD` in your values.yaml.

#### Option 1: Use Default Secret (Recommended)

Let the password default to the auth Secret, which already carries `REDIS_PASSWORD`:

```yaml
caradhras:
  redisPassword:
    enabled: true
    # secretName: ""  # Defaults to auth Secret
    # secretKey: REDIS_PASSWORD  # Defaults to REDIS_PASSWORD

# Ensure the password is set in the auth Secret
auth:
  secrets:
    REDIS_PASSWORD: "your-redis-password-here"
```

#### Option 2: Use Custom Secret

Point to a different Secret you manage:

```yaml
caradhras:
  redisPassword:
    enabled: true
    secretName: "my-redis-credentials"
    secretKey: "password"
```

#### Option 3: Use Existing Secret with auth.useExistingSecret

If you manage the auth Secret externally:

```yaml
auth:
  useExistingSecret: true
  existingSecretName: "my-external-auth-secret"

caradhras:
  redisPassword:
    enabled: true
    # Defaults to my-external-auth-secret
    # secretKey: REDIS_PASSWORD
```

> **Warning:** When `auth.useExistingSecret` is `true`, you must set `auth.existingSecretName`. If you enable `caradhras.redisPassword` without providing `auth.existingSecretName`, the chart will fail with a validation error.

**New environment variable:**

When `caradhras.redisPassword.enabled` is `true`, the following environment variable is injected into the caradhras deployment:

| Variable | Source | Description |
|----------|--------|-------------|
| `redisPassword` | `secretKeyRef` from configured Secret | Redis AUTH password, delivered to both the Beego session store and lib-commons rate limiter |

**Migration steps for existing Redis AUTH users:**

If you currently embed the password in your connection string, follow these steps to migrate:

1. **Verify your current configuration** — check if `caradhras.secrets.redisEndpoint` or `caradhras.configmap.redisEndpoint` contains a password (third field after two commas)

2. **Extract the password** — copy the password value from your connection string

3. **Update your values.yaml**:

```yaml
# Before migration
caradhras:
  secrets:
    redisEndpoint: "redis.example.com:6379,100,mySecretPassword,0"

# After migration
caradhras:
  configmap:
    redisEndpoint: "redis.example.com:6379"  # Clean host:port only
  redisPassword:
    enabled: true

auth:
  secrets:
    REDIS_PASSWORD: "mySecretPassword"  # Moved here
```

4. **Test the upgrade** — use `helm diff` to preview changes before applying

5. **Apply the upgrade** — run the helm upgrade command

> **Note:** You can keep your existing connection string approach if preferred. The new `redisPassword` configuration is entirely optional.

**Validation error examples:**

If you encounter validation errors during upgrade, here's what they mean:

**Error: Password in ConfigMap**

```
Error: template: plugin-access-manager/templates/_helpers.tpl:489:5: executing "plugin-caradhras.sessionStoreValidation" at <fail ...>: 
caradhras.configmap.redisEndpoint carries a password. Move the whole connection string to caradhras.secrets.redisEndpoint...
```

**Resolution:** Move your connection string from `caradhras.configmap.redisEndpoint` to `caradhras.secrets.redisEndpoint`, or enable `caradhras.redisPassword` and use a clean `host:port` endpoint.

**Error: Conflicting password configuration**

```
Error: template: plugin-access-manager/templates/_helpers.tpl:495:5: executing "plugin-caradhras.sessionStoreValidation" at <fail ...>:
caradhras.redisPassword.enabled is true and the session endpoint "redis.example.com:6379,100,password,0" carries beego savePath fields...
```

**Resolution:** When using `caradhras.redisPassword.enabled: true`, the endpoint must be a bare `host:port` with no additional fields. Remove the poolsize, password, and dbnum fields from your endpoint.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.4.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.4.0 -n plugin-access-manager
```
