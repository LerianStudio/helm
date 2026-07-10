# Changelog

All notable changes to the br-slc Helm chart are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
