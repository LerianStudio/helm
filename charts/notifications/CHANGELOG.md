# Changelog

All notable changes to this chart will be documented in this file.

## 1.0.0-beta.5

- Renamed the chart from `lerian-notification-helm` to `notifications-helm` to match the new application/service name.
- Renamed template helpers from `lerian-notification.*` to `notifications.*` and worker default names from `lerian-notification-worker-{email,sms,webhook}` to `notifications-worker-{email,sms,webhook}`.
- Updated default image repositories from `docker.io/lerianstudio/lerian-notification[-worker-*]` to `docker.io/lerianstudio/notifications[-worker-*]`.
- Updated `sources` and source URLs to `github.com/LerianStudio/notifications`.
- Updated environment defaults: `POSTGRES_USER` / `POSTGRES_NAME` -> `notifications`, `SWAGGER_TITLE` -> `Notifications`, `OTEL_RESOURCE_SERVICE_NAME` -> `notifications`, `OTEL_LIBRARY_NAME` -> `github.com/LerianStudio/notifications`.

## 0.1.0

Initial chart for `lerian-notification`.

- API component (`cmd/api`) on container port 8080 with ClusterIP Service and optional Ingress.
- Three worker components (`cmd/worker-email`, `cmd/worker-sms`, `cmd/worker-webhook`) on ports 8081/8082/8083 — health-probe-only, no Service exposure.
- Shared ConfigMap and Secret consumed by every component via `envFrom`.
- `secretRef.name` toggle for external Secret references (gitops / ArgoCD Vault Plugin).
- `golang-migrate` pre-install/pre-upgrade Job that reuses the API image to apply `/migrations` against the external Postgres.
- HPA and PodDisruptionBudget templates for the API (disabled by default).
- No chart dependencies: Postgres, Redis and RabbitMQ are external.
