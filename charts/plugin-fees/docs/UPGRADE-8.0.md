# Helm Upgrade from v7.3.0 to v8.0.0

# Topics

- ***[Breaking Changes](#breaking-changes)***
    - [1. `imagePullSecrets` no longer defaults to `regcred`](#1-imagepullsecrets-no-longer-defaults-to-regcred)
    - [2. New chart dependency: `lerian-common-helm`](#2-new-chart-dependency-lerian-common-helm)
    - [3. External MongoDB bootstrap now fails on a role/database mismatch](#3-external-mongodb-bootstrap-now-fails-on-a-roledatabase-mismatch)
- ***[Features](#features)***
    - [1. Shared configuration masks via `lerian-common`](#1-shared-configuration-masks-via-lerian-common)
    - [2. `SD_ENABLED`/`STREAMING_ENABLED` now honor the shared mask](#2-sd_enabledstreaming_enabled-now-honor-the-shared-mask)
    - [3. TLS support for the external MongoDB bootstrap job](#3-tls-support-for-the-external-mongodb-bootstrap-job)
    - [4. `replicaCount` no longer fights with autoscaling](#4-replicacount-no-longer-fights-with-autoscaling)
    - [5. `MIDAZ_ONBOARDING_URL`/`MIDAZ_TRANSACTION_URL` default to the unified ledger service](#5-midaz_onboarding_urlmidaz_transaction_url-default-to-the-unified-ledger-service)
    - [6. `CLIENT_ID` moved from ConfigMap to Secret (backward-compatible)](#6-client_id-moved-from-configmap-to-secret-backward-compatible)
- ***[Configuration Reference](#configuration-reference)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Breaking Changes

### 1. `imagePullSecrets` no longer defaults to `regcred`

**Before (v7.3.0):**

```yaml
fees:
  imagePullSecrets:
    - name: regcred
```

**After (v8.0.0):**

```yaml
fees:
  imagePullSecrets: []
  # - name: regcred
```

> **Warning:** If your cluster relies on a `regcred` Secret existing by default to pull the `plugin-fees` image, you must now set `fees.imagePullSecrets` explicitly. Previously the chart pointed at a `regcred` Secret name that most installs never created — this default silently assumed a Secret that, in practice, didn't exist for most operators. If you *do* have a working `regcred` Secret today, add it back explicitly:
>
> ```yaml
> fees:
>   imagePullSecrets:
>     - name: regcred
> ```

### 2. New chart dependency: `lerian-common-helm`

The chart now depends on `lerian-common-helm` v2.0.0 (OCI):

```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.0.0"
    repository: "oci://ghcr.io/lerianstudio"
```

> **Note:** Run `helm dependency update charts/plugin-fees` (or let your CI's chart-release pipeline do it) before templating/installing v8.0.0. Helm consumers pulling the packaged OCI chart directly are unaffected — the dependency is bundled in the published artifact.

### 3. External MongoDB bootstrap now fails on a role/database mismatch

`templates/bootstrap-mongodb.yaml` now validates, at Helm render time, that `global.externalMongoDefinitions.pluginFeesCredentials.roles` grants at least one role against `fees.configmap.MONGO_NAME` (default `plugin-fees-db`) — the `fail` fires while Helm renders the template, before the `bootstrap-mongodb` Job is ever created in the cluster, so both `helm template` and `helm diff` catch a mismatch upfront:

```
fail: global.externalMongoDefinitions.pluginFeesCredentials.roles has no entry
for db "plugin-fees-db" (fees.configmap.MONGO_NAME) — the app would
authenticate but be unauthorized against its own database
```

> **Why this matters:** Previously, a roles/database mismatch didn't fail the render — it created a MongoDB user with no real access to the app's own database, and the app would only discover this at runtime via an authorization error on its first query. This is now a render-time `fail` (`helm template`/`helm diff`/`helm upgrade` all catch it before anything is applied), not a runtime surprise. If you use `externalMongoDefinitions.enabled: true`, double-check your `roles` list includes an entry with `db` matching `MONGO_NAME`.

# Features

### 1. Shared configuration masks via `lerian-common`

The chart adopts the `lerian-common` datastore/global masks, letting an operator set env-wide config once instead of repeating it per component:

```yaml
global:
  datastores:
    mongo:
      host: "my-docdb.example.com"
      port: "27017"
      user: "plugin-fees"
      params: "tls=true&retryWrites=false"
  env:
    name: "production"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth:4000"
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    deploymentEnvironment: "production"
  multiTenant:
    enabled: false
  streaming:
    enabled: false
    brokers: "redpanda:9092"
  cloud: "aws"   # aws | gcp | azure — applies the matching topology preset (e.g. DocumentDB TLS/params)
```

| Mask field | Native key(s) it feeds | Precedence |
|---|---|---|
| `global.datastores.mongo.{host,port,user,params}` | `MONGO_HOST`/`MONGO_PORT`/`MONGO_USER`/`MONGO_PARAMETERS` | native `fees.configmap.<KEY>` > `datastores.mongo.*` (dedicated) > `global.datastores.mongo.*` (shared) > cloud preset > chart default |
| `global.env.name` | `ENV_NAME` | same precedence chain |
| `global.auth.{enabled,host}` | `PLUGIN_AUTH_ENABLED`/`PLUGIN_AUTH_ADDRESS` | same |
| `global.observability.{enabled,otlpEndpoint,deploymentEnvironment}` | `ENABLE_TELEMETRY`/`OTEL_EXPORTER_OTLP_ENDPOINT`/`OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | same |
| `global.multiTenant.enabled` | `MULTI_TENANT_ENABLED` | same |
| `global.streaming.*` | `STREAMING_*` (via `lerian-common.streaming.env`) | same |
| `global.cloud` | topology preset column (e.g. DocumentDB TLS defaults) | ranks below shared/dedicated, above chart default |

> **Note:** Every native `fees.configmap.<KEY>` override still works exactly as before — if you don't set any `global.*` block, the chart renders byte-identical to v7.3.0's own defaults (aside from the breaking changes above). The masks are purely additive: a way to configure the same fields once per environment instead of once per chart.

**Example: single-tenant environment using the shared mask**

```yaml
global:
  datastores:
    mongo:
      host: "shared-docdb.internal"
      user: "plugin-fees"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000"
  observability:
    enabled: true
```

### 2. `SD_ENABLED`/`STREAMING_ENABLED` now honor the shared mask

In v7.3.0, `SD_ENABLED` and `STREAMING_ENABLED` only read the native ConfigMap key — `global.serviceDiscovery.enabled`/`global.streaming.enabled` had no effect even when set, because the toggle was resolved before being passed into the `lerian-common` helper. This is now fixed:

```yaml
global:
  serviceDiscovery:
    enabled: true
  streaming:
    enabled: true
    brokers: "redpanda:9092"
```

> **Important:** If you were previously relying on `global.serviceDiscovery.enabled`/`global.streaming.enabled` having *no effect* on `plugin-fees` (e.g. it stayed disabled here while enabled everywhere else), set `fees.configmap.SD_ENABLED: "false"` / `STREAMING_ENABLED: "false"` explicitly now — the native key still always wins over the mask.

### 3. TLS support for the external MongoDB bootstrap job

`global.externalMongoDefinitions` gained `tls` and `caCert` for managed MongoDB (e.g. AWS DocumentDB), which always requires TLS:

```yaml
global:
  externalMongoDefinitions:
    enabled: true
    tls: true                    # mongosh --tls --tlsAllowInvalidCertificates --tlsAllowInvalidHostnames
    caCert:
      secretName: "docdb-ca-bundle"   # takes precedence over the insecure bypass flags above
      secretKey: "ca.crt"
```

> **Warning:** `tls: true` *without* `caCert.secretName` connects with `--tlsAllowInvalidCertificates --tlsAllowInvalidHostnames` — this **disables both certificate and hostname validation**, it does not "trust" any certificate chain. It's an insecure bypass, suitable only for quick dev/test connectivity. When `caCert.secretName` is set, the bootstrap Job mounts the real CA bundle and connects with `--tls --tlsCAFile=...` instead, with full validation — **use `caCert` in production.**

The Job's hooks were also hardened to self-heal on upgrade instead of leaving a stale Job retrying forever:

```yaml
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/sync-options: Replace=true,Force=true
```

### 4. `replicaCount` no longer fights with autoscaling

`templates/fees/deployment.yaml` now omits `spec.replicas` entirely when `fees.autoscaling.enabled: true`, matching the pattern already used elsewhere in the bundle:

```yaml
fees:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
```

> **Why this matters:** Previously, `spec.replicas` was always set to `fees.replicaCount`, which meant every reconcile of the Deployment (not just the HPA) could fight over the replica count when autoscaling was enabled — Helm would repeatedly try to reset it back to `replicaCount` while the HPA scaled it elsewhere, showing up as spurious diffs/drift in ArgoCD.

### 5. `MIDAZ_ONBOARDING_URL`/`MIDAZ_TRANSACTION_URL` default to the unified ledger service

```yaml
# Before (v7.3.0) — assumed the old split onboarding/transaction services
MIDAZ_ONBOARDING_URL: "http://midaz-onboarding.midaz.svc.cluster.local:3000/v1/"
MIDAZ_TRANSACTION_URL: "http://midaz-transaction.midaz.svc.cluster.local:3002/v1/"

# After (v8.0.0) — matches the current unified Midaz ledger topology
MIDAZ_ONBOARDING_URL: "http://midaz-ledger.midaz.svc.cluster.local:3002/v1/"
MIDAZ_TRANSACTION_URL: "http://midaz-ledger.midaz.svc.cluster.local:3002/v1/"
```

> **Note:** If you deploy Midaz with the older split onboarding/transaction services, or in a different namespace, set these two keys explicitly under `fees.configmap`.

### 6. `CLIENT_ID` moved from ConfigMap to Secret (backward-compatible)

**Before (v7.3.0):**

```yaml
fees:
  configmap:
    CLIENT_ID: "ac56c81d4d6d95c0ac12"
```

**After (v8.0.0):**

```yaml
fees:
  secrets:
    CLIENT_ID: "ac56c81d4d6d95c0ac12"   # preferred location going forward
```

`CLIENT_ID` now travels next to `CLIENT_SECRET` in the Secret (same pairing used by `MIDAZ_CLIENT_ID`/`MIDAZ_CLIENT_SECRET` in other charts) instead of the ConfigMap. Resolution order: `fees.secrets.CLIENT_ID` > `fees.configmap.CLIENT_ID` (old location, still honored) > the app-lerian default (`ac56c81d4d6d95c0ac12`).

> **Note:** If you had customized `fees.configmap.CLIENT_ID`, it keeps working as-is — no action required. New installs and anyone touching this config going forward should set `fees.secrets.CLIENT_ID` instead; the ConfigMap fallback exists only for a smooth upgrade path and may be removed in a future major version.

# Configuration Reference

**Complete example with all new v8.0.0 features:**

```yaml
global:
  datastores:
    mongo:
      host: "shared-docdb.internal"
      user: "plugin-fees"
  env:
    name: "production"
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth:4000"
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
  serviceDiscovery:
    enabled: true
  streaming:
    enabled: true
    brokers: "redpanda:9092"
  cloud: "aws"
  externalMongoDefinitions:
    enabled: true
    tls: true
    caCert:
      secretName: "docdb-ca-bundle"
    # Required: at least one role must target fees.configmap.MONGO_NAME
    # (default "plugin-fees-db"), or the bootstrap Job's render-time
    # validation (see Breaking Changes #3 above) fails.
    pluginFeesCredentials:
      roles:
        - db: "plugin-fees-db"
          role: "readWrite"

fees:
  image:
    tag: "3.4.0"
  imagePullSecrets:
    - name: regcred   # re-add explicitly if you rely on this Secret
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
  secrets:
    CLIENT_ID: "your-client-id"        # preferred location; configmap.CLIENT_ID still honored as a fallback
    CLIENT_SECRET: "your-client-secret"
    STREAMING_SASL_PASSWORD: "your-kafka-password"
```

**Minimal v8 configuration without shared masks:**

```yaml
fees:
  image:
    tag: "3.4.0"
  imagePullSecrets: []   # add back explicitly if pulling from a private registry (see Breaking Changes #1)
  secrets:
    CLIENT_SECRET: "your-client-secret"
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.0 -n midaz-plugins
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.0 -n midaz-plugins
```
