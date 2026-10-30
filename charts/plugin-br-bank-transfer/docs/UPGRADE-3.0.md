<!-- {% raw %} -->
# Helm Upgrade from v2.8.0 to v3.0.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Boolean Flag Handling Refactored](#1-boolean-flag-handling-refactored)
- **[Configuration Reference](#configuration-reference)**
  - [Affected Configuration Flags](#affected-configuration-flags)
  - [New Template Helper](#new-template-helper)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Explicit Boolean Overrides](#step-1-review-explicit-boolean-overrides)
  - [Step 2: Test Flag Behavior](#step-2-test-flag-behavior)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.0.0 introduces a **breaking change** in how boolean configuration flags are handled in the chart templates. This release refactors the internal logic for flags that default to `"true"` to correctly handle explicit `false` values set by operators. The change affects three configuration flags: `TLS_TERMINATED_UPSTREAM`, `MONGO_ENABLED`, and `ALLOW_INSECURE_TLS`.

This is a **major version bump** because the template logic change may alter runtime behavior for operators who have explicitly set these flags to `false` in their values overrides. Operators who rely on default values or have set these flags to `true` will see no change in behavior.

## Breaking Changes

### 1. Boolean Flag Handling Refactored

**What changed:**  
The chart now uses a new template helper `bank-transfer.flagDefaultTrue` to handle boolean flags that default to `"true"`. This helper correctly distinguishes between an explicit `false` value and an unset (empty) value, fixing a bug where explicit `false` was treated as empty and defaulted back to `"true"`.

**Before (v2.8.0):**

The chart used Sprig's `default` function directly in templates:

```yaml
# templates/configmap.yaml (v2.8.0)
TLS_TERMINATED_UPSTREAM: {{ .Values.bankTransfer.configmap.TLS_TERMINATED_UPSTREAM | default "true" | quote }}
MONGO_ENABLED: {{ .Values.bankTransfer.configmap.MONGO_ENABLED | default "true" | quote }}
ALLOW_INSECURE_TLS: {{ .Values.bankTransfer.configmap.ALLOW_INSECURE_TLS | default "true" | quote }}
```

**Problem with v2.8.0 behavior:**  
Sprig's `default` function treats boolean `false` as an "empty" value and replaces it with the default. This means:

| Operator sets | v2.8.0 rendered value | Expected value |
|---------------|----------------------|----------------|
| (not set) | `"true"` | `"true"` ✓ |
| `true` | `"true"` | `"true"` ✓ |
| `false` | `"true"` | `"false"` ✗ |

**After (v3.0.0):**

The chart introduces a new helper that checks if the value is a boolean type and renders it as-is, only applying the default for truly unset values:

```yaml
# templates/_helpers.tpl (v3.0.0)
{{- define "bank-transfer.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

```yaml
# templates/configmap.yaml (v3.0.0)
TLS_TERMINATED_UPSTREAM: {{ include "bank-transfer.flagDefaultTrue" .Values.bankTransfer.configmap.TLS_TERMINATED_UPSTREAM | quote }}
MONGO_ENABLED: {{ include "bank-transfer.flagDefaultTrue" .Values.bankTransfer.configmap.MONGO_ENABLED | quote }}
ALLOW_INSECURE_TLS: {{ include "bank-transfer.flagDefaultTrue" .Values.bankTransfer.configmap.ALLOW_INSECURE_TLS | quote }}
```

**New v3.0.0 behavior:**

| Operator sets | v3.0.0 rendered value | Expected value |
|---------------|----------------------|----------------|
| (not set) | `"true"` | `"true"` ✓ |
| `true` | `"true"` | `"true"` ✓ |
| `false` | `"false"` | `"false"` ✓ |

**Why it matters:**  
This change fixes a bug that prevented operators from disabling these features. However, it is a **breaking change** because:

1. **If you explicitly set any of these flags to `false` in v2.8.0**, the application was actually running with the flag set to `"true"` (due to the bug). After upgrading to v3.0.0, the flag will correctly be set to `"false"`, which **will change runtime behavior**.

2. **If you rely on the default `"true"` behavior** (by not setting these flags), no change occurs.

**Affected flags:**

| Flag | Purpose | Default | Impact if set to `false` |
|------|---------|---------|--------------------------|
| `TLS_TERMINATED_UPSTREAM` | Indicates TLS is terminated by an upstream proxy (affects health check behavior) | `"true"` | Application expects direct TLS connections; may affect health check endpoints |
| `MONGO_ENABLED` | Enables MongoDB audit/event persistence | `"true"` | Disables MongoDB integration; audit events will not be persisted |
| `ALLOW_INSECURE_TLS` | Allows insecure TLS connections (e.g., self-signed certs) | `"true"` | Enforces strict TLS validation; connections to infrastructure with self-signed certs will fail |

**Migration required:**  
Yes, if you have explicitly set any of these flags to `false` — see [Migration Steps](#migration-steps) below.

**Template changes:**

The `templates/migrations.yaml` file also applies the new helper to the `ALLOW_INSECURE_TLS` flag used by the database migration job:

**Before (v2.8.0):**
```yaml
# templates/migrations.yaml (v2.8.0)
- name: ALLOW_INSECURE_TLS
  value: {{ get $configmap "ALLOW_INSECURE_TLS" | default "true" | quote }}
```

**After (v3.0.0):**
```yaml
# templates/migrations.yaml (v3.0.0)
- name: ALLOW_INSECURE_TLS
  value: {{ include "bank-transfer.flagDefaultTrue" (get $configmap "ALLOW_INSECURE_TLS") | quote }}
```

**Operational impact:**  
- If you have set `bankTransfer.configmap.ALLOW_INSECURE_TLS: false` in your values, the migration job will now correctly enforce strict TLS validation when connecting to PostgreSQL. If your PostgreSQL instance uses self-signed certificates, the migration job will fail to connect after upgrading to v3.0.0.

**Removed template helpers:**

The following template helpers have been **removed** from `templates/_helpers.tpl` as part of this refactor:

- `rabbitmq.enabled`
- `valkey.enabled`
- `postgresql.enabled`
- `mongodb.enabled`

These helpers were used internally to check if bundled subcharts were enabled. They have been removed because they are no longer referenced in the chart templates. This removal does not affect operator-facing configuration.

## Configuration Reference

### Affected Configuration Flags

The following flags now correctly respect explicit `false` values:

```yaml
bankTransfer:
  configmap:
    # Indicates TLS is terminated by an upstream proxy (e.g., ingress controller).
    # Set to false if the application handles TLS directly.
    TLS_TERMINATED_UPSTREAM: true  # default

    # Enables MongoDB for audit/event persistence.
    # Set to false to disable MongoDB integration (single-tenant mode only).
    MONGO_ENABLED: true  # default

    # Allows insecure TLS connections (self-signed certs, skip verification).
    # Set to false to enforce strict TLS validation for all outbound connections.
    ALLOW_INSECURE_TLS: true  # default
```

| Flag | Default | Description |
|------|---------|-------------|
| `TLS_TERMINATED_UPSTREAM` | `true` | Indicates TLS is terminated by an upstream proxy; affects health check endpoint behavior |
| `MONGO_ENABLED` | `true` | Enables MongoDB audit/event persistence (single-tenant mode only) |
| `ALLOW_INSECURE_TLS` | `true` | Allows insecure TLS connections (self-signed certs, skip verification) for infrastructure connections |

### New Template Helper

The chart introduces a new internal helper to handle boolean flags with `"true"` defaults:

```yaml
{{- define "bank-transfer.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

**Purpose:**  
This helper checks if the input is a boolean type. If it is, the value is rendered as-is (preserving explicit `false`). If the input is not a boolean (e.g., unset/empty), the default `"true"` is applied.

**Usage in templates:**

```yaml
# templates/configmap.yaml
TLS_TERMINATED_UPSTREAM: {{ include "bank-transfer.flagDefaultTrue" .Values.bankTransfer.configmap.TLS_TERMINATED_UPSTREAM | quote }}
MONGO_ENABLED: {{ include "bank-transfer.flagDefaultTrue" .Values.bankTransfer.configmap.MONGO_ENABLED | quote }}
ALLOW_INSECURE_TLS: {{ include "bank-transfer.flagDefaultTrue" .Values.bankTransfer.configmap.ALLOW_INSECURE_TLS | quote }}

# templates/migrations.yaml
- name: ALLOW_INSECURE_TLS
  value: {{ include "bank-transfer.flagDefaultTrue" (get $configmap "ALLOW_INSECURE_TLS") | quote }}
```

## Migration Steps

### Step 1: Review Explicit Boolean Overrides

Check your current `values.yaml` or values overrides for explicit `false` settings on the affected flags:

```bash
# Search your values file for explicit false settings
grep -E "(TLS_TERMINATED_UPSTREAM|MONGO_ENABLED|ALLOW_INSECURE_TLS).*false" values.yaml
```

**If you find any of these flags set to `false`:**

1. **Understand the current (buggy) behavior:**  
   In v2.8.0, these flags were **ignored** and the application ran with `"true"` regardless of your override.

2. **Understand the new (correct) behavior:**  
   In v3.0.0, these flags will be **respected** and the application will run with `"false"`.

3. **Decide on the correct value:**

   - **If you intended to disable the feature** (e.g., disable MongoDB, enforce strict TLS), keep `false` and prepare for the behavior change.
   - **If you were unaware the flag was being ignored**, review whether `false` is the correct setting for your environment.

**Example scenarios:**

#### Scenario 1: You set `ALLOW_INSECURE_TLS: false` to enforce strict TLS

**Current state (v2.8.0):**  
The application is running with `ALLOW_INSECURE_TLS="true"` (your override was ignored). Connections to PostgreSQL, MongoDB, Valkey, and RabbitMQ with self-signed certificates are allowed.

**After upgrade (v3.0.0):**  
The application will run with `ALLOW_INSECURE_TLS="false"`. Connections to infrastructure with self-signed certificates will **fail** unless you provide valid CA certificates.

**Action required:**  
Ensure all infrastructure components use valid TLS certificates, or set `ALLOW_INSECURE_TLS: true` explicitly if you need to allow self-signed certs.

#### Scenario 2: You set `MONGO_ENABLED: false` to disable MongoDB

**Current state (v2.8.0):**  
The application is running with `MONGO_ENABLED="true"` (your override was ignored). The application attempts to connect to MongoDB for audit/event persistence.

**After upgrade (v3.0.0):**  
The application will run with `MONGO_ENABLED="false"`. MongoDB integration will be disabled; audit events will not be persisted.

**Action required:**  
If you intended to disable MongoDB, no action is required. If you need MongoDB, remove the `false` override or set it to `true`.

#### Scenario 3: You set `TLS_TERMINATED_UPSTREAM: false`

**Current state (v2.8.0):**  
The application is running with `TLS_TERMINATED_UPSTREAM="true"` (your override was ignored). Health check endpoints assume TLS is terminated upstream.

**After upgrade (v3.0.0):**  
The application will run with `TLS_TERMINATED_UPSTREAM="false"`. Health check endpoints will expect direct TLS connections.

**Action required:**  
Review your ingress/load balancer configuration. If TLS is terminated upstream (most common), remove the `false` override or set it to `true`.

### Step 2: Test Flag Behavior

After reviewing your overrides, test the upgrade in a non-production environment:

1. **Deploy v3.0.0 with your current values:**

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.0 -n plugin-br-bank-transfer -f values.yaml --dry-run --debug
```

2. **Inspect the rendered ConfigMap:**

```bash
helm get manifest plugin-br-bank-transfer -n plugin-br-bank-transfer | grep -A 50 "kind: ConfigMap"
```

3. **Verify the three flags are set to your expected values:**

```bash
# Check TLS_TERMINATED_UPSTREAM
helm get manifest plugin-br-bank-transfer -n plugin-br-bank-transfer | grep TLS_TERMINATED_UPSTREAM

# Check MONGO_ENABLED
helm get manifest plugin-br-bank-transfer -n plugin-br-bank-transfer | grep MONGO_ENABLED

# Check ALLOW_INSECURE_TLS
helm get manifest plugin-br-bank-transfer -n plugin-br-bank-transfer | grep ALLOW_INSECURE_TLS
```

4. **If the values are incorrect, update your `values.yaml`:**

```yaml
bankTransfer:
  configmap:
    TLS_TERMINATED_UPSTREAM: true  # or false, depending on your setup
    MONGO_ENABLED: true  # or false, depending on your setup
    ALLOW_INSECURE_TLS: true  # or false, depending on your setup
```

5. **Perform the upgrade in your test environment and validate application behavior:**

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.0 -n plugin-br-bank-transfer -f values.yaml
```

6. **Check application logs for TLS or MongoDB connection errors:**

```bash
kubectl logs -n plugin-br-bank-transfer -l app.kubernetes.io/name=bank-transfer --tail=100
```

> **Important:** If you use `ALLOW_INSECURE_TLS: false` and your infrastructure uses self-signed certificates, you will see TLS handshake errors in the logs. You must either provide valid CA certificates or set `ALLOW_INSECURE_TLS: true`.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 3.0.0 -n plugin-br-bank-transfer
```

> **Important:** If you have explicitly set `TLS_TERMINATED_UPSTREAM`, `MONGO_ENABLED`, or `ALLOW_INSECURE_TLS` to `false` in your values, review [Migration Steps](#migration-steps) before upgrading and include your updated values file with the upgrade command: `-f values.yaml`
<!-- {% endraw %} -->
