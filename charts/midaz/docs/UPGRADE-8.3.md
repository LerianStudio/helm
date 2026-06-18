# Helm Upgrade from v8.2.0 to v8.3.0

## Topics

- **[Features](#features)**
  - [1. Single-source infrastructure secrets](#1-single-source-infrastructure-secrets)
  - [2. Enhanced security context for ledger and crm](#2-enhanced-security-context-for-ledger-and-crm)
  - [3. New ALLOW_INSECURE_TLS configuration flag](#3-new-allow_insecure_tls-configuration-flag)
  - [4. PostgreSQL subchart version bump](#4-postgresql-subchart-version-bump)
  - [5. Chart metadata and repository updates](#5-chart-metadata-and-repository-updates)
- **[Configuration Reference](#configuration-reference)**
  - [Default password values](#default-password-values)
  - [New environment variables](#new-environment-variables)
  - [Security context additions](#security-context-additions)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Single-source infrastructure secrets

Version 8.3.0 introduces a major architectural improvement: infrastructure secrets (PostgreSQL, MongoDB, Valkey/Redis passwords) are now **single-sourced** from the Bitnami subchart Secrets and injected into application pods via `secretKeyRef` environment variables.

**What changed:**

Previously, operators had to manually duplicate passwords in both the subchart configuration (e.g., `postgresql.auth.password`) and the application secrets (e.g., `ledger.secrets.DB_ONBOARDING_PASSWORD`). This duplication was error-prone and violated the single-source-of-truth principle.

Now:
- When using **bundled subcharts** (default, `postgresql.enabled: true`, `mongodb.enabled: true`, `valkey.enabled: true`), the application Deployments read passwords directly from the subchart-generated Secrets via `secretKeyRef`.
- The `ledger.secrets.*` and `crm.secrets.*` password fields in `values.yaml` now default to empty strings (`""`).
- Operators **only set passwords in the subchart configuration** (e.g., `postgresql.auth.password`, `mongodb.auth.rootPassword`, `valkey.auth.password`).
- The application Secret templates (`templates/ledger/secrets.yaml`, `templates/crm/secrets.yaml`) **no longer emit** infrastructure password keys when subcharts are internal.

**When to set application secrets:**

You **only** need to set `ledger.secrets.*` or `crm.secrets.*` infrastructure passwords when:
1. The subchart is **disabled** (`postgresql.enabled: false`, `mongodb.enabled: false`, `valkey.enabled: false`), **OR**
2. The subchart is marked as **external** (`postgresql.external: true`, `mongodb.external: true`, `valkey.external: true`), **AND**
3. You are **not** using an `existingSecret` override (e.g., `postgresql.auth.existingSecret`, `mongodb.auth.existingSecret`, `valkey.auth.existingSecret`).

**Password mapping:**

| Application Secret Key | Subchart | Subchart Secret Key | Notes |
|------------------------|----------|---------------------|-------|
| `DB_ONBOARDING_PASSWORD` | `postgresql` | `password` | Role `midaz` |
| `DB_TRANSACTION_PASSWORD` | `postgresql` | `password` | Role `midaz` (same as onboarding) |
| `DB_ONBOARDING_REPLICA_PASSWORD` | `postgresql` | `replication-password` | Replication user |
| `DB_TRANSACTION_REPLICA_PASSWORD` | `postgresql` | `replication-password` | Replication user (same as onboarding) |
| `MONGO_ONBOARDING_PASSWORD` | `mongodb` | `mongodb-root-password` | Root user |
| `MONGO_TRANSACTION_PASSWORD` | `mongodb` | `mongodb-root-password` | Root user (same as onboarding) |
| `MONGO_PASSWORD` (crm) | `mongodb` | `mongodb-root-password` | Root user |
| `REDIS_PASSWORD` | `valkey` | `valkey-password` | Auth password |

**Before (v8.2.0):**

Operators had to duplicate passwords:

```yaml
postgresql:
  auth:
    password: "my-secure-password"

ledger:
  secrets:
    DB_ONBOARDING_PASSWORD: "my-secure-password"  # Duplicate!
    DB_TRANSACTION_PASSWORD: "my-secure-password" # Duplicate!
```

**After (v8.3.0):**

Operators set passwords **only once** in the subchart:

```yaml
postgresql:
  auth:
    password: "my-secure-password"

ledger:
  secrets:
    DB_ONBOARDING_PASSWORD: ""  # Empty — single-sourced from postgresql
    DB_TRANSACTION_PASSWORD: "" # Empty — single-sourced from postgresql
```

**MongoDB authentication requirement:**

The chart now enforces that MongoDB authentication is enabled when using the bundled subchart. If `mongodb.enabled: true`, `mongodb.external: false`, and `mongodb.auth.enabled: false` (with no `mongodb.auth.existingSecret`), the chart will **fail at render time** with a clear error message:

```
ERROR: mongodb.auth.enabled is REQUIRED when the bundled mongodb subchart is internal.
   ledger and crm read MONGO_*_PASSWORD from the mongodb Secret (single source), but Bitnami
   mongodb creates no Secret when auth.enabled=false, leaving a dangling secretKeyRef.
   Choose one: set mongodb.auth.enabled=true, or provide mongodb.auth.existingSecret, or set mongodb.external=true.
```

> **Important:** This validation prevents runtime `CreateContainerConfigError` failures caused by dangling `secretKeyRef` references.

**Known limitation:**

RabbitMQ secrets (`RABBITMQ_DEFAULT_PASS`, `RABBITMQ_CONSUMER_PASS`) are **not yet single-sourced** and remain operator-provided in `ledger.secrets`. This is a known gap and will be addressed in a future release.

### 2. Enhanced security context for ledger and crm

The `ledger` and `crm` Deployments now include additional security hardening fields in their `securityContext`:

**New fields:**

| Field | Value | Description |
|-------|-------|-------------|
| `allowPrivilegeEscalation` | `false` | Prevents processes from gaining more privileges than their parent |
| `seccompProfile.type` | `RuntimeDefault` | Applies the container runtime's default seccomp profile |

**Before (v8.2.0):**

```yaml
ledger:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
```

**After (v8.3.0):**

```yaml
ledger:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

The same additions apply to `crm.securityContext`.

> **Note:** These changes align with Kubernetes Pod Security Standards (Restricted profile) and improve defense-in-depth. No operator action is required unless you have custom security policies that conflict with these settings.

### 3. New ALLOW_INSECURE_TLS configuration flag

A new environment variable `ALLOW_INSECURE_TLS` has been added to both `ledger` and `crm` ConfigMaps, defaulting to `"true"`.

**New environment variable:**

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `"true"` | Allows insecure TLS connections (e.g., self-signed certificates) for development/testing |

**Configuration:**

```yaml
ledger:
  configmap:
    ALLOW_INSECURE_TLS: "true"

crm:
  configmap:
    ALLOW_INSECURE_TLS: "true"
```

> **Warning:** For production deployments, set `ALLOW_INSECURE_TLS: "false"` and ensure all backend services (PostgreSQL, MongoDB, Valkey, RabbitMQ) use valid TLS certificates.

### 4. PostgreSQL subchart version bump

The `postgresql` subchart dependency has been updated from `16.3` to `16.3.5`.

| Dependency | v8.2.0 | v8.3.0 |
|------------|--------|--------|
| `postgresql` | `16.3` | `16.3.5` |

This is a patch-level update within the same minor version series. Review the [Bitnami PostgreSQL chart changelog](https://github.com/bitnami/charts/tree/main/bitnami/postgresql) for detailed changes.

> **Note:** This update includes bug fixes and security patches. No breaking changes are expected, but test in a non-production environment first.

### 5. Chart metadata and repository updates

The chart's `home` and `sources` URLs have been updated to reflect the new repository location:

| Field | v8.2.0 | v8.3.0 |
|-------|--------|--------|
| `home` | `https://github.com/LerianStudio/midaz-helm` | `https://github.com/LerianStudio/helm` |
| `sources[0]` | `https://github.com/LerianStudio/midaz-helm/tree/main/charts/midaz` | `https://github.com/LerianStudio/helm/tree/main/charts/midaz` |

A new annotation has been added:

```yaml
annotations:
  lerian.studio/chart-type: multi-component
```

These changes are informational and do not affect chart functionality.

## Configuration Reference

### Default password values

All default passwords in `values.yaml` have been changed from hardcoded values (e.g., `"lerian"`) to empty strings (`""`). This enforces the single-source principle and prevents accidental use of insecure defaults.

**Changed defaults:**

| Setting | v8.2.0 | v8.3.0 |
|---------|--------|--------|
| `global.externalRabbitDefinitions.adminCredentials.password` | `"lerian"` | `""` |
| `global.externalRabbitDefinitions.appCredentials.transactionPassword` | `"lerian"` | `""` |
| `global.externalRabbitDefinitions.appCredentials.consumerPassword` | `"lerian"` | `""` |
| `global.externalPostgresDefinitions.adminCredentials.password` | `"lerian"` | `""` |
| `global.externalPostgresDefinitions.midazCredentials.password` | `"lerian"` | `""` |
| `global.externalMongoDefinitions.adminCredentials.password` | `"lerian"` | `""` |
| `global.externalMongoDefinitions.midazCredentials.password` | `"lerian"` | `""` |
| `ledger.secrets.DB_ONBOARDING_PASSWORD` | `"lerian"` | `""` |
| `ledger.secrets.DB_ONBOARDING_REPLICA_PASSWORD` | `"lerian"` | `""` |
| `ledger.secrets.MONGO_ONBOARDING_PASSWORD` | `"lerian"` | `""` |
| `ledger.secrets.DB_TRANSACTION_PASSWORD` | `"lerian"` | `""` |
| `ledger.secrets.DB_TRANSACTION_REPLICA_PASSWORD` | `"lerian"` | `""` |
| `ledger.secrets.MONGO_TRANSACTION_PASSWORD` | `"lerian"` | `""` |
| `ledger.secrets.REDIS_PASSWORD` | `"lerian"` | `""` |
| `ledger.secrets.RABBITMQ_DEFAULT_PASS` | `"lerian"` | `""` |
| `ledger.secrets.RABBITMQ_CONSUMER_PASS` | `"lerian"` | `""` |
| `crm.secrets.LCRYPTO_HASH_SECRET_KEY` | `"8e079fde826ead63b72611324f48e4153868ec5400a8937d74567109fc62b7b3"` | `""` |
| `crm.secrets.LCRYPTO_ENCRYPT_SECRET_KEY` | `"f81d58bc177a003126d2e2f733a4ceca9dda0ccc4b122574471c8ae886cbeeda"` | `""` |
| `crm.secrets.MONGO_PASSWORD` | `"lerian"` | `""` |
| `valkey.auth.password` | `"lerian"` | `""` |
| `postgresql.auth.postgresPassword` | `"lerian"` | `""` |
| `postgresql.auth.password` | `"lerian"` | `""` |
| `postgresql.auth.replicationPassword` | `"replicator_password"` | `""` |
| `mongodb.auth.rootPassword` | `"lerian"` | `""` |
| `rabbitmq.authentication.password.value` | `"lerian"` | `""` |
| `rabbitmq.authentication.erlangCookie.value` | `"WCB00CfurKivfNH61hbxPaNg+xtyA/7RI6bEx5RMGvE="` | `""` |

> **Important:** You **must** set passwords explicitly in your `values.yaml` or via `--set` flags. The chart will fail to render if required secrets are empty and no `existingSecret` is provided.

### New environment variables

**ledger ConfigMap:**

```yaml
ledger:
  configmap:
    ALLOW_INSECURE_TLS: "true"
```

**crm ConfigMap:**

```yaml
crm:
  configmap:
    ALLOW_INSECURE_TLS: "true"
```

### Security context additions

**ledger Deployment:**

```yaml
ledger:
  securityContext:
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

**crm Deployment:**

```yaml
crm:
  securityContext:
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

## Migration Steps

### Step 1: Review your current password configuration

Identify where you currently set passwords:

```bash
helm get values midaz -n midaz > current-values.yaml
```

Review `current-values.yaml` for all password fields listed in the [Default password values](#default-password-values) table.

### Step 2: Consolidate passwords to subchart configuration

#### Option 1: Using bundled subcharts (default)

If you use the chart's bundled PostgreSQL, MongoDB, and Valkey (default configuration), **remove** all infrastructure password duplicates from `ledger.secrets` and `crm.secrets`. Set passwords **only** in the subchart configuration:

```yaml
postgresql:
  auth:
    postgresPassword: "your-postgres-admin-password"
    password: "your-midaz-password"
    replicationPassword: "your-replication-password"

mongodb:
  auth:
    enabled: true  # REQUIRED
    rootPassword: "your-mongodb-root-password"

valkey:
  auth:
    enabled: true
    password: "your-valkey-password"

ledger:
  secrets:
    # Infrastructure passwords are now single-sourced — leave empty
    DB_ONBOARDING_PASSWORD: ""
    DB_ONBOARDING_REPLICA_PASSWORD: ""
    MONGO_ONBOARDING_PASSWORD: ""
    DB_TRANSACTION_PASSWORD: ""
    DB_TRANSACTION_REPLICA_PASSWORD: ""
    MONGO_TRANSACTION_PASSWORD: ""
    REDIS_PASSWORD: ""
    # RabbitMQ passwords remain operator-provided (not yet single-sourced)
    RABBITMQ_DEFAULT_PASS: "your-rabbitmq-admin-password"
    RABBITMQ_CONSUMER_PASS: "your-rabbitmq-consumer-password"

crm:
  secrets:
    # Infrastructure password is now single-sourced — leave empty
    MONGO_PASSWORD: ""
    # App crypto material (operator-provided, external boundary)
    LCRYPTO_HASH_SECRET_KEY: "your-hash-secret-key"
    LCRYPTO_ENCRYPT_SECRET_KEY: "your-encrypt-secret-key"
```

#### Option 2: Using external infrastructure

If you use external PostgreSQL, MongoDB, or Valkey (subcharts disabled or marked as external), **set** passwords in `ledger.secrets` and `crm.secrets`:

```yaml
postgresql:
  enabled: false

mongodb:
  enabled: false

valkey:
  enabled: false

ledger:
  secrets:
    # External infrastructure — set passwords here
    DB_ONBOARDING_PASSWORD: "your-external-postgres-password"
    DB_ONBOARDING_REPLICA_PASSWORD: "your-external-postgres-replica-password"
    MONGO_ONBOARDING_PASSWORD: "your-external-mongodb-password"
    DB_TRANSACTION_PASSWORD: "your-external-postgres-password"
    DB_TRANSACTION_REPLICA_PASSWORD: "your-external-postgres-replica-password"
    MONGO_TRANSACTION_PASSWORD: "your-external-mongodb-password"
    REDIS_PASSWORD: "your-external-redis-password"
    RABBITMQ_DEFAULT_PASS: "your-rabbitmq-admin-password"
    RABBITMQ_CONSUMER_PASS: "your-rabbitmq-consumer-password"

crm:
  secrets:
    MONGO_PASSWORD: "your-external-mongodb-password"
    LCRYPTO_HASH_SECRET_KEY: "your-hash-secret-key"
    LCRYPTO_ENCRYPT_SECRET_KEY: "your-encrypt-secret-key"
```

#### Option 3: Using existingSecret overrides

If you manage secrets externally (e.g., via External Secrets Operator, Sealed Secrets), configure `existingSecret` references:

```yaml
postgresql:
  auth:
    existingSecret: "my-postgres-secret"

mongodb:
  auth:
    existingSecret: "my-mongodb-secret"

valkey:
  auth:
    existingSecret: "my-valkey-secret"

ledger:
  useExistingSecret: true
  existingSecretName: "my-ledger-secret"

crm:
  useExistingSecret: true
  existingSecretName: "my-crm-secret"
```

> **Note:** When using `existingSecret`, ensure your external Secret contains the correct keys expected by the subcharts (e.g., `password`, `replication-password`, `mongodb-root-password`, `valkey-password`) and the application (e.g., `RABBITMQ_DEFAULT_PASS`, `LCRYPTO_HASH_SECRET_KEY`).

### Step 3: Set required CRM crypto secrets

The `crm.secrets.LCRYPTO_HASH_SECRET_KEY` and `crm.secrets.LCRYPTO_ENCRYPT_SECRET_KEY` fields are now **required** and have no defaults. Generate secure random values:

```bash
# Generate a 64-character hex string for hash key
openssl rand -hex 32

# Generate a 64-character hex string for encrypt key
openssl rand -hex 32
```

Set them in your `values.yaml`:

```yaml
crm:
  secrets:
    LCRYPTO_HASH_SECRET_KEY: "your-generated-hash-key"
    LCRYPTO_ENCRYPT_SECRET_KEY: "your-generated-encrypt-key"
```

> **Warning:** Do **not** use the example values from v8.2.0 in production. Generate new keys and store them securely.

### Step 4: Set RabbitMQ Erlang cookie

The `rabbitmq.authentication.erlangCookie.value` field now defaults to an empty string. Set a secure value (32+ printable characters, no spaces):

```bash
# Generate a 32-character base64 string
openssl rand -base64 32
```

Set it in your `values.yaml`:

```yaml
rabbitmq:
  authentication:
    erlangCookie:
      value: "your-generated-erlang-cookie"
```

### Step 5: Review ALLOW_INSECURE_TLS setting

For production deployments, disable insecure TLS:

```yaml
ledger:
  configmap:
    ALLOW_INSECURE_TLS: "false"

crm:
  configmap:
    ALLOW_INSECURE_TLS: "false"
```

Ensure all backend services use valid TLS certificates.

### Step 6: Test the upgrade in a non-production environment

Before upgrading production, test in a staging or development environment:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm \
  --version 8.3.0 \
  -n midaz-staging \
  -f your-updated-values.yaml \
  --dry-run --debug
```

Review the rendered manifests for correctness, especially:
- Secret `secretKeyRef` references point to the correct subchart Secrets
- No empty password fields in Secrets when required
- Security context changes are applied

### Step 7: Upgrade production

Once validated, proceed with the production upgrade following the [Command to upgrade](#command-to-upgrade) section.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.3.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.3.0 -n midaz
```
