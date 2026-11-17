<!-- {% raw %} -->
# Helm Upgrade from v0.7.0 to v0.8.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. JD Courier Integration Support](#1-jd-courier-integration-support)
  - [2. Courier Account Claims Worker Sweep](#2-courier-account-claims-worker-sweep)
- **[Configuration Reference](#configuration-reference)**
  - [Courier Configuration](#courier-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Courier Integration Requirements](#step-1-review-courier-integration-requirements)
  - [Step 2: Configure Courier Admission (Optional)](#step-2-configure-courier-admission-optional)
  - [Step 3: Enable Account Claims Sweep (Optional)](#step-3-enable-account-claims-sweep-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This release introduces **JD Courier integration support**, enabling the plugin to receive inbound webhook deliveries from the JD Courier and optionally claim participant CRM accounts on the Courier. The chart now exposes a top-level `courier` configuration block that controls both the inbound admission model (api-only) and the outbound account-claims worker sweep (worker-only).

| Setting | v0.7.0 | v0.8.0 |
|---------|--------|--------|
| Chart Version | 0.7.0 | 0.8.0 |
| App Version | 1.6.1 | 1.6.1 |
| Courier Integration | Not supported | Configurable via `courier.enabled` and `courier.accountClaims.enabled` |
| New Environment Variables (api) | N/A | `AUTH_M2M_INVERSION_ENABLED`, `AUTH_M2M_PRODUCT_FORWARD_ENABLED` |
| New Environment Variables (worker) | N/A | `COURIER_ACCOUNT_CLAIMS_ENABLED` |

**No breaking changes.** All new configuration is opt-in and defaults to disabled, maintaining full compatibility with existing v0.7.0 deployments.

> **Note:** The pods restart on this upgrade even with unchanged values. The ConfigMaps and Secrets carry the `helm.sh/chart` label, which changes to `plugin-br-pix-jd-helm-0.8.0`, and the Deployments hash those objects into the `checksum/config` and `checksum/secret` pod annotations. The api pods restart with a rolling update. With `worker.enabled=true`, the worker pods restart with the `Recreate` strategy: the old worker stops before the new one starts.

## Features

### 1. JD Courier Integration Support

The chart now supports receiving inbound webhook deliveries from the **JD Courier**, a component that delivers PIX channel events to the plugin's api. The Courier calls the api on an M2M credential whose manifest role is `service`, and the lib-auth library admits that role only under the **inverted authorization model**.

**What changed:**

A new `courier.enabled` flag controls whether the api ConfigMap includes the lib-auth admission pair:

- `AUTH_M2M_INVERSION_ENABLED=true` — Authorize the application under its manifest roles (the legacy model fabricates a `{product}-editor-role` subject for any application token, which holds none of the channel route permissions)
- `AUTH_M2M_PRODUCT_FORWARD_ENABLED=true` — Forward the product context (gated on inversion inside lib-auth; inversion without this flag also refuses Courier deliveries with 403)

These variables are **always emitted as a pair** when `courier.enabled=true`, which is why the chart exposes one switch instead of two separate flags. The `api.extraConfigmap` escape hatch still wins if you need to split them deliberately.

**Why it matters:**

Without the inverted authorization model, every Courier delivery is rejected with 403 Forbidden. Enabling `courier.enabled` configures the api to admit the Courier's `service` role credential.

**Configuration:**

```yaml
courier:
  enabled: false  # Default: disabled
```

**When enabled:**

```yaml
courier:
  enabled: true
```

The api ConfigMap will include:

```yaml
data:
  AUTH_M2M_INVERSION_ENABLED: "true"
  AUTH_M2M_PRODUCT_FORWARD_ENABLED: "true"
```

**Template changes:**

The api ConfigMap merge order now includes the Courier admission block:

**Before (v0.7.0):**

```yaml
{{- $data := mergeOverwrite $platform $domain $qrcode $signing $mt $streaming $rateLimit $corsEnv $http (.Values.api.extraConfigmap | default dict) -}}
```

**After (v0.8.0):**

```yaml
{{- $courier := fromYaml (include "plugin-br-pix-jd.courierAuthEnv" $) | default dict -}}
{{- $data := mergeOverwrite $platform $domain $qrcode $signing $mt $streaming $rateLimit $corsEnv $http $courier (.Values.api.extraConfigmap | default dict) -}}
```

The `courierAuthEnv` helper emits the AUTH_M2M pair only when `courier.enabled=true`; otherwise it emits nothing (the app defaults both variables to false).

**Operational impact:**

- The worker ConfigMap **never includes** the AUTH_M2M admission pair — the worker serves no Courier routes, so the variables would be inert noise
- When `courier.enabled=false` (the default), **nothing is emitted**: both variables default to false inside lib-auth, and the chart does not emit literals it does not own
- The `api.extraConfigmap` escape hatch merges last and still wins, allowing you to override the pair if needed

**Prerequisites (not modeled in this chart):**

The admission pair alone does not admit the Courier. The install also needs authentication on, the Courier credential with source `jd-courier`, the `service` role published to the Access Manager, and the Access Manager at 3.13.0 or later. The chart does not check any of these at render time. See [Step 1](#step-1-review-courier-integration-requirements) for the full list.

### 2. Courier Account Claims Worker Sweep

The chart now supports a **worker sweep** that claims each participant's CRM accounts on that participant's own Courier. This is an **outbound** call (the worker calls the Courier), independent of the inbound admission model controlled by `courier.enabled`.

**What changed:**

A new `courier.accountClaims.enabled` flag controls whether the worker ConfigMap includes:

- `COURIER_ACCOUNT_CLAIMS_ENABLED=true` — Registers the worker sweep that claims accounts (app default: false, read only by `cmd/worker`)

**Why it matters:**

Without the account-claims sweep, participant CRM accounts are not registered on the Courier, which may cause downstream ownership map issues. Enabling `courier.accountClaims.enabled` configures the worker to run the sweep.

**Configuration:**

```yaml
courier:
  accountClaims:
    enabled: false  # Default: disabled
```

**When enabled:**

```yaml
courier:
  accountClaims:
    enabled: true
```

The worker ConfigMap will include:

```yaml
data:
  COURIER_ACCOUNT_CLAIMS_ENABLED: "true"
```

**Template changes:**

The worker ConfigMap merge order now includes the Courier account-claims block:

**Before (v0.7.0):**

```yaml
{{- $data := mergeOverwrite $platform $domain $qrcode $cron $mt $streaming (.Values.worker.extraConfigmap | default dict) -}}
```

**After (v0.8.0):**

```yaml
{{- $courierClaims := fromYaml (include "plugin-br-pix-jd.courierClaimsEnv" $) | default dict -}}
{{- $data := mergeOverwrite $platform $domain $qrcode $cron $mt $streaming $courierClaims (.Values.worker.extraConfigmap | default dict) -}}
```

The `courierClaimsEnv` helper emits `COURIER_ACCOUNT_CLAIMS_ENABLED=true` only when `courier.accountClaims.enabled=true`; otherwise it emits nothing.

**Operational impact:**

- The api ConfigMap **never includes** `COURIER_ACCOUNT_CLAIMS_ENABLED` — the api never reads it, so it would be inert noise
- The sweep is a **worker job**, so enabling `courier.accountClaims.enabled` requires `worker.enabled=true` — the chart will **fail the render** with a descriptive error if you enable the sweep with the worker disabled:

```
ERROR: courier.accountClaims.enabled=true requires worker.enabled=true.
The account-claims sweep is a worker job (COURIER_ACCOUNT_CLAIMS_ENABLED is read only
by the worker process); with the worker disabled nothing would ever run it. Enable the
worker (--set worker.enabled=true) or drop courier.accountClaims.enabled.
```

- When `courier.accountClaims.enabled=false` (the default), **nothing is emitted**: the variable defaults to false inside the app
- The `worker.extraConfigmap` escape hatch merges last and still wins

**Relationship to `courier.enabled`:**

The two flags are **independent**:

| `courier.enabled` | `courier.accountClaims.enabled` | Result |
|-------------------|----------------------------------|--------|
| `false` | `false` | No Courier integration (default) |
| `true` | `false` | Api admits Courier deliveries; worker does not claim accounts |
| `false` | `true` | Worker claims accounts; api rejects Courier deliveries with 403 |
| `true` | `true` | Full Courier integration: api admits deliveries and worker claims accounts |

> **Note:** Enabling `courier.accountClaims.enabled` without `courier.enabled` is valid if you want the worker to claim accounts but the api to reject inbound Courier deliveries. This may be useful during a phased rollout.

## Configuration Reference

### Courier Configuration

**New top-level block (v0.8.0):**

```yaml
# -- PIX JD behind the JD Courier — the ADMISSION side. The Courier delivers its
# inbound calls on an M2M credential whose manifest role is `service`, and lib-auth
# admits that role only under the inverted authorization model: enabling this block
# sets AUTH_M2M_INVERSION_ENABLED=true AND AUTH_M2M_PRODUCT_FORWARD_ENABLED=true on
# the api, ALWAYS AS A PAIR. Under the legacy model (inversion off) every Courier
# delivery is 403, and inversion WITHOUT forward refuses the Courier 403 just the
# same — which is why the chart exposes one switch and never the two variables
# separately (api.extraConfigmap remains the raw escape hatch, and it still wins).
# The worker serves no Courier routes and never gets the pair. Off, NOTHING is
# emitted: the app defaults both variables to false.
#
# The OUTBOUND Courier configuration is already modeled elsewhere and is not
# repeated here: api.configmap.COURIER_URL (single-tenant only, emitted when set,
# must point at the Courier process running the `admin` role) and
# api.secrets.COURIER_CLIENT_ID / COURIER_CLIENT_SECRET. Prerequisites that are
# not this chart's — the Courier credential, the `service` role, the Access
# Manager version — are in README.md, "Installing behind the JD Courier".
courier:
  # -- Admit JD Courier deliveries on the api (the AUTH_M2M pair above).
  enabled: false
  accountClaims:
    # -- The worker sweep that claims each participant's CRM accounts on its
    # Courier: emits COURIER_ACCOUNT_CLAIMS_ENABLED=true in the WORKER ConfigMap
    # only (the api never reads it). Requires worker.enabled=true — the render
    # fails otherwise, since nothing would ever run the sweep — and is independent
    # of courier.enabled above: it is an outbound call, not inbound admission.
    enabled: false
```

**Field reference:**

| Field | Default | Description |
|-------|---------|-------------|
| `courier.enabled` | `false` | Admit JD Courier deliveries on the api (sets `AUTH_M2M_INVERSION_ENABLED=true` and `AUTH_M2M_PRODUCT_FORWARD_ENABLED=true` in the api ConfigMap) |
| `courier.accountClaims.enabled` | `false` | Enable the worker sweep that claims participant CRM accounts on the Courier (sets `COURIER_ACCOUNT_CLAIMS_ENABLED=true` in the worker ConfigMap; requires `worker.enabled=true`) |

**Environment variables added:**

| Variable | Component | Condition | Default (app) | Description |
|----------|-----------|-----------|---------------|-------------|
| `AUTH_M2M_INVERSION_ENABLED` | api | `courier.enabled=true` | `false` | Authorize applications under their manifest roles (required for Courier admission) |
| `AUTH_M2M_PRODUCT_FORWARD_ENABLED` | api | `courier.enabled=true` | `false` | Forward product context in M2M authorization (required for Courier admission) |
| `COURIER_ACCOUNT_CLAIMS_ENABLED` | worker | `courier.accountClaims.enabled=true` | `false` | Enable the worker sweep that claims participant CRM accounts on the Courier |

**Validation rules:**

The chart enforces the following at render time:

1. **`courier.accountClaims.enabled=true` requires `worker.enabled=true`**: The account-claims sweep is a worker job; with the worker disabled nothing would ever run it. The render fails with:

```
ERROR: courier.accountClaims.enabled=true requires worker.enabled=true.
The account-claims sweep is a worker job (COURIER_ACCOUNT_CLAIMS_ENABLED is read only
by the worker process); with the worker disabled nothing would ever run it. Enable the
worker (--set worker.enabled=true) or drop courier.accountClaims.enabled.
```

## Migration Steps

### Step 1: Review Courier Integration Requirements

> **Warning:** The chart does not check these prerequisites. If one is missing, the render succeeds and the integration fails only at runtime.

Before you set `courier.enabled=true`, put all of these in place. They come from the chart README, section "Installing behind the JD Courier":

1. **Authentication on.** Set `api.configmap.PLUGIN_AUTH_ENABLED: "true"` and `api.configmap.PLUGIN_AUTH_HOST`, or `global.auth.enabled` and `global.auth.host` in an umbrella chart. The admission pair authorizes the Courier's bearer, so it does nothing with authentication off.
2. **The Courier credential, with source `jd-courier`.** In multi-tenant, the Tenant Manager issues it. In single-tenant, the install's service-credential issuer issues it.
3. **The `service` role published to the Access Manager.** In single-tenant, publish it with `api.configmap.IDP_DECLARATION_ENABLED: "true"`. That key also needs `api.configmap.IDP_HOST`, `IDP_M2M_CLIENT_ID` (in `api.configmap` or `api.secrets`) and `api.secrets.IDP_M2M_CLIENT_SECRET`. Without them, the render fails.
4. **The Access Manager at 3.13.0 or later.** The first `plugin-access-manager` chart with that app is **10.0.3** (app 3.13.1). Charts 10.0.0 to 10.0.2 ship app 3.11.1.
5. **`COURIER_URL` pointed at the Courier process that runs the `admin` role** (single-tenant only). Only that role serves the ownership lookup. A Courier process in any other role answers `404` to the plugin, and its own health probe still reports healthy.

Which side each item affects:

- Items 1 to 4 govern the **inbound** side: the api authorizing the Courier deliveries.
- Item 5 governs the **outbound** side: the plugin calling the Courier. A wrong role answers `404`.

> **Note:** If you are not integrating with the JD Courier, **no action is required**. The new `courier` configuration block defaults to disabled and has no impact on existing deployments.

### Step 2: Configure Courier Admission (Optional)

If you want the api to admit inbound Courier deliveries, add `courier.enabled` to **your values file**. The upgrade commands below pass that file with `-f`. Without `-f`, `helm upgrade` reuses the stored values and the new keys never reach the cluster.

```yaml
courier:
  enabled: true
```

This will add the following to the api ConfigMap:

```yaml
data:
  AUTH_M2M_INVERSION_ENABLED: "true"
  AUTH_M2M_PRODUCT_FORWARD_ENABLED: "true"
```

**Verify the configuration:**

After upgrading, check the api ConfigMap:

```bash
kubectl get configmap plugin-br-pix-jd-api -n midaz-plugins -o yaml
```

You should see the `AUTH_M2M_INVERSION_ENABLED` and `AUTH_M2M_PRODUCT_FORWARD_ENABLED` keys.

**Configure outbound Courier settings:**

The inbound admission model is only half of the integration. You also need to configure the api to call the Courier:

```yaml
api:
  configmap:
    # Single-tenant only. Must point at the Courier process that runs the `admin` role.
    COURIER_URL: "https://courier-admin.example.internal"
  secrets:
    COURIER_CLIENT_ID: "<courier-client-id>"
    COURIER_CLIENT_SECRET: "<courier-client-secret>"
```

> **Important:** `api.configmap.COURIER_URL` is only emitted in single-tenant mode. In multi-tenant, each tenant's Courier comes from its `jd-spi` bundle in the Tenant Manager and the chart ignores this key. A `COURIER_URL` that points at a Courier process in another role gets `404`, even with that process healthy.

> **Important:** With `api.existingSecret.name`, the chart ignores `api.secrets`. Add `COURIER_CLIENT_ID` and `COURIER_CLIENT_SECRET` to your existing Secret instead.

### Step 3: Enable Account Claims Sweep (Optional)

If you want the worker to claim participant CRM accounts on the Courier, enable `courier.accountClaims.enabled`:

```yaml
worker:
  enabled: true  # Required

courier:
  accountClaims:
    enabled: true
```

This will add the following to the worker ConfigMap:

```yaml
data:
  COURIER_ACCOUNT_CLAIMS_ENABLED: "true"
```

**Verify the configuration:**

After upgrading, check the worker ConfigMap:

```bash
kubectl get configmap plugin-br-pix-jd-worker -n midaz-plugins -o yaml
```

You should see the `COURIER_ACCOUNT_CLAIMS_ENABLED` key.

> **Warning:** Enabling `courier.accountClaims.enabled` without `worker.enabled=true` will cause the render to fail with a descriptive error. The chart enforces this constraint because the account-claims sweep is a worker job — with the worker disabled, nothing would ever run it.

**Independent of inbound admission:**

The account-claims sweep is an **outbound** call, so it is independent of `courier.enabled`. You can enable the sweep without admitting inbound Courier deliveries:

```yaml
courier:
  enabled: false  # Api rejects Courier deliveries
  accountClaims:
    enabled: true  # Worker claims accounts
```

This may be useful during a phased rollout where you want to claim accounts before enabling inbound deliveries.

## Preview changes before upgrading

```bash
helm diff upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.8.0 -n midaz-plugins -f my-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.8.0 -n midaz-plugins -f my-values.yaml
```

Replace `<pix-release>` with your release name and `my-values.yaml` with your values file.

If you set the payment signing key and certificate with `--set-file`, add the same two `--set-file` flags to these commands. Otherwise the upgrade drops them and payment orders go out unsigned.
<!-- {% endraw %} -->
