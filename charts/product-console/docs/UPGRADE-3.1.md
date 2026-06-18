# Helm Upgrade from v3.0.0 to v3.1.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [Default passwords removed from values.yaml](#default-passwords-removed-from-valuesyaml)
- **[Features](#features)**
  - [1. Enhanced security context with read-only root filesystem](#1-enhanced-security-context-with-read-only-root-filesystem)
  - [2. Explicit namespace declaration in all resources](#2-explicit-namespace-declaration-in-all-resources)
  - [3. Chart type annotation](#3-chart-type-annotation)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Guide](#migration-guide)**
  - [Step 1: Prepare secret values](#step-1-prepare-secret-values)
  - [Step 2: Review security context changes](#step-2-review-security-context-changes)
  - [Step 3: Perform the upgrade](#step-3-perform-the-upgrade)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release focused on security hardening and operational best practices. The chart now enforces stricter security defaults, removes hardcoded credentials, and adds explicit namespace declarations to all resources.

| Field | v3.0.0 | v3.1.0 |
|-------|--------|--------|
| Chart version | `3.0.0` | `3.1.0` |
| App version | `1.6.0` | `1.6.0` |

## Breaking Changes

### Default passwords removed from values.yaml

All default passwords and secrets have been removed from `values.yaml`. Previously, the chart shipped with hardcoded credentials (`"lerian"`, `"change-me-in-production"`) which posed a security risk if deployed without customization.

**Affected fields:**

| Setting | v3.0.0 | v3.1.0 |
|---------|--------|--------|
| `global.mongodb.auth.adminCredentials.password` | `"lerian"` | `""` |
| `global.mongodb.auth.consoleCredentials.password` | `"lerian"` | `""` |
| `secrets.NEXTAUTH_SECRET` | `"change-me-in-production"` | `""` |
| `secrets.MONGODB_PASS` | `"lerian"` | `""` |
| `mongodb.auth.rootPassword` | `"lerian"` | `""` |

**Impact:**

- If you upgrade without providing these values, the deployment will fail or use empty passwords
- You **must** explicitly set all required passwords either via `values.yaml` or `--set` flags
- Existing installations with custom passwords are unaffected, but should verify their values file contains all required secrets

> **Warning:** Do not deploy with empty passwords in production. The chart will accept empty values but the application and MongoDB will fail to authenticate.

## Features

### 1. Enhanced security context with read-only root filesystem

The container security context has been hardened with additional restrictions following Kubernetes security best practices.

**Before (v3.0.0):**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false
```

**After (v3.1.0):**

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

**Changes:**

| Setting | v3.0.0 | v3.1.0 | Description |
|---------|--------|--------|-------------|
| `securityContext.readOnlyRootFilesystem` | `false` | `true` | Container filesystem is now read-only |
| `securityContext.allowPrivilegeEscalation` | not set | `false` | Explicitly prevents privilege escalation |
| `securityContext.seccompProfile.type` | not set | `RuntimeDefault` | Applies default seccomp profile |

**Operational impact:**

The read-only root filesystem means the container cannot write to any path except explicitly mounted volumes. If your `product-console` application writes temporary files, logs, or cache to the filesystem, you must:

1. Verify the application supports read-only root filesystem
2. Mount emptyDir volumes for writable paths if needed
3. Test the upgrade in a non-production environment first

> **Note:** The `product-console` application version `1.6.0` should support read-only root filesystem. If you encounter write permission errors after upgrading, you can temporarily revert this setting:

```yaml
securityContext:
  readOnlyRootFilesystem: false
```

### 2. Explicit namespace declaration in all resources

All Kubernetes resources now include an explicit `namespace` field in their metadata, using the `product-console.namespace` helper template.

**Template changes:**

The following resources now include `namespace: {{ include "product-console.namespace" . }}`:

- ConfigMap (`templates/configmap.yaml`)
- Deployment (`templates/deployment.yaml`)
- Secret (`templates/secrets.yaml`)
- Service (`templates/service.yaml`)

**Before (v3.0.0):**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "product-console.fullname" . }}
  labels:
    {{- include "product-console.labels" . | nindent 4 }}
```

**After (v3.1.0):**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "product-console.fullname" . }}
  namespace: {{ include "product-console.namespace" . }}
  labels:
    {{- include "product-console.labels" . | nindent 4 }}
```

**Impact:**

- Resources will now explicitly declare their namespace instead of relying on Helm's `--namespace` flag context
- This improves clarity and prevents accidental deployment to the wrong namespace
- No action required from operators; the namespace is automatically derived from the Helm release namespace

### 3. Chart type annotation

A new annotation has been added to `Chart.yaml` for internal classification purposes:

```yaml
annotations:
  lerian.studio/chart-type: single-service
```

This annotation has no operational impact and requires no action from operators.

## Configuration Changes

### Removed default values

All password and secret fields now default to empty strings. You must provide values for:

```yaml
global:
  mongodb:
    auth:
      adminCredentials:
        password: "<your-admin-password>"
      consoleCredentials:
        password: "<your-console-password>"

secrets:
  NEXTAUTH_SECRET: "<your-nextauth-secret>"
  MONGODB_PASS: "<your-mongodb-password>"

mongodb:
  auth:
    rootPassword: "<your-root-password>"
```

### Security context defaults

| Setting | v3.0.0 | v3.1.0 |
|---------|--------|--------|
| `securityContext.readOnlyRootFilesystem` | `false` | `true` |
| `securityContext.allowPrivilegeEscalation` | not set | `false` |
| `securityContext.seccompProfile.type` | not set | `RuntimeDefault` |

## Migration Guide

### Step 1: Prepare secret values

Before upgrading, ensure you have all required passwords and secrets defined. Create or update your `values.yaml` file:

```yaml
global:
  mongodb:
    auth:
      adminCredentials:
        username: "midaz"
        password: "your-secure-admin-password"
      consoleCredentials:
        username: "midaz"
        password: "your-secure-console-password"
        roles:
          - role: "readWrite"
            db: "midaz"

secrets:
  PLUGIN_AUTH_CLIENT_SECRET: "your-auth-client-secret"
  NEXTAUTH_SECRET: "your-nextauth-secret-min-32-chars"
  MONGODB_PASS: "your-mongodb-password"

mongodb:
  auth:
    enabled: true
    rootUser: midaz
    rootPassword: "your-mongodb-root-password"
```

> **Important:** Generate strong, unique passwords for each field. The `NEXTAUTH_SECRET` should be at least 32 characters long. Use a password manager or generation tool:

```bash
# Generate a secure random secret
openssl rand -base64 32
```

**Alternative: Using existing secrets**

If you prefer to manage secrets externally, set:

```yaml
useExistingSecret: true
existingSecretName: "product-console-secrets"

global:
  mongodb:
    auth:
      adminCredentials:
        useExistingSecret:
          name: "mongodb-admin-secret"
      consoleCredentials:
        useExistingSecret:
          name: "mongodb-console-secret"
```

### Step 2: Review security context changes

Verify that your `product-console` application version `1.6.0` supports running with a read-only root filesystem. If you need to disable this temporarily:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false  # Temporarily disable if needed
  seccompProfile:
    type: RuntimeDefault
```

> **Note:** Disabling `readOnlyRootFilesystem` reduces security posture. Only do this if the application requires filesystem writes and you cannot mount appropriate volumes.

### Step 3: Perform the upgrade

1. **Backup your current configuration:**

```bash
helm get values product-console -n product-console > product-console-v3.0.0-values.yaml
```

2. **Review the diff:**

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 3.1.0 \
  -f your-values.yaml \
  -n product-console
```

3. **Execute the upgrade:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 3.1.0 \
  -f your-values.yaml \
  -n product-console
```

4. **Verify the deployment:**

```bash
kubectl get pods -n product-console
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

5. **Check for security context issues:**

```bash
kubectl describe pod -n product-console -l app.kubernetes.io/name=product-console | grep -A10 "State:"
```

If pods are in `CrashLoopBackOff` with permission denied errors, the application may not support read-only root filesystem. Review logs and consider mounting emptyDir volumes or temporarily disabling the setting.

## Configuration Reference

### Required secret fields

| Field | Default | Description |
|-------|---------|-------------|
| `global.mongodb.auth.adminCredentials.password` | `""` | MongoDB admin user password |
| `global.mongodb.auth.consoleCredentials.password` | `""` | MongoDB console user password |
| `secrets.PLUGIN_AUTH_CLIENT_SECRET` | `""` | OAuth/OIDC client secret for authentication plugin |
| `secrets.NEXTAUTH_SECRET` | `""` | NextAuth.js encryption secret (min 32 chars) |
| `secrets.MONGODB_PASS` | `""` | MongoDB connection password for the application |
| `mongodb.auth.rootPassword` | `""` | MongoDB root user password (subchart) |

### Security context fields

| Field | Default | Description |
|-------|---------|-------------|
| `securityContext.readOnlyRootFilesystem` | `true` | Mounts container root filesystem as read-only |
| `securityContext.allowPrivilegeEscalation` | `false` | Prevents processes from gaining additional privileges |
| `securityContext.seccompProfile.type` | `RuntimeDefault` | Applies default seccomp security profile |

### Example values.yaml for upgrade

```yaml
# Minimal required configuration for v3.1.0
global:
  mongodb:
    auth:
      adminCredentials:
        username: "midaz"
        password: "change-this-admin-password"
      consoleCredentials:
        username: "midaz"
        password: "change-this-console-password"
        roles:
          - role: "readWrite"
            db: "midaz"

secrets:
  PLUGIN_AUTH_CLIENT_SECRET: "your-oauth-client-secret"
  NEXTAUTH_SECRET: "your-nextauth-secret-at-least-32-characters-long"
  MONGODB_PASS: "change-this-mongodb-password"

mongodb:
  auth:
    enabled: true
    rootUser: midaz
    rootPassword: "change-this-root-password"
  resourcesPreset: "medium"
  persistence:
    size: 8Gi

# Optional: Adjust security context if needed
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

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 3.1.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 3.1.0 -n product-console
```

**With inline secret values (not recommended for production):**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 3.1.0 \
  --set global.mongodb.auth.adminCredentials.password="your-admin-pass" \
  --set global.mongodb.auth.consoleCredentials.password="your-console-pass" \
  --set secrets.NEXTAUTH_SECRET="your-nextauth-secret" \
  --set secrets.MONGODB_PASS="your-mongodb-pass" \
  --set mongodb.auth.rootPassword="your-root-pass" \
  -n product-console
```

**With values file (recommended):**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 3.1.0 \
  -f product-console-values.yaml \
  -n product-console
```
