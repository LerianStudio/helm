<!-- {% raw %} -->
# Helm Upgrade from v1.2.0 to v1.3.0

`system-facts` 1.3.0 pairs the chart with app images that serve probes, `/readyz` and `/metrics` on the internal health port 8099. Upgrade the chart before, or together with, the image: the chart refuses an `image.tag` below `1.2.0-beta.4` (API, worker and, through `appVersion`, an empty tag), and an old image on the new chart fails the render instead of stalling a rollout.

## What changes

| Area | Before | After |
|---|---|---|
| Probes | `/health` and `/readyz` on the main port, tunable | `startup` and `liveness` on `/health`, `readiness` on `/readyz`, port `health` (8099); not values |
| Service | port `http` | plus ClusterIP-only port `health` 8099 (never routed by an Ingress) |
| Grace period | `terminationGracePeriodSeconds: 55` | computed: drain 15 + shutdown 30 + 10 (API); worker 50 + 10 |
| API replicas | 1, autoscaler floor 1 | 2, autoscaler floor 2 |
| Rollout | `maxUnavailable: 1` | `maxSurge: 25%`, `maxUnavailable: 0` |
| PDB | `minAvailable` / `maxUnavailable` values | `maxUnavailable: 1`, `unhealthyPodEvictionPolicy: AlwaysAllow`; only `enabled` and `annotations` remain |
| Worker admin port | `worker.port` (`SERVER_ADDRESS`) | health port 8099 only; `worker.port` removed |

## Remove from your values

- `system-facts.livenessProbe`, `readinessProbe`, `terminationGracePeriodSeconds`, `deploymentUpdate`, `pdb.minAvailable`, `pdb.maxUnavailable` and `shutdownDrainDelay` (use `system-facts.health.drainSeconds`);
- `HEALTH_PORT`, `SHUTDOWN_DRAIN_DELAY` and `SHUTDOWN_TIMEOUT` in `configmap`;
- `worker.livenessProbe`, `readinessProbe`, `terminationGracePeriodSeconds`, `deploymentUpdate` and `port`. `worker.health.shutdownSeconds` defaults to 50 and the chart refuses less.
- A main-port `/readyz` or `/metrics` monitor (load balancer or uptime check): it returns 404 on the new image. Point it at the main-port `/health`.

## Rollback

Roll back the chart and the image together. An image-tag-only rollback below `1.2.0-beta.4` fails the render and the running version stays.

## Upgrade

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm --namespace system-facts --version 1.3.0
```
<!-- {% endraw %} -->
