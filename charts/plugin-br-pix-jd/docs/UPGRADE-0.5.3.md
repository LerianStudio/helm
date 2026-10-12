# Helm Upgrade from v0.5.2 to v0.5.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application Version Bump](#1-application-version-bump)
  - [2. ALLOW_INSECURE_TLS Scope Expansion](#2-allow_insecure_tls-scope-expansion)
  - [3. MULTI_TENANT_ALLOW_INSECURE_HTTP Removal](#3-multi_tenant_allow_insecure_http-removal)
- **[Migration Impact](#migration-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** that updates the application version from 1.2.0 to 1.2.1 and consolidates TLS/HTTP security configuration. The chart now uses a single environment variable (`ALLOW_INSECURE_TLS`) to control both plaintext datastore connections and plain-HTTP upstream calls, replacing the deprecated `MULTI_TENANT_ALLOW_INSECURE_HTTP`.

| Setting | v0.5.2 | v0.5.3 |
|---------|--------|--------|
| Chart Version | 0.5.2 | 0.5.3 |
| App Version | 1.2.0 | 1.2.1 |
| API Image Tag | 1.2.0 | 1.2.1 |
| Migrations Image Tag | 1.2.0 | 1.2.1 |

## Fixes

### 1. Application Version Bump

The chart now ships application version **1.2.1** (previously 1.2.0). All component images are updated to this tag:

**Before (v0.5.2):**

```yaml
appVersion: "1.2.0"

api:
  image:
    tag: ""  # Falls back to 1.2.0

migrations:
  image:
    tag: "1.2.0"
```

**After (v0.5.3):**

```yaml
appVersion: "1.2.1"

api:
  image:
    tag: ""  # Falls back to 1.2.1

migrations:
  image:
    tag: "1.2.1"
```

**Operational impact:**

- If you have **not** pinned `api.image.tag` explicitly, the upgrade will pull the new `1.2.1` image and roll out API and worker pods
- If you **have** pinned `api.image.tag` to a specific version, your override takes precedence and no image change occurs
- The migrations Job will use the `1.2.1` migrations image on the next `helm upgrade`

> **Note:** The 1.2.1 application release includes the security configuration consolidation described below. No other functional changes are documented in this chart upgrade.

### 2. ALLOW_INSECURE_TLS Scope Expansion

The `ALLOW_INSECURE_TLS` environment variable now controls **both** plaintext datastore connections (Redis, Postgres) **and** plain-HTTP upstream calls (ledger, Access Manager, Tenant Manager, tenant `jd.base_url`, indirect-participant delivery).

**Before (v0.5.2):**

The chart documentation and template comments described `ALLOW_INSECURE_TLS` as controlling only internal datastore TLS:

```yaml
# _helpers.tpl comment (v0.5.2):
# ALLOW_INSECURE_TLS is deliberately NOT here: the app treats it as the one
# sovereign switch for internal-datastore TLS in any environment.
```

**After (v0.5.3):**

The template comments now reflect the expanded scope:

```yaml
# _helpers.tpl comment (v0.5.3):
# Since app 1.2.1 it is also the one opt-out for plain-http upstreams: the ledger, the
# Access Manager token exchange, the tenant manager, a tenant's jd.base_url and
# indirect-participant delivery. It replaces MULTI_TENANT_ALLOW_INSECURE_HTTP, which
# the app no longer reads and the chart no longer emits.
#
# Deliberately NOT in the production-bypass gate, unlike the other three ALLOW_*: the
# app treats this one as the single sovereign switch for plaintext datastores and http
# upstreams in ANY environment (config_validation.go says so explicitly, and both the
# production guard and the SaaS TLS enforcement defer to it).
```

**Operational impact:**

- If you have **not** set `ALLOW_INSECURE_TLS`, the default remains `false` (secure mode) — all datastores and upstreams must use TLS/HTTPS
- If you **have** set `ALLOW_INSECURE_TLS=true` for plaintext Redis or Postgres, the application will now **also** allow plain-HTTP upstream calls (ledger, tenant manager, etc.)
- This is a **security-relevant change**: enabling `ALLOW_INSECURE_TLS` now opts out of TLS enforcement for both datastores and HTTP clients

**Configuration example:**

```yaml
api:
  configmap:
    ALLOW_INSECURE_TLS: "true"  # Now permits both plaintext datastores AND http:// upstreams
```

> **Warning:** Setting `ALLOW_INSECURE_TLS=true` in production environments is **not recommended**. It disables TLS verification for all outbound connections, including tenant-specific JDPI endpoints and indirect-participant webhooks.

### 3. MULTI_TENANT_ALLOW_INSECURE_HTTP Removal

The chart no longer emits the `MULTI_TENANT_ALLOW_INSECURE_HTTP` environment variable. The application (as of 1.2.1) no longer reads it; `ALLOW_INSECURE_TLS` is now the single control for all plaintext connections.

**Before (v0.5.2):**

The chart rendered `MULTI_TENANT_ALLOW_INSECURE_HTTP` from the multi-tenant configuration block:

```yaml
# _helpers.tpl (v0.5.2):
{{ include "lerian-common.multiTenant.envFlat" (dict
      "configmap" $cm
      "keys" (list "MULTI_TENANT_URL" "MULTI_TENANT_ALLOW_INSECURE_HTTP"
                   "MULTI_TENANT_MAX_TENANT_POOLS" "MULTI_TENANT_IDLE_TIMEOUT_SEC"
                   ...)
```

**After (v0.5.3):**

The variable is removed from the template:

```yaml
# _helpers.tpl (v0.5.3):
{{ include "lerian-common.multiTenant.envFlat" (dict
      "configmap" $cm
      "keys" (list "MULTI_TENANT_URL"
                   "MULTI_TENANT_MAX_TENANT_POOLS" "MULTI_TENANT_IDLE_TIMEOUT_SEC"
                   ...)
```

**Operational impact:**

- If you have **not** set `MULTI_TENANT_ALLOW_INSECURE_HTTP` in your values, no action is required
- If you **have** set it explicitly, the chart will ignore it and the application will not read it
- To permit plain-HTTP tenant manager calls, set `ALLOW_INSECURE_TLS=true` instead (see [Fix #2](#2-allow_insecure_tls-scope-expansion))

**Migration example:**

**Before (v0.5.2):**

```yaml
api:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_ALLOW_INSECURE_HTTP: "true"
```

**After (v0.5.3):**

```yaml
api:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    ALLOW_INSECURE_TLS: "true"  # Replaces MULTI_TENANT_ALLOW_INSECURE_HTTP
```

> **Important:** If you were using `MULTI_TENANT_ALLOW_INSECURE_HTTP=true` to permit plain-HTTP tenant manager calls, you must now set `ALLOW_INSECURE_TLS=true`. Be aware this also permits plaintext datastores and other HTTP upstreams.

## Migration Impact

**No action required** for most deployments. The upgrade will:

1. Update the API and worker images to 1.2.1 (if not pinned)
2. Update the migrations image to 1.2.1
3. Remove `MULTI_TENANT_ALLOW_INSECURE_HTTP` from the rendered ConfigMap (if present)

**Action required** if you were using `MULTI_TENANT_ALLOW_INSECURE_HTTP`:

1. Remove `MULTI_TENANT_ALLOW_INSECURE_HTTP` from your `values.yaml`
2. Add `ALLOW_INSECURE_TLS: "true"` to `api.configmap` if you need plain-HTTP upstream calls
3. Review the security implications of enabling `ALLOW_INSECURE_TLS` (see [Fix #2](#2-allow_insecure_tls-scope-expansion))

**Example migration:**

```yaml
# values.yaml (v0.5.2)
api:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_ALLOW_INSECURE_HTTP: "true"
```

```yaml
# values.yaml (v0.5.3)
api:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    ALLOW_INSECURE_TLS: "true"
```

> **Note:** If you are running in a production environment with `ENVIRONMENT_NAME=production` and `DEPLOYMENT_MODE=saas`, the application will reject `ALLOW_INSECURE_TLS=true` at boot. This is by design — the chart defers to the application's production security gates.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.3 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.3 -n plugin-br-pix-jd
```
