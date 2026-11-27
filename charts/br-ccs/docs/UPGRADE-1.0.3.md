# Helm Upgrade from v1.0.2 to v1.0.3

## Topics

- **[Overview](#overview)**
- **[Boot contract validation](#boot-contract-validation)**
  - [1. What changed](#1-what-changed)
  - [2. Why it matters](#2-why-it-matters)
  - [3. When validation runs](#3-when-validation-runs)
  - [4. Common validation failures and fixes](#4-common-validation-failures-and-fixes)
- **[Default authentication behavior change](#default-authentication-behavior-change)**
  - [Migration scenarios](#migration-scenarios)
- **[Chart metadata update](#chart-metadata-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Chart version 1.0.3 is a **patch release** that adds boot contract validation to prevent runtime failures. The chart now validates configuration at render time instead of allowing the pod to crash-loop with missing or invalid values.

**No breaking changes to working configurations.** Existing installations with complete, valid configuration will upgrade without modification. Installations with incomplete configuration that previously crash-looped will now fail at `helm template` / `helm install` / `helm upgrade` with actionable error messages.

| Aspect | v1.0.2 | v1.0.3 |
|--------|--------|--------|
| Chart version | 1.0.2 | 1.0.3 |
| App version | 1.1.2 | 1.1.2 (unchanged) |
| Breaking changes | N/A | None (validation enforces existing app requirements) |
| New template files | N/A | `templates/_validate.tpl`, `templates/boot-contract.yaml` |
| Default `PLUGIN_AUTH_ENABLED` | `false` | `true` |

## Boot contract validation

### 1. What changed

Chart 1.0.3 adds comprehensive validation that mirrors the application's boot requirements. Each validation check corresponds to a specific boot failure in `br-ccs` (services/ccs, version 1.1.x). Previously, operators discovered missing or invalid configuration one variable at a time through pod crash loops. Now, the same mistakes fail at render time with clear instructions on which value to fix.

**New template files:**

- `templates/_validate.tpl` — 281 lines of validation logic covering 10 boot requirement categories
- `templates/boot-contract.yaml` — empty resource that triggers validation when `brCcs.enabled: true`

**Validation scope:**

1. Secret keys must be in `brCcs.secrets`, not `brCcs.extraEnvVars` (ConfigMap is plaintext)
2. Boolean environment variables must be exactly `"true"` or `"false"` (app refuses `"1"`, `"yes"`, `"TRUE"`)
3. `PLUGIN_AUTH_ENABLED` must be `"true"` in production/staging/uat and SaaS deployments
4. When auth is enabled: `PLUGIN_AUTH_HOST` and M2M credentials (Reporter, STA) are required
5. Object storage encryption must be explicitly configured for both buckets
6. `LICENSE_KEY` is required in every environment
7. `CCS_CRYPTO_MASTER_KEY` must be 64 hex characters (AES-256)
8. Production requires non-empty `TRUSTED_PROXIES` and `CORS_ALLOWED_ORIGINS` without wildcards
9. Reporter detail templates must be configured (IDs or names for CCS0002, CCS0004, ACCS005)
10. Redis TLS must be enabled or explicitly bypassed with `ALLOW_INSECURE_REDIS`
11. CRM URL must be absolute HTTPS (outside development) with organization ID
12. Reporter URL is always required (app no longer reads `REPORTER_ENABLED`)

### 2. Why it matters

**Before (v1.0.2):**

An incomplete configuration would render successfully and deploy. The pod would crash-loop with errors like:

```
PLUGIN_AUTH_HOST is required when PLUGIN_AUTH_ENABLED=true
```

The operator would fix that variable, redeploy, and encounter the next missing requirement:

```
REPORTER_CLIENT_ID is required when PLUGIN_AUTH_ENABLED=true
```

This cycle repeated for every missing or invalid value.

**After (v1.0.3):**

The same incomplete configuration fails at `helm template` / `helm upgrade`:

```
Error: execution error at (br-ccs/templates/boot-contract.yaml:4:4): br-ccs: PLUGIN_AUTH_HOST is required when PLUGIN_AUTH_ENABLED=true. Set brCcs.configmap.PLUGIN_AUTH_HOST or global.auth.host (the plugin-access-manager URL).
```

All validation errors appear immediately with actionable instructions. No pod is created until configuration is complete.

### 3. When validation runs

Validation runs during every Helm operation that renders templates:

- `helm template`
- `helm install`
- `helm upgrade`
- `helm diff upgrade` (with helm-diff plugin)

Validation is **skipped** when `brCcs.enabled: false`. It does not run for disabled subcharts or when using `brCcs.useExistingSecret: true` (the chart cannot inspect external Secrets, so the application remains the final gate for secret values).

### 4. Common validation failures and fixes

#### Failure: Secret in extraEnvVars

**Error message:**

```
br-ccs: LICENSE_KEY is a secret: set it in brCcs.secrets, not brCcs.extraEnvVars (extraEnvVars renders into the ConfigMap in plaintext).
```

**Fix:**

Move the value from `brCcs.extraEnvVars` to `brCcs.secrets`:

```yaml
# Before (v1.0.2) — WRONG, but rendered successfully
brCcs:
  extraEnvVars:
    LICENSE_KEY: "your-license-key-here"
```

```yaml
# After (v1.0.3) — correct
brCcs:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

#### Failure: Boolean spelled incorrectly

**Error message:**

```
br-ccs: REDIS_TLS must be exactly "true" or "false" (the app refuses any other spelling at boot); got "1".
```

**Fix:**

Use exact boolean strings:

```yaml
# Before (v1.0.2) — rendered but app refused at boot
brCcs:
  configmap:
    REDIS_TLS: "1"
```

```yaml
# After (v1.0.3) — correct
brCcs:
  configmap:
    REDIS_TLS: "true"
```

#### Failure: Auth enabled without host

**Error message:**

```
br-ccs: PLUGIN_AUTH_HOST is required when PLUGIN_AUTH_ENABLED=true. Set brCcs.configmap.PLUGIN_AUTH_HOST or global.auth.host (the plugin-access-manager URL).
```

**Fix:**

Set the plugin-access-manager URL:

```yaml
brCcs:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_HOST: "http://plugin-access-manager:4000"
```

Or use global configuration:

```yaml
global:
  auth:
    enabled: "true"
    host: "http://plugin-access-manager:4000"
```

#### Failure: Missing M2M credentials

**Error message:**

```
br-ccs: brCcs.secrets.REPORTER_CLIENT_SECRET is required when PLUGIN_AUTH_ENABLED=true (the app requires the Reporter and STA M2M credentials even with STA_ENABLED=false).
```

**Fix:**

Provide all four M2M credentials:

```yaml
brCcs:
  secrets:
    REPORTER_CLIENT_ID: "reporter-client-id"
    REPORTER_CLIENT_SECRET: "reporter-client-secret"
    STA_CLIENT_ID: "sta-client-id"
    STA_CLIENT_SECRET: "sta-client-secret"
```

#### Failure: Object storage encryption not configured

**Error message:**

```
br-ccs: brCcs.configmap.OBJECT_STORAGE_STA_SSE_ALGORITHM is required (bucket "sta-files" is bound). Accepted values: AES256 (recommended), aws:kms (with OBJECT_STORAGE_STA_SSE_KMS_KEY_ID), none (development only).
```

**Fix:**

Configure encryption for both buckets:

```yaml
brCcs:
  configmap:
    OBJECT_STORAGE_STA_SSE_ALGORITHM: "AES256"
    OBJECT_STORAGE_CCS_SSE_ALGORITHM: "AES256"
```

For AWS KMS:

```yaml
brCcs:
  configmap:
    OBJECT_STORAGE_STA_SSE_ALGORITHM: "aws:kms"
    OBJECT_STORAGE_STA_SSE_KMS_KEY_ID: "arn:aws:kms:region:account:key/key-id"
    OBJECT_STORAGE_CCS_SSE_ALGORITHM: "aws:kms"
    OBJECT_STORAGE_CCS_SSE_KMS_KEY_ID: "arn:aws:kms:region:account:key/key-id"
```

#### Failure: Missing license key

**Error message:**

```
br-ccs: brCcs.secrets.LICENSE_KEY is required in every environment (the app refuses to boot without a license).
```

**Fix:**

Provide the license key:

```yaml
brCcs:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

#### Failure: Invalid crypto master key

**Error message:**

```
br-ccs: brCcs.secrets.CCS_CRYPTO_MASTER_KEY must be 64 hex chars (openssl rand -hex 32); got 32 chars or a non-hex value.
```

**Fix:**

Generate a valid AES-256 key:

```bash
openssl rand -hex 32
```

Then set it:

```yaml
brCcs:
  secrets:
    CCS_CRYPTO_MASTER_KEY: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
```

#### Failure: Production gates

**Error message:**

```
br-ccs: brCcs.configmap.TRUSTED_PROXIES is required when ENV_NAME=production (comma-separated IPs or CIDRs of the L7 proxies, e.g. 10.0.0.0/8).
```

**Fix:**

Set both production-required fields:

```yaml
brCcs:
  configmap:
    ENV_NAME: "production"
    TRUSTED_PROXIES: "10.0.0.0/8,172.16.0.0/12"
    CORS_ALLOWED_ORIGINS: "https://console.example.com,https://app.example.com"
```

#### Failure: Missing Reporter templates

**Error message:**

```
br-ccs: brCcs.configmap.REPORTER_TEMPLATE_NAME_CCS0002 (or REPORTER_TEMPLATE_ID_CCS0002) is required: the app renders the CCS0002 detail answer through the Reporter.
```

**Fix:**

Configure all required templates:

```yaml
brCcs:
  configmap:
    REPORTER_TEMPLATE_NAME_CCS0002: "ccs-detail-template"
    REPORTER_TEMPLATE_NAME_CCS0004: "ccs-detail-template"
    REPORTER_TEMPLATE_NAME_ACCS005: "accs-detail-template"
```

Or use template IDs:

```yaml
brCcs:
  configmap:
    REPORTER_TEMPLATE_ID_CCS0002: "template-uuid-1"
    REPORTER_TEMPLATE_ID_CCS0004: "template-uuid-2"
    REPORTER_TEMPLATE_ID_ACCS005: "template-uuid-3"
```

#### Failure: Redis TLS without bypass

**Error message:**

```
br-ccs: REDIS_TLS=false needs ALLOW_INSECURE_REDIS="true" (the app refuses plaintext Redis otherwise). Prefer REDIS_TLS="true", with brCcs.secrets.REDIS_CA_CERT (base64 PEM) for a private CA.
```

**Fix:**

Enable Redis TLS (recommended):

```yaml
brCcs:
  configmap:
    REDIS_TLS: "true"
  secrets:
    REDIS_CA_CERT: "LS0tLS1CRUdJTi..."  # base64-encoded CA certificate
```

Or explicitly allow plaintext (development only):

```yaml
brCcs:
  configmap:
    REDIS_TLS: "false"
    ALLOW_INSECURE_REDIS: "true"
```

#### Failure: Missing CRM configuration

**Error message:**

```
br-ccs: brCcs.configmap.CRM_URL is required: the absolute URL of the Midaz CRM (https outside development).
```

**Fix:**

Configure CRM integration:

```yaml
brCcs:
  configmap:
    CRM_URL: "https://crm.example.com"
    CRM_ORGANIZATION_ID: "org-uuid"
```

#### Failure: Missing Reporter URL

**Error message:**

```
br-ccs: brCcs.configmap.REPORTER_URL is required: the app always dials the Reporter (REPORTER_ENABLED is no longer read).
```

**Fix:**

Set the Reporter URL:

```yaml
brCcs:
  configmap:
    REPORTER_URL: "https://reporter.example.com"
```

> **Important:** The application no longer reads `REPORTER_ENABLED`. The Reporter integration is always active and requires `OUTBOX_ENABLED="true"` and `CIRCUIT_BREAKER_ENABLED="true"` (both are chart defaults).

## Default authentication behavior change

### Migration scenarios

The default value for `PLUGIN_AUTH_ENABLED` changes from `false` to `true`. This aligns with the application's security requirements: authentication can only be disabled in development environments outside SaaS mode.

| Setting | v1.0.2 | v1.0.3 |
|---------|--------|--------|
| Default `PLUGIN_AUTH_ENABLED` | `false` | `true` |
| Chart comment guidance | "Leave empty ({}) for the chart defaults (PLUGIN_AUTH_ENABLED=false, HOST unset)" | "Leave empty ({}) for the chart defaults (PLUGIN_AUTH_ENABLED=true, HOST unset; the chart then requires brCcs.configmap.PLUGIN_AUTH_HOST)" |

#### Scenario 1: Development environment with auth disabled

**Current configuration (v1.0.2):**

```yaml
brCcs:
  configmap:
    ENV_NAME: "development"
    # PLUGIN_AUTH_ENABLED defaults to false
```

**Action required:** Explicitly set `PLUGIN_AUTH_ENABLED: "false"` to preserve the current behavior:

```yaml
brCcs:
  configmap:
    ENV_NAME: "development"
    PLUGIN_AUTH_ENABLED: "false"
```

Or use global configuration:

```yaml
global:
  auth:
    enabled: "false"
brCcs:
  configmap:
    ENV_NAME: "development"
```

> **Warning:** `PLUGIN_AUTH_ENABLED: "false"` is only accepted when `ENV_NAME` is a development-class name (`development`, `develop`, `dev`, `local`, `test`) and `DEPLOYMENT_MODE` is not `saas`. Production, staging, and uat environments must use `PLUGIN_AUTH_ENABLED: "true"`.

#### Scenario 2: Production environment (auth required)

**Current configuration (v1.0.2):**

```yaml
brCcs:
  configmap:
    ENV_NAME: "production"
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_HOST: "http://plugin-access-manager:4000"
  secrets:
    REPORTER_CLIENT_ID: "reporter-id"
    REPORTER_CLIENT_SECRET: "reporter-secret"
    STA_CLIENT_ID: "sta-id"
    STA_CLIENT_SECRET: "sta-secret"
```

**Action required:** None. This configuration is already complete and will upgrade without changes.

#### Scenario 3: Upgrading from default auth disabled

**Current configuration (v1.0.2):**

```yaml
brCcs:
  configmap:
    ENV_NAME: "production"
    # PLUGIN_AUTH_ENABLED defaults to false (v1.0.2)
```

**Upgrade failure (v1.0.3):**

```
br-ccs: PLUGIN_AUTH_ENABLED=false is only accepted with a development ENV_NAME (development, develop, dev, local, test) outside DEPLOYMENT_MODE=saas; got ENV_NAME="production". Set PLUGIN_AUTH_ENABLED="true" and PLUGIN_AUTH_HOST.
```

**Fix:** Enable authentication and provide required configuration:

```yaml
brCcs:
  configmap:
    ENV_NAME: "production"
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_HOST: "http://plugin-access-manager:4000"
  secrets:
    REPORTER_CLIENT_ID: "reporter-id"
    REPORTER_CLIENT_SECRET: "reporter-secret"
    STA_CLIENT_ID: "sta-id"
    STA_CLIENT_SECRET: "sta-secret"
```

## Chart metadata update

The chart source repository reference changes to reflect the application's new location:

| Field | v1.0.2 | v1.0.3 |
|-------|--------|--------|
| `sources[1]` | `https://github.com/LerianStudio/br-ccs` | `https://github.com/LerianStudio/br-sfn/tree/main/services/ccs` |

This is a documentation change only. No operator action is required.

## Preview changes before upgrading

```bash
helm diff upgrade br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm --version 1.0.3 -n br-ccs
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm --version 1.0.3 -n br-ccs
```
