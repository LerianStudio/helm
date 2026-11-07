<!-- {% raw %} -->
# Helm Upgrade from v3.1.0 to v3.2.0

`plugin-br-bank-transfer` 3.2.0 pairs the chart with app images that serve `/health`, `/readyz` and `/metrics` on the internal health port 8099 (`HEALTH_PORT`). Upgrade the chart and the image together: the chart refuses an `image.tag` below `3.6.0-beta.9` (explicit, or inherited from `appVersion`), so an old image on the new chart fails the render instead of stalling a rollout. The new image on the old chart fails differently: it no longer serves `/health/live`, `/health/ready` or the main-port `/readyz`, so the old probes return 404 and the pods restart.

## What changes

| Area | Before | After |
|---|---|---|
| Probes | liveness `/health/live`, readiness `/readyz` on the main port 4027, tunable | startup and liveness `/health`, readiness `/readyz`, port `health` (8099); not values |
| Container ports | `http` 4027 | plus `health` 8099 |
| Service | port `http` | multi-tenant only: plus ClusterIP port `health` 8099 (for `/readyz/tenant/:id`; never routed by an Ingress) |
| Env | none | `HEALTH_PORT=8099`, `SHUTDOWN_DRAIN_DELAY=15s`, `SHUTDOWN_TIMEOUT=30s` |
| Grace period | Kubernetes default (30s) | computed: drain 15 + shutdown 30 + 10 = 55s |
| Rollout | `maxSurge: 100%`, `maxUnavailable: 0` | `maxSurge: 25%`, `maxUnavailable: 0` |
| PDB | `minAvailable` / `maxUnavailable` values | `maxUnavailable: 1`, `unhealthyPodEvictionPolicy: AlwaysAllow`; only `enabled` and `annotations` remain |
| Metrics | scrape listener on `BTF_METRICS_PROMETHEUS_ADDRESS` (default `127.0.0.1:9090`) | `/metrics` on 8099; `BTF_METRICS_PROMETHEUS_ENABLED` still decides whether the `btf_` registry is served there |

## Removed routes

The image no longer serves `/health/live`, `/health/ready` or `/readyz` on the main port, and has no separate metrics listener. The main port keeps `/health` and `/version`. `/readyz` reports the pod's own state; a shared dependency down after boot is reported, never pulls the pod from the Service.

## Remove from your values

- `bankTransfer.livenessProbe`, `readinessProbe`, `deploymentUpdate`, `pdb.minAvailable` and `pdb.maxUnavailable`;
- `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY` and `SHUTDOWN_TIMEOUT` in `bankTransfer.configmap` (use `bankTransfer.health.drainSeconds` and `bankTransfer.health.shutdownSeconds`);
- `BTF_METRICS_PROMETHEUS_ADDRESS`, wherever you set it (for example `extraEnvVars`): the image ignores it.

If your GitOps overlay sets probe paths (`/health/live`, `/health/ready`), delete those overrides in the same change that bumps the chart: the render refuses them.

## Before you upgrade

- **BYOC network policy:** the kubelet probes the pod on 8099 now. A policy that admits only the node to port 4027 must also admit the node to the pod on 8099.
- **Load balancer and uptime checks:** a check on `/readyz`, `/health/live`, `/health/ready` or `/metrics` on the main port returns 404 on the new image. Point it at main `/health` on port 4027 (ALB: `alb.ingress.kubernetes.io/healthcheck-path: /health`, `healthcheck-port: "4027"`; GKE and AGIC: the same path on the serving port). Never route an Ingress to 8099.
- **Scraping:** point Prometheus at the pod's port 8099 `/metrics`, inside the cluster.
- **Grace:** the pod now has 55s to stop (15s drain, 30s shutdown budget, 10s margin). Raise `bankTransfer.health.shutdownSeconds` if your shutdown needs longer; the grace period follows.

## Rollback

Roll back the chart and the image together. An image-tag-only rollback below `3.6.0-beta.9` fails the render and the running version stays.

## Upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://ghcr.io/lerianstudio/plugin-br-bank-transfer-helm --namespace midaz-plugins --version 3.2.0
```
<!-- {% endraw %} -->
