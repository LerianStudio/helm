<!-- {% raw %} -->
# Helm Upgrade from v2.4.0 to v2.4.1

## Topics

- **[Overview](#overview)**
- **[Documentation Improvements](#documentation-improvements)**
  - [1. PodDisruptionBudget Configuration Clarification](#1-poddisruptionbudget-configuration-clarification)
  - [2. Multi-Tenant Environment Variables Documentation](#2-multi-tenant-environment-variables-documentation)
  - [3. RabbitMQ URL Configuration Guidance](#3-rabbitmq-url-configuration-guidance)
  - [4. Deprecated Authentication Variables](#4-deprecated-authentication-variables)
  - [5. Systemplane Configuration Clarification](#5-systemplane-configuration-clarification)
- **[Template Fixes](#template-fixes)**
  - [1. Multi-Tenant Flag Case-Insensitive Comparison](#1-multi-tenant-flag-case-insensitive-comparison)
  - [2. Consistent Multi-Tenant Detection Across Templates](#2-consistent-multi-tenant-detection-across-templates)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.4.1 is a patch release that improves documentation clarity and fixes template logic for multi-tenant mode detection. There are **no breaking changes**, no new features, and no configuration changes required. All changes are non-functional: they clarify existing behavior in comments and fix a minor case-sensitivity bug in template conditionals.

Operators can upgrade without modifying their values files. The changes improve operational clarity for PodDisruptionBudget configuration, multi-tenant environment variables, RabbitMQ URL handling, and deprecated authentication fields.

## Documentation Improvements

### 1. PodDisruptionBudget Configuration Clarification

**What changed:**  
The comments for `bankTransfer.pdb.minAvailable` and `bankTransfer.pdb.maxUnavailable` now explicitly document their precedence relationship.

**Before (v2.4.0):**
```yaml
bankTransfer:
  pdb:
    enabled: true
    # -- Minimum number of available pods
    minAvailable: 1
    # -- Maximum number of unavailable pods
    maxUnavailable: 1
```

**After (v2.4.1):**
```yaml
bankTransfer:
  pdb:
    enabled: true
    # -- Minimum number of available pods. Ignored while maxUnavailable is set
    # (templates/pdb.yaml renders maxUnavailable first); clear maxUnavailable
    # to use it.
    minAvailable: 1
    # -- Maximum number of unavailable pods. Takes precedence over minAvailable
    maxUnavailable: 1
```

**Why it matters:**  
Kubernetes PodDisruptionBudget resources accept either `minAvailable` or `maxUnavailable`, but not both. The chart's PDB template (`templates/pdb.yaml`) renders `maxUnavailable` first when set, which means `minAvailable` is ignored if both are configured. The updated comments make this precedence explicit.

**Operational impact:**  
- If you currently set both `minAvailable` and `maxUnavailable`, only `maxUnavailable` is applied
- To use `minAvailable`, you must explicitly clear `maxUnavailable` (set it to `null` or remove it from your values)
- Default behavior is unchanged: `maxUnavailable: 1` takes precedence

**Migration required:**  
No — this is a documentation-only change. If you want to switch from `maxUnavailable` to `minAvailable`, update your values:

```yaml
bankTransfer:
  pdb:
    minAvailable: 2
    maxUnavailable: null  # Clear to use minAvailable
```

### 2. Multi-Tenant Environment Variables Documentation

**What changed:**  
The comments for multi-tenant configuration now clarify which environment variables are automatically emitted by the chart and which must be set manually via `bankTransfer.extraEnvVars`.

**Before (v2.4.0):**
```yaml
bankTransfer:
  configmap:
    # When MULTI_TENANT_ENABLED=true the chart also emits:
    #   MULTI_TENANT_URL, AWS_REGION, MULTI_TENANT_REDIS_HOST,
    #   MULTI_TENANT_REDIS_PORT, MULTI_TENANT_REDIS_TLS,
    #   MULTI_TENANT_ENVIRONMENT, MULTI_TENANT_ALLOW_INSECURE_HTTP,
    #   MULTI_TENANT_INTEGRATION_SECRET_NAME_TEMPLATE
    # Optional tuning (lib-commons defaults apply when unset):
    #   MULTI_TENANT_MAX_TENANT_POOLS, MULTI_TENANT_IDLE_TIMEOUT_SEC,
    #   MULTI_TENANT_TIMEOUT, MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD,
    #   MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC, MULTI_TENANT_CACHE_TTL_SEC
    # Set those under .configmap as needed.
```

**After (v2.4.1):**
```yaml
bankTransfer:
  configmap:
    # When MULTI_TENANT_ENABLED=true the chart also emits:
    #   MULTI_TENANT_URL, AWS_REGION, MULTI_TENANT_REDIS_HOST,
    #   MULTI_TENANT_REDIS_PORT, MULTI_TENANT_REDIS_TLS,
    #   MULTI_TENANT_ENVIRONMENT, MULTI_TENANT_ALLOW_INSECURE_HTTP
    # Optional tuning (lib-commons defaults apply when unset):
    #   MULTI_TENANT_MAX_TENANT_POOLS, MULTI_TENANT_IDLE_TIMEOUT_SEC,
    #   MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD,
    #   MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC
    # Set those under .configmap as needed.
    # MULTI_TENANT_TIMEOUT and MULTI_TENANT_CACHE_TTL_SEC are read by the app
    # (defaults 30 / 120) but no template renders them from .configmap; set
    # them through bankTransfer.extraEnvVars if you need to change them.
```

**Why it matters:**  
The chart's ConfigMap template does not render `MULTI_TENANT_INTEGRATION_SECRET_NAME_TEMPLATE`, `MULTI_TENANT_TIMEOUT`, or `MULTI_TENANT_CACHE_TTL_SEC` from `bankTransfer.configmap` values. The application uses built-in defaults for `MULTI_TENANT_TIMEOUT` (30 seconds) and `MULTI_TENANT_CACHE_TTL_SEC` (120 seconds). If you need to override these, you must use `bankTransfer.extraEnvVars` instead of setting them under `bankTransfer.configmap`.

**Operational impact:**  
- Setting `MULTI_TENANT_TIMEOUT` or `MULTI_TENANT_CACHE_TTL_SEC` under `bankTransfer.configmap` has no effect
- To override these values, use `bankTransfer.extraEnvVars`:

```yaml
bankTransfer:
  extraEnvVars:
    - name: MULTI_TENANT_TIMEOUT
      value: "60"
    - name: MULTI_TENANT_CACHE_TTL_SEC
      value: "300"
```

**Migration required:**  
No — the application defaults are unchanged. If you previously set these variables under `bankTransfer.configmap` and they were not taking effect, migrate them to `extraEnvVars` as shown above.

### 3. RabbitMQ URL Configuration Guidance

**What changed:**  
The comment for `RABBITMQ_URL` now explains a limitation when using the chart's default URL template with `RABBITMQ_ENABLED=true`.

**Before (v2.4.0):**
```yaml
bankTransfer:
  configmap:
    # =================================================================
    # RabbitMQ (event bus, optional)
    # RABBITMQ_URL is rendered from chart defaults when empty.
    # Retries / timeouts / routing-key prefix are systemplane-managed.
    # RABBITMQ_ENABLED/RABBITMQ_EXCHANGE are NOT pinned — the chart already
    # defaults them in templates/configmap.yaml.
```

**After (v2.4.1):**
```yaml
bankTransfer:
  configmap:
    # =================================================================
    # RabbitMQ (event bus, optional)
    # RABBITMQ_URL is rendered from a chart default when empty, but that default
    # embeds a $(RABBITMQ_PASSWORD) reference inside the ConfigMap, which
    # Kubernetes does not expand for envFrom. When RABBITMQ_ENABLED=true set
    # RABBITMQ_URL explicitly with the final URL.
    # Retries / timeouts / routing-key prefix are systemplane-managed.
    # RABBITMQ_ENABLED/RABBITMQ_EXCHANGE are NOT pinned — the chart already
    # defaults them in templates/configmap.yaml.
```

**Why it matters:**  
When `RABBITMQ_ENABLED=true` and `RABBITMQ_URL` is left empty, the chart's ConfigMap template generates a default URL containing a `$(RABBITMQ_PASSWORD)` shell variable reference. Kubernetes does **not** expand environment variable references for `envFrom: configMapRef` — only for explicit `env` entries with `value` fields. This means the application receives a literal string like `amqp://user:$(RABBITMQ_PASSWORD)@host:5672/` instead of the actual password.

**Operational impact:**  
- If you use RabbitMQ (`RABBITMQ_ENABLED=true`), you must explicitly set `RABBITMQ_URL` with the complete connection string, including the password
- The chart does not automatically assemble a working URL when using the bundled RabbitMQ subchart

**Migration required:**  
Yes, if you currently rely on the chart's default `RABBITMQ_URL` with `RABBITMQ_ENABLED=true`. Set the full URL explicitly:

```yaml
bankTransfer:
  configmap:
    RABBITMQ_ENABLED: "true"
    RABBITMQ_URL: "amqp://bank_transfer:<your-rabbitmq-password>@plugin-br-bank-transfer-rabbitmq.plugin-br-bank-transfer.svc.cluster.local:5672/"
```

> **Note:** Replace `<your-rabbitmq-password>` with the actual password from `rabbitmq.auth.password.value` or your existing RabbitMQ Secret.

### 4. Deprecated Authentication Variables

**What changed:**  
The comment for `PLUGIN_AUTH_CLIENT_ID` and `PLUGIN_AUTH_CLIENT_SECRET` now documents that these variables are no longer read by the application since v3.1.0.

**Before (v2.4.0):**
```yaml
bankTransfer:
  secrets:
    # Authentication (plugin-auth) - client secret for M2M auth
    # PLUGIN_AUTH_CLIENT_SECRET: ""
```

**After (v2.4.1):**
```yaml
bankTransfer:
  secrets:
    # PLUGIN_AUTH_CLIENT_ID/PLUGIN_AUTH_CLIENT_SECRET are not read by the app
    # since v3.1.0 (inbound auth needs only PLUGIN_AUTH_ADDRESS); do not set them.
```

**Why it matters:**  
Starting with application version 3.1.0 (the current `appVersion` for this chart), the bank-transfer service no longer uses client credentials for inbound authentication. It only requires `PLUGIN_AUTH_ADDRESS` to validate incoming tokens. Setting `PLUGIN_AUTH_CLIENT_ID` or `PLUGIN_AUTH_CLIENT_SECRET` has no effect.

**Operational impact:**  
- If you currently set `PLUGIN_AUTH_CLIENT_SECRET` in your values, you can remove it
- Inbound authentication is configured via `PLUGIN_AUTH_ADDRESS` only (set under `bankTransfer.configmap`)

**Migration required:**  
No — the application ignores these variables. You can optionally clean up your values file:

```yaml
bankTransfer:
  configmap:
    PLUGIN_AUTH_ADDRESS: "http://plugin-auth.default.svc.cluster.local:3000"
  secrets:
    # Remove these if present:
    # PLUGIN_AUTH_CLIENT_ID: ""
    # PLUGIN_AUTH_CLIENT_SECRET: ""
```

### 5. Systemplane Configuration Clarification

**What changed:**  
The comment for Systemplane secrets now clarifies that the chart does not render `SYSTEMPLANE_SECRET_MASTER_KEY` and that `SYSTEMPLANE_POSTGRES_DSN` does not exist in the application.

**Before (v2.4.0):**
```yaml
bankTransfer:
  secrets:
    # Systemplane Secrets (optional - for runtime config)
    # SYSTEMPLANE_SECRET_MASTER_KEY: ""
    # SYSTEMPLANE_POSTGRES_DSN: ""
```

**After (v2.4.1):**
```yaml
bankTransfer:
  secrets:
    # Systemplane: templates/secrets.yaml does not render SYSTEMPLANE_SECRET_MASTER_KEY,
    # and no SYSTEMPLANE_POSTGRES_DSN exists in the app (systemplane uses the
    # primary Postgres connection). The app's own README still lists the master
    # key for local runs; if your image needs it, supply it through
    # bankTransfer.useExistingSecret.
```

**Why it matters:**  
- The chart's Secret template does not include `SYSTEMPLANE_SECRET_MASTER_KEY` — setting it under `bankTransfer.secrets` has no effect
- The application does not read `SYSTEMPLANE_POSTGRES_DSN` — systemplane uses the primary `POSTGRES_*` connection variables
- If your application image requires `SYSTEMPLANE_SECRET_MASTER_KEY` (e.g., for local development), you must supply it via an external Secret referenced by `bankTransfer.useExistingSecret`

**Operational impact:**  
- Setting `SYSTEMPLANE_SECRET_MASTER_KEY` or `SYSTEMPLANE_POSTGRES_DSN` under `bankTransfer.secrets` has no effect
- If you need `SYSTEMPLANE_SECRET_MASTER_KEY`, create an external Secret and reference it:

```yaml
bankTransfer:
  useExistingSecret: true
  existingSecretName: "my-systemplane-secret"
```

```bash
kubectl create secret generic my-systemplane-secret \
  --from-literal=SYSTEMPLANE_SECRET_MASTER_KEY='<your-master-key>' \
  -n plugin-br-bank-transfer
```

**Migration required:**  
No — the application does not require these variables in production. If you previously set them under `bankTransfer.secrets`, they were not being rendered.

## Template Fixes

### 1. Multi-Tenant Flag Case-Insensitive Comparison

**What changed:**  
The `templates/configmap.yaml` template now uses a case-insensitive comparison when resolving the `MULTI_TENANT_ENABLED` flag.

**Before (v2.4.0):**
```yaml
{{- $mtRaw := include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false") -}}
{{- $multiTenantEnabled := eq (toString $mtRaw) "true" }}
```

**After (v2.4.1):**
```yaml
{{- $mtRaw := include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false") -}}
{{- $multiTenantEnabled := eq (lower (toString $mtRaw)) "true" }}
```

**Why it matters:**  
The `lerian-common.globalValue` helper can return `MULTI_TENANT_ENABLED` from multiple sources (`global.multiTenant.enabled`, `bankTransfer.configmap.MULTI_TENANT_ENABLED`, etc.). If an operator sets the value as `"True"` or `"TRUE"` (uppercase), the previous case-sensitive comparison would fail, causing the chart to skip multi-tenant-specific ConfigMap entries.

The fix ensures that `"true"`, `"True"`, and `"TRUE"` are all recognized as true values.

**Operational impact:**  
- If you currently set `MULTI_TENANT_ENABLED: "true"` (lowercase), no change in behavior
- If you previously set `MULTI_TENANT_ENABLED: "True"` or `"TRUE"` and multi-tenant variables were not being emitted, they will now be emitted correctly

**Migration required:**  
No — the fix is backward-compatible and improves robustness.

### 2. Consistent Multi-Tenant Detection Across Templates

**What changed:**  
The `templates/deployment.yaml` and `templates/migration-secret.yaml` templates now use the same `lerian-common.globalValue` helper and case-insensitive comparison as `templates/configmap.yaml` when detecting multi-tenant mode.

**Before (v2.4.0):**
```yaml
# templates/deployment.yaml
{{- $multiTenantEnabled := eq (toString (.Values.bankTransfer.configmap.MULTI_TENANT_ENABLED | default "false")) "true" }}

# templates/migration-secret.yaml
{{- $multiTenant := eq (lower (toString (get $configmap "MULTI_TENANT_ENABLED" | default "false"))) "true" }}
```

**After (v2.4.1):**
```yaml
# templates/deployment.yaml
{{- $multiTenantEnabledRaw := include "lerian-common.globalValue" (dict "context" $ "configmap" (.Values.bankTransfer.configmap | default dict) "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false") }}
{{- $multiTenantEnabled := eq (lower (toString $multiTenantEnabledRaw)) "true" }}

# templates/migration-secret.yaml
{{- $multiTenantRaw := include "lerian-common.globalValue" (dict "context" $ "configmap" $configmap "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false") -}}
{{- $multiTenant := eq (lower (toString $multiTenantRaw)) "true" }}
```

**Why it matters:**  
The deployment template controls whether init containers wait for PostgreSQL/Valkey dependencies, and the migration-secret template controls whether a standalone migration Secret is rendered. Both templates must use the same multi-tenant detection logic as the ConfigMap to ensure consistent behavior.

**Operational impact:**  
- In multi-tenant mode, the deployment skips dependency wait containers (because per-tenant datastores are resolved at runtime)
- In single-tenant mode, the deployment waits for PostgreSQL and Valkey to be ready before starting
- The migration Secret is only rendered for single-tenant, external PostgreSQL setups
- All three templates now honor `global.multiTenant.enabled` and case-insensitive string values consistently

**Migration required:**  
No — the fix ensures consistent behavior across templates. If you use `global.multiTenant.enabled` or set `MULTI_TENANT_ENABLED` with uppercase values, the deployment and migration logic will now match the ConfigMap.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.4.1 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.4.1 -n plugin-br-bank-transfer
```
<!-- {% endraw %} -->
