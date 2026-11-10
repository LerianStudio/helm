# Helm Upgrade from v4.0.1 to v4.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Access Manager permission declaration](#1-access-manager-permission-declaration)
  - [2. Anti-Fraud decision hook integration](#2-anti-fraud-decision-hook-integration)
  - [3. Recurring authorization-request expiration sweep](#3-recurring-authorization-request-expiration-sweep)
- **[Configuration Reference](#configuration-reference)**
  - [Access Manager declaration variables](#access-manager-declaration-variables)
  - [Anti-Fraud hook variables](#anti-fraud-hook-variables)
  - [Recurring authorization-request sweep variables](#recurring-authorization-request-sweep-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that upgrades the application version from `1.10.0` to `1.11.0` and introduces three new optional features for the `pix` service component:

1. **Access Manager permission declaration** — allows the plugin to register its permissions with the Access Manager identity service
2. **Anti-Fraud decision hook** — enables real-time fraud checks for cashin and refund-cashin operations via an external HTTP endpoint
3. **Recurring authorization-request expiration sweep** — configures grace periods for cleaning up stale Pix Automatico authorization requests

All new features are **disabled by default**. Existing deployments can upgrade without configuration changes and will continue to operate as before. The chart version increments from `4.0.1` to `4.1.0`, and all five service components (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) receive the new `1.11.0` image tag.

No values are removed or renamed. All changes are additive.

## Features

### 1. Access Manager permission declaration

The `pix` service can now declare its permissions to the Access Manager identity service at boot time. When enabled, the service registers its resource types and actions with the centralized permission system, allowing fine-grained access control for plugin operations.

**What changed:**

Two new configuration flags and two new secrets were added to the `pix` component:

| Setting | v4.0.1 | v4.1.0 |
|---------|--------|--------|
| `pix.configmap.DECLARATION_ENABLED` | (not present) | `"false"` |
| `pix.configmap.PLUGIN_IDENTITY_HOST` | (not present) | `""` (defaults to identity service in release namespace) |
| `pix.secrets.M2M_CLIENT_ID` | (not present) | `""` |
| `pix.secrets.M2M_CLIENT_SECRET` | (not present) | `""` |

**Why it matters:**

When `DECLARATION_ENABLED` is set to `"true"`, the plugin requires:

- `PLUGIN_AUTH_ENABLED` must also be `"true"`
- `PLUGIN_AUTH_ADDRESS` must point to a valid Access Manager auth service
- `PLUGIN_IDENTITY_HOST` must point to the identity service (defaults to the service in the Helm release namespace)
- `M2M_CLIENT_ID` and `M2M_CLIENT_SECRET` must contain valid machine-to-machine credentials

If any of these prerequisites are missing when declaration is enabled, the application will fail to boot.

**Operational impact:**

By default, this feature is **disabled** and has no impact on existing deployments. To enable permission declaration, you must:

1. Ensure the Access Manager services (auth and identity) are deployed and reachable
2. Obtain M2M client credentials from the Access Manager
3. Configure the required values

**Example configuration:**

```yaml
pix:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"
    DECLARATION_ENABLED: "true"
    PLUGIN_IDENTITY_HOST: "http://plugin-access-manager-identity.my-namespace.svc.cluster.local:4001"
  secrets:
    M2M_CLIENT_ID: "your-client-id"
    M2M_CLIENT_SECRET: "your-client-secret"
```

> **Note:** The `PLUGIN_IDENTITY_HOST` defaults to `http://plugin-access-manager-identity.<release-namespace>.svc.cluster.local:4001` when left empty. Override it only if your identity service is deployed in a different namespace or uses a different service name.

> **Warning:** Enabling declaration without valid M2M credentials will cause the `pix` pods to crash on startup. Always verify your Access Manager deployment and credentials before enabling this feature.

### 2. Anti-Fraud decision hook integration

The `pix` service now supports calling an external anti-fraud service to approve or reject cashin and refund-cashin operations in real time. The hook is invoked before processing the transaction and can return an `APPROVE` or `REJECT` decision.

**What changed:**

Thirteen new configuration flags and two new secrets were added to the `pix` component:

| Setting | v4.0.1 | v4.1.0 |
|---------|--------|--------|
| `pix.configmap.ANTIFRAUD_HOOK_ENABLED` | (not present) | `"false"` |
| `pix.configmap.ANTIFRAUD_HOOK_URL` | (not present) | `""` |
| `pix.configmap.ANTIFRAUD_HOOK_TIMEOUT_MS` | (not present) | `"500"` |
| `pix.configmap.ANTIFRAUD_HOOK_FALLBACK_DECISION` | (not present) | `""` |
| `pix.configmap.ANTIFRAUD_HOOK_FALLBACK_MAX_APPROVE_AMOUNT` | (not present) | `""` |
| `pix.configmap.ANTIFRAUD_HOOK_AUTH_HEADER_NAME` | (not present) | `""` |
| `pix.configmap.ANTIFRAUD_HOOK_ALLOW_PRIVATE_NETWORK` | (not present) | `"false"` |
| `pix.configmap.ANTIFRAUD_HOOK_CB_ENABLED` | (not present) | `"true"` |
| `pix.configmap.ANTIFRAUD_HOOK_CB_MAX_REQUESTS` | (not present) | `"3"` |
| `pix.configmap.ANTIFRAUD_HOOK_CB_INTERVAL` | (not present) | `"60s"` |
| `pix.configmap.ANTIFRAUD_HOOK_CB_TIMEOUT` | (not present) | `"30s"` |
| `pix.configmap.ANTIFRAUD_HOOK_CB_FAILURE_THRESHOLD` | (not present) | `"5"` |
| `pix.configmap.ANTIFRAUD_HOOK_PREWARM_ENABLED` | (not present) | `"true"` |
| `pix.secrets.ANTIFRAUD_HOOK_HMAC_SECRET` | (not present) | `""` |
| `pix.secrets.ANTIFRAUD_HOOK_AUTH_HEADER_VALUE` | (not present) | `""` |

**Why it matters:**

When `ANTIFRAUD_HOOK_ENABLED` is set to `"true"`, the application validates the following requirements at boot:

- `ANTIFRAUD_HOOK_URL` must be set and use HTTPS (unless `ALLOW_PRIVATE_NETWORK` is `"true"`)
- `ANTIFRAUD_HOOK_HMAC_SECRET` must be at least 32 characters
- Exactly one of `ANTIFRAUD_HOOK_FALLBACK_DECISION` (`APPROVE` or `REJECT`) or `ANTIFRAUD_HOOK_FALLBACK_MAX_APPROVE_AMOUNT` must be set

If any validation fails, the application will not start.

**Fallback behavior:**

When the anti-fraud service is unreachable or times out, the plugin uses the configured fallback strategy:

- **`FALLBACK_DECISION`**: Always approve or reject (e.g., `"APPROVE"` or `"REJECT"`)
- **`FALLBACK_MAX_APPROVE_AMOUNT`**: Approve transactions below the specified amount (in cents), reject above

You must configure exactly one fallback strategy.

**Circuit breaker:**

The hook includes a circuit breaker (enabled by default via `CB_ENABLED`) that opens after `CB_FAILURE_THRESHOLD` consecutive failures within `CB_INTERVAL`. When open, the circuit breaker triggers the fallback decision without calling the hook, then enters a half-open state after `CB_TIMEOUT` to test recovery.

**Authentication:**

The hook supports two authentication methods:

1. **HMAC signature**: The plugin signs each request with `ANTIFRAUD_HOOK_HMAC_SECRET` and includes the signature in a header
2. **Custom auth header**: Set `ANTIFRAUD_HOOK_AUTH_HEADER_NAME` and `ANTIFRAUD_HOOK_AUTH_HEADER_VALUE` to include a static authorization header (e.g., `Authorization: Bearer <token>`)

Both methods can be used together. If you set `AUTH_HEADER_NAME`, you must also set `AUTH_HEADER_VALUE` (and vice versa).

**Operational impact:**

By default, this feature is **disabled** and has no impact on existing deployments. Enabling the hook adds latency to cashin and refund-cashin operations (up to `TIMEOUT_MS` per transaction). Plan your timeout and fallback strategy carefully to balance fraud prevention with user experience.

**Example configuration:**

```yaml
pix:
  configmap:
    ANTIFRAUD_HOOK_ENABLED: "true"
    ANTIFRAUD_HOOK_URL: "https://antifraud.example.com/api/v1/decision"
    ANTIFRAUD_HOOK_TIMEOUT_MS: "500"
    ANTIFRAUD_HOOK_FALLBACK_MAX_APPROVE_AMOUNT: "100000"  # 1000.00 BRL in cents
    ANTIFRAUD_HOOK_AUTH_HEADER_NAME: "Authorization"
    ANTIFRAUD_HOOK_CB_ENABLED: "true"
    ANTIFRAUD_HOOK_CB_FAILURE_THRESHOLD: "5"
    ANTIFRAUD_HOOK_CB_INTERVAL: "60s"
    ANTIFRAUD_HOOK_CB_TIMEOUT: "30s"
    ANTIFRAUD_HOOK_PREWARM_ENABLED: "true"
  secrets:
    ANTIFRAUD_HOOK_HMAC_SECRET: "your-hmac-secret-at-least-32-characters-long"
    ANTIFRAUD_HOOK_AUTH_HEADER_VALUE: "Bearer your-api-token"
```

> **Warning:** Never set `ANTIFRAUD_HOOK_ALLOW_PRIVATE_NETWORK` to `"true"` in production. This flag disables HTTPS enforcement and is intended only for local development.

> **Important:** The HMAC secret must be at least 32 characters. The application will refuse to start with a shorter secret when the hook is enabled.

### 3. Recurring authorization-request expiration sweep

The `pix` service now includes configurable grace periods for sweeping stale Pix Automatico (recurring payment) authorization requests. This prevents the accumulation of expired authorization requests that were never completed or canceled.

**What changed:**

Two new configuration flags were added to the `pix` component:

| Setting | v4.0.1 | v4.1.0 |
|---------|--------|--------|
| `pix.configmap.RECURRING_AR_EXPIRE_GRACE` | (not present) | `"1h"` |
| `pix.configmap.RECURRING_AR_EXPIRE_MIN_GRACE` | (not present) | `"1m"` |

**Why it matters:**

These settings control when the background sweep job considers an authorization request expired:

- **`RECURRING_AR_EXPIRE_GRACE`**: The default grace period after the authorization request's expiration timestamp
- **`RECURRING_AR_EXPIRE_MIN_GRACE`**: The minimum grace period to prevent premature cleanup of recently created requests

The sweep job runs periodically and marks authorization requests as expired if they meet both conditions:

1. The request's expiration timestamp plus `EXPIRE_GRACE` has passed
2. At least `EXPIRE_MIN_GRACE` has elapsed since the request was created

**Operational impact:**

The defaults (`1h` grace, `1m` minimum grace) are suitable for most deployments. You may want to adjust these values if:

- Your authorization requests have very short lifetimes (reduce `EXPIRE_GRACE`)
- You need to retain expired requests longer for auditing (increase `EXPIRE_GRACE`)
- You experience race conditions with newly created requests (increase `EXPIRE_MIN_GRACE`)

**Example configuration:**

```yaml
pix:
  configmap:
    RECURRING_AR_EXPIRE_GRACE: "2h"
    RECURRING_AR_EXPIRE_MIN_GRACE: "5m"
```

> **Note:** Both values accept Go duration strings (e.g., `"30m"`, `"1h30m"`, `"90s"`). The application will fail to start if the values cannot be parsed.

## Configuration Reference

### Access Manager declaration variables

| Flag | Default | Description |
|------|---------|-------------|
| `DECLARATION_ENABLED` | `"false"` | Master switch for permission declaration. When `"true"`, requires `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_ADDRESS`, `PLUGIN_IDENTITY_HOST`, and M2M credentials. |
| `PLUGIN_IDENTITY_HOST` | `""` | URL of the Access Manager identity service. Defaults to `http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001` when empty. |
| `M2M_CLIENT_ID` | `""` | Machine-to-machine client ID for authenticating with the identity service. |
| `M2M_CLIENT_SECRET` | `""` | Machine-to-machine client secret. |

### Anti-Fraud hook variables

| Flag | Default | Description |
|------|---------|-------------|
| `ANTIFRAUD_HOOK_ENABLED` | `"false"` | Master switch for the anti-fraud hook. When `"false"`, all other `ANTIFRAUD_HOOK_*` variables are ignored. |
| `ANTIFRAUD_HOOK_URL` | `""` | HTTPS endpoint of the anti-fraud service. Required when hook is enabled. |
| `ANTIFRAUD_HOOK_TIMEOUT_MS` | `"500"` | Request timeout in milliseconds. |
| `ANTIFRAUD_HOOK_FALLBACK_DECISION` | `""` | Fallback decision when the hook fails: `"APPROVE"` or `"REJECT"`. Mutually exclusive with `FALLBACK_MAX_APPROVE_AMOUNT`. |
| `ANTIFRAUD_HOOK_FALLBACK_MAX_APPROVE_AMOUNT` | `""` | Fallback approval threshold in cents. Transactions below this amount are approved, above are rejected. Mutually exclusive with `FALLBACK_DECISION`. |
| `ANTIFRAUD_HOOK_AUTH_HEADER_NAME` | `""` | Custom authorization header name (e.g., `"Authorization"`). Must be set together with `AUTH_HEADER_VALUE` or both left empty. |
| `ANTIFRAUD_HOOK_AUTH_HEADER_VALUE` | `""` | Custom authorization header value (e.g., `"Bearer token"`). Must be set together with `AUTH_HEADER_NAME` or both left empty. |
| `ANTIFRAUD_HOOK_ALLOW_PRIVATE_NETWORK` | `"false"` | Allow non-HTTPS URLs for local development. **Never `"true"` in production.** |
| `ANTIFRAUD_HOOK_CB_ENABLED` | `"true"` | Enable circuit breaker for the hook. |
| `ANTIFRAUD_HOOK_CB_MAX_REQUESTS` | `"3"` | Maximum concurrent requests allowed when the circuit is half-open. |
| `ANTIFRAUD_HOOK_CB_INTERVAL` | `"60s"` | Time window for counting failures. |
| `ANTIFRAUD_HOOK_CB_TIMEOUT` | `"30s"` | How long the circuit stays open before entering half-open state. |
| `ANTIFRAUD_HOOK_CB_FAILURE_THRESHOLD` | `"5"` | Number of consecutive failures within `CB_INTERVAL` that opens the circuit. |
| `ANTIFRAUD_HOOK_PREWARM_ENABLED` | `"true"` | Send a test request to the hook at startup to warm up connections. |
| `ANTIFRAUD_HOOK_HMAC_SECRET` | `""` | HMAC secret for signing requests. Must be at least 32 characters when hook is enabled. |

### Recurring authorization-request sweep variables

| Flag | Default | Description |
|------|---------|-------------|
| `RECURRING_AR_EXPIRE_GRACE` | `"1h"` | Grace period after the authorization request's expiration timestamp before marking it expired. |
| `RECURRING_AR_EXPIRE_MIN_GRACE` | `"1m"` | Minimum time since creation before an authorization request can be marked expired. |

## Migration Steps

This upgrade requires no destructive migration steps. All new features are disabled by default and existing deployments will continue to operate without configuration changes.

**Recommended upgrade process:**

1. Review the new features and determine whether you want to enable any of them.
2. If enabling Access Manager declaration, ensure the Access Manager services are deployed and obtain M2M credentials.
3. If enabling the anti-fraud hook, deploy and test your anti-fraud service endpoint, then configure the hook URL, HMAC secret, and fallback strategy.
4. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
5. Run the upgrade command during a maintenance window.
6. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg
```

7. Check the `pix` service logs for any startup errors related to the new features:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=pix --tail=100
```

8. If you enabled Access Manager declaration, verify that permissions were registered successfully by checking the identity service logs.
9. If you enabled the anti-fraud hook, monitor transaction logs to confirm the hook is being called and decisions are being applied correctly.

> **Note:** The upgrade triggers a rolling restart of all five service deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) because the image tag changes from `1.10.0` to `1.11.0`. Depending on your replica count and readiness probe timing, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.1.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.1.0 -n plugin-br-pix-indirect-btg
```
