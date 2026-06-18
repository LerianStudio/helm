# Helm Upgrade from v2.x to v3.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Default passwords removed](#1-default-passwords-removed)
  - [2. Enhanced security context defaults](#2-enhanced-security-context-defaults)
- **[Features](#features)**
  - [1. Application version bump to 1.4.2](#1-application-version-bump-to-142)
  - [2. Multi-component chart annotation](#2-multi-component-chart-annotation)
- **[Configuration Reference](#configuration-reference)**
  - [Security context additions](#security-context-additions)
  - [Password fields](#password-fields)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Generate and configure passwords](#step-1-generate-and-configure-passwords)
  - [Step 2: Review security context changes](#step-2-review-security-context-changes)
  - [Step 3: Validate existing secrets](#step-3-validate-existing-secrets)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `2.1.1` to `3.0.0`. This is a **major** release that introduces breaking changes around default password values and security context configuration.

The application version has been updated from `1.3.0` to `1.4.2` for both `manager` and `worker` components. All operators **must** review and configure passwords before upgrading, as default password values have been removed for security compliance.

> **Warning:** Upgrading without setting required passwords will result in deployment failures. Follow the migration steps carefully.

## Breaking Changes

### 1. Default passwords removed

All default password values have been removed from `values.yaml` to prevent insecure deployments. Previously, the chart shipped with hardcoded passwords like `"lerian"`, `"Lerian@123"`, and base64-encoded encryption keys. These are now empty strings.

**Before (v2.1.1):**

```yaml
global:
  mongodb:
    adminCredentials:
      username: "fetcher"
      password: "lerian"
    fetcherCredentials:
      username: "fetcher"
      password: "lerian"

secrets:
  MONGO_USER: "fetcher"
  MONGO_PASSWORD: "lerian"
  RABBITMQ_DEFAULT_USER: "plugin"
  RABBITMQ_DEFAULT_PASS: "Lerian@123"
  REDIS_USER: ""
  REDIS_PASSWORD: ""

manager:
  secrets:
    APP_ENC_KEY: "YWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWE="

worker:
  secrets:
    APP_ENC_KEY: "YWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWE="

mongodb:
  auth:
    rootUser: fetcher
    rootPassword: lerian

externalRabbitmqDefinitions:
  rabbitmqAdminLogin:
    username: "guest"
    password: "guest"
  appCredentials:
    pluginPassword: "Lerian@123"

rabbitmq:
  auth:
    user:
      value: "midaz"
    password:
      value: "lerian"
    erlangCookie:
      value: "b2a717550ac09676c545fe9d986c7651f7237b2691292961"
```

**After (v3.0.0):**

```yaml
global:
  mongodb:
    adminCredentials:
      username: "fetcher"
      password: ""
    fetcherCredentials:
      username: "fetcher"
      password: ""

secrets:
  MONGO_USER: "fetcher"
  MONGO_PASSWORD: ""
  RABBITMQ_DEFAULT_USER: "plugin"
  RABBITMQ_DEFAULT_PASS: ""
  REDIS_USER: ""
  REDIS_PASSWORD: ""

manager:
  secrets:
    APP_ENC_KEY: ""

worker:
  secrets:
    APP_ENC_KEY: ""

mongodb:
  auth:
    rootUser: fetcher
    rootPassword: ""

externalRabbitmqDefinitions:
  rabbitmqAdminLogin:
    username: "guest"
    password: ""
  appCredentials:
    pluginPassword: ""

rabbitmq:
  auth:
    user:
      value: "midaz"
    password:
      value: ""
    erlangCookie:
      value: ""
```

| Setting | v2.1.1 | v3.0.0 |
|---------|--------|--------|
| `global.mongodb.adminCredentials.password` | `"lerian"` | `""` (empty) |
| `global.mongodb.fetcherCredentials.password` | `"lerian"` | `""` (empty) |
| `secrets.MONGO_PASSWORD` | `"lerian"` | `""` (empty) |
| `secrets.RABBITMQ_DEFAULT_PASS` | `"Lerian@123"` | `""` (empty) |
| `manager.secrets.APP_ENC_KEY` | `"YWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWE="` | `""` (empty) |
| `worker.secrets.APP_ENC_KEY` | `"YWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWE="` | `""` (empty) |
| `mongodb.auth.rootPassword` | `"lerian"` | `""` (empty) |
| `externalRabbitmqDefinitions.rabbitmqAdminLogin.password` | `"guest"` | `""` (empty) |
| `externalRabbitmqDefinitions.appCredentials.pluginPassword` | `"Lerian@123"` | `""` (empty) |
| `rabbitmq.auth.password.value` | `"lerian"` | `""` (empty) |
| `rabbitmq.auth.erlangCookie.value` | `"b2a717550ac09676c545fe9d986c7651f7237b2691292961"` | `""` (empty) |

> **Important:** If you are upgrading an existing installation that relied on the default passwords, you **must** either:
> - Explicitly set the same passwords in your `values.yaml` to maintain compatibility with existing data stores, **or**
> - Migrate to new passwords and update the credentials in MongoDB and RabbitMQ accordingly

> **Warning:** The `APP_ENC_KEY` is used to encrypt sensitive data. If you change this value, previously encrypted data will become unreadable. Always preserve the existing key when upgrading.

### 2. Enhanced security context defaults

Both `manager` and `worker` Deployments now include additional security context fields to comply with Pod Security Standards (PSS) restricted profile.

**Before (v2.1.1):**

```yaml
manager:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true

worker:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
```

**After (v3.0.0):**

```yaml
manager:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault

worker:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

| Setting | v2.1.1 | v3.0.0 |
|---------|--------|--------|
| `manager.securityContext.allowPrivilegeEscalation` | (not set) | `false` |
| `manager.securityContext.seccompProfile.type` | (not set) | `RuntimeDefault` |
| `worker.securityContext.allowPrivilegeEscalation` | (not set) | `false` |
| `worker.securityContext.seccompProfile.type` | (not set) | `RuntimeDefault` |

> **Note:** These changes improve security posture and are required for clusters enforcing the Kubernetes Pod Security Standards (PSS) restricted profile. No action is required unless you have custom security policies that conflict with these settings.

## Features

### 1. Application version bump to 1.4.2

Both `manager` and `worker` components have been updated to application version `1.4.2` (from `1.3.0`).

| Component | v2.1.1 | v3.0.0 |
|-----------|--------|--------|
| `manager.image.tag` | `"1.3.0"` | `"1.4.2"` |
| `worker.image.tag` | `"1.3.0"` | `"1.4.2"` |

> **Note:** Consult the upstream `fetcher` application release notes for details on changes between `1.3.0` and `1.4.2`.

### 2. Multi-component chart annotation

The chart now includes a `lerian.studio/chart-type: multi-component` annotation in `Chart.yaml`. This is a metadata change with no operational impact.

```yaml
annotations:
  lerian.studio/chart-type: multi-component
```

## Configuration Reference

### Security context additions

The following fields have been added to both `manager` and `worker` security contexts:

| Flag | Default | Description |
|------|---------|-------------|
| `allowPrivilegeEscalation` | `false` | Prevents the container process from gaining more privileges than its parent |
| `seccompProfile.type` | `RuntimeDefault` | Applies the container runtime's default seccomp profile |

**Example configuration:**

```yaml
manager:
  securityContext:
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault

worker:
  securityContext:
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

### Password fields

All password fields now default to empty strings. Operators must provide values via `values.yaml` or Helm `--set` flags.

| Field | Purpose | Required |
|-------|---------|----------|
| `global.mongodb.adminCredentials.password` | MongoDB admin password | Yes (if using bundled MongoDB) |
| `global.mongodb.fetcherCredentials.password` | MongoDB fetcher user password | Yes (if using bundled MongoDB) |
| `secrets.MONGO_PASSWORD` | MongoDB connection password for application | Yes |
| `secrets.RABBITMQ_DEFAULT_PASS` | RabbitMQ default user password | Yes (if using bundled RabbitMQ) |
| `manager.secrets.APP_ENC_KEY` | Base64-encoded 32-byte encryption key for manager | Yes |
| `worker.secrets.APP_ENC_KEY` | Base64-encoded 32-byte encryption key for worker | Yes |
| `mongodb.auth.rootPassword` | MongoDB root password | Yes (if using bundled MongoDB) |
| `externalRabbitmqDefinitions.rabbitmqAdminLogin.password` | External RabbitMQ admin password | Yes (if using external RabbitMQ) |
| `externalRabbitmqDefinitions.appCredentials.pluginPassword` | RabbitMQ plugin user password | Yes (if using external RabbitMQ) |
| `rabbitmq.auth.password.value` | RabbitMQ user password | Yes (if using bundled RabbitMQ) |
| `rabbitmq.auth.erlangCookie.value` | RabbitMQ Erlang cookie for clustering | Yes (if using bundled RabbitMQ) |

## Migration Steps

### Step 1: Generate and configure passwords

Before upgrading, you must set all required password values. Choose one of the following approaches:

#### Option 1: Preserve existing passwords (recommended for existing installations)

If you are upgrading an existing installation, retrieve the current passwords from your deployed secrets and set them explicitly in your `values.yaml`:

```bash
# Retrieve MongoDB password
kubectl get secret -n fetcher fetcher-mongodb -o jsonpath='{.data.mongodb-root-password}' | base64 -d

# Retrieve RabbitMQ password
kubectl get secret -n fetcher fetcher-rabbitmq -o jsonpath='{.data.rabbitmq-password}' | base64 -d

# Retrieve manager encryption key
kubectl get secret -n fetcher fetcher-manager-secret -o jsonpath='{.data.APP_ENC_KEY}' | base64 -d
```

Create a `values-override.yaml` file with the retrieved values:

```yaml
global:
  mongodb:
    adminCredentials:
      password: "your-existing-mongo-password"
    fetcherCredentials:
      password: "your-existing-mongo-password"

secrets:
  MONGO_PASSWORD: "your-existing-mongo-password"
  RABBITMQ_DEFAULT_PASS: "your-existing-rabbitmq-password"

manager:
  secrets:
    APP_ENC_KEY: "your-existing-base64-encoded-key"

worker:
  secrets:
    APP_ENC_KEY: "your-existing-base64-encoded-key"

mongodb:
  auth:
    rootPassword: "your-existing-mongo-password"

rabbitmq:
  auth:
    password:
      value: "your-existing-rabbitmq-password"
    erlangCookie:
      value: "your-existing-erlang-cookie"
```

#### Option 2: Generate new passwords (for new installations only)

> **Warning:** Only use this approach for new installations. Changing passwords on an existing installation requires manual credential rotation in MongoDB and RabbitMQ.

```bash
# Generate a secure random password
openssl rand -base64 32

# Generate a 32-byte encryption key and base64 encode it
openssl rand -base64 32
```

Create a `values-override.yaml` file with the new values:

```yaml
global:
  mongodb:
    adminCredentials:
      password: "new-secure-password"
    fetcherCredentials:
      password: "new-secure-password"

secrets:
  MONGO_PASSWORD: "new-secure-password"
  RABBITMQ_DEFAULT_PASS: "new-secure-rabbitmq-password"

manager:
  secrets:
    APP_ENC_KEY: "new-base64-encoded-32-byte-key"

worker:
  secrets:
    APP_ENC_KEY: "new-base64-encoded-32-byte-key"

mongodb:
  auth:
    rootPassword: "new-secure-password"

rabbitmq:
  auth:
    password:
      value: "new-secure-rabbitmq-password"
    erlangCookie:
      value: "new-erlang-cookie-48-chars-min"
```

> **Important:** The `APP_ENC_KEY` must be a base64-encoded 32-byte value. Generate it with: `openssl rand -base64 32`

### Step 2: Review security context changes

The new security context fields are applied automatically. If your cluster enforces custom Pod Security Policies or Admission Controllers, verify compatibility:

```bash
# Test the upgrade in dry-run mode
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm \
  --version 3.0.0 \
  -n fetcher \
  -f values-override.yaml \
  --dry-run
```

If you encounter security policy violations, you can override the security context:

```yaml
manager:
  securityContext:
    allowPrivilegeEscalation: false
    seccompProfile:
      type: Localhost
      localhostProfile: "my-custom-profile.json"
```

### Step 3: Validate existing secrets

If you are using `useExistingSecret` for any credentials, ensure those secrets exist and contain the correct keys:

```bash
# Check MongoDB admin secret
kubectl get secret -n fetcher your-mongodb-admin-secret -o yaml

# Check RabbitMQ credentials secret
kubectl get secret -n fetcher your-rabbitmq-secret -o yaml

# Check manager secret
kubectl get secret -n fetcher your-manager-secret -o yaml
```

> **Note:** If using existing secrets, the empty password defaults in `values.yaml` will be ignored. Ensure your existing secrets are up to date.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.0.0 -n fetcher -f values-override.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.0.0 -n fetcher -f values-override.yaml
```

> **Important:** Always specify your `values-override.yaml` file containing the required passwords. Omitting this file will cause the upgrade to fail.

After the upgrade completes, verify all pods are running:

```bash
kubectl get pods -n fetcher
```

Check manager and worker logs for any authentication errors:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50
```
