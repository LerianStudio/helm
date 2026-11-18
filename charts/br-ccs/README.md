# br-ccs Helm Chart

Helm chart for **br-ccs** — Lerian's Go service for the BACEN **CCS (Cadastro de
Clientes do Sistema Financeiro Nacional)** regulatory integration. It ingests
customer-relationship data (from Fetcher), computes the daily delta, renders the
BACEN XML layouts, transmits via **STA**, and reconciles the responses, honoring
judicial secrecy (liminares / LC 105) and LGPD.

- Chart name: `br-ccs-helm`
- Chart type: `single-service`
- Source: https://github.com/LerianStudio/br-ccs

## Chart Contract

- Chart type: `single-service`
- Required secrets: `brCcs.secrets.CCS_CRYPTO_MASTER_KEY` (AES-256-GCM, 64 hex chars — empty fails fast at boot). `POSTGRES_PASSWORD` and `REDIS_PASSWORD` are single-sourced from the bundled `<release>-{postgresql,valkey}` Secrets via `secretKeyRef` when those subcharts are enabled; supply them (or `<subchart>.auth.existingSecret`) for external infra. `FETCHER_CRYPTO_KEY` is optional (empty = passthrough). See `docs/helm-chart-standard.md`.
- Dependency notes: Bundled PostgreSQL and Valkey subcharts are used unless external services are configured; RabbitMQ is optional and disabled by default. No MongoDB.
- Production overrides: Disable the bundled subcharts (`<subchart>.enabled=false`, `.external=true`), set `POSTGRES_HOST`/`REDIS_HOST`, and supply secrets via a secrets manager or `brCcs.useExistingSecret`; override image tags, ingress, resources, and integration endpoints (Fetcher/STA/Reporter).
- Source/license: Source is in `github.com/LerianStudio/helm` and `github.com/LerianStudio/br-ccs`; license is Apache-2.0.

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

| Key | Required | Notes |
|-----|----------|-------|
| `POSTGRES_PASSWORD` | Yes | Single-sourced from the bundled subchart Secret when `postgresql.enabled=true`; supply here for external Postgres. |
| `REDIS_PASSWORD` | Yes | Single-sourced from the bundled valkey Secret when `valkey.enabled=true`; supply here for external Redis. |
| `CCS_CRYPTO_MASTER_KEY` | Yes | AES-256-GCM master key, 64 hex chars (`openssl rand -hex 32`). Empty fails fast at boot. |
| `FETCHER_CRYPTO_KEY` | No | Optional. Empty = passthrough / plaintext (dev/staging); set to the Fetcher `APP_ENC_KEY` to decrypt snapshots. |

### Plaintext OTEL to the node-local collector (`ALLOW_INSECURE_OTEL`)

With `brCcs.configmap.ENABLE_TELEMETRY: "true"`, the pod ships telemetry to the collector on its own node at `$(HOST_IP):4317`, in plaintext (no scheme). lib-observability refuses a plaintext exporter in production unless `ALLOW_INSECURE_OTEL` carries a reason, so the chart sets that variable on the container. The value resolves in this order:

1. `brCcs.configmap.ALLOW_INSECURE_OTEL`
2. `global.observability.allowInsecureOtel`, one value for the whole environment
3. the default reason, `node-local collector on the pod's own node`

`null` counts as unset. An empty string is an explicit refusal, and the app then refuses the plaintext exporter in production. Use `""` to refuse: this app runs lib-observability v1.1.0, which only refuses an empty value, so `"false"` still stops the chart's chain but reaches the app as a reason and lets the plaintext exporter through. The ConfigMap carries the configmap value, or else the global one, so the setting also reaches the app when the node-local hop is off (telemetry enabled through `global.observability.enabled` with an explicit plaintext `otlpEndpoint`).

A key in `brCcs.extraEnvVars` is the legacy route, and the chart then adds no entry of its own. The chart's Secret renders only its own key list, so `brCcs.secrets.ALLOW_INSECURE_OTEL` is not a route. With `useExistingSecret: true` the chart cannot see the Secret, so the container entry overrides any `ALLOW_INSECURE_OTEL` held there; set `brCcs.configmap.ALLOW_INSECURE_OTEL` instead. The chart stays on `lerian-common-helm` 1.4.0 and resolves the value with a chart-local helper (`br-ccs.otel.allowInsecure`) that follows the same order as `lerian-common.otel.allowInsecure` in `lerian-common-helm` 2.7.0.

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
