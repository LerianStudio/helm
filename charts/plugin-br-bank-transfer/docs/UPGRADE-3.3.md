<!-- {% raw %} -->
# Helm Upgrade from v3.2.4 to v3.3.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Partner Antifraud Configuration](#1-partner-antifraud-configuration)
  - [2. Authentication Decision Cache](#2-authentication-decision-cache)
- **[Configuration Reference](#configuration-reference)**
  - [New Antifraud Environment Variables](#new-antifraud-environment-variables)
  - [New Authentication Cache Variable](#new-authentication-cache-variable)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.3.0 upgrades the default application and migration images from v3.6.0 to v3.7.0 and adds optional partner antifraud and authorization-cache configuration. Tenant antifraud switches default to off and the authorization cache defaults to disabled, but adopting application v3.7.0 still requires database migrations and a rollout. Review explicit application and migration image pins: retained v3.6.0 pins do not adopt the new runtime features.

### Migration and recovery prerequisites

- Application v3.7.0 adds PostgreSQL migrations `000073`–`000076`: antifraud columns/status constraints and signing-artifact storage, a concurrent due-analysis index, default tenant-policy seeds, and `usage_reserved_amount`. Migrations `000073` and `000076` are required for transfer reads even when antifraud is off.
- Preserve `bankTransfer.migrations.enabled` and a migration image compatible with the application. With external PostgreSQL, single-tenant migrations run in the existing `pre-install,pre-upgrade` hook; successful Jobs are deleted. With bundled PostgreSQL they run in the app pod's initContainer. Multi-tenant mode does not render this Job: v3.7.0 declares migration heads to Tenant Manager asynchronously; coordinate and verify every tenant schema before accepting traffic.
- Before upgrading, take private, consistent datastore backups and test restore/recovery. Preserve the current Helm revision, complete intended values, image pins and Secret references. Schedule for migration locks; `000074` uses `CREATE INDEX CONCURRENTLY`, whose failed build can leave an invalid index requiring operator diagnosis.
- Helm rollback does not reverse database migrations or restore data. Do not assume application downgrade is safe once v3.7.0 has created antifraud states. Migration `000073` down is destructive and refuses active `FRAUD_ANALYSIS` rows; do not use it as a routine production rollback. Agree a tested recovery plan before enabling tenant flows.

## Features

### 1. Partner Antifraud Configuration

**What changed:**  
The chart now supports configuration for partner antifraud integrations via two new environment variables: `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` and `ANTIFRAUD_SECRETS_BACKEND`.

**New configuration block in values.yaml:**

```yaml
bankTransfer:
  configmap:
    # Partner antifraud (app v3.7.0) — rendered only when set.
    # ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: exact hosts (comma-separated) a tenant
    # route may reach over http or a private address, e.g. an in-cluster
    # Flowker (BYOC / Lerian operation only; leave unset on Lerian Cloud).
    # ANTIFRAUD_SECRETS_BACKEND: where the antifraud credentials live, "aws" or
    # "vault"; no app default, and unset makes an enabled flow deny with
    # INVALID_CONFIG. Credentials come from the secret manager, never env.
    # ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: ""
    # ANTIFRAUD_SECRETS_BACKEND: ""
```

**Template changes:**

The ConfigMap template now conditionally renders these variables when set:

```yaml
# templates/configmap.yaml (new block)
  # -- Partner antifraud (app v3.7.0). ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: exact hosts
  # (comma-separated) a tenant route may reach over http or a private address, e.g. an
  # in-cluster Flowker; leave it unset on Lerian Cloud. ANTIFRAUD_SECRETS_BACKEND: aws or
  # vault, no app default; unset means no backend, so an enabled flow denies with
  # INVALID_CONFIG. Both are rendered only when set; routes and credentials are not
  # configured here (the app reads the credentials from the secret manager only).
  {{- with .Values.bankTransfer.configmap.ANTIFRAUD_ALLOWED_PRIVATE_HOSTS }}
  ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: {{ . | quote }}
  {{- end }}
  {{- with .Values.bankTransfer.configmap.ANTIFRAUD_SECRETS_BACKEND }}
  ANTIFRAUD_SECRETS_BACKEND: {{ . | quote }}
  {{- end }}
```

**Why it matters:**  
This feature enables partner-specific antifraud integrations for tenants. The application reads antifraud credentials from AWS Secrets Manager or HashiCorp Vault (never from environment variables), and these two configuration flags control:

1. **ANTIFRAUD_ALLOWED_PRIVATE_HOSTS**: A security allowlist for private/internal antifraud endpoints (e.g., an in-cluster Flowker instance in BYOC deployments)
2. **ANTIFRAUD_SECRETS_BACKEND**: The secret manager backend where antifraud credentials are stored

**Operational impact:**

- **Default behavior:** Tenant-policy flow switches default to off; these environment variables do not enable or disable them. An enabled flow without `ANTIFRAUD_SECRETS_BACKEND` denies with `INVALID_CONFIG`.
- **Lerian Cloud deployments:** Leave `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` unset so routes must use public HTTPS endpoints. Before enabling a tenant flow, the deployment operator must configure the supported secrets backend; leaving it unset does not provide working antifraud.
- **BYOC / Lerian-operated deployments:** Set `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` to allow internal antifraud endpoints (e.g., `"flowker.midaz-plugins.svc.cluster.local"`). Set `ANTIFRAUD_SECRETS_BACKEND` to `"aws"` or `"vault"` depending on your secret manager.

**Migration required:**  
No values migration is needed for these optional variables. The application schema prerequisites above still apply even with tenant antifraud off.

**Example configuration (BYOC with in-cluster Flowker):**

```yaml
bankTransfer:
  configmap:
    ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: "flowker.example.svc.cluster.local"
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

> **Important:** Antifraud credentials (API keys, tokens, etc.) are **never** configured in the Helm chart. The application reads them directly from the configured secret manager (AWS Secrets Manager or Vault) at runtime. Operators must ensure credentials are provisioned in the secret manager before enabling antifraud flows.

These snippets are fragments, not complete deployment configuration. Set tenant-policy routes and flow switches separately, provision the expected credential documents, and test a controlled flow before production enablement. Allowlist entries are bare exact hostnames or IP literals without scheme, port or path; invalid entries can fail startup. AWS needs the workload's supported AWS identity/region and access to the secret paths. Vault needs its own connection and authentication configuration (the pinned reader requires a Vault token); choosing `vault` alone is insufficient and can fail startup. Partner API credentials stay in the secret manager; secret-manager authentication is a separate prerequisite and must use private Secret references, never public values or command-line credentials.

### 2. Authentication Decision Cache

**What changed:**  
The chart now supports an optional `AUTH_CACHE_TTL` environment variable to enable caching of authentication/authorization decisions from the plugin-access-manager service.

**New configuration block in values.yaml:**

```yaml
bankTransfer:
  configmap:
    # AUTH_CACHE_TTL (app v3.7.0): lib-auth decision cache, a Go duration such
    # as "30s". Unset = no cache (lib-auth default); above 0 a partner change
    # reaches the pod only after the TTL.
    # AUTH_CACHE_TTL: ""
```

**Template changes:**

The ConfigMap template now conditionally renders this variable when set:

```yaml
# templates/configmap.yaml (new block)
  {{- /* lib-auth authorization decision cache (app v3.7.0), a Go duration. Rendered only
     when set: lib-auth's default is no cache. Above 0 it caches ALLOW and DENY, so a
     partner suspended or narrowed reaches the pod only after the TTL. */}}
  {{- with .Values.bankTransfer.configmap.AUTH_CACHE_TTL }}
  AUTH_CACHE_TTL: {{ . | quote }}
  {{- end }}
```

**Why it matters:**  
For requests that reach enabled per-route authorization, the cache stores successful authorization-service ALLOW and DENY decisions locally in each pod. Cache hits can avoid an authorization-service call; this is not a measured latency guarantee and does not apply to public routes, disabled auth, or requests refused by local guards.

**Trade-offs:**

| Aspect | No Cache (default) | Cache Enabled (e.g., `"30s"`) |
|--------|-------------------|-------------------------------|
| Authorization round trips | Applicable requests consult access-manager | Matching cache hits can avoid the round trip |
| Access-manager load | No decision-cache reduction | Can decrease with cache hits; workload-dependent |
| Partner changes propagation | Fresh service check on the next applicable request; upstream propagation still applies | An existing entry can delay observation by up to the TTL |
| Use case | Avoiding local decision-cache staleness | Accepting bounded local decision-cache staleness |

**Operational impact:**

- **Default behavior (unset or nonpositive TTL):** This decision cache is disabled; applicable authorized routes consult plugin-access-manager rather than reusing a decision-cache entry.
- **Cache enabled (TTL > 0):** Successful authorization responses (both ALLOW and DENY) are cached. A cached ALLOW can retain access after suspension/narrowing for up to the TTL; a cached DENY can delay reactivation. Entries are scoped to the token and authorization inputs (including client IP and instance attributes), not to all requests by a partner. Expiry, eviction, a new token or a different request key can trigger an earlier fresh check; failures are not a cached authorization grant.

**Migration required:**  
No — the variable is optional and unset by default (no cache).

**Example configuration (enable 30-second cache):**

```yaml
bankTransfer:
  configmap:
    AUTH_CACHE_TTL: "30s"
```

> **Warning:** A positive `AUTH_CACHE_TTL` permits stale cached decisions for up to the TTL in each pod. Do not enable caching where immediate partner suspension is required; disabling this cache alone does not guarantee immediate propagation through upstream systems.

**Supported duration formats:**

The value must be a valid Go duration string:

- `"30s"` — 30 seconds
- `"1m"` — 1 minute
- `"5m30s"` — 5 minutes 30 seconds
- `"1h"` — 1 hour

## Configuration Reference

### New Antifraud Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` | `""` (unset) | Comma-separated list of exact hostnames that tenant antifraud routes may reach over HTTP or private addresses (e.g., `"flowker.midaz-plugins.svc.cluster.local"`). Leave unset on Lerian Cloud; set only for BYOC/Lerian-operated deployments with in-cluster antifraud services. |
| `ANTIFRAUD_SECRETS_BACKEND` | `""` (unset) | Secret manager backend for antifraud credentials: `"aws"` (AWS Secrets Manager) or `"vault"` (HashiCorp Vault). Unset means no backend; an enabled antifraud flow will deny requests with `INVALID_CONFIG`. |

**Configuration location:**

```yaml
bankTransfer:
  configmap:
    ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: ""
    ANTIFRAUD_SECRETS_BACKEND: ""
```

**Rendering behavior:**

Both variables are rendered in the ConfigMap **only when explicitly set**. If left empty (the default), they are omitted from the ConfigMap entirely.

### New Authentication Cache Variable

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTH_CACHE_TTL` | `""` (unset, no cache) | Go duration string (e.g., `"30s"`, `"1m"`) controlling the per-pod authorization-decision cache. Unset/nonpositive disables it; positive values cache successful ALLOW and DENY responses for matching request keys, permitting stale decisions for up to the TTL. |

**Configuration location:**

```yaml
bankTransfer:
  configmap:
    AUTH_CACHE_TTL: ""
```

**Rendering behavior:**

The variable is rendered in the ConfigMap **only when explicitly set**. If left empty (the default), it is omitted from the ConfigMap entirely, and the application uses lib-auth's default behavior (no cache).

## Preview changes before upgrading

Prepare a private `values-3.3.0.yaml` containing the **complete intended configuration**, not just the fragments above. Preserve unrelated overrides, datastore credentials, encryption keys, license settings, Secret references and intended image pins. Remove obsolete settings deliberately. Both commands below reset stored overrides and use that same file; do not use an empty map as a migration plan. Retain a private backup of current values/manifests and datastore recovery artifacts; previews and Helm output may contain sensitive material.

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.3.0 --reset-values -f values-3.3.0.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.3.0 --reset-values -f values-3.3.0.yaml
```

The app Deployment rolls even when both application and migration images remain pinned to v3.6.0: its ConfigMap checksum changes with this chart release. With default pins, the app and migrator use v3.7.0. Bundled PostgreSQL, MongoDB, Valkey and RabbitMQ pod templates and Service selectors are unchanged in identical-values renders; this is not a no-downtime guarantee.

After upgrading, check the release-scoped app rollout and readiness, migration outcome (hook logs before deletion, or initContainer status), and controlled business/authentication smoke tests:

```bash
kubectl rollout status deployment -n midaz-plugins -l app.kubernetes.io/name=bank-transfer,app.kubernetes.io/instance=plugin-br-bank-transfer
```

Use your actual release/namespace if different. Rendering and a successful Helm command alone do not establish application startup, tenant migration completion or working antifraud.
<!-- {% endraw %} -->
