# plugin-br-payments-helm

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
| `app.configmap.OUTBOX_ENABLED` | Must be `"true"`. The plugin only registers HTTP routes when the outbox is enabled. |
| `app.configmap.PROVIDER_API_BASE_URL` | Provider API base URL. |
| `app.configmap.PROVIDER_AUTH_URL` | Provider OAuth2 token URL. |
| `app.configmap.MIDAZ_ONBOARDING_URL` | Midaz onboarding service URL. |
| `app.configmap.MIDAZ_TRANSACTION_URL` | Midaz transaction service URL. |
| `app.secrets.PROVIDER_CLIENT_ID` | Provider OAuth2 client ID. |
| `app.secrets.PROVIDER_CLIENT_SECRET` | Provider OAuth2 client secret. |
| `app.secrets.PROVIDER_WEBHOOK_SECRET` | Bearer token for incoming provider webhooks. |
| `app.secrets.POSTGRES_PASSWORD` | PostgreSQL application password. |
| `app.secrets.INTERNAL_API_KEY` | At least 32 characters. Required when `SERVICE_TYPE` includes worker (default `both`). Generate with `openssl rand -hex 32`. |
| `app.secrets.CREDENTIAL_ENCRYPTION_KEY` | Base64-encoded AES-256 key. Required when `SERVICE_TYPE` includes worker. Generate with `openssl rand -base64 32`. |

When `app.configmap.MULTI_TENANCY_ENABLED=true`, the following are additionally required:

| Field | Description |
|-------|-------------|
| `app.configmap.MULTI_TENANT_MANAGER_URL` | Tenant Manager service URL. |
| `app.secrets.MULTI_TENANT_SERVICE_API_KEY` | Tenant Manager service API key. |

## Probes

| Probe | Path | Notes |
|-------|------|-------|
| Liveness | `/health` | Lightweight startup self-probe. Returns 200 once startup completes. |
| Readiness | `/readyz` | Deep per-dependency checks (Postgres, Provider, Midaz, Tenant Manager). Returns 503 if any dep is `down`/`degraded`. |
| Tenant readiness | `/readyz/tenant/:id` | Mounted only when `MULTI_TENANCY_ENABLED=true`. Anti-enumeration uniform shape. |

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
    MULTI_TENANCY_ENABLED: "true"
    MULTI_TENANT_MANAGER_URL: "https://tenant-manager.example.com"
    MULTI_TENANT_SERVICE_NAME: "plugin-br-payments"
  secrets:
    MULTI_TENANT_SERVICE_API_KEY: "<api key>"
```

When enabled, `/readyz/tenant/:id` becomes available and `/readyz` reports `provider:n/a` globally (use the per-tenant probe instead).

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
| `app.configmap.OUTBOX_ENABLED` | `"true"` | REQUIRED — the plugin won't register routes otherwise. |
| `app.configmap.MULTI_TENANCY_ENABLED` | `"false"` | Toggle multi-tenant mode. |
| `postgresql.enabled` | `true` | Deploy the in-cluster PostgreSQL subchart. |
| `postgresql.architecture` | `replication` | Primary + read replica. |
| `global.externalPostgresDefinitions.enabled` | `false` | Run a bootstrap Job against an external PostgreSQL. |
| `otel-collector-lerian.enabled` | `false` | Inject host-level OTLP endpoint env vars. |

See [`values.yaml`](./values.yaml) for the full list, and [`values-template.yaml`](./values-template.yaml) for a production-ready overlay starter.

## Production layout

In production, you typically:

1. **Disable the in-cluster PostgreSQL** and point at a managed service:
   ```yaml
   postgresql:
     enabled: false

   app:
     configmap:
       POSTGRES_HOST: my-rds-instance.example.com
       POSTGRES_SSLMODE: require
   ```

2. **Use existing secrets** instead of inline values:
   ```yaml
   app:
     useExistingSecret: true
     existingSecretName: plugin-br-payments-secrets
   ```

3. **Optional bootstrap** for a fresh external Postgres (creates DB + role + grants, idempotent):
   ```yaml
   global:
     externalPostgresDefinitions:
       enabled: true
       connection:
         host: my-rds-instance.example.com
         port: "5432"
       postgresAdminLogin:
         username: postgres
         password: <admin password>
       paymentsCredentials:
         password: <plugin_br_payments role password>
   ```

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
