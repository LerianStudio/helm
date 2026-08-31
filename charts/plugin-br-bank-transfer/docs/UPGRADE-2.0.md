# Deploying the latest stable v2 versus v1

This is the operator how-to for the two current stable lanes:

| Lane | Helm chart | Application | Use when |
|---|---:|---:|---|
| Latest stable v1 | `1.5.0` | `1.2.1` | Keeping an existing deployment on the previous major |
| Latest stable v2 | `2.0.0` | `2.0.0` | New deployments and controlled upgrades with a maintenance window |

Both lanes deploy two coupled images:

- `ghcr.io/lerianstudio/plugin-br-bank-transfer:<application-version>`
- `ghcr.io/lerianstudio/plugin-br-bank-transfer-migrations:<application-version>`

The chart version and application version are different in v1. Pin both
explicitly. Do not infer the application image from the chart major.

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [0. Application Money-Path Breaking Change: Devolution Sweep No Longer Auto-Resends](#0-application-money-path-breaking-change-devolution-sweep-no-longer-auto-resends)
  - [1. New Dependency: lerian-common-helm](#1-new-dependency-lerian-common-helm)
  - [2. Global Datastore Masks Replace Hardcoded Defaults](#2-global-datastore-masks-replace-hardcoded-defaults)
  - [3. ConfigMap Keys Removed or Moved to Masks](#3-configmap-keys-removed-or-moved-to-masks)
  - [4. MongoDB Bootstrap Job Now Available](#4-mongodb-bootstrap-job-now-available)
  - [5. Bootstrap Job Hook Ordering Fixed](#5-bootstrap-job-hook-ordering-fixed)
  - [6. PostgreSQL Password Handling Improved](#6-postgresql-password-handling-improved)
- **[New Features](#new-features)**
  - [1. Environment-Wide Configuration Masks](#1-environment-wide-configuration-masks)
  - [2. Streaming Support (lib-streaming v3 / RedPanda)](#2-streaming-support-lib-streaming-v3--redpanda)
  - [3. Managed-Cloud Topology Presets](#3-managed-cloud-topology-presets)
  - [4. MongoDB TLS and CA Bundle Support](#4-mongodb-tls-and-ca-bundle-support)
  - [5. Multi-Tenant Redis CA Certificate Support](#5-multi-tenant-redis-ca-certificate-support)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Step 1: Pin the lane and render it](#step-1-pin-the-lane-and-render-it)
  - [Step 2: Prepare v2 configuration](#step-2-prepare-v2-configuration)
  - [Step 3: Drain streaming while v1 is alive](#step-3-drain-streaming-while-v1-is-alive)
  - [Step 4: Stop every v1 pod](#step-4-stop-every-v1-pod)
  - [Step 5: Apply v2 and its migrations at zero replicas](#step-5-apply-v2-and-its-migrations-at-zero-replicas)
  - [Step 6: Start and verify v2](#step-6-start-and-verify-v2)
- **[Fresh installs](#fresh-installs)**
- **[GitOps and ArgoCD sequence](#gitops-and-argocd-sequence)**
- **[Rollback](#rollback)**
- **[Verification checklist](#verification-checklist)**

## Overview

Version 2.0.0 is a **major release** that introduces breaking changes requiring operator action before upgrading. This release adds a new chart dependency (`lerian-common-helm`), implements environment-wide configuration masks for datastores and cross-cutting concerns (multi-tenancy, observability, auth, streaming), removes hardcoded ConfigMap defaults in favor of mask-driven resolution, and adds a MongoDB bootstrap job for external MongoDB deployments. The application version is upgraded from 1.2.1 to 2.0.0.

This is **not a normal image bump**. Upgrading v1 to v2 requires zero overlap
between binaries. The v1 and v2 streaming outbox envelopes are mutually
unreadable, and the TED IN identity migrations make old/new coexistence a money
hazard. A rolling update is forbidden even when streaming is disabled.

Operators **must** review their datastore configuration, migrate removed ConfigMap keys, and configure the new MongoDB bootstrap job if using external MongoDB. The chart now supports managed-cloud topology presets (AWS, GCP, Azure) and streaming event publication via RedPanda/Kafka.

## Breaking Changes

### 0. Application Money-Path Breaking Change: Devolution Sweep No Longer Auto-Resends

> ⚠️ **This is the reason 2.0.0 is a major bump on the application side, not the
> chart refactor below.** It carries a real risk of double-paying a bank if the
> deploy sequencing below isn't followed. Read this before any of the
> chart-level changes.

**What changed:**  
`plugin-br-bank-transfer` v2.0.0 aligns TED transaction contracts and devolution identity (`feat!: align TED transaction contracts and devolution identity` in the application's own release history). Two things move together:

1. A new deploy-critical migration, `000028_ted_in_devolution_identity_walk`, which the TED IN poller's inbound drain stays gated behind until it completes.
2. The devolution sweep **no longer re-dispatches an `STR0010` on its own initiative** when the clearing house never received a devolution — it only asks and records the answer. An operator now moves that money by hand.

**Why it matters — this is a money hazard, not a config change:**  
Per the application's own migration runbook ("Operator notes" → "The deploy precondition, in one place"), a **rolling upgrade with old and new binaries coexisting can pay a bank twice**:

- **No previous binary may still be draining the tenant's JD queue** when the migration runs — a pre-2.0.0 pod writes inbound rows under the old identity, invisible to the new credit guard forever, so a redelivered TED can be credited twice.
- **No pod running a binary whose devolution sweep still auto-resends (anything from before the application version that stopped the auto-resend, which includes the `1.2.1` this chart previously shipped) may be alive at the same time as a 2.0.0 pod.** One pod that still dispatches is enough: if an aged devolution the clearing house never received gets swept by the old pod while the new one is also up, **two `STR0010`s go out for the same TED to the same paying bank — with no reversal path.** This condition is symmetric: it applies to upgrading *and* to rolling back.

**Operational impact:**  
The chart's default `bankTransfer.deploymentUpdate` is `RollingUpdate` with `maxSurge: 100%` / `maxUnavailable: 0` — by design, it brings the new pod up *before* retiring the old one. That is exactly the coexistence window this breaking change warns against. **Do not rely on the default rolling strategy for this upgrade.**

Recommended sequencing, validated on `benedita/dev-st` and `benedita/stg-mt`:
1. Scale `bankTransfer.replicaCount` to `0` and confirm the old pods are fully `Terminated` (not just `Terminating`).
2. Only then run `helm upgrade` with the `2.0.0` image tag and replicas restored. The migration Job (hook) runs before any new pod exists, and no old binary is ever up at the same time as a new one.

**Migration required:**  
Yes — this is an operator deploy-sequencing step, not a values.yaml change. See the application's migration runbook for the full precondition text.

### 1. New Dependency: lerian-common-helm

**What changed:**  
The chart now depends on `lerian-common-helm` version 2.0.0, a shared library chart providing template helpers for datastore masks, global configuration resolution, and streaming environment variables.

**Chart.yaml diff:**
```yaml
dependencies:
  - name: lerian-common-helm
    version: "2.0.0"
    repository: "oci://ghcr.io/lerianstudio"
  - name: valkey
    version: "2.4.7"
    repository: "oci://registry-1.docker.io/bitnamicharts"
```

**Why it matters:**  
The `lerian-common-helm` library provides the `lerian-common.datastore.value`, `lerian-common.globalValue`, and `lerian-common.streaming.env` template helpers that power the new mask-driven configuration system. Without this dependency, the chart cannot render datastore connection strings or resolve global configuration blocks.

**Operational impact:**  
- Helm will automatically fetch the `lerian-common-helm` dependency during upgrade
- No operator action is required unless your Helm registry access is restricted (ensure `ghcr.io/lerianstudio` is accessible)

**Migration required:**  
No — Helm handles dependency resolution automatically.

### 2. Global Datastore Masks Replace Hardcoded Defaults

**What changed:**  
The chart now resolves PostgreSQL and Redis connection parameters (host, port, user, SSL/TLS settings) via the `global.datastores` mask instead of hardcoding them in `bankTransfer.configmap`. A native `configmap.<KEY>` entry still wins over the mask, but the chart no longer pins default values for these keys in `values.yaml`.

**Before (v1.5.0):**
```yaml
bankTransfer:
  configmap:
    POSTGRES_PORT: "5432"
    POSTGRES_USER: "bank_transfer"
    POSTGRES_SSLMODE: "require"
    REDIS_TLS: "false"
```

**After (v2.0.0):**
```yaml
# These keys are NO LONGER pinned in values.yaml — they are resolved via global.datastores
# or defaulted in templates/configmap.yaml. A native configmap.<KEY> WINS over the mask.
global:
  datastores:
    postgres:
      host: "my-rds.example.com"
      port: "5432"
      user: "bank_transfer"
      ssl: "require"
    redis:
      host: "my-elasticache.example.com:6379"
      user: "default"
      tls: "true"
```

**Why it matters:**  
- **Environment-wide consistency:** Set datastore connection details once in `global.datastores` and share them across all charts in your environment (plugin-br-bank-transfer, plugin-crm, plugin-fees, etc.)
- **Managed-cloud presets:** Use `global.cloud: "aws"` to automatically set `ssl: "require"` and `tls: "true"` for all datastores (see [Managed-Cloud Topology Presets](#3-managed-cloud-topology-presets))
- **Override flexibility:** A native `bankTransfer.configmap.POSTGRES_PORT` entry still wins over `global.datastores.postgres.port`, so existing overrides continue to work

**Affected keys:**

| ConfigMap Key | v1.5.0 Default | v2.0.0 Resolution |
|---------------|----------------|-------------------|
| `POSTGRES_PORT` | `"5432"` (pinned) | Resolved via `global.datastores.postgres.port` or defaulted to `"5432"` in template |
| `POSTGRES_USER` | `"bank_transfer"` (pinned) | Resolved via `global.datastores.postgres.user` or defaulted to `"bank_transfer"` in template |
| `POSTGRES_SSLMODE` | `"require"` (pinned) | Resolved via `global.datastores.postgres.ssl` or defaulted to `"require"` in template |
| `REDIS_TLS` | `"false"` (pinned) | Resolved via `global.datastores.redis.tls` or defaulted to `"false"` in template |

**Migration required:**  
Yes — see [Step 2: Prepare v2 configuration](#step-2-prepare-v2-configuration).

### 3. ConfigMap Keys Removed or Moved to Masks

**What changed:**  
Multiple ConfigMap keys have been removed from `values.yaml` because they are now resolved via global masks, never read by any template, or duplicated the chart's own template defaults. Pinning them in `values.yaml` was noise and a drift risk.

**Removed keys (resolved via global masks):**

| Key | v1.5.0 Default | v2.0.0 Resolution |
|-----|----------------|-------------------|
| `ENV_NAME` | `"production"` (pinned) | Resolved via `global.env.name` or defaulted to `"production"` in template |
| `MULTI_TENANT_ENABLED` | `"false"` (pinned) | Resolved via `global.multiTenant.enabled` or defaulted to `"false"` in template |
| `ENABLE_TELEMETRY` | `"false"` (pinned) | Resolved via `global.observability.enabled` or defaulted to `"false"` in template |

**Removed keys (never read by templates — dead configuration):**

| Key | v1.5.0 Default | Reason for Removal |
|-----|----------------|-------------------|
| `DEFAULT_TENANT_ID` | `"11111111-1111-1111-1111-111111111111"` | No template reads this key; it never rendered into the ConfigMap |
| `DEFAULT_TENANT_SLUG` | `"default"` | No template reads this key; it never rendered into the ConfigMap |
| `INFRA_CONNECT_TIMEOUT_SEC` | `"30"` | No template reads this key; it never rendered into the ConfigMap |
| `IS_DEVELOPMENT` | `"false"` | No template reads this key; it never rendered into the ConfigMap |

**Removed keys (duplicated chart defaults):**

| Key | v1.5.0 Default | v2.0.0 Resolution |
|-----|----------------|-------------------|
| `APPLICATION_NAME` | `"plugin-br-bank-transfer"` (pinned) | Defaulted to `"plugin-br-bank-transfer"` in template; no mask reads it |
| `SERVER_ADDRESS` | `":4027"` (pinned) | Defaulted to `":4027"` in template; no mask reads it |
| `HTTP_BODY_LIMIT_BYTES` | `"1048576"` (pinned) | Defaulted to `"1048576"` in template; no mask reads it |
| `TLS_TERMINATED_UPSTREAM` | `"true"` (pinned) | Defaulted to `"true"` in template; no mask reads it |
| `POSTGRES_DB` | `"bank_transfer"` (pinned) | Defaulted to `"bank_transfer"` in template; no mask reads it |
| `POSTGRES_MAX_OPEN_CONNS` | `"25"` (pinned) | Defaulted to `"25"` in template; no mask reads it |
| `POSTGRES_MAX_IDLE_CONNS` | `"5"` (pinned) | Defaulted to `"5"` in template; no mask reads it |
| `POSTGRES_CONN_MAX_LIFETIME_MINS` | `"30"` (pinned) | Defaulted to `"30"` in template; no mask reads it |
| `POSTGRES_CONN_MAX_IDLE_TIME_MINS` | `"5"` (pinned) | Defaulted to `"5"` in template; no mask reads it |
| `POSTGRES_CONNECT_TIMEOUT_SEC` | `"10"` (pinned) | Defaulted to `"10"` in template; no mask reads it |
| `MIGRATIONS_PATH` | `"migrations"` (pinned) | Defaulted to `"migrations"` in template; no mask reads it |
| `REDIS_DB` | `"0"` (pinned) | Defaulted to `"0"` in template; no mask reads it |
| `REDIS_PROTOCOL` | `"3"` (pinned) | Defaulted to `"3"` in template; no mask reads it |
| `REDIS_POOL_SIZE` | `"10"` (pinned) | Defaulted to `"10"` in template; no mask reads it |
| `REDIS_MIN_IDLE_CONNS` | `"2"` (pinned) | Defaulted to `"2"` in template; no mask reads it |
| `REDIS_READ_TIMEOUT_MS` | `"3000"` (pinned) | Defaulted to `"3000"` in template; no mask reads it |
| `REDIS_WRITE_TIMEOUT_MS` | `"3000"` (pinned) | Defaulted to `"3000"` in template; no mask reads it |
| `REDIS_DIAL_TIMEOUT_MS` | `"5000"` (pinned) | Defaulted to `"5000"` in template; no mask reads it |
| `MONGO_ENABLED` | `"true"` (pinned) | Defaulted to `"true"` in template; no mask reads it |
| `MONGO_DATABASE` | `"plugin_br_bank_transfer"` (pinned) | Defaulted to `"plugin_br_bank_transfer"` in template; no mask reads it |
| `MONGO_MAX_POOL_SIZE` | `"25"` (pinned) | Defaulted to `"25"` in template; no mask reads it |
| `MONGO_SERVER_SELECTION_TIMEOUT_MS` | `"3000"` (pinned) | Defaulted to `"3000"` in template; no mask reads it |
| `MONGO_HEARTBEAT_INTERVAL_MS` | `"10000"` (pinned) | Defaulted to `"10000"` in template; no mask reads it |
| `RABBITMQ_ENABLED` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |
| `RABBITMQ_EXCHANGE` | `"bank_transfer.lifecycle"` (pinned) | Defaulted to `"bank_transfer.lifecycle"` in template; no mask reads it |
| `PLUGIN_AUTH_ENABLED` | `"true"` (pinned) | Defaulted to `"true"` in template; no mask reads it |
| `PLUGIN_AUTH_ADDRESS` | `"http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"` (pinned) | Defaulted to standard in-cluster service name in template; no mask reads it |
| `OTEL_LIBRARY_NAME` | `"github.com/LerianStudio/plugin-br-bank-transfer"` (pinned) | Defaulted to `"github.com/LerianStudio/plugin-br-bank-transfer"` in template; no mask reads it |
| `OTEL_RESOURCE_SERVICE_NAME` | `"plugin-br-bank-transfer"` (pinned) | Defaulted to `"plugin-br-bank-transfer"` in template; no mask reads it |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `""` (pinned) | Defaulted to `""` in template; no mask reads it |
| `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `"production"` (pinned) | Defaulted to `"production"` in template; no mask reads it |
| `MIDAZ_BASE_URL` | `"http://midaz.midaz.svc.cluster.local.:3001"` (pinned) | Defaulted to standard in-cluster Midaz service name in template; no mask reads it |
| `MIDAZ_TRANSACTION_URL` | `"http://midaz.midaz.svc.cluster.local.:3001"` (pinned) | Defaulted to standard in-cluster Midaz service name in template; no mask reads it |
| `MIDAZ_AUTH_ENABLED` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |
| `CRM_AUTH_ENABLED` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |
| `FEES_AUTH_ENABLED` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |
| `JD_SANDBOX_MODE` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |
| `JD_SOAP_PATH` | `"/soap"` (pinned) | Defaulted to `"/soap"` in template; no mask reads it |
| `JD_SIGNING_MODE` | `"local_pem"` (pinned) | Defaulted to `"local_pem"` in template; no mask reads it |
| `JD_POLLING_ENABLED` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |
| `WEBHOOK_ENABLED` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |
| `BTF_FEE_ENABLED` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |
| `RATE_LIMIT_ENABLED` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |
| `ALLOW_INSECURE_TLS` | `"true"` (pinned) | Defaulted to `"true"` in template; no mask reads it |
| `OTEL_SDK_DISABLED` | `"false"` (pinned) | Defaulted to `"false"` in template; no mask reads it |

**Why it matters:**  
- **Reduced drift risk:** A future template default change now takes effect immediately instead of being silently overridden by a stale pin in `values.yaml`
- **Cleaner values files:** Operators only need to override keys that differ from chart defaults, not duplicate every default in their values file
- **Mask-driven resolution:** Keys like `ENV_NAME`, `MULTI_TENANT_ENABLED`, and `ENABLE_TELEMETRY` are now set once in `global.*` and shared across all charts

**Operational impact:**  
- If you never overrode these keys in your values file, no action is required — the chart defaults them in `templates/configmap.yaml`
- If you overrode any of these keys in your values file, your override continues to work (a native `configmap.<KEY>` entry wins over the mask or template default)
- If you relied on the pinned value in `values.yaml` as documentation, refer to the inline comments in `values.yaml` or the template defaults in `templates/configmap.yaml`

**Migration required:**  
Yes, if you overrode any of the removed keys — see
[Step 2: Prepare v2 configuration](#step-2-prepare-v2-configuration).

### 4. MongoDB Bootstrap Job Now Available

**What changed:**  
The chart now includes a MongoDB bootstrap job (`templates/bootstrap-mongodb.yaml`) that creates the application user and grants roles when `global.externalMongoDefinitions.enabled=true`. This job mirrors the existing PostgreSQL and RabbitMQ bootstrap jobs.

**New template:**
```yaml
# templates/bootstrap-mongodb.yaml (new file)
{{- if .Values.global.externalMongoDefinitions.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "bank-transfer.fullname" . }}-bootstrap-mongodb
  namespace: {{ include "global.namespace" . }}
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-5"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/sync-wave: "-5"
spec:
  # ... (creates user, grants roles, updates password on upgrade)
{{- end }}
```

**Why it matters:**  
- **External MongoDB support:** Operators using managed MongoDB (AWS DocumentDB, MongoDB Atlas, etc.) can now bootstrap the application user via Helm instead of manual `mongosh` commands
- **TLS support:** The job supports TLS connections with optional CA bundle mounting (required for AWS DocumentDB)
- **Idempotent:** The job creates the user on first install and updates the password + roles on subsequent upgrades

**Operational impact:**  
- The job runs as a Helm pre-install/pre-upgrade hook (weight -5) before the application deployment starts
- MongoDB is **mandatory** for this application (the app hard-requires `MONGO_ENABLED=true` for transfer audit persistence), so operators using external MongoDB must enable this job

**Migration required:**  
Yes, if you use external MongoDB — see
[Step 2: Prepare v2 configuration](#step-2-prepare-v2-configuration).

### 5. Bootstrap Job Hook Ordering Fixed

**What changed:**  
The PostgreSQL bootstrap job (`templates/bootstrap-postgres.yaml`) now runs as a **pre-install/pre-upgrade** hook (weight -5) instead of a post-install hook. The RabbitMQ bootstrap job (`templates/bootstrap-rabbitmq.yaml`) now includes ArgoCD sync options (`Replace=true,Force=true`) to handle immutable Job spec changes.

**Before (v1.5.0):**
```yaml
# templates/bootstrap-postgres.yaml
metadata:
  annotations:
    # No annotations — ran as a post-install hook by default
```

**After (v2.0.0):**
```yaml
# templates/bootstrap-postgres.yaml
metadata:
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-5"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/sync-wave: "-5"
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
    argocd.argoproj.io/sync-options: Replace=true,Force=true
```

**Why it matters:**  
- **Correct ordering:** The PostgreSQL bootstrap job must run **before** the migration job (weight -1), not after it — migrations connect as the `bank_transfer` role this job creates, so a post-install ordering caused migrations to fail with "password authentication failed for user 'bank_transfer'" on every deploy
- **Immutable Job spec:** Kubernetes Job specs are immutable — any pod-template change makes a plain `kubectl apply` or ArgoCD Sync fail to patch it in place. The new annotations ensure the Job is replaced on upgrade under both Helm and ArgoCD deploy paths

**Operational impact:**  
- On upgrade to v2.0.0, the PostgreSQL bootstrap job will run before migrations (correct order)
- The Job is naturally idempotent (create-or-update role/db/grants), so running it multiple times is safe

**Migration required:**  
No — the fix is transparent to operators.

### 6. PostgreSQL Password Handling Improved

**What changed:**  
The PostgreSQL bootstrap job now escapes single quotes in the `bank_transfer` role password and sends the `CREATE ROLE` / `ALTER ROLE` statement via stdin instead of `-c` to avoid exposing the password in process arguments.

**Before (v1.5.0):**
```yaml
# templates/bootstrap-postgres.yaml (script excerpt)
PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -v pw="$DB_PASSWORD_BANK_TRANSFER" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE" -c "CREATE ROLE bank_transfer LOGIN PASSWORD :'pw'"
```

**After (v2.0.0):**
```yaml
# templates/bootstrap-postgres.yaml (script excerpt)
ESCAPED_PW=$(printf '%s' "$DB_PASSWORD_BANK_TRANSFER" | sed "s/'/''/g")
printf "CREATE ROLE bank_transfer LOGIN PASSWORD '%s';\n" "$ESCAPED_PW" | PGPASSWORD="$DB_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER_ADMIN" -d "$DB_DATABASE"
```

**Why it matters:**  
- **Security:** The password never appears in the container's process arguments (`ps` output)
- **Correctness:** Passwords containing single quotes are now properly escaped (the old `-v pw=` interpolation didn't fire on this psql version, causing syntax errors)

**Operational impact:**  
- The job now refreshes the `bank_transfer` role password on every upgrade (idempotent `ALTER ROLE` statement), not just on first install
- Passwords with special characters (single quotes, backslashes) are now handled correctly

**Migration required:**  
No — the fix is transparent to operators.

## New Features

### 1. Environment-Wide Configuration Masks

**What changed:**  
The chart now supports environment-wide configuration masks for datastores, environment name, multi-tenancy, observability, auth, and streaming. These masks are set once in `global.*` and shared across all charts in your environment.

**New global blocks:**

```yaml
global:
  # Datastore connection details (shared across all charts)
  datastores:
    postgres:
      host: "my-rds.example.com"
      port: "5432"
      user: "bank_transfer"
      ssl: "require"
      replicaHost: "my-rds-replica.example.com"
    redis:
      host: "my-elasticache.example.com:6379"
      user: "default"
      tls: "true"

  # Environment name (e.g. production, staging, dev)
  env:
    name: "production"

  # Multi-tenancy gate
  multiTenant:
    enabled: true

  # Observability gate
  observability:
    enabled: true

  # Auth (plugin-access-manager)
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth:4000"

  # Streaming (lib-streaming v3 / RedPanda)
  streaming:
    enabled: true
    brokers: "redpanda.example.com:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "bank-transfer"
    # Additional fields: saslAllowPlaintext, compression, requiredAcks, batchLingerMs

  # Managed-cloud topology preset (aws | gcp | azure)
  cloud: "aws"
```

**Why it matters:**  
- **Single source of truth:** Set datastore connection details once and share them across all charts (plugin-br-bank-transfer, plugin-crm, plugin-fees, etc.)
- **Override flexibility:** A native `bankTransfer.configmap.<KEY>` entry still wins over the mask, so existing overrides continue to work
- **Managed-cloud presets:** Use `global.cloud: "aws"` to automatically set `ssl: "require"` and `tls: "true"` for all datastores (see [Managed-Cloud Topology Presets](#3-managed-cloud-topology-presets))

**Operational impact:**  
- Operators can now define datastore connection details once in a parent Helm chart (e.g., an umbrella chart for all Midaz plugins) and inherit them in all subcharts
- The chart continues to default to the bundled in-cluster infrastructure (PostgreSQL, Valkey, MongoDB) when no mask is set

**Migration required:**  
No — the masks are optional. Existing deployments continue to use chart defaults or native `configmap.*` overrides.

### 2. Streaming Support (lib-streaming v3 / RedPanda)

**What changed:**  
The chart now supports streaming event publication via lib-streaming v3 (RedPanda/Kafka). When `global.streaming.enabled=true` and `global.streaming.brokers` is set, the chart emits streaming configuration environment variables (broker list, TLS, SASL, compression, etc.) into the application ConfigMap.

**New configuration:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda.example.com:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "bank-transfer"
    saslAllowPlaintext: false
    compression: "snappy"
    requiredAcks: "1"
    batchLingerMs: "10"

bankTransfer:
  configmap:
    STREAMING_CLOUDEVENTS_SOURCE: "plugin-br-bank-transfer"
    # Optional overrides:
    # STREAMING_CLIENT_ID: ""
    # STREAMING_OUTBOX_DISPATCH_INTERVAL_SECONDS: ""
    # STREAMING_CB_FAILURE_RATIO: ""
    # STREAMING_CB_MIN_REQUESTS: ""
    # STREAMING_CB_TIMEOUT_S: ""
    # STREAMING_CLOSE_TIMEOUT_S: ""

  secrets:
    STREAMING_SASL_PASSWORD: "<sasl-password>"
    STREAMING_TLS_CA_CERT: "<pem-encoded-ca-bundle>"
```

**Why it matters:**  
- **Business event publication:** The application can now publish business events (transfer lifecycle events) to a RedPanda/Kafka cluster for downstream consumption
- **Disabled by default:** `STREAMING_ENABLED` defaults to `"false"` — a disabled emitter is a no-op (events are not held and replayed later)
- **Environment-wide configuration:** Broker/TLS/SASL settings are shared across all charts via `global.streaming.*`

**Operational impact:**  
- When `STREAMING_ENABLED=false`, the application does not connect to the broker (no-op emitter)
- When `STREAMING_ENABLED=true`, the application validates `STREAMING_CLOUDEVENTS_SOURCE` at startup (the chart defaults it to `"plugin-br-bank-transfer"`, which is the only value the app accepts for this service)
- SASL password and TLS CA certificate are set via `bankTransfer.secrets`, not `global.streaming` (secrets never live in global blocks)

**Migration required:**  
No — streaming is disabled by default. See
[Step 2: Prepare v2 configuration](#step-2-prepare-v2-configuration) to enable it.

### 3. Managed-Cloud Topology Presets

**What changed:**  
The chart now supports a `global.cloud` preset that automatically sets TLS/SSL flags for all datastores in one knob. Valid values are `"aws"`, `"gcp"`, `"azure"`, or `""` (empty string for bundled in-cluster infrastructure).

**New configuration:**

```yaml
global:
  cloud: "aws"
  datastores:
    postgres:
      host: "my-rds.example.com"
      # ssl: "require" is automatically set when cloud="aws"
    redis:
      host: "my-elasticache.example.com:6379"
      # tls: "true" is automatically set when cloud="aws"
```

**Why it matters:**  
- **One-knob TLS:** Set `global.cloud: "aws"` and all datastores automatically use TLS/SSL (no need to set `ssl: "require"` and `tls: "true"` for each datastore)
- **Managed-cloud defaults:** AWS RDS, ElastiCache, and DocumentDB require TLS on every connection — this preset ensures correct defaults

**Operational impact:**  
- When `global.cloud` is set to `"aws"`, `"gcp"`, or `"azure"`, the chart sets `ssl: "require"` for PostgreSQL and `tls: "true"` for Redis/MongoDB
- When `global.cloud` is `""` (empty string), the chart defaults to plaintext connections (bundled in-cluster infrastructure)
- A native `global.datastores.postgres.ssl` or `bankTransfer.configmap.POSTGRES_SSLMODE` entry still wins over the preset

**Migration required:**  
No — the preset is optional. Existing deployments continue to use explicit `ssl`/`tls` settings or chart defaults.

### 4. MongoDB TLS and CA Bundle Support

The MongoDB bootstrap job supports TLS and an optional CA bundle for external
MongoDB-compatible services such as AWS DocumentDB. When external MongoDB is
used, the rendered bootstrap Job must receive the same host, database, TLS
posture, CA, and credentials as the application. Do not enable the bootstrap
Job until those values and Secret references render correctly.

### 5. Multi-Tenant Redis CA Certificate Support

`MULTI_TENANT_REDIS_CA_CERT` is an optional PEM CA bundle for the tenant-manager
Redis/Valkey connection. Set it through `bankTransfer.secrets` only when
`MULTI_TENANT_REDIS_TLS=true` and the issuer is not already trusted by the
container image.

## Configuration Reference

The v2 chart can resolve datastore, environment, tenancy, observability, auth,
and streaming settings from `global.*`. A native
`bankTransfer.configmap.<KEY>` remains the highest-precedence application
override. Render the final manifest instead of assuming which source won.

Keep these new sensitive fields out of ConfigMaps and Git:

- `bankTransfer.secrets.STREAMING_SASL_PASSWORD`
- `bankTransfer.secrets.STREAMING_TLS_CA_CERT`
- `bankTransfer.secrets.MULTI_TENANT_REDIS_CA_CERT`

The deploy-critical environment additions are:

- `STREAMING_CLOUDEVENTS_SOURCE=plugin-br-bank-transfer` — validated even when
  streaming is disabled.
- `STREAMING_*` broker/TLS/SASL settings — required when streaming is enabled.
- `REQUIRE_UPSTREAM_HTTPS=true` — optional non-production/BYOC guard for the
  CRM and enabled Fees HTTP clients. It refuses boot when a covered URL is
  plain HTTP.
- `MULTI_TENANT_REDIS_CA_CERT` — optional CA bundle described above.

## Migration Steps

### Step 1: Pin the lane and render it

Set the operator variables once:

```bash
export RELEASE=plugin-br-bank-transfer
export NAMESPACE=plugin-br-bank-transfer
export CHART=oci://ghcr.io/lerianstudio/plugin-br-bank-transfer-helm
export VALUES_V1=values-v1.yaml
export VALUES_V2=values-v2.yaml
```

Latest stable v1:

```yaml
bankTransfer:
  image:
    tag: "1.2.1"
  migrations:
    image:
      tag: "1.2.1"
```

Latest stable v2:

```yaml
bankTransfer:
  image:
    tag: "2.0.0"
  migrations:
    image:
      tag: "2.0.0"
```

Render before touching the cluster:

```bash
helm template "$RELEASE" "$CHART" \
  --version 2.0.0 \
  --namespace "$NAMESPACE" \
  -f "$VALUES_V2" > /tmp/plugin-br-bank-transfer-v2.yaml
```

Confirm the rendered application and migrations images are both `2.0.0`, the
namespace is correct, and every ConfigMap/Secret reference exists. The release
workflow publishes both images for every stable release; moving only the API
image is unsupported.

### Step 2: Prepare v2 configuration

Before the outage:

1. Diff the live v1 values against v2 `values.yaml` and this guide.
2. Move datastore/environment/tenancy/observability/streaming settings to
   `global.*` where appropriate, or keep deliberate native overrides.
3. For external MongoDB, render and verify the bootstrap Job and CA mount.
4. Set `STREAMING_CLOUDEVENTS_SOURCE=plugin-br-bank-transfer`. The old URI form
   is rejected by v2 even when streaming is disabled.
5. If `DEPLOYMENT_MODE=saas` and streaming is enabled, set broker TLS. Plaintext
   broker transport is rejected.
6. Back up every affected PostgreSQL tenant database and record the current
   `schema_migrations` value.

Do not combine configuration discovery with the maintenance window. The values
must already render successfully before the old pods are stopped.

### Step 3: Drain streaming while v1 is alive

Skip this SQL only when streaming has never been enabled and the table contains
no `lerian.streaming.publish` rows. Otherwise run it in every database:

```sql
SELECT count(*)
  FROM outbox_events
 WHERE event_type = 'lerian.streaming.publish'
   AND status <> 'PUBLISHED';
```

The result must be `0` everywhere while v1 is still alive. Only v1 can drain v1
envelopes. Resolve `FAILED` and `INVALID` rows explicitly; they do not heal by
waiting.

Quiesce all emitters before the final count: public/API intake, the TED IN
poller, reconciliation workers, and operator trigger routes. Do not set
`STREAMING_ENABLED=false` to quiesce: disabled streaming discards new events
instead of buffering them.

### Step 4: Stop every v1 pod

Disable the HPA first. With autoscaling enabled, `replicaCount: 0` is ignored and
the HPA recreates pods from `minReplicas`.

Apply this change while the release is still chart `1.5.0` / app `1.2.1`:

```yaml
bankTransfer:
  autoscaling:
    enabled: false
  replicaCount: 0
```

```bash
helm upgrade "$RELEASE" "$CHART" \
  --version 1.5.0 \
  --namespace "$NAMESPACE" \
  -f "$VALUES_V1"

kubectl -n "$NAMESPACE" wait \
  --for=delete pod \
  -l app.kubernetes.io/name=bank-transfer \
  --timeout=10m

kubectl -n "$NAMESPACE" get deploy,hpa,pod
```

Proceed only when no v1 pod is `Running` or `Terminating` and no HPA can recreate
it. Re-run the outbox query through an administrative database connection; it
must still return `0` everywhere.

### Step 5: Apply v2 and its migrations at zero replicas

Keep autoscaling disabled and replicas at zero. Upgrade the chart and both
images together:

```bash
helm upgrade "$RELEASE" "$CHART" \
  --version 2.0.0 \
  --namespace "$NAMESPACE" \
  -f "$VALUES_V2" \
  --wait \
  --timeout 15m
```

Migration ownership depends on tenancy:

- **Single-tenant:** keep `bankTransfer.migrations.enabled=true`. The chart runs
  the `2.0.0` migrations image before an external PostgreSQL rollout. Verify the
  Job succeeded.
- **Multi-tenant:** set `bankTransfer.migrations.enabled=false`. The chart
  rejects migrations in MT mode because tenant-manager owns each tenant
  database. Run the approved tenant-manager migration flow for every tenant
  before starting the application.

Verify every database:

```sql
SELECT version, dirty FROM schema_migrations;
```

For v2.0.0 the result must be `version = 28` and `dirty = false`. Run `VACUUM
ANALYZE transfers;` after migration `000023`, because it rewrites existing
inbound TED rows. Do not start v2 with a tenant below the required schema.

### Step 6: Start and verify v2

Restore the desired replicas or HPA only after migrations are verified:

```bash
helm upgrade "$RELEASE" "$CHART" \
  --version 2.0.0 \
  --namespace "$NAMESPACE" \
  -f "$VALUES_V2" \
  --wait \
  --timeout 15m

kubectl -n "$NAMESPACE" rollout status \
  deployment/"$RELEASE" \
  --timeout=10m
```

Confirm the running image is exactly `2.0.0`, readiness passes, tenant schemas
are visible to the poller, and no v1 ReplicaSet has live pods. Then resume
intake.

When streaming is enabled:

- `GET /streaming/manifest` must report topic
  `lerian.streaming.plugin-br-bank-transfer`, DLQ topic
  `lerian.streaming.plugin-br-bank-transfer.dlq`, no commands topic, and source
  `plugin-br-bank-transfer`.
- The outbox query must return to `0` after the first dispatch interval.
- Consumers must subscribe to the single application topic and dispatch on
  `ce-resourcetype` / `ce-eventtype`; the old per-event topics receive nothing.

## Fresh installs

Latest stable v1:

```bash
helm upgrade --install "$RELEASE" "$CHART" \
  --version 1.5.0 \
  --namespace "$NAMESPACE" \
  --create-namespace \
  -f "$VALUES_V1" \
  --wait \
  --timeout 15m
```

Latest stable v2, on a fresh database with no old binaries or outbox rows:

```bash
helm upgrade --install "$RELEASE" "$CHART" \
  --version 2.0.0 \
  --namespace "$NAMESPACE" \
  --create-namespace \
  -f "$VALUES_V2" \
  --wait \
  --timeout 15m
```

Do not mix chart `1.5.0` with application `2.0.0`.

## GitOps and ArgoCD sequence

Use three independently verifiable changes; do not collapse them into one sync:

1. **Stop v1:** keep chart `1.5.0` and images `1.2.1`; disable HPA and set
   replicas to zero. Sync and verify no pod remains.
2. **Migrate at zero:** bump chart and both images to `2.0.0`; keep HPA disabled
   and replicas at zero. Sync, verify hooks/Jobs, and verify every tenant schema.
3. **Start v2:** restore replicas/HPA. Sync, verify readiness, outbox, streaming
   manifest, and money-path telemetry; only then resume intake.

An automated image-tag bump is insufficient because this migration also changes
the chart version, values contract, scaling state, and migration ownership.

## Rollback

Do not use an ordinary `helm rollback` while v2 is serving traffic. Rollback has
the same zero-overlap boundary:

1. Quiesce all emitters.
2. Drain v2 outbox rows to zero with v2 still running.
3. Disable HPA, scale v2 to zero, and verify no v2 pod remains.
4. Re-run the outbox query; it must remain zero everywhere.
5. Restore the v1 values, including the previous CloudEvents source, chart
   `1.5.0`, and both image tags `1.2.1`.
6. Start only v1 pods, verify readiness and business flows, then resume intake.

Do not run down migrations as part of an automatic rollback. Preserve the
database backup and make an explicit data decision if schema reversal is ever
required.

## Verification checklist

- [ ] Chart is exactly `1.5.0` + app/migrations `1.2.1`, or chart/app/migrations
      are all exactly `2.0.0`.
- [ ] Rendered manifests contain the intended namespace, images, ConfigMap keys,
      Secret refs, and topology.
- [ ] HPA is disabled during the zero-replica boundary.
- [ ] No v1 and v2 pods overlap in either upgrade or rollback direction.
- [ ] Outbox is zero in every database before crossing the version boundary.
- [ ] Every v2 database reports schema `28`, `dirty=false`.
- [ ] v2 readiness and rollout succeed before intake resumes.
- [ ] Streaming manifest, topic/ACL consumers, webhook fanout, and outbox drain
      are verified when streaming is enabled.
- [ ] Rollback values and database backup are available before the window begins.
