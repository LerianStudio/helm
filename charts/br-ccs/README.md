# br-ccs Helm Chart

Helm chart for **br-ccs** — Lerian's Go service for the BACEN **CCS (Cadastro de
Clientes do Sistema Financeiro Nacional)** regulatory integration. It ingests
customer-relationship data (from Fetcher), computes the daily delta, renders the
BACEN XML layouts, transmits via **STA**, and reconciles the responses, honoring
judicial secrecy (liminares / LC 105) and LGPD.

- Chart name: `br-ccs-helm`
- Chart type: `single-service`
- Source: https://github.com/LerianStudio/br-ccs

## TL;DR

```bash
helm dependency build charts/br-ccs
helm install br-ccs charts/br-ccs \
  --set brCcs.configmap.ENV_NAME=production \
  --set brCcs.secrets.POSTGRES_PASSWORD=... \
  --set brCcs.secrets.REDIS_PASSWORD=... \
  --set brCcs.secrets.CCS_CRYPTO_MASTER_KEY=$(openssl rand -hex 32)
```

## Service topology

| Aspect | Value |
|--------|-------|
| Container port / Service port | `4030` (`SERVER_ADDRESS=:4030`) |
| Service type | `ClusterIP` |
| Run mode | Single Deployment, `CCS_RUN_MODE=all` (API + workers) |
| Liveness probe | `GET /health` |
| Readiness probe | `GET /readyz` (PROJECT_RULES §13.4) |
| Persistence | PostgreSQL (no MongoDB) |
| Messaging | RabbitMQ (optional, disabled by default) |
| Cache / idempotency / rate-limit | Redis / Valkey |

## Dependencies

All bundled subcharts are `.enabled`-gated. For BYOC / production, disable them
and point the app at external infrastructure (see `values-template.yaml`).

| Subchart | Version | Repository |
|----------|---------|------------|
| postgresql | 16.3.5 | https://charts.bitnami.com/bitnami |
| valkey | 2.4.7 | oci://registry-1.docker.io/bitnamicharts |
| rabbitmq | 2.1.11 | https://groundhog2k.github.io/helm-charts |

## Configuration

Non-secret configuration lives under `brCcs.configmap`; credentials and keys
under `brCcs.secrets`. Every variable from the application's
`config/.env.example` is mapped. Optional knobs not modeled explicitly can be
set via `brCcs.extraEnvVars`.

### Required secrets

| Key | Notes |
|-----|-------|
| `POSTGRES_PASSWORD` | Single-sourced from the bundled subchart Secret when `postgresql.enabled=true`; supply here for external Postgres. |
| `REDIS_PASSWORD` | Single-sourced from the bundled valkey Secret when `valkey.enabled=true`; supply here for external Redis. |
| `CCS_CRYPTO_MASTER_KEY` | AES-256-GCM master key, 64 hex chars (`openssl rand -hex 32`). Empty fails fast at boot. |
| `FETCHER_CRYPTO_KEY` | Fetcher snapshot decryption key (base64; same value as Fetcher `APP_ENC_KEY`). |

### Migrations

`brCcs.migrations.enabled=true` (default) runs the dedicated `br-ccs-migrations`
image as a Helm/ArgoCD hook:

- **External Postgres** → PreSync (`pre-install,pre-upgrade`), backed by a
  migration-only Secret carrying just `POSTGRES_PASSWORD`.
- **Bundled Postgres subchart** → PostSync (`post-install,post-upgrade`), reading
  the app Secret after the database is provisioned.

## Security

All containers run non-root (`runAsUser: 1000`, `runAsNonRoot: true`), with
`readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`,
`capabilities.drop: [ALL]`, and `seccompProfile: RuntimeDefault`.

## Validation

```bash
helm lint charts/br-ccs
helm template charts/br-ccs
```
