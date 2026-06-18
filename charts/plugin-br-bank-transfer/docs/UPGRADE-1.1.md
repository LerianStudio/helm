# Helm Upgrade from v1.0.0 to v1.1.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Default Passwords Removed](#1-default-passwords-removed)
  - [2. RabbitMQ Erlang Cookie Required](#2-rabbitmq-erlang-cookie-required)
  - [3. JD_PRIVATE_KEY_KEYINFO Moved to Secret](#3-jd_private_key_keyinfo-moved-to-secret)
- **[Security Enhancements](#security-enhancements)**
  - [1. Enhanced Container Security Context](#1-enhanced-container-security-context)
  - [2. Single-Source Infrastructure Secrets](#2-single-source-infrastructure-secrets)
- **[Dependency Updates](#dependency-updates)**
- **[Configuration Reference](#configuration-reference)**
  - [New Security Context Fields](#new-security-context-fields)
  - [Modified Secret Fields](#modified-secret-fields)
  - [New Template Helpers](#new-template-helpers)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Supply Required Passwords](#step-1-supply-required-passwords)
  - [Step 2: Generate RabbitMQ Erlang Cookie](#step-2-generate-rabbitmq-erlang-cookie)
  - [Step 3: Migrate JD_PRIVATE_KEY_KEYINFO](#step-3-migrate-jd_private_key_keyinfo)
  - [Step 4: Review Security Context Changes](#step-4-review-security-context-changes)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.1.0 introduces **breaking changes** that require operator action before upgrading. This release removes default passwords for all infrastructure components (PostgreSQL, MongoDB, Valkey, RabbitMQ), enhances container security posture, and refactors secret management to follow single-source principles. Operators **must** supply explicit credentials and a stable RabbitMQ Erlang cookie before upgrading.

The chart also updates PostgreSQL and MongoDB subchart dependencies to their latest patch versions and moves the `JD_PRIVATE_KEY_KEYINFO` configuration from ConfigMap to Secret for improved security.

## Breaking Changes

### 1. Default Passwords Removed

**What changed:**  
All default passwords (`"lerian"`, `"replicator_password"`, etc.) have been removed from `values.yaml`. The chart now requires operators to explicitly provide credentials for all infrastructure components.

**Why it matters:**  
Hardcoded default passwords are a security risk. This change enforces explicit credential management and prevents accidental production deployments with weak defaults.

**Affected components:**

| Component | Field | v1.0.0 Default | v1.1.0 Default |
|-----------|-------|----------------|----------------|
| PostgreSQL (admin) | `global.externalPostgresDefinitions.adminCredentials.password` | `"lerian"` | `""` (empty) |
| PostgreSQL (app user) | `global.externalPostgresDefinitions.bankTransferCredentials.password` | `"lerian"` | `""` (empty) |
| PostgreSQL (bundled admin) | `postgresql.auth.postgresPassword` | `"lerian"` | `""` (empty) |
| PostgreSQL (bundled app user) | `postgresql.auth.password` | `"lerian"` | `""` (empty) |
| PostgreSQL (bundled replication) | `postgresql.auth.replicationPassword` | `"replicator_password"` | `""` (empty) |
| MongoDB (admin) | `mongodb.auth.rootPassword` | `"lerian"` | `""` (empty) |
| MongoDB (app user) | `mongodb.auth.passwords[0]` | `"lerian"` | `""` (empty) |
| Valkey | `valkey.auth.password` | `"lerian"` | `""` (empty) |
| RabbitMQ (admin) | `global.externalRabbitmqDefinitions.adminCredentials.password` | `"lerian"` | `""` (empty) |
| RabbitMQ (app user) | `global.externalRabbitmqDefinitions.bankTransferCredentials.password` | `"lerian"` | `""` (empty) |
| RabbitMQ (bundled) | `rabbitmq.auth.password.value` | `"lerian"` | `""` (empty) |
| Application secrets | `bankTransfer.secrets.POSTGRES_PASSWORD` | `"lerian"` | `""` (empty) |
| Application secrets | `bankTransfer.secrets.REDIS_PASSWORD` | `"lerian"` | `""` (empty) |
| Application secrets | `bankTransfer.secrets.MONGO_PASSWORD` | `"lerian"` | `""` (empty) |

**Migration required:**  
Yes — see [Migration Steps](#migration-steps) below.

### 2. RabbitMQ Erlang Cookie Required

**What changed:**  
The default RabbitMQ Erlang cookie has been removed. Operators must now supply a stable cookie value when `rabbitmq.enabled=true`.

**Before (v1.0.0):**
```yaml
rabbitmq:
  auth:
    erlangCookie:
      value: "WCB00CfurKivfNH61hbxPaNg+xtyA/7RI6bEx5RMGvE="
```

**After (v1.1.0):**
```yaml
rabbitmq:
  auth:
    erlangCookie:
      # Operators MUST supply a stable cookie (e.g. openssl rand -base64 32) when rabbitmq.enabled=true.
      value: ""
```

**Why it matters:**  
The Erlang cookie is used for inter-node authentication in RabbitMQ clusters. Using a default cookie across deployments is a security risk. A stable, operator-managed cookie is required for cluster formation and must persist across upgrades.

**Migration required:**  
Yes — see [Step 2: Generate RabbitMQ Erlang Cookie](#step-2-generate-rabbitmq-erlang-cookie).

### 3. JD_PRIVATE_KEY_KEYINFO Moved to Secret

**What changed:**  
The `JD_PRIVATE_KEY_KEYINFO` configuration field has been moved from `bankTransfer.configmap` to `bankTransfer.secrets`.

**Before (v1.0.0):**
```yaml
bankTransfer:
  configmap:
    JD_PRIVATE_KEY_KEYINFO: ""  # key metadata for external signing providers
```

**After (v1.1.0):**
```yaml
bankTransfer:
  secrets:
    JD_PRIVATE_KEY_KEYINFO: ""  # key metadata for external signing providers (credential-like → Secret)
```

**Why it matters:**  
`JD_PRIVATE_KEY_KEYINFO` may contain credential-like metadata (key identifiers, provider tokens, etc.) that should not be exposed in a ConfigMap. Moving it to a Secret improves security posture.

**Operational impact:**  
- The field is no longer rendered in the ConfigMap template (`templates/configmap.yaml`)
- It is now rendered in the Secret template (`templates/secrets.yaml`)
- The deployment continues to read it from the same Secret via `envFrom: secretRef`

**Migration required:**  
Yes, if you currently set `bankTransfer.configmap.JD_PRIVATE_KEY_KEYINFO` — see [Step 3: Migrate JD_PRIVATE_KEY_KEYINFO](#step-3-migrate-jd_private_key_keyinfo).

## Security Enhancements

### 1. Enhanced Container Security Context

**What changed:**  
The default `securityContext` for the bank-transfer container now includes additional hardening fields.

**Before (v1.0.0):**
```yaml
bankTransfer:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
```

**After (v1.1.0):**
```yaml
bankTransfer:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    capabilities:
      drop:
        - ALL
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
```

**New fields:**

| Field | Default | Description |
|-------|---------|-------------|
| `allowPrivilegeEscalation` | `false` | Prevents the container from gaining more privileges than its parent process |
| `seccompProfile.type` | `RuntimeDefault` | Applies the default seccomp profile (restricts syscalls) |

**Why it matters:**  
These fields align the chart with Pod Security Standards (PSS) "restricted" profile and reduce the container's attack surface. They are non-breaking (additive) and can be overridden via `bankTransfer.securityContext` if your environment requires different settings.

**Migration required:**  
No — changes are additive and backward-compatible. Review [Step 4: Review Security Context Changes](#step-4-review-security-context-changes) if you override `securityContext`.

### 2. Single-Source Infrastructure Secrets

**What changed:**  
The chart now implements a "single-source" pattern for infrastructure secrets (PostgreSQL, Valkey, MongoDB). When using bundled Bitnami subcharts, the application deployment reads passwords directly from the subchart-generated Secrets via `secretKeyRef` instead of duplicating them in the application Secret.

**Template changes:**

**Before (v1.0.0):**
```yaml
# templates/deployment.yaml (envFrom only)
envFrom:
  - secretRef:
      name: {{ include "bank-transfer.fullname" . }}
  - configMapRef:
      name: {{ include "bank-transfer.fullname" . }}
```

**After (v1.1.0):**
```yaml
# templates/deployment.yaml (envFrom + explicit env with secretKeyRef)
envFrom:
  - secretRef:
      name: {{ include "bank-transfer.fullname" . }}
  - configMapRef:
      name: {{ include "bank-transfer.fullname" . }}
env:
  # PostgreSQL password from subchart Secret (if bundled) or app Secret (if external)
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: <release>-postgresql  # or app Secret for external
        key: password
  # Valkey password from subchart Secret (if bundled) or app Secret (if external)
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: <release>-valkey
        key: valkey-password
  # MongoDB password from subchart Secret (if bundled) or app Secret (if external)
  - name: MONGO_PASSWORD
    valueFrom:
      secretKeyRef:
        name: <release>-mongodb
        key: mongodb-passwords
  # MONGO_URI assembled via $(MONGO_PASSWORD) shell expansion
  - name: MONGO_URI
    value: "mongodb://bank_transfer:$(MONGO_PASSWORD)@<release>-mongodb.<namespace>.svc.cluster.local:27017/?authSource=admin"
```

**Why it matters:**  
- **Bundled subcharts:** Passwords are generated once by the subchart and read directly by the application — no duplication, no drift
- **External infrastructure:** Passwords are still written to the application Secret (for backward compatibility) but only when the external component does not use an `existingSecret` override
- **MongoDB URI assembly:** The application is URI-only; the chart now builds `MONGO_URI` on the deployment using `$(MONGO_PASSWORD)` expansion instead of embedding plaintext passwords in the Secret

**Operational impact:**  
- When using bundled PostgreSQL/Valkey/MongoDB, the application Secret (`templates/secrets.yaml`) no longer contains `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, or `MONGO_PASSWORD` — they are read from subchart Secrets
- When using external infrastructure **without** an `existingSecret` override, you must still set `bankTransfer.secrets.POSTGRES_PASSWORD`, `bankTransfer.secrets.REDIS_PASSWORD`, and `bankTransfer.secrets.MONGO_PASSWORD` (the chart writes them to the application Secret for the deployment to read)
- When using external infrastructure **with** an `existingSecret` override (e.g., `postgresql.auth.existingSecret`), the deployment reads from that Secret directly

**Migration required:**  
No — the change is transparent to operators. Existing `bankTransfer.secrets.*` overrides continue to work. See [Step 1: Supply Required Passwords](#step-1-supply-required-passwords) for credential requirements.

## Dependency Updates

The chart updates two Bitnami subchart dependencies to their latest patch versions:

| Subchart | v1.0.0 | v1.1.0 | Change Type |
|----------|--------|--------|-------------|
| `postgresql` | `16.3` | `16.3.5` | Patch |
| `mongodb` | `16.4` | `16.4.12` | Patch |

**Why it matters:**  
Patch updates include bug fixes and security patches. No breaking changes are expected.

**Migration required:**  
No — patch updates are backward-compatible.

## Configuration Reference

### New Security Context Fields

Add these fields to `bankTransfer.securityContext` if you need to override the new defaults:

```yaml
bankTransfer:
  securityContext:
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

| Field | Default | Description |
|-------|---------|-------------|
| `allowPrivilegeEscalation` | `false` | Prevents privilege escalation |
| `seccompProfile.type` | `RuntimeDefault` | Applies default seccomp profile |

### Modified Secret Fields

The following fields have moved or changed behavior:

| Field | v1.0.0 Location | v1.1.0 Location | Notes |
|-------|-----------------|-----------------|-------|
| `JD_PRIVATE_KEY_KEYINFO` | `bankTransfer.configmap` | `bankTransfer.secrets` | Moved to Secret for security |
| `MONGO_PASSWORD` | `bankTransfer.secrets` (always written) | `bankTransfer.secrets` (written only for external MongoDB without `existingSecret`) | Single-sourced from subchart Secret when bundled |
| `POSTGRES_PASSWORD` | `bankTransfer.secrets` (always written) | `bankTransfer.secrets` (written only for external PostgreSQL without `existingSecret`) | Single-sourced from subchart Secret when bundled |
| `REDIS_PASSWORD` | `bankTransfer.secrets` (always written) | `bankTransfer.secrets` (written only for external Valkey without `existingSecret`) | Single-sourced from subchart Secret when bundled |

### New Template Helpers

Three new template helpers support the single-source secret pattern:

| Helper | Purpose |
|--------|---------|
| `bank-transfer.infraSecretRef` | Emits a `secretKeyRef` env entry pointing at a Bitnami subchart Secret (or `existingSecret` override) |
| `bank-transfer.mongoInternal` | Returns `true` when the bundled MongoDB subchart is enabled |
| `bank-transfer.mongoEnv` | Emits `MONGO_PASSWORD` (secretKeyRef) and `MONGO_URI` (assembled via `$(MONGO_PASSWORD)` expansion) |
| `bank-transfer.migrationPostgresPassword` | Gate helper for the migration-only Secret (external PostgreSQL path) |
| `common.names.dependency.fullname` | Vendored from Bitnami common; computes subchart Secret/Service names honoring `nameOverride`/`fullnameOverride` |

## Migration Steps

### Step 1: Supply Required Passwords

You must explicitly set passwords for all enabled infrastructure components. Choose one of the following approaches:

#### Option 1: Use Helm values (recommended for non-production)

Create a `values-override.yaml` file with strong, randomly generated passwords:

```yaml
# PostgreSQL (if using bundled subchart with postgresql.enabled=true)
postgresql:
  auth:
    postgresPassword: "<strong-random-password>"
    password: "<strong-random-password>"
    replicationPassword: "<strong-random-password>"

# MongoDB (if using bundled subchart with mongodb.enabled=true)
mongodb:
  auth:
    rootPassword: "<strong-random-password>"
    passwords:
      - "<strong-random-password>"

# Valkey (if using bundled subchart with valkey.enabled=true)
valkey:
  auth:
    password: "<strong-random-password>"

# RabbitMQ (if using bundled subchart with rabbitmq.enabled=true)
rabbitmq:
  auth:
    password:
      value: "<strong-random-password>"
    erlangCookie:
      value: "<base64-encoded-cookie>"  # See Step 2

# External PostgreSQL bootstrap job (if using global.externalPostgresDefinitions.enabled=true)
global:
  externalPostgresDefinitions:
    adminCredentials:
      password: "<postgres-admin-password>"
    bankTransferCredentials:
      password: "<app-user-password>"

# External RabbitMQ bootstrap job (if using global.externalRabbitmqDefinitions.enabled=true)
global:
  externalRabbitmqDefinitions:
    adminCredentials:
      password: "<rabbitmq-admin-password>"
    bankTransferCredentials:
      password: "<app-user-password>"

# Application secrets (required for external infrastructure without existingSecret)
bankTransfer:
  secrets:
    POSTGRES_PASSWORD: "<app-user-password>"
    REDIS_PASSWORD: "<valkey-password>"
    MONGO_PASSWORD: "<mongo-app-user-password>"
```

Generate strong passwords using:

```bash
openssl rand -base64 32
```

#### Option 2: Use existing Kubernetes Secrets (recommended for production)

Create Secrets manually and reference them via `existingSecret` fields:

```bash
# Example: Create a Secret for PostgreSQL
kubectl create secret generic my-postgres-secret \
  --from-literal=postgres-password='<admin-password>' \
  --from-literal=password='<app-user-password>' \
  --from-literal=replication-password='<replication-password>' \
  -n plugin-br-bank-transfer

# Example: Create a Secret for the application
kubectl create secret generic my-app-secret \
  --from-literal=POSTGRES_PASSWORD='<app-user-password>' \
  --from-literal=REDIS_PASSWORD='<valkey-password>' \
  --from-literal=MONGO_PASSWORD='<mongo-password>' \
  -n plugin-br-bank-transfer
```

Reference the Secrets in your `values-override.yaml`:

```yaml
postgresql:
  auth:
    existingSecret: "my-postgres-secret"

mongodb:
  auth:
    existingSecret: "my-mongo-secret"

valkey:
  auth:
    existingSecret: "my-valkey-secret"

rabbitmq:
  auth:
    existingSecret: "my-rabbitmq-secret"

bankTransfer:
  useExistingSecret: true
  existingSecretName: "my-app-secret"
```

> **Important:** When using `existingSecret`, ensure the Secret keys match the subchart's expected key names (e.g., `postgres-password`, `password`, `mongodb-passwords`, `valkey-password`). Refer to each subchart's documentation for exact key names.

### Step 2: Generate RabbitMQ Erlang Cookie

If you are using the bundled RabbitMQ subchart (`rabbitmq.enabled=true`), generate a stable Erlang cookie:

```bash
openssl rand -base64 32
```

Add it to your `values-override.yaml`:

```yaml
rabbitmq:
  auth:
    erlangCookie:
      value: "<base64-encoded-cookie-from-above>"
```

> **Warning:** The Erlang cookie must remain stable across upgrades. Store it securely (e.g., in a secret management system) and reuse the same value for all future upgrades.

### Step 3: Migrate JD_PRIVATE_KEY_KEYINFO

If you currently set `bankTransfer.configmap.JD_PRIVATE_KEY_KEYINFO`, move it to `bankTransfer.secrets.JD_PRIVATE_KEY_KEYINFO`.

**Before (v1.0.0):**
```yaml
bankTransfer:
  configmap:
    JD_PRIVATE_KEY_KEYINFO: "my-key-metadata"
```

**After (v1.1.0):**
```yaml
bankTransfer:
  secrets:
    JD_PRIVATE_KEY_KEYINFO: "my-key-metadata"
```

> **Note:** If you do not use external signing providers or have never set this field, no action is required.

### Step 4: Review Security Context Changes

The new `allowPrivilegeEscalation` and `seccompProfile` fields are additive and should not break existing deployments. However, if you override `bankTransfer.securityContext` in your values, review the new defaults and merge them if appropriate:

```yaml
bankTransfer:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    capabilities:
      drop:
        - ALL
    allowPrivilegeEscalation: false  # New in v1.1.0
    readOnlyRootFilesystem: true
    seccompProfile:  # New in v1.1.0
      type: RuntimeDefault
```

If your environment (e.g., older Kubernetes versions or custom security policies) does not support these fields, you can explicitly disable them:

```yaml
bankTransfer:
  securityContext:
    allowPrivilegeEscalation: true  # Override if required
    seccompProfile: {}  # Disable seccomp if unsupported
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.1.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 1.1.0 -n plugin-br-bank-transfer -f values-override.yaml
```

> **Important:** Replace `values-override.yaml` with the path to your values file containing the required passwords and configuration changes from the migration steps above.
