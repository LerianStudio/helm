# Combined Helm Upgrade Guide: v8.6.0 → v9.2.0

This guide is for anyone jumping **directly** from `v8.6.0` (or an earlier
`v8.x`) straight to `v9.2.0`, skipping the intermediate `v9.0.0`/`v9.1.0`
releases. It combines:

- the **breaking changes** introduced in `v9.0.0` ([UPGRADE-9.0.md](./UPGRADE-9.0.md)),
- the **additive features** introduced in `v9.1.0` ([UPGRADE-9.1.md](./UPGRADE-9.1.md)), and
- the **caradhras rename and related changes** introduced in `v9.2.0` ([UPGRADE-9.2.md](./UPGRADE-9.2.md))

into a single pass. `v9.2.0` itself is a **minor** release — the
auth-backend→caradhras rename ships with its own backward-compatibility
layer, so it does not add to the breaking-changes list above the three
from `v9.0.0` — but it does need its own read-through (see "Notable
Changes" below), especially the one field where that compatibility layer
does NOT apply. If you are already on `v9.1.0` and only need the `v9.1.0 →
v9.2.0` step, read [UPGRADE-9.2.md](./UPGRADE-9.2.md) directly instead.

# Topics

- **[Breaking Changes (introduced in v9.0.0)](#breaking-changes-introduced-in-v900)**
  - [1. Component Names Now Derived from Release Name](#1-component-names-now-derived-from-release-name)
  - [2. Admin Password Now Required](#2-admin-password-now-required)
  - [3. Cross-Component DNS References Updated](#3-cross-component-dns-references-updated)
- **[Notable Changes (introduced in v9.2.0)](#notable-changes-introduced-in-v920)**
  - [1. Caradhras Component Promotion](#1-caradhras-component-promotion)
  - [2. Database Creation Default Changed](#2-database-creation-default-changed)
  - [3. Init User Job Disabled by Default (Again)](#3-init-user-job-disabled-by-default-again)
- **[Additive Features (v9.0.0 + v9.1.0 + v9.2.0)](#additive-features-v900--v910--v920)**
  - [1. Centralized Authorizer Client ID](#1-centralized-authorizer-client-id)
  - [2. Automatic Service Discovery for Dependencies](#2-automatic-service-discovery-for-dependencies)
  - [3. Lerian Common Helm Library Integration](#3-lerian-common-helm-library-integration)
  - [4. Global Configuration Masks](#4-global-configuration-masks)
  - [5. Datastore Connection Masks](#5-datastore-connection-masks)
  - [6. Service Discovery Configuration Masks](#6-service-discovery-configuration-masks)
  - [7. OpenTelemetry Configuration Consolidation](#7-opentelemetry-configuration-consolidation)
  - [8. Template Refactoring](#8-template-refactoring)
  - [9. Auth Backend Service Configuration Moved](#9-auth-backend-service-configuration-moved)
  - [10. Caradhras UI Component](#10-caradhras-ui-component)
  - [11. Caradhras Ingress Support](#11-caradhras-ingress-support)
  - [12. Independent PodDisruptionBudget for Caradhras](#12-independent-poddisruptionbudget-for-caradhras)
- **[Required Migration Steps](#required-migration-steps)**
  - [Step 1: Identify Your Current Release Name](#step-1-identify-your-current-release-name)
  - [Step 2: Pin Component Names (If Not Using Default Release Name)](#step-2-pin-component-names-if-not-using-default-release-name)
  - [Step 3: Set or Disable the Admin Password](#step-3-set-or-disable-the-admin-password)
  - [Step 4: Review Cross-Component References](#step-4-review-cross-component-references)
  - [Step 5: Check the Caradhras Image Override](#step-5-check-the-caradhras-image-override)
  - [Step 6: Check the createDatabase Setting](#step-6-check-the-createdatabase-setting)
- **[Optional Migration Steps](#optional-migration-steps)**
  - [Step 7: Migrate to Global Masks](#step-7-migrate-to-global-masks)
  - [Step 8: Migrate Service Discovery Configuration](#step-8-migrate-service-discovery-configuration)
  - [Step 9: Migrate to the caradhras.\* Path](#step-9-migrate-to-the-caradhras-path)
- **[Configuration Reference](#configuration-reference)**
- **[Backward Compatibility Aliases (auth.backend.\* → caradhras.\*)](#backward-compatibility-aliases-authbackend--caradhras)**
- **[Known Gotchas (Field-Verified)](#known-gotchas-field-verified)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Breaking Changes (introduced in v9.0.0)

These three items are the only true **breaking** changes between `v8.6.0`
and `v9.2.0` — everything else in this guide is additive/optional, or (for
`v9.2.0`'s caradhras rename) shipped with its own backward-compatibility
layer. All three were introduced in `v9.0.0` and carry through unchanged
into `v9.2.0`.

### 1. Component Names Now Derived from Release Name

**What changed:**

Component names (identity, auth, auth-backend) are now derived from the Helm release name instead of being hardcoded to `plugin-access-manager-*`.

| Component | v8.6.0 Default | v9.2.0 Default |
|-----------|----------------|----------------|
| Identity | `plugin-access-manager-identity` | `<release-name>-identity` |
| Auth | `plugin-access-manager-auth` | `<release-name>-auth` |
| Auth Backend | `plugin-access-manager-auth-backend` | `<release-name>-auth-backend` |

**Before (v8.6.0):**

```yaml
identity:
  name: "plugin-access-manager-identity"

auth:
  name: "plugin-access-manager-auth"
  backend:
    name: "plugin-access-manager-auth-backend"
```

**After (v9.2.0):**

```yaml
identity:
  # -- Component name. Empty derives it from the release name (<release>-identity),
  # which is what the cross-component DNS defaults resolve to. Set it only to pin a
  # legacy name, and remember every other component reference must then be pinned too.
  name: ""

auth:
  # -- Component name. Empty derives it from the release name (<release>-auth).
  name: ""
  backend:
    # -- Component name. Empty derives it from the release name (<release>-auth-backend).
    name: ""
```

**Why this matters:**

- **If your release is named `plugin-access-manager`**: No action required. Component names remain unchanged.
- **If your release has a different name** (e.g., `my-auth-plugin`): Component names will change to `my-auth-plugin-identity`, `my-auth-plugin-auth`, etc. This affects:
  - Kubernetes resource names (Deployments, Services, ConfigMaps, Secrets)
  - Service DNS names used for cross-component communication
  - Any external references to these services

**Operational impact:**

The upgrade will create new Deployments and Services with the new names. The old resources will remain until manually cleaned up. This can cause:
- Duplicate pods running simultaneously
- Service selector conflicts if not properly managed
- Potential downtime if external systems reference the old service names

> **Warning:** If you are not using the default release name `plugin-access-manager`, you MUST pin the component names to their v8.6.0 values to maintain continuity. See [Step 2](#step-2-pin-component-names-if-not-using-default-release-name) below.

> **v9.2.0 update:** the "Auth Backend" component in the table above was itself renamed `auth-backend` → `caradhras` in `v9.2.0` (see [Notable Changes §1](#1-caradhras-component-promotion)). Its release-derived name is therefore `<release-name>-caradhras`, not `<release-name>-auth-backend`, once you're on `v9.2.0`. If you pinned `auth.backend.name` per this section, that pin is still honored as a fallback — but read the caradhras section before assuming nothing else changed for this component.

### 2. Admin Password Now Required

**What changed:**

The default admin password has been removed from `values.yaml`. The chart now fails installation if `auth.initUser.adminPassword` is empty and `useExistingSecret` is false.

> **Path correction:** `initUser` lives directly under `auth:`, as a sibling of `auth.backend`, not under `auth.backend.initUser`. Templates read `.Values.auth.initUser.*` exclusively — a value set under `auth.backend.initUser` is silently ignored by Helm (it just becomes an unused key) and the chart falls back to the `auth.initUser` default. Placing it under `auth.backend` is easy to assume by analogy with `auth.backend.migrations`, but it is incorrect and has caused real upgrade failures.

| Setting | v8.6.0 | v9.2.0 |
|---------|--------|--------|
| `auth.initUser.adminPassword` | `"Lerian@123"` (default) | `""` (no default, required) |

**Before (v8.6.0):**

```yaml
auth:
  initUser:
    adminPassword: "Lerian@123"
```

**After (v9.2.0):**

```yaml
auth:
  initUser:
    # -- Admin password (will be stored in a secret). REQUIRED when initUser is
    # -- enabled and useExistingSecret is false — the install fails loud if it is
    # -- empty. The chart ships no default on purpose: a published default password
    # -- on the platform admin account is a live credential in every install that
    # -- never overrode it.
    adminPassword: ""
```

**Why this matters:**

Publishing a default password for the platform admin account creates a security vulnerability in every installation that doesn't explicitly override it. The chart now enforces that operators must consciously set a password.

**Operational impact:**

- Upgrades will fail if you don't provide a password via `values.yaml` or `--set`
- If you were relying on the default password `Lerian@123`, you must now explicitly set it (or choose a new secure password)

> **If this is a `helm upgrade` of an existing release**, the admin user was already created during the original install — you almost never need `initUser` to run again. The simplest fix for most upgrades is to set:
> ```yaml
> auth:
>   initUser:
>     enabled: false
> ```
> This skips the Job and the generated Secret entirely, so `adminPassword` is never evaluated and the `required` guard never fires. Only keep `initUser.enabled: true` (and set `adminPassword`, or `useExistingSecret` + `adminPasswordSecretName`) if you actually need the chart to (re)create the admin user — e.g. on a fresh install, or a DB reset that wiped the existing admin account.

> **Important:** You must either set `auth.initUser.enabled: false` (upgrades, see above), or set `auth.initUser.adminPassword` / use an existing secret (fresh installs). See [Step 3](#step-3-set-or-disable-the-admin-password) below.

### 3. Cross-Component DNS References Updated

**What changed:**

Default values for cross-component DNS references have been removed from `values.yaml` and are now computed dynamically in templates based on the release name.

| Setting | v8.6.0 Default | v9.2.0 Default |
|---------|----------------|----------------|
| `identity.configmap.AUTH_ADDRESS` | `http://plugin-access-manager-auth:4000` | Computed: `http://<release>-auth:4000` |
| `identity.configmap.AUTHORIZER_CLIENT_ID` | `{{ .Values.common.authorizer.clientId }}` | Computed from `common.authorizer.clientId` |
| `auth.configmap.DB_HOST` | `plugin-access-manager-auth-database` | Computed from subchart fullname |
| `auth.configmap.REDIS_HOST` | `plugin-access-manager-valkey-primary` | Computed from subchart fullname |
| `auth.configmap.AUTHORIZER_CLIENT_ID` | `ac56c81d4d6d95c0ac12` | Computed from `common.authorizer.clientId` |

**Before (v8.6.0):**

```yaml
identity:
  configmap:
    AUTH_ADDRESS: "http://plugin-access-manager-auth:4000"
    AUTHORIZER_CLIENT_ID: "{{ .Values.common.authorizer.clientId }}"

auth:
  configmap:
    DB_HOST: "plugin-access-manager-auth-database"
    REDIS_HOST: "plugin-access-manager-valkey-primary"
    AUTHORIZER_CLIENT_ID: "ac56c81d4d6d95c0ac12"
```

**After (v9.2.0):**

```yaml
identity:
  configmap:
    # AUTH_ADDRESS defaults to http://<auth component>:4000 (templates/identity/configmap.yaml).
    # Set it only to point identity at an auth outside this release.

auth:
  configmap:
    # DB_HOST defaults to the bundled auth-database Service (templates/auth/configmap.yaml).
    # Set it only for an external database.
    # REDIS_HOST defaults to the bundled valkey primary Service (templates/auth/configmap.yaml).
    # Set it only for an external Redis/Valkey.
```

**Why this matters:**

- The hardcoded references only worked when the release was named `plugin-access-manager`
- With any other release name, the DNS references pointed to non-existent services
- Init containers waiting for dependencies would block forever
- The new dynamic computation ensures DNS names match actual Service names

**Operational impact:**

If you have explicitly set any of these values in your `values.yaml` to override the defaults, those overrides will continue to work. If you were relying on the defaults, they will now automatically resolve to the correct service names based on your release name.

> **Note:** You only need to set these values if you're pointing to external services outside the Helm release (e.g., an external database or Redis cluster).

# Notable Changes (introduced in v9.2.0)

`v9.2.0` shipped as a **minor** release, not a major one, because every
item below has a backward-compatibility fallback — with one deliberate
exception called out in item 1. None of these three items require action
if you're doing a fresh install; they matter most for upgrades of an
existing release.

### 1. Caradhras Component Promotion

The auth backend component (formerly `auth.backend`) has been promoted to a top-level component named `caradhras`. This reflects the product transition from Casdoor to Lerian's Caradhras authorization service.

**What changed:**

| Setting | v9.1.0 | v9.2.0 |
|---------|--------|--------|
| Component path | `auth.backend.*` | `caradhras.*` |
| Component name | `<release>-auth-backend` | `<release>-caradhras` |
| Image repository | `ghcr.io/lerianstudio/casdoor` | `ghcr.io/lerianstudio/caradhras` |
| Image tag | `3.1.0` | `1.2.0` |
| Migrations image | `ghcr.io/lerianstudio/casdoor-migrations` | `ghcr.io/lerianstudio/caradhras-migrations` |

**Before (v9.1.0):**

```yaml
auth:
  backend:
    name: ""
    replicaCount: 1
    service:
      type: ClusterIP
      port: 8000
    image:
      repository: ghcr.io/lerianstudio/casdoor
      pullPolicy: Always
      tag: "3.1.0"
    migrations:
      image:
        repository: ghcr.io/lerianstudio/casdoor-migrations
        pullPolicy: Always
        tag: "3.1.0"
```

**After (v9.2.0):**

```yaml
caradhras:
  name: ""
  replicaCount: ""
  service:
    type: ClusterIP
    port: ""
    annotations: {}
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.2.0"
  migrations:
    image:
      repository: ""
      pullPolicy: ""
      tag: ""
```

**Why this matters:**

- Kubernetes resource names change from `*-auth-backend` to `*-caradhras`
- Service DNS names change: `<release>-auth-backend:8000` becomes `<release>-caradhras:8000`
- The auth component's `AUTHORIZER_ADDRESS` ConfigMap value is automatically updated to point to the new service name
- PodDisruptionBudget is now independent (see [Feature 12](#12-independent-poddisruptionbudget-for-caradhras))

> **Important:** The chart implements backward compatibility for existing installs, with **one exception**: `image.repository`, `image.tag`, and `image.pullPolicy` are NOT part of the fallback. The chart ships an explicit, non-empty default for these three (`ghcr.io/lerianstudio/caradhras:1.2.0`), and the fallback only triggers when the new key is empty — so this explicit default always wins over a legacy `auth.backend.image.*` override, even if you never touch `caradhras.image.*` yourself. If you were relying on `auth.backend.image.tag` to pin a specific version (e.g. to stay on Casdoor `3.1.0`), that override is now silently ignored; set `caradhras.image.repository`/`.tag` directly instead. Every other field — `name`, `replicaCount`, `service.port`, probe timeouts, and the *migrations* image (as opposed to the main image) — still falls back to `auth.backend.*` normally. See the [full alias table](#backward-compatibility-aliases-authbackend--caradhras).

### 2. Database Creation Default Changed

The `createDatabase` setting default has changed from `true` to `false`.

| Setting | v9.1.0 Default | v9.2.0 Default |
|---------|----------------|----------------|
| `auth.backend.createDatabase` | `true` | N/A (removed) |
| `caradhras.createDatabase` | N/A | `false` |

**Why this matters:**

Most production database users granted to the caradhras component do not have `CREATEDB` privilege. The previous default of `true` caused permission-denied errors on startup in environments where the database/schema is provisioned ahead of time by infrastructure automation.

**Action required:**

If your deployment relies on caradhras creating its own database on startup (i.e., the database user has `CREATEDB` permission and no external provisioning exists), you must explicitly set:

```yaml
caradhras:
  createDatabase: true
```

> **Warning:** If you do not set this and your database does not already exist, caradhras will fail to start with a "database does not exist" error.

### 3. Init User Job Disabled by Default (Again)

`v9.0.0` made `auth.initUser.adminPassword` required (see [Breaking Change 2](#2-admin-password-now-required)), but still defaulted `auth.initUser.enabled` to `true`. `v9.2.0` goes one step further and flips that default too.

| Setting | v9.1.0 Default | v9.2.0 Default |
|---------|----------------|----------------|
| `auth.initUser.enabled` | `true` | `false` |

**Why this matters:**

Combined with the `v9.0.0` change, `auth.initUser.enabled: true` with no password was already a guaranteed install failure. The new default (`false`) makes that explicit instead of failing loud on every install that doesn't touch this field: operators who want the admin user auto-created must now opt in.

**Action required:**

If you already followed [Step 3](#step-3-set-or-disable-the-admin-password) below and set `auth.initUser.enabled: false` explicitly, this change is a no-op for you. If you never touched the field and were relying on the (now-gone) `true` default plus your own `adminPassword`, you must now set `enabled: true` explicitly alongside it:

```yaml
auth:
  initUser:
    enabled: true
    adminPassword: "your-secure-password"
```

> **Note:** Same as before — the init user job only runs on first install, not on upgrades. If you delete the admin user after creation, it will not be recreated.

# Additive Features (v9.0.0 + v9.1.0 + v9.2.0)

None of the items in this section are required to complete the upgrade —
they are new capabilities you can opt into now or later.

### 1. Centralized Authorizer Client ID

A new `common.authorizer.clientId` field centralizes the authorizer client ID configuration, shared by both identity and auth components. Previously it was duplicated: hardcoded in `auth.configmap.AUTHORIZER_CLIENT_ID` and referenced via template syntax in `identity.configmap.AUTHORIZER_CLIENT_ID`.

```yaml
common:
  authorizer:
    # -- Casdoor application client id, shared by the identity and auth components.
    clientId: "ac56c81d4d6d95c0ac12"
```

Both components use this value automatically; override per-component with `{identity,auth}.configmap.AUTHORIZER_CLIENT_ID` if needed.

### 2. Automatic Service Discovery for Dependencies

New template helpers (`plugin-access-manager.authDatabaseHost`, `plugin-access-manager.valkeyHost`) automatically discover the correct service names for bundled dependencies (auth-database, valkey) based on the release name and subchart configuration, honoring `nameOverride`/`fullnameOverride`. If you use the bundled database and Redis/Valkey (default configuration), no changes are needed — this fixes the same underlying problem as [item 3 of the breaking changes](#3-cross-component-dns-references-updated).

### 3. Lerian Common Helm Library Integration

Introduces `lerian-common-helm` as a dependency, providing shared templates and configuration patterns across all Lerian Studio charts (foundation for the masks in items 4-6 below).

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.0.0"
    repository: "oci://ghcr.io/lerianstudio"
```

Run `helm dependency update` after upgrading. Your existing configuration continues to work without modification — this is purely foundational.

### 4. Global Configuration Masks

A new top-level `global` block lets you set environment-wide defaults once instead of duplicating them across `auth` and `identity`:

```yaml
global:
  cloud: ""
  datastores: {}
  env: {}
  multiTenant: {}
  serviceDiscovery: {}
  observability: {}
```

**Configuration precedence** (highest to lowest):

1. Native component configmap key (e.g., `auth.configmap.ENV_NAME`)
2. Dedicated component-level override (e.g., `auth.datastores`)
3. Global shared mask (e.g., `global.datastores`)
4. Cloud topology preset (e.g., `global.cloud: "aws"`)
5. Chart default value

**Example:**

```yaml
# Before: duplicated per component
auth:
  configmap:
    ENV_NAME: "production"
identity:
  configmap:
    ENV_NAME: "production"

# After: set once
global:
  env:
    name: "production"
```

> **Important:** A component-level `ENV_NAME` (or any masked key) still overrides the global value if both are set — remove the component-level key to actually use the global mask.

### 5. Datastore Connection Masks

Database and Redis connection parameters can be configured once at the environment level:

| Setting | Legacy Location | Mask Location |
|---------|-----------------|----------------|
| PostgreSQL host | `auth.configmap.DB_HOST` | `global.datastores.postgres.host` |
| PostgreSQL port | `auth.configmap.DB_PORT` | `global.datastores.postgres.port` |
| PostgreSQL user | `auth.configmap.DB_USER` | `global.datastores.postgres.user` |
| PostgreSQL SSL mode | `auth.configmap.DB_SSLMODE` | `global.datastores.postgres.ssl` |
| Redis host | `auth.configmap.REDIS_HOST` | `global.datastores.redis.host` |
| Redis port | `auth.configmap.REDIS_PORT` | `global.datastores.redis.port` |
| Redis user | `auth.configmap.REDIS_USER` | `global.datastores.redis.user` |
| Redis TLS | `auth.configmap.REDIS_TLS` | `global.datastores.redis.tls` |
| Redis CA cert | `auth.configmap.REDIS_CA_CERT` | `global.datastores.redis.caCert` |

If you don't configure the masks, the chart continues to use the bundled in-cluster PostgreSQL and Valkey instances, same as before. `global.cloud: "aws"` automatically sets `postgres.ssl: "require"` and `redis.tls: "true"` unless overridden.

> **Warning:** Do not set connection parameters in both `auth.configmap.DB_*` and `global.datastores.postgres` — the native configmap keys take precedence and silently defeat the centralized mask.

### 6. Service Discovery Configuration Masks

Consul service discovery configuration now derives all `SD_*` environment variables from a single global block when a component opts in.

| Setting | Legacy | Mask |
|---------|--------|------|
| Opt-in flag | `auth.configmap.SD_ENABLED` | unchanged, still per-component |
| Consul address | `auth.configmap.SD_ADDRESS` | `global.serviceDiscovery.address` |
| External address | `auth.configmap.SD_EXTERNAL_ADDRESS` | Derived from ingress host |
| External port | `auth.configmap.SD_EXTERNAL_PORT` | `global.serviceDiscovery.externalPort` |
| TLS enabled | `auth.configmap.SD_TLS` | `global.serviceDiscovery.tls` |

> **Important:** `SD_ENABLED` is **not** part of the mask — set it directly on each component (`auth.configmap.SD_ENABLED`, `identity.configmap.SD_ENABLED`). Setting `global.serviceDiscovery.*` alone does not register any component with Consul.

When `SD_ENABLED` is unset or `false`, the legacy static `SD_*` keys continue to work exactly as before — zero diff for existing installs that don't use service discovery.

### 7. OpenTelemetry Configuration Consolidation

OTel env vars are now managed through the shared `lerian-common.otel.envFlat` helper. `ENABLE_TELEMETRY` can now be set globally via `global.observability.enabled` (component-level `configmap.ENABLE_TELEMETRY` still overrides it if set). All other OTel defaults are unchanged.

### 8. Template Refactoring

HPA, PDB, and the auth-backend Service now use shared `lerian-common-helm` templates. Rendered manifests are functionally identical (minor formatting only), with two concrete behavior changes worth knowing:

- **auth-backend PDB `minAvailable` default**: was `0`, is now `1`. Only affects deployments with `auth.pdb.enabled: true` and no explicit `minAvailable`/`maxUnavailable` set.
- **auth-backend migrations Job name**: now truncated to 63 characters (`trunc 63 | trimSuffix "-"`) to avoid an invalid `job-name` pod label on long release names, which previously made the Job fail to create pods.

### 9. Auth Backend Service Configuration Moved

The auth-backend service configuration moved from the top-level `auth.service` block to a dedicated `auth.backend.service` block, and the port is now configurable instead of hardcoded `8000`:

```yaml
auth:
  backend:
    service:
      type: ClusterIP
      port: 8000
```

> **Note:** If you were overriding `auth.service.type` expecting it to affect auth-backend, set `auth.backend.service.type` instead.

### 10. Caradhras UI Component

A new optional UI component (`caradhras.ui`) is available, an nginx-based SPA console that serves the Caradhras admin panel and reverse-proxies API requests to the caradhras backend service. **Disabled by default.**

```yaml
caradhras:
  ui:
    enabled: true
```

| Setting | Default | Description |
|---------|---------|-------------|
| `caradhras.ui.image.repository` | `ghcr.io/lerianstudio/caradhras-ui` | UI container image |
| `caradhras.ui.image.tag` | `1.2.0` | UI image version |
| `caradhras.ui.service.port` | `80` | Service port |
| `caradhras.ui.replicaCount` | `1` | Number of replicas |
| `caradhras.ui.ingress.enabled` | `false` | Enable ingress |

```yaml
caradhras:
  ui:
    enabled: true
    ingress:
      enabled: true
      className: nginx
      hosts:
        - host: caradhras-console.example.com
          paths:
            - path: /
              pathType: Prefix
```

> **Note:** The UI ingress (`caradhras.ui.ingress`) is separate from the backend API ingress (`caradhras.ingress`, item 11 below). Most deployments will only expose the UI publicly and keep the backend API internal.

### 11. Caradhras Ingress Support

The caradhras backend component now supports its own ingress configuration, independent of the auth and identity components — previously it had none, so external access required a hand-declared raw Ingress resource outside the chart.

```yaml
caradhras:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: caradhras-api.example.com
        paths:
          - path: /
            pathType: Prefix
```

> **Important:** Do not confuse `caradhras.ingress` (backend API, port 8000) with `caradhras.ui.ingress` (SPA console, port 80). They front different services.

### 12. Independent PodDisruptionBudget for Caradhras

Caradhras now has its own PodDisruptionBudget, separate from `auth.pdb` (which previously covered both `auth` and `auth-backend`).

```yaml
auth:
  pdb:
    enabled: true
caradhras:
  pdb:
    enabled: true   # defaults to enabled, matching the previous shared behavior
```

> **Action required:** If you previously disabled `auth.pdb.enabled` intending to also disable the PDB for the auth backend, you must now also set `caradhras.pdb.enabled: false` — the two are independent starting in `v9.2.0`.

# Required Migration Steps

Steps 1-4 correspond to the three breaking changes from `v9.0.0`. Steps 5-6
correspond to the two "Notable Changes" from `v9.2.0` that actually require
a decision (the third, initUser, is covered by Step 3 already). All six
must be reviewed for every install upgrading from `v8.6.0`/`v8.x` to
`v9.2.0`.

### Step 1: Identify Your Current Release Name

```bash
helm list -n plugin-access-manager
```

Look for the release name in the `NAME` column (commonly `plugin-access-manager`, but can be custom).

### Step 2: Pin Component Names (If Not Using Default Release Name)

> Only follow this step if your release name is **not** `plugin-access-manager`.

```yaml
identity:
  name: "plugin-access-manager-identity"

auth:
  name: "plugin-access-manager-auth"
  backend:
    name: "plugin-access-manager-auth-backend"
```

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 9.2.0 \
  -n plugin-access-manager \
  --set identity.name="plugin-access-manager-identity" \
  --set auth.name="plugin-access-manager-auth" \
  --set auth.backend.name="plugin-access-manager-auth-backend"
```

Alternatively, embrace the new release-based naming: accept new Deployments/Services under the new names, update external references (ingress, monitoring), then clean up the old resources once the new ones are confirmed healthy.

### Step 3: Set or Disable the Admin Password

`initUser` lives directly under `auth:`, not under `auth.backend:`.

**Most upgrades** (existing release, admin user already created): disable the job — no password needed at all.

```yaml
auth:
  initUser:
    enabled: false
```

**Fresh installs, or the admin account was wiped:** set a password, or point at an existing secret.

```yaml
auth:
  initUser:
    enabled: true
    adminPassword: "YourSecurePassword123!"
```

```yaml
auth:
  initUser:
    enabled: true
    useExistingSecret: true
    adminPasswordSecretName: "my-admin-password-secret"
    adminPasswordSecretKey: "password"
```

### Step 4: Review Cross-Component References

Check whether your current `values.yaml` explicitly sets any of: `identity.configmap.AUTH_ADDRESS`, `identity.configmap.AUTHORIZER_ADDRESS`, `auth.configmap.DB_HOST`, `auth.configmap.REDIS_HOST`, `auth.configmap.AUTHORIZER_ADDRESS`.

- **Not set:** no action — the chart now computes the correct DNS names from your release name.
- **Set, pointing at external services:** keep the overrides.
- **Set, only as a workaround for the old hardcoded defaults:** remove them, they're no longer needed.

### Step 5: Check the Caradhras Image Override

If your current `values.yaml` sets `auth.backend.image.repository` or `auth.backend.image.tag` (e.g. to pin a specific Casdoor version), **that override no longer applies** — see [Notable Change 1](#1-caradhras-component-promotion). After upgrading, the deployment will run `ghcr.io/lerianstudio/caradhras:1.2.0` regardless.

- **If that's what you want** (adopt the new Caradhras image): no action needed.
- **If you need to stay on the old Casdoor image for now:** set `caradhras.image.repository`/`.tag` explicitly — do not rely on the legacy `auth.backend.image.*` path for this specific field.

```yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/casdoor
    tag: "3.1.0"
```

### Step 6: Check the createDatabase Setting

Check if your database user has `CREATEDB` privilege:

```bash
psql -h <db-host> -U <db-user> -d postgres -c "\du <db-user>"
```

- **No `CREATEDB`** (most production setups): no action required — the new default (`caradhras.createDatabase: false`) is already correct.
- **Has `CREATEDB` and you rely on auto-creation:** set `caradhras.createDatabase: true` explicitly.

# Optional Migration Steps

None of these three are required — skip them if you want to defer
adopting the new masks or the `caradhras.*` path, and revisit later.

### Step 7: Migrate to Global Masks

Existing `auth.configmap`/`identity.configmap` values continue to work unmodified (native keys take precedence over masks). To consolidate:

**Before:**

```yaml
auth:
  configmap:
    ENV_NAME: "production"
    DB_HOST: "postgres.example.com"
    DB_PORT: "5432"
    DB_USER: "auth"
    DB_SSLMODE: "require"
    REDIS_HOST: "redis.example.com"
    REDIS_PORT: "6379"
    REDIS_USER: "auth"
    REDIS_TLS: "true"
    MULTI_TENANT_ENABLED: "true"
    ENABLE_TELEMETRY: "true"
identity:
  configmap:
    ENV_NAME: "production"
    MULTI_TENANT_ENABLED: "true"
    ENABLE_TELEMETRY: "true"
```

**After:**

```yaml
global:
  env:
    name: "production"
  multiTenant:
    enabled: true
  observability:
    enabled: true
  datastores:
    postgres:
      host: "postgres.example.com"
      port: "5432"
      user: "auth"
      ssl: "require"
    redis:
      host: "redis.example.com"
      port: "6379"
      user: "auth"
      tls: "true"

auth:
  configmap: {}
identity:
  configmap: {}
```

Remove the migrated keys from the component `configmap` blocks — otherwise they keep taking precedence over the global mask and the migration has no visible effect.

### Step 8: Migrate Service Discovery Configuration

Only relevant if `SD_ENABLED: "true"` is set on any component.

**Before:**

```yaml
auth:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.internal:8500"
    SD_EXTERNAL_ADDRESS: "auth.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"
identity:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.internal:8500"
    SD_EXTERNAL_ADDRESS: "identity.example.com"
    SD_EXTERNAL_PORT: "443"
    SD_TLS: "true"
```

**After:**

```yaml
global:
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"
    externalPort: "443"

auth:
  configmap:
    SD_ENABLED: "true"
  ingress:
    enabled: true
    hosts:
      - host: auth.example.com
        paths:
          - path: /
            pathType: Prefix
identity:
  configmap:
    SD_ENABLED: "true"
  ingress:
    enabled: true
    hosts:
      - host: identity.example.com
        paths:
          - path: /
            pathType: Prefix
```

`SD_EXTERNAL_ADDRESS` is now derived automatically from the first configured ingress host — remove the explicit key once you add the ingress block.

### Step 9: Migrate to the caradhras.\* Path

Your existing `auth.backend.*` overrides continue to work (except `image.repository`/`.tag`/`.pullPolicy` — see [Step 5](#step-5-check-the-caradhras-image-override)). To adopt the new structure and drop the legacy path:

**Before:**

```yaml
auth:
  backend:
    replicaCount: 3
    service:
      port: 8000
    image:
      repository: ghcr.io/lerianstudio/casdoor
      tag: "3.1.0"
    readinessProbe:
      timeoutSeconds: 10
    livenessProbe:
      timeoutSeconds: 10
```

**After:**

```yaml
caradhras:
  replicaCount: 3
  service:
    port: 8000
  image:
    repository: ghcr.io/lerianstudio/caradhras
    tag: "1.2.0"
  readinessProbe:
    timeoutSeconds: 10
  livenessProbe:
    timeoutSeconds: 10
```

> **Note:** For clarity and maintainability, use **either** `caradhras.*` **or** `auth.backend.*` consistently — don't mix them (see the [alias table](#backward-compatibility-aliases-authbackend--caradhras) for exactly which fields fall back and which don't).

# Configuration Reference

### Component Names

| Field | Default | Description |
|-------|---------|-------------|
| `identity.name` | `""` (derives `<release>-identity`) | Override to pin a specific identity component name |
| `auth.name` | `""` (derives `<release>-auth`) | Override to pin a specific auth component name |
| `auth.backend.name` (fallback) / `caradhras.name` | `""` (derives `<release>-caradhras` as of v9.2.0; was `<release>-auth-backend` in v9.0.0-v9.1.0) | Override to pin a specific caradhras component name |

### Admin User Initialization

```yaml
auth:
  initUser:
    enabled: true
    adminName: "admin"
    adminEmail: "admin@midaz.tech"
    adminDisplayName: "Admin"
    adminPassword: ""            # REQUIRED when enabled + not useExistingSecret
    useExistingSecret: false
    adminPasswordSecretName: ""
    adminPasswordSecretKey: "password"
```

> On an upgrade of an existing release, set `enabled: false` — see [Step 3](#step-3-set-or-disable-the-admin-password).

### Cross-Component DNS Defaults

| Variable | Computed Default | When to Override |
|----------|------------------|------------------|
| `AUTH_ADDRESS` | `http://<release>-auth:4000` | Pointing to auth service outside this release |
| `AUTHORIZER_ADDRESS` | `http://<release>-caradhras:8000` (as of v9.2.0) | Pointing to caradhras outside this release |
| `DB_HOST` | `<release>-auth-database` | Using external PostgreSQL database |
| `REDIS_HOST` | `<release>-valkey-primary` | Using external Redis/Valkey cluster |
| `AUTHORIZER_CLIENT_ID` | `common.authorizer.clientId` | Component needs different client ID |

### Caradhras Component

The authorization backend (formerly `auth.backend`, see [Notable Changes §1](#1-caradhras-component-promotion)):

```yaml
caradhras:
  name: ""
  replicaCount: ""
  createDatabase: false        # see Notable Changes §2
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.2.0"
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
  readinessProbe: {}
  livenessProbe: {}
  pdb:
    enabled: true               # independent of auth.pdb as of v9.2.0
  ingress:
    enabled: false               # new in v9.2.0, see Feature 11
  migrations:
    image:
      repository: ""            # default: ghcr.io/lerianstudio/caradhras-migrations
      tag: ""                   # default: 1.2.0
  ui:
    enabled: false                # new in v9.2.0, see Feature 10
```

### Global Configuration

```yaml
global:
  cloud: ""                 # aws | gcp | azure | "" (bundled in-cluster)
  env:
    name: "production"
  multiTenant:
    enabled: false
  observability:
    enabled: true
  datastores:
    postgres:
      host: "postgres.example.com"
      port: "5432"
      user: "access_manager"
      ssl: "require"
    redis:
      host: "redis.example.com"
      port: "6379"
      user: "default"
      tls: "true"
      caCert: ""
  serviceDiscovery:
    address: "consul.internal:8500"
    tls: "true"
    tlsSkipVerify: "false"
    workload: ""
    preferView: ""
    internalScheme: ""
    externalPort: "443"
```

### Removed from values.yaml (now resolved through masks/template defaults)

**Auth component:** `DB_USER`, `DB_PORT`, `DB_SSLMODE`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_USER`, `REDIS_TLS`, `REDIS_CA_CERT`, `ENV_NAME`.

**Identity component:** `ENV_NAME`, `AUTH_ENABLED`, `AUTH_PORT`.

All of these can still be set directly in `auth.configmap`/`identity.configmap` to override the mask/default — the native key always takes precedence.

# Backward Compatibility Aliases (auth.backend.\* → caradhras.\*)

The chart maintains backward compatibility with the legacy `auth.backend.*` configuration path for most fields:

| New Path | Legacy Path | Default |
|----------|-------------|---------|
| `caradhras.name` | `auth.backend.name` | `<release>-caradhras` |
| `caradhras.replicaCount` | `auth.backend.replicaCount` | `1` |
| `caradhras.service.port` | `auth.backend.service.port` | `8000` |
| `caradhras.readinessProbe.timeoutSeconds` | `auth.backend.readinessProbe.timeoutSeconds` | `1` |
| `caradhras.livenessProbe.timeoutSeconds` | `auth.backend.livenessProbe.timeoutSeconds` | `1` |
| `caradhras.migrations.image.repository` | `auth.backend.migrations.image.repository` | `ghcr.io/lerianstudio/caradhras-migrations` |
| `caradhras.migrations.image.tag` | `auth.backend.migrations.image.tag` | `1.2.0` |
| `caradhras.migrations.image.pullPolicy` | `auth.backend.migrations.image.pullPolicy` | `Always` |

> **NOT in this list on purpose:** `caradhras.image.repository`/`.tag`/`.pullPolicy` (the main backend image, as opposed to the *migrations* image above). The chart ships these three with an explicit, non-empty default (`ghcr.io/lerianstudio/caradhras:1.2.0`), so the fallback branch — which only triggers on an *empty* new-key value — never runs for them. A legacy `auth.backend.image.*` override is silently ignored for these three fields. See [Notable Changes §1](#1-caradhras-component-promotion) and [Step 5](#step-5-check-the-caradhras-image-override).

**Precedence rules (for the fields in the table above):**

1. If `caradhras.<field>` is set (non-empty), it is used
2. Otherwise, if `auth.backend.<field>` is set (non-empty), it is used as a fallback
3. Otherwise, the hardcoded chart default is used

> **Note:** For clarity and maintainability, use **either** `caradhras.*` **or** `auth.backend.*` consistently — don't mix them.

# Known Gotchas (Field-Verified)

Found while running a real `global.cloud: "aws"` install against managed RDS/ElastiCache. Not template-diff changes, so they don't appear above — operational pitfalls worth knowing before configuring the masks.

### Redis `caCert` must be Amazon's root CA, not the RDS bundle

`global.datastores.redis.caCert` (or `auth.configmap.REDIS_CA_CERT`) must be the **Amazon Root CA1** certificate, not the RDS regional truststore bundle. RDS's bundle signs RDS/Aurora endpoints; ElastiCache/MemoryDB (and managed Valkey) TLS certificates chain to Amazon's general trust root instead. Using the RDS bundle fails at connection time with:

```
x509: certificate signed by unknown authority
```

Fetch the correct certificate with:

```bash
curl -s https://www.amazontrust.com/repository/AmazonRootCA1.pem | base64 -w0
```

and set the base64 output as `global.datastores.redis.caCert`.

### Dedicated (non-master) PostgreSQL role

`caradhras.createDatabase` (`auth.backend.createDatabase` before `v9.2.0`) controls whether caradhras' own migrations attempt `CREATE DATABASE` themselves:

- `createDatabase: true` — the connecting user must have `CREATEDB`. Fine with the master user, but defeats least-privilege if you've already created a dedicated role.
- `createDatabase: false` (**default as of `v9.2.0`**, see [Notable Changes §2](#2-database-creation-default-changed)) — use when the database is pre-created by a dedicated role without `CREATEDB` (bootstrap job, Terraform, DBA tooling). The migrations Job connects and runs schema migrations only.

```sql
CREATE ROLE plugin_access_manager WITH LOGIN PASSWORD '...';
CREATE DATABASE casdoor OWNER plugin_access_manager;
```

```yaml
global:
  datastores:
    postgres:
      host: "my-rds-instance.us-east-1.rds.amazonaws.com"
      user: "plugin_access_manager"

caradhras:
  createDatabase: false
```

> This is a one-time provisioning decision, independent of whether you use `global.datastores` or native `configmap.DB_*` keys.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.0 -n plugin-access-manager
```

> Requires the [helm-diff plugin](https://github.com/databus23/helm-diff): `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.0 -n plugin-access-manager
```
