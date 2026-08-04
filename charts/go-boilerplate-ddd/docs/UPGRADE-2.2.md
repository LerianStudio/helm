# Helm Upgrade from v2.1.0 to v2.2.0

## Topics

- **[Features](#features)**
  - [1. Enhanced Security Context](#1-enhanced-security-context)
  - [2. Multi-Tenant Redis Password Security](#2-multi-tenant-redis-password-security)
  - [3. Chart Type Annotation](#3-chart-type-annotation)
- **[Configuration Reference](#configuration-reference)**
  - [Security Context Fields](#security-context-fields)
  - [Secret Fields](#secret-fields)
- **[Migration Steps](#migration-steps)**
  - [1. Update Default Passwords](#1-update-default-passwords)
  - [2. Configure Multi-Tenant Redis Password](#2-configure-multi-tenant-redis-password)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Enhanced Security Context

The pod security context has been enhanced with additional security hardening fields to align with Kubernetes security best practices.

**Before (v2.1.0):**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

**After (v2.2.0):**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
```

| Setting | v2.1.0 | v2.2.0 |
|---------|--------|--------|
| `allowPrivilegeEscalation` | Not set | `false` |
| `seccompProfile.type` | Not set | `RuntimeDefault` |

#### Operational Impact

These changes improve the security posture of your pods by:

- **`allowPrivilegeEscalation: false`**: Prevents processes from gaining more privileges than their parent process
- **`seccompProfile.type: RuntimeDefault`**: Applies the container runtime's default seccomp profile, restricting system calls

> **Note:** These settings are additive and do not require any changes to your application code. They are automatically applied when you upgrade to v2.2.0.

If your cluster enforces Pod Security Standards at the `restricted` level, these changes ensure compliance. No action is required unless you have custom security context overrides that conflict with these settings.

### 2. Multi-Tenant Redis Password Security

The multi-tenant Redis password has been moved from the ConfigMap to the Secret for improved security.

**Before (v2.1.0):**

The `MULTI_TENANT_REDIS_PASSWORD` was stored in the ConfigMap:

```yaml
# configmap.yaml
data:
  MULTI_TENANT_REDIS_PASSWORD: ""
```

**After (v2.2.0):**

The `MULTI_TENANT_REDIS_PASSWORD` is now stored in the Secret:

```yaml
# secrets.yaml
data:
  MULTI_TENANT_REDIS_PASSWORD: ""
```

| Setting | v2.1.0 | v2.2.0 |
|---------|--------|--------|
| `MULTI_TENANT_REDIS_PASSWORD` location | ConfigMap | Secret |

#### Operational Impact

Sensitive credentials should never be stored in ConfigMaps as they are not designed for secret data. This change ensures that the multi-tenant Redis password is properly encrypted at rest (if your cluster has encryption enabled) and is not visible in plain text through ConfigMap inspection.

> **Important:** If you are using multi-tenant mode with Redis authentication, you must now set `boilerplate.secrets.MULTI_TENANT_REDIS_PASSWORD` instead of `boilerplate.configmap.MULTI_TENANT_REDIS_PASSWORD`.

### 3. Chart Type Annotation

A new annotation has been added to the Chart.yaml metadata to categorize this chart as a single-service deployment.

```yaml
annotations:
  lerian.studio/chart-type: single-service
```

This is a metadata-only change with no operational impact. It helps with chart discovery and categorization in chart repositories.

## Configuration Reference

### Security Context Fields

Two new fields have been added to `boilerplate.securityContext`:

| Field | Default | Description |
|-------|---------|-------------|
| `allowPrivilegeEscalation` | `false` | Prevents processes from gaining more privileges than their parent |
| `seccompProfile.type` | `RuntimeDefault` | Applies the container runtime's default seccomp profile |

**Example configuration:**

```yaml
boilerplate:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
        - ALL
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
```

### Secret Fields

A new secret field has been added for multi-tenant Redis authentication:

| Field | Default | Description |
|-------|---------|-------------|
| `boilerplate.secrets.MULTI_TENANT_REDIS_PASSWORD` | `""` | Multi-tenant Redis password (empty if auth disabled) |

**Example configuration:**

```yaml
boilerplate:
  secrets:
    POSTGRES_PASSWORD: "your-postgres-password"
    REDIS_PASSWORD: "your-redis-password"
    MULTI_TENANT_SERVICE_API_KEY: "your-api-key"
    MULTI_TENANT_REDIS_PASSWORD: "your-multi-tenant-redis-password"
```

## Migration Steps

### 1. Update Default Passwords

Default password values have been changed from `"lerian"` to empty strings (`""`) for improved security. This affects the following fields:

| Field | v2.1.0 | v2.2.0 |
|-------|--------|--------|
| `global.postgresql.adminCredentials.password` | `"lerian"` | `""` |
| `global.postgresql.boilerplateCredentials.password` | `"lerian"` | `""` |
| `boilerplate.secrets.POSTGRES_PASSWORD` | `"lerian"` | `""` |

#### Option 1: Set passwords explicitly

If you are deploying a new instance or want to change passwords, set them explicitly in your `values.yaml`:

```yaml
global:
  postgresql:
    adminCredentials:
      password: "your-secure-admin-password"
    boilerplateCredentials:
      password: "your-secure-boilerplate-password"

boilerplate:
  secrets:
    POSTGRES_PASSWORD: "your-secure-boilerplate-password"
```

Then upgrade using:

```bash
helm upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.2.0 -n go-boilerplate-ddd -f values.yaml
```

#### Option 2: Use existing secrets

If you are already using existing secrets (recommended for production), ensure `useExistingSecret` is configured:

```yaml
global:
  postgresql:
    adminCredentials:
      useExistingSecret:
        name: "postgres-admin-secret"
    boilerplateCredentials:
      useExistingSecret:
        name: "postgres-boilerplate-secret"

boilerplate:
  useExistingSecret: true
  existingSecretName: "boilerplate-secrets"
```

> **Warning:** If you do not set passwords explicitly and are not using existing secrets, the chart will deploy with empty passwords, which may cause authentication failures.

### 2. Configure Multi-Tenant Redis Password

If you are using multi-tenant mode with Redis authentication, you must migrate the password configuration from ConfigMap to Secret.

**Before (v2.1.0):**

```yaml
boilerplate:
  configmap:
    MULTI_TENANT_REDIS_PASSWORD: "your-redis-password"
```

**After (v2.2.0):**

```yaml
boilerplate:
  secrets:
    MULTI_TENANT_REDIS_PASSWORD: "your-redis-password"
```

Update your `values.yaml` to move the password to the secrets section:

```yaml
boilerplate:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_REDIS_HOST: "redis.example.com"
    MULTI_TENANT_REDIS_PORT: "6379"
    MULTI_TENANT_REDIS_TLS: "true"
  secrets:
    MULTI_TENANT_REDIS_PASSWORD: "your-redis-password"
```

> **Note:** If your multi-tenant Redis instance does not require authentication, leave `MULTI_TENANT_REDIS_PASSWORD` as an empty string.

## Preview changes before upgrading

```bash
helm diff upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.2.0 -n go-boilerplate-ddd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.2.0 -n go-boilerplate-ddd
```
