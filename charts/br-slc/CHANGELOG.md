# Changelog

All notable changes to the br-slc Helm chart are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `mock-nuclea` fail-closed render guard (ADR-23): `mockNuclea.enabled=true` now
  **fails** the Helm render under `ENV_NAME=production` or `DEPLOYMENT_MODE=saas`,
  mirroring the app's `validateDispatchDevRecipientConfig`. The mock stays a
  **separate optional Deployment** (not a same-pod sidecar — team decision
  2026-07-23), keeping the app pod small and independently scalable.
- `mockNuclea.spbKeysSecret` (default disabled): optional external provisioning
  of the SPB key material for the signed credit round-trip. When enabled, the
  operator/client supplies a Secret with the recipient PRIVATE key + emitter
  PUBLIC cert, mounted read-only into the mock and wired via
  `SPB_RECIPIENT_KEY_PATH`/`SPB_EMITTER_CERT_PATH` — exercising the real BYOC
  deploy flow where the client sets the key material themselves. Disabled = bare
  connectivity/health fixture.
- Pod-level `nodeSelector`, `affinity`, and `tolerations` values. When
  `mqbridge.enabled`, the required `kubernetes.io/arch: amd64` pin is merged into
  `nodeSelector` last (dest wins), so an override cannot drop the arch constraint.

### Fixed

- `REDIS_MIN_RETRY_BACKOFF` / `REDIS_MAX_RETRY_BACKOFF` defaults were inverted
  (min `8` > max `1`); swapped to min `1` / max `8`.
- `migrations` init container (wait-for-Postgres) now uses
  `migrations.resources` instead of hard-coded CPU/memory, matching the main
  migrations container.

## [0.1.0-beta.2] - 2026-07-15

### Added

- `mock-nuclea` (Núclea clearing-house simulator) as a gated, standalone
  Deployment + ClusterIP Service — DEV/HML FIXTURE ONLY, `enabled: false` by
  default (never enable in production/BYOC). Unlike the same-pod
  signer/xsdValidator/mqbridge sidecars, the app reaches it over cluster DNS
  (`br-slc-mock-nuclea:9190`), not localhost. Uses its own
  `ghcr.io/lerianstudio/br-slc-mock-nuclea` image (published by a separate
  br-slc release-pipeline workstream); exposes only `GET /health`, used for
  both liveness and readiness.

## [0.1.0-beta.1] - 2026-07-10

### Added

- Initial Helm chart for the br-slc monolith (Sistema de Liquidação Centralizada — SLC).
- Single Deployment running the app plus the mandatory same-pod `slc-signer` and
  `aslc-xsd-validator` sidecars (ADR-12, reached over localhost) and a conditional
  `mqbridge` sidecar (RSFN IBM MQ inbound, amd64-pinned, `replicaCount=1`, off by default).
- Detached migrations via an ArgoCD PreSync hook Secret + Job using the dedicated
  `ghcr.io/lerianstudio/br-slc-migrations` image, with a `busybox` wait-for-postgres
  initContainer.
- BYOC single-tenant posture: ClusterIP-only Service, no Ingress; external, client-managed
  Postgres/Redis/RabbitMQ (no bundled subcharts). Per-container hardened `securityContext`
  and ADR-9 signing-key custody isolated to the signer container.
