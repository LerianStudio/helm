# Helm Upgrade from v2.0.0 to v2.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Enhanced security context with seccomp profile](#1-enhanced-security-context-with-seccomp-profile)
  - [2. New ALLOW_INSECURE_TLS configuration flag](#2-new-allow_insecure_tls-configuration-flag)
  - [3. Default password values removed](#3-default-password-values-removed)
  - [4. Repository URL updates](#4-repository-url-updates)
  - [5. Chart type annotation added](#5-chart-type-annotation-added)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `2.0.0` to `2.1.0`. This minor version bump introduces enhanced security defaults, a new TLS configuration flag, and removes insecure default passwords. The application version remains unchanged at `1.0.0`.

| Field | v2.0.0 | v2.1.0 |
|-------|--------|--------|
| Chart version | `2.0.0` | `2.1.0` |
| App version | `1.0.0` | `1.0.0` |

> **Important:** This release removes default password values for security. Operators must explicitly provide passwords via values overrides or existing secrets before upgrading.

## Features

### 1. Enhanced security context with seccomp profile

The pod security context has been hardened with two additional fields to align with Kubernetes security best practices.

| Setting | v2.0.0 | v2.1.0 |
|---------|--------|--------|
| `tracer.securityContext.allowPrivilegeEscalation` | not set | `false` |
| `tracer.securityContext.seccompProfile.type` | not set | `RuntimeDefault` |

**Before (v2.0.0):**

```yaml
tracer:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
```

**After (v2.1.0):**

```yaml
tracer:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    capabilities:
      drop:
        - ALL
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
```

**Operational impact:**

- `allowPrivilegeEscalation: false` prevents the container from gaining more privileges than its parent process
- `seccompProfile.type: RuntimeDefault` applies the container runtime's default seccomp profile, restricting system calls

These changes improve the security posture of the tracer pod. No action is required unless your cluster has custom PodSecurityPolicies or admission controllers that conflict with these settings.

> **Note:** If your environment requires a custom seccomp profile, override `tracer.securityContext.seccompProfile` in your values file.

### 2. New ALLOW_INSECURE_TLS configuration flag

A new environment variable `ALLOW_INSECURE_TLS` has been added to control TLS certificate validation behavior.

| Setting | v2.0.0 | v2.1.0 |
|---------|--------|--------|
| `tracer.configmap.ALLOW_INSECURE_TLS` | not present | `"true"` |

**Template change:**

**Before (v2.0.0):**

```yaml
data:
  # Application Configuration
  ENV_NAME: {{ .Values.tracer.configmap.ENV_NAME | default "production" | quote }}
  SERVER_PORT: {{ .Values.tracer.configmap.SERVER_PORT | default "4020" | quote }}
```

**After (v2.1.0):**

```yaml
data:
  # Application Configuration
  ALLOW_INSECURE_TLS: {{ .Values.tracer.configmap.ALLOW_INSECURE_TLS | default "true" | quote }}
  ENV_NAME: {{ .Values.tracer.configmap.ENV_NAME | default "production" | quote }}
  SERVER_PORT: {{ .Values.tracer.configmap.SERVER_PORT | default "4020" | quote }}
```

**Default value:**

```yaml
tracer:
  configmap:
    ALLOW_INSECURE_TLS: "true"
```

| Flag | Default | Description |
|------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `"true"` | When `"true"`, allows connections to TLS endpoints without validating certificates. Set to `"false"` in production environments with proper certificate infrastructure. |

> **Warning:** The default value `"true"` is insecure and intended for development or testing environments. For production deployments, override this to `"false"` and ensure all upstream services have valid TLS certificates.

**Production override example:**

```yaml
tracer:
  configmap:
    ALLOW_INSECURE_TLS: "false"
```

### 3. Default password values removed

All default password values have been removed from the chart for security. Operators must now explicitly provide passwords.

| Setting | v2.0.0 | v2.1.0 |
|---------|--------|--------|
| `global.postgresql.adminCredentials.password` | `"lerian"` | `""` |
| `global.postgresql.tracerCredentials.password` | `"lerian"` | `""` |
| `tracer.secrets.DB_PASSWORD` | `"lerian"` | `""` |

**Before (v2.0.0):**

```yaml
global:
  postgresql:
    adminCredentials:
      username: "postgres"
      password: "lerian"
    tracerCredentials:
      password: "lerian"

tracer:
  secrets:
    DB_PASSWORD: "lerian"
```

**After (v2.1.0):**

```yaml
global:
  postgresql:
    adminCredentials:
      username: "postgres"
      password: ""
    tracerCredentials:
      password: ""

tracer:
  secrets:
    DB_PASSWORD: ""
```

**Operational impact:**

Helm will fail to install or upgrade if these passwords remain empty and no existing secret is configured. Operators must choose one of the following options:

#### Option 1: Provide passwords via values file

```yaml
global:
  postgresql:
    adminCredentials:
      password: "your-secure-admin-password"
    tracerCredentials:
      password: "your-secure-tracer-password"

tracer:
  secrets:
    DB_PASSWORD: "your-secure-tracer-password"
```

#### Option 2: Use existing Kubernetes secrets

```yaml
global:
  postgresql:
    adminCredentials:
      useExistingSecret:
        name: "postgres-admin-secret"
    tracerCredentials:
      useExistingSecret:
        name: "postgres-tracer-secret"
```

> **Important:** The `DB_PASSWORD` value under `tracer.secrets` must match the password in `global.postgresql.tracerCredentials` (either directly or via the same existing secret).

### 4. Repository URL updates

The chart metadata has been updated to reflect the new repository structure.

| Setting | v2.0.0 | v2.1.0 |
|---------|--------|--------|
| `home` | `https://github.com/LerianStudio/midaz-helm` | `https://github.com/LerianStudio/helm` |
| `sources[0]` | `https://github.com/LerianStudio/midaz-helm/tree/main/charts/tracer` | `https://github.com/LerianStudio/helm/tree/main/charts/tracer` |

**Operational impact:**

This is a metadata-only change and does not affect chart functionality or deployment behavior. No action is required.

### 5. Chart type annotation added

A new annotation has been added to classify the chart type.

| Setting | v2.0.0 | v2.1.0 |
|---------|--------|--------|
| `annotations.lerian.studio/chart-type` | not present | `single-service` |

**Chart.yaml change:**

```yaml
type: application
annotations:
  lerian.studio/chart-type: single-service
```

**Operational impact:**

This annotation is informational and used for chart categorization. It does not affect deployment behavior. No action is required.

## Configuration Reference

### New Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `"true"` | Controls TLS certificate validation. Set to `"false"` in production. |

### Security Context Fields

| Field | Default | Description |
|-------|---------|-------------|
| `allowPrivilegeEscalation` | `false` | Prevents the container from gaining additional privileges. |
| `seccompProfile.type` | `RuntimeDefault` | Applies the container runtime's default seccomp profile. |

## Migration Steps

This upgrade requires explicit password configuration before applying.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Prepare password configuration using one of the following methods:

   **Method A: Direct password values**
   
   Create or update your environment-specific values file:

   ```yaml
   global:
     postgresql:
       adminCredentials:
         password: "your-secure-admin-password"
       tracerCredentials:
         password: "your-secure-tracer-password"

   tracer:
     secrets:
       DB_PASSWORD: "your-secure-tracer-password"
   ```

   **Method B: Existing Kubernetes secrets**
   
   Ensure your secrets exist in the namespace, then configure:

   ```yaml
   global:
     postgresql:
       adminCredentials:
         useExistingSecret:
           name: "postgres-admin-secret"
       tracerCredentials:
         useExistingSecret:
           name: "postgres-tracer-secret"
   ```

3. (Optional) Override the `ALLOW_INSECURE_TLS` flag for production environments:

   ```yaml
   tracer:
     configmap:
       ALLOW_INSECURE_TLS: "false"
   ```

4. Render the chart locally with your production values and review the manifest diff:

   ```bash
   helm template tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.0 -n tracer -f your-values.yaml > /tmp/tracer-2.1.0.yaml
   ```

5. Apply the upgrade in a non-production environment first to validate the configuration.

6. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n tracer
   ```

7. Check service logs for any startup issues:

   ```bash
   kubectl logs -n tracer -l app.kubernetes.io/name=tracer-helm --tail=50
   ```

8. Verify database connectivity and application functionality.

> **Warning:** Upgrading without providing passwords will cause the deployment to fail. Ensure password configuration is in place before running the upgrade command.

## Preview changes before upgrading

```bash
helm diff upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.0 -n tracer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.0 -n tracer
```
