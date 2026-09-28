# br-sisbajud Helm Chart

Deploys **br-sisbajud** — the Lerian SISBAJUD plugin (judicial asset blocking/unblocking integration with BACEN SISBAJUD) — into Kubernetes. The service is a single Go binary running the HTTP API + background workers in one process.

## Chart Contract

- Chart type: `single-service`
- Required secrets: **None for a default render.** For external Postgres (the default), provide `POSTGRES_PASSWORD` via `brSisbajud.secrets.POSTGRES_PASSWORD` or `brSisbajud.useExistingSecret`; on the target environments this is sourced from GitOps/Vault. `REDIS_PASSWORD` is needed when the external Redis requires auth. When the bundled `postgresql`/`valkey` subcharts are enabled instead, those passwords are **single-sourced** from the subchart Secrets (read at runtime via `secretKeyRef`) and are not stored in the app Secrets. No credential is ever placed in a ConfigMap. Optional keys added under `brSisbajud.secrets` are emitted only when set.
- Dependency notes: Bundled `postgresql` (16.3.5) and `valkey` (2.4.7) Bitnami subcharts are **declared but disabled by default** — Postgres and Redis are external and pre-provisioned on the target environments. Kafka/Redpanda is external and referenced only by `STREAMING_BROKERS`. Enable the subcharts only for a self-contained install.
- Production overrides: Set `brSisbajud.image.tag` (defaults to `Chart.appVersion`); `POSTGRES_HOST` and `POSTGRES_PASSWORD`; `REDIS_HOST`; `STREAMING_BROKERS` (a producer with `STREAMING_ENABLED=true` and empty `STREAMING_BROKERS` fails closed at boot by design); `KMS_PROVIDER` / `VAULT_ADDR` / `VAULT_AUTH_METHOD` / `VAULT_APPROLE_ROLE_ID` / `VAULT_APPROLE_SECRET_ID` for envelope encryption; `MIDAZ_BASE_URL` for the ledger connector; and `ingress`, `autoscaling`, and `resources` as needed. `useExistingSecret`/`existingSecretName` are supported for the app and the migration Job.
- Source/license: Source is in `github.com/LerianStudio/helm`; chart license is Apache-2.0. The `br-sisbajud` service source is `github.com/LerianStudio/br-sisbajud`.

## Configuration knobs (ConfigMap passthrough)

`brSisbajud.configmap` is emitted verbatim into the ConfigMap — it is **not** a fixed allowlist. Any additional env can be added under `brSisbajud.configmap` without editing the chart. `POSTGRES_HOST` and `REDIS_HOST` are handled first-class by the template (the hosts derive from the bundled subchart when enabled). Secrets must go under `brSisbajud.secrets`, never `configmap`.

| Key | Default | Notes |
|-----|---------|-------|
| `ENV_NAME` | `development` | App env; `development` relaxes production boot guards |
| `SERVER_ADDRESS` | `0.0.0.0:4029` | host:port form (container port is 4029) |
| `POSTGRES_{HOST,PORT,USER,NAME,SSLMODE}` | see values | External managed Postgres |
| `REDIS_HOST` | `""` | host:port; required for rate limiting + idempotency |
| `KMS_PROVIDER` | `vault` | Envelope encryption key manager |
| `VAULT_ADDR` | `""` | Vault server address |
| `VAULT_AUTH_METHOD` | `approle` | `token` or `approle` |
| `VAULT_TRANSIT_MOUNT_PATH` | `transit-st` | Transit secrets-engine mount path |
| `STREAMING_ENABLED` | `true` | fail-closed when brokers/source empty |
| `STREAMING_BROKERS` | `""` | CSV; **required when streaming enabled** |
| `STREAMING_CLOUDEVENTS_SOURCE` | `br-sisbajud` | CloudEvents source identifier |
| `MIDAZ_BASE_URL` | `""` | Midaz ledger connector URL (required service-wide) |
| `ENABLE_TELEMETRY` | `false` | when `true`, `OTEL_EXPORTER_OTLP_ENDPOINT` is set to `http://$(HOST_IP):4317` |

## Detached migrations

`migrations.enabled` (default `true`) ships an ArgoCD **PreSync** Secret (`hook-weight: -2`) + Job (`hook-weight: -1`) that runs `ghcr.io/lerianstudio/br-sisbajud-migrations`. That image applies the `golang-migrate` SQL migrations to the `br_sisbajud` database. The Job pod is hardened (non-root, read-only rootfs, drop ALL, no service-account token) and waits for Postgres via a `busybox` initContainer. Supports `migrations.useExistingSecret`/`existingSecretName`.
