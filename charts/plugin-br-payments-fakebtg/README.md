# plugin-br-payments-fakebtg-helm

## Chart Contract

- Chart type: `single-service`
- Required secrets: None for default render.
- Dependency notes: This is a constrained fake/mock chart and intentionally has no local dependency charts.
- Production overrides: Do not use this chart as a production payment provider; override image, ingress, resources, and probes only for test environments.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

A Helm chart for [fakebtg](https://github.com/LerianStudio/plugin-br-payments/tree/main/cmd/fakebtg) — a stand-in HTTP server that mocks the BTG provider API surface for use in dev/staging environments without access to the real BTG sandbox.

> Dev/staging only. Do **not** install in production.

This chart is a constrained `single-service` mock chart: one Deployment, one Service, no persistent state, no upstream dependencies, and no required secrets. The intentionally small surface is part of the contract; do not copy production-only constructs from `plugin-br-payments` into this fake unless the fake binary actually needs them.

## TL;DR

```bash
helm install fakebtg oci://ghcr.io/lerianstudio/plugin-br-payments-fakebtg-helm \
  --namespace midaz-plugins --create-namespace
```

## Prerequisites

- Kubernetes 1.23+
- Helm 3.10+

## Architecture

The chart deploys **one Deployment, one pod** running the `/fakebtg` binary on a distroless nonroot image. It listens on port `8090` by default (override with the `FAKEBTG_PORT` env var via `fakebtg.extraEnvVars`). There is no persistent state and no external dependency.

## Endpoints

- `GET /health` — liveness/readiness probe target (also `/fakebtg healthcheck` CLI subcommand)
- BTG provider surface:
  - `POST /oauth/token`
  - `POST /{companyId}/banking/collections`
  - `POST /{companyId}/banking/payments`
  - `GET /{companyId}/banking/payments`
- Chaos / scenario control (for external testers):
  - `POST /admin/set-error`
  - `POST /admin/set-latency`
  - `POST /admin/clear-error`
  - `POST /admin/clear-latency`
  - `POST /admin/reset`
- Inspection:
  - `GET /inspect/calls`, `DELETE /inspect/calls`
- Inbound webhook recording:
  - `POST /webhook-receiver`, `GET /inspect/webhook-receiver`

## Required configuration

None. fakebtg starts with no env vars set and exposes `GET /health` on port `8090`.

## Common values

| Key | Default | Description |
|-----|---------|-------------|
| `fakebtg.replicaCount` | `1` | Number of replicas. Keep at 1 — scenario state is in-memory. |
| `fakebtg.image.repository` | `ghcr.io/lerianstudio/plugin-br-payments-fakebtg` | Container image. |
| `fakebtg.image.tag` | `""` (Chart `appVersion`) | Image tag. |
| `fakebtg.service.type` | `ClusterIP` | Service type. |
| `fakebtg.service.port` | `8090` | Service port. |
| `fakebtg.ingress.enabled` | `false` | Expose via Ingress for external testers. |
| `fakebtg.extraEnvVars` | `{}` | Extra env vars (e.g., `FAKEBTG_PORT: ":9000"`). |

See [`values.yaml`](./values.yaml) for the full list.

## Ingress

External integrators that need to hit `/admin/*` for chaos scenarios can expose fakebtg via Ingress:

```yaml
fakebtg:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: fakebtg.staging.example.com
        paths:
          - path: /
            pathType: Prefix
```

## Probes

| Probe | Path | Notes |
|-------|------|-------|
| Liveness | `/health` | Returns 200 once the HTTP server is up. |
| Readiness | `/health` | Same endpoint; no external deps to gate on. |

## Uninstall

```bash
helm uninstall fakebtg -n midaz-plugins
```

## Source

- Binary source: https://github.com/LerianStudio/plugin-br-payments/tree/main/cmd/fakebtg
- Chart source:  https://github.com/LerianStudio/helm/tree/main/charts/plugin-br-payments-fakebtg

## License

[Apache 2.0](../../LICENSE) (chart). The `plugin-br-payments` application itself is licensed under the [Elastic License 2.0](https://github.com/LerianStudio/plugin-br-payments/blob/main/LICENSE.md).
