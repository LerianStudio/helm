# br-spi Helm Chart

Deploys the **br-sfn SPI (Pix) rail** — the four Go binaries (`core`, `spi`, `brcode`, `dict`) that connect a financial institution to BACEN SPI / DICT / Pix — into Kubernetes. When streaming is enabled, `core` becomes a CloudEvents **producer**, emitting `studio.lerian.settlement.*` onto the `br-spi.settlement` topic of a Redpanda/Kafka bus.

## Chart Contract

- Chart type: `multi-component`
- Required secrets: **None for a default render.** For external Postgres (the default), provide each component's `POSTGRES_PASSWORD` (all four share the single `brspi` database) via `<component>.secrets.POSTGRES_PASSWORD` or `<component>.useExistingSecret`; on the target environments this is sourced from GitOps/Vault. `dict` additionally needs `REDIS_PASSWORD` when its external Redis requires auth. When the bundled `postgresql`/`valkey` subcharts are enabled instead, those passwords are **single-sourced** from the subchart Secrets (read at runtime via `secretKeyRef`) and are not stored in the app Secrets. No credential is ever placed in a ConfigMap. Optional at-rest / PII keys added under `<component>.secrets` are emitted only when set.
- Dependency notes: Bundled `postgresql` (16.3.5) and `valkey` (2.4.7) Bitnami subcharts are **declared but disabled by default** — Postgres and Redis are external and pre-provisioned on the target environments. Kafka/Redpanda is external and referenced only by `STREAMING_BROKERS` (plaintext; no SASL/TLS knobs). Enable the subcharts only for a self-contained install.
- Production overrides: Set `<component>.image.tag` (defaults to `Chart.appVersion`); `POSTGRES_HOST` and `POSTGRES_PASSWORD` for every enabled component; `STREAMING_BROKERS` for `core` and `spi` (a producer with `STREAMING_ENABLED=true` and empty `STREAMING_BROKERS`/`STREAMING_CLOUDEVENTS_SOURCE` **fails closed at boot** by design); `REDIS_HOST` for `dict`; and per-component `ingress`, `autoscaling`, and `resources` as needed. `useExistingSecret`/`existingSecretName` are supported per component and for the migration Job.
- Source/license: Source is in `github.com/LerianStudio/helm`; chart license is Apache-2.0. The `br-spi` service source is `github.com/LerianStudio/br-spi`.

## Components

All four components are the same Go binary family (identical deployment shape). The chart renders them from one shared template library, so env — especially `STREAMING_*` — is emitted uniformly and a component can never silently drop a producer knob.

| Component | Image (default) | Listens | Streams | Role |
|-----------|-----------------|---------|---------|------|
| `core` | `ghcr.io/lerianstudio/br-sfn-core` | `:8080` | **yes** | Settlement engine; sole producer of `studio.lerian.settlement.*` |
| `spi` | `ghcr.io/lerianstudio/br-sfn-spi` | `:8080` | **yes** | ISO 20022 / BACEN SPI; writes the `spi->core` seam |
| `brcode` | `ghcr.io/lerianstudio/br-sfn-brcode` | `:8080` | no | Pix BR Code (QR) REST |
| `dict` | `ghcr.io/lerianstudio/br-sfn-dict` | `:8080` | no | DICT (Pix directory) REST; **requires `REDIS_HOST`** |

Each component exposes: `<component>.enabled`, `image.{repository,tag,pullPolicy}`, `replicaCount`, `service`, `ingress`, `autoscaling`, `pdb`, `resources`, `configmap` (map, emitted verbatim), `secrets`, `useExistingSecret`/`existingSecretName`, `extraEnvVars` (raw env list escape). Probes are `/health` (liveness) and `/readyz` (readiness) on the `http` port (containerPort `8080`).

### Settlement producer coupling

`core` produces `settlement.*` only by **consuming** the `spi->core` seam topics that `spi` writes. Therefore **both** `core` and `spi` must have `STREAMING_ENABLED=true`, the **same** `STREAMING_BROKERS`, and the **same** Postgres, or no settlement event is emitted at all. `brcode` and `dict` are REST-only and stream `false`.

## Configuration knobs (ConfigMap passthrough)

`<component>.configmap` is emitted verbatim into the component ConfigMap — it is **not** a fixed allowlist. Any additional env (BACEN endpoints, Postgres pool tuning, signer/JOSE knobs) can be added under `<component>.configmap` without editing the chart. `STREAMING_ENABLED`, `STREAMING_BROKERS`, `STREAMING_CLOUDEVENTS_SOURCE`, `POSTGRES_HOST`, and `REDIS_HOST` are handled first-class by the template (the hosts derive from the bundled subchart when enabled). Secrets must go under `<component>.secrets`, never `configmap`.

| Key | Default | Notes |
|-----|---------|-------|
| `ENV_NAME` | `development` | SPI env; `development` relaxes BACEN mTLS + accepts `http://`/mock endpoints |
| `SERVER_ADDRESS` | `:8080` | host:port form (container port is 8080) |
| `POSTGRES_{HOST,PORT,USER,DB,SSLMODE}` | see values | All four share the `brspi` database |
| `REDIS_HOST` | `""` | host:port; **required for `dict`** |
| `OUTBOX_ENABLED` | `true` | keep on for the producer |
| `IDEMPOTENCY_RETRY_WINDOW_SEC` | `300` | `core` only; must be `> 0` |
| `STREAMING_ENABLED` | `true` (core/spi), `false` (brcode/dict) | fail-closed when brokers/source empty |
| `STREAMING_BROKERS` | `""` | CSV; **required when streaming enabled** |
| `STREAMING_CLOUDEVENTS_SOURCE` | `studio.lerian.core` / `studio.lerian.spi` | required when streaming enabled |
| `ENABLE_TELEMETRY` | `false` | when `true`, `OTEL_EXPORTER_OTLP_ENDPOINT` is set to `$(HOST_IP):4317` (gRPC) |
| `OTEL_RESOURCE_SERVICE_NAME` | `br-spi-<component>` | distinct per binary so dashboards don't collapse |

## Detached migrations

`migrations.enabled` (default `true`) ships an ArgoCD **PreSync** Secret (`hook-weight: -2`) + Job (`hook-weight: -1`) that runs `ghcr.io/lerianstudio/br-sfn-spi-migrations`. That image's entrypoint applies the 6-module `golang-migrate` loop in manifest order (`global events spi dict brcode core`) to the single `brspi` database, using the per-module `x-migrations-table=schema_migrations_<module>` naming that `/readyz` reads back. `systemplane` is **not** applied by `golang-migrate` — it is managed by lib-systemplane at runtime. br-sfn runtime binaries are detached — they verify the schema on boot and refuse to start unmigrated — so the PreSync Job runs before every component Deployment. The Job pod is hardened (non-root, read-only rootfs, drop ALL, no service-account token) and waits for Postgres via a `busybox` initContainer. Supports `migrations.useExistingSecret`/`existingSecretName`.

Source code:
* https://github.com/LerianStudio/helm/tree/main/charts/br-spi
* https://github.com/LerianStudio/br-spi

## Install

```console
$ helm install br-spi oci://ghcr.io/lerianstudio/br-spi-helm --version 0.1.0 -n br-spi --create-namespace \
    --set core.configmap.POSTGRES_HOST=pg-dev,core.secrets.POSTGRES_PASSWORD=... \
    --set core.configmap.STREAMING_BROKERS=kafka-dev:9092
```

## External vs bundled infrastructure

Default (external): leave `postgresql.enabled=false` and `valkey.enabled=false`, set `POSTGRES_HOST`/`REDIS_HOST` per component, and provide `POSTGRES_PASSWORD` (and `REDIS_PASSWORD` if the Redis needs auth).

Bundled (self-contained): set `postgresql.enabled=true` (and `valkey.enabled=true`); the app reads the subchart-generated passwords via `secretKeyRef` (single-sourced), and `POSTGRES_HOST`/`REDIS_HOST` derive from the subchart Service names collapse-aware via `common.names.dependency.fullname`.

## Support & Community

- **GitHub Issues**: https://github.com/LerianStudio/br-spi/issues
- **Email**: contact@lerian.studio
