# Changelog

All notable changes to this chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this chart adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — Unreleased

### Added

- Initial Helm chart for `plugin-br-payments-fakebtg`, a stand-in HTTP server
  that mocks the BTG provider API surface for dev/staging environments without
  access to the real BTG sandbox.
- Single Deployment + Service (ClusterIP, port 8090). Optional Ingress for
  external integrators reaching the `/admin/*` and `/inspect/*` endpoints.
- HTTP `GET /health` wired to both readiness and liveness probes.
- Distroless nonroot security context with read-only root filesystem and all
  capabilities dropped.
- ServiceAccount auto-created by default; override with `fakebtg.serviceAccount`.
