# lerian-notification

Helm chart for the Lerian Notification service — multi-channel delivery (email, SMS, webhook) for the Lerian platform.

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

## Install

```sh
helm install lerian-notification ./charts/lerian-notification \
  -n lerian-notification --create-namespace \
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
| `config.ENV_NAME`                  | `firmino` / `staging` / `production`             |
| `config.POSTGRES_HOST`             | External Postgres host                           |
| `config.REDIS_HOST`                | External Redis host                              |
| `config.RABBITMQ_HOST`             | External RabbitMQ host                           |
| `secrets.POSTGRES_PASSWORD`        | Required                                         |
| `secrets.RABBITMQ_URL`             | Full AMQP URL with credentials (alternative)     |
| `secretRef.name`                   | Optional: name of pre-existing Secret            |
| `migrations.enabled`               | Skip if migrations are managed out-of-band       |

See `values.yaml` for the full env contract.
