# Changelog

All notable changes to the br-ccs Helm chart are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-07

### Added

- Initial Helm chart for the br-ccs service (BACEN CCS regulatory integration).
- Single Deployment running `CCS_RUN_MODE=all` (HTTP API + background workers in one process).
- ClusterIP Service on port 4030 (`SERVER_ADDRESS=:4030`).
- Health probes wired to the verified application endpoints: liveness `GET /health`,
  readiness `GET /readyz`.
- Full env-var coverage from `config/.env.example` split across ConfigMap (non-secret)
  and Secret (credentials, crypto keys, object-storage keys, M2M API keys).
- PostgreSQL migrations Job using the dedicated `br-ccs-migrations` image
  (golang-migrate runner; PreSync for external Postgres, PostSync for the bundled
  subchart), plus a migration-only Secret hook for the external chart-managed path.
- Optional subchart dependencies: `postgresql`, `valkey`, `rabbitmq` (all `.enabled`-gated).
- External-infra bootstrap Jobs for PostgreSQL and RabbitMQ (opt-in via `global.*Definitions.enabled`).
- HPA, PodDisruptionBudget, Ingress, ServiceAccount templates.
- Non-root, read-only-root-filesystem, drop-ALL security contexts on all containers.
