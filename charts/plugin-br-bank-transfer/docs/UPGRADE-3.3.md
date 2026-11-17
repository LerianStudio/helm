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

Version 3.3.0 is a minor release that upgrades the application from v3.6.0 to v3.7.0. This release introduces two new optional features: partner antifraud integration configuration and authentication decision caching. Both features are opt-in and require no action from operators unless you need to enable them. The upgrade is non-breaking and backward-compatible.

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

- **Default behavior (unset):** Antifraud flows are disabled. If a tenant attempts to use an antifraud-enabled flow without `ANTIFRAUD_SECRETS_BACKEND` configured, the application will deny the request with `INVALID_CONFIG`.
- **Lerian Cloud deployments:** Leave both variables unset (the default). Antifraud routes must use public HTTPS endpoints.
- **BYOC / Lerian-operated deployments:** Set `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` to allow internal antifraud endpoints (e.g., `"flowker.midaz-plugins.svc.cluster.local"`). Set `ANTIFRAUD_SECRETS_BACKEND` to `"aws"` or `"vault"` depending on your secret manager.

**Migration required:**  
No — both variables are optional and unset by default. Enable them only if you need partner antifraud integrations.

**Example configuration (BYOC with in-cluster Flowker):**

```yaml
bankTransfer:
  configmap:
    ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: "flowker.midaz-plugins.svc.cluster.local,flowker-staging.internal"
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

> **Important:** Antifraud credentials (API keys, tokens, etc.) are **never** configured in the Helm chart. The application reads them directly from the configured secret manager (AWS Secrets Manager or Vault) at runtime. Operators must ensure credentials are provisioned in the secret manager before enabling antifraud flows.

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
Authentication checks are performed on every request to the plugin-access-manager service. Enabling a cache reduces latency and load on the access-manager service by caching ALLOW and DENY decisions locally in each pod.

**Trade-offs:**

| Aspect | No Cache (default) | Cache Enabled (e.g., `"30s"`) |
|--------|-------------------|-------------------------------|
| Latency | Higher (every request calls access-manager) | Lower (cached decisions served locally) |
| Access-manager load | Higher | Lower |
| Partner changes propagation | Immediate | Delayed by TTL (e.g., 30 seconds) |
| Use case | Environments requiring immediate partner suspension/permission changes | High-throughput environments where eventual consistency is acceptable |

**Operational impact:**

- **Default behavior (unset):** No caching. Every request performs a fresh authorization check against plugin-access-manager.
- **Cache enabled (TTL > 0):** Authorization decisions (both ALLOW and DENY) are cached for the specified duration. A partner suspended or permission-narrowed will continue to have access until the cache expires (up to the TTL).

**Migration required:**  
No — the variable is optional and unset by default (no cache).

**Example configuration (enable 30-second cache):**

```yaml
bankTransfer:
  configmap:
    AUTH_CACHE_TTL: "30s"
```

> **Warning:** When `AUTH_CACHE_TTL` is set above 0, partner access changes (suspension, permission revocation, etc.) will not take effect immediately. The change will propagate to each pod only after the TTL expires. Do not enable caching in environments where immediate partner suspension is a compliance or security requirement.

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
| `AUTH_CACHE_TTL` | `""` (unset, no cache) | Go duration string (e.g., `"30s"`, `"1m"`) controlling the TTL for cached authentication/authorization decisions from plugin-access-manager. Unset means no cache (every request performs a fresh check). Above 0, both ALLOW and DENY decisions are cached, delaying partner access changes by up to the TTL. |

**Configuration location:**

```yaml
bankTransfer:
  configmap:
    AUTH_CACHE_TTL: ""
```

**Rendering behavior:**

The variable is rendered in the ConfigMap **only when explicitly set**. If left empty (the default), it is omitted from the ConfigMap entirely, and the application uses lib-auth's default behavior (no cache).

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.3.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.3.0
```
<!-- {% endraw %} -->
