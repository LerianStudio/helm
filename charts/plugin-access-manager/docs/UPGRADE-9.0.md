# Helm Upgrade from v8.x to v9.x

# Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. Component Names Now Derived from Release Name](#1-component-names-now-derived-from-release-name)
  - [2. Admin Password Now Required](#2-admin-password-now-required)
  - [3. Cross-Component DNS References Updated](#3-cross-component-dns-references-updated)
- **[Features](#features)**
  - [1. Centralized Authorizer Client ID](#1-centralized-authorizer-client-id)
  - [2. Automatic Service Discovery for Dependencies](#2-automatic-service-discovery-for-dependencies)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Identify Your Current Release Name](#step-1-identify-your-current-release-name)
  - [Step 2: Pin Component Names (If Not Using Default Release Name)](#step-2-pin-component-names-if-not-using-default-release-name)
  - [Step 3: Set Admin Password](#step-3-set-admin-password)
  - [Step 4: Review Cross-Component References](#step-4-review-cross-component-references)
- **[Configuration Reference](#configuration-reference)**
  - [Component Name Configuration](#component-name-configuration)
  - [Admin User Initialization](#admin-user-initialization)
  - [Cross-Component DNS Defaults](#cross-component-dns-defaults)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Breaking Changes

### 1. Component Names Now Derived from Release Name

**What changed:**

Component names (identity, auth, auth-backend) are now derived from the Helm release name instead of being hardcoded to `plugin-access-manager-*`.

| Component | v8.6.0 Default | v9.0.0 Default |
|-----------|----------------|----------------|
| Identity | `plugin-access-manager-identity` | `<release-name>-identity` |
| Auth | `plugin-access-manager-auth` | `<release-name>-auth` |
| Auth Backend | `plugin-access-manager-auth-backend` | `<release-name>-auth-backend` |

**Before (v8.6.0):**

```yaml
identity:
  name: "plugin-access-manager-identity"

auth:
  name: "plugin-access-manager-auth"
  backend:
    name: "plugin-access-manager-auth-backend"
```

**After (v9.0.0):**

```yaml
identity:
  # -- Component name. Empty derives it from the release name (<release>-identity),
  # which is what the cross-component DNS defaults resolve to. Set it only to pin a
  # legacy name, and remember every other component reference must then be pinned too.
  name: ""

auth:
  # -- Component name. Empty derives it from the release name (<release>-auth).
  name: ""
  backend:
    # -- Component name. Empty derives it from the release name (<release>-auth-backend).
    name: ""
```

**Why this matters:**

- **If your release is named `plugin-access-manager`**: No action required. Component names remain unchanged.
- **If your release has a different name** (e.g., `my-auth-plugin`): Component names will change to `my-auth-plugin-identity`, `my-auth-plugin-auth`, etc. This affects:
  - Kubernetes resource names (Deployments, Services, ConfigMaps, Secrets)
  - Service DNS names used for cross-component communication
  - Any external references to these services

**Operational impact:**

The upgrade will create new Deployments and Services with the new names. The old resources will remain until manually cleaned up. This can cause:
- Duplicate pods running simultaneously
- Service selector conflicts if not properly managed
- Potential downtime if external systems reference the old service names

> **Warning:** If you are not using the default release name `plugin-access-manager`, you MUST pin the component names to their v8.6.0 values to maintain continuity. See [Migration Steps](#migration-steps) below.

### 2. Admin Password Now Required

**What changed:**

The default admin password has been removed from `values.yaml`. The chart now fails installation if `auth.backend.initUser.adminPassword` is empty and `useExistingSecret` is false.

| Setting | v8.6.0 | v9.0.0 |
|---------|--------|--------|
| `auth.backend.initUser.adminPassword` | `"Lerian@123"` (default) | `""` (no default, required) |

**Before (v8.6.0):**

```yaml
auth:
  backend:
    initUser:
      adminPassword: "Lerian@123"
```

**After (v9.0.0):**

```yaml
auth:
  backend:
    initUser:
      # -- Admin password (will be stored in a secret). REQUIRED when initUser is
      # -- enabled and useExistingSecret is false — the install fails loud if it is
      # -- empty. The chart ships no default on purpose: a published default password
      # -- on the platform admin account is a live credential in every install that
      # -- never overrode it.
      adminPassword: ""
```

**Why this matters:**

Publishing a default password for the platform admin account creates a security vulnerability in every installation that doesn't explicitly override it. The chart now enforces that operators must consciously set a password.

**Operational impact:**

- Upgrades will fail if you don't provide a password via `values.yaml` or `--set`
- If you were relying on the default password `Lerian@123`, you must now explicitly set it (or choose a new secure password)

> **Important:** You must set `auth.backend.initUser.adminPassword` in your values or use an existing secret. See [Step 3: Set Admin Password](#step-3-set-admin-password) for instructions.

### 3. Cross-Component DNS References Updated

**What changed:**

Default values for cross-component DNS references have been removed from `values.yaml` and are now computed dynamically in templates based on the release name.

| Setting | v8.6.0 Default | v9.0.0 Default |
|---------|----------------|----------------|
| `identity.configmap.AUTH_ADDRESS` | `http://plugin-access-manager-auth:4000` | Computed: `http://<release>-auth:4000` |
| `identity.configmap.AUTHORIZER_CLIENT_ID` | `{{ .Values.common.authorizer.clientId }}` | Computed from `common.authorizer.clientId` |
| `auth.configmap.DB_HOST` | `plugin-access-manager-auth-database` | Computed from subchart fullname |
| `auth.configmap.REDIS_HOST` | `plugin-access-manager-valkey-primary` | Computed from subchart fullname |
| `auth.configmap.AUTHORIZER_CLIENT_ID` | `ac56c81d4d6d95c0ac12` | Computed from `common.authorizer.clientId` |

**Before (v8.6.0):**

```yaml
identity:
  configmap:
    AUTH_ADDRESS: "http://plugin-access-manager-auth:4000"
    AUTHORIZER_CLIENT_ID: "{{ .Values.common.authorizer.clientId }}"

auth:
  configmap:
    DB_HOST: "plugin-access-manager-auth-database"
    REDIS_HOST: "plugin-access-manager-valkey-primary"
    AUTHORIZER_CLIENT_ID: "ac56c81d4d6d95c0ac12"
```

**After (v9.0.0):**

```yaml
identity:
  configmap:
    # AUTH_ADDRESS defaults to http://<auth component>:4000 (templates/identity/configmap.yaml).
    # Set it only to point identity at an auth outside this release.

auth:
  configmap:
    # DB_HOST defaults to the bundled auth-database Service (templates/auth/configmap.yaml).
    # Set it only for an external database.
    # REDIS_HOST defaults to the bundled valkey primary Service (templates/auth/configmap.yaml).
    # Set it only for an external Redis/Valkey.
```

**Why this matters:**

- The hardcoded references only worked when the release was named `plugin-access-manager`
- With any other release name, the DNS references pointed to non-existent services
- Init containers waiting for dependencies would block forever
- The new dynamic computation ensures DNS names match actual Service names

**Operational impact:**

If you have explicitly set any of these values in your `values.yaml` to override the defaults, those overrides will continue to work. If you were relying on the defaults, they will now automatically resolve to the correct service names based on your release name.

> **Note:** You only need to set these values if you're pointing to external services outside the Helm release (e.g., an external database or Redis cluster).

# Features

### 1. Centralized Authorizer Client ID

**What changed:**

A new `common.authorizer.clientId` field has been added to centralize the authorizer client ID configuration, which is shared by both identity and auth components.

**New configuration:**

```yaml
common:
  # Common secrets and configurations
  authorizer:
    # -- Casdoor application client id, shared by the identity and auth components.
    # Consumed by templates/{identity,auth}/configmap.yaml — values.yaml is NOT
    # templated by Helm, so components must never self-reference this with `{{ }}`.
    # Per-component override: {identity,auth}.configmap.AUTHORIZER_CLIENT_ID.
    clientId: "ac56c81d4d6d95c0ac12"
```

**Why this matters:**

Previously, the authorizer client ID was duplicated in multiple places:
- Hardcoded in `auth.configmap.AUTHORIZER_CLIENT_ID`
- Referenced via template syntax in `identity.configmap.AUTHORIZER_CLIENT_ID`

Now there's a single source of truth that both components reference.

**How to use it:**

Set the client ID once in the `common` section:

```yaml
common:
  authorizer:
    clientId: "your-custom-client-id"
```

Both identity and auth components will automatically use this value. You can still override it per-component if needed:

```yaml
identity:
  configmap:
    AUTHORIZER_CLIENT_ID: "identity-specific-client-id"

auth:
  configmap:
    AUTHORIZER_CLIENT_ID: "auth-specific-client-id"
```

### 2. Automatic Service Discovery for Dependencies

**What changed:**

The chart now includes template helpers that automatically discover the correct service names for bundled dependencies (auth-database, valkey) based on the release name and subchart configuration.

**New template helpers:**

- `plugin-access-manager.authDatabaseHost`: Resolves the auth-database (PostgreSQL) primary service name
- `plugin-access-manager.valkeyHost`: Resolves the valkey primary service name

**Before (v8.6.0):**

```yaml
# templates/auth/configmap.yaml
data:
  DB_HOST: {{ .Values.auth.configmap.DB_HOST | default (printf "plugin-access-manager-authdb.%s.svc.cluster.local." .Release.Namespace) | quote }}
  REDIS_HOST: {{ printf "%s:%s" (.Values.auth.configmap.REDIS_HOST | default (printf "plugin-access-manager-valkey-primary.%s.svc.cluster.local" .Release.Namespace)) (.Values.auth.configmap.REDIS_PORT | default "6379" | toString) | quote }}
```

**After (v9.0.0):**

```yaml
# templates/auth/configmap.yaml
data:
  DB_HOST: {{ .Values.auth.configmap.DB_HOST | default (include "plugin-access-manager.authDatabaseHost" .) | quote }}
  REDIS_HOST: {{ printf "%s:%s" (.Values.auth.configmap.REDIS_HOST | default (include "plugin-access-manager.valkeyHost" .)) (.Values.auth.configmap.REDIS_PORT | default "6379" | toString) | quote }}
```

**Why this matters:**

- Service names now automatically follow the release name and Bitnami subchart naming conventions
- Honors `nameOverride` and `fullnameOverride` settings in subcharts
- Eliminates hardcoded service names that only worked with the default release name
- Prevents init container deadlocks caused by incorrect DNS references

**Operational impact:**

If you're using the bundled database and Redis/Valkey (default configuration), service discovery now works correctly regardless of your release name. No configuration changes required.

If you're using external database or Redis, continue setting the explicit values:

```yaml
auth:
  configmap:
    DB_HOST: "external-postgres.example.com"
    REDIS_HOST: "external-redis.example.com"
```

# Migration Steps

### Step 1: Identify Your Current Release Name

First, determine the name of your existing Helm release:

```bash
helm list -n plugin-access-manager
```

Look for the release name in the `NAME` column. Common examples:
- `plugin-access-manager` (default)
- `pam`
- `auth-plugin`
- Custom names specific to your deployment

### Step 2: Pin Component Names (If Not Using Default Release Name)

> **Important:** Only follow this step if your release name is NOT `plugin-access-manager`.

If your release has a custom name, you must pin the component names to maintain continuity with v8.6.0:

```yaml
identity:
  name: "plugin-access-manager-identity"

auth:
  name: "plugin-access-manager-auth"
  backend:
    name: "plugin-access-manager-auth-backend"
```

Add these settings to your `values.yaml` or pass them via `--set`:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 9.0.0 \
  -n plugin-access-manager \
  --set identity.name="plugin-access-manager-identity" \
  --set auth.name="plugin-access-manager-auth" \
  --set auth.backend.name="plugin-access-manager-auth-backend"
```

> **Note:** If you pin component names, you should also verify that cross-component DNS references are correct. The defaults will still work because they now compute based on the actual component names.

#### Alternative: Embrace the New Naming Convention

If you prefer to adopt the new release-based naming convention:

1. Accept that new Deployments and Services will be created with new names
2. Plan for a brief transition period where both old and new resources exist
3. Update any external references (ingress rules, monitoring, etc.) to use the new service names
4. Clean up old resources after verifying the new deployment works:

```bash
# List old resources
kubectl get deployments,services -n plugin-access-manager -l app.kubernetes.io/instance=<your-release-name>

# Delete old resources (example)
kubectl delete deployment plugin-access-manager-identity -n plugin-access-manager
kubectl delete deployment plugin-access-manager-auth -n plugin-access-manager
kubectl delete deployment plugin-access-manager-auth-backend -n plugin-access-manager
kubectl delete service plugin-access-manager-identity -n plugin-access-manager
kubectl delete service plugin-access-manager-auth -n plugin-access-manager
kubectl delete service plugin-access-manager-auth-backend -n plugin-access-manager
```

> **Warning:** Only delete old resources after confirming the new deployment is fully operational and all external integrations have been updated.

### Step 3: Set Admin Password

The chart now requires an explicit admin password. Choose one of the following options:

#### Option 1: Set Password in values.yaml

Add the password to your `values.yaml`:

```yaml
auth:
  backend:
    initUser:
      enabled: true
      adminPassword: "YourSecurePassword123!"
```

#### Option 2: Set Password via --set Flag

Pass the password during upgrade:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 9.0.0 \
  -n plugin-access-manager \
  --set auth.backend.initUser.adminPassword="YourSecurePassword123!"
```

#### Option 3: Use Existing Secret

If you manage secrets externally:

```yaml
auth:
  backend:
    initUser:
      enabled: true
      useExistingSecret: true
      adminPasswordSecretName: "my-admin-password-secret"
      adminPasswordSecretKey: "password"
```

> **Important:** If you were using the default password `Lerian@123` in v8.6.0, you must now explicitly set it. For production environments, choose a strong, unique password.

### Step 4: Review Cross-Component References

Check if you have explicitly set any of these values in your current `values.yaml`:

- `identity.configmap.AUTH_ADDRESS`
- `identity.configmap.AUTHORIZER_ADDRESS`
- `auth.configmap.DB_HOST`
- `auth.configmap.REDIS_HOST`
- `auth.configmap.AUTHORIZER_ADDRESS`

**If you have NOT set these values:**

No action required. The chart will automatically compute the correct DNS names based on your release name.

**If you HAVE set these values:**

Review whether they still point to the correct services:

```yaml
# Example: If you're using external services
auth:
  configmap:
    DB_HOST: "external-postgres.example.com"
    REDIS_HOST: "external-redis.example.com"
```

Keep these overrides if they point to external services. Remove them if they were workarounds for the old hardcoded defaults.

# Configuration Reference

### Component Name Configuration

Control how component names are derived:

```yaml
identity:
  # -- Component name. Empty derives it from the release name (<release>-identity),
  # which is what the cross-component DNS defaults resolve to. Set it only to pin a
  # legacy name, and remember every other component reference must then be pinned too.
  name: ""

auth:
  # -- Component name. Empty derives it from the release name (<release>-auth).
  name: ""
  backend:
    # -- Component name. Empty derives it from the release name (<release>-auth-backend).
    name: ""
```

| Field | Default | Description |
|-------|---------|-------------|
| `identity.name` | `""` (derives `<release>-identity`) | Override to pin a specific identity component name |
| `auth.name` | `""` (derives `<release>-auth`) | Override to pin a specific auth component name |
| `auth.backend.name` | `""` (derives `<release>-auth-backend`) | Override to pin a specific auth-backend component name |

**Example: Pin all component names to v8.6.0 defaults**

```yaml
identity:
  name: "plugin-access-manager-identity"

auth:
  name: "plugin-access-manager-auth"
  backend:
    name: "plugin-access-manager-auth-backend"
```

### Admin User Initialization

Configure the admin user created during initial setup:

```yaml
auth:
  backend:
    initUser:
      # -- Enable admin user initialization on first startup
      enabled: true
      # -- Admin username
      adminName: "admin"
      # -- Admin email address
      adminEmail: "admin@midaz.tech"
      # -- Admin user display name
      adminDisplayName: "Admin"
      # -- Admin password (will be stored in a secret). REQUIRED when initUser is
      # -- enabled and useExistingSecret is false — the install fails loud if it is
      # -- empty. The chart ships no default on purpose: a published default password
      # -- on the platform admin account is a live credential in every install that
      # -- never overrode it.
      adminPassword: ""
      # -- Use existing secret for admin password instead of creating one
      # -- IMPORTANT: If set to true, adminPasswordSecretName MUST be specified
      useExistingSecret: false
      # -- Name of existing secret containing admin password
      adminPasswordSecretName: ""
      # -- Key in existing secret containing admin password
      adminPasswordSecretKey: "password"
```

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `true` | Whether to create an admin user on first startup |
| `adminName` | `"admin"` | Username for the admin account |
| `adminEmail` | `"admin@midaz.tech"` | Email address for the admin account |
| `adminDisplayName` | `"Admin"` | Display name for the admin account |
| `adminPassword` | `""` | **REQUIRED** password for the admin account |
| `useExistingSecret` | `false` | Use an existing Kubernetes secret for the password |
| `adminPasswordSecretName` | `""` | Name of existing secret (required if `useExistingSecret: true`) |
| `adminPasswordSecretKey` | `"password"` | Key in the secret containing the password |

> **Warning:** The upgrade will fail if `enabled: true`, `useExistingSecret: false`, and `adminPassword` is empty.

### Cross-Component DNS Defaults

The following environment variables now have automatic defaults computed from the release name. Set them only to override the defaults (e.g., for external services):

**Identity component:**

```yaml
identity:
  configmap:
    # AUTH_ADDRESS defaults to http://<auth component>:4000 (templates/identity/configmap.yaml).
    # Set it only to point identity at an auth outside this release.
    AUTH_ADDRESS: ""
    
    # AUTHORIZER_ADDRESS defaults to http://<auth-backend component>:8000
    AUTHORIZER_ADDRESS: ""
    
    # AUTHORIZER_CLIENT_ID defaults to common.authorizer.clientId
    AUTHORIZER_CLIENT_ID: ""
```

**Auth component:**

```yaml
auth:
  configmap:
    # DB_HOST defaults to the bundled auth-database Service (templates/auth/configmap.yaml).
    # Set it only for an external database.
    DB_HOST: ""
    
    # REDIS_HOST defaults to the bundled valkey primary Service (templates/auth/configmap.yaml).
    # Set it only for an external Redis/Valkey.
    REDIS_HOST: ""
    
    # AUTHORIZER_ADDRESS defaults to http://<auth-backend component>:8000
    AUTHORIZER_ADDRESS: ""
    
    # AUTHORIZER_CLIENT_ID defaults to common.authorizer.clientId
    AUTHORIZER_CLIENT_ID: ""
```

| Variable | Computed Default | When to Override |
|----------|------------------|------------------|
| `AUTH_ADDRESS` | `http://<release>-auth:4000` | Pointing to auth service outside this release |
| `AUTHORIZER_ADDRESS` | `http://<release>-auth-backend:8000` | Pointing to auth-backend outside this release |
| `DB_HOST` | `<release>-auth-database` | Using external PostgreSQL database |
| `REDIS_HOST` | `<release>-valkey-primary` | Using external Redis/Valkey cluster |
| `AUTHORIZER_CLIENT_ID` | `common.authorizer.clientId` | Component needs different client ID |

**Example: Using external database and Redis**

```yaml
auth:
  configmap:
    DB_HOST: "postgres.example.com"
    DB_PORT: 5432
    REDIS_HOST: "redis.example.com"
    REDIS_PORT: 6379
```

**Example: Pointing identity at external auth service**

```yaml
identity:
  configmap:
    AUTH_ADDRESS: "http://external-auth.example.com:4000"
    AUTHORIZER_ADDRESS: "http://external-auth-backend.example.com:8000"
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.0.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.0.0 -n plugin-access-manager
```
