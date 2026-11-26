<!-- {% raw %} -->
# Helm Upgrade from v3.3.1 to v3.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Expanded Partner Antifraud Destination Controls](#1-expanded-partner-antifraud-destination-controls)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Existing Antifraud Configuration](#step-1-review-existing-antifraud-configuration)
  - [Step 2: Evaluate New Destination List Requirements](#step-2-evaluate-new-destination-list-requirements)
  - [Step 3: Update values.yaml (If Required)](#step-3-update-valuesyaml-if-required)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.4.0 is a **minor release** that expands the partner antifraud feature (introduced in app v3.7.0) with two new destination approval lists: `ANTIFRAUD_PARTNER_HOSTS` and `ANTIFRAUD_PARTNER_TOKEN_URLS`. These complement the existing `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` setting, giving operators fine-grained control over which partner endpoints the application may reach during antifraud flows.

This release does **not** change the application version, container image, or any existing runtime behavior. The changes are purely additive: new optional configuration fields and updated template logic to render them. Existing deployments will continue to work without configuration changes.

**Version changes:**

| Component | v3.3.1 | v3.4.0 |
|-----------|--------|--------|
| Chart version | `3.3.1` | `3.4.0` |
| App version | `3.8.0` | `3.8.0` |
| Image tag | `3.8.0` | `3.8.0` |

**Breaking changes:** None. All new configuration fields are optional and default to unset (which maintains the existing behavior of denying all destinations not explicitly approved).

## Features

### 1. Expanded Partner Antifraud Destination Controls

**What changed:**

The chart now supports two additional environment variables for controlling partner antifraud destinations:

- **`ANTIFRAUD_PARTNER_HOSTS`**: Comma-separated list of approved route hosts (e.g., `partner1.example.com,partner2.example.com`). These hosts must use HTTPS and must not resolve to private addresses.
- **`ANTIFRAUD_PARTNER_TOKEN_URLS`**: Comma-separated list of approved token endpoint URLs (exact match, e.g., `https://auth.partner1.example.com/oauth/token,https://auth.partner2.example.com/token`).

These join the existing `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS`, which approves route hosts **and** exempts them from the HTTPS and private-address checks (intended for BYOC / Lerian-operated deployments with in-cluster services like Flowker).

**values.yaml changes:**

**Before (v3.3.1):**

```yaml
    # =================================================================
    # Partner antifraud (app v3.7.0) — rendered only when set.
    # ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: exact hosts (comma-separated) a tenant
    # route may reach over http or a private address, e.g. an in-cluster
    # Flowker (BYOC / Lerian operation only; leave unset on Lerian Cloud).
    # ANTIFRAUD_SECRETS_BACKEND: where the antifraud credentials live, "aws" or
    # "vault"; no app default, and unset makes an enabled flow deny with
    # INVALID_CONFIG. Credentials come from the secret manager, never env.
    # ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: ""
    # ANTIFRAUD_SECRETS_BACKEND: ""
    # =================================================================
```

**After (v3.4.0):**

```yaml
    # =================================================================
    # Partner antifraud (app v3.7.0) — rendered only when set.
    # Destination lists (comma-separated, empty approves none, deploy-owned):
    # ANTIFRAUD_ALLOWED_PRIVATE_HOSTS approves a route host and also exempts it
    # from https and the private-address check (BYOC / Lerian operation only;
    # leave unset on Lerian Cloud). ANTIFRAUD_PARTNER_HOSTS approves route
    # hosts, ANTIFRAUD_PARTNER_TOKEN_URLS approves token URLs (exact match).
    # ANTIFRAUD_SECRETS_BACKEND: where the antifraud credentials live, "aws" or
    # "vault"; no app default, and unset makes an enabled flow deny with
    # INVALID_CONFIG. Credentials come from the secret manager, never env.
    # ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: ""
    # ANTIFRAUD_PARTNER_HOSTS: ""
    # ANTIFRAUD_PARTNER_TOKEN_URLS: ""
    # ANTIFRAUD_SECRETS_BACKEND: ""
    # =================================================================
```

**Template changes:**

The `templates/configmap.yaml` template now iterates over all three destination list variables and renders each one only when set, replacing the previous single-variable conditional block.

**Before (v3.3.1):**

```yaml
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
```

**After (v3.4.0):**

```yaml
  # -- Partner antifraud (app v3.7.0). The three destination lists are deploy-owned and empty
  # approves none; ANTIFRAUD_SECRETS_BACKEND is aws or vault, unset denies every enabled
  # flow (INVALID_CONFIG). Rendered only when set; credentials never come from env.
  {{- range $k := list "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "ANTIFRAUD_PARTNER_HOSTS" "ANTIFRAUD_PARTNER_TOKEN_URLS" }}
  {{- with index $cm $k }}
  {{ $k }}: {{ . | quote }}
  {{- end }}
  {{- end }}
  {{- with .Values.bankTransfer.configmap.ANTIFRAUD_SECRETS_BACKEND }}
  ANTIFRAUD_SECRETS_BACKEND: {{ . | quote }}
```

**Why it matters:**

The partner antifraud feature validates outbound requests to partner services (e.g., for fraud scoring or identity verification). Prior to v3.4.0, operators could only approve private/in-cluster destinations via `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS`. For public partner APIs, there was no way to pre-approve specific hosts or token endpoints — the application would deny all requests unless the partner host happened to be in the private allowlist.

The new `ANTIFRAUD_PARTNER_HOSTS` and `ANTIFRAUD_PARTNER_TOKEN_URLS` settings allow operators to explicitly approve external partner endpoints while maintaining strict security controls:

- **`ANTIFRAUD_PARTNER_HOSTS`**: Approves the partner's main API host (e.g., `api.fraudprovider.com`). The application enforces HTTPS and rejects private IP addresses for these hosts.
- **`ANTIFRAUD_PARTNER_TOKEN_URLS`**: Approves the partner's OAuth token endpoint (e.g., `https://auth.fraudprovider.com/oauth/token`). This is required when the partner uses OAuth 2.0 client credentials flow for authentication.
- **`ANTIFRAUD_ALLOWED_PRIVATE_HOSTS`**: Continues to serve its original purpose — approving in-cluster or private network destinations (e.g., `flowker.midaz-plugins.svc.cluster.local`) and exempting them from HTTPS/private-address checks.

**Operational impact:**

- **If you are not using the partner antifraud feature:** No impact. The new fields are optional and unset by default.
- **If you are using antifraud with in-cluster services only:** No impact. Continue using `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` as before.
- **If you are using antifraud with external partner APIs:** You can now explicitly approve partner hosts and token endpoints via the new settings. This is **optional** — if you leave them unset, the application will deny requests to those destinations (existing behavior).

**Security considerations:**

All three destination lists follow a **deny-by-default** policy:

- An empty or unset list approves **no** destinations.
- Each list is comma-separated with no wildcards or pattern matching — only exact matches are approved.
- `ANTIFRAUD_PARTNER_HOSTS` and `ANTIFRAUD_PARTNER_TOKEN_URLS` enforce HTTPS and reject private IP addresses.
- `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` bypasses these checks (intended for trusted in-cluster services only).

> **Important:** These settings control **destination approval**, not authentication. Partner credentials are always read from the configured secret manager (`ANTIFRAUD_SECRETS_BACKEND`), never from environment variables. The chart does not render or manage partner credentials.

## Configuration Reference

The following table describes the new configuration fields added in v3.4.0. All fields are optional and placed under `bankTransfer.configmap`.

| Field | Default | Description |
|-------|---------|-------------|
| `ANTIFRAUD_PARTNER_HOSTS` | `""` (unset) | Comma-separated list of approved partner route hosts (e.g., `api.partner1.com,api.partner2.com`). The application enforces HTTPS and rejects private IP addresses. Empty or unset approves no hosts. |
| `ANTIFRAUD_PARTNER_TOKEN_URLS` | `""` (unset) | Comma-separated list of approved partner token endpoint URLs (exact match, e.g., `https://auth.partner1.com/oauth/token`). Required when the partner uses OAuth 2.0 client credentials flow. Empty or unset approves no URLs. |

**Existing antifraud fields (unchanged):**

| Field | Default | Description |
|-------|---------|-------------|
| `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` | `""` (unset) | Comma-separated list of approved private/in-cluster hosts (e.g., `flowker.midaz-plugins.svc.cluster.local`). Exempts these hosts from HTTPS and private-address checks. BYOC / Lerian operation only; leave unset on Lerian Cloud. |
| `ANTIFRAUD_SECRETS_BACKEND` | `""` (unset) | Secret manager backend for antifraud credentials: `"aws"` or `"vault"`. No application default; unset causes enabled flows to deny with `INVALID_CONFIG`. |

**Example configuration:**

```yaml
bankTransfer:
  configmap:
    # Approve two external partner APIs
    ANTIFRAUD_PARTNER_HOSTS: "api.fraudprovider.com,api.identityverifier.com"
    
    # Approve their OAuth token endpoints
    ANTIFRAUD_PARTNER_TOKEN_URLS: "https://auth.fraudprovider.com/oauth/token,https://auth.identityverifier.com/token"
    
    # Approve in-cluster Flowker (BYOC only)
    ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: "flowker.midaz-plugins.svc.cluster.local"
    
    # Use AWS Secrets Manager for credentials
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

> **Note:** The application reads partner credentials (client IDs, secrets, API keys) from the configured secret manager at runtime. The chart does not render these credentials in the ConfigMap or Secret. Operators must provision partner credentials in AWS Secrets Manager or Vault separately, following the application's credential naming conventions.

## Migration Steps

### Step 1: Review Existing Antifraud Configuration

Before upgrading, check whether your deployment uses the partner antifraud feature. Look for the following settings in your `values.yaml` or values overrides:

```bash
helm get values plugin-br-bank-transfer -n midaz-plugins | grep -E "ANTIFRAUD_"
```

**If the command returns no output:** You are not using the antifraud feature. Skip to the upgrade command — no migration is required.

**If you see `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` or `ANTIFRAUD_SECRETS_BACKEND`:** Continue to Step 2.

### Step 2: Evaluate New Destination List Requirements

Determine whether your antifraud flows require approval for external partner APIs:

**Scenario A: In-cluster services only (e.g., Flowker in BYOC)**

If your antifraud routes only reach in-cluster services (e.g., `flowker.midaz-plugins.svc.cluster.local`), you do **not** need the new settings. Your existing `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` configuration is sufficient.

**Action required:** None. Proceed to the upgrade command.

**Scenario B: External partner APIs**

If your antifraud flows call external partner services (e.g., `api.fraudprovider.com`), you can now explicitly approve those destinations using the new settings.

**Action required:** Proceed to Step 3 to add the new configuration.

**Scenario C: Mixed (in-cluster and external)**

If your antifraud flows reach both in-cluster services and external partner APIs, use all three settings:

- `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` for in-cluster destinations
- `ANTIFRAUD_PARTNER_HOSTS` for external partner API hosts
- `ANTIFRAUD_PARTNER_TOKEN_URLS` for external partner token endpoints

**Action required:** Proceed to Step 3 to add the new configuration.

### Step 3: Update values.yaml (If Required)

If you determined in Step 2 that you need to approve external partner destinations, add the new settings to your `values.yaml` or values overrides.

**Example: Approve external partner API**

```yaml
bankTransfer:
  configmap:
    # Existing setting (if applicable)
    ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: "flowker.midaz-plugins.svc.cluster.local"
    
    # New settings for external partner
    ANTIFRAUD_PARTNER_HOSTS: "api.fraudprovider.com"
    ANTIFRAUD_PARTNER_TOKEN_URLS: "https://auth.fraudprovider.com/oauth/token"
    
    # Existing backend setting
    ANTIFRAUD_SECRETS_BACKEND: "aws"
```

**Example: Multiple external partners**

```yaml
bankTransfer:
  configmap:
    ANTIFRAUD_PARTNER_HOSTS: "api.fraudprovider.com,api.identityverifier.com,api.riskscoring.com"
    ANTIFRAUD_PARTNER_TOKEN_URLS: "https://auth.fraudprovider.com/oauth/token,https://auth.identityverifier.com/token,https://auth.riskscoring.com/oauth/token"
    ANTIFRAUD_SECRETS_BACKEND: "vault"
```

> **Important:** 
> - Use exact host names in `ANTIFRAUD_PARTNER_HOSTS` (no `https://` prefix, no paths, no wildcards).
> - Use full URLs in `ANTIFRAUD_PARTNER_TOKEN_URLS` (including `https://` scheme and full path).
> - Separate multiple entries with commas, no spaces.
> - The application enforces HTTPS for partner hosts and token URLs — HTTP is rejected.

**Verification:**

After updating your values file, verify the configuration will be rendered correctly:

```bash
helm template plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm \
  --version 3.4.0 \
  -n midaz-plugins \
  -f your-values.yaml \
  | grep -A 5 "ANTIFRAUD_"
```

You should see the new environment variables in the ConfigMap data section:

```yaml
  ANTIFRAUD_PARTNER_HOSTS: "api.fraudprovider.com"
  ANTIFRAUD_PARTNER_TOKEN_URLS: "https://auth.fraudprovider.com/oauth/token"
  ANTIFRAUD_SECRETS_BACKEND: "aws"
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.4.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.4.0
```
<!-- {% endraw %} -->
