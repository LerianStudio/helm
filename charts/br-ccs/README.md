# br-ccs Helm Chart

Helm chart for **br-ccs** — Lerian's Go service for the BACEN **CCS (Cadastro de
Clientes do Sistema Financeiro Nacional)** regulatory integration. It ingests
customer-relationship data (from Fetcher), computes the daily delta, renders the
BACEN XML layouts, transmits via **STA**, and reconciles the responses, honoring
judicial secrecy (liminares / LC 105) and LGPD.

- Chart name: `br-ccs-helm`
- Chart type: `single-service`
- Source: https://github.com/LerianStudio/br-sfn (`services/ccs`)

## Chart Contract

- Chart type: `single-service`
- Required secrets: `brCcs.secrets.CCS_CRYPTO_MASTER_KEY` (AES-256-GCM, 64 hex chars), `brCcs.secrets.LICENSE_KEY` and, with auth on (the default), the Reporter and STA M2M client credentials. The chart refuses to render without them (see [Boot contract](#boot-contract)). `POSTGRES_PASSWORD` and `REDIS_PASSWORD` are single-sourced from the bundled `<release>-{postgresql,valkey}` Secrets via `secretKeyRef` when those subcharts are enabled; supply them (or `<subchart>.auth.existingSecret`) for external infra. `FETCHER_CRYPTO_KEY` is optional (empty = passthrough). See `docs/helm-chart-standard.md`.
- Dependency notes: Bundled PostgreSQL and Valkey subcharts are used unless external services are configured. No MongoDB.
- Production overrides: Disable the bundled subcharts (`<subchart>.enabled=false`, `.external=true`), set `POSTGRES_HOST`/`REDIS_HOST`, and supply secrets via a secrets manager or `brCcs.useExistingSecret`; override image tags, ingress, resources, and integration endpoints (Fetcher/STA/Reporter).
- Source/license: Source is in `github.com/LerianStudio/helm`; chart license is Elastic License 2.0. The br-ccs service itself is proprietary (Lerian Studio).

## TL;DR

```bash
cp charts/br-ccs/values-template.yaml my-values.yaml   # fill every REQUIRED field
helm dependency build charts/br-ccs
helm install br-ccs charts/br-ccs -f my-values.yaml \
  --set brCcs.secrets.CCS_CRYPTO_MASTER_KEY=$(openssl rand -hex 32)
```

The render fails, naming the variable, until every value the app needs at boot is set.

## Service topology

| Aspect | Value |
|--------|-------|
| Container port / Service port | `4030` (`SERVER_ADDRESS=:4030`) |
| Service type | `ClusterIP` |
| Run mode | Single Deployment, `CCS_RUN_MODE=all` (API + workers) |
| Liveness probe | `GET /health` |
| Readiness probe | `GET /readyz` (PROJECT_RULES §13.4) |
| Persistence | PostgreSQL (no MongoDB) |
| Cache / idempotency / rate-limit | Redis / Valkey |

## Dependencies

All bundled subcharts are `.enabled`-gated. For BYOC / production, disable them
and point the app at external infrastructure (see `values-template.yaml`).

| Subchart | Version | Repository |
|----------|---------|------------|
| postgresql | 16.3.5 | https://charts.bitnami.com/bitnami |
| valkey | 2.4.7 | oci://registry-1.docker.io/bitnamicharts |

## Configuration

Non-secret configuration lives under `brCcs.configmap`; credentials and keys
under `brCcs.secrets`. Optional knobs not modeled explicitly can be set via
`brCcs.extraEnvVars`. `LICENSE_FILE_PATH` is not modeled: the chart mounts no
license file, so use `LICENSE_KEY`.

### Boot contract

The app (CCS 1.1.x) refuses to boot on a set of values. The chart runs the same
checks at render time (`templates/_validate.tpl`), so `helm template` and
`helm install` fail with the variable to fix instead of a pod that crash-loops.
A value in `brCcs.extraEnvVars` counts as set, except a credential the chart
Secret renders (passwords, `LICENSE_KEY`, `CCS_CRYPTO_MASTER_KEY`, `*_CLIENT_SECRET`,
`*_API_KEY`, `*_SECRET_KEY`, `STREAMING_SASL_PASSWORD`, …): set there, it fails the
render, because `extraEnvVars` is rendered into the ConfigMap in plaintext. Put it in
`brCcs.secrets`. Ids, access-key ids and CA certificates are not refused.

| Value | Rule |
|-------|------|
| `ENV_NAME` | `production`, `staging`, `uat` or `local` as written, or a development name in any case. Anything else (`homolog`, `Production`) is refused by the app logger. |
| `REDIS_TLS`, `OUTBOX_ENABLED`, `CIRCUIT_BREAKER_ENABLED`, `CCS_DETAIL_MESSAGE_EMIT_ENABLED` | Exactly `"true"` or `"false"`: the app refuses `"1"`, `"t"` or `"TRUE"`. |
| `PLUGIN_AUTH_ENABLED` | Default `"true"`. `"false"` only with a development `ENV_NAME` (`development`, `develop`, `dev`, `local`, `test`) outside `DEPLOYMENT_MODE=saas`. |
| `PLUGIN_AUTH_HOST` (or `global.auth.host`) | Required with auth on. |
| `REPORTER_CLIENT_ID/SECRET`, `STA_CLIENT_ID/SECRET` | Required with auth on, even with `STA_ENABLED=false`. |
| `OBJECT_STORAGE_{STA,CCS}_SSE_ALGORITHM` | Required: both buckets are always bound. `AES256` (recommended), `aws:kms` with `*_SSE_KMS_KEY_ID`, or `none` in development only. |
| `LICENSE_KEY` | Required in every environment. The chart mounts no license file, so `LICENSE_FILE_PATH` does not count. |
| `CCS_CRYPTO_MASTER_KEY` | Required, 64 hex chars. An argocd-vault-plugin placeholder (`<path:...>`) passes the shape check; the plugin replaces it after the render. |
| `TRUSTED_PROXIES`, `CORS_ALLOWED_ORIGINS` | Required with `ENV_NAME=production`; no `0.0.0.0/0` or `*`. |
| `REPORTER_TEMPLATE_{NAME,ID}_<t>` | One per template: `CCS0002`, `CCS0004` and `ACCS005`; only `ACCS005` with `CCS_DETAIL_MESSAGE_EMIT_ENABLED=false`. |
| `REDIS_TLS` | Unset, it renders `"true"` for external Redis, or `"false"` when `ALLOW_INSECURE_REDIS` or `ALLOW_INSECURE_TLS` is true (`true`, `1`, `yes`, `on`). `ALLOW_INSECURE_TLS` relaxes every data store, so it turns Redis to plaintext too: set `REDIS_TLS` explicitly if Redis serves TLS. The bundled valkey serves no TLS: when `REDIS_HOST` is empty or exactly its Service name, the chart renders `"false"` plus `ALLOW_INSECURE_REDIS="true"`, unless you set `ALLOW_INSECURE_REDIS` yourself. Any other `REDIS_HOST`, a short Service name included, is external Redis, even with the subchart on. Plaintext needs a true bypass. |
| `CRM_URL`, `CRM_ORGANIZATION_ID` | Required; `CRM_URL` absolute and https outside development. |
| `REPORTER_URL` | Required. The app always dials the Reporter; `REPORTER_ENABLED` is no longer read or rendered. |
| `OUTBOX_ENABLED`, `CIRCUIT_BREAKER_ENABLED` | Default `"true"`; `"false"` is refused (the Reporter needs both). |

With `brCcs.useExistingSecret: true` the chart cannot read the Secret, so the
checks on secret values are skipped; the app still refuses to boot without them.

`CCS_BACEN_DESTINATARIO_CNPJ_BASE` is not checked: unset, the app sends its
placeholder `00000000` in the BACEN envelope. Set it to the real value.

### Required secrets

| Key | Required | Notes |
|-----|----------|-------|
| `POSTGRES_PASSWORD` | Yes | Single-sourced from the bundled subchart Secret when `postgresql.enabled=true`; supply here for external Postgres. |
| `REDIS_PASSWORD` | Yes | Single-sourced from the bundled valkey Secret when `valkey.enabled=true`; supply here for external Redis. |
| `CCS_CRYPTO_MASTER_KEY` | Yes | AES-256-GCM master key, 64 hex chars (`openssl rand -hex 32`). The render fails without it. |
| `LICENSE_KEY` | Yes | Lerian license key, checked at boot in every environment. |
| `REPORTER_CLIENT_ID` / `REPORTER_CLIENT_SECRET` | With auth on | M2M credentials for the Reporter. |
| `STA_CLIENT_ID` / `STA_CLIENT_SECRET` | With auth on | M2M credentials for STA, required even with `STA_ENABLED=false`. |
| `REDIS_CA_CERT` | No | Base64 PEM of a private CA for Redis TLS. |
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
helm lint charts/br-ccs -f charts/br-ccs/tests/values/boot-contract.yaml
helm template charts/br-ccs -f charts/br-ccs/tests/values/boot-contract.yaml
helm unittest charts/br-ccs
python3 charts/br-ccs/tests/test_no_duplicate_env_keys.py
```
