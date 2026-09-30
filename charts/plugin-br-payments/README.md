# plugin-br-payments-helm

## Chart Contract

- Chart type: `single-service`
- Required secrets: `app.secrets.PROVIDER_CLIENT_ID`, `PROVIDER_CLIENT_SECRET`, `INTERNAL_API_KEY`, and `CREDENTIAL_ENCRYPTION_KEY` for the default worker-enabled render. The `PROVIDER_CLIENT_*` pair is required in **single-tenant only**; in multi-tenant it is resolved per tenant and must be left empty. With the bundled PostgreSQL subchart the database password is auto-generated and read via `secretKeyRef` — only supply `POSTGRES_PASSWORD` for an external Postgres without `postgresql.auth.existingSecret`.
- Dependency notes: Uses a local PostgreSQL dependency chart unless external PostgreSQL is configured.
- Production overrides: Provide provider and database credentials through chart secrets or an existing Secret where supported; override BTG/Midaz URLs, image tags, ingress, resources, and persistence.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

A Helm chart for [plugin-br-payments](https://github.com/LerianStudio/plugin-br-payments) — Lerian Studio's plugin for Brazilian payment operations: boleto issuance, bill payments (bankslip, utilities, DARF), settlement via webhooks, and periodic reconciliation.

## TL;DR

```bash
helm repo add lerian https://lerianstudio.github.io/helm
helm install my-payments lerian/plugin-br-payments-helm \
  --namespace midaz-plugins --create-namespace \
  -f values-prod.yaml
```

## Prerequisites

- Kubernetes 1.23+
- Helm 3.10+
- Either:
  - the in-cluster PostgreSQL subchart (default, `postgresql.enabled=true`), or
  - an externally managed PostgreSQL 16+ instance.
- A reachable `plugin-auth` (lib-auth) deployment when `PLUGIN_AUTH_ENABLED=true`.
- A reachable Midaz onboarding/transaction stack.
- A configured Brazilian payment provider (BTG is the first supported adapter).

## Architecture

The chart deploys **one Deployment, one process** (`/app` with `SERVICE_TYPE=both`):

- HTTP API (boletos, payments, DARF, webhooks, dashboards)
- Reconciliation worker (in-process goroutine, period: `RECONCILIATION_INTERVAL`)
- Outbox dispatcher (in-process goroutine, polls every `OUTBOX_DISPATCH_INTERVAL_SEC`)
- Webhook delivery (in-process)

There is **no separate worker Deployment** — all background work runs inside the API pod. The Dockerfile also ships a standalone `/worker` binary for split deployments, but the chart does not use it; the unified `SERVICE_TYPE=both` mode is the operational model agreed with the plugin team.

## Storage

The plugin uses **PostgreSQL only**:
- Idempotency is stored in PostgreSQL (no Redis — see ADR-003 in the plugin repo).
- Async events use the **outbox pattern** with PostgreSQL (no message broker — ADR-002).

## Required configuration

The chart **fails fast** on `helm install` if any of the following are missing:

| Field | Description |
|-------|-------------|
| `app.configmap.BTG_API_BASE_URL` | BTG API base URL. |
| `app.configmap.BTG_AUTH_URL` | BTG OAuth2 token URL. |
| `app.configmap.MIDAZ_LEDGER_URL` | Midaz Ledger service URL: one URL serves onboarding and transaction. The former `MIDAZ_ONBOARDING_URL` / `MIDAZ_TRANSACTION_URL` pair is refused at render with the rename named. |
| `app.secrets.PROVIDER_CLIENT_ID` | Provider OAuth2 client ID. **Single-tenant only** — in multi-tenant it is resolved per tenant and must be left empty. Named for the role rather than the vendor; renamed from `BTG_CLIENT_ID`. |
| `app.secrets.PROVIDER_CLIENT_SECRET` | Provider OAuth2 client secret. Same conditionality as above; renamed from `BTG_CLIENT_SECRET`. |
| `app.secrets.INTERNAL_API_KEY` | At least 32 characters. Required when `SERVICE_TYPE` includes worker (default `both`). Generate with `openssl rand -hex 32`. |
| `app.secrets.CREDENTIAL_ENCRYPTION_KEY` | Base64-encoded AES-256 key. Required when `SERVICE_TYPE` includes worker. Generate with `openssl rand -base64 32`. |

When `app.configmap.MULTI_TENANT_ENABLED=true`, the `PROVIDER_CLIENT_*` pair above stops being required — the app resolves it per tenant — and the following are additionally required:

| Field | Description |
|-------|-------------|
| `app.configmap.MULTI_TENANT_URL` | Tenant Manager service URL (or env-wide `global.multiTenant.url`). |
| `app.secrets.MULTI_TENANT_SERVICE_API_KEY` | Tenant Manager service API key. |
| `app.configmap.MULTI_TENANT_CREDENTIAL_SOURCE` | Must be `"vault"` — the only accepted value. The app fails closed at boot for any other value (empty, a typo, or the retired `"tenant_manager"` spelling). |
| `app.configmap.AWS_REGION` | Standard AWS SDK region variable, read directly by the AWS SDK when building the Secrets Manager client for the per-tenant integrations bundle. |

> **Database password:** with the bundled PostgreSQL subchart (default), the password is auto-generated into the subchart's own Secret and read by the app via `secretKeyRef` — leave `app.secrets.POSTGRES_PASSWORD` empty. Only set it for an external Postgres that has no `postgresql.auth.existingSecret`.

## Upgrading to the template-owned configuration

The ConfigMap and Secret no longer echo every key of `app.configmap` / `app.secrets`:
they render the application contract listed in [Configuration keys](#configuration-keys),
and the render **fails** on a key the application renamed or stopped reading, naming the fix.
Before upgrading, in your overlay:

1. **Rename** `BTG_CLIENT_ID` / `BTG_CLIENT_SECRET` to `PROVIDER_CLIENT_ID` /
   `PROVIDER_CLIENT_SECRET`, `BTG_WEBHOOK_SECRET` to `BTG_WEBHOOK_HMAC_SECRET`,
   `MIDAZ_ONBOARDING_URL` + `MIDAZ_TRANSACTION_URL` to one `MIDAZ_LEDGER_URL`, and the
   deprecated multi-tenant names (`MULTI_TENANCY_ENABLED`, `MULTI_TENANT_MANAGER_URL`,
   `MULTI_TENANT_CLIENT_TIMEOUT_SEC`, `MULTI_TENANT_CACHE_TTL_MINUTES` in minutes to
   `MULTI_TENANT_CACHE_TTL_SEC` in seconds, `MULTI_TENANT_CB_*`) to their canonical names.
2. **Remove** keys the application no longer reads: `OUTBOX_ENABLED`, `OUTBOX_TABLE_NAME`,
   `CIRCUIT_BREAKER_ENABLED`, `RATE_LIMIT_READ`, `RATE_LIMIT_WRITE`,
   `RECONCILIATION_LOOKBACK_HOURS`, `RECONCILIATION_MAX_PROVIDER_PAGES`, `TRUSTED_PROXIES`,
   `EXAMPLE_STATUS_PROVIDER_MODE`.
3. **Drop the `null` workarounds** for `OUTBOX_PUBLISH_MAX_ATTEMPTS`,
   `OUTBOX_RETRY_WINDOW_SEC`, `OUTBOX_PROCESSING_TIMEOUT_SEC` and `RECONCILIATION_INTERVAL`:
   the chart no longer ships defaults for them, so the application applies its own. A
   `null` still works (it counts as unset).
4. **Multi-tenant**: `MULTI_TENANT_CREDENTIAL_SOURCE` defaults to `"vault"`, the only value
   the application accepts; `AWS_REGION` is required.

Optionally move connection endpoints to the `global:` block (see `values-template.yaml`);
native `app.configmap.<KEY>` values keep working and win over it. Pods now roll on a
ConfigMap or Secret change (`checksum/*` annotations), so a `restartedAt` annotation bump
is no longer needed.

## Configuration keys

The ConfigMap and Secret are **template-owned**: they render exactly the keys below (the
application v1.0.0-beta.163 contract), and `values.schema.json` refuses any other key under
`app.configmap` / `app.secrets`. Set `app.configmap.<KEY>` to override a key; a key marked
*unset* is rendered only when you set it, so the application default applies otherwise. A
`null` counts as unset. Connection endpoints resolve through the lerian-common masks, native
key first: `app.configmap.<KEY>` > `datastores.*` > `global.datastores.*` > `global.cloud`
preset > chart default. `app.extraEnvVars` stays a verbatim escape hatch.

<details><summary><b>APPLICATION</b></summary>

| Key | Default |
|-----|---------|
| `ENV_NAME` | `global.env.name`, else `"production"` |
| `LOG_LEVEL` | `"info"` |
| `DEPLOYMENT_MODE` | `"saas"` |
| `SERVICE_TYPE` | `"both"` |
| `SWAGGER_ENABLED` | `"false"` |
| `VERSION` | the image tag |
| `ALLOW_INSECURE_TLS` | `"true"` |

</details>

<details><summary><b>HTTP SERVER</b></summary>

| Key | Default |
|-----|---------|
| `SERVER_ADDRESS` | `"0.0.0.0:8080"` |
| `HTTP_BODY_LIMIT_BYTES` | `"104857600"` |
| `HTTP_READ_BUFFER_SIZE` | unset (app default) |
| `TLS_TERMINATED_UPSTREAM` | `"true"` |
| `SERVER_TLS_CERT_FILE` | unset (app default) |
| `SERVER_TLS_KEY_FILE` | unset (app default) |
| `INTERNAL_WORKER_URL` | `""` |

</details>

<details><summary><b>CORS</b></summary>

| Key | Default |
|-----|---------|
| `ACCESS_CONTROL_ALLOW_ORIGIN` | `"*"` |
| `ACCESS_CONTROL_ALLOW_METHODS` | `"GET,POST,PUT,PATCH,DELETE,OPTIONS"` |
| `ACCESS_CONTROL_ALLOW_HEADERS` | `"Origin,Content-Type,Accept,Authorization,X-Request-ID"` |
| `ACCESS_CONTROL_EXPOSE_HEADERS` | `""` |
| `ACCESS_CONTROL_ALLOW_CREDENTIALS` | `"false"` |

</details>

<details><summary><b>RATE LIMITING</b></summary>

| Key | Default |
|-----|---------|
| `RATE_LIMIT_ENABLED` | `"true"` |
| `RATE_LIMIT_MAX` | `"500"` |
| `RATE_LIMIT_WINDOW_SEC` | `"60"` |
| `AGGRESSIVE_RATE_LIMIT_MAX` | `"100"` |
| `AGGRESSIVE_RATE_LIMIT_WINDOW_SEC` | `"60"` |
| `RELAXED_RATE_LIMIT_MAX` | `"1000"` |
| `RELAXED_RATE_LIMIT_WINDOW_SEC` | `"60"` |

</details>

<details><summary><b>MULTI-TENANCY</b></summary>

| Key | Default |
|-----|---------|
| `MULTI_TENANT_ENABLED` | `global.multiTenant.enabled`, else unset |
| `MULTI_TENANT_URL` | `global.multiTenant.url`, else `""` |
| `MULTI_TENANT_SERVICE_NAME` | `"plugin-br-payments"` |
| `MULTI_TENANT_POSTGRES_MODULE` | `""` |
| `MULTI_TENANT_ALLOW_INSECURE_HTTP` | `"false"` |
| `MULTI_TENANT_TIMEOUT` | `"10"` |
| `MULTI_TENANT_CACHE_TTL_SEC` | `"3600"` |
| `MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD` | `"5"` |
| `MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC` | `"30"` |
| `MULTI_TENANT_MAX_TENANT_POOLS` | `"100"` |
| `MULTI_TENANT_CREDENTIAL_SOURCE` | `"vault"` |
| `MULTI_TENANT_DISCOVERY_INTERVAL_SEC` | unset (app default) |
| `MULTI_TENANT_IDLE_TIMEOUT_SEC` | unset (app default) |
| `AWS_REGION` | unset (app default) |

</details>

<details><summary><b>POSTGRESQL</b></summary>

| Key | Default |
|-----|---------|
| `POSTGRES_HOST` | `datastores` / `global.datastores` `postgres.host`, else the bundled subchart |
| `POSTGRES_PORT` | `postgres.port` mask, else `"5432"` |
| `POSTGRES_USER` | `postgres.user` mask, else `"plugin_br_payments"` |
| `POSTGRES_DB` | `postgres.name` mask, else `"plugin_br_payments"` |
| `POSTGRES_SSLMODE` | `postgres.ssl` mask, else `"require"` |
| `POSTGRES_MAX_IDLE_CONNS` | `"15"` |
| `POSTGRES_MAX_OPEN_CONNS` | `"25"` |
| `POSTGRES_CONN_MAX_LIFETIME_MINS` | `"30"` |
| `POSTGRES_CONN_MAX_IDLE_TIME_MINS` | `"5"` |
| `POSTGRES_CONNECT_TIMEOUT_SEC` | `"10"` |
| `POSTGRES_REPLICA_HOST` | `postgres.replicaHost` mask, else unset |
| `POSTGRES_REPLICA_PORT` | unset (app default) |
| `POSTGRES_REPLICA_USER` | unset (app default) |
| `POSTGRES_REPLICA_DB` | unset (app default) |
| `POSTGRES_REPLICA_SSLMODE` | unset (app default) |
| `INFRA_CONNECT_TIMEOUT_SEC` | `"30"` |
| `MIGRATION_TIMEOUT_SEC` | `"300"` |
| `MIGRATION_LOCK_TIMEOUT_MS` | `"10000"` |
| `DB_METRICS_INTERVAL_SEC` | `"15"` |
| `IDEMPOTENCY_RECORD_TTL_HOURS` | `"48"` |

</details>

<details><summary><b>OUTBOX</b></summary>

| Key | Default |
|-----|---------|
| `OUTBOX_DISPATCH_INTERVAL_SEC` | `"2"` |
| `OUTBOX_BATCH_SIZE` | `"50"` |
| `OUTBOX_PUBLISH_BACKOFF_MS` | `"200"` |
| `OUTBOX_MAX_DISPATCH_ATTEMPTS` | `"10"` |
| `OUTBOX_MAX_FAILED_PER_BATCH` | `"25"` |
| `OUTBOX_INCLUDE_TENANT_METRICS` | `"false"` |
| `OUTBOX_ALLOW_EMPTY_TENANT` | `"true"` |
| `OUTBOX_PRIORITY_EVENT_TYPES` | unset (app default) |
| `OUTBOX_PUBLISH_MAX_ATTEMPTS` | unset (app default) |
| `OUTBOX_RETRY_WINDOW_SEC` | unset (app default) |
| `OUTBOX_PROCESSING_TIMEOUT_SEC` | unset (app default) |

</details>

<details><summary><b>AUTHENTICATION (plugin-access-manager)</b></summary>

| Key | Default |
|-----|---------|
| `PLUGIN_AUTH_ENABLED` | `global.auth.enabled`, else `"true"` |
| `PLUGIN_AUTH_ADDRESS` | `global.auth.host`, else the in-cluster plugin-access-manager |

</details>

<details><summary><b>PROVIDER (BTG)</b></summary>

| Key | Default |
|-----|---------|
| `BTG_API_BASE_URL` | `""` |
| `BTG_AUTH_URL` | `""` |
| `BTG_COMMON_BASE_URL` | `""` |
| `BTG_TOKEN_REFRESH_INTERVAL` | `"4m"` |
| `BTG_HTTP_TIMEOUT` | unset (app default) |
| `BTG_CREDENTIAL_SYNC_INTERVAL` | unset (app default) |
| `PROVIDER_CREDENTIAL_CLAIM_LEASE` | unset (app default) |
| `BTG_MTLS_OUTBOUND_ENABLED` | unset (app default) |
| `BTG_MTLS_OUTBOUND_CERT_FILE` | unset (app default) |
| `BTG_MTLS_OUTBOUND_KEY_FILE` | unset (app default) |
| `BTG_MTLS_OUTBOUND_CA_FILE` | unset (app default) |
| `BTG_MTLS_INBOUND_ENABLED` | unset (app default) |
| `BTG_MTLS_INBOUND_CERT_HEADER` | unset (app default) |
| `BTG_WEBHOOK_CERTIFICATE_URL` | unset (app default) |

</details>

<details><summary><b>MIDAZ</b></summary>

| Key | Default |
|-----|---------|
| `MIDAZ_LEDGER_URL` | `""` |
| `MIDAZ_CRM_URL` | unset (app default) |
| `MIDAZ_AUTH_ENABLED` | unset (app default) |
| `MIDAZ_ALLOW_INSECURE_HTTP` | unset (app default) |
| `MIDAZ_DEFAULT_ORG_ID` | unset (app default) |
| `MIDAZ_DEFAULT_LEDGER_ID` | unset (app default) |
| `M2M_CRM_TARGET_SERVICE` | unset (app default) |
| `ORGANIZATION_IDS` | unset (app default) |
| `ACCOUNT_VALIDATION_DISABLED` | unset (app default) |
| `ACCOUNTING_ROUTES_ENABLED` | unset (app default) |
| `ACCOUNTING_ROUTES_CACHE_TTL_SEC` | unset (app default) |
| `ACCOUNTING_ROUTES_FETCH_TIMEOUT_SEC` | unset (app default) |

</details>

<details><summary><b>RECONCILIATION</b></summary>

| Key | Default |
|-----|---------|
| `RECONCILIATION_INTERVAL` | unset (app default) |
| `RECONCILIATION_DELAY_MS` | unset (app default) |
| `RECONCILIATION_MAX_BOLETOS_PER_CYCLE` | unset (app default) |
| `RECONCILIATION_MAX_MONEY_ITEMS_PER_CYCLE` | unset (app default) |
| `RECONCILIATION_BOLETO_GRACE_PERIOD` | unset (app default) |
| `RECONCILIATION_PAYMENT_GRACE_PERIOD` | unset (app default) |
| `RECONCILIATION_WEBHOOK_CLAIM_LEASE` | unset (app default) |
| `RECONCILIATION_WEBHOOK_SILENCE_WINDOW` | unset (app default) |

</details>

<details><summary><b>WEBHOOKS</b></summary>

| Key | Default |
|-----|---------|
| `WEBHOOK_PUBLIC_BASE_URL` | unset (app default) |
| `WEBHOOK_SKIP_URL_VALIDATION` | unset (app default) |
| `WEBHOOK_CONNECTION_GRACE_WINDOW_SEC` | unset (app default) |
| `WEBHOOK_DISPATCHER_INTERVAL` | unset (app default) |
| `WEBHOOK_DISPATCHER_BATCH_SIZE` | unset (app default) |
| `WEBHOOK_DISPATCHER_CLAIM_LEASE` | unset (app default) |
| `WEBHOOK_CONSUMER_INTERVAL` | unset (app default) |

</details>

<details><summary><b>TELEMETRY</b></summary>

| Key | Default |
|-----|---------|
| `ENABLE_TELEMETRY` | `global.observability.enabled`, else `"true"` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `global.observability.otlpEndpoint`, else `""` |
| `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `global.observability.deploymentEnvironment`, else `"production"` |
| `OTEL_LIBRARY_NAME` | `"github.com/LerianStudio/plugin-br-payments"` |
| `OTEL_RESOURCE_SERVICE_NAME` | `"plugin-br-payments"` |
| `OTEL_RESOURCE_SERVICE_VERSION` | the image tag |

</details>

**Secret keys** (`app.secrets`, each rendered only when set): `POSTGRES_PASSWORD`, `POSTGRES_REPLICA_PASSWORD`, `PROVIDER_CLIENT_ID`, `PROVIDER_CLIENT_SECRET`, `BTG_WEBHOOK_HMAC_SECRET`, `INTERNAL_API_KEY`, `INTERNAL_API_KEY_PREVIOUS`, `CREDENTIAL_ENCRYPTION_KEY`, `CREDENTIAL_ENCRYPTION_KEY_PREVIOUS`, `LICENSE_KEY`, `PLUGIN_AUTH_CLIENT_ID`, `PLUGIN_AUTH_CLIENT_SECRET`, `MULTI_TENANT_SERVICE_API_KEY`.

**Refused at render**, with the replacement named: `MULTI_TENANCY_ENABLED`, `MULTI_TENANT_MANAGER_URL`, `MULTI_TENANT_CLIENT_TIMEOUT_SEC`, `MULTI_TENANT_CACHE_TTL_MINUTES`, `MULTI_TENANT_CB_THRESHOLD`, `MULTI_TENANT_CB_TIMEOUT_SEC`, `MIDAZ_ONBOARDING_URL`, `MIDAZ_TRANSACTION_URL`, `OUTBOX_ENABLED`, `OUTBOX_TABLE_NAME`, `CIRCUIT_BREAKER_ENABLED`, `RATE_LIMIT_READ`, `RATE_LIMIT_WRITE`, `RECONCILIATION_LOOKBACK_HOURS`, `EXAMPLE_STATUS_PROVIDER_MODE`, `RECONCILIATION_MAX_PROVIDER_PAGES`, `TRUSTED_PROXIES` (`app.configmap`); `BTG_CLIENT_ID`, `BTG_CLIENT_SECRET`, `BTG_WEBHOOK_SECRET` (`app.secrets`). The retired ones are no longer read by the application.

## Probes

| Probe | Path | Notes |
|-------|------|-------|
| Liveness | `/health` | Lightweight startup self-probe. Returns 200 once startup completes. |
| Readiness | `/readyz` | Deep per-dependency checks (Postgres, Provider, Midaz, Tenant Manager). Returns 503 if any dep is `down`/`degraded`. |
| Tenant readiness | `/readyz/tenant/:id` | Mounted only when `MULTI_TENANT_ENABLED=true`. Anti-enumeration uniform shape. |

Default probe values match the canonical Lerian readiness contract documented in [`plugin-br-payments/docs/readyz-guide.md`](https://github.com/LerianStudio/plugin-br-payments/blob/main/docs/readyz-guide.md):

```yaml
readinessProbe:
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
livenessProbe:
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

`terminationGracePeriodSeconds` is set to **60** to match the service's drain + shutdown budget. Setting it lower will cause `SIGKILL` mid-shutdown.

## Multi-tenancy

The plugin supports schema-per-tenant via Lerian's Tenant Manager. To enable:

```yaml
app:
  configmap:
    MULTI_TENANT_ENABLED: "true"
    MULTI_TENANT_URL: "https://tenant-manager.example.com"
    MULTI_TENANT_SERVICE_NAME: "plugin-br-payments"
    MULTI_TENANT_CREDENTIAL_SOURCE: "vault"
    AWS_REGION: "<aws-region>"
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "<api key>"
```

When enabled, `/readyz/tenant/:id` becomes available and `/readyz` reports `provider:n/a` globally (use the per-tenant probe instead). Do not set `app.secrets.BTG_CLIENT_ID` or `app.secrets.BTG_CLIENT_SECRET`; the application resolves those credentials from each tenant's control-plane record.

### AWS credentials for Secrets Manager (`aws.rolesAnywhere`)

Multi-tenant mode with `MULTI_TENANT_CREDENTIAL_SOURCE: "vault"` calls AWS Secrets
Manager to read each tenant's integrations bundle. On a cluster that already runs on
AWS (IRSA), the pod gets credentials for free. On a **non-AWS cluster** (on-prem,
Proxmox, another cloud) there is no such mechanism, so enable IAM Roles Anywhere: an
`aws-signing-helper` sidecar exchanges an X.509 client certificate for temporary AWS
credentials and serves them on a local metadata endpoint the app reads via the
standard AWS SDK credential chain.

```yaml
aws:
  rolesAnywhere:
    enabled: true
    trustAnchorArn: "arn:aws:rolesanywhere:<region>:<account>:trust-anchor/<id>"
    profileArn: "arn:aws:rolesanywhere:<region>:<account>:profile/<id>"
    roleArn: "arn:aws:iam::<account>:role/<role>"
    region: "<region>"  # MUST match the region trustAnchorArn/profileArn were created in — Roles Anywhere resources are regional; defaults to us-east-2
    certificateSecretName: "plugin-br-payments-iam-tls"  # cert-manager Secret the sidecar mounts
```

`trustAnchorArn`, `profileArn`, and `roleArn` are required once `enabled: true` — the
render fails closed otherwise. The `certificateSecretName` Secret (containing
`tls.crt`/`tls.key`) is provisioned by the GitOps deploy layer as a cert-manager
`Certificate`, not by this chart; see the Roles Anywhere deploy docs for that half.
Off by default — zero cost when unset.

## Accounting routes

The accounting-route resolver attaches a `routeId` to the plugin's Midaz transactions by resolving the tenant's operation and transaction routes. The chart sets none of its keys: the app owns their defaults, and omitted, the resolver stays **off**, which is the behaviour the plugin had before the feature existed.

| Key | App default | Meaning |
|---|---|---|
| `ACCOUNTING_ROUTES_ENABLED` | `false` | Gates the resolver as a whole. |
| `ACCOUNTING_ROUTES_CACHE_TTL_SEC` | `900` | Per-tenant route inventory cache TTL, in seconds; `<= 0` disables the cache. |
| `ACCOUNTING_ROUTES_FETCH_TIMEOUT_SEC` | `60` | Budget for one full route resolution, in seconds; `<= 0` falls back to the default. |
| `RECONCILIATION_WEBHOOK_CLAIM_LEASE` | `2h` | How long one replica's claim on a webhook row stays exclusive. |

Turn it on per environment, one deployment at a time, after the per-tenant credentials exist — a tenant whose credential is not provisioned yet is taken down, not degraded, by the first request that reaches the resolver:

```yaml
app:
  extraEnvVars:
    ACCOUNTING_ROUTES_ENABLED: "true"
```

If you also disable the routes cache (`ACCOUNTING_ROUTES_CACHE_TTL_SEC` `<= 0`), raise `RECONCILIATION_WEBHOOK_CLAIM_LEASE` first, to at least `RECONCILIATION_MAX_MONEY_ITEMS_PER_CYCLE x (65s + ACCOUNTING_ROUTES_FETCH_TIMEOUT_SEC)` — `3h30m` at the defaults. The lease is a fencing token's lifetime, not a timeout: shorter than the batch it covers, it lets a second replica take rows the first is still working. The full rollout sequence is the plugin's accounting-routes runbook.

## Common values

| Key | Default | Description |
|-----|---------|-------------|
| `app.replicaCount` | `2` | Number of replicas. |
| `app.image.repository` | `ghcr.io/lerianstudio/plugin-br-payments` | Container image. |
| `app.image.tag` | `""` (Chart `appVersion`) | Image tag. |
| `app.service.port` | `8080` | Service port. |
| `app.ingress.enabled` | `false` | Expose via Ingress. |
| `app.autoscaling.enabled` | `true` | Enable HPA. |
| `app.terminationGracePeriodSeconds` | `60` | Required by the readyz contract. |
| `app.configmap.SERVICE_TYPE` | `both` | Run API + worker in one process. |
| `app.configmap.MULTI_TENANT_ENABLED` | unset (app default `false`) | Toggle multi-tenant mode; env-wide via `global.multiTenant.enabled`. The deprecated `MULTI_TENANCY_ENABLED` is refused at render with the rename named. |
| `app.controlplaneMigrations.enabled` | `false` | Enable the control-plane migrations `PreSync` Job. Renders with `MULTI_TENANT_ENABLED=true` and the bundled PostgreSQL disabled; it does not require database bootstrap. |
| `app.controlplaneMigrations.resources` | requests `50m`/`64Mi`, limits `250m`/`256Mi` | Resources for the control-plane migrations Job. |
| `postgresql.enabled` | `true` | Deploy the in-cluster PostgreSQL subchart. |
| `postgresql.architecture` | `replication` | Primary + read replica. |
| `global.externalPostgresDefinitions.enabled` | `false` | Run a bootstrap Job against an external PostgreSQL. |
| `otel-collector-lerian.enabled` | `false` | Inject host-level OTLP endpoint env vars. |
| `aws.rolesAnywhere.enabled` | `false` | Enable the `aws-signing-helper` sidecar for AWS credentials on non-AWS clusters. |

See [`values.yaml`](./values.yaml) for the full list, and [`values-template.yaml`](./values-template.yaml) for a production-ready overlay starter.

## Production layout

In production, you typically:

1. **Disable the in-cluster PostgreSQL** and point at a managed service.
   `app.configmap.POSTGRES_HOST`/`POSTGRES_PORT` is the single source the
   app Deployment, the control-plane migrations Job, and the bootstrap Job
   all read to reach Postgres — set it to your real external host/port.
   `global.externalPostgresDefinitions.connection.host`/`.port` is no longer
   read by any template (kept only for backward compatibility with older
   overlays) — you do not need to set it, and setting it to a different
   value than `app.configmap.POSTGRES_HOST`/`.PORT` has no effect on where
   the bootstrap Job connects:
   ```yaml
   postgresql:
     enabled: false

   app:
     configmap:
       POSTGRES_HOST: my-rds-instance.example.com
       POSTGRES_PORT: "5432"
       POSTGRES_SSLMODE: require
   ```

2. **Use existing secrets** instead of inline values:
   ```yaml
   app:
     useExistingSecret: true
     existingSecretName: plugin-br-payments-secrets
   ```

3. **Optional bootstrap** for a fresh external Postgres (creates DB + role + grants, idempotent).
   It connects to the same `app.configmap.POSTGRES_HOST`/`POSTGRES_PORT` set in
   step 1 above — only the admin credentials it needs to create the role and
   database are configured here:
   ```yaml
   global:
     externalPostgresDefinitions:
       enabled: true
       postgresAdminLogin:
         username: postgres
         password: <admin password>
       paymentsCredentials:
         password: <plugin_br_payments role password>
   ```

4. **Enable control-plane migrations** for multi-tenant deployments after the
   external database already exists:
   ```yaml
   app:
     controlplaneMigrations:
       enabled: true
   ```
   This runs `/controlplane-migrate` as a `PreSync`/pre-upgrade Job against
   `app.configmap.POSTGRES_*`. It is independent of
   `global.externalPostgresDefinitions.enabled`; keep the bootstrap flag off
   when the database and role are already provisioned.

## Uninstall

```bash
helm uninstall my-payments -n midaz-plugins
```

If `postgresql.enabled=true` was used, the PVCs are NOT deleted automatically. Remove them manually if no longer needed:

```bash
kubectl delete pvc -n midaz-plugins -l app.kubernetes.io/instance=my-payments
```

## License

[Apache 2.0](../../LICENSE) (chart). The `plugin-br-payments` application itself is licensed under the [Elastic License 2.0](https://github.com/LerianStudio/plugin-br-payments/blob/main/LICENSE.md).
