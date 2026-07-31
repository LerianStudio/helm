# br-consignado-gw Helm Chart

Deploys the **br-consignado-gw** Dataprev consignado gateway together with its
operator console. The console is a separate nginx SPA Deployment, but it shares
one ingress host with the API: `/` serves the UI and `/v1` routes to the API.
That topology is intentional — the console refuses cross-origin API URLs so its
Bearer token cannot be sent to an arbitrary origin.

## Chart Contract

- Chart type: `multi-component` (`api`, `ui`, `migrations`). Components default to `enabled: false`; enable only the surface you intend to operate.
- Required secrets: when `migrations.enabled=true`, a Postgres password is required through `migrations.postgres.password`, `api.secrets.POSTGRES_PASSWORD`, or an operator-owned `migrations.postgres.passwordSecret.name`. In GitOps, use AVP/Vault placeholders — never store credentials in values. `api.useExistingSecret` / `api.existingSecretName` replace the chart-managed API Secret.
- Dependency notes: Postgres, Valkey/Redis, RabbitMQ/Redpanda, Casdoor, and image credentials are external platform services. The chart deliberately has no infra subcharts. The dedicated migrations image contains the SQL tree because the API image is distroless.
- Production overrides: set API and UI image tags; Postgres host/user/database/password and explicit TLS mode; app integration keys under `api.configmap` / `api.secrets`; the one ingress host; and UI Casdoor runtime configuration. Keep `ui.configmap.API_BASE_URL` empty unless it is a same-origin path prefix — the chart routes `/v1` on that host to the API. UI nginx is read-only and mounts `/tmp`; its image pins one worker to prevent high-core nodes from creating a worker-per-core OOM.
- Source/license: chart source is `github.com/LerianStudio/helm` (Apache-2.0); service and UI source is `github.com/LerianStudio/br-consignado-gw`.

## Components

### API

`api.configmap` and `api.secrets` are verbatim maps, not allowlists. This keeps
the chart compatible as the gateway gains rail, outbox, tenant, and observability
settings. Put only non-secret settings in `api.configmap`; secret fields belong
in `api.secrets` or an existing Secret.

### Operator console

The console gets public runtime values from `ui.configmap`, rendered into
`/config.js` at container start. `CASDOOR_CLIENT_ID` is a PKCE public identifier,
not a secret. The API and UI must use the same browser origin; `ingress.apiPaths`
keeps `/v1`, health, readiness, version, and metrics routed to the API while the
UI owns `/`.

### Migrations

`migrations.enabled` creates an ArgoCD PreSync Secret (weight `-2`) and Job
(weight `-1`). This sequencing is necessary on a first install: the Job cannot
read the main-sync API Secret. The Job invokes `migrate` from
`br-consignado-gw-migrations` and uses the migration image's `/migrations` tree.
Passwords must be URL-safe for the PostgreSQL migration DSN.

## Validation

```sh
helm lint charts/br-consignado-gw-helm
helm template br-consignado-gw charts/br-consignado-gw-helm \
  -f .github/configs/helm-render-values/br-consignado-gw.yaml
```
