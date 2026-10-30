# notifications

## Chart Contract

- Chart type: `multi-component`
- Required secrets: none are enforced at render time, so the default render succeeds, but the application will not start without `secrets.NOTIFICATION_ENCRYPTION_KEY` and `secrets.NOTIFICATION_AUTH_CACHE_ENCRYPTION_KEY` (each a base64-encoded 32-byte key), and `secrets.POSTGRES_PASSWORD` is required when `config.ENV_NAME` is `production`. `secrets.DATABASE_URL` is required by the migrations Job while `migrations.enabled` is `true`. See [Required secrets](#required-secrets).
- Dependency notes: No local dependency charts are bundled. PostgreSQL, Redis, and RabbitMQ are external (provided by the target environment); migrations run as a Helm pre-install/pre-upgrade Job against the external PostgreSQL. External notification providers are configured through values.
- Production overrides: Provide provider credentials through chart secrets or existing Secrets where supported; override API/worker image tags, ingress, resources, and provider endpoints.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

Helm chart for the Notifications service — multi-channel delivery (email, SMS, webhook) for the Lerian platform.

## Topology

| Component         | Path (service repo)   | Port | Kind                              |
|-------------------|-----------------------|------|-----------------------------------|
| `api`             | `cmd/api`             | 8080 | Deployment + Service + Ingress    |
| `worker-email`    | `cmd/worker-email`    | 8081 | Deployment (health probe only)    |
| `worker-sms`      | `cmd/worker-sms`      | 8082 | Deployment (health probe only)    |
| `worker-webhook`  | `cmd/worker-webhook`  | 8083 | Deployment (health probe only)    |

All four components consume the **same** env contract, exposed via a single shared `ConfigMap` (non-sensitive) and a single shared `Secret` (sensitive). Workers bind `/health` and `/readyz` on their respective `containerPort` via `WORKER_HEALTH_ADDRESS`, which the chart injects per worker.

## External dependencies

The chart does **not** bundle subcharts. The target environment must provide:

- PostgreSQL (configured via `POSTGRES_*` keys under `.Values.config` and `.Values.secrets`)
- Redis (configured via `REDIS_*`)
- RabbitMQ (configured via `RABBITMQ_*`)

## Migrations

`golang-migrate` runs as a Helm `pre-install`/`pre-upgrade` Job (`hook-weight: -5`). It reuses the API image — the service Dockerfile bundles `/migrations`. Toggle with `migrations.enabled` (default `true`).

## Secrets

Two modes:

1. **Chart-rendered Secret** (default). Populate `.Values.secrets.*` from your gitops layer (ArgoCD Vault Plugin substitutes the values at sync time).
2. **External Secret**. Set `.Values.secretRef.name` to the name of an existing Secret in the release namespace. The chart skips its own Secret template and every component mounts the external Secret via `envFrom` instead.

## Required secrets

The chart does not fail the render when these are empty (the defaults are empty strings), so a missing value surfaces at runtime, not at `helm template`. Set them via `.Values.secrets.*` or, with `secretRef.name`, as keys in the external Secret.

| Key | Consumed by | Notes |
|-----|-------------|-------|
| `NOTIFICATION_ENCRYPTION_KEY` | API and workers | Base64-encoded 32-byte key (AES-256) that encrypts delivery-profile credentials at rest. The application refuses to boot in every environment if it is empty or malformed. Not declared in the chart's default `secrets` map; add it under `secrets` (or `extraSecrets`, or in the external Secret). |
| `NOTIFICATION_AUTH_CACHE_ENCRYPTION_KEY` | API and workers | Base64-encoded 32-byte key for the destination auth cache stored in Redis. Required in every environment; boot fails if empty or malformed. |
| `DATABASE_URL` | Migrations Job | Pre-built, URL-escaped Postgres DSN (`postgres://USER:PASSWORD@HOST:PORT/DB?sslmode=...`). Required while `migrations.enabled` is `true`. If it is empty the render still succeeds and the Job receives an empty `-database` argument and fails at run time. With `secretRef.name`, the external Secret must contain a `DATABASE_URL` key. |
| `POSTGRES_PASSWORD` | API and workers | Required by the application when `config.ENV_NAME` is `production`. |

With `config.ENV_NAME: production` the application also refuses the dev-only encryption keys committed in its repository, so generate real keys, for example `openssl rand -base64 32`. Do not set the same Secret key in both `secrets` and `extraSecrets`: both are rendered into the same Secret.

## Environment name

The chart default is `config.ENV_NAME: "firmino"`. The application only applies its production safeguards when `ENV_NAME` is exactly `production`: Swagger is forced off, rate limiting is forced on, stack traces are suppressed, `POSTGRES_PASSWORD` is required, `POSTGRES_SSLMODE=disable` and insecure RabbitMQ TLS/health-check settings are rejected, and the dev-only encryption keys are refused. Any other value, including the default, leaves these checks off. Set `config.ENV_NAME: production` (and `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`, which is independent) for production installs.

## Autoscaling and PodDisruptionBudgets

Only the API has an HPA and a PodDisruptionBudget template (`api.autoscaling.*`, `api.pdb.*`). `workerEmail`, `workerSms` and `workerWebhook` expose `autoscaling.*` and `pdb.*` values, but the chart ships no HPA or PDB template for them. Setting `workerX.autoscaling.enabled: true` only removes `replicas:` from that worker's Deployment, which leaves the replica count to whatever else manages it (an externally created HPA, or the Kubernetes default of 1 on first create). While `workerX.autoscaling.enabled` is `true`, `workerX.replicaCount` has no effect because the Deployment omits `replicas:`. Keep it `false` to scale with `workerX.replicaCount`, or create an HPA outside this chart.

## Release naming

Resource names come from `api.name` (default `notifications`) and the `workerX.name` values, not from the Helm release name. The API Deployment, Service, ConfigMap, Secret and ServiceAccount are all named `notifications` unless you set `fullnameOverride` (or change `api.name`), and the worker Deployments are always named from `workerX.name`. Two releases of this chart in the same namespace therefore collide; use one release per namespace, or set `api.name`, `fullnameOverride` and each `workerX.name` to unique values per release.

## Install

```sh
helm install notifications ./charts/notifications \
  -n notifications --create-namespace \
  -f values-firmino.yaml
```

## Key values (per-env overrides)

| Key                                | Notes                                            |
|------------------------------------|--------------------------------------------------|
| `api.image.tag`                    | Image tag for the API and (by default) workers   |
| `workerEmail.image.tag`            | Override per worker if independently versioned   |
| `workerSms.image.tag`              | ditto                                            |
| `workerWebhook.image.tag`          | ditto                                            |
| `api.ingress.enabled`              | `false` by default                               |
| `api.ingress.hosts[].host`         | Per-env host                                     |
| `config.ENV_NAME`                  | `production` enables the app's production checks; any other value (default `firmino`) leaves them off |
| `config.POSTGRES_HOST`             | External Postgres host                           |
| `config.REDIS_HOST`                | External Redis host                              |
| `config.RABBITMQ_HOST`             | External RabbitMQ host                           |
| `secrets.POSTGRES_PASSWORD`        | Required by the app when `ENV_NAME=production`   |
| `secrets.DATABASE_URL`             | Required by the migrations Job (pre-built DSN)   |
| `secrets.NOTIFICATION_ENCRYPTION_KEY` | Required: app will not boot without it (base64, 32 bytes) |
| `secrets.NOTIFICATION_AUTH_CACHE_ENCRYPTION_KEY` | Required: app will not boot without it (base64, 32 bytes) |
| `secrets.RABBITMQ_URL`             | Full AMQP URL with credentials (alternative)     |
| `secretRef.name`                   | Optional: name of pre-existing Secret            |
| `migrations.enabled`               | Skip if migrations are managed out-of-band       |

See `values.yaml` for the full env contract.
