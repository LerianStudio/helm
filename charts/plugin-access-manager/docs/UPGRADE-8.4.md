# Helm Upgrade from v8.3.0 to v8.4.0

# Topics

- **[Features](#features)**
  - [1. Application Version Updates](#1-application-version-updates)
  - [2. Multi-Factor Authentication (MFA) Support](#2-multi-factor-authentication-mfa-support)
  - [3. Service Discovery Integration](#3-service-discovery-integration)
  - [4. Runtime and Deployment Configuration](#4-runtime-and-deployment-configuration)
  - [5. Cache Configuration Options](#5-cache-configuration-options)
  - [6. Authorizer Configuration for Identity Service](#6-authorizer-configuration-for-identity-service)
  - [7. Machine-to-Machine (M2M) Authentication](#7-machine-to-machine-m2m-authentication)
  - [8. Autoscaling Compatibility Fix](#8-autoscaling-compatibility-fix)
- **[Configuration Reference](#configuration-reference)**
  - [MFA Configuration](#mfa-configuration)
  - [Service Discovery Configuration](#service-discovery-configuration)
  - [Runtime Configuration](#runtime-configuration)
  - [Cache Configuration](#cache-configuration)
  - [Authorizer Configuration](#authorizer-configuration)
  - [M2M Configuration](#m2m-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Application Version Updates

This release updates the application versions for all services in the plugin-access-manager chart.

| Service | v8.3.0 | v8.4.0 |
|---------|--------|--------|
| Identity | 2.4.5 | 3.1.0 |
| Auth | 2.6.7 | 3.1.0 |
| Auth Backend | 2.6.7 | 3.1.0 |
| Init User Job | 2.6.1 | 3.1.0 |
| Auth Migrator | 2.6.3 | 3.1.0 |
| Chart appVersion | 2.6.7 | 3.1.0 |

**What this means for operators:**

This is a major version update (v2.x → v3.x) for all application components. The upgrade includes new features and capabilities detailed in the sections below. All services are now aligned to version 3.1.0 for consistency.

### 2. Multi-Factor Authentication (MFA) Support

The auth service now supports Multi-Factor Authentication (MFA) using TOTP (Time-based One-Time Password).

**What changed:**

A new secret variable `MFA_SECRET` has been added to the auth service configuration. This secret is used to sign and verify TOTP tokens for MFA functionality.

```yaml
auth:
  secrets:
    MFA_SECRET: ""
```

**Why this matters:**

- Enables TOTP-based MFA for enhanced security
- The feature remains dormant (inactive) when `MFA_SECRET` is empty
- When configured, users can enable two-factor authentication on their accounts

**How to enable MFA:**

To activate MFA functionality, provide a secure random string as the MFA signing secret:

```yaml
auth:
  secrets:
    MFA_SECRET: "your-secure-random-string-here"
```

> **Important:** Generate a cryptographically secure random string for production use. The MFA_SECRET should be treated as highly sensitive and rotated according to your security policies.

> **Note:** If you leave `MFA_SECRET` empty, the MFA feature will remain dormant and users will not be able to enable two-factor authentication.

### 3. Service Discovery Integration

Both identity and auth services now support integration with Consul for service discovery.

**What changed:**

New configuration options have been added to enable service discovery via Consul:

**Auth service:**

```yaml
auth:
  configmap:
    SD_ENABLED: "false"
    SD_ADDRESS: "localhost:8500"
    SD_EXTERNAL_ADDRESS: ""
    SD_EXTERNAL_PORT: "0"
    SD_TLS: "false"
  secrets:
    SD_TOKEN: ""
```

**Identity service:**

```yaml
identity:
  configmap:
    SD_ENABLED: "false"
    SD_ADDRESS: "localhost:8500"
    SD_EXTERNAL_ADDRESS: ""
    SD_EXTERNAL_PORT: "0"
    SD_TLS: "false"
  secrets:
    SD_TOKEN: ""
```

**Why this matters:**

- Enables dynamic service registration and discovery in Consul-based environments
- Services can automatically register themselves and discover other services
- Supports Consul ACL tokens for secure service mesh integration
- The feature is opt-in and disabled by default (`SD_ENABLED: "false"`)

**How to enable service discovery:**

```yaml
auth:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.default.svc.cluster.local:8500"
    SD_EXTERNAL_ADDRESS: "auth.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"
  secrets:
    SD_TOKEN: "your-consul-acl-token"

identity:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.default.svc.cluster.local:8500"
    SD_EXTERNAL_ADDRESS: "identity.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"
  secrets:
    SD_TOKEN: "your-consul-acl-token"
```

> **Note:** When `SD_ENABLED` is `false`, all service discovery configuration is ignored and the services operate in standalone mode.

> **Important:** If your Consul deployment uses ACL tokens, you must provide the `SD_TOKEN` secret. Leave it empty if your Consul instance does not require ACL authentication.

### 4. Runtime and Deployment Configuration

New runtime configuration options have been added to both auth and identity services for better deployment control.

**What changed:**

**Auth service:**

```yaml
auth:
  configmap:
    DEPLOYMENT_MODE: "local"
    TRUSTED_PROXIES: ""
    SWAGGER_ENABLED: "true"
```

**Identity service:**

```yaml
identity:
  configmap:
    DEPLOYMENT_MODE: "local"
    TRUSTED_PROXIES: ""
```

**Why this matters:**

- **DEPLOYMENT_MODE**: Controls deployment-specific behavior (e.g., `local`, `staging`, `production`)
- **TRUSTED_PROXIES**: Configures which proxy IPs to trust for X-Forwarded-* headers (important for correct client IP detection behind load balancers)
- **SWAGGER_ENABLED**: Controls whether the Swagger UI is available (auth service only)

**Configuration examples:**

For production deployments behind a load balancer:

```yaml
auth:
  configmap:
    DEPLOYMENT_MODE: "production"
    TRUSTED_PROXIES: "10.0.0.0/8,172.16.0.0/12"
    SWAGGER_ENABLED: "false"

identity:
  configmap:
    DEPLOYMENT_MODE: "production"
    TRUSTED_PROXIES: "10.0.0.0/8,172.16.0.0/12"
```

For development environments:

```yaml
auth:
  configmap:
    DEPLOYMENT_MODE: "local"
    TRUSTED_PROXIES: ""
    SWAGGER_ENABLED: "true"
```

> **Note:** The `TRUSTED_PROXIES` field accepts comma-separated CIDR ranges. Leave empty if not behind a proxy.

### 5. Cache Configuration Options

The auth service now provides fine-grained control over caching behavior for various data types.

**What changed:**

New cache configuration options have been added to the auth service:

```yaml
auth:
  configmap:
    CACHE_TTL_ACCESS_TOKEN: "0"
    CACHE_TTL_ENFORCE_FALLBACK: "0"
    CACHE_TTL_USER_INFO: "0"
    CACHE_TTL_USER_PERMISSIONS: "0"
    CACHE_TTL_ORG_PERMISSIONS: "0"
    CACHE_MAX_ENTRIES_ORG_PERMISSIONS: "0"
    CACHE_LOADER_TIMEOUT_ORG_PERMISSIONS: "0"
```

**Why this matters:**

- Allows tuning cache TTL (Time To Live) for different data types
- Controls cache size limits to manage memory usage
- Configures timeout values for cache loading operations
- Default value of `"0"` means the service uses built-in defaults from application constants

**Configuration examples:**

To customize cache behavior for better performance:

```yaml
auth:
  configmap:
    CACHE_TTL_ACCESS_TOKEN: "300"           # 5 minutes
    CACHE_TTL_USER_INFO: "600"              # 10 minutes
    CACHE_TTL_USER_PERMISSIONS: "300"       # 5 minutes
    CACHE_TTL_ORG_PERMISSIONS: "600"        # 10 minutes
    CACHE_MAX_ENTRIES_ORG_PERMISSIONS: "10000"
    CACHE_LOADER_TIMEOUT_ORG_PERMISSIONS: "5"  # 5 seconds
```

> **Note:** All TTL values are in seconds. Setting a value to `"0"` instructs the service to use its internal default value.

> **Important:** Increasing cache TTL values improves performance but may result in stale data. Balance TTL values according to your consistency requirements.

### 6. Authorizer Configuration for Identity Service

The identity service now includes explicit configuration for the Casbin authorization enforcer.

**What changed:**

New authorizer configuration options have been added to the identity service:

```yaml
identity:
  configmap:
    AUTHORIZER_ENFORCER_NAME: "lerian-user-enforcer"
    AUTHORIZER_MODEL_NAME: "api-model"
```

**Why this matters:**

- Provides explicit control over Casbin enforcer and model names
- Ensures consistency with the auth service's Casdoor configuration
- Allows customization for different authorization models if needed

**Default behavior:**

The default values align with the standard Lerian authorization model. Most operators will not need to change these values.

**Custom configuration example:**

If you need to use a different authorization model:

```yaml
identity:
  configmap:
    AUTHORIZER_ENFORCER_NAME: "custom-enforcer"
    AUTHORIZER_MODEL_NAME: "custom-model"
```

> **Note:** Only modify these values if you have a custom Casbin authorization model. The defaults work with the standard plugin-access-manager setup.

### 7. Machine-to-Machine (M2M) Authentication

The identity service now supports M2M authentication inversion for authorizing inbound service-to-service calls.

**What changed:**

A new configuration flag has been added to the identity service:

```yaml
identity:
  configmap:
    AUTH_M2M_INVERSION_ENABLED: "false"
```

**Why this matters:**

- Enables the identity service to authorize inbound M2M calls using lib-auth/v3 middleware
- Allows service-to-service authentication without user context
- The feature is disabled by default for backward compatibility

**How to enable M2M authentication:**

```yaml
identity:
  configmap:
    AUTH_M2M_INVERSION_ENABLED: "true"
```

> **Note:** This feature requires lib-auth/v3 middleware to be properly configured in your service mesh. Consult your service mesh documentation before enabling.

### 8. Autoscaling Compatibility Fix

All three services (identity, auth, and auth-backend) now properly support Horizontal Pod Autoscaling (HPA).

**What changed:**

The deployment templates have been updated to conditionally include the `replicas` field only when autoscaling is disabled.

**Before (v8.3.0):**

```yaml
# deployment.yaml
spec:
  replicas: {{ .Values.auth.replicaCount }}
```

**After (v8.4.0):**

```yaml
# deployment.yaml
spec:
  {{- if not .Values.auth.autoscaling.enabled }}
  replicas: {{ .Values.auth.replicaCount }}
  {{- end }}
```

**Why this matters:**

- Prevents conflicts between manually specified replica counts and HPA-managed replica counts
- When HPA is enabled, the HPA controller fully manages the replica count
- When HPA is disabled, the static `replicaCount` value is used

**Default behavior:**

If you have not configured autoscaling, this change has no impact. The static `replicaCount` continues to work as before.

**For operators using HPA:**

If you have autoscaling enabled, the deployment will no longer include a static replica count, allowing the HPA controller to manage scaling without conflicts:

```yaml
auth:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
```

> **Note:** This fix applies to all three services: identity, auth, and auth-backend.

# Configuration Reference

### MFA Configuration

Configure Multi-Factor Authentication for the auth service:

```yaml
auth:
  secrets:
    MFA_SECRET: ""
```

| Secret | Default | Description |
|--------|---------|-------------|
| `MFA_SECRET` | `""` (empty) | TOTP signing secret for MFA. When empty, MFA feature is dormant. Provide a secure random string to enable. |

### Service Discovery Configuration

Configure Consul service discovery for auth and identity services:

**Auth service:**

```yaml
auth:
  configmap:
    SD_ENABLED: "false"
    SD_ADDRESS: "localhost:8500"
    SD_EXTERNAL_ADDRESS: ""
    SD_EXTERNAL_PORT: "0"
    SD_TLS: "false"
  secrets:
    SD_TOKEN: ""
```

**Identity service:**

```yaml
identity:
  configmap:
    SD_ENABLED: "false"
    SD_ADDRESS: "localhost:8500"
    SD_EXTERNAL_ADDRESS: ""
    SD_EXTERNAL_PORT: "0"
    SD_TLS: "false"
  secrets:
    SD_TOKEN: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `SD_ENABLED` | `"false"` | Enable/disable service discovery. When `false`, all SD configuration is ignored. |
| `SD_ADDRESS` | `"localhost:8500"` | Consul agent address (host:port). |
| `SD_EXTERNAL_ADDRESS` | `""` (empty) | External address for service registration (e.g., public domain). |
| `SD_EXTERNAL_PORT` | `"0"` | External port for service registration. `0` means use internal port. |
| `SD_TLS` | `"false"` | Enable TLS for Consul communication. |
| `SD_TOKEN` | `""` (empty) | Consul ACL token for authentication. Leave empty if ACL is not enabled. |

### Runtime Configuration

Configure deployment mode and proxy settings:

**Auth service:**

```yaml
auth:
  configmap:
    DEPLOYMENT_MODE: "local"
    TRUSTED_PROXIES: ""
    SWAGGER_ENABLED: "true"
```

**Identity service:**

```yaml
identity:
  configmap:
    DEPLOYMENT_MODE: "local"
    TRUSTED_PROXIES: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `DEPLOYMENT_MODE` | `"local"` | Deployment environment mode (e.g., `local`, `staging`, `production`). |
| `TRUSTED_PROXIES` | `""` (empty) | Comma-separated CIDR ranges of trusted proxy IPs for X-Forwarded-* headers. |
| `SWAGGER_ENABLED` | `"true"` | Enable/disable Swagger UI (auth service only). |

### Cache Configuration

Configure caching behavior for the auth service:

```yaml
auth:
  configmap:
    CACHE_TTL_ACCESS_TOKEN: "0"
    CACHE_TTL_ENFORCE_FALLBACK: "0"
    CACHE_TTL_USER_INFO: "0"
    CACHE_TTL_USER_PERMISSIONS: "0"
    CACHE_TTL_ORG_PERMISSIONS: "0"
    CACHE_MAX_ENTRIES_ORG_PERMISSIONS: "0"
    CACHE_LOADER_TIMEOUT_ORG_PERMISSIONS: "0"
```

| Flag | Default | Description |
|------|---------|-------------|
| `CACHE_TTL_ACCESS_TOKEN` | `"0"` | TTL in seconds for access token cache. `0` = use built-in default. |
| `CACHE_TTL_ENFORCE_FALLBACK` | `"0"` | TTL in seconds for enforce fallback cache. `0` = use built-in default. |
| `CACHE_TTL_USER_INFO` | `"0"` | TTL in seconds for user info cache. `0` = use built-in default. |
| `CACHE_TTL_USER_PERMISSIONS` | `"0"` | TTL in seconds for user permissions cache. `0` = use built-in default. |
| `CACHE_TTL_ORG_PERMISSIONS` | `"0"` | TTL in seconds for organization permissions cache. `0` = use built-in default. |
| `CACHE_MAX_ENTRIES_ORG_PERMISSIONS` | `"0"` | Maximum number of entries in org permissions cache. `0` = use built-in default. |
| `CACHE_LOADER_TIMEOUT_ORG_PERMISSIONS` | `"0"` | Timeout in seconds for loading org permissions. `0` = use built-in default. |

### Authorizer Configuration

Configure Casbin authorization for the identity service:

```yaml
identity:
  configmap:
    AUTHORIZER_ENFORCER_NAME: "lerian-user-enforcer"
    AUTHORIZER_MODEL_NAME: "api-model"
```

| Flag | Default | Description |
|------|---------|-------------|
| `AUTHORIZER_ENFORCER_NAME` | `"lerian-user-enforcer"` | Name of the Casbin enforcer instance. |
| `AUTHORIZER_MODEL_NAME` | `"api-model"` | Name of the Casbin authorization model. |

### M2M Configuration

Configure Machine-to-Machine authentication for the identity service:

```yaml
identity:
  configmap:
    AUTH_M2M_INVERSION_ENABLED: "false"
```

| Flag | Default | Description |
|------|---------|-------------|
| `AUTH_M2M_INVERSION_ENABLED` | `"false"` | Enable M2M authentication inversion using lib-auth/v3 middleware. |

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.4.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.4.0 -n plugin-access-manager
```
