# Changelog

All notable changes to this chart will be documented in this file.

## 0.1.0

Initial chart for `lerian-notification`.

- API component (`cmd/api`) on container port 8080 with ClusterIP Service and optional Ingress.
- Three worker components (`cmd/worker-email`, `cmd/worker-sms`, `cmd/worker-webhook`) on ports 8081/8082/8083 — health-probe-only, no Service exposure.
- Shared ConfigMap and Secret consumed by every component via `envFrom`.
- `secretRef.name` toggle for external Secret references (gitops / ArgoCD Vault Plugin).
- `golang-migrate` pre-install/pre-upgrade Job that reuses the API image to apply `/migrations` against the external Postgres.
- HPA and PodDisruptionBudget templates for the API (disabled by default).
- No chart dependencies: Postgres, Redis and RabbitMQ are external.
