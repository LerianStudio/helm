# notifications

## Chart Contract

- Chart type: `multi-component`
- Images: ghcr `notifications` 1.2.0-beta.6 (the first image that serves the health port); the api binds `0.0.0.0:8080`.
- Required secrets: `secrets.LICENSE_KEY` is enforced at render time (the render refuses without it, unless `secretRef.name` points at an existing Secret or `licenseFile.existingSecret` mounts a signed licence file). The application will not start without `secrets.NOTIFICATION_ENCRYPTION_KEY` and `secrets.NOTIFICATION_AUTH_CACHE_ENCRYPTION_KEY` (each a base64-encoded 32-byte key), and `secrets.POSTGRES_PASSWORD` is required when `config.ENV_NAME` is `production`. `secrets.DATABASE_URL` is required by the migrations Job while `migrations.enabled` is `true`. See [Required secrets](#required-secrets).
- Dependency notes: the only subchart is `lerian-common-helm` (health preset). PostgreSQL, Redis, and RabbitMQ are external (provided by the target environment); migrations run as a Helm pre-install/pre-upgrade Job against the external PostgreSQL.
- Production overrides: Override API/worker image tags, ingress, and resources.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Elastic License 2.0.

Helm chart for the Notifications service — multi-channel delivery (email, SMS, webhook) for the Lerian platform.

## Topology

| Component         | Path (service repo)   | Port       | Kind                              |
|-------------------|-----------------------|------------|-----------------------------------|
| `api`             | `cmd/api`             | 8080, 8099 | Deployment + Service + Ingress    |
| `worker-email`    | `cmd/worker-email`    | 8099       | Deployment (no Service)           |
| `worker-sms`      | `cmd/worker-sms`      | 8099       | Deployment (no Service)           |
| `worker-webhook`  | `cmd/worker-webhook`  | 8099       | Deployment (no Service)           |

All four components consume the **same** env contract, exposed via a single shared `ConfigMap` (non-sensitive) and a single shared `Secret` (sensitive). Every component serves `/health`, `/readyz` and `/metrics` on `HEALTH_PORT` 8099; see [Health](#health).

## External dependencies

The chart bundles no datastore. The target environment must provide:

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

The chart refuses to render without `LICENSE_KEY` (unless `secretRef.name` is set); the other keys are not enforced at render time, so a missing value surfaces at runtime, not at `helm template`. Set them via `.Values.secrets.*` or, with `secretRef.name`, as keys in the external Secret.

| Key | Consumed by | Notes |
|-----|-------------|-------|
| `LICENSE_KEY` | API and workers | Licence key; every component refuses to boot without it. Render fails if it is empty and neither `secretRef.name` nor `licenseFile.existingSecret` is set. With `secretRef.name`, the external Secret must contain a `LICENSE_KEY` key. |
| `NOTIFICATION_ENCRYPTION_KEY` | API and workers | Base64-encoded 32-byte key (AES-256) that encrypts delivery-profile credentials at rest. The application refuses to boot in every environment if it is empty or malformed. Not declared in the chart's default `secrets` map; add it under `secrets` (or `extraSecrets`, or in the external Secret). |
| `NOTIFICATION_AUTH_CACHE_ENCRYPTION_KEY` | API and workers | Base64-encoded 32-byte key for the destination auth cache stored in Redis. Required in every environment; boot fails if empty or malformed. |
| `DATABASE_URL` | Migrations Job | Pre-built, URL-escaped Postgres DSN (`postgres://USER:PASSWORD@HOST:PORT/DB?sslmode=...`). Required while `migrations.enabled` is `true`. If it is empty the render still succeeds and the Job receives an empty `-database` argument and fails at run time. With `secretRef.name`, the external Secret must contain a `DATABASE_URL` key. |
| `POSTGRES_PASSWORD` | API and workers | Required by the application when `config.ENV_NAME` is `production`. |

With `config.ENV_NAME: production` the application also refuses the dev-only encryption keys committed in its repository, so generate real keys, for example `openssl rand -base64 32`. Do not set the same Secret key in both `secrets` and `extraSecrets`: both are rendered into the same Secret.

## Environment name

The chart default for `config.ENV_NAME` is not `production`. The application only applies its production safeguards when `ENV_NAME` is exactly `production`: Swagger is forced off, rate limiting is forced on, stack traces are suppressed, `POSTGRES_PASSWORD` is required, `POSTGRES_SSLMODE=disable` and insecure RabbitMQ TLS settings are rejected, and the dev-only encryption keys are refused. Any other value, including the default, leaves these checks off. Set `config.ENV_NAME: production` (and `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`, which is independent) for production installs.

## Autoscaling and PodDisruptionBudgets

Only the API has an HPA and a PodDisruptionBudget template (`api.autoscaling.*`, `api.pdb.enabled`, `api.pdb.annotations`; the budget itself is owned by the health preset). `workerEmail`, `workerSms` and `workerWebhook` are singletons: one replica, no HPA, no PodDisruptionBudget, and no `autoscaling.*` or `pdb.*` values.

## Health

Every component serves `/health` (liveness and startup, constant), `/readyz` (readiness) and `/metrics` on the internal health port 8099 (`HEALTH_PORT`). On the API it is a named ClusterIP Service port `health` that no Ingress routes to; on a LoadBalancer or NodePort Service the port is not published. The main API port answers only `/health` and `/version`. The `lerian-common` health preset owns probes, `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY`, `SHUTDOWN_TIMEOUT`, `terminationGracePeriodSeconds` (drain + shutdown + 10) and the rollout strategy (`maxSurge: 25%`, `maxUnavailable: 0`); tune only `<component>.health.drainSeconds` (API) and `<component>.health.shutdownSeconds`. The API runs 2 replicas with a PodDisruptionBudget (`maxUnavailable: 1`, `unhealthyPodEvictionPolicy: AlwaysAllow`); each worker is a singleton (1 replica, `Recreate`, no PDB) because the retry scheduler has no row claim, so two overlapping pods could both resend.

The chart refuses an `image.tag` below `1.2.0-beta.6` on any component and reads the tag from `Chart.appVersion` when you set none. Prereleases sort `beta < rc < stable`, so the floor refuses `1.2.0-beta.5` and older. `v1.2.0-rc.1` sorts above the floor and predates the cut, so staging pairs this chart only with an rc cut after notifications#220.

## Upgrading from 1.1.x

The render fails, with a message naming the key, for: `terminationGracePeriodSeconds`; `<component>.probes`; `<component>.deploymentStrategy`; `api.pdb.maxUnavailable` and `api.pdb.minAvailable`; `<worker>.containerPort`; `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY` or `SHUTDOWN_TIMEOUT` in `config`, `extraConfig` or `extraEnvVars`; and an `image.tag` below the floor. Drop `WORKER_HEALTH_ADDRESS`, `WORKER_SHUTDOWN_TIMEOUT_SEC`, `RABBITMQ_PORT_HOST`, `RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS`, `RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK` and the secret `RABBITMQ_HEALTH_CHECK_URL`: the application no longer reads them.

Load-balancer or uptime checks that used the main port's `/readyz` must use its `/health`; BYOC needs node-to-pod traffic on 8099. Upgrade the chart and the image together: the chart refuses an older image, and rollback means chart and image together.

## Release naming

Resource names come from `api.name` (default `notifications`) and the `workerX.name` values, not from the Helm release name. The API Deployment, Service, ConfigMap, Secret and ServiceAccount are all named `notifications` unless you set `fullnameOverride` (or change `api.name`), and the worker Deployments are always named from `workerX.name`. Two releases of this chart in the same namespace therefore collide; use one release per namespace, or set `api.name`, `fullnameOverride` and each `workerX.name` to unique values per release.

## Install

```sh
helm install notifications ./charts/notifications \
  -n notifications --create-namespace \
  -f my-values.yaml
```

## Key values (per-env overrides)

| Key                                | Notes                                            |
|------------------------------------|--------------------------------------------------|
| `api.image.tag`                    | Image tag for the API, and for the migrations Job while `migrations.image.tag` is empty; workers do not inherit it (set each `workerX.image.tag`) |
| `workerEmail.image.tag`            | Override per worker if independently versioned   |
| `workerSms.image.tag`              | ditto                                            |
| `workerWebhook.image.tag`          | ditto                                            |
| `api.ingress.enabled`              | `false` by default                               |
| `api.ingress.hosts[].host`         | Per-env host                                     |
| `config.ENV_NAME`                  | `production` enables the app's production checks; any other value, including the chart default, leaves them off |
| `config.POSTGRES_HOST`             | External Postgres host                           |
| `config.REDIS_HOST`                | External Redis host                              |
| `config.RABBITMQ_HOST`             | External RabbitMQ host                           |
| `secrets.LICENSE_KEY`              | Required: render fails without it (unless `secretRef.name` or `licenseFile.existingSecret` is set) |
| `licenseFile.existingSecret`       | Optional Secret with a signed licence file under the `license` key, mounted as a directory on the api and workers; sets `LICENSE_FILE_PATH` to `/etc/lerian/license/license`; file mode needs an image on lib-license-go v5 |
| `secrets.POSTGRES_PASSWORD`        | Required by the app when `ENV_NAME=production`   |
| `secrets.DATABASE_URL`             | Required by the migrations Job (pre-built DSN)   |
| `secrets.NOTIFICATION_ENCRYPTION_KEY` | Required: app will not boot without it (base64, 32 bytes) |
| `secrets.NOTIFICATION_AUTH_CACHE_ENCRYPTION_KEY` | Required: app will not boot without it (base64, 32 bytes) |
| `secrets.RABBITMQ_URL`             | Full AMQP URL with credentials (alternative)     |
| `secretRef.name`                   | Optional: name of pre-existing Secret            |
| `migrations.enabled`               | Skip if migrations are managed out-of-band       |

See `values.yaml` for the full env contract.
