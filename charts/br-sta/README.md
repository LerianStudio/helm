# br-sta-helm

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `None for default render`. With the bundled PostgreSQL and Valkey subcharts the database and Redis passwords are auto-generated and read via `secretKeyRef`. Only supply `br-sta.secrets.POSTGRES_PASSWORD` / `br-sta.secrets.REDIS_PASSWORD` for external infra without `postgresql.auth.existingSecret` / `valkey.auth.existingSecret`. `br-sta.secrets.MULTI_TENANT_SERVICE_API_KEY` is required only when `MULTI_TENANT_ENABLED=true`.
- Dependency notes: Bundles two local subcharts — Bitnami `postgresql` (`postgresql.enabled`, default `true`) and Bitnami `valkey` (`valkey.enabled`, default `true`). RabbitMQ is optional, config-only, and NOT bundled (`RABBITMQ_ENABLED=false`). All can be pointed at external services.
- Production overrides: Disable the bundled subcharts and point `POSTGRES_HOST` / `REDIS_HOST` at managed services; supply credentials via chart secrets or an existing Secret; override image tag, ingress, resources, and persistence.
- Source/license: Source is in `github.com/LerianStudio/br-sta`; chart license is Apache-2.0.

A Helm chart for [br-sta](https://github.com/LerianStudio/br-sta) — a Lerian Studio Go/Fiber HTTP service. It ships a manager Deployment running the `/service` binary and an optional worker Deployment running background jobs, backed by PostgreSQL (SQL migrations applied at startup) and Redis/Valkey (caching + rate limiting).

## TL;DR

```bash
helm repo add lerian https://lerianstudio.github.io/helm
helm install my-br-sta lerian/br-sta-helm \
  --namespace br-sta --create-namespace
```

The default render brings up br-sta plus an in-cluster PostgreSQL and Valkey, with no operator-provided secrets required.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.10+
- Either the bundled PostgreSQL/Valkey subcharts (default) or externally managed PostgreSQL 16+ and Redis/Valkey.

## Architecture

The chart deploys a **manager Deployment** (`/service`, a Go/Fiber HTTP server) and an optional **worker Deployment** (`/worker`, background jobs):

- HTTP API served on port `8080` (`/health`, `/api/v1/...`).
- PostgreSQL is the primary datastore; SQL migrations are applied at startup from `MIGRATIONS_PATH` (`migrations`).
- Redis/Valkey provides caching and rate limiting (`REDIS_*`).

### Optional integrations (disabled by default)

| Toggle | Default | Purpose |
|--------|---------|---------|
| `RABBITMQ_ENABLED` | `"false"` | Event-driven starter (config-only; broker not bundled). |
| `OUTBOX_ENABLED` | `"false"` | Transactional outbox dispatcher. |
| `PLUGIN_AUTH_ENABLED` | `"false"` | lib-auth / plugin-auth integration. |
| `MULTI_TENANT_ENABLED` | `"false"` | Multi-tenant mode via tenant-manager. |
| `ENABLE_TELEMETRY` | `"false"` | OpenTelemetry OTLP export. |

## Storage

- **PostgreSQL** — application data + SQL migrations.
- **Redis/Valkey** — cache + rate-limiting counters.

## Single-source infra credentials

Following [`docs/helm-chart-standard.md`](../../docs/helm-chart-standard.md):

- With the bundled **PostgreSQL** subchart (default), the password is auto-generated into the subchart's own Secret and read by the app via `secretKeyRef` (key `password`) — leave `br-sta.secrets.POSTGRES_PASSWORD` empty.
- With the bundled **Valkey** subchart (default), the password is auto-generated into the subchart's own Secret and read via `secretKeyRef` (key `valkey-password`) — leave `br-sta.secrets.REDIS_PASSWORD` empty.
- For external infra (subchart disabled), supply `br-sta.secrets.POSTGRES_PASSWORD` / `br-sta.secrets.REDIS_PASSWORD`, or set `postgresql.auth.existingSecret` / `valkey.auth.existingSecret`.

## Required configuration

The chart **fails fast** on `helm install` only when an enabled optional integration is missing its inputs:

| Field | When required |
|-------|---------------|
| `br-sta.configmap.MULTI_TENANT_URL` | `MULTI_TENANT_ENABLED=true` |
| `br-sta.secrets.MULTI_TENANT_SERVICE_API_KEY` | `MULTI_TENANT_ENABLED=true` |

## Probes

| Probe | Path | Notes |
|-------|------|-------|
| Liveness | `/health` | HTTP self-probe. |
| Readiness | `/health` | br-sta exposes a single `/health` endpoint. |

## Common values

| Key | Default | Description |
|-----|---------|-------------|
| `br-sta.replicaCount` | `2` | Number of replicas. |
| `br-sta.image.repository` | `ghcr.io/lerianstudio/br-sta` | Container image. |
| `br-sta.image.tag` | `""` (Chart `appVersion`) | Image tag. |
| `br-sta.service.port` | `8080` | Service port. |
| `br-sta.ingress.enabled` | `false` | Expose via Ingress. |
| `br-sta.autoscaling.enabled` | `true` | Enable HPA. |
| `postgresql.enabled` | `true` | Deploy the in-cluster PostgreSQL subchart. |
| `postgresql.architecture` | `replication` | Primary + read replica. |
| `valkey.enabled` | `true` | Deploy the in-cluster Valkey subchart. |
| `valkey.architecture` | `standalone` | Single Valkey primary. |
| `global.externalPostgresDefinitions.enabled` | `false` | Run a bootstrap Job against an external PostgreSQL. |
| `otel-collector-lerian.enabled` | `false` | Inject host-level OTLP endpoint env vars. |

See [`values.yaml`](./values.yaml) for the full list, and [`values-template.yaml`](./values-template.yaml) for a production overlay starter.

## Production layout

1. **Disable the bundled infra** and point at managed services:
   ```yaml
   postgresql:
     enabled: false
   valkey:
     enabled: false
   br-sta:
     configmap:
       POSTGRES_HOST: my-rds-instance.example.com
       POSTGRES_SSLMODE: require
       REDIS_HOST: my-redis.example.com:6379
     secrets:
       POSTGRES_PASSWORD: <db password>
       REDIS_PASSWORD: <redis password>
   ```

2. **Use an existing Secret** instead of inline values:
   ```yaml
   br-sta:
     useExistingSecret: true
     existingSecretName: br-sta-secrets
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
       appCredentials:
         password: <br_sta role password>
   ```

## Uninstall

```bash
helm uninstall my-br-sta -n br-sta
```

If the bundled PostgreSQL was used, its PVCs are NOT deleted automatically:

```bash
kubectl delete pvc -n br-sta -l app.kubernetes.io/instance=my-br-sta
```

## License

[Apache 2.0](../../LICENSE) (chart).
