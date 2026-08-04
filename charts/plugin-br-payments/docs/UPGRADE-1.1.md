# Helm Upgrade from v1.0.0 to v1.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. PostgreSQL Dependency Upgrade](#1-postgresql-dependency-upgrade)
  - [2. Single-Source Infrastructure Secrets](#2-single-source-infrastructure-secrets)
  - [3. Enhanced Security Defaults](#3-enhanced-security-defaults)
  - [4. New Configuration Flag: ALLOW_INSECURE_TLS](#4-new-configuration-flag-allow_insecure_tls)
  - [5. Chart Metadata Annotation](#5-chart-metadata-annotation)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `1.0.0` to `1.1.0`. The application version remains `1.0.0-beta.9`; the chart bump to `1.1.0` introduces several non-breaking improvements focused on security hardening, secret management, and infrastructure dependency updates.

The most significant change is the adoption of **single-source infrastructure secrets**: the PostgreSQL password is now read directly from the Bitnami subchart's generated Secret via `secretKeyRef` instead of being duplicated in `app.secrets.POSTGRES_PASSWORD`. This eliminates secret drift and aligns with Helm best practices. Existing deployments using the bundled PostgreSQL subchart require no action; operators using external PostgreSQL must review the migration steps.

Additional changes include a PostgreSQL subchart version bump (from `16.3` to `16.3.5`), enhanced container security profiles (seccomp), a new `ALLOW_INSECURE_TLS` configuration flag, and improved default password handling (all default passwords now empty strings).

## Features

### 1. PostgreSQL Dependency Upgrade

The bundled PostgreSQL subchart dependency was upgraded from version `16.3` to `16.3.5`.

| Dependency | v1.0.0 | v1.1.0 |
|------------|--------|--------|
| `postgresql` chart version | `16.3` | `16.3.5` |

**Impact:**

- The upgrade includes bug fixes and security patches from the Bitnami PostgreSQL chart releases between `16.3` and `16.3.5`
- No breaking changes in the subchart API; existing `postgresql.*` values remain compatible
- The upgrade triggers a rolling restart of PostgreSQL pods if the bundled subchart is enabled

> **Note:** If you are using an external PostgreSQL instance (`postgresql.enabled: false`), this change has no impact on your deployment.

### 2. Single-Source Infrastructure Secrets

The chart now implements **single-source infrastructure secrets** for PostgreSQL credentials. Instead of duplicating the PostgreSQL password in both `postgresql.auth.password` and `app.secrets.POSTGRES_PASSWORD`, the application deployment reads the password directly from the Bitnami subchart's generated Secret via `secretKeyRef`.

**Before (v1.0.0):**

The password was set in two places:

```yaml
app:
  secrets:
    POSTGRES_PASSWORD: "lerian"

postgresql:
  auth:
    password: "lerian"
```

The deployment consumed `POSTGRES_PASSWORD` from the application secret:

```yaml
env:
  - secretRef:
      name: plugin-br-payments
```

**After (v1.1.0):**

The password is set only in the PostgreSQL subchart configuration:

```yaml
app:
  secrets:
    # Leave empty when using bundled subchart
    POSTGRES_PASSWORD: ""

postgresql:
  auth:
    password: "your-secure-password"
```

The deployment reads the password directly from the PostgreSQL Secret:

```yaml
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: <release>-postgresql
        key: password
```

**Migration scenarios:**

#### Option 1: Using bundled PostgreSQL subchart (default)

No action required. The chart automatically derives the Secret name from the subchart's `fullnameOverride`, `nameOverride`, or release name, honoring Bitnami's naming conventions.

**Recommended values configuration:**

```yaml
postgresql:
  enabled: true
  auth:
    password: "your-secure-password"
    postgresPassword: "your-admin-password"
    replicationPassword: "your-replication-password"

app:
  secrets:
    POSTGRES_PASSWORD: ""  # Leave empty
```

> **Important:** Remove any explicit `app.secrets.POSTGRES_PASSWORD` value from your values overlay. The chart will fail validation if both the bundled subchart is enabled and `app.secrets.POSTGRES_PASSWORD` is set.

#### Option 2: Using external PostgreSQL with existing Secret

If you manage PostgreSQL credentials in a separate Kubernetes Secret, configure the subchart to reference it:

```yaml
postgresql:
  enabled: false

  auth:
    existingSecret: "my-external-postgres-secret"

app:
  secrets:
    POSTGRES_PASSWORD: ""  # Leave empty
```

The chart will read the password from `my-external-postgres-secret` with key `password`.

#### Option 3: Using external PostgreSQL without existing Secret

If you are using an external PostgreSQL instance and do not have a pre-existing Secret, you must now set the password in `app.secrets.POSTGRES_PASSWORD`:

```yaml
postgresql:
  enabled: false

app:
  secrets:
    POSTGRES_PASSWORD: "your-external-db-password"
```

> **Warning:** This is the only scenario where `app.secrets.POSTGRES_PASSWORD` should be set. Mixing this with `postgresql.enabled: true` will cause the deployment to fail.

**Template changes:**

The deployment template now includes conditional logic to select the correct Secret source:

```yaml
env:
  {{- if or (and (ne (toString $pg.enabled) "false") (not $pg.external)) $pgAuth.existingSecret }}
  {{- include "plugin-br-payments.infraSecretRef" (dict "context" $ "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") | nindent 12 }}
  {{- else if .Values.app.secrets.POSTGRES_PASSWORD }}
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ if .Values.app.useExistingSecret }}{{ .Values.app.existingSecretName }}{{ else }}{{ include "plugin-br-payments.fullname" . }}{{ end }}
        key: POSTGRES_PASSWORD
  {{- end }}
```

A new helper function `plugin-br-payments.infraSecretRef` was added to `_helpers.tpl` to resolve the correct Secret name, honoring `nameOverride`, `fullnameOverride`, and release-name collapse.

**ConfigMap changes:**

The `POSTGRES_HOST` derivation logic was updated to use the same `common.names.dependency.fullname` helper, ensuring consistency between Secret and Service name resolution:

```yaml
{{- $pgFullname := include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" (index .Values "postgresql") "context" .) }}
{{- if eq $pgArch "replication" }}
POSTGRES_HOST: {{ printf "%s-primary.%s.svc.cluster.local" $pgFullname (include "global.namespace" .) | quote }}
{{- else }}
POSTGRES_HOST: {{ printf "%s.%s.svc.cluster.local" $pgFullname (include "global.namespace" .) | quote }}
{{- end }}
```

> **Note:** The default PostgreSQL architecture was corrected from `"replication"` to `"standalone"` to match the Bitnami subchart's actual default.

### 3. Enhanced Security Defaults

Two security improvements were introduced in this release:

#### Seccomp Profile

A `seccompProfile` was added to the application container's security context:

```yaml
app:
  securityContext:
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
```

**Impact:**

- The container now runs with the Kubernetes `RuntimeDefault` seccomp profile, restricting system calls to a safe subset
- This aligns with Pod Security Standards (PSS) `restricted` profile requirements
- No application code changes are required; the Go binary is compatible with the restricted syscall set

#### Empty Default Passwords

All default password values in `values.yaml` were changed from `"lerian"` to empty strings:

| Setting | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| `global.externalPostgresDefinitions.adminCredentials.password` | `"lerian"` | `""` |
| `global.externalPostgresDefinitions.paymentsCredentials.password` | `"lerian"` | `""` |
| `app.secrets.POSTGRES_PASSWORD` | `"lerian"` | `""` |
| `postgresql.auth.postgresPassword` | `"lerian"` | `""` |
| `postgresql.auth.password` | `"lerian"` | `""` |
| `postgresql.auth.replicationPassword` | `"replicator_password"` | `""` |

**Impact:**

- Operators must now explicitly set passwords in their values overlays; the chart will not deploy with working credentials if passwords are left empty
- The `plugin-br-payments.secretWarnings` helper was updated to remove the `POSTGRES_PASSWORD` default-value warning (since the field is now single-sourced from the subchart)
- Existing deployments that relied on default passwords must set explicit values before upgrading

> **Warning:** If you are upgrading an existing deployment that used default passwords, you must set explicit password values in your values overlay to match the current running credentials. Changing passwords during an upgrade will break the application's database connection.

**Recommended migration:**

```yaml
postgresql:
  auth:
    postgresPassword: "your-current-admin-password"
    password: "your-current-app-password"
    replicationPassword: "your-current-replication-password"
```

### 4. New Configuration Flag: ALLOW_INSECURE_TLS

A new environment variable `ALLOW_INSECURE_TLS` was added to the application ConfigMap:

| Flag | Default | Description |
|------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `"true"` | Allow insecure TLS connections (skip certificate verification) for development/testing environments |

**Configuration:**

```yaml
app:
  configmap:
    ALLOW_INSECURE_TLS: "true"
```

**Impact:**

- The default value `"true"` maintains backward compatibility with existing deployments that may connect to services with self-signed certificates
- For production environments, operators should explicitly set this to `"false"` to enforce strict TLS certificate validation
- This flag controls TLS behavior for outbound HTTP clients (e.g., BTG API calls, Midaz transaction service)

> **Important:** The default `"true"` value is intended for development and testing environments only. Production deployments should set `ALLOW_INSECURE_TLS: "false"` and ensure all external services present valid TLS certificates.

**Production-ready configuration:**

```yaml
app:
  configmap:
    ALLOW_INSECURE_TLS: "false"
```

### 5. Chart Metadata Annotation

A new annotation was added to `Chart.yaml`:

```yaml
annotations:
  lerian.studio/chart-type: single-service
```

**Impact:**

- This is a metadata-only change with no operational impact
- The annotation is used by Lerian Studio's internal chart classification and tooling
- No action required from operators

## Configuration Changes

### New Fields

| Setting | Default | Description |
|---------|---------|-------------|
| `app.configmap.ALLOW_INSECURE_TLS` | `"true"` | Allow insecure TLS connections (skip certificate verification) |
| `app.securityContext.seccompProfile.type` | `RuntimeDefault` | Seccomp profile for the application container |

### Changed Defaults

| Setting | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| `global.externalPostgresDefinitions.adminCredentials.password` | `"lerian"` | `""` |
| `global.externalPostgresDefinitions.paymentsCredentials.password` | `"lerian"` | `""` |
| `app.secrets.POSTGRES_PASSWORD` | `"lerian"` | `""` |
| `postgresql.version` (dependency) | `16.3` | `16.3.5` |
| `postgresql.auth.postgresPassword` | `"lerian"` | `""` |
| `postgresql.auth.password` | `"lerian"` | `""` |
| `postgresql.auth.replicationPassword` | `"replicator_password"` | `""` |

### Removed Validations

The `_helpers.tpl` validation for `app.secrets.POSTGRES_PASSWORD` was removed:

**Before (v1.0.0):**

```yaml
{{- if not .Values.app.secrets.POSTGRES_PASSWORD }}
{{- fail "\n\nERROR: app.secrets.POSTGRES_PASSWORD is REQUIRED.\n   Set the PostgreSQL application password.\n" }}
{{- end }}
```

**After (v1.1.0):**

The validation was replaced with a comment explaining the single-source pattern:

```yaml
{{/* PostgreSQL password is single-sourced from the postgresql subchart Secret
     (<release>-postgresql, key "password") via secretKeyRef; see
     docs/helm-chart-standard.md "Single-Source Infra Secrets". No gate here:
     for the bundled subchart the value is generated; for external Postgres the
     operator supplies postgresql.auth.existingSecret or app.secrets.POSTGRES_PASSWORD. */}}
```

### Template File Rename

The secrets template file was renamed for consistency:

| File | v1.0.0 | v1.1.0 |
|------|--------|--------|
| Secrets template | `templates/secrets.yml` | `templates/secrets.yaml` |

**Impact:** No operational change; the file extension was corrected to match Helm conventions.

## Migration Steps

1. **Review your current PostgreSQL configuration:**

   Determine which scenario applies to your deployment:
   - **Scenario A:** Using the bundled PostgreSQL subchart (`postgresql.enabled: true`)
   - **Scenario B:** Using external PostgreSQL with an existing Kubernetes Secret
   - **Scenario C:** Using external PostgreSQL without an existing Secret

2. **Update your values overlay based on your scenario:**

   **Scenario A (bundled subchart):**

   ```yaml
   postgresql:
     enabled: true
     auth:
       postgresPassword: "your-current-admin-password"
       password: "your-current-app-password"
       replicationPassword: "your-current-replication-password"

   app:
     secrets:
       POSTGRES_PASSWORD: ""  # Remove any explicit value
   ```

   **Scenario B (external with existing Secret):**

   ```yaml
   postgresql:
     enabled: false
     auth:
       existingSecret: "my-external-postgres-secret"

   app:
     secrets:
       POSTGRES_PASSWORD: ""  # Remove any explicit value
   ```

   **Scenario C (external without existing Secret):**

   ```yaml
   postgresql:
     enabled: false

   app:
     secrets:
       POSTGRES_PASSWORD: "your-external-db-password"
   ```

3. **Set explicit passwords for all empty defaults:**

   If your current deployment uses any of the default passwords (`"lerian"`, `"replicator_password"`), you must set explicit values in your overlay to match the current running credentials:

   ```yaml
   postgresql:
     auth:
       postgresPassword: "your-current-admin-password"
       password: "your-current-app-password"
       replicationPassword: "your-current-replication-password"
   ```

   > **Warning:** Do not change passwords during the upgrade. Set values that match your current running deployment to avoid breaking the database connection.

4. **(Optional) Harden TLS configuration for production:**

   If you are running in a production environment with valid TLS certificates for all external services, set:

   ```yaml
   app:
     configmap:
       ALLOW_INSECURE_TLS: "false"
   ```

5. **Preview the rendered diff:**

   Use the helm-diff plugin to review all changes before applying:

   ```bash
   helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.0 -n plugin-br-payments -f your-values.yaml
   ```

6. **Run the upgrade:**

   Execute the upgrade command during a maintenance window:

   ```bash
   helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.0 -n plugin-br-payments -f your-values.yaml
   ```

7. **Verify the deployment:**

   Check that all pods are running and healthy:

   ```bash
   kubectl get pods -n plugin-br-payments -l app.kubernetes.io/name=plugin-br-payments-helm
   ```

   Verify the application can connect to PostgreSQL:

   ```bash
   kubectl logs -n plugin-br-payments -l app.kubernetes.io/name=plugin-br-payments-helm --tail=50 | grep -i postgres
   ```

   Confirm the `POSTGRES_PASSWORD` environment variable is sourced from the correct Secret:

   ```bash
   kubectl get pod -n plugin-br-payments -l app.kubernetes.io/name=plugin-br-payments-helm -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="POSTGRES_PASSWORD")]}' | jq
   ```

   Expected output (bundled subchart):

   ```json
   {
     "name": "POSTGRES_PASSWORD",
     "valueFrom": {
       "secretKeyRef": {
         "name": "<release>-postgresql",
         "key": "password"
       }
     }
   }
   ```

> **Note:** The upgrade triggers a rolling restart of the application pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions. If the bundled PostgreSQL subchart is enabled, PostgreSQL pods will also restart to apply the subchart version upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.0 -n plugin-br-payments
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.0 -n plugin-br-payments
```
